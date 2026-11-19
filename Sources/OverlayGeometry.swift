// Floating Camera — MIT License. See LICENSE.

import AppKit
import Foundation

enum OverlayGeometry {
    static let resizeBandWidth: CGFloat = 20
    static let resizeMargin = resizeBandWidth / 2

    static func resizedFrame(_ frame: NSRect, from point: CGPoint, delta: CGPoint) -> NSRect {
        let dx = point.x - frame.midX
        let dy = point.y - frame.midY
        let distanceSquared = dx * dx + dy * dy
        guard distanceSquared > 1 else { return frame }
        let scale = 1 + (delta.x * dx + delta.y * dy) / distanceSquared
        let aspect = frame.width / frame.height
        let width = min(800, max(max(160, minimumWidth(for: aspect)), frame.width * scale))
        let size = CGSize(width: width, height: width / aspect)
        return NSRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    static func aspect(for settings: AppSettings, cameraAspect: CGSize) -> CGFloat {
        if let fixed = settings.shape.fixedAspect {
            return max(0.1, fixed)
        }
        guard cameraAspect.width > 0, cameraAspect.height > 0 else {
            return 16.0 / 9.0
        }
        return max(0.1, cameraAspect.width / cameraAspect.height)
    }

    static func minimumWidth(for aspect: CGFloat) -> CGFloat {
        max(120, 90 * max(0.1, aspect))
    }

    static func size(for settings: AppSettings, cameraAspect: CGSize) -> CGSize {
        let aspect = aspect(for: settings, cameraAspect: cameraAspect)
        let requestedWidth = CGFloat(settings.customWidth)
        let width = max(requestedWidth, minimumWidth(for: aspect))
        return CGSize(width: width, height: max(1, (width / aspect).rounded()))
    }

    static func defaultOrigin(for size: CGSize, on screen: NSScreen, margin: CGFloat = 24) -> CGPoint {
        defaultOrigin(for: size, visibleFrame: screen.visibleFrame, margin: margin)
    }

    static func defaultOrigin(for size: CGSize, visibleFrame: NSRect, margin: CGFloat = 24) -> CGPoint {
        CGPoint(
            x: visibleFrame.maxX - size.width - margin,
            y: visibleFrame.minY + margin
        )
    }

    static func centeredOrigin(for size: CGSize, on screen: NSScreen) -> CGPoint {
        centeredOrigin(for: size, visibleFrame: screen.visibleFrame)
    }

    static func centeredOrigin(for size: CGSize, visibleFrame: NSRect) -> CGPoint {
        CGPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )
    }

    static func clampedFrame(_ frame: NSRect, to screen: NSScreen) -> NSRect {
        clampedFrame(frame, within: screen.visibleFrame)
    }

    static func clampedFrame(_ frame: NSRect, within visibleFrame: NSRect) -> NSRect {
        var result = frame
        result.origin.x = min(
            max(result.origin.x, visibleFrame.minX),
            max(visibleFrame.minX, visibleFrame.maxX - result.width)
        )
        result.origin.y = min(
            max(result.origin.y, visibleFrame.minY),
            max(visibleFrame.minY, visibleFrame.maxY - result.height)
        )
        return result
    }

    static func screen(for frame: NSRect) -> NSScreen? {
        var bestScreen: NSScreen?
        var bestArea: CGFloat = 0

        for screen in NSScreen.screens {
            let intersection = screen.visibleFrame.intersection(frame)
            guard !intersection.isNull else { continue }
            let area = intersection.width * intersection.height
            if area > bestArea {
                bestScreen = screen
                bestArea = area
            }
        }

        return bestArea >= 40 * 40 ? bestScreen : nil
    }
}
