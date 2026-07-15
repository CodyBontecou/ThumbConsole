import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    let name = window[kCGWindowName as String] as? String ?? ""
    let number = window[kCGWindowNumber as String] as? Int ?? -1
    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let width = (bounds["Width"] as? NSNumber)?.doubleValue ?? 0
    let height = (bounds["Height"] as? NSNumber)?.doubleValue ?? 0

    if owner == "Screen Sharing", name == "Virtualization", width > 1000, height > 700 {
        print(number)
        exit(0)
    }
}

fputs("No Screen Sharing Virtualization window found.\n", stderr)
exit(1)
