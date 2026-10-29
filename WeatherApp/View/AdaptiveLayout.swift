import SwiftUI

/// Layout decisions are made from the width a screen actually gets, not from the device,
/// so they also hold for iPad, Split View and the iPhone Duo (open display, either orientation).
enum AdaptiveLayout {
    /// Smallest content width at which a regular-width environment places areas side by side.
    static let sideBySideMinWidth: CGFloat = 600
    static let singleColumnMaxWidth: CGFloat = 680
    static let dashboardMaxWidth: CGFloat = 1100
}

/// Two stacks side by side when there is room, otherwise one column.
/// The width is measured (not `ViewThatFits`, which compares ideal sizes and never fits long text), and
/// `AnyLayout` keeps every child's identity when the width changes, e.g. when the Duo is folded or unfolded.
struct TwoColumnWhenWide<Leading: View, Trailing: View>: View {
    var spacing: CGFloat = 20
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing
    @State private var isWide = false

    var body: some View {
        let layout = isWide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: spacing))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
        layout {
            column { leading }
            column { trailing }
        }
        .frame(maxWidth: isWide ? .infinity : AdaptiveLayout.singleColumnMaxWidth, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .onWideLayoutChange { isWide = $0 }
        .layoutIdentifier(isWide: isWide)
    }

    private func column<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: spacing) { content() }
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

extension Color {
    /// Cards and rows that sit on `systemGroupedBackground`. The plain secondary colors equal that background
    /// in light mode, so such cards disappeared; the grouped variants stay distinct in both modes.
    static var groupedCard: Color { Color(.secondarySystemGroupedBackground) }
    /// An inset area inside a `groupedCard`.
    static var groupedCardInset: Color { Color(.tertiarySystemGroupedBackground) }
}

extension View {
    /// Reports whether this view should use side-by-side layouts: the environment has a regular
    /// horizontal size class (iPad, the iPhone Duo's inner display, large iPhones in landscape) and the
    /// view itself is at least `AdaptiveLayout.sideBySideMinWidth` wide, which keeps narrow Split View
    /// panes and odd containers on the single column.
    func onWideLayoutChange(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(WideLayoutReader(action: action))
    }

    /// Exposes the active layout to UI tests ("layout.sideBySide" or "layout.single").
    func layoutIdentifier(isWide: Bool) -> some View {
        accessibilityElement(children: .contain)
            .accessibilityIdentifier(isWide ? "layout.sideBySide" : "layout.single")
    }
}

private struct WideLayoutReader: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var width: CGFloat = 0
    let action: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0; report() }
            .onChange(of: sizeClass, initial: true) { report() }
    }

    private func report() {
        action(sizeClass == .regular && width >= AdaptiveLayout.sideBySideMinWidth)
    }
}
