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
        #expect(schedule.scheduleType == "weekday")
        #expect(schedule.routeCode == "sho25")
        #expect(schedule.routeName == "湘25")
        #expect(schedule.name == "ツインライナー 急行・慶応大学行")
        #expect(schedule.origin == "湘南台駅西口")
        #expect(schedule.destination == "慶応中高等部前")
        #expect(schedule.via == "ツインライナー急行・南大山")
        #expect(schedule.metadata.stops.count == 5)
    }

    @Test func testMakeURL() {
        let url = SFCBusScheduleAPI.makeURL(direction: .fromSFC, day: .weekday)
        #expect(url?.absoluteString == "https://sugijotaro.github.io/sfc-bus-schedule/data/v1/flat/from_sfc_weekday.json")
    }
}
