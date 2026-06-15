import Foundation

public enum MissingMigrantsDate {
    private static let storedDateFormat = "yyyy-MM-dd"
    private static let importDateFormats = [
        storedDateFormat,
        "EEE, MM/dd/yyyy - HH:mm"
    ]

    public static func storedString(from date: Date) -> String {
        return storedFormatter.string(from: date)
    }

    public static func storedDate(from string: String) -> Date? {
        return storedFormatter.date(from: string)
    }

    public static func importedDate(from string: String) -> Date? {
        for formatter in importFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private static let storedFormatter = makeFormatter(storedDateFormat)

    private static let importFormatters = importDateFormats.map { format in
        return makeFormatter(format)
    }

    private static func makeFormatter(_ dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = dateFormat
        return formatter
    }
}
