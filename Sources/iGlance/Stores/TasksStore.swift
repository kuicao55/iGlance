import Foundation
import Combine

class TasksStore: ObservableObject {
    @Published var tasks: [TaskEntry] = []
    @Published var isLoading = false
    @Published var isDegraded = false
    @Published var degradedNote: String?

    private let taskDiscoveryService: TaskDiscoveryService

    init(taskDiscoveryService: TaskDiscoveryService) {
        self.taskDiscoveryService = taskDiscoveryService
    }

    func refresh() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let discoveredTasks = self.taskDiscoveryService.discoverAllTasks()

            DispatchQueue.main.async {
                self.tasks = discoveredTasks
                self.isLoading = false
                self.isDegraded = discoveredTasks.contains { $0.notes != nil }
            }
        }
    }
}
