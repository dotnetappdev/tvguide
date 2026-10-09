import SwiftUI

@main
struct TVGuideApp: App {
    @State private var store = GuideStore()

    init() {
        // Programme artwork and channel logos are loaded with AsyncImage, which
        // goes through the shared URL cache; give it room for a week of artwork.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024,
                                   diskCapacity: 300 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            GuideRootView()
                .environment(store)
                .task { await store.start() }
                .preferredColorScheme(.dark)
        }
    }
}
