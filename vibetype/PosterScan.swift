import UIKit
import VisionKit

// MARK: - Poster Scan Handlers
extension ViewController: VNDocumentCameraViewControllerDelegate {

    func handlePosterScan() {
        guard VNDocumentCameraViewController.isSupported else {
            dispatchEvent(eventName: "poster-scan-error", detail: "Document scanning is not supported on this device.")
            return
        }
        let documentCamera = VNDocumentCameraViewController()
        documentCamera.delegate = self
        present(documentCamera, animated: true)
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true)
        guard scan.pageCount > 0 else {
            dispatchEvent(eventName: "poster-scan-cancel", detail: "")
            return
        }
        let page = scan.imageOfPage(at: 0)
        // Encoding a full resolution scan takes long enough to stall the dismiss animation.
        DispatchQueue.global(qos: .userInitiated).async {
            let dataUrl = posterJpeg(page).map(jpegDataUrl)
            DispatchQueue.main.async {
                if let dataUrl {
                    self.dispatchEvent(eventName: "poster-scan-result", detail: dataUrl)
                } else {
                    self.dispatchEvent(eventName: "poster-scan-error", detail: "The scanned poster could not be encoded.")
                }
            }
        }
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
        dispatchEvent(eventName: "poster-scan-cancel", detail: "")
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true)
        dispatchEvent(eventName: "poster-scan-error", detail: error.localizedDescription)
    }
}

func jpegDataUrl(_ jpeg: Data) -> String {
    return "data:image/jpeg;base64," + jpeg.base64EncodedString()
}
