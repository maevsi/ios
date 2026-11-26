import CoreLocation
import WebKit

// Before iOS 27 the app cannot answer WebKit's own per-site location prompt, which shows up after the system prompt.
// This script answers `navigator.geolocation` from CoreLocation instead, so the system prompt is the only one.
let geolocationScript = WKUserScript(source: """
(() => {
  const PERMISSION_DENIED = 1
  const POSITION_UNAVAILABLE = 2
  const TIMEOUT = 3
  const requests = new Map()
  let nextId = 1

  const post = (body) => window.webkit.messageHandlers.geolocation.postMessage(body)
  const fail = (request, code, message) =>
    request.error?.({ code, message, PERMISSION_DENIED, POSITION_UNAVAILABLE, TIMEOUT })

  // like in browsers, the timeout only runs once the permission is granted and restarts with every watched position
  const arm = (id, request) => {
    clearTimeout(request.timer)
    const timeout = request.options.timeout
    if (!(timeout >= 0) || timeout === Infinity) return
    request.timer = setTimeout(() => {
      if (!request.watch) {
        requests.delete(id)
        post({ id, type: 'clear' })
      }
      fail(request, TIMEOUT, 'Timeout expired')
    }, timeout)
  }

  const request = (watch, success, error, options) => {
    const id = nextId++
    requests.set(id, { error, options: options ?? {}, success, watch })
    post({
      highAccuracy: !!options?.enableHighAccuracy,
      id,
      maximumAge: options?.maximumAge ?? 0,
      type: watch ? 'watch' : 'get',
    })
    return id
  }

  Geolocation.prototype.getCurrentPosition = function (success, error, options) {
    request(false, success, error, options)
  }
  Geolocation.prototype.watchPosition = function (success, error, options) {
    return request(true, success, error, options)
  }
  Geolocation.prototype.clearWatch = function (id) {
    const request = requests.get(id)
    if (!request?.watch) return
    clearTimeout(request.timer)
    requests.delete(id)
    post({ id, type: 'clear' })
  }

  window.addEventListener('geolocation-result', ({ detail }) => {
    const { code, id, message, position, type } = JSON.parse(detail)
    const request = requests.get(id)
    if (!request) return

    if (type === 'start') {
      if (!request.started) {
        request.started = true
        arm(id, request)
      }
      return
    }

    if (!request.watch || code === PERMISSION_DENIED) {
      clearTimeout(request.timer)
      requests.delete(id)
    }
    if (type === 'position') {
      if (request.watch) arm(id, request)
      request.success(position)
    } else {
      fail(request, code, message)
    }
  })
})()
""", injectionTime: .atDocumentStart, forMainFrameOnly: true)

// Answers the requests of `geolocationScript` with the position from CoreLocation.
final class GeolocationBridge: NSObject, CLLocationManagerDelegate {
    private static let permissionDenied = 1
    private static let positionUnavailable = 2

    private let manager = CLLocationManager()
    private let dispatch: (String) -> Void
    private var getIds: Set<Int> = []
    private var watchIds: Set<Int> = []

    init(dispatch: @escaping (String) -> Void) {
        self.dispatch = dispatch
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func handle(_ body: Any) {
        guard let body = body as? [String: Any],
              let id = (body["id"] as? NSNumber)?.intValue,
              let type = body["type"] as? String else { return }

        switch type {
        case "clear":
            getIds.remove(id)
            watchIds.remove(id)
            if watchIds.isEmpty {
                manager.stopUpdatingLocation()
            }
        case "get", "watch":
            if type == "get",
               let maximumAge = (body["maximumAge"] as? NSNumber)?.doubleValue,
               maximumAge > 0,
               let location = manager.location,
               -location.timestamp.timeIntervalSinceNow * 1000 <= maximumAge {
                send(["id": id, "position": position(location), "type": "position"])
                return
            }
            if (body["highAccuracy"] as? Bool) == true {
                manager.desiredAccuracy = kCLLocationAccuracyBest
            }
            if type == "get" {
                getIds.insert(id)
            } else {
                watchIds.insert(id)
            }
            start()
        default:
            return
        }
    }

    private func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            for id in getIds.union(watchIds) {
                send(["id": id, "type": "start"])
            }
            if watchIds.isEmpty {
                manager.requestLocation()
            } else {
                manager.startUpdatingLocation()
            }
        default:
            fail(code: GeolocationBridge.permissionDenied, message: "User denied Geolocation")
        }
    }

    private func fail(code: Int, message: String) {
        for id in getIds {
            send(["code": code, "id": id, "message": message, "type": "error"])
        }
        getIds.removeAll()
        guard code == GeolocationBridge.permissionDenied else { return }
        for id in watchIds {
            send(["code": code, "id": id, "message": message, "type": "error"])
        }
        watchIds.removeAll()
        manager.stopUpdatingLocation()
    }

    private func position(_ location: CLLocation) -> [String: Any] {
        // CoreLocation marks unknown values as negative, the Geolocation API as `null`.
        func value(_ value: Double, if isKnown: Bool) -> Any { isKnown ? value : NSNull() }
        let hasAltitude = location.verticalAccuracy >= 0
        return [
            "coords": [
                "accuracy": location.horizontalAccuracy,
                "altitude": value(location.altitude, if: hasAltitude),
                "altitudeAccuracy": value(location.verticalAccuracy, if: hasAltitude),
                "heading": value(location.course, if: location.course >= 0),
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "speed": value(location.speed, if: location.speed >= 0),
            ],
            "timestamp": location.timestamp.timeIntervalSince1970 * 1000,
        ]
    }

    private func send(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        dispatch(json)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Also called once the delegate is set, when nothing may be waiting yet.
        guard manager.authorizationStatus != .notDetermined, !getIds.isEmpty || !watchIds.isEmpty else { return }
        start()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        for id in getIds.union(watchIds) {
            send(["id": id, "position": position(location), "type": "position"])
        }
        getIds.removeAll()
        if watchIds.isEmpty {
            manager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let code = (error as? CLError)?.code
        // While watching, CoreLocation keeps trying after a position is temporarily unknown.
        if code == .locationUnknown && !watchIds.isEmpty { return }
        if code == .denied {
            fail(code: GeolocationBridge.permissionDenied, message: "User denied Geolocation")
        } else {
            fail(code: GeolocationBridge.positionUnavailable, message: error.localizedDescription)
        }
    }
}
