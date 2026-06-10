#if os(iOS)
import SwiftUI

@main
struct CmdTabApp_iOS: App {
    @StateObject private var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
        }
    }
}
#endif
