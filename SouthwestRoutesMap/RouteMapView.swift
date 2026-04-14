import SwiftUI
import MapKit

struct RouteMapView: UIViewRepresentable {
    @ObservedObject var viewModel: FlightViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.pointOfInterestFilter = .excludingAll

        // Set initial region over continental US
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.5, longitude: -100.0),
            span: MKCoordinateSpan(latitudeDelta: 28, longitudeDelta: 38)
        )
        mapView.setRegion(region, animated: false)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        // Add route overlays
        for segment in viewModel.routeSegments {
            let overlay = CurvedRouteOverlay(
                from: segment.fromCoordinate,
                to: segment.toCoordinate,
                frequency: segment.frequency,
                fromCode: segment.from,
                toCode: segment.to
            )
            mapView.addOverlay(overlay)
        }

        // Add airport annotations
        let activeAirportCodes = Set(viewModel.filteredRoutes.flatMap { [$0.from, $0.to] })
        for code in activeAirportCodes {
            if let airport = viewModel.airports[code] {
                let annotation = AirportAnnotation(airport: airport)
                mapView.addAnnotation(annotation)
            }
        }
    }

    // MARK: - Coordinator / Delegate
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteMapView

        init(_ parent: RouteMapView) {
            self.parent = parent
        }

        // Render curved route overlays
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let curvedOverlay = overlay as? CurvedRouteOverlay {
                return CurvedRouteRenderer(overlay: curvedOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // Custom airport annotation views
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let airportAnnotation = annotation as? AirportAnnotation else { return nil }

            let reuseId = "AirportPin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)

            if view == nil {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                view?.canShowCallout = true
            }

            view?.annotation = annotation
            let airport = airportAnnotation.airport
            let count = airport.flightCount
            view?.image = airportDotImage(count: count, code: airport.id)
            view?.centerOffset = CGPoint(x: 0, y: 0)

            // Info button in callout
            let btn = UIButton(type: .detailDisclosure)
            view?.rightCalloutAccessoryView = btn

            return view
        }

        func mapView(_ mapView: MKMapView,
                     annotationView view: MKAnnotationView,
                     calloutAccessoryControlTapped control: UIControl) {
            guard let annotation = view.annotation as? AirportAnnotation else { return }
            parent.viewModel.selectedAirport = annotation.airport
        }

        // MARK: - Draw airport dot image
        private func airportDotImage(count: Int, code: String) -> UIImage {
            let maxCount = 8
            let t = min(Double(count) / Double(maxCount), 1.0)
            let diameter = CGFloat(10 + t * 14)  // 10–24pt

            // Blue scale
            let blue = UIColor(
                red: 0.1 + t * 0.1,
                green: 0.3 + t * 0.2,
                blue: 0.7 + t * 0.25,
                alpha: 1.0
            )

            let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter + 4, height: diameter + 4 + 14))
            return renderer.image { ctx in
                let rect = CGRect(x: 2, y: 2, width: diameter, height: diameter)
                // White border
                ctx.cgContext.setFillColor(UIColor.white.cgColor)
                ctx.cgContext.fillEllipse(in: rect.insetBy(dx: -1.5, dy: -1.5))
                // Colored fill
                ctx.cgContext.setFillColor(blue.cgColor)
                ctx.cgContext.fillEllipse(in: rect)

                // Airport code label
                let label = code as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 7),
                    .foregroundColor: UIColor.white
                ]
                let labelSize = label.size(withAttributes: attrs)
                let labelRect = CGRect(
                    x: rect.midX - labelSize.width / 2,
                    y: rect.midY - labelSize.height / 2,
                    width: labelSize.width,
                    height: labelSize.height
                )
                label.draw(in: labelRect, withAttributes: attrs)
            }
        }
    }
}
