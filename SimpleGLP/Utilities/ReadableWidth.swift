import SwiftUI

/// Keeps a scrolling screen (ScrollView, List, Form) to a readable column on
/// iPad and any other wide container. The scroll view and its background still
/// span the full width, only the content is inset, so scroll indicators stay at
/// the screen edge. Phone widths are below the cap and unchanged.
private struct ReadableWidth: ViewModifier {
    let maxWidth: CGFloat
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, max(0, (width - maxWidth) / 2), for: .scrollContent)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

extension View {
    /// Content column for scrolling screens. 640 pt matches a large phone.
    func readableWidth(_ maxWidth: CGFloat = 640) -> some View {
        modifier(ReadableWidth(maxWidth: maxWidth))
    }

    /// Centers fixed (non scrolling) content in a column of at most `maxWidth`.
    func centeredColumn(_ maxWidth: CGFloat = 560) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}

extension View {
    /// Apply to a ScrollView's content. The height is measured on the scroll
    /// view's own frame, via the parent, so apply `.measuredScrollHeight` there.
    func centeredInScroll(viewportHeight: CGFloat) -> some View {
        frame(minHeight: UIUserInterfaceIdiom.isPad ? viewportHeight : 0, alignment: .center)
    }

    /// Reports the view's height. Put it on the ScrollView.
    func measuredHeight(_ height: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height.wrappedValue = $0 }
    }

    /// Centered inline title on iPad, where a large title would sit at the
    /// window edge far from the centered column.
    func padInlineTitle() -> some View {
        navigationBarTitleDisplayMode(UIUserInterfaceIdiom.isPad ? .inline : .automatic)
    }
}

extension UIUserInterfaceIdiom {
    /// The Duo split is for the unfolded iPhone Duo only, never an iPad.
    @MainActor static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
}
