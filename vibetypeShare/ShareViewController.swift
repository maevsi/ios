import ImageIO
import UIKit
import UniformTypeIdentifiers

// Share extensions cannot open their app, so this one leaves the poster in the App Group container for the app's next launch or foreground and only confirms briefly.
final class ShareViewController: UIViewController {

    private let messageLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        messageLabel.font = .preferredFont(forTextStyle: .headline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        let provider = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] }
            .first { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        guard let provider else {
            finish(saved: false)
            return
        }

        provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
            // The file is deleted once this handler returns, so it has to be read right here.
            var saved = false
            if let url, let image = downsampledImage(at: url), let jpeg = posterJpeg(image), let destination = sharedPosterUrl() {
                saved = (try? jpeg.write(to: destination, options: .atomic)) != nil
            }
            DispatchQueue.main.async {
                self.finish(saved: saved)
            }
        }
    }

    private func finish(saved: Bool) {
        messageLabel.text = saved
            ? NSLocalizedString("Open Vibetype to read the poster.", comment: "Shown after a poster image was handed to the app")
            : NSLocalizedString("The image could not be shared.", comment: "Shown when the shared image could not be read or saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}

// Decoding a full resolution photo as `UIImage` can exceed the extension's memory limit, so ImageIO scales it while decoding.
private func downsampledImage(at url: URL, maxPixels: Int = 2048) -> UIImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixels,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    return UIImage(cgImage: image)
}
