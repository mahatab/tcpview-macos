import SwiftUI

@main
struct TCPViewMacApp: App {
    @State private var viewModel = ConnectionListViewModel()

    var body: some Scene {
        WindowGroup {
            MainWindow(viewModel: viewModel)
                .onAppear {
                    viewModel.start()
                }
                .onDisappear {
                    viewModel.stop()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandMenu("Connections") {
                Button("Refresh") {
                    viewModel.monitor.manualRefresh()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Toggle("Resolve Addresses", isOn: $viewModel.filterState.resolveAddresses)
                    .keyboardShortcut("d", modifiers: .command)

                Toggle("Show Listening", isOn: $viewModel.filterState.showListening)

                Toggle("Show IPv6", isOn: $viewModel.filterState.showIPv6)

                Divider()

                Picker("Refresh Rate", selection: $viewModel.monitor.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
            }
        }
        .defaultSize(width: 1100, height: 600)
    }
}
