import SwiftUI

struct ServiceCardView: View {
    let binding: ServiceBinding
    let runtime: ServiceRuntime
    let memoryHistory: [Double]
    let hasToken: Bool
    let panelURL: URL?

    let onStart: () -> Void
    let onOpenPanel: () -> Void
    let onStop: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsGroups = false
    @State private var confirmingDelete = false

    var body: some View {
        CardSurfaceView(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 10) {
                titleRow

                if let target = targetDescription {
                    Text(target)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(target)
                }

                metaRow

                if let error = runtime.lastError {
                    errorLine(error)
                }

                if !binding.startCommandApproved && !binding.readOnly {
                    inlineWarning("Control is not approved. Edit the service to allow iGlance to start and stop it.")
                }

                if let baseURL = binding.baseURL, !ServiceManifestParser.isLoopback(baseURL) {
                    inlineWarning("Non-loopback service address: \(baseURL.absoluteString)")
                }

                memorySection
                controls
            }
            .padding(Design.Spacing.cardContent)
        }
        .alert("Delete \(binding.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The binding and its stored token are removed. The service itself is not stopped.")
        }
    }

    // MARK: - Header

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 3 }
                .accessibilityHidden(true)

            Text(binding.name)
                .font(.body.weight(.semibold))
                .lineLimit(1)

            if binding.kind != .manifest {
                Text(binding.kind.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let version = binding.serviceVersion {
                Text("v\(version)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let serviceID = binding.serviceID {
                Text(serviceID)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if hasToken {
                Image(systemName: "key.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .help("Token stored in Keychain")
                    .accessibilityLabel("Token stored in Keychain")
            }

            if binding.readOnly {
                Image(systemName: "eye")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .help("Read-only")
                    .accessibilityLabel("Read-only")
            }

            Spacer(minLength: 6)

            Text(runtime.state.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(statusColor)
                .accessibilityLabel("Status: \(runtime.state.label)")
        }
    }

    private var metaRow: some View {
        HStack(spacing: 10) {
            if let uptime = runtime.uptimeSec, runtime.state == .running || runtime.state == .paused {
                metaItem(icon: "clock", text: Formatters.formatDuration(uptime))
            }

            if let pid = runtime.pid {
                metaItem(icon: "number", text: "pid \(pid)")
            }

            if let baseURL = binding.baseURL {
                metaItem(icon: "network", text: baseURL.host.map { host in
                    if let port = baseURL.port { return "\(host):\(port)" }
                    return host
                } ?? baseURL.absoluteString)
            }

            Spacer(minLength: 0)

            if runtime.state == .offline, let lastSeen = runtime.lastSeen {
                Text("last seen \(Formatters.formatRelativeDate(lastSeen))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if runtime.state == .starting {
                Text("waiting for manifest…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if runtime.state == .stopping {
                Text("shutting down…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// What this card is actually observing, for non-manifest kinds.
    private var targetDescription: String? {
        switch binding.kind {
        case .manifest:
            return nil
        case .launchd:
            return binding.trimmedLaunchdLabel.map { "launchd · \($0)" }
        case .process:
            if let pidFile = binding.trimmedPIDFile {
                return "pidfile · \(pidFile)"
            }
            return binding.trimmedProcessPattern.map { "pgrep -f · \($0)" }
        case .command:
            return binding.trimmedStatusCommand.map { "status · \($0)" }
        }
    }

    private func metaItem(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .accessibilityHidden(true)
            Text(text)
                .font(.caption2)
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Memory

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Memory")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(memoryTotalText)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()

                if let memory = runtime.memory, memory.available, !memory.groups.isEmpty {
                    Button {
                        toggleGroups()
                    } label: {
                        HStack(spacing: 3) {
                            Text("\(memory.groups.count) groups")
                                .font(.caption2)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .rotationEffect(.degrees(showsGroups ? 180 : 0))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Memory groups")
                    .accessibilityValue(showsGroups ? "Expanded" : "Collapsed")
                }
            }

            if memoryHistory.count > 1 {
                SparklineView(values: memoryHistory, color: .teal)
                    .frame(height: 24)
            }

            if let memory = runtime.memory {
                if !memory.available {
                    Text(memory.error ?? "Memory is not available for this service.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if showsGroups {
                    VStack(spacing: 4) {
                        ForEach(memory.groups) { group in
                            memoryGroupRow(group)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private var memoryTotalText: String {
        guard let memory = runtime.memory, memory.available else { return "—" }
        return Formatters.formatByteCount(memory.totalRssBytes)
    }

    private func memoryGroupRow(_ group: ServiceMemoryGroup) -> some View {
        HStack(spacing: 6) {
            Text(group.label)
                .font(.caption2)
                .lineLimit(1)

            if group.processes > 0 {
                Text("\(group.processes) proc")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(Formatters.formatByteCount(group.rssBytes))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func toggleGroups() {
        if reduceMotion {
            showsGroups.toggle()
        } else {
            withAnimation(Design.Motion.disclosure) {
                showsGroups.toggle()
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 8) {
            if showsStartControl {
                Button {
                    onStart()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .disabled(runtime.isBusy || startDisabled)
                .help(startHelp)
            }

            if binding.kind == .manifest {
                if runtime.state == .paused {
                    Button {
                        onResume()
                    } label: {
                        Label("Resume", systemImage: "play.circle")
                    }
                    .disabled(runtime.isBusy || binding.resumePath == nil)
                } else {
                    Button {
                        onPause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .disabled(runtime.isBusy || runtime.state != .running || binding.pausePath == nil)
                }
            }

            if showsStopControl {
                Button {
                    onStop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(runtime.isBusy || runtime.state == .offline || stopDisabled)
                .help(stopHelp)
            }

            if panelURL != nil {
                Button {
                    onOpenPanel()
                } label: {
                    Image(systemName: "safari")
                }
                .disabled(runtime.isBusy || !canOpenPanel)
                .help("Open Panel")
                .accessibilityLabel("Open Panel")
                .accessibilityHint(panelURL?.absoluteString ?? "")
            }

            Spacer(minLength: 0)

            if runtime.isBusy {
                ProgressView()
                    .controlSize(.mini)
            }

            Menu {
                Button("Edit Service…", action: onEdit)

                if binding.togglePath != nil {
                    Button("Toggle Pause", action: onToggle)
                        .disabled(runtime.isBusy)
                }

                Divider()

                Button("Delete Service", role: .destructive) {
                    confirmingDelete = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
            .accessibilityLabel("More")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    /// Manifest cards keep showing Start/Stop and disable them when they do not
    /// apply. Provider kinds hide the controls entirely when the binding is
    /// read-only or has no command.
    private var showsStartControl: Bool {
        binding.kind == .manifest || binding.canStart
    }

    private var showsStopControl: Bool {
        binding.kind == .manifest || binding.canStop
    }

    private var startDisabled: Bool {
        if binding.kind == .manifest {
            return !binding.startCommandApproved
        }
        return runtime.state == .running || runtime.state == .starting
    }

    private var stopDisabled: Bool {
        if binding.kind == .manifest {
            return binding.stopPath == nil
        }
        return false
    }

    private var startHelp: String {
        switch binding.kind {
        case .manifest: return "Run the start command and read its manifest"
        case .launchd: return "Ask launchd to start the job"
        case .process, .command: return "Run the start command"
        }
    }

    private var stopHelp: String {
        switch binding.kind {
        case .manifest: return "Ask the service to stop"
        case .launchd: return "Unload the job with launchctl bootout"
        case .process, .command: return "Run the stop command"
        }
    }

    // MARK: - Helpers

    /// The panel is only reachable once the service is actually up.
    private var canOpenPanel: Bool {
        runtime.state == .running || runtime.state == .paused
    }

    private var statusColor: Color {
        switch runtime.state {
        case .running: return .green
        case .paused: return .orange
        case .stopping: return .yellow
        case .starting: return .blue
        case .unauthorized: return .red
        case .offline, .unknown: return .gray
        }
    }

    private func errorLine(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.orange)
                .padding(.top, 1)
                .accessibilityHidden(true)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func inlineWarning(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 9))
                .foregroundStyle(.orange)
                .padding(.top, 1)
                .accessibilityHidden(true)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
