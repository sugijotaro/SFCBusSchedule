import Foundation

public enum ScheduleType: Codable, Hashable {
    case weekday
    case saturday
    case sunday
    case special(String)
    case unknown
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "weekday": self = .weekday
        case "saturday": self = .saturday
        case "sunday": self = .sunday
        default:
            if rawValue.starts(with: "special_") {
                self = .special(rawValue)
            } else {
                self = .unknown
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
    
    public var stringValue: String {
        switch self {
        case .weekday: return "weekday"
        case .saturday: return "saturday"
        case .sunday: return "sunday"
        case .special(let type): return type
        case .unknown: return "unknown"
        }
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
    public let sfcDirection: BusDirection
    public let metadata: Metadata
    
    enum CodingKeys: String, CodingKey {
        case id
        case time
        case minute
        case scheduleType
        case routeCode
        case routeName
        case name
        case origin
        case destination
        case via
        case sfcDirection = "sfc_direction"
        case metadata
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        time = try container.decode(Int.self, forKey: .time)
        minute = try container.decode(Int.self, forKey: .minute)
        scheduleType = try container.decode(ScheduleType.self, forKey: .scheduleType)
        routeCode = try container.decode(RouteCode.self, forKey: .routeCode)
        routeName = try container.decode(String.self, forKey: .routeName)
        name = try container.decode(String.self, forKey: .name)
        origin = try container.decode(String.self, forKey: .origin)
        destination = try container.decode(String.self, forKey: .destination)
        via = try container.decode(String.self, forKey: .via)
        sfcDirection = try container.decode(BusDirection.self, forKey: .sfcDirection)
        metadata = try container.decode(Metadata.self, forKey: .metadata)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(time, forKey: .time)
        try container.encode(minute, forKey: .minute)
        try container.encode(scheduleType, forKey: .scheduleType)
        try container.encode(routeCode, forKey: .routeCode)
        try container.encode(routeName, forKey: .routeName)
        try container.encode(name, forKey: .name)
        try container.encode(origin, forKey: .origin)
        try container.encode(destination, forKey: .destination)
        try container.encode(via, forKey: .via)
        try container.encode(sfcDirection, forKey: .sfcDirection)
        try container.encode(metadata, forKey: .metadata)
    }
    
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
        sfcDirection: BusDirection,
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
        self.sfcDirection = sfcDirection
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

public struct SpecialScheduleInfo: Codable, Identifiable, Hashable {
    public var id: String { date }
    public let date: String
    public let description: String
    public let type: String
    
    public init(date: String, description: String, type: String) {
        self.date = date
        self.description = description
        self.type = type
    }
}

extension BusSchedule {
    public func departureDate(basedOn referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = self.time
        components.minute = self.minute
        components.second = 0
        return calendar.date(from: components)
    }
}
