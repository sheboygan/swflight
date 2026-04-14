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

    private let monthNames = ["January","February","March","April","May","June",
                               "July","August","September","October","November","December"]

    // MARK: - XML Loading
    func loadXML(from url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        parseXML(data)
    }

    // MARK: - XML Parsing
    private func parseXML(_ data: Data) {
        let parser = LogbookXMLParser()
        parser.parse(data: data)

        var parsedRoutes: [FlightRoute] = []
        var pilotSet = Set<String>()
        var monthSet = Set<String>()

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
            if pilot != "Unknown" { pilotSet.insert(pilot) }
            if month != "Unknown" { monthSet.insert(month) }

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

        allRoutes = parsedRoutes
        pilots = ["All Pilots"] + pilotSet.sorted()

        // Build sorted months list
        let sortedMonths = monthSet.sorted { a, b in
            (monthNames.firstIndex(of: a) ?? 0) < (monthNames.firstIndex(of: b) ?? 0)
        }
        months = ["All Months"] + sortedMonths

        // Build airport dictionary
        var airportMap: [String: Airport] = [:]
        for route in parsedRoutes {
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
        hasData = !parsedRoutes.isEmpty

        // Reset filters
        selectedPilot = "All Pilots"
        selectedMonth = "All Months"
        applyFilters()
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

    var topRoutes: [(route: String, from: String, to: String, count: Int)] {
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
                return (key, fromInfo.name, toInfo.name, count)
            }
    }
}

// MARK: - XML Parser for SWAPA Logbook Export
class LogbookXMLParser: NSObject, XMLParserDelegate {
    var flights: [[String: String]] = []

    func parse(data: Data) {
        let parser = XMLParser(data: data)
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
