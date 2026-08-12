import Foundation

enum ScheduleResolver {
    static func trainingDays(
        in plans: [TrainingPlan],
        on date: Date,
        calendar: Calendar = .current
    ) -> [(plan: TrainingPlan, day: TrainingDay)] {
        plans.flatMap { plan in
            guard isWithinPlan(plan, date: date, calendar: calendar) else { return [] }
            return plan.days.compactMap { day in
                matches(day.recurrence, date: date, calendar: calendar) ? (plan, day) : nil
            }
        }
    }

    static func matches(_ rule: ScheduleRule, date: Date, calendar: Calendar = .current) -> Bool {
        let target = calendar.startOfDay(for: date)
        let anchor = calendar.startOfDay(for: rule.anchorDate)

        guard target >= anchor else { return false }
        if let endDate = rule.endDate, target > calendar.startOfDay(for: endDate) {
            return false
        }

        switch rule.kind {
        case .specificDate:
            return calendar.isDate(target, inSameDayAs: anchor)
        case .weekly, .biweekly:
            let weekday = calendar.component(.weekday, from: target)
            guard rule.weekdays.contains(weekday) else { return false }
            guard rule.kind == .biweekly else { return true }

            let anchorWeek = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
            let targetWeek = calendar.dateInterval(of: .weekOfYear, for: target)?.start ?? target
            let weeks = calendar.dateComponents([.weekOfYear], from: anchorWeek, to: targetWeek).weekOfYear ?? 0
            return weeks >= 0 && weeks.isMultiple(of: 2)
        }
    }

    private static func isWithinPlan(_ plan: TrainingPlan, date: Date, calendar: Calendar) -> Bool {
        let target = calendar.startOfDay(for: date)
        guard target >= calendar.startOfDay(for: plan.startDate) else { return false }
        if let endDate = plan.endDate, target > calendar.startOfDay(for: endDate) {
            return false
        }
        return true
    }
}
