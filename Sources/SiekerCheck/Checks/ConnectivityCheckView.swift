import SwiftUI

struct ConnectivityCheckView: View {
    @State private var addresses: [NetworkAddress] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CheckSection(title: "Network interfaces") {
                    Text("Every interface the system knows about, with its addresses. Wi-Fi and Ethernet "
                         + "should each show a routable IPv4 address while connected.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if addresses.isEmpty {
                        Text("No addresses reported.").foregroundStyle(.secondary)
                    } else {
                        ForEach(addresses) { entry in
                            HStack {
                                Image(systemName: entry.family == "IPv6" ? "6.circle" : "4.circle")
                                    .foregroundStyle(entry.isLoopback ? Color.secondary : Color.accentColor)
                                Text(entry.interface).frame(width: 70, alignment: .leading).fontWeight(.medium)
                                Text(entry.family).font(.caption).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
                                Text(entry.address).font(.system(.body, design: .monospaced))
                                Spacer()
                                if entry.isLoopback {
                                    Text("loopback").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }

                    Button("Refresh") { addresses = ConnectivityInfo.addresses() }
                }

                CheckSection(title: "What to check") {
                    bullet("Connected Wi-Fi should show an address on en0 (IPv4, 192.168.x.x or similar).")
                    bullet("Disconnect your network and press Refresh: that interface's address should disappear.")
                    bullet("A missing Wi-Fi interface entirely can point to a hardware fault rather than a router problem.")
                }

                CheckOutcomeControls(module: .connectivity)
            }
            .padding(20)
        }
        .onAppear { addresses = ConnectivityInfo.addresses() }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 4)).padding(.top, 8)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
