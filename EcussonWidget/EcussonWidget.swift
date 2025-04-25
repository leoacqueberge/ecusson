import SwiftUI
import WidgetKit
import UIKit
// MARK: - Hex Color Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (r, g, b) = (255, 255, 255)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255)
    }
}

// MARK: - Shared Data Types
struct SpendEntry: TimelineEntry {
    let date: Date
    let history: [String: Int]
}

struct SpendProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpendEntry {
        SpendEntry(date: .now, history: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendEntry) -> Void) {
        // Sample placeholder data
        completion(SpendEntry(date: .now, history: [:]))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendEntry>) -> Void) {
        // Load shared data
        let defs = UserDefaults(suiteName: "group.com.leoacqueberge.ecusson")!
        let history = defs.dictionary(forKey: "history") as? [String: Int] ?? [:]
        let entry = SpendEntry(date: .now, history: history)
        // Refresh after midnight
        let next = Calendar.current.nextDate(after: .now,
                                             matching: DateComponents(hour: 0, minute: 1),
                                             matchingPolicy: .strict)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - View Modifiers & Blocks (from ContentView)
struct TitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(.subheadline, design: .rounded))
            .fontWeight(.medium)
            .foregroundColor(.secondary)
    }
}

struct AmountStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: UIFont.preferredFont(forTextStyle: .headline).pointSize + 4, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
    }
}

extension View {
    func titleStyle() -> some View { self.modifier(TitleStyle()) }
    func amountStyle() -> some View { self.modifier(AmountStyle()) }
}

struct AmountBlock: View {
    let title: String
    let value: Int
    let systemImage: String?
    @State private var previousValue: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color(hex: "#FFD400"))
                }
                Text(title).titleStyle()
            }
            let isCountingDown = value < previousValue

            Text("\(value) €")
                .amountStyle()
                .contentTransition(.numericText(countsDown: isCountingDown))
                .onAppear { previousValue = value }
                .onChange(of: value) { _, newValue in
                    previousValue = newValue
                }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct NoOpacityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Compatibility helper for widget background
#if canImport(WidgetKit)
extension View {
    @ViewBuilder
    func widgetBackground(_ backgroundView: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { backgroundView }
        } else {
            background(backgroundView)
        }
    }
}
#endif

struct SpendWidgetView: View {
    let entry: SpendEntry
    @Environment(\.widgetFamily) private var family

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private var todayKey: String {
        dateFormatter.string(from: entry.date)
    }

    private var history: [String: Int] { entry.history }
    private var amountToday: Int   { history[todayKey] ?? 0 }
    private func sum(days: Int) -> Int {
        (0..<days).compactMap { offset in
            let d = Calendar.current.date(byAdding: .day, value: -offset, to: entry.date)!
            return history[dateFormatter.string(from: d)]
        }.reduce(0, +)
    }
    private var sum28: Int { sum(days: 28) }
    private var sumYTD: Int {
        let start = Calendar.current.date(from:
            Calendar.current.dateComponents([.year], from: entry.date)
        )!
        let days = Calendar.current.dateComponents([.day], from: start, to: entry.date).day! + 1
        return sum(days: days)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color("BackgroundColor")
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 10) {
                AmountBlock(title: "Today", value: amountToday, systemImage: "star.fill")

                Divider()
                    .background(Color("Divider"))
                    .padding(.vertical, 0)

                AmountBlock(title: "Last 28 Days", value: sum28, systemImage: nil)
            }
        }
        .widgetBackground(Color("BackgroundColor"))
    }
}

struct EcussonWidget: Widget {
    let kind: String = "EcussonWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpendProvider()) { entry in
            SpendWidgetView(entry: entry)
        }
        .configurationDisplayName("Ecusson Dépenses")
        .description("Affiche vos dépenses quotidiennes")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#if DEBUG
struct SpendWidgetView_Previews: PreviewProvider {
    // Sample history for preview
    static var sampleHistory: [String: Int] = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        return [todayKey: 42]
    }()

    static var sampleEntry: SpendEntry {
        SpendEntry(date: Date(), history: sampleHistory)
    }

    static var previews: some View {
        Group {
            SpendWidgetView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")
            SpendWidgetView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")
        }
    }
}
#endif
