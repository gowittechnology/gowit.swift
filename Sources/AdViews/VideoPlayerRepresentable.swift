import SwiftUI
import AVFoundation
import AVKit

// MARK: - Video Player Representable

struct VideoPlayerRepresentable: UIViewRepresentable {
    let player: AVPlayer?
    let videoGravity: AVLayerVideoGravity

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.videoGravity = videoGravity
        if let player = player {
            view.player = player
        }
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        // Only update if the player has changed
        if uiView.playerLayer.player !== player {
            uiView.player = player
            // Force a layout update to ensure the video layer displays correctly
            uiView.setNeedsLayout()
            uiView.layoutIfNeeded()
        }
    }
}

// MARK: - Player UI View

class PlayerUIView: UIView {
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        guard let layer = layer as? AVPlayerLayer else {
            fatalError("Expected AVPlayerLayer but got \(type(of: layer))")
        }
        return layer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            // Ensure the layer is visible and properly configured
            playerLayer.isHidden = false
        }
    }

    var videoGravity: AVLayerVideoGravity {
        get { playerLayer.videoGravity }
        set { playerLayer.videoGravity = newValue }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure the player layer fills the entire view
        playerLayer.frame = bounds
    }
}
