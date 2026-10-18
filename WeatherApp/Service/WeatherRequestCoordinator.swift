import Foundation

@MainActor
final class WeatherRequestCoordinator {
    private var task: Task<Void, Never>?
    private var language: String?

    func perform(language: String, operation: @escaping @MainActor () async -> Void) async {
        // A language change supersedes older requests. Same-language refreshes
        // wait for the current load instead of ending the refresh indicator early.
        while let pending = task {
            if self.language == language && !pending.isCancelled {
                await pending.value
                return
            }
            guard !Task.isCancelled else { return }
            pending.cancel()
            await pending.value
            guard !Task.isCancelled else { return }
        }
        let task = Task { @MainActor in
            defer {
                self.task = nil
                self.language = nil
            }
            await operation()
        }
        self.task = task
        self.language = language
        await task.value
    }
}
