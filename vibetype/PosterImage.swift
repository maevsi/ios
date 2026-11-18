import UIKit

// Where the share extension leaves a poster for the app, which picks it up on its next launch or foreground.
func sharedPosterUrl() -> URL? {
    return FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.si.maev.twa")?
        .appendingPathComponent("poster-shared.jpg")
}

// Downscales the image to at most `maxPixels` on its long edge and encodes it as JPEG.
func posterJpeg(_ image: UIImage, maxPixels: CGFloat = 2048) -> Data? {
    let pixelWidth = image.size.width * image.scale
    let pixelHeight = image.size.height * image.scale
    guard pixelWidth > 0, pixelHeight > 0 else { return nil }

    let factor = min(1, maxPixels / max(pixelWidth, pixelHeight))
    let size = CGSize(width: (pixelWidth * factor).rounded(), height: (pixelHeight * factor).rounded())
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
        image.draw(in: CGRect(origin: .zero, size: size))
    }

    return resized.jpegData(compressionQuality: 0.8)
}
