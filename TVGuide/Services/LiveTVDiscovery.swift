import Foundation
import Network
import Observation

/// Finds live TV hardware on the home network:
/// - Channels DVR servers, which advertise themselves over Bonjour.
/// - HDHomeRun tuners, via SiliconDust's discovery service (it lists tuners
///   on the same internet connection). These stream raw MPEG-TS, which Apple
///   TV can't play directly, so they're shown as "add Channels DVR" hints.
@MainActor
@Observable
final class LiveTVDiscovery {
    struct Server: Identifiable, Hashable {
        let name: String
        let url: URL
        var id: URL { url }
    }

    struct Tuner: Identifiable, Hashable, Decodable {
        let deviceID: String?
        let localIP: String?
        let friendlyName: String?
        var id: String { deviceID ?? localIP ?? "tuner" }

        enum CodingKeys: String, CodingKey {
            case deviceID = "DeviceID", localIP = "LocalIP", friendlyName = "FriendlyName"
        }
    }

    static let channelsServiceType = "_channels_dvr._tcp"

    private(set) var servers: [Server] = []
    private(set) var tuners: [Tuner] = []
    private(set) var isSearching = false

    private var browser: NWBrowser?
    private var resolving: [NWConnection] = []

    func start() {
        stop()
        isSearching = true
        let browser = NWBrowser(for: .bonjour(type: Self.channelsServiceType, domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in self?.resolve(results) }
        }
        browser.start(queue: .main)
        self.browser = browser
        Task { await findTuners() }
        // Bonjour keeps browsing; stop the spinner after a few seconds.
        Task {
            try? await Task.sleep(for: .seconds(6))
            isSearching = false
        }
    }

    func stop() {
        browser?.cancel()
        browser = nil
        resolving.forEach { $0.cancel() }
        resolving = []
    }

    /// Bonjour gives a service name; connect briefly to learn its address.
    private func resolve(_ results: Set<NWBrowser.Result>) {
        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            let connection = NWConnection(to: result.endpoint, using: .tcp)
            connection.stateUpdateHandler = { [weak self, weak connection] state in
                guard case .ready = state, let connection,
                      case let .hostPort(host, port)? = connection.currentPath?.remoteEndpoint else { return }
                var hostString = "\(host)"
                if let percent = hostString.firstIndex(of: "%") { hostString = String(hostString[..<percent]) }
                if hostString.contains(":") { hostString = "[\(hostString)]" } // IPv6
                connection.cancel()
                guard let url = URL(string: "http://\(hostString):\(port.rawValue)") else { return }
                Task { @MainActor in
                    guard let self, !self.servers.contains(where: { $0.url == url || $0.name == name }) else { return }
                    self.servers.append(Server(name: name, url: url))
                }
            }
            connection.start(queue: .main)
            resolving.append(connection)
        }
    }

    private func findTuners() async {
        guard let url = URL(string: "https://api.hdhomerun.com/discover"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let found = try? JSONDecoder().decode([Tuner].self, from: data) else { return }
        tuners = found
    }
}
