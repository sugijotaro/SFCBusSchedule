import Foundation

public struct BusSchedule: Codable, Identifiable {
    public let id: String
    public let time: Int
    public let minute: Int
    public let scheduleType: String
    public let routeCode: String
    public let routeName: String
    public let name: String
    public let origin: String
    public let destination: String
    public let via: String
    public let metadata: Metadata
}

public struct Metadata: Codable {
    public let stops: [Stop]
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
}

public struct Arrival: Codable {
    public let time: Int
    public let minute: Int
} 