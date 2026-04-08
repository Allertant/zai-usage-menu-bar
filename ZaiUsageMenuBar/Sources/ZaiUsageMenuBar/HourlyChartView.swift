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
