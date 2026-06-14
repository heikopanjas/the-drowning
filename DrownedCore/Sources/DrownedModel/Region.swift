import Foundation

public enum Region: String, Sendable, CaseIterable, Codable, Identifiable, Comparable {
    case mediterranean = "Mediterranean"
    case northAmerica = "North America"
    case centralAmerica = "Central America"
    case southAmerica = "South America"
    case caribbean = "Caribbean"
    case northernAfrica = "Northern Africa"
    case easternAfrica = "Eastern Africa"
    case westernAfrica = "Western Africa"
    case middleAfrica = "Middle Africa"
    case southernAfrica = "Southern Africa"
    case westernAsia = "Western Asia"
    case centralAsia = "Central Asia"
    case southernAsia = "Southern Asia"
    case southEasternAsia = "South-eastern Asia"
    case easternAsia = "Eastern Asia"
    case europe = "Europe"
    case oceania = "Oceania"
    case unknown = "Unknown"

    public var id: String { return rawValue }

    public init(source: String) {
        self = Region(rawValue: source.trimmingCharacters(in: .whitespacesAndNewlines)) ?? .unknown
    }

    public static func < (lhs: Region, rhs: Region) -> Bool {
        return lhs.rawValue.localizedStandardCompare(rhs.rawValue) == .orderedAscending
    }
}
