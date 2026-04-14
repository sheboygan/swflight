import SwiftUI

struct StatsPanelView: View {
    @ObservedObject var viewModel: FlightViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Summary cards
                HStack(spacing: 12) {
                    StatCard(title: "Flights", value: "\(viewModel.totalFlights)",
                             color: .blue, icon: "airplane")
                    StatCard(title: "Airports", value: "\(viewModel.totalAirports)",
                             color: .indigo, icon: "mappin.circle")
                }

                StatCard(title: "Block Hours", value: String(format: "%.1f", viewModel.totalBlockHours),
                         color: .orange, icon: "clock")

                // Top Airports
                SectionHeader(title: "Top Airports", icon: "building.2")

                ForEach(Array(viewModel.topAirports.enumerated()), id: \.element.code) { idx, airport in
                    HStack {
                        Text("\(idx + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(airport.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(airport.code)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(airport.count)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                    Divider()
                }

                // Top Routes
                SectionHeader(title: "Top Routes", icon: "arrow.triangle.swap")

                ForEach(Array(viewModel.topRoutes.enumerated()), id: \.element.route) { idx, route in
                    HStack {
                        Text("\(idx + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(route.from)
                                    .font(.caption2)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text(route.to)
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(route.count)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                    Divider()
                }

                // Legend
                SectionHeader(title: "Legend", icon: "info.circle")

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(red: 0.1, green: 0.4, blue: 0.85))
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        Text("Airport (size = flight count)")
                            .font(.caption)
                    }
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.98, green: 0.75, blue: 0.14))
                            .frame(width: 24, height: 4)
                        Text("Route (width = frequency)")
                            .font(.caption)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Subviews

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .kerning(0.5)
        }
        .padding(.top, 4)
    }
}
