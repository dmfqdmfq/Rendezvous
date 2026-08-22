import SwiftUI

@main
struct SchwarzschildApp: App {

    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // アプリ全体で設定を共有する
                .environmentObject(settings)
        }
    }
}
