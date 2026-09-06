import SwiftUI

struct StatusIconTheme: Equatable {
    let accent: QuotaColorScale.RGB
    private let quotaLevel: WeeklyQuotaLevel

    init(usage: UsageSnapshot?) {
        quotaLevel = WeeklyQuotaLevel(weeklyWindow: usage?.weeklyWindow)
        if let weekly = usage?.weeklyWindow {
            accent = QuotaColorScale.components(for: weekly.remainingPercent)
        } else {
            accent = QuotaColorScale.RGB(red: 0.6, green: 0.6, blue: 0.6)
        }
    }

    var flowerFill: QuotaColorScale.RGB {
        QuotaColorScale.RGB(red: 0, green: 0, blue: 0)
    }

    var runningEcho: QuotaColorScale.RGB {
        // A red quota is useful information; a recurring red pulse can read
        // as an alarm. Keep the outline hue static and activity neutral there.
        quotaLevel == .critical
            ? QuotaColorScale.RGB(red: 0.78, green: 0.78, blue: 0.78)
            : accent
    }

    var runningEchoColor: Color {
        Color(red: runningEcho.red, green: runningEcho.green, blue: runningEcho.blue)
    }

    var flowerColor: Color {
        Color(red: flowerFill.red, green: flowerFill.green, blue: flowerFill.blue)
    }

    var flowerOutlineColor: Color {
        Color(red: accent.red, green: accent.green, blue: accent.blue)
    }
}
