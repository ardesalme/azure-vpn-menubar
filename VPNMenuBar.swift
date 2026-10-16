import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusLabel: NSMenuItem!
    private var toggleItem: NSMenuItem!
    private var autoReconnectItem: NSMenuItem!
    private var timer: Timer!
    private var serviceID: String?
    private var userDisconnected = false
    private var lastReconnectAttempt: Date?
    private let reconnectCooldown: TimeInterval = 15

    private static let autoReconnectKey = "autoReconnect"
    private var autoReconnect: Bool {
        get { UserDefaults.standard.bool(forKey: Self.autoReconnectKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.autoReconnectKey) }
    }

    private enum VPNState {
        case connected
        case disconnected
        case connecting
        case notFound
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        statusLabel = NSMenuItem(title: "Azure VPN: …", action: nil, keyEquivalent: "")
        statusLabel.isEnabled = false
        menu.addItem(statusLabel)
        menu.addItem(NSMenuItem.separator())
        toggleItem = NSMenuItem(title: "Se connecter", action: #selector(toggleVPN), keyEquivalent: "")
        menu.addItem(toggleItem)
        autoReconnectItem = NSMenuItem(title: "Reconnexion automatique", action: #selector(toggleAutoReconnect), keyEquivalent: "")
        autoReconnectItem.state = autoReconnect ? .on : .off
        menu.addItem(autoReconnectItem)
        menu.addItem(NSMenuItem(title: "Ouvrir Azure VPN Client", action: #selector(openAzureVPN), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc private func openAzureVPN() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Azure VPN Client.app"))
    }

    @objc private func toggleAutoReconnect() {
        autoReconnect.toggle()
        autoReconnectItem.state = autoReconnect ? .on : .off
        refresh()
    }

    @objc private func toggleVPN() {
        let connected = queryVPNState().0 == .connected
        // Une déconnexion manuelle suspend la reconnexion auto jusqu'à la prochaine connexion manuelle.
        userDisconnected = connected
        runNC(connected ? "stop" : "start")
    }

    private func runNC(_ action: String) {
        guard let serviceID else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        task.arguments = ["--nc", action, serviceID]
        try? task.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refresh()
        }
    }

    private func reconnectIfNeeded(_ state: VPNState) {
        guard autoReconnect, !userDisconnected, state == .disconnected, serviceID != nil else { return }
        if let last = lastReconnectAttempt, Date().timeIntervalSince(last) < reconnectCooldown { return }
        lastReconnectAttempt = Date()
        runNC("start")
    }

    private func queryVPNState() -> (VPNState, String?) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        task.arguments = ["--nc", "list"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return (.notFound, nil)
        }
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return (.notFound, nil) }

        guard let line = output.split(separator: "\n").first(where: { $0.contains("com.microsoft.AzureVpnMac") }) else {
            return (.notFound, nil)
        }

        let uuidPattern = "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
        let id = line.range(of: uuidPattern, options: .regularExpression).map { String(line[$0]) }

        if line.contains("(Connected)") {
            return (.connected, id)
        } else if line.contains("(Connecting)") || line.contains("(Disconnecting)") {
            return (.connecting, id)
        } else {
            return (.disconnected, id)
        }
    }

    private func refresh() {
        let (state, id) = queryVPNState()
        serviceID = id
        if state == .connected { lastReconnectAttempt = nil }
        reconnectIfNeeded(state)

        let symbolName: String
        let tint: NSColor
        let label: String

        switch state {
        case .connected:
            symbolName = "lock.fill"
            tint = .systemGreen
            label = "Azure VPN: connecté"
        case .connecting:
            symbolName = "lock.rotation"
            tint = .systemOrange
            label = "Azure VPN: connexion…"
        case .disconnected:
            symbolName = "lock.open.fill"
            tint = .secondaryLabelColor
            label = "Azure VPN: déconnecté"
        case .notFound:
            symbolName = "lock.trianglebadge.exclamationmark"
            tint = .secondaryLabelColor
            label = "Azure VPN: introuvable"
        }

        guard let button = statusItem.button else { return }
        let config = NSImage.SymbolConfiguration(paletteColors: [tint])
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)?
            .withSymbolConfiguration(config)
        image?.isTemplate = false
        button.image = image
        button.toolTip = label
        statusLabel.title = label

        toggleItem.title = (state == .connected) ? "Se déconnecter" : "Se connecter"
        toggleItem.isEnabled = (id != nil) && (state == .connected || state == .disconnected)
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
