import SwiftUI

struct ToolbarContent: CustomizableToolbarContent {
    @Bindable var viewModel: ConnectionListViewModel

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "search", placement: .automatic) {
            TextField("Search", text: $viewModel.filterState.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 150, maxWidth: 250)
        }

        ToolbarItem(id: "refreshRate", placement: .automatic) {
            Picker("Refresh", selection: $viewModel.monitor.refreshInterval) {
                ForEach(RefreshInterval.allCases) { interval in
                    Text(interval.label).tag(interval)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
        }

        ToolbarItem(id: "pause", placement: .automatic) {
            Button {
                if viewModel.monitor.refreshInterval == .paused {
                    viewModel.monitor.refreshInterval = .twoSeconds
                } else {
                    viewModel.monitor.refreshInterval = .paused
                }
            } label: {
                Label(
                    viewModel.monitor.refreshInterval == .paused ? "Resume" : "Pause",
                    systemImage: viewModel.monitor.refreshInterval == .paused ? "play.fill" : "pause.fill"
                )
            }
        }

        ToolbarItem(id: "refresh", placement: .automatic) {
            Button {
                viewModel.monitor.manualRefresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }

        ToolbarItem(id: "dns", placement: .automatic) {
            Toggle(isOn: $viewModel.filterState.resolveAddresses) {
                Label("DNS", systemImage: "network")
            }
            .toggleStyle(.button)
            .help("Resolve addresses to hostnames")
        }

        ToolbarItem(id: "listening", placement: .automatic) {
            Toggle(isOn: $viewModel.filterState.showListening) {
                Label("Listening", systemImage: "ear")
            }
            .toggleStyle(.button)
            .help("Show listening endpoints")
        }

        ToolbarItem(id: "ipv6", placement: .automatic) {
            Toggle(isOn: $viewModel.filterState.showIPv6) {
                Label("IPv6", systemImage: "6.circle")
            }
            .toggleStyle(.button)
            .help("Show IPv6 connections")
        }
    }
}
