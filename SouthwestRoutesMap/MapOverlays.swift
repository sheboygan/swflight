import MapKit
import UIKit

// MARK: - Route Polyline with frequency metadata
class RoutePolyline: MKPolyline {
    var frequency: Int = 1
    var fromCode: String = ""
    var toCode: String = ""
}

// MARK: - Custom curved route overlay
class CurvedRouteOverlay: NSObject, MKOverlay {
    let fromCoordinate: CLLocationCoordinate2D
    let toCoordinate: CLLocationCoordinate2D
    let frequency: Int
    let fromCode: String
    let toCode: String

    var coordinate: CLLocationCoordinate2D {
        // Midpoint
        CLLocationCoordinate2D(
            latitude: (fromCoordinate.latitude + toCoordinate.latitude) / 2,
            longitude: (fromCoordinate.longitude + toCoordinate.longitude) / 2
        )
    }

    var boundingMapRect: MKMapRect {
        let fromPoint = MKMapPoint(fromCoordinate)
        let toPoint = MKMapPoint(toCoordinate)
        let rect = MKMapRect(
            x: min(fromPoint.x, toPoint.x) - 50000,
            y: min(fromPoint.y, toPoint.y) - 50000,
            width: abs(fromPoint.x - toPoint.x) + 100000,
            height: abs(fromPoint.y - toPoint.y) + 100000
        )
        return rect
    }

    init(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D,
         frequency: Int, fromCode: String, toCode: String) {
        self.fromCoordinate = from
        self.toCoordinate = to
        self.frequency = frequency
        self.fromCode = fromCode
        self.toCode = toCode
    }
}

// MARK: - Curved Route Renderer
class CurvedRouteRenderer: MKOverlayRenderer {
    let curvedOverlay: CurvedRouteOverlay
    var isHighlighted = false

    init(overlay: CurvedRouteOverlay) {
        self.curvedOverlay = overlay
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let fromPoint = point(for: MKMapPoint(curvedOverlay.fromCoordinate))
        let toPoint = point(for: MKMapPoint(curvedOverlay.toCoordinate))

        let dx = toPoint.x - fromPoint.x
        let dy = toPoint.y - fromPoint.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0 else { return }

        // Curve control point — perpendicular to midpoint
        let curveFactor: CGFloat = min(0.35, 80 / dist)
        let curve = dist * curveFactor

        let midX = (fromPoint.x + toPoint.x) / 2
        let midY = (fromPoint.y + toPoint.y) / 2

        // Perpendicular offset (always curve upward / north)
        let perpX = -dy / dist * curve
        let perpY = dx / dist * curve

        let controlPoint = CGPoint(x: midX + perpX, y: midY + perpY)

        let path = CGMutablePath()
        path.move(to: fromPoint)
        path.addQuadCurve(to: toPoint, control: controlPoint)

        // Line width scales with frequency (1–5 pts)
        let lineWidth = CGFloat(1.5 + Double(curvedOverlay.frequency - 1) * 0.8) / zoomScale

        context.setStrokeColor(isHighlighted
            ? UIColor.systemRed.cgColor
            : routeColor(for: curvedOverlay.frequency))
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setAlpha(isHighlighted ? 1.0 : 0.75)
        context.addPath(path)
        context.strokePath()

        // Draw arrowhead at destination
        drawArrow(context: context, path: path, at: toPoint,
                  controlPoint: controlPoint, zoomScale: zoomScale)
    }

    private func drawArrow(context: CGContext, path: CGMutablePath,
                           at point: CGPoint, controlPoint: CGPoint, zoomScale: MKZoomScale) {
        let dx = point.x - controlPoint.x
        let dy = point.y - controlPoint.y
        let angle = atan2(dy, dx)
        let arrowLen: CGFloat = 10 / zoomScale

        let arrowPath = CGMutablePath()
        arrowPath.move(to: point)
        arrowPath.addLine(to: CGPoint(
            x: point.x - arrowLen * cos(angle - 0.4),
            y: point.y - arrowLen * sin(angle - 0.4)
        ))
        arrowPath.move(to: point)
        arrowPath.addLine(to: CGPoint(
            x: point.x - arrowLen * cos(angle + 0.4),
            y: point.y - arrowLen * sin(angle + 0.4)
        ))

        context.addPath(arrowPath)
        context.setStrokeColor(isHighlighted
            ? UIColor.systemRed.cgColor
            : routeColor(for: curvedOverlay.frequency))
        context.strokePath()
    }

    private func routeColor(for frequency: Int) -> CGColor {
        // Amber gradient: low freq = light amber, high freq = deep amber/orange
        let t = min(Double(frequency - 1) / 4.0, 1.0)
        let r = 0.98 - t * 0.15
        let g = 0.75 - t * 0.30
        let b = 0.14
        return UIColor(red: r, green: g, blue: b, alpha: 1).cgColor
    }
}

// MARK: - Airport Annotation
class AirportAnnotation: NSObject, MKAnnotation {
    let airport: Airport
    var coordinate: CLLocationCoordinate2D { airport.coordinate }
    var title: String? { airport.name }
    var subtitle: String? { "\(airport.id) — \(airport.flightCount) flights" }

    init(airport: Airport) {
        self.airport = airport
    }
}
