import AppKit
import SwiftUI
import Carbon

final class CompanionPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var panel: CompanionPanel!
    var store: GameStore!
    var statusItem: NSStatusItem!
    var hotkey: EventHotKeyRef?
    var eventHandler: EventHandlerRef?
    var isResizing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store = GameStore()
        store.onModeChange = { [weak self] mode in self?.applyMode(mode) }
        store.onAppearanceChange = { [weak self] in self?.applyAppearance() }
        store.onHide = { [weak self] in self?.hide() }
        store.onQuit = { NSApp.terminate(nil) }

        panel = CompanionPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 452),
                               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "角落有喵"
        panel.onCancel = { [weak self] in self?.hide() }
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: CompanionRoot(store: store))
        applyMode(store.settings.mode, initial: true)
        applyAppearance()
        setupStatusItem()
        setupHotkey()
        panel.orderFrontRegardless()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showRoom()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.tick()
        store.save()
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "pawprint", accessibilityDescription: "角落有喵")
        button.toolTip = "角落有喵 · 点击显示/隐藏，右键打开菜单"
        button.target = self
        button.action = #selector(statusClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            addItem(menu, "打开小屋", #selector(showRoom))
            addItem(menu, "透明桌宠", #selector(showPet))
            addItem(menu, "迷你状态条", #selector(showCompact))
            menu.addItem(.separator())
            let pin = addItem(menu, "窗口置顶", #selector(togglePin))
            pin.state = store.settings.alwaysOnTop ? .on : .off
            let dim = addItem(menu, "低调透明", #selector(toggleDim))
            dim.state = store.settings.dimmed ? .on : .off
            addItem(menu, "隐藏 / 显示    ⌘⇧H", #selector(toggleVisibility))
            menu.addItem(.separator())
            addItem(menu, "退出角落有喵", #selector(quit))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else { toggleVisibility() }
    }

    @discardableResult
    func addItem(_ menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    func setupHotkey() {
        var specification = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { delegate.toggleVisibility() }
            return noErr
        }, 1, &specification, context, &eventHandler)
        if status == noErr {
            let identifier = EventHotKeyID(signature: 0x43434154, id: 1)
            let registered = RegisterEventHotKey(UInt32(kVK_ANSI_H), UInt32(cmdKey | shiftKey), identifier, GetApplicationEventTarget(), 0, &hotkey)
            store.hotkeyAvailable = registered == noErr
        } else { store.hotkeyAvailable = false }
    }

    func applyMode(_ mode: DisplayMode, initial: Bool = false) {
        let size: NSSize
        switch mode {
        case .room: size = NSSize(width: 320, height: 452)
        case .compact: size = NSSize(width: 164, height: 34)
        case .pet: size = NSSize(width: 120, height: 120)
        }
        let oldFrame = panel.frame
        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
        var visible = screen.visibleFrame
        var origin = NSPoint(x: oldFrame.maxX - size.width, y: oldFrame.minY)
        if initial {
            if let x = store.settings.windowX, let y = store.settings.windowY, x.isFinite, y.isFinite {
                origin = NSPoint(x: x, y: y)
                visible = bestScreen(for: NSRect(origin: origin, size: size)).visibleFrame
            } else {
                origin = NSPoint(x: visible.maxX - size.width - 24, y: visible.minY + 28)
            }
        }
        isResizing = true
        panel.setFrame(clamped(NSRect(origin: origin, size: size), to: visible), display: true)
        panel.hasShadow = mode != .pet
        isResizing = false
        rememberPosition()
        panel.orderFrontRegardless()
    }

    func clamped(_ rect: NSRect, to visible: NSRect) -> NSRect {
        var result = rect
        result.origin.x = max(visible.minX, min(result.minX, visible.maxX - result.width))
        result.origin.y = max(visible.minY, min(result.minY, visible.maxY - result.height))
        return result
    }

    func bestScreen(for rect: NSRect) -> NSScreen {
        let best = NSScreen.screens.max { lhs, rhs in
            let a = lhs.visibleFrame.intersection(rect)
            let b = rhs.visibleFrame.intersection(rect)
            return (a.isNull ? 0 : a.width * a.height) < (b.isNull ? 0 : b.width * b.height)
        }
        if let best, best.visibleFrame.intersects(rect) { return best }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    func applyAppearance() {
        panel.level = store.settings.alwaysOnTop ? .floating : .normal
        panel.alphaValue = store.settings.dimmed ? 0.72 : 1
    }

    func windowDidMove(_ notification: Notification) { if !isResizing { rememberPosition() } }
    func rememberPosition() {
        store.settings.windowX = panel.frame.minX
        store.settings.windowY = panel.frame.minY
    }
    @objc func screenChanged() {
        let screen = bestScreen(for: panel.frame)
        panel.setFrame(clamped(panel.frame, to: screen.visibleFrame), display: true)
    }
    @objc func willSleep() { store.tick(); store.save() }
    @objc func didWake() { store.tick(); store.save() }
    @objc func showRoom() { store.setMode(.room) }
    @objc func showPet() { store.setMode(.pet) }
    @objc func showCompact() { store.setMode(.compact) }
    @objc func togglePin() { store.togglePin() }
    @objc func toggleDim() { store.toggleDim() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func hide() { store.leaveFishing(); store.save(); panel.orderOut(nil) }
    @objc func toggleVisibility() {
        if panel.isVisible { hide() } else { panel.orderFrontRegardless() }
    }
}

struct WindowDragHandle: NSViewRepresentable {
    var onDoubleClick: (() -> Void)? = nil
    func makeNSView(context: Context) -> DragRegion { let view = DragRegion(); view.onDoubleClick = onDoubleClick; return view }
    func updateNSView(_ nsView: DragRegion, context: Context) { nsView.onDoubleClick = onDoubleClick }
    final class DragRegion: NSView {
        var onDoubleClick: (() -> Void)?
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2, let onDoubleClick { onDoubleClick() }
            else { window?.performDrag(with: event) }
        }
    }
}

#if !TESTING
@main
struct CornerCatEntry {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
#endif
