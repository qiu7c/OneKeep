import CoreData
import CryptoKit
import Foundation

struct CompleteBackup: Codable {
    let formatVersion: Int
    let exportedAt: Date
    let profile: UserProfile
    let aiProvider: AIProviderConfiguration?
    let plans: [TrainingPlan]
    let sessions: [BackupWorkoutSession]
    let performedSets: [BackupPerformedSet]
    let quickLogs: [BackupQuickLog]
    let chatHistory: [AIChatMessage]?
}

struct BackupWorkoutSession: Codable {
    let id: UUID
    let trainingDayID: UUID
    let title: String
    let startedAt: Date
    let endedAt: Date?
    let status: String
    let updatedAt: Date
}

struct BackupPerformedSet: Codable {
    let id: UUID
    let sessionID: UUID
    let exerciseID: UUID
    let exerciseName: String
    let stepIndex: Int64
    let setIndex: Int64
    let repetitions: Int64?
    let durationSeconds: Int64?
    let plannedWeightKilograms: Double?
    let weightKilograms: Double?
    let completedAt: Date
}

struct BackupQuickLog: Codable {
    let id: UUID
    let kind: String
    let createdAt: Date
    let note: String?
    let value: Double?
}

private struct BackupManifest: Codable {
    let formatVersion: Int
    let exportedAt: Date
    let dataSHA256: String
    let note: String
}

enum CompleteBackupError: LocalizedError {
    case invalidArchive
    case unsupportedVersion
    case damagedData

    var errorDescription: String? {
        switch self {
        case .invalidArchive: return "这不是有效的 OneKeep 备份文件"
        case .unsupportedVersion: return "备份版本过新，请先更新 OneKeep"
        case .damagedData: return "备份校验失败，文件可能已损坏"
        }
    }
}

@MainActor
final class CompleteBackupService {
    static let formatVersion = 1

    private let context: NSManagedObjectContext
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(context: NSManagedObjectContext) {
        self.context = context
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func exportArchive() throws -> URL {
        let backup = CompleteBackup(
            formatVersion: Self.formatVersion,
            exportedAt: .now,
            profile: UserProfilePreferences.load(),
            aiProvider: AIProviderPreferences.load(),
            plans: try CoreDataPlanRepository(context: context).fetchAll(),
            sessions: try fetchSessions(),
            performedSets: try fetchSets(),
            quickLogs: try fetchQuickLogs(),
            chatHistory: AIConversationPreferences.load()
        )
        let data = try encoder.encode(backup)
        let manifest = BackupManifest(
            formatVersion: Self.formatVersion,
            exportedAt: backup.exportedAt,
            dataSHA256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            note: "API Key 不包含在备份中"
        )
        let archive = try SimpleZIPArchive.make(entries: [
            "manifest.json": encoder.encode(manifest),
            "data.json": data
        ])
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OneKeep-\(formatter.string(from: .now)).zip")
        try archive.write(to: url, options: .atomic)
        return url
    }

    func restoreArchive(from url: URL) throws {
        let archiveData = try Data(contentsOf: url)
        let entries = try SimpleZIPArchive.extract(archiveData)
        guard let manifestData = entries["manifest.json"], let backupData = entries["data.json"] else {
            throw CompleteBackupError.invalidArchive
        }
        let manifest = try decoder.decode(BackupManifest.self, from: manifestData)
        guard manifest.formatVersion <= Self.formatVersion else { throw CompleteBackupError.unsupportedVersion }
        let digest = SHA256.hash(data: backupData).map { String(format: "%02x", $0) }.joined()
        guard digest == manifest.dataSHA256 else { throw CompleteBackupError.damagedData }
        let backup = try decoder.decode(CompleteBackup.self, from: backupData)
        guard backup.formatVersion <= Self.formatVersion else { throw CompleteBackupError.unsupportedVersion }

        try replaceLocalData(with: backup)
        try UserProfilePreferences.save(backup.profile)
        if let provider = backup.aiProvider {
            try AIProviderPreferences.save(provider)
        } else {
            AIProviderPreferences.clear()
        }
        AIConversationPreferences.save(backup.chatHistory ?? [])
    }

    private func replaceLocalData(with backup: CompleteBackup) throws {
        let entityNames = ["TrainingPlanEntity", "WorkoutSessionEntity", "PerformedSetEntity", "QuickLogEntity"]
        for entityName in entityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            try context.fetch(request).forEach(context.delete)
        }

        let planEncoder = JSONEncoder()
        planEncoder.dateEncodingStrategy = .iso8601
        for plan in backup.plans {
            let object = NSEntityDescription.insertNewObject(forEntityName: "TrainingPlanEntity", into: context)
            object.setValue(plan.id, forKey: "id")
            object.setValue(plan.title, forKey: "title")
            object.setValue(plan.startDate, forKey: "startDate")
            object.setValue(plan.endDate, forKey: "endDate")
            object.setValue(try planEncoder.encode(plan), forKey: "payload")
            object.setValue(backup.exportedAt, forKey: "createdAt")
            object.setValue(backup.exportedAt, forKey: "updatedAt")
        }
        for item in backup.sessions {
            let object = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSessionEntity", into: context)
            object.setValuesForKeys([
                "id": item.id, "trainingDayID": item.trainingDayID, "title": item.title,
                "startedAt": item.startedAt, "status": item.status, "updatedAt": item.updatedAt
            ])
            object.setValue(item.endedAt, forKey: "endedAt")
        }
        for item in backup.performedSets {
            let object = NSEntityDescription.insertNewObject(forEntityName: "PerformedSetEntity", into: context)
            object.setValuesForKeys([
                "id": item.id, "sessionID": item.sessionID, "exerciseID": item.exerciseID,
                "exerciseName": item.exerciseName, "stepIndex": item.stepIndex,
                "setIndex": item.setIndex, "completedAt": item.completedAt
            ])
            object.setValue(item.repetitions, forKey: "repetitions")
            object.setValue(item.durationSeconds, forKey: "durationSeconds")
            object.setValue(item.plannedWeightKilograms, forKey: "plannedWeightKilograms")
            object.setValue(item.weightKilograms, forKey: "weightKilograms")
        }
        for item in backup.quickLogs {
            let object = NSEntityDescription.insertNewObject(forEntityName: "QuickLogEntity", into: context)
            object.setValuesForKeys(["id": item.id, "kind": item.kind, "createdAt": item.createdAt])
            object.setValue(item.note, forKey: "note")
            object.setValue(item.value, forKey: "value")
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func fetchSessions() throws -> [BackupWorkoutSession] {
        try fetch("WorkoutSessionEntity").compactMap { object in
            guard let id = object.value(forKey: "id") as? UUID,
                  let dayID = object.value(forKey: "trainingDayID") as? UUID,
                  let title = object.value(forKey: "title") as? String,
                  let startedAt = object.value(forKey: "startedAt") as? Date,
                  let status = object.value(forKey: "status") as? String,
                  let updatedAt = object.value(forKey: "updatedAt") as? Date else { return nil }
            return BackupWorkoutSession(id: id, trainingDayID: dayID, title: title, startedAt: startedAt,
                                        endedAt: object.value(forKey: "endedAt") as? Date,
                                        status: status, updatedAt: updatedAt)
        }
    }

    private func fetchSets() throws -> [BackupPerformedSet] {
        try fetch("PerformedSetEntity").compactMap { object in
            guard let id = object.value(forKey: "id") as? UUID,
                  let sessionID = object.value(forKey: "sessionID") as? UUID,
                  let exerciseID = object.value(forKey: "exerciseID") as? UUID,
                  let exerciseName = object.value(forKey: "exerciseName") as? String,
                  let completedAt = object.value(forKey: "completedAt") as? Date else { return nil }
            return BackupPerformedSet(
                id: id, sessionID: sessionID, exerciseID: exerciseID, exerciseName: exerciseName,
                stepIndex: (object.value(forKey: "stepIndex") as? NSNumber)?.int64Value ?? 0,
                setIndex: (object.value(forKey: "setIndex") as? NSNumber)?.int64Value ?? 0,
                repetitions: (object.value(forKey: "repetitions") as? NSNumber)?.int64Value,
                durationSeconds: (object.value(forKey: "durationSeconds") as? NSNumber)?.int64Value,
                plannedWeightKilograms: (object.value(forKey: "plannedWeightKilograms") as? NSNumber)?.doubleValue,
                weightKilograms: (object.value(forKey: "weightKilograms") as? NSNumber)?.doubleValue,
                completedAt: completedAt
            )
        }
    }

    private func fetchQuickLogs() throws -> [BackupQuickLog] {
        try fetch("QuickLogEntity").compactMap { object in
            guard let id = object.value(forKey: "id") as? UUID,
                  let kind = object.value(forKey: "kind") as? String,
                  let createdAt = object.value(forKey: "createdAt") as? Date else { return nil }
            return BackupQuickLog(id: id, kind: kind, createdAt: createdAt,
                                  note: object.value(forKey: "note") as? String,
                                  value: (object.value(forKey: "value") as? NSNumber)?.doubleValue)
        }
    }

    private func fetch(_ entityName: String) throws -> [NSManagedObject] {
        try context.fetch(NSFetchRequest<NSManagedObject>(entityName: entityName))
    }
}

private enum SimpleZIPArchive {
    static func make(entries: [String: Data]) throws -> Data {
        var output = Data()
        var central = Data()
        var count: UInt16 = 0

        for (name, contents) in entries.sorted(by: { $0.key < $1.key }) {
            let nameData = Data(name.utf8)
            guard nameData.count <= Int(UInt16.max), contents.count <= Int(UInt32.max) else {
                throw CompleteBackupError.invalidArchive
            }
            let offset = UInt32(output.count)
            let crc = CRC32.checksum(contents)
            output.appendLE(UInt32(0x04034b50)); output.appendLE(UInt16(20)); output.appendLE(UInt16(0x0800))
            output.appendLE(UInt16(0)); output.appendLE(UInt16(0)); output.appendLE(UInt16(0))
            output.appendLE(crc); output.appendLE(UInt32(contents.count)); output.appendLE(UInt32(contents.count))
            output.appendLE(UInt16(nameData.count)); output.appendLE(UInt16(0)); output.append(nameData); output.append(contents)

            central.appendLE(UInt32(0x02014b50)); central.appendLE(UInt16(20)); central.appendLE(UInt16(20))
            central.appendLE(UInt16(0x0800)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0))
            central.appendLE(crc); central.appendLE(UInt32(contents.count)); central.appendLE(UInt32(contents.count))
            central.appendLE(UInt16(nameData.count)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0))
            central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt32(0)); central.appendLE(offset)
            central.append(nameData)
            count += 1
        }
        let centralOffset = UInt32(output.count)
        output.append(central)
        output.appendLE(UInt32(0x06054b50)); output.appendLE(UInt16(0)); output.appendLE(UInt16(0))
        output.appendLE(count); output.appendLE(count); output.appendLE(UInt32(central.count)); output.appendLE(centralOffset)
        output.appendLE(UInt16(0))
        return output
    }

    static func extract(_ data: Data) throws -> [String: Data] {
        guard data.count >= 22 else { throw CompleteBackupError.invalidArchive }
        let searchStart = max(0, data.count - 65_557)
        var eocd: Int?
        for offset in stride(from: data.count - 22, through: searchStart, by: -1) {
            if try data.readLE(UInt32.self, at: offset) == 0x06054b50 { eocd = offset; break }
        }
        guard let eocd else { throw CompleteBackupError.invalidArchive }
        let count = Int(try data.readLE(UInt16.self, at: eocd + 10))
        var cursor = Int(try data.readLE(UInt32.self, at: eocd + 16))
        var result: [String: Data] = [:]
        for _ in 0..<count {
            guard try data.readLE(UInt32.self, at: cursor) == 0x02014b50 else { throw CompleteBackupError.invalidArchive }
            let method = try data.readLE(UInt16.self, at: cursor + 10)
            guard method == 0 else { throw CompleteBackupError.invalidArchive }
            let size = Int(try data.readLE(UInt32.self, at: cursor + 24))
            let nameLength = Int(try data.readLE(UInt16.self, at: cursor + 28))
            let extraLength = Int(try data.readLE(UInt16.self, at: cursor + 30))
            let commentLength = Int(try data.readLE(UInt16.self, at: cursor + 32))
            let localOffset = Int(try data.readLE(UInt32.self, at: cursor + 42))
            let nameData = try data.checkedSubdata(in: cursor + 46..<cursor + 46 + nameLength)
            guard let name = String(data: nameData, encoding: .utf8), !name.contains(".."), !name.contains("/") else {
                throw CompleteBackupError.invalidArchive
            }
            guard try data.readLE(UInt32.self, at: localOffset) == 0x04034b50 else { throw CompleteBackupError.invalidArchive }
            let localNameLength = Int(try data.readLE(UInt16.self, at: localOffset + 26))
            let localExtraLength = Int(try data.readLE(UInt16.self, at: localOffset + 28))
            let contentStart = localOffset + 30 + localNameLength + localExtraLength
            result[name] = try data.checkedSubdata(in: contentStart..<contentStart + size)
            cursor += 46 + nameLength + extraLength + commentLength
        }
        return result
    }
}

private enum CRC32 {
    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ (0xedb88320 & (0 &- (crc & 1))) }
        }
        return crc ^ 0xffffffff
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    func readLE<T: FixedWidthInteger>(_ type: T.Type, at offset: Int) throws -> T {
        let bytes = try checkedSubdata(in: offset..<offset + MemoryLayout<T>.size)
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: T.self) }.littleEndian
    }

    func checkedSubdata(in range: Range<Int>) throws -> Data {
        guard range.lowerBound >= 0, range.upperBound <= count, range.lowerBound <= range.upperBound else {
            throw CompleteBackupError.invalidArchive
        }
        return subdata(in: range)
    }
}
