import SwiftUI

enum RowDisplayState: Sendable {
    case normal
    case new
    case changed
    case closing

    var backgroundColor: Color {
        switch self {
        case .normal: .clear
        case .new: .green.opacity(0.15)
        case .changed: .yellow.opacity(0.12)
        case .closing: .red.opacity(0.15)
        }
    }
}
