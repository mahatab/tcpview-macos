import SwiftUI

struct MainWindow: View {
    @Bindable var viewModel: ConnectionListViewModel

    var body: some View {
        VStack(spacing: 0) {
            ConnectionTableView(viewModel: viewModel)
            Divider()
            StatusBarView(viewModel: viewModel)
        }
        .toolbar {
            ToolbarContent(viewModel: viewModel)
        }
        .navigationTitle("TCPView")
        .frame(minWidth: 800, minHeight: 400)
        .onChange(of: viewModel.filterState.resolveAddresses) { _, newValue in
            if newValue {
                Task { await viewModel.refreshDNS() }
            }
        }
    }
}
