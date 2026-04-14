import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = FlightViewModel()
    @State private var showStats = false
    @State private var showFilters = false
    @State private var showFileImporter = false

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
                    // Floating filter chips at top
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
                allowedContentTypes: [UTType.xml],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        viewModel.loadXML(from: url)
                    }
                case .failure:
                    break
                }
            }
            .sheet(isPresented: $showStats) {
                NavigationStack {
                    StatsPanelView(viewModel: viewModel)
                        .navigationTitle("Flight Statistics")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showStats = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showFilters) {
                FilterSheet(viewModel: viewModel)
                    .presentationDetents([.height(280)])
            }
            .sheet(item: $viewModel.selectedAirport) { airport in
                AirportDetailSheet(airport: airport, viewModel: viewModel)
                    .presentationDetents([.medium])
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

#Preview {
    ContentView()
}
