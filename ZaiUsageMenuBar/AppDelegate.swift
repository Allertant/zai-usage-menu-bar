import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var refreshTimer: Timer?
    
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
        
        refreshTimer = Timer(timeInterval: 300, repeats: true) { _ in
            NotificationCenter.default.post(name: .refreshUsage, object: nil)
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)

        fetchAndUpdateStatusItem()
    }

    private func fetchAndUpdateStatusItem() {
        let accounts = AccountConfigStore.loadAccounts()
        let enabledAccounts = accounts.filter { $0.isEnabled && !$0.authToken.trimmed.isEmpty }
        guard !enabledAccounts.isEmpty else { return }

        Task { @MainActor in
            let results = await UsageAPIClient.shared.fetchAllUsage(accounts: enabledAccounts)
            let first = results.first { $0.usage != nil }
            updateStatusItem(percentage: UsageAggregation.tokenPercentage(from: first?.usage?.quotaLimits))
        }
    }
    
    func updateStatusItem(percentage: Double?) {
        guard let button = statusItem.button else { return }
        if let percentage = percentage {
            button.title = String(format: "%.0f%%", percentage)
        } else {
            button.title = "--"
        }
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
        }
    }
    
    func hidePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }
}

extension Notification.Name {
    static let refreshUsage = Notification.Name("refreshUsage")
}
