// RadialMenuView.swift
// CoreGraphics radial menu. No Metal or SceneKit.

import AppKit

// MARK: - RadialMenuView

final class RadialMenuView: NSView {

    // MARK: - Constants

    private let outerRadius: CGFloat = 130
    private let innerRadius: CGFloat = 48
    private let accentColour = NSColor(red: 0.325, green: 0.290, blue: 0.718, alpha: 1) // #534AB7
    private var segmentCount: Int { model?.segments.count ?? 3 }

    // MARK: - Model

    var model: RadialMenuModel? {
        didSet { model?.view = self; needsDisplay = true }
    }

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let centre = CGPoint(x: bounds.midX, y: bounds.midY)
        let model  = self.model

        // 1. Segment fills + dividers
        drawSegments(ctx: ctx, centre: centre, model: model)

        // 2. Outer progress arc
        if let m = model, m.cumulativeAngle != 0 {
            drawProgressArc(ctx: ctx, centre: centre, angleDeg: m.cumulativeAngle)
        }

        // 3. Segment labels
        drawLabels(centre: centre, model: model)

        // 4. Centre disc
        drawCentreDisc(ctx: ctx, centre: centre, label: model?.centreLabel ?? "Default")

        // 5. Outer ring border
        drawOuterBorder(ctx: ctx, centre: centre)
    }

    // MARK: - Segment fills & dividers

    private func drawSegments(ctx: CGContext, centre: CGPoint, model: RadialMenuModel?) {
        // Segment 0 starts at top (90° in standard CG coords = 270° clock).
        // Angles in radians, measured from positive-x axis, counterclockwise (CG default).
        // Segment 0 (top):   90° → 210°  (clock 270°→30°)
        // Segment 1 (right): 210°→ 330°  (clock 30°→150°)
        // Segment 2 (left):  330°→  90°  (clock 150°→270°)
        let arcSize = (2 * Double.pi) / Double(segmentCount)

        for i in 0..<segmentCount {
            let startAngle = CGFloat(Double.pi / 2) + CGFloat(i) * CGFloat(arcSize)
            let endAngle   = startAngle + CGFloat(arcSize)

            let isHighlighted = model?.highlightedIndex == i

            // Fill
            let fillColour: NSColor = isHighlighted
                ? accentColour.withAlphaComponent(0.85)
                : NSColor.white.withAlphaComponent(0.08)

            ctx.saveGState()
            buildAnnularPath(ctx: ctx, centre: centre, startAngle: startAngle, endAngle: endAngle)
            ctx.setFillColor(fillColour.cgColor)
            ctx.fillPath()
            ctx.restoreGState()

            // Divider line
            ctx.saveGState()
            let lineStart = CGPoint(
                x: centre.x + innerRadius * cos(startAngle),
                y: centre.y + innerRadius * sin(startAngle)
            )
            let lineEnd = CGPoint(
                x: centre.x + outerRadius * cos(startAngle),
                y: centre.y + outerRadius * sin(startAngle)
            )
            ctx.move(to: lineStart)
            ctx.addLine(to: lineEnd)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.15).cgColor)
            ctx.setLineWidth(1)
            ctx.strokePath()
            ctx.restoreGState()
        }
    }

    /// Clips and fills an annular arc segment.
    private func buildAnnularPath(ctx: CGContext, centre: CGPoint,
                                  startAngle: CGFloat, endAngle: CGFloat) {
        ctx.beginPath()
        ctx.move(to: CGPoint(
            x: centre.x + innerRadius * cos(startAngle),
            y: centre.y + innerRadius * sin(startAngle)
        ))
        ctx.addArc(center: centre, radius: outerRadius,
                   startAngle: startAngle, endAngle: endAngle, clockwise: false)
        ctx.addArc(center: centre, radius: innerRadius,
                   startAngle: endAngle, endAngle: startAngle, clockwise: true)
        ctx.closePath()
    }

    // MARK: - Progress arc

    private func drawProgressArc(ctx: CGContext, centre: CGPoint, angleDeg: Double) {
        let startAngle = CGFloat(Double.pi / 2) // top
        let sweep      = CGFloat(angleDeg * Double.pi / 180)
        let endAngle   = startAngle + sweep
        let clockwise  = sweep < 0

        ctx.saveGState()
        ctx.beginPath()
        ctx.addArc(center: centre, radius: outerRadius + 6,
                   startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
        ctx.setStrokeColor(accentColour.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(3)
        ctx.setLineCap(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Labels

    private func drawLabels(centre: CGPoint, model: RadialMenuModel?) {
        let arcSize = (2 * Double.pi) / Double(segmentCount)
        let midRadius: CGFloat = (innerRadius + outerRadius) / 2

        for i in 0..<segmentCount {
            guard let segment = model?.segments[i] else { continue }

            let midAngle = CGFloat(Double.pi / 2) + CGFloat(i) * CGFloat(arcSize) + CGFloat(arcSize) / 2
            let labelCentre = CGPoint(
                x: centre.x + midRadius * cos(midAngle),
                y: centre.y + midRadius * sin(midAngle)
            )

            let isHighlighted = model?.highlightedIndex == i
            let textColour: NSColor = isHighlighted ? .white : NSColor.white.withAlphaComponent(0.65)

            // Glyph
            let glyphAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: textColour,
            ]
            let glyphStr = NSAttributedString(string: segment.glyph, attributes: glyphAttrs)
            let glyphSize = glyphStr.size()
            glyphStr.draw(at: CGPoint(
                x: labelCentre.x - glyphSize.width / 2,
                y: labelCentre.y + 2
            ))

            // Mode name
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: textColour,
            ]
            let nameStr = NSAttributedString(string: segment.label, attributes: nameAttrs)
            let nameSize = nameStr.size()
            nameStr.draw(at: CGPoint(
                x: labelCentre.x - nameSize.width / 2,
                y: labelCentre.y - glyphSize.height - 1
            ))

            // Live value (if present)
            if let live = segment.liveValue {
                let liveAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
                    .foregroundColor: textColour.withAlphaComponent(0.8),
                ]
                let liveStr = NSAttributedString(string: live, attributes: liveAttrs)
                let liveSize = liveStr.size()
                liveStr.draw(at: CGPoint(
                    x: labelCentre.x - liveSize.width / 2,
                    y: labelCentre.y - glyphSize.height - nameSize.height - 2
                ))
            }
        }
    }

    // MARK: - Centre disc

    private func drawCentreDisc(ctx: CGContext, centre: CGPoint, label: String) {
        // Fill
        ctx.saveGState()
        ctx.beginPath()
        ctx.addArc(center: centre, radius: innerRadius - 2, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.06).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // Border
        ctx.saveGState()
        ctx.beginPath()
        ctx.addArc(center: centre, radius: innerRadius - 2, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.2).cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()
        ctx.restoreGState()

        // Text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.55),
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let sz  = str.size()
        str.draw(at: CGPoint(x: centre.x - sz.width / 2, y: centre.y - sz.height / 2))
    }

    // MARK: - Outer border

    private func drawOuterBorder(ctx: CGContext, centre: CGPoint) {
        ctx.saveGState()
        ctx.beginPath()
        ctx.addArc(center: centre, radius: outerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Animations

    func animateAppear() {
        guard let layer else { return }
        layer.opacity = 0
        layer.transform = CATransform3DMakeScale(0.6, 0.6, 1)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.opacity = 1
            layer.transform = CATransform3DIdentity
        }
    }

    func animateDismiss(completion: @escaping () -> Void) {
        guard let layer else { completion(); return }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            layer.opacity = 0
            layer.transform = CATransform3DMakeScale(0.8, 0.8, 1)
        } completionHandler: {
            completion()
        }
    }
}
