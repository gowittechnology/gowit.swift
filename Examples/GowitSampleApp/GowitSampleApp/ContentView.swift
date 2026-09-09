import SwiftUI
import Gowit
import AdViews

/// The one fixture this sample renders, and the errors it can fail to load with.
enum FixtureLoader {
    enum Failure: Error, LocalizedError {
        case notBundled
        case undecodable(Error)
        case noAd

        var errorDescription: String? {
            switch self {
            case .notBundled: return "standard-ad-response.json is not in the app bundle."
            case .undecodable(let error): return "The fixture did not decode: \(error)"
            case .noAd: return "The fixture decoded but carries no ad."
            }
        }
    }

    /// Load the first ad of the first placement. A missing fixture is surfaced, never
    /// swallowed into an empty screen that looks like a no-fill.
    static func loadFirstAd() -> Result<Ad, Failure> {
        guard let url = Bundle.main.url(forResource: "standard-ad-response", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return .failure(.notBundled)
        }
        do {
            let response = try JSONDecoder().decode(AdResponse.self, from: data)
            guard let ad = response.allAds.first else { return .failure(.noAd) }
            return .success(ad)
        } catch {
            return .failure(.undecodable(error))
        }
    }
}

struct ContentView: View {
    @StateObject private var log = RenderLog()
    @State private var loaded = FixtureLoader.loadFirstAd()
    @State private var lastAction: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    manifestSection

                    section("Rendered ad") {
                        switch loaded {
                        case .success(let ad):
                            StandardAdContainerView(
                                ad: ad,
                                capability: GowitCapabilities.installed(in: geometry),
                                lifecycle: log.lifecycle,
                                onAction: { request in
                                    // The host decides what an action means. The renderer
                                    // hands over a token and a URL and never reaches into
                                    // the app itself.
                                    lastAction = "\(request.token) -> \(request.url.absoluteString)"
                                    log.append("action \(request.token)")
                                }
                            )
                            .accessibilityIdentifier("gowit.standard-ad")
                        case .failure(let error):
                            Text(error.localizedDescription)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .accessibilityIdentifier("gowit.fixture-error")
                        }
                    }

                    if let lastAction = lastAction {
                        section("Last action") {
                            Text(lastAction).font(.caption).textSelection(.enabled)
                        }
                    }

                    section("Lifecycle") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(log.lines.enumerated()), id: \.offset) { item in
                                Text(item.element).font(.system(.caption, design: .monospaced))
                            }
                        }
                        .accessibilityIdentifier("gowit.lifecycle-log")
                    }
                }
                .padding()
            }
            .navigationTitle("Gowit sample host")
        }
        .navigationViewStyle(.stack)
    }

    /// The space actually available at request time, which is a property of the
    /// request rather than of the installed build.
    private var geometry: GeometryCapability {
        GeometryCapability(
            availableWidth: Int(UIScreen.main.bounds.width),
            availableHeight: 240,
            density: Double(UIScreen.main.scale),
            heightMayChange: true
        )
    }

    private var manifestSection: some View {
        section("Declared capabilities") {
            VStack(alignment: .leading, spacing: 4) {
                row("platform", GowitCapabilities.installed.platform.rawValue)
                row("renderer_version", GowitCapabilities.rendererVersion)
                row("protocol_major", String(GowitCapabilities.protocolMajor))
                row("minimum_os", "\(GowitCapabilities.support.minimumOS) (\(GowitCapabilities.support.status.rawValue))")
                row("primitives", (GowitCapabilities.installed.primitives ?? []).count.description)
                row("observation", (GowitCapabilities.installed.observation ?? []).joined(separator: ", "))
            }
            .accessibilityIdentifier("gowit.manifest")
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key).font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
            Spacer(minLength: 12)
            Text(value).font(.system(.caption, design: .monospaced)).multilineTextAlignment(.trailing)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }
}

/// Collects the renderer's lifecycle events so the simulator run has something to
/// show, and echoes them to stdout so a headless launch is evidence too.
final class RenderLog: ObservableObject {
    @Published private(set) var lines: [String] = []
    private(set) lazy var lifecycle = AdRenderLifecycle { [weak self] event in
        switch event {
        case .mounted(let adID): self?.append("mounted \(adID ?? "-")")
        case .exposed(let adID): self?.append("exposed \(adID ?? "-")")
        case .disposed(let adID): self?.append("disposed \(adID ?? "-")")
        case .refused(let refusal):
            self?.append("refused \(refusal.code.rawValue) \((refusal.missingCapabilities ?? []).joined(separator: ","))")
        }
    }

    func append(_ line: String) {
        print("[gowit-sample] \(line)")
        DispatchQueue.main.async { self.lines.append(line) }
    }
}
