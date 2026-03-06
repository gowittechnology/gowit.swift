import SwiftUI

// MARK: - Shimmer View

/// A loading shimmer effect view
struct ShimmerView: View {
    @State private var startPoint: UnitPoint = .init(x: -1.8, y: -1.2)
    @State private var endPoint: UnitPoint = .init(x: 0, y: -0.2)

    private let gradientColors = [
        Color.gray.opacity(0.2),
        Color.gray.opacity(0.4),
        Color.gray.opacity(0.5),
        Color.gray.opacity(0.4),
        Color.gray.opacity(0.2)
    ]

    var body: some View {
        ZStack {
            // Base background
            Color.gray.opacity(0.15)

            // Shimmer gradient overlay
            LinearGradient(
                colors: gradientColors,
                startPoint: startPoint,
                endPoint: endPoint
            )
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                startPoint = .init(x: 1, y: 1)
                endPoint = .init(x: 2.2, y: 2.2)
            }
        }
    }
}
