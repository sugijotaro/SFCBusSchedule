import Testing
import Foundation
@testable import SFCBusSchedule

@Suite("SFCBusSchedule Tests")
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
    
    @Test func testDecodeSpecialScheduleType() throws {
        let specialJson = """
        "special_20250705"
        """.data(using: .utf8)!
        
        let specialType = try JSONDecoder().decode(ScheduleType.self, from: specialJson)
        #expect(specialType == .special("special_20250705"))
        
        let encodedData = try JSONEncoder().encode(specialType)
        let encodedString = String(data: encodedData, encoding: .utf8)
        #expect(encodedString == "\"special_20250705\"")
        
        let weekdayType = ScheduleType.weekday
        let encodedWeekdayData = try JSONEncoder().encode(weekdayType)
        let encodedWeekdayString = String(data: encodedWeekdayData, encoding: .utf8)
        #expect(encodedWeekdayString == "\"weekday\"")
    }
    
    @Test func testDecodeSpecialScheduleInfo() throws {
        let mockInfoJSON = """
        [
            {
                "date": "2025-07-05",
                "description": "七夕祭臨時ダイヤ",
                "type": "special_20250705"
            }
        ]
        """.data(using: .utf8)!
        
        let info = try JSONDecoder().decode([SpecialScheduleInfo].self, from: mockInfoJSON)
        #expect(info.count == 1)
        #expect(info[0].date == "2025-07-05")
        #expect(info[0].type == "special_20250705")
    }
    
    @Test func testMakeURL() {
        let regularURL = SFCBusScheduleAPI.makeURL(direction: .fromSFC, type: .regular(.weekday))
        #expect(regularURL?.absoluteString == "https://sugijotaro.github.io/sfc-bus-schedule/data/v1/flat/from_sfc_weekday.json")
        
        let specialURL = SFCBusScheduleAPI.makeURL(direction: .toSFC, type: .special("special_20250705"))
        #expect(specialURL?.absoluteString == "https://sugijotaro.github.io/sfc-bus-schedule/data/v1/special/special_20250705/to_sfc.json")
        
        let metaURL = SFCBusScheduleAPI.makeSpecialSchedulesURL()
        #expect(metaURL?.absoluteString == "https://sugijotaro.github.io/sfc-bus-schedule/data/v1/special_schedules.json")
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
        #expect(liveResponse.specialInfo == nil)
        #expect(cacheResponse.specialInfo == nil)
    }
    
    @Test func testDepartureDateBasedOn() throws {
        let schedules = try JSONDecoder().decode([BusSchedule].self, from: mockBusScheduleJSON)
        let schedule = schedules[0]
        
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = 2025
        dateComponents.month = 7
        dateComponents.day = 5
        let baseDate = calendar.date(from: dateComponents)!
        
        let departureDate = schedule.departureDate(basedOn: baseDate)
        #expect(departureDate != nil)
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: departureDate!)
        #expect(components.year == 2025)
        #expect(components.month == 7)
        #expect(components.day == 5)
        #expect(components.hour == 7)
        #expect(components.minute == 10)
    }
    
    @Test func testBusScheduleResponseWithSpecialInfo() {
        let schedules = try? JSONDecoder().decode([BusSchedule].self, from: mockBusScheduleJSON)
        #expect(schedules != nil)
        
        let specialInfo = SpecialScheduleInfo(date: "2025-07-05", description: "テスト臨時ダイヤ", type: "special_20250705")
        let responseWithSpecial = BusScheduleResponse(schedules: schedules!, source: .live, specialInfo: specialInfo)
        
        #expect(responseWithSpecial.schedules.count == 1)
        #expect(responseWithSpecial.source == .live)
        #expect(responseWithSpecial.specialInfo != nil)
        #expect(responseWithSpecial.specialInfo?.date == "2025-07-05")
        #expect(responseWithSpecial.specialInfo?.description == "テスト臨時ダイヤ")
        #expect(responseWithSpecial.specialInfo?.type == "special_20250705")
    }
}
