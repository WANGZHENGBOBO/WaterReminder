import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WaterCore

struct HistoryView: View {
    let drinks: [Drink]
    let goal: Int
    let serving: Int
    let now: Date

    @State private var expanded = false
    @State private var period: HistoryPeriod = .month
    @State private var anchor = Date()
    @State private var selected: HistoryBucket?
    @State private var showingExport = false
    @State private var exportStart = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
    @State private var exportEnd = Date()
    @State private var message: String?

    private var calendar: Calendar { .current }
    private var cells: [HistoryBucket] {
        HistoryReport.cells(drinks: drinks, period: period, anchor: anchor,
                            goal: goal, serving: serving, calendar: calendar)
    }
    private var displayedCells: [HistoryBucket] {
        let values = cells
        guard period == .year else { return values }
        let weeks = values.count / 7
        return (0..<7).flatMap { row in (0..<weeks).map { column in values[column * 7 + row] } }
    }
    private var columns: [GridItem] {
        let count = period == .year ? cells.count / 7 : period == .day ? 12 : 7
        return Array(repeating: GridItem(period == .year ? .fixed(4) : .flexible(), spacing: period == .year ? 1 : 4), count: count)
    }
    private var periodLabel: String {
        let range = HistoryReport.interval(for: period, anchor: anchor, calendar: calendar)
        switch period {
        case .day: return anchor.formatted(.dateTime.year().month().day())
        case .week:
            let last = range.end.addingTimeInterval(-1)
            return "\(range.start.formatted(.dateTime.month().day()))–\(last.formatted(.dateTime.month().day()))"
        case .month: return anchor.formatted(.dateTime.year().month())
        case .year: return anchor.formatted(.dateTime.year())
        }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                if showingExport {
                    exportSheet
                } else {
                Picker("", selection: $period) {
                    ForEach(HistoryPeriod.allCases) { value in Text(value.title).tag(value) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: period) { _ in anchor = now; selected = nil }

                HStack {
                    Button { move(-1) } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(periodLabel).font(.caption.weight(.semibold))
                    Spacer()
                    Button { move(1) } label: { Image(systemName: "chevron.right") }
                }
                .buttonStyle(.borderless)

                LazyVGrid(columns: columns, alignment: .center, spacing: period == .year ? 1 : 4) {
                    ForEach(displayedCells) { cell in
                        if cell.inPeriod {
                            Button { selected = cell } label: {
                                RoundedRectangle(cornerRadius: period == .year ? 1 : 3)
                                    .fill(cell.intensity == 0 ? Color.white.opacity(0.12) :
                                            Color(red: 0, green: 0.5, blue: 1).opacity(0.2 + Double(cell.intensity) * 0.16))
                                    .frame(height: period == .year ? 4 : 22)
                            }
                            .buttonStyle(.plain)
                            .help("\(cell.start.formatted(date: .abbreviated, time: period == .day ? .shortened : .omitted))：\(cell.grams)ml")
                        } else {
                            Color.clear.frame(height: period == .year ? 4 : 22)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                if let selected {
                    Text("\(selected.start.formatted(date: .abbreviated, time: period == .day ? .shortened : .omitted)) · \(selected.grams)ml · \(selected.count) 次")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Text("本期 \(cells.filter(\.inPeriod).reduce(0) { $0 + $1.grams })ml")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("导出记录…") { showingExport = true }
                        .font(.caption)
                }
                if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
            }
            .padding(.top, 8)
        } label: {
            Text("历史趋势").font(.caption.weight(.semibold))
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .onAppear { anchor = now }
    }

    private func move(_ amount: Int) {
        anchor = calendar.date(byAdding: period.component, value: amount, to: anchor) ?? anchor
        selected = nil
    }

    private var exportSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("导出喝水记录").font(.headline)
            DatePicker("开始日期", selection: $exportStart, displayedComponents: .date)
            DatePicker("结束日期", selection: $exportEnd, displayedComponents: .date)
            if let message { Text(message).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("取消") { showingExport = false; message = nil }
                Button("导出 CSV") { exportCSV() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func exportCSV() {
        guard let csv = HistoryReport.csv(drinks: drinks, from: exportStart, through: exportEnd, calendar: calendar) else {
            message = calendar.startOfDay(for: exportStart) > calendar.startOfDay(for: exportEnd)
                ? "结束日期不能早于开始日期" : "所选时间段没有喝水记录"
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "喝水BO～-饮水记录.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try Data(csv.utf8).write(to: url, options: .atomic)
            message = "记录已导出"
            showingExport = false
        } catch {
            message = "导出失败：\(error.localizedDescription)"
        }
    }
}
