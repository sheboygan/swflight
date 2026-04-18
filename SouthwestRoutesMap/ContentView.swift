import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = FlightViewModel()
    @State private var showStats = false
    @State private var showFilters = false
    @State private var showFileImporter = false
    @State private var showSearch = false
    @State private var showDeleteConfirm = false
    @State private var showImportAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen map
                RouteMapView(viewModel: viewModel)
                    .ignoresSafeArea()

                if !viewModel.hasData {
                    // Empty state overlay
                    VStack(spacing: 16) {
                        Image(systemName: "airplane.circle")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary)
                        Text("No Logbook Loaded")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Import your SWAPA logbook XML to see your routes on the map.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Import Logbook", systemImage: "square.and.arrow.down")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(24)
                } else {
                    VStack {
                        filterChipBar
                        Spacer()
                        floatingLegend
                    }
                }
            }
            .navigationTitle("Southwest Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.hasData {
                        flightCountBadge
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showFileImporter = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        if viewModel.hasData {
                            Button {
                                showSearch.toggle()
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            Button {
                                showFilters.toggle()
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                            }
                            Button {
                                showStats.toggle()
                            } label: {
                                Image(systemName: "chart.bar.fill")
                            }
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType.xml, UTType.data, UTType.plainText],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        guard url.startAccessingSecurityScopedResource() else { continue }
                        defer { url.stopAccessingSecurityScopedResource() }
                        guard let data = try? Data(contentsOf: url) else { continue }
                        viewModel.importXML(data: data)
                    }
                    showImportAlert = true
                case .failure:
                    break
                }
            }
            .alert("Import Complete", isPresented: $showImportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                if viewModel.lastImportDuplicates > 0 {
                    Text("Added \(viewModel.lastImportCount) flights. \(viewModel.lastImportDuplicates) duplicates skipped.")
                } else {
                    Text("Added \(viewModel.lastImportCount) flights.")
                }
            }
            .sheet(isPresented: $showStats) {
                NavigationStack {
                    StatsPanelView(viewModel: viewModel)
                        .navigationTitle("Flight Statistics")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(role: .destructive) {
                                    showDeleteConfirm = true
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showStats = false }
                            }
                        }
                        .alert("Delete All Data?", isPresented: $showDeleteConfirm) {
                            Button("Delete", role: .destructive) {
                                viewModel.deleteAllData()
                                showStats = false
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will remove all imported flight data. This cannot be undone.")
                        }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showFilters) {
                FilterSheet(viewModel: viewModel)
                    .presentationDetents([.height(280)])
            }
            .sheet(isPresented: $showSearch) {
                SearchSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $viewModel.selectedAirport) { airport in
                AirportDetailSheet(airport: airport, viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Subviews

    private var flightCountBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "airplane")
                .font(.caption)
            Text("\(viewModel.totalFlights)")
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.blue)
        .clipShape(Capsule())
    }

    private var filterChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if viewModel.selectedPilot != "All Pilots" {
                    FilterChip(label: viewModel.selectedPilot, color: .blue) {
                        viewModel.selectedPilot = "All Pilots"
                        viewModel.applyFilters()
                    }
                }
                if viewModel.selectedMonth != "All Months" {
                    FilterChip(label: viewModel.selectedMonth, color: .indigo) {
                        viewModel.selectedMonth = "All Months"
                        viewModel.applyFilters()
                    }
                }
                if !viewModel.searchText.isEmpty {
                    FilterChip(label: "Search: \(viewModel.searchText)", color: .green) {
                        viewModel.searchText = ""
                        viewModel.applyFilters()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var floatingLegend: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: 0.1, green: 0.4, blue: 0.85))
                    .frame(width: 10, height: 10)
                Text("Airport")
                    .font(.caption2)
            }
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color(red: 0.98, green: 0.75, blue: 0.14))
                    .frame(width: 16, height: 3)
                Text("Route")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .padding(.bottom, 32)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color)
        .clipShape(Capsule())
    }
}

// MARK: - Filter Sheet
struct FilterSheet: View {
    @ObservedObject var viewModel: FlightViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Pilot") {
                    Picker("Pilot", selection: $viewModel.selectedPilot) {
                        ForEach(viewModel.pilots, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                }
                Section("Month") {
                    Picker("Month", selection: $viewModel.selectedMonth) {
                        ForEach(viewModel.months, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        viewModel.selectedPilot = "All Pilots"
                        viewModel.selectedMonth = "All Months"
                        viewModel.applyFilters()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        viewModel.applyFilters()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Search Sheet
struct SearchSheet: View {
    @ObservedObject var viewModel: FlightViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var localSearch: String = ""
    @State private var selectedPilot: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search airports, pilots, flights...", text: $localSearch)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { applySearch() }
                    if !localSearch.isEmpty {
                        Button { localSearch = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)

                List {
                    if !matchedAirports.isEmpty {
                        Section("Airports") {
                            ForEach(matchedAirports, id: \.code) { airport in
                                Button {
                                    viewModel.searchText = airport.code
                                    viewModel.applyFilters()
                                    dismiss()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(airport.name)
                                                .font(.subheadline).fontWeight(.medium)
                                            Text(airport.code)
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text("\(airport.count) flights")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !matchedPilots.isEmpty {
                        Section("Pilots") {
                            ForEach(matchedPilots, id: \.name) { pilot in
                                Button {
                                    selectedPilot = pilot.name
                                } label: {
                                    HStack {
                                        Label {
                                            Text(pilot.name)
                                                .font(.subheadline).fontWeight(.medium)
                                        } icon: {
                                            Image(systemName: "person")
                                                .foregroundColor(.blue)
                                        }
                                        Spacer()
                                        Text("\(pilot.count) flights")
                                            .font(.caption).foregroundColor(.secondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption2).foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !matchedFlights.isEmpty {
                        Section("Flights (\(matchedFlights.count))") {
                            ForEach(matchedFlights.prefix(20)) { flight in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(flight.flightNumber)
                                            .font(.subheadline).fontWeight(.medium)
                                        Text("\(flight.from) -> \(flight.to)")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(flight.date)
                                            .font(.caption).foregroundColor(.secondary)
                                        Text(flight.pilot)
                                            .font(.caption2).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    if localSearch.count >= 2 && matchedAirports.isEmpty
                        && matchedPilots.isEmpty && matchedFlights.isEmpty {
                        Section {
                            Text("No results found")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Search")
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

    private func applySearch() {
        viewModel.searchText = localSearch
        viewModel.applyFilters()
        dismiss()
    }

    private var matchedAirports: [(code: String, name: String, count: Int)] {
        guard localSearch.count >= 1 else { return [] }
        let query = localSearch.lowercased()
        var counts: [String: Int] = [:]
        for route in viewModel.allRoutes {
            counts[route.from, default: 0] += 1
            counts[route.to, default: 0] += 1
        }
        return counts
            .compactMap { code, count -> (String, String, Int)? in
                guard let info = airportDatabase[code] else { return nil }
                if code.lowercased().contains(query) || info.name.lowercased().contains(query) {
                    return (code, info.name, count)
                }
                return nil
            }
            .sorted { $0.2 > $1.2 }
    }

    private var matchedPilots: [(name: String, count: Int)] {
        guard localSearch.count >= 2 else { return [] }
        let query = localSearch.lowercased()
        var counts: [String: Int] = [:]
        for route in viewModel.allRoutes {
            if route.pilot != "Unknown" && route.pilot.lowercased().contains(query) {
                counts[route.pilot, default: 0] += 1
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }

    private var matchedFlights: [FlightRoute] {
        guard localSearch.count >= 2 else { return [] }
        let query = localSearch.lowercased()
        return viewModel.allRoutes.filter { route in
            route.flightNumber.lowercased().contains(query) ||
            route.from.lowercased().contains(query) ||
            route.to.lowercased().contains(query) ||
            route.pilot.lowercased().contains(query) ||
            route.date.contains(query)
        }
    }
}

#Preview {
    ContentView()
}
