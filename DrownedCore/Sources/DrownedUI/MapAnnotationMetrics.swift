import CoreGraphics

enum MapAnnotationMetrics {
    static let incidentDiameter: CGFloat = 24
    static let incidentSymbolSize: CGFloat = 13
    static let clusterDiameter: CGFloat = 32

    static var incidentCenterOffset: CGPoint {
        return CGPoint(x: 0, y: -incidentDiameter / 2)
    }

    static var clusterCenterOffset: CGPoint {
        return CGPoint(x: 0, y: -clusterDiameter / 2)
    }
}
