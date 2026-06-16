import SwiftUI

struct TasksView: View {
    @ObservedObject var tasksStore: TasksStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

            if tasksStore.isLoading {
                    loadingState
            } else if tasksStore.tasks.isEmpty {
                    emptyState
            } else {
                    LazyVStack(spacing: 10) {
                        ForEach(tasksStore.tasks) { task in
                            TaskRowView(task: task)
                        }
                    }
                }

            if tasksStore.isDegraded {
                    degradedBanner
                }
            }
            .padding(12)
        }
        .onAppear {
            tasksStore.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Tasks")
                .font(.title3.weight(.semibold))
            Text("Launch agents, daemons, cron, and at jobs")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var loadingState: some View {
        CardSurfaceView {
            VStack(spacing: 10) {
                ProgressView()
                Text("Scanning scheduled jobs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(14)
        }
    }

    private var emptyState: some View {
        CardSurfaceView {
            VStack(spacing: 10) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.title)
                    .foregroundColor(.secondary)
                Text("No scheduled tasks found")
                    .font(.headline)
                Text("Nothing obvious is registered in the usual locations.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .padding(14)
        }
    }

    private var degradedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Some tasks may be incomplete")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TaskRowView: View {
    let task: TaskEntry

    var body: some View {
        CardSurfaceView {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: task.source.sfSymbolName)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.label)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    Text(task.ruleDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let notes = task.notes {
                        Text(notes)
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .lineLimit(2)
                    }

                    if let nextTrigger = task.nextTrigger {
                        Text(nextTrigger)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if task.isRunning {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Running")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(14)
        }
    }
}
