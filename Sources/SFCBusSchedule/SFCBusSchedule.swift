import Foundation

public enum BusDirection: String {
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

public struct SFCBusScheduleAPI {
    public static func makeURL(direction: BusDirection, day: ScheduleDay) -> URL? {
        URL(string: "https://sugijotaro.github.io/sfc-bus-schedule/data/v1/flat/\(direction.rawValue)_\(day.rawValue).json")
    }

    public static func fetchSchedule(
        direction: BusDirection,
        day: ScheduleDay
    ) async throws -> [BusSchedule] {
        guard let url = makeURL(direction: direction, day: day) else {
            throw BusScheduleError.invalidURL
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let schedules = try JSONDecoder().decode([BusSchedule].self, from: data)
            return schedules
        } catch let error as DecodingError {
            throw BusScheduleError.decodingError(error)
        } catch {
            throw BusScheduleError.networkError(error)
        }
    }
}
