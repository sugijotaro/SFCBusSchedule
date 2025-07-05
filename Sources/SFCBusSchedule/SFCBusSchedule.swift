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

public enum BusScheduleType {
    case regular(ScheduleDay)
    case special(String)
    
    var pathComponent: String {
        switch self {
        case .regular(let day): return day.rawValue
        case .special(let type): return type
        }
    }
}

public enum BusScheduleError: Error {
    case invalidURL
    case networkError(any Error)
    case decodingError(any Error)
    case noScheduleForDate
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
    private static let baseURL = "https://sugijotaro.github.io/sfc-bus-schedule/data/v1"
    private static let cacheKeyPrefix = "sfc_bus_schedule_cache_"
    
    private static func cacheKey(direction: BusDirection, type: BusScheduleType) -> String {
        return "\(cacheKeyPrefix)\(direction.rawValue)_\(type.pathComponent)"
    }
    
    private static func saveToCache(_ schedules: [BusSchedule], direction: BusDirection, type: BusScheduleType) {
        if let encoded = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(encoded, forKey: cacheKey(direction: direction, type: type))
        }
    }
    
    private static func loadFromCache(direction: BusDirection, type: BusScheduleType) -> [BusSchedule]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(direction: direction, type: type)),
              let schedules = try? JSONDecoder().decode([BusSchedule].self, from: data) else {
            return nil
        }
        return schedules
    }

    public static func makeURL(direction: BusDirection, type: BusScheduleType) -> URL? {
        URL(string: "\(baseURL)/flat/\(direction.rawValue)_\(type.pathComponent).json")
    }
    
    public static func makeSpecialSchedulesURL() -> URL? {
        URL(string: "\(baseURL)/special_schedules.json")
    }

    private static func fetchData<T: Decodable>(from url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw BusScheduleError.decodingError(error)
        } catch {
            throw BusScheduleError.networkError(error)
        }
    }

    public static func fetchSpecialSchedules() async throws -> [SpecialScheduleInfo] {
        guard let url = makeSpecialSchedulesURL() else {
            throw BusScheduleError.invalidURL
        }
        return try await fetchData(from: url)
    }

    public static func fetchSchedule(
        direction: BusDirection,
        type: BusScheduleType
    ) async throws -> BusScheduleResponse {
        guard let url = makeURL(direction: direction, type: type) else {
            throw BusScheduleError.invalidURL
        }
        
        do {
            let schedules: [BusSchedule] = try await fetchData(from: url)
            saveToCache(schedules, direction: direction, type: type)
            return BusScheduleResponse(schedules: schedules, source: .live)
        } catch {
            if let cachedSchedules = loadFromCache(direction: direction, type: type) {
                return BusScheduleResponse(schedules: cachedSchedules, source: .cache)
            }
            throw error
        }
    }
    
    public static func fetchSchedule(
        for date: Date,
        direction: BusDirection,
        calendar: Calendar = .current
    ) async throws -> BusScheduleResponse {
        let specialSchedules = try? await fetchSpecialSchedules()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        if let specialInfo = specialSchedules?.first(where: { $0.date == dateString }) {
            return try await fetchSchedule(direction: direction, type: .special(specialInfo.type))
        } else {
            let weekday = calendar.component(.weekday, from: date)
            let scheduleDay: ScheduleDay
            switch weekday {
            case 1: scheduleDay = .sunday
            case 7: scheduleDay = .saturday
            default: scheduleDay = .weekday
            }
            return try await fetchSchedule(direction: direction, type: .regular(scheduleDay))
        }
    }
    
    @available(*, deprecated, message: "Use fetchSchedule(for:direction:) instead for automatic special schedule handling.")
    public static func fetchSchedule(
        direction: BusDirection,
        day: ScheduleDay
    ) async throws -> BusScheduleResponse {
        return try await fetchSchedule(direction: direction, type: .regular(day))
    }
}
