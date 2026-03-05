import Foundation
import Flutter
import MapboxMaps
import MapboxCommon
import CoreLocation
import Combine
import UIKit

final class MockLocationApiImpl: NSObject {
    private let channel: FlutterMethodChannel
    private weak var mapView: MapView?

    private let locationSubject: CurrentValueSubject<[MapboxCommon.Location], Never>
    private let headingSubject: CurrentValueSubject<MapboxMaps.Heading, Never>

    init(mapView: MapView, messenger: FlutterBinaryMessenger, channelName: String = "mock_location_channel") {
        self.mapView = mapView
        self.channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

        let startCoord = mapView.mapboxMap.cameraState.center
        let startLoc = MapboxCommon.Location(
            coordinate: startCoord,
            timestamp: Date(),
            altitude: 0,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
            bearing: 0,
            bearingAccuracy: 0,
            floor: nil,
            source: nil,
            extra: nil
        )

        self.locationSubject = CurrentValueSubject<[MapboxCommon.Location], Never>([startLoc])
        self.headingSubject = CurrentValueSubject<MapboxMaps.Heading, Never>(
            MapboxMaps.Heading(direction: 0, accuracy: 0, timestamp: Date())
        )

        super.init()

        mapView.location.override(
            locationProvider: locationSubject.eraseToSignal(),
            headingProvider: headingSubject.eraseToSignal()
        )

        let config = Puck2DConfiguration.makeDefault(showBearing: true)
        mapView.location.options.puckType = .puck2D(config)

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setMockLocation":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments missing", details: nil))
                return
            }

            guard let lat = args["latitude"] as? Double,
                  let lon = args["longitude"] as? Double else {
                result(FlutterError(code: "MISSING", message: "latitude/longitude missing", details: nil))
                return
            }

            let bearing = args["bearing"] as? Double
            let durationMs = (args["duration"] as? NSNumber)?.intValue ?? 1000
            let cameraMap = args["cameraOptions"] as? [String: Any]

            setMockLocation(
                latitude: lat,
                longitude: lon,
                bearing: bearing,
                durationMs: durationMs,
                cameraOptions: cameraMap.flatMap(parseCameraOptions)
            )

            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setMockLocation(
        latitude: Double,
        longitude: Double,
        bearing: Double?,
        durationMs: Int,
        cameraOptions: MapboxMaps.CameraOptions?
    ) {
        guard let mapView else { return }

        let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        let loc = MapboxCommon.Location(
            coordinate: coord,
            timestamp: Date(),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            speed: 0,
            speedAccuracy: 0,
            bearing: bearing ?? 0,
            bearingAccuracy: 0,
            floor: nil,
            source: nil,
            extra: nil
        )

        locationSubject.send([loc])

        if let b = bearing {
            headingSubject.send(MapboxMaps.Heading(direction: b, accuracy: 0, timestamp: Date()))
        }

        if let cam = cameraOptions {
            let durationSec = TimeInterval(durationMs) / 1000.0
            mapView.camera.fly(to: cam, duration: durationSec, completion: nil)
        }
    }

    private func parseCameraOptions(_ map: [String: Any]) -> MapboxMaps.CameraOptions {
        var center: CLLocationCoordinate2D?
        if let centerMap = map["center"] as? [String: Any],
           let lat = (centerMap["latitude"] as? NSNumber)?.doubleValue,
           let lon = (centerMap["longitude"] as? NSNumber)?.doubleValue {
            center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        var padding: UIEdgeInsets?
        if let paddingMap = map["padding"] as? [String: Any] {
            let top = CGFloat((paddingMap["top"] as? NSNumber)?.doubleValue ?? 0)
            let left = CGFloat((paddingMap["left"] as? NSNumber)?.doubleValue ?? 0)
            let bottom = CGFloat((paddingMap["bottom"] as? NSNumber)?.doubleValue ?? 0)
            let right = CGFloat((paddingMap["right"] as? NSNumber)?.doubleValue ?? 0)
            padding = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        }

        let zoom = (map["zoom"] as? NSNumber).map { CGFloat($0.doubleValue) }
        let bearing = (map["bearing"] as? NSNumber)?.doubleValue
        let pitch = (map["pitch"] as? NSNumber).map { CGFloat($0.doubleValue) }

        return MapboxMaps.CameraOptions(
            center: center,
            padding: padding,
            anchor: nil,
            zoom: zoom,
            bearing: bearing,
            pitch: pitch
        )
    }

    func dispose() {
        channel.setMethodCallHandler(nil)
        mapView = nil
    }
}
