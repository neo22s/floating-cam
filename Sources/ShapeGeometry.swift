// Floating Camera — MIT License. See LICENSE.

import CoreGraphics
import Foundation

enum ShapeGeometry {
    static func path(for shape: OverlayShape, in rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        guard rect.width > 1, rect.height > 1 else { return CGMutablePath() }

        switch shape {
        case .rectangle:
            return roundedRect(rect, radius: cornerRadius)
        case .verticalRectangle:
            return roundedRect(rect, radius: cornerRadius)
        case .roundedSquare:
            return roundedRect(rect, radius: cornerRadius)
        case .square:
            return roundedRect(rect, radius: cornerRadius)
        case .circle:
            return CGPath(ellipseIn: rect, transform: nil)
        case .capsule:
            return roundedRect(rect, radius: min(rect.width, rect.height) / 2)
        case .heart:
            return heart(rect)
        case .star:
            return star(rect, points: 5, innerRatio: 0.44)
        case .hexagon:
            return polygon(rect, sides: 6, startAngle: 0)
        case .pentagon:
            return polygon(rect, sides: 5, startAngle: .pi / 2)
        case .diamond:
            return polygon(rect, sides: 4, startAngle: .pi / 2)
        }
    }

    private static func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
        let clamped = max(0, min(radius, min(rect.width, rect.height) / 2))
        return CGPath(roundedRect: rect, cornerWidth: clamped, cornerHeight: clamped, transform: nil)
    }

    private static func polygon(_ rect: CGRect, sides: Int, startAngle: CGFloat) -> CGPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let step = (2 * CGFloat.pi) / CGFloat(sides)
        let path = CGMutablePath()

        for index in 0..<sides {
            let angle = startAngle + CGFloat(index) * step
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }

        path.closeSubpath()
        return path
    }

    private static func star(_ rect: CGRect, points: Int, innerRatio: CGFloat) -> CGPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let step = CGFloat.pi / CGFloat(points)
        let path = CGMutablePath()

        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = CGFloat.pi / 2 + CGFloat(index) * step
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }

        path.closeSubpath()
        return path
    }

    private static func heart(_ rect: CGRect) -> CGPath {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        let path = CGMutablePath()
        path.move(to: point(0.5, 0.03))
        path.addCurve(
            to: point(0.03, 0.68),
            control1: point(0.16, 0.27),
            control2: point(0.03, 0.51)
        )
        path.addCurve(
            to: point(0.5, 0.86),
            control1: point(0.03, 0.98),
            control2: point(0.30, 0.99)
        )
        path.addCurve(
            to: point(0.97, 0.68),
            control1: point(0.70, 0.99),
            control2: point(0.97, 0.98)
        )
        path.addCurve(
            to: point(0.5, 0.03),
            control1: point(0.97, 0.51),
            control2: point(0.84, 0.27)
        )
        path.closeSubpath()
        return path
    }
}
