import SwiftUI
import UIKit

/// Loads a logo from URL with a browser User-Agent so CDNs (e.g. ESPN) serve the image.
/// Use this instead of AsyncImage for team logos so requests are not blocked.
struct LogoImageView: View {
    let url: URL
    let fallbackText: String
    let size: CGFloat
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.8, height: size * 0.8)
                    .clipShape(Circle())
            } else if failed {
                Text(fallbackText)
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundColor(.white)
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.7)
            }
        }
        .task(id: url) {
            await MainActor.run { image = nil; failed = false }
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let uiImage = UIImage(data: data) {
                    image = uiImage
                } else {
                    failed = true
                }
            } catch {
                failed = true
            }
        }
    }
}
