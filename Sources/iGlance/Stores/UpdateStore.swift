import Foundation

final class UpdateStore: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate(latest: String)
        case available(UpdateInfo)
        case downloading
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var hasUpdate = false

    private let service: UpdateService
    private let defaults: UserDefaults
    private let checkInterval: TimeInterval
    private var isWorking = false

    private enum Keys {
        static let lastCheck = "iGlance.lastUpdateCheck.v1"
    }

    init(
        service: UpdateService = UpdateService(),
        defaults: UserDefaults = .standard,
        checkInterval: TimeInterval = 6 * 60 * 60
    ) {
        self.service = service
        self.defaults = defaults
        self.checkInterval = checkInterval
    }

    var currentVersion: String { AppVersion.current }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .installing:
            return true
        case .idle, .upToDate, .available, .failed:
            return false
        }
    }

    @MainActor
    func checkIfNeeded() async {
        if let lastCheck = defaults.object(forKey: Keys.lastCheck) as? Date,
           Date().timeIntervalSince(lastCheck) < checkInterval {
            return
        }
        await check()
    }

    @MainActor
    func check() async {
        guard !isWorking else { return }
        isWorking = true
        state = .checking
        defer { isWorking = false }

        do {
            let info = try await service.latestRelease()
            defaults.set(Date(), forKey: Keys.lastCheck)

            if AppVersion.compare(info.version, AppVersion.current) == .orderedDescending {
                hasUpdate = true
                state = .available(info)
            } else {
                hasUpdate = false
                state = .upToDate(latest: info.version)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func install(_ info: UpdateInfo) async {
        guard !isWorking else { return }
        guard let assetURL = info.assetURL else {
            state = .failed(UpdateError.noAsset.localizedDescription)
            return
        }

        isWorking = true
        state = .downloading
        defer { isWorking = false }

        do {
            let zip = try await service.download(assetURL)
            let app = try UpdateInstaller.extractApp(from: zip)
            try UpdateInstaller.validate(app, expectedVersion: info.version)

            state = .installing
            try await UpdateInstaller.relaunchReplacingCurrentApp(with: app)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
