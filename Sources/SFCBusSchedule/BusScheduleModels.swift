import Foundation

public enum ScheduleType: String, Codable {
    case weekday
    case saturday
    case sunday
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ScheduleType(rawValue: rawValue) ?? .unknown
    }
}

public enum RouteCode: String, Codable {
    case sho19 = "sho19"
    case sho23 = "sho23"
    case sho24 = "sho24"
    case sho25 = "sho25"
    case sho28 = "sho28"
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = RouteCode(rawValue: rawValue) ?? .unknown
    }
}

public struct BusSchedule: Codable, Identifiable {
    public let id: String
    public let time: Int
    public let minute: Int
    public let scheduleType: ScheduleType
    public let routeCode: RouteCode
    public let routeName: String
    public let name: String
    public let origin: String
    public let destination: String
    public let via: String
    public let metadata: Metadata

    public init(
        id: String,
        time: Int,
        minute: Int,
        scheduleType: ScheduleType,
        routeCode: RouteCode,
        routeName: String,
        name: String,
        origin: String,
        destination: String,
        via: String,
        metadata: Metadata
    ) {
        self.id = id
        self.time = time
        self.minute = minute
        self.scheduleType = scheduleType
        self.routeCode = routeCode
        self.routeName = routeName
        self.name = name
        self.origin = origin
        self.destination = destination
        self.via = via
        self.metadata = metadata
    }
}

public struct Metadata: Codable {
    public let stops: [Stop]

    public init(stops: [Stop]) {
        self.stops = stops
    }
}

public struct Stop: Codable {
    public let name: String
    public let cumulativeTime: Int
    public let arrival: Arrival

    enum CodingKeys: String, CodingKey {
        case name
        case cumulativeTime = "cumulative_time"
        case arrival
    }

    public init(name: String, cumulativeTime: Int, arrival: Arrival) {
        self.name = name
        self.cumulativeTime = cumulativeTime
        self.arrival = arrival
    }
}

public struct Arrival: Codable {
    public let time: Int
    public let minute: Int

    public init(time: Int, minute: Int) {
        self.time = time
        self.minute = minute
    }
} 