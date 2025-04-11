# SFCBusSchedule

SFCBusScheduleは、慶應義塾大学湘南藤沢キャンパス（SFC）のバス時刻表を簡単に取得できるSwiftライブラリです。

## 機能

- バス時刻表の取得（行き／帰り、平日／土曜日／日曜日）
- Codableに準拠したデータモデル
- 非同期データ取得（async/await）
- エラーハンドリング

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

```swift
import SFCBusSchedule

// バス時刻表の取得
let schedules = try await SFCBusScheduleAPI.fetchSchedule(
    direction: .fromSFC,
    day: .weekday
)

// 取得したデータの利用
for schedule in schedules {
    print("\(schedule.time):\(schedule.minute) \(schedule.name)")
}
```