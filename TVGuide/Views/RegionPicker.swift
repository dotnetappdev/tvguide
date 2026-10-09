import SwiftUI

/// Lets the viewer pick their Freeview region so BBC One, ITV1/STV/UTV and
/// Channel 4 show the right regional listings.
struct RegionPicker: View {
    @Environment(GuideStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(Region.all) { region in
                Button {
                    Task { await store.setRegion(region) }
                    dismiss()
                } label: {
                    HStack {
                        Text(region.name)
                        Spacer()
                        if region == store.region {
                            Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
            .navigationTitle("Your TV region")
        }
    }
}
