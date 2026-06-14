import DrownedStore
import MapKit
import Observation

@Observable
@MainActor
final class SearchModel: NSObject, MKLocalSearchCompleterDelegate {
    var query = ""
    var completions: [LocationCompletion] = []

    private let completer = MKLocalSearchCompleter()
    private var skipsNextQueryUpdate = false

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ query: String) -> Void {
        if skipsNextQueryUpdate == true {
            skipsNextQueryUpdate = false
            return
        }

        self.query = query
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        completer.queryFragment = trimmedQuery
        if trimmedQuery.isEmpty == true {
            completions = []
        }
    }

    func select(_ completion: LocationCompletion) -> Void {
        skipsNextQueryUpdate = true
        query = completion.title
        completer.queryFragment = ""
        completions = []
    }

    func clear() -> Void {
        skipsNextQueryUpdate = false
        query = ""
        completer.queryFragment = ""
        completions = []
    }

    func camera(for completion: LocationCompletion) async throws -> CameraState? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = [completion.title, completion.subtitle]
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
        let response = try await MKLocalSearch(request: request).start()
        guard let coordinate = response.mapItems.first?.placemark.coordinate else { return nil }
        return CameraState(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            distance: 150_000,
            pitch: 0,
            heading: 0
        )
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) -> Void {
        let results = completer.results.map {
            LocationCompletion(title: $0.title, subtitle: $0.subtitle)
        }
        Task { @MainActor in
            completions = results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) -> Void {
        Task { @MainActor in
            completions = []
        }
    }
}
