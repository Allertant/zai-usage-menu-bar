# Hourly Token Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a stacked bar chart showing hourly token usage by model, inside each account's expanded section, with Today/24h toggle.

**Architecture:** Decode the existing `modelDataList` from the API, add a filtering helper to produce `HourlyBar` arrays, render bars as stacked SwiftUI `RoundedRectangle` shapes, and integrate into `AccountSectionView`.

**Tech Stack:** Swift 5.9, SwiftUI (macOS 14+), Swift Package Manager

---

### Task 1: Decode modelDataList and modelSummaryList from API

**Files:**
- Modify: `ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/UsageModels.swift`
- Test: `ZaiUsageMenuBar/Tests/ZaiUsageMenuBarTests/UsageModelsTests.swift` (create)

- [ ] **Step 1: Write the failing test**

Create `ZaiUsageMenuBar/Tests/ZaiUsageMenuBarTests/UsageModelsTests.swift`:

```swift
import XCTest
@testable import ZaiUsageMenuBar

final class UsageModelsTests: XCTestCase {
    func testDecodeModelDataList() throws {
        let json = """
        {
            "x_time": ["2026-04-09 10:00", "2026-04-09 11:00"],
            "modelCallCount": [5, 10],
            "tokensUsage": [1000, 2000],
            "totalUsage": {
                "totalModelCallCount": 15,
                "totalTokensUsage": 3000
            },
            "modelDataList": [
                {
                    "modelName": "GLM-5.1",
                    "sortOrder": 1,
                    "tokensUsage": [800, 1500],
                    "totalTokens": 2300
                },
                {
                    "modelName": "GLM-4.7",
                    "sortOrder": 2,
                    "tokensUsage": [200, 500],
                    "totalTokens": 700
                }
            ],
            "modelSummaryList": [
                {"modelName": "GLM-5.1", "totalTokens": 2300, "sortOrder": 1}
            ],
            "granularity": "hourly"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ModelUsageData.self, from: json)
        XCTAssertEqual(decoded.modelDataList?.count, 2)
        XCTAssertEqual(decoded.modelDataList?[0].modelName, "GLM-5.1")
        XCTAssertEqual(decoded.modelDataList?[0].tokensUsage, [800, 1500])
        XCTAssertEqual(decoded.modelSummaryList?.count, 1)
        XCTAssertEqual(decoded.granularity, "hourly")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/benjamin/tools/zai_usage_menu_bar/ZaiUsageMenuBar && swift test --filter UsageModelsTests 2>&1 | tail -5`
Expected: FAIL — `ModelUsageData` does not have `modelDataList` field yet.

- [ ] **Step 3: Write minimal implementation**

In `ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/UsageModels.swift`, add these structs after `ModelUsageTotal`:

```swift
struct ModelDataItem: Codable {
    let modelName: String?
    let sortOrder: Int?
    let tokensUsage: [Int?]?
    let totalTokens: Int?
}

struct ModelSummaryItem: Codable {
    let modelName: String?
    let totalTokens: Int?
    let sortOrder: Int?
}
```

Add three fields to `ModelUsageData`:

```swift
struct ModelUsageData: Codable {
    let xTime: [String]?
    let modelCallCount: [Int?]?
    let tokensUsage: [Int?]?
    let totalUsage: ModelUsageTotal?
    let modelDataList: [ModelDataItem]?
    let modelSummaryList: [ModelSummaryItem]?
    let granularity: String?

    enum CodingKeys: String, CodingKey {
        case xTime = "x_time"
        case modelCallCount
        case tokensUsage
        case totalUsage
        case modelDataList
        case modelSummaryList
        case granularity
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/benjamin/tools/zai_usage_menu_bar/ZaiUsageMenuBar && swift test --filter UsageModelsTests 2>&1 | tail -5`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/UsageModels.swift ZaiUsageMenuBar/Tests/ZaiUsageMenuBarTests/UsageModelsTests.swift
git commit -m "feat: decode modelDataList and modelSummaryList from API"
```

---

### Task 2: Add HourlyBar struct and filtering helper

**Files:**
- Modify: `ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/UsageModels.swift`
- Modify: `ZaiUsageMenuBar/Tests/ZaiUsageMenuBarTests/UsageModelsTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `UsageModelsTests`:

```swift
extension UsageModelsTests {
    func testHourlyBarFiltering24h() {
        let modelData = ModelUsageData(
            xTime: ["2026-04-08 22:00", "2026-04-08 23:00", "2026-04-09 00:00", "2026-04-09 01:00"],
            modelCallCount: [5, 0, 10, 3],
            tokensUsage: [1000, 0, 2000, 500],
            totalUsage: nil,
            modelDataList: [
                ModelDataItem(modelName: "GLM-5.1", sortOrder: 1, tokensUsage: [800, 0, 1500, 400], totalTokens: 2700),
                ModelDataItem(modelName: "GLM-4.7", sortOrder: 2, tokensUsage: [200, 0, 500, 100], totalTokens: 800)
            ],
            modelSummaryList: nil,
            granularity: "hourly"
        )

        let bars = HourlyBars.from(modelData: modelData, range: .last24h)
        // 24h: skip zero-total hours (23:00), keep 3 bars
        XCTAssertEqual(bars.count, 3)
        XCTAssertEqual(bars[0].label, "22")
        XCTAssertEqual(bars[0].totalTokens, 1000)
        XCTAssertEqual(bars[0].segments.count, 2)
        XCTAssertEqual(bars[0].segments[0].model, "GLM-5.1")
        XCTAssertEqual(bars[0].segments[0].tokens, 800)
        XCTAssertEqual(bars[0].segments[1].model, "GLM-4.7")
        XCTAssertEqual(bars[0].segments[1].tokens, 200)
    }

    func testHourlyBarFilteringToday() {
        let modelData = ModelUsageData(
            xTime: ["2026-04-08 23:00", "2026-04-09 00:00", "2026-04-09 01:00", "2026-04-09 02:00"],
            modelCallCount: [5, 10, 0, 3],
            tokensUsage: [1000, 2000, 0, 500],
            totalUsage: nil,
            modelDataList: [
                ModelDataItem(modelName: "GLM-5.1", sortOrder: 1, tokensUsage: [800, 1500, 0, 400], totalTokens: 2700)
            ],
            modelSummaryList: nil,
            granularity: "hourly"
        )

        // "today" = April 9 in the x_time strings. Use a fixed date for determinism.
        let bars = HourlyBars.from(modelData: modelData, range: .today(referenceDate: date(year: 2026, month: 4, day: 9, hour: 2)))
        // Only Apr 9 hours: 00:00, 01:00, 02:00. Skip 01:00 (zero). Skip 23:00 (Apr 8).
        XCTAssertEqual(bars.count, 2)
        XCTAssertEqual(bars[0].label, "00")
        XCTAssertEqual(bars[1].label, "02")
    }

    func testHourlyBarEmptyModelData() {
        let modelData = ModelUsageData(
            xTime: nil,
            modelCallCount: nil,
            tokensUsage: nil,
            totalUsage: nil,
            modelDataList: nil,
            modelSummaryList: nil,
            granularity: nil
        )

        let bars = HourlyBars.from(modelData: modelData, range: .last24h)
        XCTAssertTrue(bars.isEmpty)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/benjamin/tools/zai_usage_menu_bar/ZaiUsageMenuBar && swift test --filter UsageModelsTests 2>&1 | tail -5`
Expected: FAIL — `HourlyBars` and `HourlyBar` types don't exist yet.

- [ ] **Step 3: Write minimal implementation**

Append to `ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/UsageModels.swift`:

```swift
import Foundation

enum HourlyRange {
    case today(referenceDate: Date)
    case last24h

    var isToday: Bool {
        if case .today = self { return true }
        return false
    }
}

struct HourlyBar {
    let label: String
    let segments: [(model: String, tokens: Int)]
    var totalTokens: Int { segments.reduce(0) { $0 + $1.tokens } }
}

enum HourlyBars {
    static func from(modelData: ModelUsageData, range: HourlyRange) -> [HourlyBar] {
        guard let xTime = modelData.xTime, !xTime.isEmpty,
              let modelItems = modelData.modelDataList else {
            return []
        }

        let calendar = Calendar.current
        let referenceDate: Date
        switch range {
        case .today(let ref): referenceDate = ref
        case .last24h: referenceDate = Date()
        }

        let todayStart = calendar.startOfDay(for: referenceDate)

        var bars: [HourlyBar] = []
        for (index, timeString) in xTime.enumerated() {
            guard let hourDate = parseHourDate(timeString) else { continue }

            if case .today = range {
                if hourDate < todayStart { continue }
            }

            var segments: [(model: String, tokens: Int)] = []
            for item in modelItems {
                guard let tokens = item.tokensUsage,
                      index < tokens.count,
                      let tokenCount = tokens[index], tokenCount > 0 else { continue }
                segments.append((model: item.modelName ?? "Unknown", tokens: tokenCount))
            }

            let total = segments.reduce(0) { $0 + $1.tokens }
            guard total > 0 else { continue }

            let label = formatHourLabel(hourDate: hourDate, isNow: calendar.isDate(hourDate, equalTo: referenceDate, toGranularity: .hour))
            bars.append(HourlyBar(label: label, segments: segments))
        }

        return bars
    }

    private static func parseHourDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }

    private static func formatHourLabel(hourDate: Date, isNow: Bool) -> String {
        if isNow { return "Now" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: hourDate)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/benjamin/tools/zai_usage_menu_bar/ZaiUsageMenuBar && swift test --filter UsageModelsTests 2>&1 | tail -5`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/UsageModels.swift ZaiUsageMenuBar/Tests/ZaiUsageMenuBarTests/UsageModelsTests.swift
git commit -m "feat: add HourlyBar model and filtering logic"
```

---

### Task 3: Build HourlyChartView

**Files:**
- Create: `ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/HourlyChartView.swift`

This is a SwiftUI view — tested visually at runtime. No unit tests for view rendering.

- [ ] **Step 1: Create the chart view file**

Create `ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/HourlyChartView.swift`:

```swift
import SwiftUI

struct HourlyChartView: View {
    let bars: [HourlyBar]
    let modelNames: [String]
    let range: HourlyRange
    let onRangeChange: (HourlyRange) -> Void

    private let barHeight: CGFloat = 60
    private let barGap: CGFloat = 2
    private let maxLabelCount = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with toggle
            HStack {
                Text(L10n.localized("hourly_tokens"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.7))
                Spacer()
                rangeToggle
            }

            if bars.isEmpty {
                Text(L10n.localized("no_data"))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                // Bar chart
                GeometryReader { geometry in
                    let barWidth = max((geometry.size.width - barGap * CGFloat(max(bars.count - 1, 0))) / CGFloat(bars.count), 2)
                    HStack(alignment: .bottom, spacing: barGap) {
                        ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                barStack(bar: bar, barWidth: barWidth)
                            }
                            .frame(width: barWidth, height: barHeight)
                        }
                    }
                    .frame(height: barHeight)
                }
                .frame(height: barHeight)

                // Legend
                legend

                // X-axis labels
                xAxisLabels
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var rangeToggle: some View {
        Picker("", selection: Binding(
            get: { range.isToday ? 0 : 1 },
            set: { onRangeChange($0 == 0 ? .today(referenceDate: Date()) : .last24h) }
        )) {
            Text(L10n.localized("today")).tag(0)
            Text("24h").tag(1)
        }
        .pickerStyle(.segmented)
        .frame(width: 100)
        .scaleEffect(0.8)
        .frame(width: 80, height: 16)
    }

    @ViewBuilder
    private func barStack(bar: HourlyBar, barWidth: CGFloat) -> some View {
        let maxTotal = bars.map(\.totalTokens).max() ?? 1
        let scaleFactor = CGFloat(bar.totalTokens) / CGFloat(max(maxTotal, 1))

        VStack(spacing: 0) {
            ForEach(Array(bar.segments.enumerated()), id: \.offset) { segIndex, segment in
                let segFraction = CGFloat(segment.tokens) / CGFloat(max(bar.totalTokens, 1))
                let segHeight = max(barHeight * scaleFactor * segFraction, segment.tokens > 0 ? 1 : 0)
                RoundedRectangle(cornerRadius: segIndex == bar.segments.count - 1 ? 2 : 0)
                    .fill(colorForModel(segment.model))
                    .frame(height: segHeight)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private var legend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(modelNames, id: \.self) { name in
                    HStack(spacing: 2) {
                        Circle()
                            .fill(colorForModel(name))
                            .frame(width: 5, height: 5)
                        Text(name)
                            .font(.system(size: 7))
                            .foregroundColor(.secondary.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var xAxisLabels: some View {
        HStack(spacing: 0) {
            ForEach(Array(labelIndices.enumerated()), id: \.offset) { _, index in
                if let bar = bars[safe: index] {
                    Text(bar.label)
                        .font(.system(size: 7))
                        .foregroundColor(.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var labelIndices: [Int] {
        guard bars.count > maxLabelCount else { return Array(0..<bars.count) }
        let step = max(1, bars.count / (maxLabelCount - 1))
        var indices = stride(from: 0, to: bars.count, by: step).map { $0 }
        if indices.last != bars.count - 1 {
            indices.append(bars.count - 1)
        }
        return indices
    }

    private func colorForModel(_ name: String) -> Color {
        let index = modelNames.firstIndex(of: name) ?? 0
        return accountColorPalette[index % accountColorPalette.count]
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/benjamin/tools/zai_usage_menu_bar/ZaiUsageMenuBar && swift build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (may need localization key — see Task 4)

Note: The build will fail on `L10n.localized("hourly_tokens")` and `L10n.localized("no_data")` if those keys don't exist yet. That's fine — Task 4 adds them.

- [ ] **Step 3: Commit**

```bash
git add ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/HourlyChartView.swift
git commit -m "feat: add HourlyChartView with stacked bars"
```

---

### Task 4: Add localization keys and integrate into AccountSectionView

**Files:**
- Modify: `ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/Localization.swift`
- Modify: `ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/MenuBarContentView.swift`

- [ ] **Step 1: Add localization keys**

In `ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/Localization.swift`, add these three entries to the `translations` dictionary (after the `"system_default"` entry, before the closing `]`):

```swift
        "hourly_tokens": [
            "en": "Hourly Tokens",
            "zh": "每小时 Token",
        ],
        "no_data": [
            "en": "No data",
            "zh": "暂无数据",
        ],
        "today": [
            "en": "Today",
            "zh": "今天",
        ],
```

- [ ] **Step 2: Integrate HourlyChartView into AccountSectionView**

In `ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/MenuBarContentView.swift`:

1. Add a `@State private var hourlyRange: HourlyRange = .today(referenceDate: Date())` to `AccountSectionView`.

2. Between the `QuotaSectionView` and `StatsSectionView` blocks in the expanded content `VStack`, add:

```swift
if let usage = result.usage, let modelData = usage.modelUsage.modelDataList, !modelData.isEmpty {
    let bars = HourlyBars.from(modelData: usage.modelUsage, range: hourlyRange)
    let modelNames = modelData.compactMap { $0.modelName }

    Divider()
        .background(Color.primary.opacity(0.05))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)

    HourlyChartView(
        bars: bars,
        modelNames: modelNames,
        range: hourlyRange,
        onRangeChange: { hourlyRange = $0 }
    )
}
```

3. Update the `hourlyRange` when it changes for the today variant:

```swift
.onAppear {
    hourlyRange = .today(referenceDate: Date())
}
```

- [ ] **Step 3: Verify it builds and runs**

Run: `cd /Users/benjamin/tools/zai_usage_menu_bar/ZaiUsageMenuBar && swift build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run all tests**

Run: `cd /Users/benjamin/tools/zai_usage_menu_bar/ZaiUsageMenuBar && swift test 2>&1 | tail -10`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/Localization.swift ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/MenuBarContentView.swift
git commit -m "feat: integrate hourly chart into account sections with localization"
```

---

### Task 5: Visual verification and polish

**Files:**
- Potentially modify: `ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/HourlyChartView.swift`

- [ ] **Step 1: Build and run the app**

Run: `cd /Users/benjamin/tools/zai_usage_menu_bar/ZaiUsageMenuBar && swift build && swift run`

- [ ] **Step 2: Verify visually**

- Open the popover, expand an account
- Confirm chart appears between quota bars and stats
- Toggle between Today and 24h
- Verify stacked bars render with correct colors
- Verify legend shows model names
- Verify x-axis labels are readable

- [ ] **Step 3: Fix any visual issues**

Adjust spacing, font sizes, or bar proportions as needed based on visual inspection.

- [ ] **Step 4: Commit any fixes**

```bash
git add -u
git commit -m "fix: polish hourly chart layout"
```

---

### Task 6: Run all tests and final commit

- [ ] **Step 1: Run full test suite**

Run: `cd /Users/benjamin/tools/zai_usage_menu_bar/ZaiUsageMenuBar && swift test 2>&1 | tail -10`
Expected: All tests pass

- [ ] **Step 2: Verify no regressions in existing features**

Run the app and confirm:
- Menu bar icon shows percentage
- Account sections expand/collapse
- Quota bars render
- Stats section shows model calls, tool calls, tokens
- Settings sheet opens
- Refresh works
