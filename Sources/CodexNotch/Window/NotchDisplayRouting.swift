import AppKit
import CoreGraphics

/// Chooses the safe presentation path for display topologies that do not have
/// a one-to-one screen coordinate system.
enum NotchDisplayRouting {
    /// A hardware mirror set exposes the mirror master's coordinate space to
    /// the app. If that space has no camera safe areas, a floating island would
    /// cover ordinary mirrored content instead of aligning with the built-in
    /// display's physical camera housing.
    static func shouldSuppressFloatingIsland(
        layoutMode: NotchLayoutMode,
        displayIsInHardwareMirrorSet: Bool
    ) -> Bool {
        layoutMode == .floatingBar && displayIsInHardwareMirrorSet
    }

    static func isInHardwareMirrorSet(screen: NSScreen) -> Bool {
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        guard let screenNumber = screen.deviceDescription[screenNumberKey] as? NSNumber else {
            return false
        }
        return CGDisplayIsInMirrorSet(
            CGDirectDisplayID(screenNumber.uint32Value)
        ) != 0
    }
}
