import Foundation
import CoreLocation
import MapKit

// MARK: - Airport Model
struct Airport: Identifiable, Hashable {
    let id: String  // IATA code
    let name: String
    let coordinate: CLLocationCoordinate2D
    var flightCount: Int = 0

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Airport, rhs: Airport) -> Bool { lhs.id == rhs.id }
}

// MARK: - Flight Route
struct FlightRoute: Identifiable {
    let id = UUID()
    let from: String
    let to: String
    let date: String
    let flightNumber: String
    let month: String
    let pilot: String
    let blockTime: Double
}

// MARK: - Route Segment (unique from→to pair with frequency)
struct RouteSegment: Identifiable {
    let id: String
    let from: String
    let to: String
    let fromCoordinate: CLLocationCoordinate2D
    let toCoordinate: CLLocationCoordinate2D
    var frequency: Int
}

/// Converts ICAO code to IATA-style code used in the airport database.
/// Strips the leading "K" from US domestic ICAO codes (e.g. KPHX → PHX).
/// Non-US codes (e.g. MMSD) are returned as-is.
func icaoToIATA(_ icao: String) -> String {
    let trimmed = icao.trimmingCharacters(in: .whitespaces)
    if trimmed.count == 4 && trimmed.hasPrefix("K") {
        return String(trimmed.dropFirst())
    }
    return trimmed
}

// MARK: - Airport Coordinate Database (All Southwest Airlines destinations)
let airportDatabase: [String: (lat: Double, lng: Double, name: String)] = [
    // California
    "BUR": (34.2007, -118.3590, "Burbank"),
    "FAT": (36.7762, -119.7181, "Fresno"),
    "LGB": (33.8177, -118.1516, "Long Beach"),
    "LAX": (33.9416, -118.4085, "Los Angeles"),
    "OAK": (37.7214, -122.2208, "Oakland"),
    "ONT": (34.0556, -117.6006, "Ontario"),
    "PSP": (33.8303, -116.5067, "Palm Springs"),
    "SAN": (32.7336, -117.1897, "San Diego"),
    "SFO": (37.6213, -122.3790, "San Francisco"),
    "SJC": (37.3639, -121.9289, "San Jose"),
    "SNA": (33.6762, -117.8675, "Orange County"),
    "SMF": (38.6957, -121.5908, "Sacramento"),
    "SBA": (34.4262, -119.8405, "Santa Barbara"),
    // Pacific Northwest
    "BOI": (43.5644, -116.2228, "Boise"),
    "GEG": (47.6199, -117.5338, "Spokane"),
    "PAE": (47.9063, -122.2816, "Everett/Paine Field"),
    "PDX": (45.5887, -122.5968, "Portland"),
    "SEA": (47.4502, -122.3088, "Seattle"),
    // Mountain West
    "ABQ": (35.0433, -106.6129, "Albuquerque"),
    "DEN": (39.8561, -104.6737, "Denver"),
    "ELP": (31.8019, -106.3952, "El Paso"),
    "LAS": (36.0840, -115.1537, "Las Vegas"),
    "PHX": (33.4352, -112.0101, "Phoenix"),
    "RNO": (39.5074, -119.7754, "Reno"),
    "SLC": (40.7899, -111.9791, "Salt Lake City"),
    "TUS": (32.1161, -110.9410, "Tucson"),
    "COS": (38.8058, -104.7009, "Colorado Springs"),
    // Texas
    "AMA": (35.2194, -101.7059, "Amarillo"),
    "AUS": (30.1975, -97.6664, "Austin"),
    "CRP": (27.7704, -97.5012, "Corpus Christi"),
    "DAL": (32.8481, -96.8512, "Dallas Love Field"),
    "ELP": (31.8019, -106.3952, "El Paso"),
    "HOU": (29.9902, -95.3368, "Houston Hobby"),
    "HRL": (26.2285, -97.6544, "Harlingen"),
    "LBB": (33.6636, -101.8230, "Lubbock"),
    "MAF": (31.9425, -102.2019, "Midland"),
    "SAT": (29.5337, -98.4698, "San Antonio"),
    // Central US
    "DSM": (41.5341, -93.6631, "Des Moines"),
    "ICT": (37.6499, -97.4331, "Wichita"),
    "MCI": (39.2976, -94.7139, "Kansas City"),
    "MSP": (44.8848, -93.2223, "Minneapolis"),
    "OKC": (35.3931, -97.6007, "Oklahoma City"),
    "OMA": (41.3032, -95.8941, "Omaha"),
    "STL": (38.7487, -90.3700, "St. Louis"),
    "TUL": (36.1919, -95.8864, "Tulsa"),
    "LIT": (34.7294, -92.2243, "Little Rock"),
    // Great Lakes / Midwest
    "MDW": (41.7868, -87.7522, "Chicago Midway"),
    "CLE": (41.4117, -81.8498, "Cleveland"),
    "CMH": (39.9981, -82.8919, "Columbus"),
    "CVG": (39.0488, -84.6678, "Cincinnati"),
    "DTW": (42.2124, -83.3534, "Detroit"),
    "GRR": (42.8808, -85.5228, "Grand Rapids"),
    "IND": (39.7173, -86.2944, "Indianapolis"),
    "MKE": (42.9476, -87.8966, "Milwaukee"),
    "PIT": (40.4915, -80.2329, "Pittsburgh"),
    "SDF": (38.1740, -85.7364, "Louisville"),
    // Southeast
    "ATL": (33.6407, -84.4277, "Atlanta"),
    "BHM": (33.5629, -86.7535, "Birmingham"),
    "BNA": (36.1263, -86.6774, "Nashville"),
    "CHS": (32.8986, -80.0405, "Charleston"),
    "FLL": (26.0726, -80.1527, "Fort Lauderdale"),
    "GSP": (34.8957, -82.2189, "Greenville-Spartanburg"),
    "JAX": (30.4941, -81.6879, "Jacksonville"),
    "MEM": (35.0424, -89.9767, "Memphis"),
    "MYR": (33.6797, -78.9283, "Myrtle Beach"),
    "MSY": (29.9934, -90.2580, "New Orleans"),
    "MCO": (28.4312, -81.3081, "Orlando"),
    "PBI": (26.6832, -80.0956, "West Palm Beach"),
    "PNS": (30.4734, -87.1866, "Pensacola"),
    "RDU": (35.8776, -78.7875, "Raleigh-Durham"),
    "RSW": (26.5362, -81.7552, "Fort Myers"),
    "SAV": (32.1276, -81.2021, "Savannah"),
    "SRQ": (27.3954, -82.5544, "Sarasota"),
    "TPA": (27.9756, -82.5333, "Tampa"),
    // Northeast
    "ALB": (42.7483, -73.8017, "Albany"),
    "BDL": (41.9389, -72.6832, "Hartford"),
    "BOS": (42.3656, -71.0096, "Boston"),
    "BUF": (42.9405, -78.7322, "Buffalo"),
    "BWI": (39.1774, -76.6684, "Baltimore"),
    "DCA": (38.8512, -77.0402, "Washington Reagan"),
    "ISP": (40.7952, -73.1002, "Long Island"),
    "LGA": (40.7772, -73.8726, "New York LaGuardia"),
    "MHT": (42.9326, -71.4357, "Manchester"),
    "PHL": (39.8721, -75.2411, "Philadelphia"),
    "PVD": (41.7240, -71.4282, "Providence"),
    "ROC": (43.1189, -77.6724, "Rochester"),
    "SYR": (43.1112, -76.1063, "Syracuse"),
    // Hawaii
    "HNL": (21.3187, -157.9225, "Honolulu"),
    "OGG": (20.8986, -156.4305, "Maui"),
    "KOA": (19.7388, -156.0456, "Kona"),
    "LIH": (21.9760, -159.3390, "Lihue"),
    // Caribbean
    "SJU": (18.4394, -66.0018, "San Juan"),
    // Mexico
    "MMSD": (23.1518, -109.7215, "Los Cabos"),
    "MMCN": (23.9085, -106.0651, "Mazatlan"),
    "MMPR": (20.6801, -105.2538, "Puerto Vallarta"),
    "MMUN": (21.0365, -86.8771, "Cancun"),
    // Central America / Caribbean
    "BZE": (17.5391, -88.3082, "Belize City"),
    "MBJ": (18.5037, -77.9134, "Montego Bay"),
    "NAS": (25.0390, -77.4662, "Nassau"),
    "PUJ": (18.5674, -68.3634, "Punta Cana"),
    "AUA": (12.5014, -70.0152, "Aruba"),
    "GCM": (19.2928, -81.3577, "Grand Cayman"),
    "PVR": (20.6801, -105.2538, "Puerto Vallarta"),
    "CUN": (21.0365, -86.8771, "Cancun"),
    "SJD": (23.1518, -109.7215, "Los Cabos"),
]
