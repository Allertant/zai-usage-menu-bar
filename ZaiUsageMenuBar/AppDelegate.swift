import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    var statusItem: NSStatusItem!
    var popover = NSPopover()
    private var lastPercentage: Double?
    private var lastChangeTime: Date = .now
    private var fetchTask: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "--"
            button.action = #selector(statusBarClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let contentView = MenuBarContentView().preferredColorScheme(.dark)
        popover.contentSize = NSSize(width: 300, height: 360)
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = NSHostingController(rootView: contentView)

        scheduleNextFetch()
    }

    private func adaptiveInterval() -> TimeInterval {
        let idle = Date.now.timeIntervalSince(lastChangeTime)
        if idle < 600 { return 30 }    // 10min 内活跃 → 30s
        if idle < 1800 { return 60 }   // 10~30min 空闲 → 1min
        return 300                       // >30min 长时间空闲 → 5min
    }

    private func scheduleNextFetch() {
        fetchTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.fetchAndUpdateStatusItem()
        }
        fetchTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + adaptiveInterval(), execute: task)
    }

    private func fetchAndUpdateStatusItem() {
        let accounts = AccountConfigStore.loadAccounts()
        let enabledAccounts = accounts.filter { $0.isEnabled && !$0.authToken.trimmed.isEmpty }
        guard !enabledAccounts.isEmpty else {
            scheduleNextFetch()
            return
        }

        Task { @MainActor in
            let results = await UsageAPIClient.shared.fetchAllUsage(accounts: enabledAccounts)
            let first = results.first { $0.usage != nil }
            let percentage = UsageAggregation.tokenPercentage(from: first?.usage?.quotaLimits)
            if percentage != lastPercentage {
                lastChangeTime = .now
                lastPercentage = percentage
            }
            updateStatusItem(percentage: percentage)
            scheduleNextFetch()
        }
    }
    
    func updateStatusItem(percentage: Double?) {
        guard let button = statusItem.button else { return }
        if let percentage = percentage {
            let text = String(format: "%.0f%%", percentage)
            button.title = text
            writeQuotaFile(text)
        } else {
            button.title = "--"
        }
    }

    private func writeQuotaFile(_ text: String) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ZaiUsageMenuBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("quota.txt")
        try? text.data(using: .utf8)?.write(to: file, options: .atomic)
    }
    
    @objc func statusBarClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: sender)
        } else {
            togglePopover(sender)
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            hidePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    func showPopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func hidePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }
}

extension Notification.Name {
    static let refreshUsage = Notification.Name("refreshUsage")
}
