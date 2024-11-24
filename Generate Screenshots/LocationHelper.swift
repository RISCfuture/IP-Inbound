import CoreLocation

struct LocationHelper {
    private static let target = (36.772367, -115.453840)
    private static let preIP = (36.876930, -115.481479)
    private static let postIP = (36.80782, -115.484047)
    private static let altitude = 1502.0
    private static let course = 359.0 - 180.0
    private static let speed = 62.0

    static let IPBearingTrue = 359.0
    static let IPDistanceNM = 4.8
    static let targetGroundSpeed = 120

    static func targetLocation() -> CLLocation {
        .init(coordinate: .init(latitude: Self.target.0, longitude: Self.target.1),
              altitude: 1060,
              horizontalAccuracy: 1,
              verticalAccuracy: 1,
              course: 0,
              courseAccuracy: 1,
              speed: 0,
              speedAccuracy: 1,
              timestamp: Date())
    }

    static func preIPLocation() -> CLLocation {
        .init(coordinate: .init(latitude: Self.preIP.0, longitude: Self.preIP.1),
              altitude: Self.altitude,
              horizontalAccuracy: 1,
              verticalAccuracy: 1,
              course: Self.course,
              courseAccuracy: 1,
              speed: Self.speed,
              speedAccuracy: 1,
              timestamp: Date())
    }

    static func postIPLocation() -> CLLocation {
        .init(coordinate: .init(latitude: Self.postIP.0, longitude: Self.postIP.1),
              altitude: Self.altitude,
              horizontalAccuracy: 1,
              verticalAccuracy: 1,
              course: Self.course,
              courseAccuracy: 1,
              speed: Self.speed,
              speedAccuracy: 1,
              timestamp: Date())
    }

    static func groundLocation() -> CLLocation {
        .init(coordinate: .init(latitude: 36.2362000, longitude: -115.0342556),
              altitude: 570,
              horizontalAccuracy: 1,
              verticalAccuracy: 1,
              course: 29,
              courseAccuracy: 1,
              speed: 0,
              speedAccuracy: 1,
              timestamp: Date())
    }

    static func pickerComponents(minutesFromNow: Double) -> PickerComponents {
        let date = Date(timeIntervalSinceNow: minutesFromNow*60),
            components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return .init(components: components)!
    }
}

struct PickerComponents {
    let hour: String
    let minute: String
    let meridian: String

    init?(components: DateComponents) {
        guard let hour = components.hour,
              let minute = components.minute else { return nil }

        if hour > 12 {
            self.hour = String(hour - 12)
            meridian = "PM"
        } else if hour == 0 {
            self.hour = "12"
            meridian = "AM"
        } else {
            self.hour = String(hour)
            meridian = "AM"
        }

        self.minute = String(format: "%02d", minute)
    }
}
