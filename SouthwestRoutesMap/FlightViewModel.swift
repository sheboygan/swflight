import Foundation
import CoreLocation

class FlightViewModel: ObservableObject {
    @Published var allRoutes: [FlightRoute] = []
    @Published var filteredRoutes: [FlightRoute] = []
    @Published var airports: [String: Airport] = [:]
    @Published var routeSegments: [RouteSegment] = []
    @Published var selectedPilot: String = "All Pilots"
    @Published var selectedMonth: String = "All Months"
    @Published var pilots: [String] = ["All Pilots"]
    @Published var months: [String] = ["All Months"]
    @Published var selectedAirport: Airport? = nil
    @Published var hasData: Bool = false
    @Published var searchText: String = ""
    @Published var lastImportCount: Int = 0
    @Published var lastImportDuplicates: Int = 0

    private let monthNames = ["January","February","March","April","May","June",
                               "July","August","September","October","November","December"]

    private static let saveKey = "savedFlightRoutes"

    init() {
        loadFromDisk()
    }

    // MARK: - Persistence

    private static var saveURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("flightRoutes.json")
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(allRoutes) else { return }
        try? data.write(to: Self.saveURL, options: .atomic)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: Self.saveURL),
              let routes = try? JSONDecoder().decode([FlightRoute].self, from: data) else { return }
        allRoutes = routes
        rebuildMetadata()
        hasData = !allRoutes.isEmpty
        applyFilters()
    }

    func deleteAllData() {
        allRoutes = []
        filteredRoutes = []
        airports = [:]
        routeSegments = []
        pilots = ["All Pilots"]
        months = ["All Months"]
        selectedPilot = "All Pilots"
        selectedMonth = "All Months"
        searchText = ""
        hasData = false
        try? FileManager.default.removeItem(at: Self.saveURL)
    }

    // MARK: - XML Loading (appends, deduplicates)

    func loadXML(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        importXML(data: data)
    }

    func importXML(data: Data) {
        let newRoutes = parseXMLData(data)

        // Deduplicate against existing routes
        let existingKeys = Set(allRoutes.map { $0.deduplicationKey })
        let unique = newRoutes.filter { !existingKeys.contains($0.deduplicationKey) }

        lastImportCount = unique.count
        lastImportDuplicates = newRoutes.count - unique.count

        guard !unique.isEmpty else { return }

        allRoutes.append(contentsOf: unique)
        rebuildMetadata()
        hasData = !allRoutes.isEmpty

        // Reset filters
        selectedPilot = "All Pilots"
        selectedMonth = "All Months"
        applyFilters()
        saveToDisk()
    }

    // MARK: - XML Parsing

    private func parseXMLData(_ data: Data) -> [FlightRoute] {
        let parser = LogbookXMLParser()
        parser.parse(data: data)

        var parsedRoutes: [FlightRoute] = []

        for entry in parser.flights {
            let from = icaoToIATA(entry["From"] ?? "")
            let to = icaoToIATA(entry["To"] ?? "")

            guard !from.isEmpty, !to.isEmpty,
                  airportDatabase[from] != nil,
                  airportDatabase[to] != nil else { continue }

            // Block time is in minutes in the XML
            let blockMinutes = Double(entry["Block"] ?? "0") ?? 0
            let blockHours = blockMinutes / 60.0

            // Parse date (format: 2026-01-18)
            let dateStr = entry["DATE"] ?? ""
            var month = "Unknown"
            let dateComponents = dateStr.components(separatedBy: "-")
            if dateComponents.count >= 2, let monthNum = Int(dateComponents[1]),
               monthNum >= 1, monthNum <= 12 {
                month = monthNames[monthNum - 1]
            }

            // Parse pilot from CoPilot field (format: "CA  LASTNAME FIRSTNAME [ID]")
            let copilotRaw = entry["CoPilot"] ?? ""
            var pilot = "Unknown"
            if !copilotRaw.isEmpty && copilotRaw != "Deadheading" && copilotRaw != "NOT AVAILABLE" {
                let parts = copilotRaw.components(separatedBy: " ").filter { !$0.isEmpty }
                if parts.count >= 2 {
                    pilot = parts[1]
                }
            }

            parsedRoutes.append(FlightRoute(
                from: from,
                to: to,
                date: dateStr,
                flightNumber: entry["Flight"] ?? "",
                month: month,
                pilot: pilot,
                blockTime: blockHours
            ))
        }

        return parsedRoutes
    }

    /// Rebuild pilots, months, airports from allRoutes
    private func rebuildMetadata() {
        var pilotSet = Set<String>()
        var monthSet = Set<String>()

        for route in allRoutes {
            if route.pilot != "Unknown" { pilotSet.insert(route.pilot) }
            if route.month != "Unknown" { monthSet.insert(route.month) }
        }

        pilots = ["All Pilots"] + pilotSet.sorted()
        let sortedMonths = monthSet.sorted { a, b in
            (monthNames.firstIndex(of: a) ?? 0) < (monthNames.firstIndex(of: b) ?? 0)
        }
        months = ["All Months"] + sortedMonths

        var airportMap: [String: Airport] = [:]
        for route in allRoutes {
            for code in [route.from, route.to] {
                if airportMap[code] == nil, let info = airportDatabase[code] {
                    airportMap[code] = Airport(
                        id: code,
                        name: info.name,
                        coordinate: CLLocationCoordinate2D(latitude: info.lat, longitude: info.lng)
                    )
                }
            }
        }
        airports = airportMap
    }

    // MARK: - Filtering

    func applyFilters() {
        var result = allRoutes

        if selectedPilot != "All Pilots" {
            result = result.filter { $0.pilot == selectedPilot }
        }
        if selectedMonth != "All Months" {
            result = result.filter { $0.month == selectedMonth }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { route in
                route.from.lowercased().contains(query) ||
                route.to.lowercased().contains(query) ||
                route.pilot.lowercased().contains(query) ||
                route.flightNumber.lowercased().contains(query) ||
                route.date.contains(query) ||
                (airportDatabase[route.from]?.name.lowercased().contains(query) == true) ||
                (airportDatabase[route.to]?.name.lowercased().contains(query) == true)
            }
        }

        filteredRoutes = result
        buildRouteSegments(from: result)
        updateAirportCounts(from: result)
    }

    private func buildRouteSegments(from routes: [FlightRoute]) {
        var freq: [String: Int] = [:]
        for route in routes {
            let key = "\(route.from)-\(route.to)"
            freq[key, default: 0] += 1
        }

        routeSegments = freq.compactMap { key, count in
            let parts = key.components(separatedBy: "-")
            guard parts.count == 2,
                  let fromInfo = airportDatabase[parts[0]],
                  let toInfo = airportDatabase[parts[1]] else { return nil }
            return RouteSegment(
                id: key,
                from: parts[0],
                to: parts[1],
                fromCoordinate: CLLocationCoordinate2D(latitude: fromInfo.lat, longitude: fromInfo.lng),
                toCoordinate: CLLocationCoordinate2D(latitude: toInfo.lat, longitude: toInfo.lng),
                frequency: count
            )
        }
    }

    private func updateAirportCounts(from routes: [FlightRoute]) {
        var counts: [String: Int] = [:]
        for route in routes {
            counts[route.from, default: 0] += 1
            counts[route.to, default: 0] += 1
        }
        for code in airports.keys {
            airports[code]?.flightCount = counts[code] ?? 0
        }
    }

    // MARK: - Search helpers

    var searchResultAirports: [(code: String, name: String, count: Int)] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        var counts: [String: Int] = [:]
        for route in filteredRoutes {
            counts[route.from, default: 0] += 1
            counts[route.to, default: 0] += 1
        }
        return counts
            .sorted { $0.value > $1.value }
            .compactMap { code, count in
                guard let info = airportDatabase[code] else { return nil }
                if code.lowercased().contains(query) || info.name.lowercased().contains(query) {
                    return (code, info.name, count)
                }
                return nil
            }
    }

    var searchResultPilots: [(name: String, count: Int)] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        var counts: [String: Int] = [:]
        for route in allRoutes {
            if route.pilot != "Unknown" && route.pilot.lowercased().contains(query) {
                counts[route.pilot, default: 0] += 1
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }

    // MARK: - Stats helpers

    var totalFlights: Int { filteredRoutes.count }
    var totalAirports: Int { Set(filteredRoutes.flatMap { [$0.from, $0.to] }).count }
    var totalBlockHours: Double { filteredRoutes.reduce(0) { $0 + $1.blockTime } }

    var topAirports: [(code: String, name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for route in filteredRoutes {
            counts[route.from, default: 0] += 1
            counts[route.to, default: 0] += 1
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .compactMap { code, count in
                guard let info = airportDatabase[code] else { return nil }
                return (code, info.name, count)
            }
    }

    var topRoutes: [(route: String, fromCode: String, toCode: String, from: String, to: String, count: Int)] {
        var counts: [String: Int] = [:]
        for route in filteredRoutes {
            counts["\(route.from)-\(route.to)", default: 0] += 1
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .compactMap { key, count in
                let parts = key.components(separatedBy: "-")
                guard parts.count == 2,
                      let fromInfo = airportDatabase[parts[0]],
                      let toInfo = airportDatabase[parts[1]] else { return nil }
                return (key, parts[0], parts[1], fromInfo.name, toInfo.name, count)
            }
    }

    /// Get all flights for a specific route pair
    func flights(from: String, to: String) -> [FlightRoute] {
        filteredRoutes.filter { $0.from == from && $0.to == to }
    }

    /// Get all flights involving an airport
    func flights(forAirport code: String) -> [FlightRoute] {
        filteredRoutes.filter { $0.from == code || $0.to == code }
    }
}

// MARK: - XML Parser for SWAPA Logbook Export
class LogbookXMLParser: NSObject, XMLParserDelegate {
    var flights: [[String: String]] = []

    func parse(data: Data) {
        // Strip the XML namespace so element names match without prefix
        var xml = String(data: data, encoding: .utf8) ?? ""
        xml = xml.replacingOccurrences(of: "xmlns=\"Pilot_x0020_Log_x0020_Book\"", with: "")
        xml = xml.replacingOccurrences(of: "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"", with: "")
        xml = xml.replacingOccurrences(of: "xsi:schemaLocation=\"Pilot_x0020_Log_x0020_Book", with: "schemaLocation=\"")
        guard let cleanData = xml.data(using: .utf8) else { return }
        let parser = XMLParser(data: cleanData)
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        if elementName == "Details1" {
            flights.append(attributeDict)
        }
    }
}
