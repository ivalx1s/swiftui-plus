import SwiftUI

public struct PreventDisplaySleepAction: Sendable {
    @MainActor
    public func callAsFunction(_ toggle: Bool) {
        UIApplication.shared.isIdleTimerDisabled = toggle
    }
}

public struct PreventDisplaySleepKey: EnvironmentKey {
    public static let defaultValue = PreventDisplaySleepAction()
}

public extension EnvironmentValues {
    var preventDisplaySleep: PreventDisplaySleepAction {
        get {
            self[PreventDisplaySleepKey.self]
        }
    }
}

public extension View {
    
    func preventingDisplaySleep() -> some View {
        self
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
    }
    
}
