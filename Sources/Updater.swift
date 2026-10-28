// Floating Camera — MIT License. See LICENSE.

import AppKit
import Foundation

struct GitHubRelease {
    let version: String
    let pageURL: URL
    let assetURL: URL?
}

extension GitHubRelease {
    static func parse(_ data: Data) -> GitHubRelease? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String,
              let page = object["html_url"] as? String,
              let pageURL = URL(string: page)
        else { return nil }

        let assets = object["assets"] as? [[String: Any]] ?? []
        let preferred = assets.first { asset in
            (asset["name"] as? String)?.caseInsensitiveCompare("FloatingCamera.zip") == .orderedSame
        }
        let zip = preferred ?? assets.first { asset in
            (asset["name"] as? String)?.lowercased().hasSuffix(".zip") == true
        }
        let assetURL = (zip?["browser_download_url"] as? String).flatMap(URL.init)
        let version = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

        return GitHubRelease(version: version, pageURL: pageURL, assetURL: assetURL)
    }
}

enum UpdateError: LocalizedError {
    case downloadFailed
    case invalidArchive
    case processFailed
    case notWritable

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return L10n.s("The update could not be downloaded.", "No se pudo descargar la actualización.")
        case .invalidArchive:
            return L10n.s(
                "The downloaded update is not a valid Floating Camera app.",
                "La actualización descargada no es una app Floating Camera válida."
            )
        case .processFailed:
            return L10n.s(
                "The update helper could not complete.",
                "El asistente de actualización no pudo completarse."
            )
        case .notWritable:
            return L10n.s(
                "The application folder is not writable.",
                "La carpeta de la aplicación no permite escritura."
            )
        }
    }
}

final class Updater {
    private static let checkInterval: TimeInterval = 30 * 24 * 60 * 60
    private static let lastCheckKey = "updates.lastCheck"

    private let owner: String
    private let repo: String
    private var isChecking = false

    init() {
        owner = Bundle.main.object(forInfoDictionaryKey: "FCGitHubOwner") as? String ?? ""
        repo = Bundle.main.object(forInfoDictionaryKey: "FCGitHubRepo") as? String ?? ""
    }

    var isConfigured: Bool {
        !owner.isEmpty && !owner.hasPrefix("__")
            && !repo.isEmpty && !repo.hasPrefix("__")
    }

    func checkIfDue() {
        guard isConfigured else { return }
        if let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date,
           Date().timeIntervalSince(last) < Self.checkInterval {
            return
        }
        UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)
        check(manual: false)
    }

    func checkNow() {
        guard isConfigured else {
            showError(
                L10n.s("Updates are not configured.", "Las actualizaciones no están configuradas."),
                details: L10n.s(
                    "This build does not include GitHub repository metadata.",
                    "Esta compilación no incluye los datos del repositorio de GitHub."
                )
            )
            return
        }
        check(manual: true)
    }

    private func check(manual: Bool) {
        guard !isChecking else { return }
        isChecking = true

        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("FloatingCamera/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isChecking = false

                if let error {
                    if manual {
                        self.showError(
                            L10n.s("Could not check for updates.", "No se pudieron buscar actualizaciones."),
                            details: error.localizedDescription
                        )
                    }
                    return
                }

                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 200,
                      let data,
                      let release = GitHubRelease.parse(data)
                else {
                    if manual {
                        self.showError(
                            L10n.s("Could not check for updates.", "No se pudieron buscar actualizaciones."),
                            details: L10n.s(
                                "GitHub returned an unexpected response.",
                                "GitHub devolvió una respuesta inesperada."
                            )
                        )
                    }
                    return
                }

                if Version.isNewer(release.version, than: Self.currentVersion) {
                    self.presentUpdate(release)
                } else if manual {
                    self.showNoUpdate()
                }
            }
        }.resume()
    }

    private func presentUpdate(_ release: GitHubRelease) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = L10n.s(
            "Floating Camera \(release.version) is available",
            "Floating Camera \(release.version) está disponible"
        )
        alert.informativeText = L10n.s(
            "You are using version \(Self.currentVersion).",
            "Estás usando la versión \(Self.currentVersion)."
        )
        alert.addButton(withTitle: L10n.s("Update", "Actualizar"))
        alert.addButton(withTitle: L10n.s("Later", "Más tarde"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let assetURL = release.assetURL else {
            NSWorkspace.shared.open(release.pageURL)
            return
        }
        download(release: release, assetURL: assetURL)
    }

    private func download(release: GitHubRelease, assetURL: URL) {
        let alert = NSAlert()
        alert.messageText = L10n.s(
            "Downloading Floating Camera \(release.version)…",
            "Descargando Floating Camera \(release.version)…"
        )
        alert.informativeText = L10n.s(
            "The app will restart when the update is ready.",
            "La app se reiniciará cuando la actualización esté lista."
        )

        let spinner = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 280, height: 20))
        spinner.style = .spinning
        spinner.startAnimation(nil)
        alert.accessoryView = spinner
        alert.addButton(withTitle: L10n.s("Cancel", "Cancelar"))

        var downloadResult: Result<URL, Error>?
        var finished = false
        var cancelled = false

        let task = URLSession.shared.downloadTask(with: assetURL) { tempURL, _, error in
            let result: Result<URL, Error>

            if let error {
                result = .failure(error)
            } else if let tempURL {
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent("FloatingCamera-\(UUID().uuidString).zip")
                do {
                    try FileManager.default.moveItem(at: tempURL, to: destination)
                    result = .success(destination)
                } catch {
                    result = .failure(error)
                }
            } else {
                result = .failure(UpdateError.downloadFailed)
            }

            DispatchQueue.main.async {
                finished = true
                downloadResult = result
                NSApp.abortModal()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !cancelled {
                task.resume()
            }
        }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            cancelled = true
            task.cancel()
            return
        }

        guard finished, let downloadResult else { return }

        switch downloadResult {
        case .success(let zipURL):
            install(zipURL: zipURL, release: release)
        case .failure(let error):
            showError(
                L10n.s("The update could not be downloaded.", "No se pudo descargar la actualización."),
                details: error.localizedDescription
            )
        }
    }

    private func install(zipURL: URL, release: GitHubRelease) {
        let target = URL(fileURLWithPath: Bundle.main.bundlePath)
        let parent = target.deletingLastPathComponent()

        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            showError(
                L10n.s(
                    "The update could not be installed automatically.",
                    "No se pudo instalar la actualización automáticamente."
                ),
                details: L10n.s(
                    "The application folder is not writable. Download the release manually.",
                    "La carpeta de la aplicación no permite escritura. Descarga la versión manualmente."
                )
            )
            NSWorkspace.shared.open(release.pageURL)
            return
        }

        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("FloatingCameraUpdate-\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            try run("/usr/bin/ditto", ["-x", "-k", zipURL.path, work.path])

            let newApp = work.appendingPathComponent("FloatingCamera.app")
            guard let bundle = Bundle(url: newApp),
                  bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
                  let newVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                  newVersion == release.version
            else {
                throw UpdateError.invalidArchive
            }

            try installAndRelaunch(newApp: newApp, target: target, work: work)
        } catch {
            showError(
                L10n.s("The update could not be installed.", "No se pudo instalar la actualización."),
                details: error.localizedDescription
            )
            NSWorkspace.shared.open(release.pageURL)
        }
    }

    private func installAndRelaunch(newApp: URL, target: URL, work: URL) throws {
        let scriptURL = work.appendingPathComponent("install.sh")
        let script = """
        #!/bin/bash
        set -e
        target="$1"
        source="$2"
        work="$3"
        while /usr/bin/pgrep -x FloatingCamera >/dev/null 2>&1; do sleep 0.2; done
        rm -rf "${target}.new"
        cp -R "$source" "${target}.new"
        rm -rf "$target"
        mv "${target}.new" "$target"
        /usr/bin/xattr -dr com.apple.quarantine "$target" 2>/dev/null || true
        /usr/bin/open "$target"
        rm -rf "$work"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptURL.path
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path, target.path, newApp.path, work.path]
        try process.run()

        NSApp.terminate(nil)
    }

    private func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError.processFailed
        }
    }

    private func showNoUpdate() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L10n.s("You’re up to date", "Estás al día")
        alert.informativeText = L10n.s(
            "Floating Camera \(Self.currentVersion) is the latest version.",
            "Floating Camera \(Self.currentVersion) es la última versión."
        )
        alert.addButton(withTitle: L10n.s("OK", "Aceptar"))
        alert.runModal()
    }

    private func showError(_ message: String, details: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = details
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.s("OK", "Aceptar"))
        alert.runModal()
    }

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

}
