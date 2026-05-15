import SwiftUI
import SynchronizedTimerCore

/// The shared ring canvas — draws phase arcs, tick marks, position dot, and centre text.
/// Used on iOS main screen, macOS popover, Live Activity, and widget.
struct CycleRingView: View {

    // MARK: - Inputs

    /// Elapsed seconds within the current cycle  (0 ..< cycleDuration).
    let cyclePosition:   Double
    let config:          Configuration
    let ringLineWidth:   CGFloat
    let dotRadius:       CGFloat
    let currentPhase:    Phase
    let remainingSeconds: Int
    /// Pass `false` on small surfaces (widget, Live Activity compact).
    let showCentreText:  Bool

    init(
        cyclePosition:    Double,
        config:           Configuration = .default,
        ringLineWidth:    CGFloat       = 15,
        dotRadius:        CGFloat       = 4,
        currentPhase:     Phase         = .work,
        remainingSeconds: Int           = 1_500,
        showCentreText:   Bool          = true
    ) {
        self.cyclePosition    = cyclePosition
        self.config           = config
        self.ringLineWidth    = ringLineWidth
        self.dotRadius        = dotRadius
        self.currentPhase     = currentPhase
        self.remainingSeconds = remainingSeconds
        self.showCentreText   = showCentreText
    }

    // MARK: - Helpers

    private var cycleDuration: Double { config.cycleDuration }

    private var sequence: [(phase: Phase, boundary: Double)] {
        TimerCalculator.phaseSequence(for: config)
    }

    private var formattedTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ringCanvas
            if showCentreText { centreText }
        }
    }

    // MARK: - Ring canvas

    private var ringCanvas: some View {
        Canvas { context, size in
            let cx     = size.width  / 2
            let cy     = size.height / 2
            let radius = min(cx, cy) - ringLineWidth / 2 - dotRadius - 2

            drawPhaseArcs(context: context, cx: cx, cy: cy, radius: radius)
            drawTickMarks(context: context, cx: cx, cy: cy, radius: radius)
            drawPositionDot(context: context, cx: cx, cy: cy, radius: radius)
        }
    }

    private func drawPhaseArcs(
        context: GraphicsContext, cx: CGFloat, cy: CGFloat, radius: CGFloat
    ) {
        var prev: Double = 0
        for (phase, boundary) in sequence {
            let start = Angle(radians: (prev     / cycleDuration) * 2 * .pi - .pi / 2)
            let end   = Angle(radians: (boundary / cycleDuration) * 2 * .pi - .pi / 2)
            var path = Path()
            path.addArc(center: CGPoint(x: cx, y: cy),
                        radius: radius,
                        startAngle: start, endAngle: end, clockwise: false)
            context.stroke(
                path,
                with: .color(phase.ringColor),
                style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .butt)
            )
            prev = boundary
        }
    }

    private func drawTickMarks(
        context: GraphicsContext, cx: CGFloat, cy: CGFloat, radius: CGFloat
    ) {
        for i in 0 ..< 60 {
            let angle   = Double(i) / 60.0 * 2 * .pi - .pi / 2
            let isMajor = i % 5 == 0
            let len     = isMajor ? ringLineWidth * 0.9 : ringLineWidth * 0.45
            let r1      = radius - len / 2
            let r2      = radius + len / 2
            var tick = Path()
            tick.move(to:    CGPoint(x: cx + cos(angle) * r1, y: cy + sin(angle) * r1))
            tick.addLine(to: CGPoint(x: cx + cos(angle) * r2, y: cy + sin(angle) * r2))
            context.stroke(
                tick,
                with: .color(isMajor ? .tickMajor : .tickMinor),
                style: StrokeStyle(lineWidth: isMajor ? 2 : 1)
            )
        }
    }

    private func drawPositionDot(
        context: GraphicsContext, cx: CGFloat, cy: CGFloat, radius: CGFloat
    ) {
        let angle = (cyclePosition / cycleDuration) * 2 * .pi - .pi / 2
        let dc    = CGPoint(x: cx + cos(angle) * radius, y: cy + sin(angle) * radius)
        var dot   = Path()
        dot.addEllipse(in: CGRect(x: dc.x - dotRadius, y: dc.y - dotRadius,
                                  width: dotRadius * 2, height: dotRadius * 2))
        context.fill(dot, with: .color(.white))
    }

    // MARK: - Centre text overlay

    private var centreText: some View {
        VStack(spacing: 6) {
            Text(currentPhase.displayLabel)
                .font(.system(size: 13, weight: .medium))
                .kerning(3)
                .foregroundStyle(currentPhase.ringColorMuted)

            Text(formattedTime)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(currentPhase.ringColor)
        }
    }
}

// MARK: - Preview

#Preview("Work phase — mid-session") {
    CycleRingView(
        cyclePosition:    750,
        currentPhase:     .work,
        remainingSeconds: 750
    )
    .frame(width: 220, height: 220)
    .background(Color.black)
}

#Preview("Short break") {
    CycleRingView(
        cyclePosition:    1_650,
        currentPhase:     .shortBreak,
        remainingSeconds: 150
    )
    .frame(width: 220, height: 220)
    .background(Color.black)
}
