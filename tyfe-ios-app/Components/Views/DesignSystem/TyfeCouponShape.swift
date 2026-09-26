import SwiftUI

/// A ticket silhouette: a rounded rectangle with concave notches cut into the
/// top and bottom edges at the tear line.
struct TyfeCouponShape: Shape {

    /// Distance from the leading edge to the perforation line.
    var tearOffset: CGFloat
    /// Radius of the concave notches cut into the top and bottom edges.
    var notchRadius: CGFloat
    /// Radius of the outer corners.
    var cornerRadius: CGFloat

    init(
        tearOffset: CGFloat,
        notchRadius: CGFloat = 10,
        cornerRadius: CGFloat = TyfeRadius.card
    ) {
        self.tearOffset = tearOffset
        self.notchRadius = notchRadius
        self.cornerRadius = cornerRadius
    }

    func path(in rect: CGRect) -> Path {
        let tearX = clampedTearX(in: rect)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
        addTopEdge(to: &path, in: rect, tearX: tearX)
        addRightEdge(to: &path, in: rect)
        addBottomEdge(to: &path, in: rect, tearX: tearX)
        addLeftEdge(to: &path, in: rect)
        path.closeSubpath()
        return path
    }

    private func clampedTearX(in rect: CGRect) -> CGFloat {
        min(
            max(rect.minX + tearOffset, rect.minX + cornerRadius + notchRadius),
            rect.maxX - cornerRadius - notchRadius
        )
    }

    private func addTopEdge(to path: inout Path, in rect: CGRect, tearX: CGFloat) {
        let control = circleControlOffset(for: notchRadius)

        path.addLine(to: CGPoint(x: tearX - notchRadius, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: tearX, y: rect.minY + notchRadius),
            control1: CGPoint(x: tearX - notchRadius, y: rect.minY + control),
            control2: CGPoint(x: tearX - control, y: rect.minY + notchRadius)
        )
        path.addCurve(
            to: CGPoint(x: tearX + notchRadius, y: rect.minY),
            control1: CGPoint(x: tearX + control, y: rect.minY + notchRadius),
            control2: CGPoint(x: tearX + notchRadius, y: rect.minY + control)
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        addTopRightCorner(to: &path, in: rect)
    }

    private func addRightEdge(to path: inout Path, in rect: CGRect) {
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        addBottomRightCorner(to: &path, in: rect)
    }

    private func addBottomEdge(to path: inout Path, in rect: CGRect, tearX: CGFloat) {
        let control = circleControlOffset(for: notchRadius)

        path.addLine(to: CGPoint(x: tearX + notchRadius, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: tearX, y: rect.maxY - notchRadius),
            control1: CGPoint(x: tearX + notchRadius, y: rect.maxY - control),
            control2: CGPoint(x: tearX + control, y: rect.maxY - notchRadius)
        )
        path.addCurve(
            to: CGPoint(x: tearX - notchRadius, y: rect.maxY),
            control1: CGPoint(x: tearX - control, y: rect.maxY - notchRadius),
            control2: CGPoint(x: tearX - notchRadius, y: rect.maxY - control)
        )
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        addBottomLeftCorner(to: &path, in: rect)
    }

    private func addLeftEdge(to path: inout Path, in rect: CGRect) {
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        addTopLeftCorner(to: &path, in: rect)
    }

    private func addTopRightCorner(to path: inout Path, in rect: CGRect) {
        let control = circleControlOffset(for: cornerRadius)
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
            control1: CGPoint(x: rect.maxX - cornerRadius + control, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius - control)
        )
    }

    private func addBottomRightCorner(to path: inout Path, in rect: CGRect) {
        let control = circleControlOffset(for: cornerRadius)
        path.addCurve(
            to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius + control),
            control2: CGPoint(x: rect.maxX - cornerRadius + control, y: rect.maxY)
        )
    }

    private func addBottomLeftCorner(to path: inout Path, in rect: CGRect) {
        let control = circleControlOffset(for: cornerRadius)
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
            control1: CGPoint(x: rect.minX + cornerRadius - control, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius + control)
        )
    }

    private func addTopLeftCorner(to path: inout Path, in rect: CGRect) {
        let control = circleControlOffset(for: cornerRadius)
        path.addCurve(
            to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + cornerRadius - control),
            control2: CGPoint(x: rect.minX + cornerRadius - control, y: rect.minY)
        )
    }

    /// Control offset for approximating a quarter circle with a cubic curve.
    private func circleControlOffset(for radius: CGFloat) -> CGFloat {
        0.5523 * radius
    }
}

/// The vertical dashed tear line between a coupon stub and its body.
struct TyfePerforationLine: Shape {

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

#Preview("Coupon shape") {
    TyfeCouponShape(tearOffset: 92)
        .fill(TyfeEditorialPalette.paper)
        .overlay {
            TyfeCouponShape(tearOffset: 92)
                .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.standard)
        }
        .frame(width: 280, height: 180)
        .padding(TyfeSpacing.card)
        .background(TyfeEditorialPalette.canvas)
}
