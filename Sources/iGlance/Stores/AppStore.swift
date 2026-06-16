import Foundation
import Combine

class AppStore: ObservableObject {
    @Published var activeSection: AppSection = .monitor
    @Published var isPopoverVisible = false

    func popoverDidOpen() {
        isPopoverVisible = true
    }

    func popoverDidClose() {
        isPopoverVisible = false
    }

    func switchToSection(_ section: AppSection) {
        activeSection = section
    }
}
