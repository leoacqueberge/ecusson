import WidgetKit
import SwiftUI
import AppIntents

struct AddEuroIntent: AppIntent { static var title: LocalizedStringResource = "Add €1" }
struct RemoveEuroIntent: AppIntent { static var title: LocalizedStringResource = "Remove €1" }

@MainActor
extension AddEuroIntent {
    func perform() async throws -> some IntentResult {
        let defs = UserDefaults(suiteName: "group.com.leoacqueberge.ecusson")!
        var hist = (defs.dictionary(forKey: "history") as? [String:Int]) ?? [:]
        
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        hist[df.string(from: .now), default: 0] += 1
        defs.set(hist, forKey: "history")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

@MainActor
extension RemoveEuroIntent {
    func perform() async throws -> some IntentResult {
        let defs = UserDefaults(suiteName: "group.com.leoacqueberge.ecusson")!
        var hist = (defs.dictionary(forKey: "history") as? [String:Int]) ?? [:]
        
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        hist[df.string(from: .now), default: 0] -= 1
        defs.set(hist, forKey: "history")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct EcussonWidgetControl: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EcussonWidgetControl",
                            provider: SpendProvider()) { entry in
            VStack {
                SpendWidgetView(entry: entry)
                HStack {
                    Button(intent: RemoveEuroIntent()) { Image(systemName:"minus") }
                    Button(intent: AddEuroIntent()) { Image(systemName:"plus") }
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Spending (interactive)")
        .supportedFamilies([.systemMedium])
    }
}
