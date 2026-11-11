import XCTest
@testable import AdViews

@MainActor
final class VideoAdMuteCallbackTests: XCTestCase {

    private let vastURL = URL(string: "https://example.com/vast.xml")!

    func testToggleMuteReportsEachNewStateToHost() {
        let viewModel = VideoAdViewModel(vastURL: vastURL, configuration: .default)
        var reported: [Bool] = []
        viewModel.onMuteChanged = { reported.append($0) }

        viewModel.toggleMute()
        viewModel.toggleMute()

        XCTAssertEqual(reported, [false, true])
        XCTAssertTrue(viewModel.isMuted)
    }

    func testFirstToggleStartsFromConfiguredDefault() {
        let configuration = VideoAdConfiguration(isMutedByDefault: false)
        let viewModel = VideoAdViewModel(vastURL: vastURL, configuration: configuration)
        var reported: [Bool] = []
        viewModel.onMuteChanged = { reported.append($0) }

        viewModel.toggleMute()

        XCTAssertEqual(reported, [true])
    }

    func testToggleMuteWithoutCallbackStillTogglesState() {
        let viewModel = VideoAdViewModel(vastURL: vastURL, configuration: .default)

        viewModel.toggleMute()

        XCTAssertFalse(viewModel.isMuted)
    }

    func testCallbackIsNotCalledWithoutUserToggle() {
        let viewModel = VideoAdViewModel(vastURL: vastURL, configuration: .default)
        var callCount = 0
        viewModel.onMuteChanged = { _ in callCount += 1 }

        XCTAssertEqual(callCount, 0)
        XCTAssertTrue(viewModel.isMuted)
    }
}
