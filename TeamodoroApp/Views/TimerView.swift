import SwiftUI
import SynchronizedTimerCore

struct TimerView: View {

    @Environment(TimerViewModel.self) private var vm

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                logoRow
                Spacer()
                ringSection
                skewBanner
                Spacer()
                controlButton
                footerLabel
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private var logoRow: some View {
        HStack {
            Text("🍅🍅🍅")
                .font(.system(size: 20))
            Spacer()
            if vm.isRunning {
                Text("CYCLE \(vm.cycleIndex + 1)")
                    .font(.system(size: 11, weight: .medium))
                    .kerning(1.5)
                    .foregroundStyle(vm.currentPhase.ringColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var ringSection: some View {
        // TimelineView fires every ~1 s to refresh cyclePosition without a Timer.
        TimelineView(.animation(minimumInterval: 1, paused: !vm.isRunning)) { _ in
            CycleRingView(
                cyclePosition:    vm.cyclePosition,
                config:           vm.config,
                ringLineWidth:    15,
                dotRadius:        4,
                currentPhase:     vm.currentPhase,
                remainingSeconds: vm.remainingSeconds,
                showCentreText:   true
            )
            .frame(width: 220, height: 220)
        }
    }

    @ViewBuilder
    private var skewBanner: some View {
        if vm.clockSkewWarning {
            Label("Clock out of sync", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.yellow)
                .padding(.top, 14)
        }
    }

    private var controlButton: some View {
        Group {
            if vm.isRunning {
                Button(action: vm.stopSession) {
                    Text("STOP SESSION")
                        .font(.system(size: 12, weight: .medium))
                        .kerning(1.5)
                        .foregroundStyle(Color.gray)
                }
            } else {
                Button(action: vm.startSoloSession) {
                    Text("START FOCUS SESSION")
                        .font(.system(size: 14, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.workColor, lineWidth: 1.5)
                        )
                }
            }
        }
        .padding(.bottom, 10)
    }

    private var footerLabel: some View {
        Text("TEAMODORO · \(vm.roomName)")
            .font(.system(size: 10))
            .kerning(1.5)
            .foregroundStyle(Color.surfaceText)
            .padding(.bottom, 24)
    }
}

// MARK: - Preview

#Preview {
    let vm = TimerViewModel()
    return TimerView()
        .environment(vm)
}
