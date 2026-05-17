import Foundation
import MetricKit
import os

final class DiagnosticsService: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = DiagnosticsService()

    private let log = Logger(subsystem: "com.jackwallner.glp", category: "diagnostics")
    private let fileManager = FileManager.default

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            persist(payload.jsonRepresentation(), kind: "metric", timestamp: payload.timeStampEnd)
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            persist(payload.jsonRepresentation(), kind: "diagnostic", timestamp: payload.timeStampEnd)
            log.error("MetricKit diagnostic payload received")
        }
    }

    private func persist(_ data: Data, kind: String, timestamp: Date) {
        guard let directory = diagnosticsDirectory() else { return }
        let stamp = ISO8601DateFormatter().string(from: timestamp)
            .replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("\(kind)-\(stamp).json")
        try? data.write(to: url, options: .atomic)
        pruneOldFiles(in: directory, keep: 20)
    }

    private func diagnosticsDirectory() -> URL? {
        guard let base = fileManager.containerURL(forSecurityApplicationGroupIdentifier: GLPAppGroup.identifier) else {
            return nil
        }
        let directory = base.appendingPathComponent("Diagnostics", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func pruneOldFiles(in directory: URL, keep: Int) {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let sorted = files.sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhs > rhs
        }
        for url in sorted.dropFirst(keep) {
            try? fileManager.removeItem(at: url)
        }
    }
}
