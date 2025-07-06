# SFCBusSchedule

SFCBusScheduleは、慶應義塾大学湘南藤沢キャンパス（SFC）のバス時刻表を簡単に取得できるSwiftライブラリです。

## 機能

- バス時刻表の取得（行き／帰り、平日／土曜日／日曜日）
- 臨時ダイヤの自動判定と取得
- Codableに準拠したデータモデル
- 非同期データ取得（async/await）
- エラーハンドリング
- キャッシュ機能

## データソース

このライブラリは、[sugijotaro/sfc-bus-schedule](https://github.com/sugijotaro/sfc-bus-schedule) リポジトリで管理されているJSONデータを使用しています。

バス時刻表の更新や詳細な情報については、上記リポジトリを参照してください。

## インストール

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/sugijotaro/SFCBusSchedule.git", from: "1.0.0")
]
```

## 使用方法

### 日付を指定して時刻表を取得（推奨）
指定した日付の時刻表を取得します。ライブラリが自動で臨時ダイヤの有無を判断し、臨時ダイヤ情報を含んだレスポンスを返します。

```swift
import SFCBusSchedule
import Foundation

do {
    // 今日の日付のSFC行きバス時刻表を取得
    let response = try await SFCBusScheduleAPI.fetchSchedule(
        for: Date(), 
        direction: .toSFC
    )

    // 臨時ダイヤ情報をチェック
    if let specialInfo = response.specialInfo {
        print("本日は臨時ダイヤです: \(specialInfo.description)")
    }

    // 取得したデータの利用
    for schedule in response.schedules {
        print("\(schedule.time):\(String(format: "%02d", schedule.minute)) \(schedule.name)")
        
        // 特定の日付の出発時刻を計算
        if let departureDate = schedule.departureDate(basedOn: Date()) {
            print("出発時刻: \(departureDate)")
        }
    }
    
} catch {
    print("Error fetching schedule: \(error)")
}
```

### 臨時ダイヤの情報を取得
利用可能な臨時ダイヤのリストを取得できます。

```swift
let specialSchedules = try await SFCBusScheduleAPI.fetchSpecialSchedules()
for info in specialSchedules {
    print("臨時ダイヤ情報: \(info.date) - \(info.description)")
}
```

### 曜日を指定して通常ダイヤを取得（旧来の方法）
臨時ダイヤを考慮せず、特定の曜日の時刻表を取得します。

```swift
// 土曜日のSFC発バス時刻表を取得（非推奨）
let response = try await SFCBusScheduleAPI.fetchSchedule(
    direction: .fromSFC,
    day: .saturday
)
```

### ヘルパーメソッド

#### 出発時刻の計算
各バススケジュールから、特定の日付での出発時刻を計算できます。

```swift
let schedule = // BusScheduleインスタンス
let targetDate = Date() // 対象日
if let departureDate = schedule.departureDate(basedOn: targetDate) {
    print("このバスは \(departureDate) に出発します")
}
```