import Testing
import Foundation
@testable import SFCBusSchedule

final class SFCBusScheduleTests {
    private let mockBusScheduleJSON = """
    [
      {
        "id": "sho250710",
        "time": 7,
        "minute": 10,
        "scheduleType": "weekday",
        "routeCode": "sho25",
        "routeName": "湘25",
        "name": "ツインライナー 急行・慶応大学行",
        "origin": "湘南台駅西口",
        "destination": "慶応中高等部前",
        "via": "ツインライナー急行・南大山",
        "sfc_direction": "to_sfc",
        "metadata": {
          "stops": [
            {
              "name": "湘南台駅西口",
              "cumulative_time": 0,
              "arrival": {
                "time": 7,
                "minute": 10
              }
            },
            {
              "name": "南大山",
              "cumulative_time": 5,
              "arrival": {
                "time": 7,
                "minute": 15
              }
            },
            {
              "name": "慶応大学",
              "cumulative_time": 9,
              "arrival": {
                "time": 7,
                "minute": 19
              }
            },
            {
              "name": "慶応大学本館前",
              "cumulative_time": 12,
              "arrival": {
                "time": 7,
                "minute": 22
              }
            },
            {
              "name": "慶応中高等部前",
              "cumulative_time": 15,
              "arrival": {
                "time": 7,
                "minute": 25
              }
            }
          ]
        }
      }
    ]
    """.data(using: .utf8)!

    @Test func testDecodeBusSchedule() async throws {
        let schedules = try JSONDecoder().decode([BusSchedule].self, from: mockBusScheduleJSON)
        #expect(schedules.count == 1)
        let schedule = schedules[0]
        #expect(schedule.id == "sho250710")
        #expect(schedule.time == 7)
        #expect(schedule.minute == 10)
        #expect(schedule.scheduleType == .weekday)
        #expect(schedule.routeCode == .sho25)
        #expect(schedule.routeName == "湘25")
        #expect(schedule.name == "ツインライナー 急行・慶応大学行")
        #expect(schedule.origin == "湘南台駅西口")
        #expect(schedule.destination == "慶応中高等部前")
        #expect(schedule.via == "ツインライナー急行・南大山")
        #expect(schedule.sfcDirection == .toSFC)
        #expect(schedule.metadata.stops.count == 5)
    }

    @Test func testMakeURL() {
        let url = SFCBusScheduleAPI.makeURL(direction: .fromSFC, day: .weekday)
        #expect(url?.absoluteString == "https://sugijotaro.github.io/sfc-bus-schedule/data/v1/flat/from_sfc_weekday.json")
    }

    @Test func testCacheKeyGeneration() {
        let key1 = SFCBusScheduleAPI.cacheKey(direction: .fromSFC, day: .weekday)
        let key2 = SFCBusScheduleAPI.cacheKey(direction: .toSFC, day: .saturday)
        
        #expect(key1 == "sfc_bus_schedule_cache_from_sfc_weekday")
        #expect(key2 == "sfc_bus_schedule_cache_to_sfc_saturday")
        #expect(key1 != key2)
    }

    @Test func testCacheSaveAndLoad() async throws {
        let testSchedules = try JSONDecoder().decode([BusSchedule].self, from: mockBusScheduleJSON)
        
        SFCBusScheduleAPI.saveToCache(testSchedules, direction: .toSFC, day: .weekday)
        
        let cachedSchedules = SFCBusScheduleAPI.loadFromCache(direction: .toSFC, day: .weekday)
        
        #expect(cachedSchedules != nil)
        #expect(cachedSchedules?.count == 1)
        #expect(cachedSchedules?[0].id == "sho250710")
        #expect(cachedSchedules?[0].routeCode == .sho25)
        #expect(cachedSchedules?[0].scheduleType == .weekday)
    }

    @Test func testCacheNotFound() {
        let nonExistentCache = SFCBusScheduleAPI.loadFromCache(direction: .fromSFC, day: .saturday)
        #expect(nonExistentCache == nil)
    }

    @Test func testBusScheduleResponse() {
        let schedules = try? JSONDecoder().decode([BusSchedule].self, from: mockBusScheduleJSON)
        #expect(schedules != nil)
        
        let liveResponse = BusScheduleResponse(schedules: schedules!, source: .live)
        let cacheResponse = BusScheduleResponse(schedules: schedules!, source: .cache)
        
        #expect(liveResponse.schedules.count == 1)
        #expect(cacheResponse.schedules.count == 1)
        #expect(liveResponse.source == .live)
        #expect(cacheResponse.source == .cache)
    }
}
