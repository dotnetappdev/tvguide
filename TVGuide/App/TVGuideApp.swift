import AVFoundation
import SwiftData
import SwiftUI

@main
struct TVGuideApp: App {
    @State private var store = GuideStore()
    private let container: ModelContainer
    @State private var reminders: ReminderStore

    init() {
        // Programme artwork and channel logos are loaded with AsyncImage, which
        // goes through the shared URL cache; give it room for a week of artwork.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024,
                                   diskCapacity: 300 * 1024 * 1024)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)

        // Reminders live in SwiftData. If the iCloud (CloudKit) capability is
        // added, the default configuration syncs them through iCloud too.
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Reminder.self)
        } catch {
            container = try! ModelContainer(for: Reminder.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
        self.container = container
        _reminders = State(initialValue: ReminderStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            GuideRootView()
                .environment(store)
                .environment(reminders)
                .modelContainer(container)
                .task { await store.start() }
                .task { await ReminderStore.requestBadgePermission() }
                .preferredColorScheme(.dark)
        }
    }
}
