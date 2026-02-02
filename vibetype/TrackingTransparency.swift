import Foundation
import AppTrackingTransparency
import AdSupport

@available(iOS 14, *)
class TrackingTransparencyManager {

    // Request ATT permission and return the result via callback
    static func requestPermission(completion: @escaping (ATTrackingManager.AuthorizationStatus) -> Void) {
        ATTrackingManager.requestTrackingAuthorization { status in
            DispatchQueue.main.async {
                completion(status)
            }
        }
    }

    // Get current tracking authorization status
    static func getStatus() -> ATTrackingManager.AuthorizationStatus {
        return ATTrackingManager.trackingAuthorizationStatus
    }

    // Get status as a string representation for JavaScript
    static func getStatusString() -> String {
        let status = getStatus()
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        @unknown default:
            return "unknown"
        }
    }

    // Convert status to string
    static func statusToString(_ status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        @unknown default:
            return "unknown"
        }
    }

    // Get IDFA (Identifier for Advertisers) if authorized
    static func getIDFA() -> String? {
        guard getStatus() == .authorized else {
            return nil
        }

        let idfa = ASIdentifierManager.shared().advertisingIdentifier
        return idfa.uuidString
    }
}
