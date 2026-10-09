import Foundation
import Observation
import SwiftData
import UserNotifications

/// A programme the viewer asked to be reminded about.
///
/// Stored with SwiftData. Every property has a default and none are unique, so
/// the model is CloudKit compatible: add the iCloud capability (CloudKit) and
/// reminders sync across the viewer's Apple TVs and survive tvOS clearing
/// local storage.
@Model
final class Reminder {
    var programmeID: String = ""
    var channelID: String = ""
    var channelName: String = ""
    var channelNumber: Int = 0
    /// "101" for TV, "0101" for radio.
    var channelDisplayNumber: String = ""
    var title: String = ""
    var start: Date = Date.distantPast
    var end: Date = Date.distantPast
    var createdAt: Date = Date()

    init(programme: Programme, channel: Channel) {
        programmeID = programme.id
        channelID = channel.id
        channelName = channel.name
        channelNumber = channel.number
        channelDisplayNumber = channel.displayNumber
        title = programme.title
        start = programme.start
        end = programme.end
    }
}

/// Reads and writes reminders, decides when one is due, and keeps the app
/// icon badge up to date (tvOS notifications can only badge, not alert, so the
/// reminder itself is shown in-app).
@MainActor
@Observable
final class ReminderStore {
    /// How long before the start a reminder pops up.
    static let leadTime: TimeInterval = 60

    private(set) var reminders: [Reminder] = []
    private let context: ModelContext
    private var alerted: Set<String> = []

    init(context: ModelContext) {
        self.context = context
        removeExpired()
        refresh()
    }

    func isSet(for programme: Programme) -> Bool {
        reminders.contains { $0.programmeID == programme.id }
    }

    func toggle(_ programme: Programme, on channel: Channel) {
        if let existing = reminders.filter({ $0.programmeID == programme.id }).first {
            remove(existing)
        } else {
            guard !programme.isPlaceholder, programme.start > Date() else { return }
            context.insert(Reminder(programme: programme, channel: channel))
            save()
        }
    }

    func remove(_ reminder: Reminder) {
        // Delete every copy (CloudKit sync can briefly create duplicates).
        for match in reminders where match.programmeID == reminder.programmeID { context.delete(match) }
        save()
    }

    /// The next reminder that should pop up now, if any.
    func due(at now: Date) -> Reminder? {
        reminders.first {
            !alerted.contains($0.programmeID) && $0.start.timeIntervalSince(now) <= Self.leadTime && now < $0.end
        }
    }

    func markAlerted(_ reminder: Reminder) {
        alerted.insert(reminder.programmeID)
    }

    func removeExpired(now: Date = Date()) {
        let cutoff = now
        let expired = (try? context.fetch(FetchDescriptor<Reminder>(predicate: #Predicate { $0.end < cutoff }))) ?? []
        guard !expired.isEmpty else { return }
        expired.forEach(context.delete)
        save()
    }

    func refresh() {
        let all = (try? context.fetch(FetchDescriptor<Reminder>(sortBy: [SortDescriptor(\.start)]))) ?? []
        var seen = Set<String>()
        reminders = all.filter { seen.insert($0.programmeID).inserted }
    }

    private func save() {
        try? context.save()
        refresh()
        Task { await Self.scheduleBadges(for: reminders) }
    }

    // MARK: App icon badge

    static func requestBadgePermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.badge])
        try? await center.setBadgeCount(0)
    }

    /// Schedules badge-only notifications so the TV app icon shows how many
    /// reminders have started while the app is closed.
    private static func scheduleBadges(for reminders: [Reminder]) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let upcoming = reminders.filter { $0.start > Date() }.prefix(60)
        for (index, reminder) in upcoming.enumerated() {
            let content = UNMutableNotificationContent()
            content.badge = NSNumber(value: index + 1)
            let fireDate = reminder.start.addingTimeInterval(-leadTime)
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.programmeID, content: content, trigger: trigger))
        }
    }
}
