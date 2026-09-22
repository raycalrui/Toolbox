import SwiftUI

struct SleepPreventionView: View {
    @ObservedObject var controller: SleepPreventionController
    @State private var mode = SleepPreventionMode.system
    @State private var duration = SleepPreventionDuration.oneHour

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep Prevention")
                    .font(.title2.bold())
                Text("Keep your Mac awake for transfers, renders, and other long-running work.")
                    .foregroundStyle(.secondary)
            }

            statusCard

            GroupBox("Mode") {
                VStack(spacing: 0) {
                    ForEach(SleepPreventionMode.allCases) { option in
                        Button {
                            mode = option
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mode == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(mode == option ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.title)
                                        .foregroundStyle(.primary)
                                    Text(option.detail)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        .disabled(controller.isActive)

                        if option != SleepPreventionMode.allCases.last {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 10)
            }

            GroupBox("Duration") {
                Picker("Duration", selection: $duration) {
                    ForEach(SleepPreventionDuration.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(controller.isActive)
                .padding(10)
            }

            if let errorMessage = controller.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            HStack {
                if controller.isActive {
                    Button("Turn Off", systemImage: "stop.fill") {
                        controller.stop()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button("Keep Mac Awake", systemImage: "moon.zzz.fill") {
                        controller.start(mode: mode, duration: duration)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
                Label("Uses the macOS power management API", systemImage: "lock.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 700, minHeight: 560)
    }

    private var statusCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(controller.isActive ? Color.green.opacity(0.16) : Color.secondary.opacity(0.12))
                Image(systemName: controller.isActive ? "sun.max.fill" : "moon.zzz")
                    .font(.system(size: 27))
                    .foregroundStyle(controller.isActive ? .green : .secondary)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(controller.isActive ? "Sleep Prevention Is Active" : "Sleep Prevention Is Off")
                    .font(.title3.bold())
                if controller.isActive {
                    Text(activeStatusText)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Your Mac follows its normal Energy settings.")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(18)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    private var activeStatusText: String {
        let activeModeTitle = controller.activeMode?.title ?? mode.title
        guard let remainingSeconds = controller.remainingSeconds else {
            return "\(activeModeTitle) · Until turned off"
        }
        let totalSeconds = max(0, Int(remainingSeconds.rounded(.up)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return "\(activeModeTitle) · \(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds)) remaining"
        }
        return "\(activeModeTitle) · \(minutes):\(String(format: "%02d", seconds)) remaining"
    }
}

#Preview {
    SleepPreventionView(controller: SleepPreventionController())
}
