//
//  Theme.swift
//  GrowthBookTests
//
//  Created by Volodymyr Nazarkevych on 26.04.2022.
//

import Foundation

open class Themes {}

open class Theme: Themes {
    /// The theme colors.
    var colors: [Level: String]

    /// The theme textual representation.
    var description: String {
        return colors.keys.sorted().map {
            $0.description.withColor(colors[$0])
        }.joined(separator: " ")
    }

    /**
     Creates and returns a theme with the specified colors.

     - parameter trace:   The color for the trace level.
     - parameter debug:   The color for the debug level.
     - parameter info:    The color for the info level.
     - parameter warning: The color for the warning level.
     - parameter error:   The color for the error level.

     - returns: A theme with the specified colors.
     */
    public init(trace: String, debug: String, info: String, warning: String, error: String) {
        colors = [
            .trace: Theme.formatHex(trace),
            .debug: Theme.formatHex(debug),
            .info: Theme.formatHex(info),
            .warning: Theme.formatHex(warning),
            .error: Theme.formatHex(error)
        ]
    }

    /**
     Returns a string representation of the hex color.

     - parameter hex: The hex color.

     - returns: A string representation of the hex color.
     */
    private static func formatHex(_ hex: String) -> String {
        let allowedHexCount = hex.hasPrefix("#") ? 7 : 6
        assert(hex.count == allowedHexCount, "Invalid hex color format: \(hex)")

        let scanner = Scanner(string: hex)
        var hex: UInt64 = 0

        scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#")
        scanner.scanHexInt64(&hex)

        let r = (hex & 0xFF0000) >> 16
        let g = (hex & 0xFF00) >> 8
        let b = (hex & 0xFF)

        return [r, g, b].map({ String($0) }).joined(separator: ",")
    }
}

extension Themes {
    public static let `default` = Theme(
        trace: "#C8C8C8",
        debug: "#0000FF",
        info: "#00FF00",
        warning: "#FFFB00",
        error: "#FF0000"
    )

    public static let dusk = Theme(
        trace: "#FFFFFF",
        debug: "#526EDA",
        info: "#93C96A",
        warning: "#D28F5A",
        error: "#E44347"
    )

    public static let midnight = Theme(
        trace: "#FFFFFF",
        debug: "#527EFF",
        info: "#08FA95",
        warning: "#EB905A",
        error: "#FF4647"
    )

    public static let tomorrow = Theme(
        trace: "#4D4D4C",
        debug: "#4271AE",
        info: "#718C00",
        warning: "#EAB700",
        error: "#C82829"
    )

    public static let tomorrowNight = Theme(
        trace: "#C5C8C6",
        debug: "#81A2BE",
        info: "#B5BD68",
        warning: "#F0C674",
        error: "#CC6666"
    )

    public static let tomorrowNightEighties = Theme(
        trace: "#CCCCCC",
        debug: "#6699CC",
        info: "#99CC99",
        warning: "#FFCC66",
        error: "#F2777A"
    )

    public static let tomorrowNightBright = Theme(
        trace: "#EAEAEA",
        debug: "#7AA6DA",
        info: "#B9CA4A",
        warning: "#E7C547",
        error: "#D54E53"
    )
}
