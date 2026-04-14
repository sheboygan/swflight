import SwiftUI

struct AirportDetailSheet: View {
    let airport: Airport
    @ObservedObject var viewModel: FlightViewModel
    @Environment(\.dismiss) private var dismiss

    var connectedRoutes: [(from: String, to: String, count: Int)] {
        var counts: [String: Int] = [:]
        for route in viewModel.filteredRoutes {
            if route.from == airport.id || route.to == airport.id {
                let key = "\(route.from)-\(route.to)"
                counts[key, default: 0] += 1
            }
        }
        return counts.map { key, count in
            let parts = key.components(separatedBy: "-")
            return (parts[0], parts[1], count)
        }.sorted { $0.count > $1.count }
    }

    var body: some View {
        NavigationView {
            List {
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

                Section("Connected Routes") {
                    ForEach(connectedRoutes, id: \.from) { route in
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
                            Text("\(route.count)×")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(.secondary)
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
        }
    }
}
