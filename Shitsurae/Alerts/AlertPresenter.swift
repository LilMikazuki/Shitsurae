import Foundation
import ShitsuraeKit

@MainActor
final class AlertPresenter {
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        watch()
    }

    private func watch() {
        withObservationTracking {
            _ = model.alert
        } onChange: { [weak self] in
            // Not a Task and not DispatchQueue.main.async: a modal entered from a main-queue
            // block starves that queue for as long as it is up. Measured — the block that would
            // have dismissed the alert never ran.
            RunLoop.main.perform {
                MainActor.assumeIsolated {
                    self?.watch()
                    self?.presentPending()
                }
            }
        }
    }

    private func presentPending() {
        guard let kind = model.beginPresenting() else { return }
        let confirmed = ShitsuraeAlert.ask(kind)
        Task {
            if confirmed {
                await model.confirmAlert(kind)
            } else {
                model.dismissAlert(kind)
            }
            RunLoop.main.perform { MainActor.assumeIsolated { self.presentPending() } }
        }
    }
}
