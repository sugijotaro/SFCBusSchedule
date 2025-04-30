import Foundation

public enum BusDirection: String, Codable {
    case fromSFC = "from_sfc"
    case toSFC = "to_sfc"
}

public enum ScheduleDay: String {
    case weekday
    case saturday
    case sunday
}

public enum BusScheduleError: Error {
    case invalidURL
    case networkError(any Error)
    case decodingError(any Error)
}

public enum DataSource {
    case live
    case cache
}

public struct BusScheduleResponse {
    public let schedules: [BusSchedule]
    public let source: DataSource
}

public struct SFCBusScheduleAPI {
    static let cacheKeyPrefix = "sfc_bus_schedule_cache_"
    
    static func cacheKey(direction: BusDirection, day: ScheduleDay) -> String {
        return "\(cacheKeyPrefix)\(direction.rawValue)_\(day.rawValue)"
    }
    
    static func saveToCache(_ schedules: [BusSchedule], direction: BusDirection, day: ScheduleDay) {
        if let encoded = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(encoded, forKey: cacheKey(direction: direction, day: day))
        }
    }
    
    static func loadFromCache(direction: BusDirection, day: ScheduleDay) -> [BusSchedule]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(direction: direction, day: day)),
              let schedules = try? JSONDecoder().decode([BusSchedule].self, from: data) else {
            return nil
        }
        return schedules
    }

    public static func makeURL(direction: BusDirection, day: ScheduleDay) -> URL? {
        URL(string: "https://sugijotaro.github.io/sfc-bus-schedule/data/v1/flat/\(direction.rawValue)_\(day.rawValue).json")
    }

    public static func fetchSchedule(
        direction: BusDirection,
        day: ScheduleDay
    ) async throws -> BusScheduleResponse {
        guard let url = makeURL(direction: direction, day: day) else {
            throw BusScheduleError.invalidURL
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let schedules = try JSONDecoder().decode([BusSchedule].self, from: data)
            saveToCache(schedules, direction: direction, day: day)
            return BusScheduleResponse(schedules: schedules, source: .live)
        } catch let error as DecodingError {
            throw BusScheduleError.decodingError(error)
        } catch {
            if let cachedSchedules = loadFromCache(direction: direction, day: day) {
                return BusScheduleResponse(schedules: cachedSchedules, source: .cache)
            }
            throw BusScheduleError.networkError(error)
        }
    }
}
