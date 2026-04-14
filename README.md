# Southwest Routes Map — iOS App

A native SwiftUI + MapKit port of the React/D3 Southwest Airlines route visualizer.

## Requirements
- Xcode 15+
- iOS 17+ deployment target
- No external dependencies (pure Apple frameworks)

## Project Structure

```
SouthwestRoutesMap/
├── SouthwestRoutesMapApp.swift   # @main entry point
├── ContentView.swift              # Root view: map + toolbar + sheets
├── Models.swift                   # Data types + airport database + CSV
├── FlightViewModel.swift          # Parsing, filtering, stats logic
├── MapOverlays.swift              # MKOverlay + MKOverlayRenderer for curved routes
├── RouteMapView.swift             # UIViewRepresentable wrapping MKMapView
├── StatsPanelView.swift           # Stats sheet (airports, routes, totals)
└── AirportDetailSheet.swift       # Airport tap → detail sheet
```

## Opening in Xcode

1. Open `SouthwestRoutesMap.xcodeproj` in Xcode
2. Select your team in **Signing & Capabilities** → set `PRODUCT_BUNDLE_IDENTIFIER` to something unique (e.g. `com.yourname.SouthwestRoutesMap`)
3. Choose a simulator or connected device
4. Press **⌘R** to build and run

## Features

| Feature | Implementation |
|---|---|
| Interactive map | MKMapView with muted standard style |
| Curved flight routes | Custom `MKOverlay` + `MKOverlayRenderer` drawing quadratic Bézier curves |
| Route thickness | Scales with flight frequency |
| Airport dots | Sized + colored by flight count, labeled with IATA code |
| Filter by pilot | Picker in filter sheet |
| Filter by month | Segmented control |
| Active filter chips | Shown on map, tappable to clear |
| Flight statistics | Bottom sheet: top airports, top routes, totals |
| Airport detail | Tap callout → sheet with connected routes |
| Portrait + landscape | Supported on iPhone and iPad |

## Adding Real Data

Replace `sampleCSV` in `Models.swift` with a larger dataset, or modify `FlightViewModel.parseCSV(_:)` to load from a file:

```swift
// Load from app bundle
if let url = Bundle.main.url(forResource: "flights", withExtension: "csv"),
   let csv = try? String(contentsOf: url) {
    parseCSV(csv)
}
```

Then add your `flights.csv` to the Xcode project target.
