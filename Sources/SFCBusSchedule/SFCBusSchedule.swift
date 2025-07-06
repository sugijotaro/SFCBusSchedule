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

public enum DataSource: String, Codable {
    case live
    case cache
}

public struct BusScheduleResponse: Codable {
    public let schedules: [BusSchedule]
    public let source: DataSource
    public let specialInfo: SpecialScheduleInfo?
    
    public init(schedules: [BusSchedule], source: DataSource, specialInfo: SpecialScheduleInfo? = nil) {
        self.schedules = schedules
        self.source = source
        self.specialInfo = specialInfo
    }
}

public struct SFCBusScheduleAPI {
    private static let baseURL = "https://sugijotaro.github.io/sfc-bus-schedule/data/v1"
    private static let cacheKeyPrefix = "sfc_bus_schedule_cache_"
    
    private static func cacheKey(direction: BusDirection, type: BusScheduleType) -> String {
        return "\(cacheKeyPrefix)\(direction.rawValue)_\(type.pathComponent)"
    }
    
    private static func saveToCache(_ response: BusScheduleResponse, direction: BusDirection, type: BusScheduleType) {
        if let encoded = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(encoded, forKey: cacheKey(direction: direction, type: type))
        }
    }
    
    private static func loadFromCache(direction: BusDirection, type: BusScheduleType) -> BusScheduleResponse? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(direction: direction, type: type)),
              let response = try? JSONDecoder().decode(BusScheduleResponse.self, from: data) else {
            return nil
        }
        return response
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
    
    private static func fetchAndPackageSchedule(
        direction: BusDirection,
        type: BusScheduleType,
        specialInfo: SpecialScheduleInfo?
    ) async throws -> BusScheduleResponse {
        guard let url = makeURL(direction: direction, type: type) else {
            throw BusScheduleError.invalidURL
        }
        
        do {
            let schedules: [BusSchedule] = try await fetchData(from: url)
            let response = BusScheduleResponse(schedules: schedules, source: .live, specialInfo: specialInfo)
            saveToCache(response, direction: direction, type: type)
            return response
        } catch {
            if let cachedResponse = loadFromCache(direction: direction, type: type) {
                return cachedResponse
            }
            throw error
        }
    }
    
    public static func fetchSchedule(
        for date: Date,
        direction: BusDirection,
        calendar: Calendar = .current
    ) async throws -> BusScheduleResponse {
        // 1. 臨時ダイヤ情報を先に取得
        let allSpecialSchedules = try? await fetchSpecialSchedules()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let scheduleType: BusScheduleType
        let specialInfo: SpecialScheduleInfo?

        // 2. 指定日が臨時ダイヤに該当するかチェック
        if let info = allSpecialSchedules?.first(where: { $0.date == dateString }) {
            scheduleType = .special(info.type)
            specialInfo = info
        } else {
            // 3. 該当しない場合は曜日から通常ダイヤを判断
            let weekday = calendar.component(.weekday, from: date)
            let day: ScheduleDay
            switch weekday {
            case 1: day = .sunday
            case 7: day = .saturday
            default: day = .weekday
            }
            scheduleType = .regular(day)
            specialInfo = nil
        }
        
        // 4. 決定したダイヤ種別で時刻表を取得
        return try await fetchAndPackageSchedule(direction: direction, type: scheduleType, specialInfo: specialInfo)
    }
    
    @available(*, deprecated, message: "Use fetchSchedule(for:direction:) instead for automatic special schedule handling.")
    public static func fetchSchedule(
        direction: BusDirection,
        day: ScheduleDay
    ) async throws -> BusScheduleResponse {
        return try await fetchAndPackageSchedule(direction: direction, type: .regular(day), specialInfo: nil)
    }
}
