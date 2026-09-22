import SwiftUI

struct CloudflareDDNSView: View {
    @ObservedObject private var model: CloudflareDDNSViewModel

    init(model: CloudflareDDNSViewModel) {
        self.model = model
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    credentialsSection
                    recordSection(.ipv4)
                    recordSection(.ipv6)
                    automationSection
                    statusSection
                }
                .padding(20)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cloudflare DDNS").font(.title2.bold())
                Text("Keep A and AAAA records synchronized with your public addresses.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isUpdating { ProgressView().controlSize(.small) }
            Button("Update Now", systemImage: "arrow.triangle.2.circlepath", action: model.updateNow)
                .buttonStyle(.borderedProminent)
                .disabled(model.isUpdating)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var credentialsSection: some View {
        GroupBox("Cloudflare Credentials") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Zone ID") {
                    TextField("Cloudflare Zone ID", text: $model.configuration.zoneID)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 340)
                }
                LabeledContent("API Token") {
                    HStack {
                        SecureField(model.hasSavedToken ? "Enter a replacement token" : "Token with DNS Edit permission", text: $model.tokenInput)
                            .textFieldStyle(.roundedBorder)
                        Button("Save", action: model.saveToken).disabled(model.tokenInput.isEmpty)
                        Button("Delete", role: .destructive, action: model.deleteToken)
                            .disabled(!model.hasSavedToken)
                    }
                    .frame(minWidth: 500)
                }
                HStack(spacing: 6) {
                    Image(systemName: model.hasSavedToken ? "checkmark.shield.fill" : "shield")
                        .foregroundStyle(model.hasSavedToken ? .green : .secondary)
                    Text(model.tokenMessage ?? (model.hasSavedToken
                        ? "A token is stored in macOS Keychain. Its value is never displayed or logged."
                        : "The token is stored only in macOS Keychain."))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(6)
        }
    }

    private func recordSection(_ family: DDNSAddressFamily) -> some View {
        let record = family == .ipv4 ? $model.configuration.ipv4 : $model.configuration.ipv6
        return GroupBox("\(family.recordType) Record (\(family.rawValue))") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Update this record", isOn: record.isEnabled)
                LabeledContent("Record name") {
                    TextField(family == .ipv4 ? "home.example.com" : "home-v6.example.com", text: record.name)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!record.wrappedValue.isEnabled)
                }
                LabeledContent("Record ID") {
                    SecureField("Cloudflare DNS Record ID", text: record.recordID)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!record.wrappedValue.isEnabled)
                }
            }
            .padding(6)
        }
    }

    private var automationSection: some View {
        GroupBox("Update Settings") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Cloudflare proxy", isOn: $model.configuration.proxied)
                LabeledContent("TTL") { Text("Auto (1)").foregroundStyle(.secondary) }
                LabeledContent("Schedule") {
                    Picker("Schedule", selection: $model.interval) {
                        ForEach(DDNSUpdateInterval.allCases) { interval in
                            Text(interval.label).tag(interval)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
                if let nextUpdateAt = model.nextUpdateAt {
                    Text("Next update: \(nextUpdateAt.formatted(date: .omitted, time: .shortened)). Automatic updates run only while Toolbox is open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(6)
        }
    }

    private var statusSection: some View {
        GroupBox("Status") {
            VStack(spacing: 0) {
                statusRow(.ipv4, status: model.ipv4Status)
                Divider()
                statusRow(.ipv6, status: model.ipv6Status)
            }
            .padding(6)
        }
    }

    private func statusRow(_ family: DDNSAddressFamily, status: DDNSProtocolStatus) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(family.rawValue).fontWeight(.medium).frame(width: 50, alignment: .leading)
            switch status {
            case .idle:
                Image(systemName: "circle").foregroundStyle(.secondary)
                Text("Not updated").foregroundStyle(.secondary)
            case .updating:
                ProgressView().controlSize(.small)
                Text("Fetching public address and updating Cloudflare…").foregroundStyle(.secondary)
            case .success(let address, let date):
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(address).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                Spacer()
                Text(date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}
