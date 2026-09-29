// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import Metal

final class Probe: ObservableObject {
    static let shared = Probe()
    @Published var lines: [String] = []
    @Published var status = "Ready"
    @Published var running = false
    private var started = false

    func log(_ text: String) {
        DispatchQueue.main.async {
            self.lines.append(text)
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? (self.lines.joined(separator: "\n") + "\n")
                .write(to: documents.appendingPathComponent("probe.log"), atomically: true, encoding: .utf8)
        }
    }

    func run() {
        guard !started else { return }
        started = true
        running = true
        status = "Testing x86-64 translation…"
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        // A durable running marker distinguishes a crash from a completed test.
        writeReport(documents, result: "running", code: nil)
        fex_set_log_callback { message in
            if let message { Probe.shared.log(String(cString: message)) }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let code = fex_test_execute()
            self.writeReport(documents, result: code == 0 ? "passed" : "failed", code: code)
            DispatchQueue.main.async {
                self.running = false
                self.status = code == 0 ? "x86-64 CPU probe passed" : "CPU probe failed (\(code))"
            }
        }
    }

    private func writeReport(_ directory: URL, result: String, code: Int64?) {
        var report: [String: Any] = [
            "probe": "Madeira FEX x86-64 ELF",
            "status": result,
            "platform": "iOS Simulator arm64",
            "metalDevice": MTLCreateSystemDefaultDevice()?.name ?? "unavailable",
            "wineTested": false, "wow64Tested": false, "d3d9Tested": false,
            "civ4Playable": false
        ]
        if let code { report["exitCode"] = code }
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: directory.appendingPathComponent("probe.json"), options: .atomic)
        } catch { log("Could not write probe report: \(error)") }
    }
}

@main
struct CivSimulatorApp: App {
    @StateObject private var probe = Probe.shared
    var body: some Scene {
        WindowGroup {
            VStack(alignment: .leading, spacing: 16) {
                Text("Civ IV · iOS runtime lab").font(.largeTitle.bold())
                Text(probe.status).font(.headline)
                Text("Tests Madeira’s FEX CPU translator on this Mac. Wine, 32-bit Windows, Direct3D 9 and Civ IV gameplay are not yet verified.")
                    .foregroundStyle(.secondary)
                Text("Metal: \(MTLCreateSystemDefaultDevice()?.name ?? "unavailable")")
                ScrollView {
                    Text(probe.lines.joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding().background(.black.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 12))
                Text("A passing CPU probe does not establish game or physical-device compatibility.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .task { probe.run() }
        }
    }
}
