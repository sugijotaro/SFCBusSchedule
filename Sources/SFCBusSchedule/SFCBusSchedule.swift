import Foundation

private func log(_ message: String) {
#if DEBUG
    let timestamp = Date().formatted(
        .dateTime
            .hour(.twoDigits(amPM: .abbreviated))
            .minute(.twoDigits)
            .second(.twoDigits)
            .secondFraction(.fractional(3))
    )
    print("[\(timestamp)] \(message)")
#endif
}

public struct SFCBusScheduleAPI {
    private static let baseURL = "https://sugijotaro.github.io/sfc-bus-schedule/data/v1"
    private static let cacheKeyPrefix = "sfc_bus_schedule_cache_"

    private static func cacheFileURL(direction: BusDirection, type: BusScheduleType) -> URL? {
        guard let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileName = "\(cacheKeyPrefix)\(direction.rawValue)_\(type.pathComponent).json"
        return cacheDirectory.appendingPathComponent(fileName)
    }

    private static func saveToCache(_ response: BusScheduleResponse, direction: BusDirection, type: BusScheduleType) {
        guard let fileURL = cacheFileURL(direction: direction, type: type) else { return }

        log("🚌 キャッシュを保存します... Path: \(fileURL.lastPathComponent)")

        let directoryURL = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }

        if let encoded = try? JSONEncoder().encode(response) {
            try? encoded.write(to: fileURL)
            log("✅ キャッシュの保存に成功しました。")
        } else {
            log("🛑 キャッシュのエンコードまたは書き込みに失敗しました。")
        }
    }

    private static func loadFromCache(direction: BusDirection, type: BusScheduleType) -> BusScheduleResponse? {
        guard let fileURL = cacheFileURL(direction: direction, type: type) else {
            log("⚠️ キャッシュファイルのURLが取得できませんでした。")
            return nil
        }
        log("🔍 キャッシュを探しています... Path: \(fileURL.lastPathComponent)")

        guard let data = try? Data(contentsOf: fileURL) else {
            log("ℹ️ キャッシュが見つかりませんでした。")
            return nil
        }

        if var response = try? JSONDecoder().decode(BusScheduleResponse.self, from: data) {
            response.source = .cache
            log("✅ キャッシュが見つかりました。まずこれを表示します。")
            return response
        }
        log("🛑 キャッシュのデコードに失敗しました。")
        return nil
    }

    public static func makeURL(direction: BusDirection, type: BusScheduleType) -> URL? {
        switch type {
        case .special(let specialType):
            // specialの場合: /special/{type}/{direction}.json
            return URL(string: "\(baseURL)/special/\(specialType)/\(direction.rawValue).json")
        case .regular:
            // regularの場合: /flat/{direction}_{type}.json
            return URL(string: "\(baseURL)/flat/\(direction.rawValue)_\(type.pathComponent).json")
        }
    }

    public static func makeSpecialSchedulesURL() -> URL? {
        URL(string: "\(baseURL)/special_schedules.json")
    }

    private static func fetchData<T: Decodable>(from url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        log("📡 ネットワークリクエストを開始します: \(url.absoluteString)")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            log("✅ ネットワークリクエスト成功。")
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            log("🛑 ネットワークデータのデコードに失敗: \(error)")
            throw BusScheduleError.decodingError(error)
        } catch {
            log("🛑 ネットワークエラー: \(error)")
            throw BusScheduleError.networkError(error)
        }
    }

    public static func fetchSpecialSchedules() async throws -> [SpecialScheduleInfo] {
        guard let url = makeSpecialSchedulesURL() else {
            throw BusScheduleError.invalidURL
        }
        return try await fetchData(from: url)
    }

    public static func scheduleStream(
        for date: Date,
        direction: BusDirection,
        calendar: Calendar = .current
    ) -> AsyncThrowingStream<BusScheduleResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                log("🚌 時刻表データストリーム処理を開始します。Direction: \(direction.rawValue)")

                // --- 高速化のための修正 ---
                // 1. まず考えられるキャッシュを先に探し、あれば即座に表示する
                let todayWeekday = calendar.component(.weekday, from: date)
                let potentialScheduleDays: [ScheduleDay] = [.weekday, .saturday, .sunday]
                // 今日の曜日を優先的に探すように順序を調整
                let sortedPotentialDays = potentialScheduleDays.sorted { a, b in
                    let aIsToday = (a == .weekday && (2...6).contains(todayWeekday)) || (a == .saturday && todayWeekday == 7) || (a == .sunday && todayWeekday == 1)
                    let bIsToday = (b == .weekday && (2...6).contains(todayWeekday)) || (b == .saturday && todayWeekday == 7) || (b == .sunday && todayWeekday == 1)
                    return aIsToday && !bIsToday
                }

                var yieldedInitialCache = false
                for day in sortedPotentialDays {
                    if let cachedResponse = loadFromCache(direction: direction, type: .regular(day)) {
                        continuation.yield(cachedResponse)
                        yieldedInitialCache = true
                        log("✅ 仮のキャッシュデータを表示しました: \(day)")
                        break // 最初のキャッシュを見つけたらループを抜ける
                    }
                }

                // 2. その後、ネットワークで正確なダイヤ情報を確認する
                let allSpecialSchedules = try? await fetchSpecialSchedules()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: date)

                let scheduleType: BusScheduleType
                let specialInfo: SpecialScheduleInfo?

                if let info = allSpecialSchedules?.first(where: { $0.date == dateString }) {
                    scheduleType = .special(info.type)
                    specialInfo = info
                } else {
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

                // キャッシュがまだ一つも表示されていない場合のみ、改めてキャッシュを探す
                if !yieldedInitialCache {
                    if let cachedResponse = loadFromCache(direction: direction, type: scheduleType) {
                        continuation.yield(cachedResponse)
                    } else {
                        log("ℹ️ 表示できるキャッシュがないため、ネットワーク取得を待ちます。")
                    }
                }

                do {
                    guard let url = makeURL(direction: direction, type: scheduleType) else {
                        throw BusScheduleError.invalidURL
                    }

                    let schedules: [BusSchedule] = try await fetchData(from: url)
                    var liveResponse = BusScheduleResponse(schedules: schedules, source: .live, specialInfo: specialInfo)

                    log("🔄 ネットワークから取得した最新データでUIを更新します。")
                    continuation.yield(liveResponse)

                    // liveResponseのsourceをcacheに変更して保存する
                    liveResponse.source = .cache
                    saveToCache(liveResponse, direction: direction, type: scheduleType)

                    continuation.finish()
                    log("✅ ストリーム処理が正常に完了しました。")

                } catch {
                    log("🛑 ストリーム処理中にエラーが発生しました: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
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

    @available(*, deprecated, message: "Use scheduleStream(for:direction:) instead.")
    public static func fetchSchedule(
        for date: Date,
        direction: BusDirection,
        calendar: Calendar = .current
    ) async throws -> BusScheduleResponse {
        for try await response in scheduleStream(for: date, direction: direction, calendar: calendar) {
            return response
        }
        throw BusScheduleError.noScheduleForDate
    }

    @available(*, deprecated, message: "Use fetchSchedule(for:direction:) instead for automatic special schedule handling.")
    public static func fetchSchedule(
        direction: BusDirection,
        day: ScheduleDay
    ) async throws -> BusScheduleResponse {
        return try await fetchAndPackageSchedule(direction: direction, type: .regular(day), specialInfo: nil)
    }
}
