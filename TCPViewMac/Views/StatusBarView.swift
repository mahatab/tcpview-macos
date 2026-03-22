import SwiftUI

struct StatusBarView: View {
    @Bindable var viewModel: ConnectionListViewModel

    var body: some View {
        HStack(spacing: 16) {
            Text("Connections: \(viewModel.filteredConnections.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.filteredConnections.count != viewModel.monitor.totalCount {
                Text("(of \(viewModel.monitor.totalCount) total)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if viewModel.monitor.hasLimitedVisibility {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("Limited visibility — run as admin to see all processes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Refresh: \(viewModel.monitor.refreshInterval.label)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
