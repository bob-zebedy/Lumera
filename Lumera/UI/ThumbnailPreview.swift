import SwiftUI

struct ThumbnailPreview: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.6), lineWidth: 1)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel("Latest photo")
    }
}
