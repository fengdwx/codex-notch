import AppKit
import CoreGraphics
import Foundation

struct FrontmostWindowSnapshot: Equatable {
    let ownerProcessIdentifier: pid_t
    let layer: Int
    let bounds: CGRect
}

enum FrontmostFullScreenDetector {
    private static let edgeTolerance: CGFloat = 2
    private static let minimumCoverage: CGFloat = 0.98

    static func isFrontmostApplicationFullScreen(
        on screen: NSScreen,
        workspace: NSWorkspace = .shared
    ) -> Bool {
        guard let processIdentifier = workspace.frontmostApplication?.processIdentifier,
              processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let screenNumber = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
              ] as? NSNumber else {
            return false
        }

        let screenBounds = CGDisplayBounds(CGDirectDisplayID(screenNumber.uint32Value))
        return shouldSuppressNotch(
            frontmostProcessIdentifier: processIdentifier,
            screenBounds: screenBounds,
            windows: currentWindowSnapshots()
        )
    }

    static func shouldSuppressNotch(
        frontmostProcessIdentifier: pid_t?,
        screenBounds: CGRect,
        windows: [FrontmostWindowSnapshot]
    ) -> Bool {
        guard let frontmostProcessIdentifier,
              screenBounds.width > 0,
              screenBounds.height > 0 else {
            return false
        }

        return windows.contains { window in
            window.ownerProcessIdentifier == frontmostProcessIdentifier
                && window.layer == 0
                && coversScreen(window.bounds, screenBounds: screenBounds)
        }
    }

    private static func coversScreen(_ windowBounds: CGRect, screenBounds: CGRect) -> Bool {
        let intersection = windowBounds.intersection(screenBounds)
        guard !intersection.isNull else { return false }

        let screenArea = screenBounds.width * screenBounds.height
        let coveredArea = intersection.width * intersection.height
        guard coveredArea / screenArea >= minimumCoverage else { return false }

        return windowBounds.minX <= screenBounds.minX + edgeTolerance
            && windowBounds.maxX >= screenBounds.maxX - edgeTolerance
            && windowBounds.minY <= screenBounds.minY + edgeTolerance
            && windowBounds.maxY >= screenBounds.maxY - edgeTolerance
    }

    private static func currentWindowSnapshots() -> [FrontmostWindowSnapshot] {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return windowInfo.compactMap { info in
            guard let ownerProcessIdentifier = (
                info[kCGWindowOwnerPID as String] as? NSNumber
            )?.int32Value,
            let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
            let rawBounds = info[kCGWindowBounds as String] as? [String: Any],
            let x = (rawBounds["X"] as? NSNumber)?.doubleValue,
            let y = (rawBounds["Y"] as? NSNumber)?.doubleValue,
            let width = (rawBounds["Width"] as? NSNumber)?.doubleValue,
            let height = (rawBounds["Height"] as? NSNumber)?.doubleValue else {
                return nil
            }

            return FrontmostWindowSnapshot(
                ownerProcessIdentifier: ownerProcessIdentifier,
                layer: layer,
                bounds: CGRect(x: x, y: y, width: width, height: height)
            )
        }
    }
}
