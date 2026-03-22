import SwiftUI

struct WhoisSheet: View {
    let address: String
    @State private var result: WhoisService.WhoisResult?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WHOIS: \(address)")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            if isLoading {
                ProgressView("Looking up...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let result {
                Group {
                    if let org = result.organization {
                        LabeledContent("Organization", value: org)
                    }
                    if let country = result.country {
                        LabeledContent("Country", value: country)
                    }
                    if let range = result.netRange {
                        LabeledContent("Net Range", value: range)
                    }
                }
                .font(.body)

                Divider()

                ScrollView {
                    Text(result.rawResponse)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("No WHOIS data found for \(address)")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .task {
            result = await WhoisService.lookup(address)
            isLoading = false
        }
    }
}
