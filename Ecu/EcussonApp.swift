import SwiftUI

@main
struct EcussonApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
                    .modelContainer(for: Expense.self)
            }
        }
    }
}
