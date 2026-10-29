import SwiftUI

/// Shared visual constants so the popover keeps one consistent rhythm.
enum Design {
    enum Layout {
        static let popoverWidth: CGFloat = 400
        static let popoverHeight: CGFloat = 545
    }

    enum Radius {
        static let card: CGFloat = 14
        static let panel: CGFloat = 12
        static let chip: CGFloat = 10
        static let field: CGFloat = 6
    }

    enum Spacing {
        /// One inset for every page edge and every card's interior.
        static let page: CGFloat = 16
        static let cardContent: CGFloat = 16
        /// Gap between cards, headers, and other stacked elements.
        static let section: CGFloat = 16
    }

    enum Typography {
        static let cardTitle = Font.system(size: 13, weight: .bold, design: .rounded)
        static let cardDetail = Font.system(size: 11, weight: .medium, design: .rounded)
        static let cardCaption = Font.system(size: 10, weight: .medium, design: .rounded)
    }

    enum Motion {
        static let cardFlip = Animation.spring(response: 0.38, dampingFraction: 1.0)
        static let gauge = Animation.easeInOut(duration: 0.45)
        static let bar = Animation.easeInOut(duration: 0.3)
        static let selection = Animation.snappy(duration: 0.26)
        static let section = Animation.easeInOut(duration: 0.22)
        static let hover = Animation.easeOut(duration: 0.12)
        static let disclosure = Animation.easeInOut(duration: 0.18)
        static let number = Animation.snappy(duration: 0.3)
    }
}
