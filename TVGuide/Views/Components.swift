import SwiftUI

/// What the guide is currently pointing at (drives the hero panel and detail view).
struct Highlight: Identifiable, Equatable {
    let channel: Channel
    let programme: Programme?

    var id: String { programme?.id ?? channel.id }
}

/// Channel logo on a dark navy chip (the logos are designed for dark
/// backgrounds), falling back to a branded monogram.
struct ChannelLogo: View {
    let channel: Channel
    var height: CGFloat = 44

    var body: some View {
        AsyncImage(url: channel.logoURL, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            if case .success(let image) = phase {
                image
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical, height * 0.14)
                    .padding(.horizontal, height * 0.22)
                    .frame(width: height * 2, height: height)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: height * 0.22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: height * 0.22, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    }
            } else {
                monogram
            }
        }
        .frame(width: height * 2, height: height)
        .accessibilityLabel(channel.name)
    }

    private var monogram: some View {
        Text(channel.monogram)
            .font(.system(size: height * 0.42, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 6)
            .frame(width: height * 2, height: height)
            .background(Color(hex: channel.brandHex).gradient,
                        in: RoundedRectangle(cornerRadius: height * 0.22, style: .continuous))
    }
}

/// Small rounded label such as "HD", "S", "NEW" or "S2 E4".
struct Badge: View {
    let text: String
    var filled = false
    var tint: Color = .white

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(filled ? Theme.ink : tint)
            .background(filled ? tint : .clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(tint.opacity(filled ? 0 : 0.7), lineWidth: 1.5)
            }
    }
}

/// Thin progress bar showing how far through a programme we are.
struct ProgrammeProgress: View {
    let progress: Double
    var tint: Color = Theme.accent
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.22))
                Capsule().fill(tint).frame(width: max(height, proxy.size.width * progress))
            }
        }
        .frame(height: height)
    }
}

/// Programme artwork with a branded gradient fallback.
struct Artwork: View {
    let url: URL?
    let channel: Channel

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    LinearGradient(colors: [Color(hex: channel.brandHex), Theme.backgroundTop],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    ChannelLogo(channel: channel, height: 70).opacity(0.9)
                }
            }
        }
        .clipped()
    }
}

/// Full-screen backdrop: classic Sky royal blue gradient.
struct GuideBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.backgroundTop, Theme.backgroundBottom],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.glow.opacity(0.45), .clear],
                           center: .topTrailing, startRadius: 40, endRadius: 900)
            RadialGradient(colors: [Theme.backgroundTop.opacity(0.6), .clear],
                           center: .bottomLeading, startRadius: 20, endRadius: 700)
        }
        .ignoresSafeArea()
    }
}

extension Programme {
    /// Badges shown next to a listing, Sky style.
    func badges(on channel: Channel) -> [String] {
        var list: [String] = []
        if channel.isHD { list.append("HD") }
        if !isPlaceholder { list.append("S") }
        if let episode { list.append(episode) }
        return list
    }
}
