import Foundation

public enum DrinkSyncCSV {
    public static let header = "\u{FEFF}事件ID,类型,记录ID,时间,水量(ml),来源\r\n"

    public static func encode(_ event: DrinkSyncEvent) throws -> String {
        guard !event.id.contains(","), !event.id.contains(where: \.isNewline),
              !event.recordID.contains(","), !event.recordID.contains(where: \.isNewline),
              !event.source.contains(","), !event.source.contains(where: \.isNewline) else {
            throw DrinkSyncError.invalidSource
        }
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        let amount = event.milliliters.map(String.init) ?? ""
        return "\(event.id),\(event.kind.rawValue),\(event.recordID),"
            + "\(formatter.string(from: event.timestamp)),\(amount),\(event.source)\r\n"
    }

    public static func decode(_ text: String) -> [DrinkSyncEvent] {
        let normalized = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var seen = Set<String>()
        var events: [DrinkSyncEvent] = []

        for line in normalized.components(separatedBy: .newlines) where !line.isEmpty {
            let parts = line.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 6, parts[0] != "事件ID",
                  let kind = DrinkSyncEvent.Kind(rawValue: parts[1]),
                  let timestamp = formatter.date(from: parts[3]) else {
                continue
            }
            let milliliters = parts[4].isEmpty ? nil : Int(parts[4])
            guard kind == .delete || milliliters != nil,
                  let event = try? DrinkSyncEvent(
                      id: parts[0],
                      kind: kind,
                      recordID: parts[2],
                      timestamp: timestamp,
                      milliliters: milliliters,
                      source: parts[5]
                  ),
                  seen.insert(event.id).inserted else {
                continue
            }
            events.append(event)
        }
        return events
    }
}
