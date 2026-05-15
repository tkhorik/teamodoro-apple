import SwiftUI

@main
struct TeamodoroApp: App {

    @State private var viewModel = TimerViewModel()

    var body: some Scene {
        WindowGroup {
            TimerView()
                .environment(viewModel)
        }
    }
}
