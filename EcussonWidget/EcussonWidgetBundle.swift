import WidgetKit
import SwiftUI

@main
struct EcussonWidgetBundle: WidgetBundle {
    var body: some Widget {
        EcussonWidget()          // basique
        EcussonWidgetControl()   // interactif
        EcussonLiveActivity()    // Live Activity
    }
}
