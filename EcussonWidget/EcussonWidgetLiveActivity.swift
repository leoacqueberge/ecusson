import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.2, *)
struct SpendAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var today: Int
    }
    var title = "Daily Spend"
}

@available(iOSApplicationExtension 16.2, *)
struct EcussonLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SpendAttributes.self) { context in
            // Lock‑screen
            VStack {
                Text("Today")
                Text("\(context.state.today) €")
                    .font(.title)
            }
            .activityBackgroundTint(.mint)
        } dynamicIsland: { context in
            DynamicIsland {
                // ------- Vue agrandie -------
                DynamicIslandExpandedRegion(.center) {
                    Text("Today: \(context.state.today) €")
                }
            } compactLeading: {
                Text("€\(context.state.today)")
            } compactTrailing: {
                Image(systemName: "eurosign")
            } minimal: {
                Text("€\(context.state.today)")
            }
        }
    }
}
