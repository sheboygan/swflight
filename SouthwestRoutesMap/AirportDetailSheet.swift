import SwiftUI

struct AirportDetailSheet: View {
    let airport: Airport
    @ObservedObject var viewModel: FlightViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var expandedRoute: String?
    @State private var selectedPilot: String?

    var connectedRoutes: [(key: String, from: String, to: String, count: Int)] {
        var counts: [String: Int] = [:]
        for route in viewModel.filteredRoutes {
            if route.from == airport.id || route.to == airport.id {
                let key = "\(route.from)-\(route.to)"
                counts[key, default: 0] += 1
            }
        }
        return counts.map { key, count in
            let parts = key.components(separatedBy: "-")
            return (key, parts[0], parts[1], count)
        }.sorted { $0.count > $1.count }
    }

    func flightsForRoute(from: String, to: String) -> [FlightRoute] {
        viewModel.filteredRoutes.filter { $0.from == from && $0.to == to }
    }

    var totalBlock: Double {
        viewModel.flights(forAirport: airport.id).reduce(0) { $0 + $1.blockTime }
    }

    var uniquePilots: [String] {
        let pilots = Set(viewModel.flights(forAirport: airport.id)
            .map { $0.pilot }
            .filter { $0 != "Unknown" })
        return pilots.sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(airport.name)
                                .font(.title2).fontWeight(.bold)
                            Text(airport.id)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        Spacer()
                        VStack {
                            Text("\(airport.flightCount)")
                                .font(.largeTitle).fontWeight(.black)
                                .foregroundColor(.blue)
                            Text("flights")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                // Summary stats
                Section {
                    HStack {
                        Label("Block Hours", systemImage: "clock")
                        Spacer()
                        Text(String(format: "%.1f hrs", totalBlock))
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Label("Routes", systemImage: "arrow.triangle.swap")
                        Spacer()
                        Text("\(connectedRoutes.count)")
                            .fontWeight(.semibold)
                    }
                    if !uniquePilots.isEmpty {
                        HStack {
                            Label("Pilots", systemImage: "person.2")
                            Spacer()
                            Text("\(uniquePilots.count)")
                                .fontWeight(.semibold)
                        }
                    }
                }

                // Connected Routes (expandable)
                Section("Connected Routes") {
                    ForEach(connectedRoutes, id: \.key) { route in
                        VStack(spacing: 0) {
                            Button {
                                withAnimation {
                                    if expandedRoute == route.key {
                                        expandedRoute = nil
                                    } else {
                                        expandedRoute = route.key
                                    }
                                }
                            } label: {
                                HStack {
                                    Label {
                                        HStack(spacing: 6) {
                                            Text(route.from)
                                                .fontWeight(route.from == airport.id ? .bold : .regular)
                                            Image(systemName: "arrow.right")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                            Text(route.to)
                                                .fontWeight(route.to == airport.id ? .bold : .regular)
                                        }
                                    } icon: {
                                        Image(systemName: "airplane")
                                            .foregroundColor(.orange)
                                    }
                                    Spacer()
                                    Text("\(route.count)x")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    Image(systemName: expandedRoute == route.key ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            if expandedRoute == route.key {
                                let flights = flightsForRoute(from: route.from, to: route.to)
                                VStack(spacing: 0) {
                                    ForEach(flights) { flight in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(flight.flightNumber)
                                                    .font(.caption).fontWeight(.medium)
                                                Text(flight.date)
                                                    .font(.caption2).foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 1) {
                                                Text(flight.pilot)
                                                    .font(.caption2).foregroundColor(.secondary)
                                                Text(String(format: "%.1f hrs", flight.blockTime))
                                                    .font(.caption2).foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 28)
                                        if flight.id != flights.last?.id {
                                            Divider().padding(.leading, 28)
                                        }
                                    }
                                }
                                .padding(.top, 6)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }

                // Pilots who flew here
                if !uniquePilots.isEmpty {
                    Section("Pilots") {
                        ForEach(uniquePilots, id: \.self) { pilot in
                            let count = viewModel.flights(forAirport: airport.id)
                                .filter { $0.pilot == pilot }.count
                            Button {
                                selectedPilot = pilot
                            } label: {
                                HStack {
                                    Label(pilot, systemImage: "person")
                                    Spacer()
                                    Text("\(count) flights")
                                        .font(.caption).foregroundColor(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Airport Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { selectedPilot.map { PilotID(name: $0) } },
                set: { selectedPilot = $0?.name }
            )) { pilot in
                PilotDetailSheet(pilotName: pilot.name, viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Pilot ID wrapper for sheet binding
struct PilotID: Identifiable {
    let name: String
    var id: String { name }
}

// MARK: - Pilot Detail Sheet
struct PilotDetailSheet: View {
    let pilotName: String
    @ObservedObject var viewModel: FlightViewModel
    @Environment(\.dismiss) private var dismiss

    var flights: [FlightRoute] {
        viewModel.allRoutes
            .filter { $0.pilot == pilotName }
            .sorted { $0.date < $1.date }
    }

    var totalBlock: Double { flights.reduce(0) { $0 + $1.blockTime } }

    var uniqueAirports: Int {
        Set(flights.flatMap { [$0.from, $0.to] }).count
    }

    var uniqueRoutes: Int {
        Set(flights.map { "\($0.from)-\($0.to)" }).count
    }

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pilotName)
                                .font(.title2).fontWeight(.bold)
                            Text("Co-Pilot")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack {
                            Text("\(flights.count)")
                                .font(.largeTitle).fontWeight(.black)
                                .foregroundColor(.blue)
                            Text("flights")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                // Stats
                Section {
                    HStack {
                        Label("Block Hours", systemImage: "clock")
                        Spacer()
                        Text(String(format: "%.1f hrs", totalBlock))
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Label("Airports", systemImage: "mappin.circle")
                        Spacer()
                        Text("\(uniqueAirports)")
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Label("Routes", systemImage: "arrow.triangle.swap")
                        Spacer()
                        Text("\(uniqueRoutes)")
                            .fontWeight(.semibold)
                    }
                }

                // Flight log
                Section("Flight Log") {
                    ForEach(flights) { flight in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(flight.flightNumber)
                                    .font(.subheadline).fontWeight(.medium)
                                HStack(spacing: 4) {
                                    Text(flight.from).fontWeight(.semibold)
                                    Image(systemName: "arrow.right")
                                        .font(.caption2).foregroundColor(.orange)
                                    Text(flight.to).fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(flight.date)
                                    .font(.caption).foregroundColor(.secondary)
                                Text(String(format: "%.1f hrs", flight.blockTime))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pilot Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
