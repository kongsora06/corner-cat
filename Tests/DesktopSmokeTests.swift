import AppKit
import SwiftUI

@main
struct DesktopSmokeTests {
    @MainActor static func main() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("cornercat-smoke-\(UUID().uuidString)")
        setenv("CORNER_CAT_TEST_SAVE_DIR", directory.path, 1)
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                try run(delegate)
                print("Desktop smoke tests: 37 assertions passed")
                delegate.store.onQuit = nil
                delegate.panel.orderOut(nil)
                try? FileManager.default.removeItem(at: directory)
                // Stop the test process without applicationWillTerminate creating
                // another save in the temporary directory we just removed.
                app.delegate = nil
                app.terminate(nil)
            } catch {
                fputs("Desktop smoke tests failed: \(error)\n", stderr)
                exit(1)
            }
        }
        withExtendedLifetime(delegate) { app.run() }
    }

    @MainActor static func run(_ delegate: AppDelegate) throws {
        let store = delegate.store!
        check(delegate.panel.isVisible, "initial window visible")
        check(delegate.panel.frame.size == NSSize(width: 320, height: 452), "room bounds")
        check(delegate.statusItem.button != nil, "menu bar restore control")
        check(!delegate.panel.isOpaque, "transparent backing")
        check(!delegate.panel.hidesOnDeactivate, "desktop persistence")
        check(delegate.panel.level == .floating, "default on top")
        let initial = store.game.dew
        store.game.lastPet = nil
        store.pet()
        check(store.game.dew >= initial + 2, "pet reward")
        let bond = store.game.bond
        store.pet()
        check(store.game.bond == bond, "pet cannot double claim")
        store.buy(.planter)
        check(store.game.upgradeLevel(.planter) == 1, "first upgrade affordable")
        store.setActivity(.explore)
        check(store.game.activity == .garden, "locked activity guarded")

        store.fishingRecord.lastStartedAt = nil
        store.startFishing()
        check(store.fishingSession != nil, "start mini-game")
        let beforeFish = store.game.dew
        for _ in 0..<3 {
            let session = store.fishingSession!
            let date = session.roundStartedAt.addingTimeInterval(session.target * (1.8 - Double(session.catches.count) * 0.18))
            store.castFishing(at: date)
        }
        check(store.fishingSession!.score == 6, "perfect skill session")
        check(store.game.dew == beforeFish + 21, "fishing award once")
        store.castFishing()
        check(store.game.dew == beforeFish + 21, "no duplicate award")
        check(store.fishingRecord.completedRounds == 1, "fishing record")
        store.startFishing()
        check(store.fishingRecord.completedRounds == 1 && store.fishingSession!.finished, "fishing cooldown")
        store.fishingRecord.lastStartedAt = nil
        store.startFishing()
        delegate.hide()
        check(store.fishingSession == nil, "hiding cancels active fishing")
        check(!delegate.panel.isVisible, "hide")
        delegate.toggleVisibility()
        check(delegate.panel.isVisible, "restore")

        store.setMode(.compact)
        check(delegate.panel.frame.size == NSSize(width: 164, height: 34), "compact bounds")
        store.setMode(.pet)
        check(delegate.panel.frame.size == NSSize(width: 120, height: 120), "pet bounds")
        check(!delegate.panel.hasShadow, "transparent pet shadow")
        store.setMode(.room)
        check(delegate.panel.hasShadow, "room shadow restored")
        store.toggleDim()
        check(abs(delegate.panel.alphaValue - 0.72) < 0.001, "opacity")
        store.togglePin()
        check(delegate.panel.level == .normal, "unpin")
        let clamped = delegate.clamped(NSRect(x: -9000, y: -9000, width: 320, height: 452), to: NSRect(x: 0, y: 0, width: 1440, height: 900))
        check(clamped.minX == 0 && clamped.minY == 0, "offscreen clamping")

        store.save()
        check(FileManager.default.fileExists(atPath: store.saveURL.path), "save file")
        let restored = GameStore()
        check(restored.game.upgradeLevel(.planter) == 1, "persist upgrades")
        check(restored.settings.dimmed, "persist preferences")
        check(restored.fishingRecord.completedRounds == 1, "persist fishing")
        check(abs(restored.game.dew - store.game.dew) < 1, "persist currency")

        var expected = store.game
        expected.advance(seconds: 8 * 3600)
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: store.saveURL)) as! [String: Any]
        var gameObject = object["game"] as! [String: Any]
        gameObject["lastSaved"] = Date().addingTimeInterval(-12 * 3600).timeIntervalSinceReferenceDate
        object["game"] = gameObject
        try JSONSerialization.data(withJSONObject: object).write(to: store.saveURL, options: .atomic)
        let offline = GameStore()
        check(abs(offline.game.dew - expected.dew) < 0.001, "offline capped at eight hours")
        check(offline.offlineDew > 0, "offline receipt")
        check(offline.game.level > store.game.level, "offline levels")

        // A broken primary save must fall back to the last valid backup.
        try Data("invalid save".utf8).write(to: store.saveURL)
        let recovery = GameStore()
        check(recovery.game.upgradeLevel(.planter) == 1, "backup recovery")
        check(recovery.toast.contains("备用"), "recovery visible")
        let partial = try JSONDecoder().decode(AppSettings.self, from: Data("{\"mode\":\"unknown\"}".utf8))
        check(partial.mode == .room && partial.alwaysOnTop, "settings migration defaults")
        print("Global hotkey registration: \(store.hotkeyAvailable ? "available" : "conflict surfaced in help")")
    }

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
}
