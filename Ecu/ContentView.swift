import SwiftUI
import ActivityKit
import WidgetKit
@available(iOS 16.1, *)
struct SpendAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var today: Int
    }
}
import UIKit
import CloudKit

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
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

struct TitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: UIFont.preferredFont(forTextStyle: .headline).pointSize + 2, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
    }
}

struct AmountStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: UIFont.preferredFont(forTextStyle: .title1).pointSize + 4, weight: .bold, design: .rounded))
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
                        .font(.title2)
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
        .padding(.horizontal)
    }
}


private let appGroupID = "group.com.leoacqueberge.ecusson"

// MARK: - Floating radial menu tied to the "+" button
private struct FloatingMenu: View {
    @GestureState private var dragOffset: CGFloat = 0
    @State private var expanded = false

    /// Callbacks provided by the parent view
    let addAmount: (Int) -> Void
    let triggerHaptic: () -> Void

    private let threshold: CGFloat = 40

    /// Combined long‑press + drag‑up gesture that drives the expansion
    private var longPressDrag: some Gesture {
        LongPressGesture(minimumDuration: 0)
            .sequenced(before: DragGesture())
            .updating($dragOffset) { value, state, _ in
                if case .second(true, let drag?) = value {
                    // Track only vertical upward movement (negative values)
                    state = min(0, drag.translation.height)
                } else {
                    state = 0
                }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                // Open if the user dragged up past the threshold, otherwise close
                if drag.translation.height < -threshold {
                    expanded = true
                    triggerHaptic()
                } else {
                    expanded = false
                }
            }
    }

    var body: some View {
        ZStack {
            // Secondary button #1  (subtract 1)
            if expanded {
                Button {
                    addAmount(-1)
                    triggerHaptic()
                    expanded = true
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.white, .red)
                        .rotationEffect(.degrees(Double(dragOffset) / -4))
                }
                .offset(y: -130)          // 2 × step
                .opacity(expanded ? 1 : 0)
                .buttonStyle(NoOpacityButtonStyle())

                // Secondary button #2  (add +5 as example)
                Button {
                    addAmount(10)
                    triggerHaptic()
                    expanded = true
                } label: {
                    Image(systemName: "10.circle.fill")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.white, Color.accentColor)
                        .rotationEffect(.degrees(Double(dragOffset) / -4))
                }
                .offset(y: -65)           // 1 × step
                .opacity(expanded ? 1 : 0)
                .buttonStyle(NoOpacityButtonStyle())
            }

            // Primary “+” button / drag handle
            Button {
                addAmount(1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white, Color.accentColor)
                    // Small visual rotation while dragging
                    .rotationEffect(.degrees(Double(dragOffset) / -4))
            }
            // Horizontal left swipe → −1 (keeps previous behaviour)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0).onEnded { value in
                    if value.translation.width < -20 && abs(value.translation.height) < 20 {
                        addAmount(-1)
                        triggerHaptic()
                    }
                }
            )
            // Long‑press + vertical drag gesture
            .gesture(longPressDrag)
            .buttonStyle(NoOpacityButtonStyle())
        } // end of ZStack
        .onTapBackground(enabled: expanded) {
            withAnimation { expanded = false }
        }
        .animation(.spring(), value: expanded)
    }
}


struct ContentView: View {
    @State private var amountToday: Int = 0
    @State private var history: [String: Int] = [:]
    @State private var showSettings = false

    private var currentDate: Date { Date() }

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private var todayDate: String {
        dateFormatter.string(from: currentDate)
    }

    private func addAmount(_ value: Int) {
        withAnimation(.easeInOut) {
            history[todayDate, default: 0] += value
            amountToday = history[todayDate] ?? 0
        }

        let sharedDefaults = UserDefaults(suiteName: appGroupID)!
        sharedDefaults.set(history, forKey: "history")
        WidgetCenter.shared.reloadTimelines(ofKind: "EcussonWidget")

        // Start / refresh Live Activity with today's amount
        if #available(iOS 16.1, *) {
            let attr = SpendAttributes()
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: SpendAttributes.ContentState(today: amountToday),
                                              staleDate: nil)
                _ = try? Activity.request(attributes: attr,
                                          content: content,
                                          pushType: nil)
            } else {
                // iOS 16.1 fallback (deprecated API)
                _ = try? Activity.request(attributes: attr,
                                          contentState: .init(today: amountToday),
                                          pushType: nil)
            }
        }
    }

    private func sum(days: Int) -> Int {
        (0..<days).compactMap { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: currentDate)!
            let key = dateFormatter.string(from: date)
            return history[key]
        }.reduce(0, +)
    }

    private func sumSinceStartOfYear() -> Int {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: currentDate))!
        let days = Calendar.current.dateComponents([.day], from: start, to: currentDate).day ?? 0
        return sum(days: days + 1)
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func loadHistory() {
        let sharedDefaults = UserDefaults(suiteName: appGroupID)!
        if let saved = sharedDefaults.dictionary(forKey: "history") as? [String: Int] {
            history = saved
        } else {
            history = [:]
        }
        amountToday = history[todayDate] ?? 0
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    AmountBlock(title: "Today", value: amountToday, systemImage: "star.fill")

                    Rectangle()
                        .fill(Color("SectionSeparator"))
                        .frame(height: 1)
                        .cornerRadius(0.5)
                        .padding(.vertical, 10)
                        .padding(.horizontal)

                    AmountBlock(title: "Last 28 Days", value: sum(days: 28), systemImage: nil)
                        .animation(.easeInOut, value: sum(days: 28))

                    Rectangle()
                        .fill(Color("SectionSeparator"))
                        .frame(height: 1)
                        .cornerRadius(0.5)
                        .padding(.vertical, 10)
                        .padding(.horizontal)

                    AmountBlock(title: "Since January 1", value: sumSinceStartOfYear(), systemImage: nil)
                        .animation(.easeInOut, value: sumSinceStartOfYear())
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 40)
            }
            
            FloatingMenu(
                addAmount: { value in addAmount(value) },
                triggerHaptic: triggerHaptic
            )
            .padding([.leading, .trailing, .top])
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            Button(action: {
                showSettings = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text("Settings")
                        .font(.system(size: UIFont.preferredFont(forTextStyle: .headline).pointSize - 2, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)}
                .padding(10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 11)
            .buttonStyle(NoOpacityButtonStyle())


        }
        .background(Color("BackgroundColor"))
        .onAppear {
            DispatchQueue.main.async {
                loadHistory()

                let center = UNUserNotificationCenter.current()
                center.getPendingNotificationRequests { requests in
                    let alreadyScheduled = requests.contains { $0.identifier == "dailyExpenseReminder" }
                    if !alreadyScheduled {
                        let content = UNMutableNotificationContent()
                        content.title = "Daily Expenses"
                        content.body = "Have you recorded your expenses for today? 🤑"

                        var dateComponents = DateComponents()
                        dateComponents.hour = 22 // 10pm
                        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                        let request = UNNotificationRequest(identifier: "dailyExpenseReminder", content: content, trigger: trigger)
                        center.add(request)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HistoryImported"))) { _ in
            loadHistory()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct NoOpacityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Tap‑through background helper
extension View {
    @ViewBuilder
    private func onTapBackgroundContent(enabled: Bool, _ action: @escaping () -> Void) -> some View {
        if enabled {
            Color.clear
                .frame(width: UIScreen.main.bounds.width * 2,
                       height: UIScreen.main.bounds.height * 2)
                .contentShape(Rectangle())
                .onTapGesture(perform: action)
        }
    }

    func onTapBackground(enabled: Bool, _ action: @escaping () -> Void) -> some View {
        background(
            onTapBackgroundContent(enabled: enabled, action)
        )
    }
}

#Preview {
    ContentView()
}
