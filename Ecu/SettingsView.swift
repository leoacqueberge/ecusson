import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct SettingsView: View {
    @State private var showHelp = false
    @State private var showingExportError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) var dismiss
    
    @State private var document: CSVDocument? = nil
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var history: [String: Int] = [:]

    struct CSVDocument: FileDocument {
        static var readableContentTypes: [UTType] { [.plainText] }
        
        var text = ""
        
        init(text: String) {
            self.text = text
        }
        
        init(configuration: ReadConfiguration) throws {
            if let data = configuration.file.regularFileContents {
                text = String(decoding: data, as: UTF8.self)
            } else {
                text = ""
            }
        }
        
        func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
            let data = Data(text.utf8)
            return FileWrapper(regularFileWithContents: data)
        }
    }

    private func loadHistory() {
        if let saved = UserDefaults.standard.dictionary(forKey: "history") as? [String: Int] {
            history = saved
        } else {
            history = [:]
        }
        print("History loaded: \(history)")
    }

    private func shareCSV(fileURL: URL) {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
        dismiss()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            rootVC.present(activityVC, animated: true, completion: nil)
        }
        }
    }
    
    func exportToMarkdown() {
        print("Starting Markdown export...")
        
        loadHistory()
        
        if history.isEmpty {
            print("No history data to export.")
            return
        }

        var mdString = ""
        for (date, amount) in history {
            mdString.append("\(date),\(amount)\n")
        }

        print("Generated Markdown content: \(mdString)")
        
        document = CSVDocument(text: mdString)
        isExporting = true
    }

    private func importerMarkdown(from url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Unable to access the file with startAccessingSecurityScopedResource")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            print("Import started")
            let accessibleURL: URL
            if FileManager.default.isReadableFile(atPath: url.path) {
                accessibleURL = url
            } else {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tempURL)
                try FileManager.default.copyItem(at: url, to: tempURL)
                accessibleURL = tempURL
            }
            let content = try String(contentsOf: accessibleURL, encoding: .utf8)
            var imported: [String: Int] = [:]
            let lines = content.components(separatedBy: .newlines)

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let parts = trimmed.components(separatedBy: ",")
                guard parts.count == 2,
                      let amount = Int(parts[1]) else {
                    continue
                }
                let date = parts[0]
                imported[date] = amount
            }

            history.merge(imported) { _, new in new }
            UserDefaults.standard.set(history, forKey: "history")
            print("✅ Markdown import successful: \(imported.count) entries")
            NotificationCenter.default.post(name: Notification.Name("HistoryImported"), object: nil)
        } catch {
            print("❌ Markdown read error: \(error)")
        }
    }
    

    var body: some View {
        ZStack {
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                            .foregroundColor(.settingsIcon)
                            .frame(width: 24, height: 24)
                    }

                    Spacer()

                    Text("Settings")
                        .font(.system(
                            size: UIFont.preferredFont(forTextStyle: .headline).pointSize,
                            weight: .bold,
                            design: .rounded
                        ))
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: {
                        showHelp = true
                    }) {
                        Image(systemName: "questionmark.circle")
                            .fontWeight(.semibold)
                            .foregroundColor(.settingsIcon)
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 20)
                

                VStack(spacing: 5) {

                    Button(action: {
                        print("Export button pressed")
                        exportToMarkdown()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .fontWeight(.semibold)
                                .frame(width: 24, height: 24)
                            Text("Export markdown")
                                .font(.system(
                                    size: UIFont.preferredFont(forTextStyle: .headline).pointSize,
                                    weight: .medium,
                                    design: .rounded
                                ))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                    }

                    Rectangle()
                        .fill(Color("SectionSeparator"))
                        .frame(height: 1)
                        .cornerRadius(0.5)
                        .padding(.horizontal)

                    Button(action: {
                        isImporting = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.down")
                                .fontWeight(.semibold)
                                .frame(width: 24, height: 24)
                            Text("Import markdown")
                                .font(.system(
                                    size: UIFont.preferredFont(forTextStyle: .headline).pointSize,
                                    weight: .medium,
                                    design: .rounded
                                ))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                    }

                    Rectangle()
                        .fill(Color("SectionSeparator"))
                        .frame(height: 1)
                        .cornerRadius(0.5)
                        .padding(.horizontal)

                    Button(action: {
                        if let url = URL(string: "mailto:leoacqueberge@icloud.com") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "lightbulb")
                                .fontWeight(.semibold)
                                .frame(width: 24, height: 24)
                            Text("Send me your ideas!")
                                .font(.system(
                                    size: UIFont.preferredFont(forTextStyle: .headline).pointSize,
                                    weight: .medium,
                                    design: .rounded
                                ))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                    }
                    
                    Rectangle()
                        .fill(Color("SectionSeparator"))
                        .frame(height: 1)
                        .cornerRadius(0.5)
                        .padding(.horizontal)
                    
                }

                Spacer()
            }
            .padding()

            VStack(spacing: 10) {
                Spacer()
                Link(destination: URL(string: "https://leoacqueberge.co")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "desktopcomputer")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("design & dev @leoacqueberge")
                            .font(.system(
                                size: UIFont.preferredFont(forTextStyle: .headline).pointSize - 4,
                                weight: .medium,
                                design: .rounded
                            ))
                            .foregroundColor(.secondary)
                    }
                }

                Link(destination: URL(string: "https://www.linkedin.com/in/ottavia-piccolo-76178a254/")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "paintbrush.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("icon @ottaviapiccolo")
                            .font(.system(
                                size: UIFont.preferredFont(forTextStyle: .headline).pointSize - 4,
                                weight: .medium,
                                design: .rounded
                            ))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 11)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("BackgroundColor"))
        .alert("How to use the app", isPresented: $showHelp) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Tap the + button to add €1.\nSwipe it left to remove €1.\n\nYou can also export and import your data in .md format from Settings.\n\nEnjoy 🌈")
        }
        .alert("Export Error", isPresented: $showingExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importerMarkdown(from: url)
                }
            case .failure(let error):
                print("❌ Import error: \(error)")
                errorMessage = "Import error: \(error.localizedDescription)"
                showingExportError = true
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: document,
            contentType: .plainText,
            defaultFilename: "history.md"
        ) { result in
            switch result {
            case .success(let url):
                print("Markdown file successfully saved at: \(url.path)")
            case .failure(let error):
                print("Export failed: \(error.localizedDescription)")
                errorMessage = "Export failed: \(error.localizedDescription)"
                showingExportError = true
            }
        }
    }
}


extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    SettingsView()
}
