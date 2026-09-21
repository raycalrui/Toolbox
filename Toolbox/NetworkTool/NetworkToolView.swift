import SwiftUI

struct NetworkToolsView: View {
    private enum Page: String, CaseIterable, Identifiable {
        case addresses = "IP Addresses"
        case ping = "Ping"
        case parser = "IP / CIDR Parser"

        var id: Self { self }
    }

    @StateObject private var model: NetworkToolViewModel
    @State private var page: Page = .addresses

    init(service: any NetworkServiceProtocol = NetworkService()) {
        _model = StateObject(wrappedValue: NetworkToolViewModel(service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Picker("Network tool", selection: $page) {
                ForEach(Page.allCases) { page in Text(page.rawValue).tag(page) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(20)

            Group {
                switch page {
                case .addresses: addressesPage
                case .ping: pingPage
                case .parser: parserPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { model.refreshLocalAddresses() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Tools").font(.title2.bold())
                Text("Inspect addresses, test reachability, and analyze IP networks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if page == .addresses {
                Button("Refresh", systemImage: "arrow.clockwise", action: model.refreshAll)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var addressesPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Public Addresses").font(.headline)
                HStack(alignment: .top, spacing: 14) {
                    PublicAddressCard(title: "Public IPv4", state: model.publicIPv4)
                    PublicAddressCard(title: "Public IPv6", state: model.publicIPv6)
                }
                Text("Click Refresh to query ipify.org directly. No public address result is stored by Toolbox.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Local Interfaces").font(.headline)
                    Spacer()
                    Button("Refresh Local", systemImage: "arrow.clockwise", action: model.refreshLocalAddresses)
                        .labelStyle(.iconOnly)
                        .help("Refresh local interfaces")
                }
                if let error = model.localAddressError {
                    ErrorMessage(text: error)
                } else if model.localAddresses.isEmpty {
                    ContentUnavailableView("No Addresses", systemImage: "network", description: Text("No active IP interfaces were found."))
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(model.localAddresses.enumerated()), id: \.element.id) { index, address in
                            HStack {
                                Text(address.name).fontWeight(.medium).frame(width: 90, alignment: .leading)
                                Text(address.family.rawValue).foregroundStyle(.secondary).frame(width: 48, alignment: .leading)
                                Text(address.address).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                Spacer()
                            }
                            .padding(12)
                            if index < model.localAddresses.count - 1 { Divider() }
                        }
                    }
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var pingPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                TextField("Hostname or IP address", text: $model.pingHost)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(model.startPing)
                Picker("IP version", selection: $model.pingFamily) {
                    ForEach(NetworkAddressFamily.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
                if model.isPinging {
                    Button("Cancel", role: .destructive, action: model.cancelPing)
                } else {
                    Button("Run Ping", systemImage: "waveform.path.ecg", action: model.startPing)
                        .buttonStyle(.borderedProminent)
                        .disabled(model.pingHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            GroupBox("Output") {
                ScrollView([.horizontal, .vertical]) {
                    Text(model.pingOutput.isEmpty ? "Run a four-packet ping to see latency, packet loss, and statistics." : model.pingOutput)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(model.pingOutput.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private var parserPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    TextField("Address or CIDR, for example 192.168.1.10/24", text: $model.parserInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(model.parseAddress)
                    Button("Analyze", systemImage: "magnifyingglass", action: model.parseAddress)
                        .buttonStyle(.borderedProminent)
                        .disabled(model.parserInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let error = model.parserError {
                    ErrorMessage(text: error)
                }
                if let result = model.parserResult {
                    VStack(spacing: 0) {
                        ResultRow(label: "Version", value: result.version.rawValue)
                        ResultRow(label: "Normalized", value: result.normalizedAddress)
                        ResultRow(label: "Prefix", value: "/\(result.prefixLength)")
                        ResultRow(label: "Network", value: "\(result.networkAddress)/\(result.prefixLength)")
                        ResultRow(label: "Range Start", value: result.rangeStart)
                        ResultRow(label: "Range End", value: result.rangeEnd)
                        ResultRow(label: "Address Count", value: result.totalAddresses)
                        ResultRow(label: "Scope", value: result.scope, showsDivider: false)
                    }
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                } else if model.parserError == nil {
                    ContentUnavailableView(
                        "Analyze an IP Network",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text("Enter an IPv4 or IPv6 address, optionally followed by a CIDR prefix.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

private struct PublicAddressCard: View {
    let title: String
    let state: RemoteValueState

    var body: some View {
        GroupBox(title) {
            HStack(spacing: 10) {
                switch state {
                case .idle:
                    Text("Not loaded").foregroundStyle(.secondary)
                case .loading:
                    ProgressView().controlSize(.small)
                    Text("Loading…").foregroundStyle(.secondary)
                case .loaded(let address):
                    Text(address).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                case .failed(let message):
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(message).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ErrorMessage: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ResultRow: View {
    let label: String
    let value: String
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
                Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                Spacer()
            }
            .padding(12)
            if showsDivider { Divider() }
        }
    }
}
