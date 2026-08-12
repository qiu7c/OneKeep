import SwiftUI

struct ExerciseLibraryView: View {
    var onSelect: ((ExerciseLibraryItem) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var items = ExerciseLibraryCatalog.allItems()
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseLibraryItem.Category?
    @State private var videosOnly = false

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(title: "全部", selected: selectedCategory == nil) { selectedCategory = nil }
                        ForEach(ExerciseLibraryItem.Category.allCases.filter { $0 != .custom }, id: \.self) { category in
                            filterChip(title: category.title, selected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                }
                Toggle("只看有视频的动作", isOn: $videosOnly)
                    .font(.subheadline)
            }

            ForEach(groupedCategories, id: \.self) { category in
                Section(category.title) {
                    ForEach(filteredItems.filter { $0.category == category }) { item in
                        HStack(spacing: 10) {
                            NavigationLink {
                                ExerciseLibraryDetailView(itemID: item.id, onSelect: onSelect)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(item.name)
                                            .font(.body.weight(.medium))
                                        if item.videoURL != nil {
                                            Image(systemName: "play.rectangle.fill")
                                                .font(.caption)
                                                .foregroundStyle(OKColor.secondaryText)
                                                .accessibilityLabel("包含视频")
                                        }
                                    }
                                    Text(item.summary)
                                        .font(.caption)
                                        .foregroundStyle(OKColor.secondaryText)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                            }
                            if let onSelect {
                                Button {
                                    onSelect(item)
                                    dismiss()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("选择\(item.name)")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle(onSelect == nil ? "动作库" : "选择动作")
        .searchable(text: $searchText, prompt: "搜索动作名称或别名")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    ExerciseLibraryEditorView(item: ExerciseLibraryItem(
                        id: "custom.\(UUID().uuidString)", name: "", aliases: [], category: .custom,
                        summary: "", instructions: [], commonMistakes: [], defaultTrackingMode: .repetitions,
                        defaultDurationSeconds: nil, defaultRestSeconds: 60, videoURL: nil, isCustom: true
                    ))
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新建自定义动作")
            }
        }
        .onAppear { items = ExerciseLibraryCatalog.allItems() }
        .overlay {
            if filteredItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.title2)
                    Text("没有匹配动作").font(.headline)
                    Text("可以新建自定义动作").font(.footnote).foregroundStyle(OKColor.secondaryText)
                }
            }
        }
    }

    private var filteredItems: [ExerciseLibraryItem] {
        let value = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return items.filter(matchesFilter) }
        return items.filter { item in
            matchesFilter(item) && (item.name.localizedCaseInsensitiveContains(value) ||
                (item.englishName?.localizedCaseInsensitiveContains(value) ?? false) ||
                item.aliases.contains { $0.localizedCaseInsensitiveContains(value) } ||
                item.summary.localizedCaseInsensitiveContains(value) ||
                (item.equipment?.localizedCaseInsensitiveContains(value) ?? false) ||
                (item.primaryMuscles?.contains { $0.localizedCaseInsensitiveContains(value) } ?? false))
        }
    }

    private func matchesFilter(_ item: ExerciseLibraryItem) -> Bool {
        (selectedCategory == nil || item.category == selectedCategory) && (!videosOnly || item.videoURL != nil)
    }

    private var groupedCategories: [ExerciseLibraryItem.Category] {
        ExerciseLibraryItem.Category.allCases.filter { category in filteredItems.contains { $0.category == category } }
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? OKColor.background : .primary)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(selected ? OKColor.accent : OKColor.background)
                .clipShape(Capsule())
                .overlay { Capsule().stroke(OKColor.border, lineWidth: selected ? 0 : 0.5) }
        }
        .buttonStyle(.plain)
    }
}

private struct ExerciseLibraryDetailView: View {
    let itemID: String
    var onSelect: ((ExerciseLibraryItem) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var item: ExerciseLibraryItem?
    @State private var showsRemoveConfirmation = false
    @State private var removeError: String?
    @State private var healthRecord: ExerciseVideoHealthRecord?
    @State private var isCheckingVideo = false
    @State private var offlineURL: URL?
    @State private var mediaMessage: String?

    var body: some View {
        ScrollView {
            if let item {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.category.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(OKColor.secondaryText)
                        Text(item.name)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        if let englishName = item.englishName, !englishName.isEmpty {
                            Text(englishName)
                                .font(.subheadline)
                                .foregroundStyle(OKColor.secondaryText)
                        }
                        Text(item.summary)
                            .foregroundStyle(OKColor.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .okCard()

                    detailCard(title: "动作步骤", icon: "list.number", lines: item.instructions)
                    detailCard(title: "常见错误", icon: "exclamationmark.triangle", lines: item.commonMistakes)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("默认记录").font(.headline)
                        if let equipment = item.equipment, !equipment.isEmpty {
                            Label(equipment, systemImage: "dumbbell")
                        }
                        if let muscles = item.primaryMuscles, !muscles.isEmpty {
                            Label(muscles.joined(separator: "、"), systemImage: "figure.strengthtraining.traditional")
                        }
                        if let difficulty = item.difficulty, !difficulty.isEmpty {
                            Label(difficulty, systemImage: "chart.bar")
                        }
                        Label(item.defaultTrackingMode.title, systemImage: "timer")
                        if let duration = item.defaultDurationSeconds {
                            Label("\(duration) 秒", systemImage: "clock")
                        }
                        Label("休息 \(item.defaultRestSeconds) 秒", systemImage: "pause")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .okCard()

                    if let safety = item.safetyNotes, !safety.isEmpty {
                        detailCard(title: "安全提示", icon: "shield", lines: safety)
                    }
                    if let breathing = item.breathingNotes, !breathing.isEmpty {
                        detailCard(title: "呼吸提示", icon: "wind", lines: breathing)
                    }
                    if let contraindications = item.contraindications, !contraindications.isEmpty {
                        detailCard(title: "不适合练习的情况", icon: "hand.raised", lines: contraindications)
                    }

                    if let url = ExerciseMediaResolver.playableURL(for: item), let source = VideoSource(urlString: url.absoluteString) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("动作视频").font(.headline)
                            if let thumbnailURL = healthRecord?.thumbnailURL {
                                CachedVideoThumbnail(url: thumbnailURL)
                            }
                            ExerciseVideoView(source: source)
                            if let author = healthRecord?.author ?? item.videoAuthor, !author.isEmpty {
                                Label("来源作者：\(author)", systemImage: "person.crop.circle")
                                    .font(.caption)
                                    .foregroundStyle(OKColor.secondaryText)
                            }
                            if let duration = item.videoDurationSeconds {
                                Label("视频时长：\(duration / 60) 分 \(duration % 60) 秒", systemImage: "clock")
                                    .font(.caption)
                                    .foregroundStyle(OKColor.secondaryText)
                            }
                            videoHealthLabel(item: item, playingURL: url)
                            HStack {
                                Button {
                                    checkVideo(url)
                                } label: {
                                    Label(isCheckingVideo ? "检测中" : "检测链接", systemImage: "checkmark.shield")
                                }
                                .disabled(isCheckingVideo)
                                if source.supportsOfflineCache {
                                    Button {
                                        toggleOffline(url)
                                    } label: {
                                        Label(offlineURL == nil ? "离线缓存" : "删除缓存", systemImage: offlineURL == nil ? "arrow.down.circle" : "trash")
                                    }
                                }
                            }
                            .font(.footnote.weight(.semibold))
                            if let mediaMessage {
                                Text(mediaMessage).font(.caption).foregroundStyle(OKColor.secondaryText)
                            }
                            Link(destination: url) {
                                Label("使用浏览器打开原始页面", systemImage: "safari")
                                    .font(.footnote.weight(.semibold))
                            }
                        }
                        .okCard()
                    } else {
                        Label("尚未配置视频链接，可在本地编辑资料中添加。", systemImage: "video.slash")
                            .font(.footnote)
                            .foregroundStyle(OKColor.secondaryText)
                            .okCard()
                    }

                    if let onSelect {
                        Button {
                            onSelect(item)
                            dismiss()
                        } label: {
                            Label("使用这个动作", systemImage: "checkmark")
                        }
                        .buttonStyle(OKPrimaryButtonStyle())
                    }

                    if let removeError {
                        Label(removeError, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .okCard()
                    }
                }
                .padding(20)
            }
        }
        .background(OKColor.background)
        .navigationTitle("动作详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let item {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ExerciseLibraryEditorView(item: item)
                    } label: {
                        Text("编辑")
                    }
                    Menu {
                        Button(role: .destructive) {
                            showsRemoveConfirmation = true
                        } label: {
                            Label(item.isCustom ? "删除自定义动作" : "恢复内置资料", systemImage: item.isCustom ? "trash" : "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            item = ExerciseLibraryCatalog.item(id: itemID)
            refreshMediaState()
        }
        .confirmationDialog(
            item?.isCustom == true ? "删除这个自定义动作？" : "恢复内置动作资料？",
            isPresented: $showsRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button(item?.isCustom == true ? "删除" : "恢复", role: .destructive) {
                removeLocalItem()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(item?.isCustom == true ? "已在计划中使用的动作不会被删除。" : "本机编辑过的文字和视频链接会恢复为应用内置版本。")
        }
    }

    private func detailCard(title: String, icon: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.headline)
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(OKColor.secondaryText)
                    Text(line).font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .okCard()
    }

    @ViewBuilder
    private func videoHealthLabel(item: ExerciseLibraryItem, playingURL: URL) -> some View {
        let isFallback = playingURL != item.videoURL
        HStack(spacing: 8) {
            Image(systemName: isFallback ? "arrow.triangle.branch" : "checkmark.seal")
            Text(isFallback ? "主链接不可用，已自动切换备用视频" : "动作与视频名称已审核")
        }
        .font(.caption)
        .foregroundStyle(isFallback ? Color.orange : OKColor.secondaryText)
        if let record = healthRecord {
            Text(record.status == .available ? "最近检测可用：\(record.checkedAt.formatted(date: .abbreviated, time: .shortened))" : (record.message ?? "尚未确认可用"))
                .font(.caption)
                .foregroundStyle(record.status == .unavailable ? Color.red : OKColor.secondaryText)
        }
    }

    private func refreshMediaState() {
        guard let item, let url = ExerciseMediaResolver.playableURL(for: item) else { return }
        healthRecord = ExerciseVideoHealthStore.record(for: url)
        Task { offlineURL = await ExerciseVideoOfflineStore.shared.localURL(for: url) }
    }

    private func checkVideo(_ url: URL) {
        isCheckingVideo = true
        mediaMessage = nil
        Task {
            healthRecord = await ExerciseVideoHealthService.shared.check(url)
            isCheckingVideo = false
            if healthRecord?.status == .unavailable {
                item = ExerciseLibraryCatalog.item(id: itemID)
                mediaMessage = "检测到主链接失效时会自动使用备用视频。"
            }
        }
    }

    private func toggleOffline(_ url: URL) {
        mediaMessage = nil
        Task {
            do {
                if offlineURL == nil {
                    offlineURL = try await ExerciseVideoOfflineStore.shared.download(url)
                    mediaMessage = "视频已缓存到本机。"
                } else {
                    try await ExerciseVideoOfflineStore.shared.remove(url)
                    offlineURL = nil
                    mediaMessage = "本机视频缓存已删除。"
                }
            } catch {
                mediaMessage = error.localizedDescription
            }
        }
    }

    private func removeLocalItem() {
        do {
            let wasCustom = item?.isCustom == true
            try ExerciseLibraryCatalog.removeLocalItem(id: itemID)
            if wasCustom {
                dismiss()
            } else {
                item = ExerciseLibraryCatalog.item(id: itemID)
            }
        } catch {
            removeError = error.localizedDescription
        }
    }
}

private struct ExerciseLibraryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: ExerciseLibraryItem
    @State private var aliasesText: String
    @State private var instructionsText: String
    @State private var mistakesText: String
    @State private var videoText: String
    @State private var alternateVideosText: String
    @State private var equipmentText: String
    @State private var englishNameText: String
    @State private var musclesText: String
    @State private var safetyText: String
    @State private var difficultyText: String
    @State private var breathingText: String
    @State private var contraindicationsText: String
    @State private var errorMessage: String?

    init(item: ExerciseLibraryItem) {
        _item = State(initialValue: item)
        _aliasesText = State(initialValue: item.aliases.joined(separator: "、"))
        _instructionsText = State(initialValue: item.instructions.joined(separator: "\n"))
        _mistakesText = State(initialValue: item.commonMistakes.joined(separator: "\n"))
        _videoText = State(initialValue: item.videoURL?.absoluteString ?? "")
        _alternateVideosText = State(initialValue: (item.alternateVideoURLs ?? []).map(\.absoluteString).joined(separator: "\n"))
        _equipmentText = State(initialValue: item.equipment ?? "")
        _englishNameText = State(initialValue: item.englishName ?? "")
        _musclesText = State(initialValue: item.primaryMuscles?.joined(separator: "、") ?? "")
        _safetyText = State(initialValue: item.safetyNotes?.joined(separator: "\n") ?? "")
        _difficultyText = State(initialValue: item.difficulty ?? "")
        _breathingText = State(initialValue: item.breathingNotes?.joined(separator: "\n") ?? "")
        _contraindicationsText = State(initialValue: item.contraindications?.joined(separator: "\n") ?? "")
    }

    var body: some View {
        Form {
            Section("基本资料") {
                TextField("动作名称", text: $item.name)
                TextField("英文名称（可选）", text: $englishNameText)
                Picker("分类", selection: $item.category) {
                    ForEach(ExerciseLibraryItem.Category.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                TextField("别名，用顿号分隔", text: $aliasesText)
                TextField("简短说明", text: $item.summary, axis: .vertical)
                TextField("器械", text: $equipmentText)
                TextField("主要肌群，用顿号分隔", text: $musclesText)
                TextField("难度，例如入门", text: $difficultyText)
            }
            Section("动作步骤（每行一条）") {
                TextEditor(text: $instructionsText).frame(minHeight: 120)
            }
            Section("常见错误（每行一条）") {
                TextEditor(text: $mistakesText).frame(minHeight: 100)
            }
            Section("安全提示（每行一条）") {
                TextEditor(text: $safetyText).frame(minHeight: 80)
            }
            Section("呼吸提示（每行一条）") {
                TextEditor(text: $breathingText).frame(minHeight: 80)
            }
            Section("不适合练习的情况（每行一条）") {
                TextEditor(text: $contraindicationsText).frame(minHeight: 80)
            }
            Section("默认记录") {
                Picker("记录方式", selection: $item.defaultTrackingMode) {
                    ForEach(PlannedExercise.TrackingMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                if item.defaultTrackingMode == .countdown {
                    Stepper("时长 \(item.defaultDurationSeconds ?? 30) 秒", value: duration, in: 5...3600, step: 5)
                }
                Stepper("休息 \(item.defaultRestSeconds) 秒", value: $item.defaultRestSeconds, in: 0...1800, step: 15)
            }
            Section("在线视频") {
                TextField("https://", text: $videoText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextEditor(text: $alternateVideosText)
                    .frame(minHeight: 70)
                Text("第一行是主视频；下方每行填写一个备用链接。主链接检测失效后自动切换。")
                    .font(.footnote)
                    .foregroundStyle(OKColor.secondaryText)
                if let source = VideoSource(urlString: videoText) {
                    ExerciseVideoView(source: source)
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle(item.isCustom ? "自定义动作" : "编辑本地资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("保存", action: save) }
        }
    }

    private var duration: Binding<Int> {
        Binding(get: { item.defaultDurationSeconds ?? 30 }, set: { item.defaultDurationSeconds = $0 })
    }

    private func save() {
        let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { errorMessage = "动作名称不能为空"; return }
        if !videoText.isEmpty, VideoSource(urlString: videoText) == nil {
            errorMessage = "视频链接格式无效"
            return
        }
        let alternateURLs = alternateVideosText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if alternateURLs.contains(where: { VideoSource(urlString: $0) == nil }) {
            errorMessage = "备用视频中存在无效链接"
            return
        }
        item.name = name
        item.aliases = aliasesText.components(separatedBy: CharacterSet(charactersIn: "、,\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        item.instructions = instructionsText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        item.commonMistakes = mistakesText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        item.equipment = equipmentText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        item.englishName = englishNameText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        item.primaryMuscles = splitList(musclesText)
        item.safetyNotes = safetyText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        item.difficulty = difficultyText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        item.breathingNotes = breathingText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        item.contraindications = contraindicationsText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        item.videoURL = videoText.isEmpty ? nil : URL(string: videoText)
        item.alternateVideoURLs = alternateURLs.compactMap(URL.init(string:))
        item.videoReviewStatus = .userProvided
        item.videoReviewedAt = .now
        do {
            try ExerciseLibraryCatalog.save(item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func splitList(_ value: String) -> [String] {
        value.components(separatedBy: CharacterSet(charactersIn: "、,\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
