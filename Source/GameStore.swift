import Foundation
import Combine

enum DisplayMode: String, Codable { case room, pet, compact }

struct AppSettings: Codable {
    var mode: DisplayMode = .room
    var alwaysOnTop = true
    var dimmed = false
    var windowX: Double? = nil
    var windowY: Double? = nil
    init() {}
    private enum CodingKeys: String, CodingKey { case mode, alwaysOnTop, dimmed, windowX, windowY }
    init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = (try? container.decode(DisplayMode.self, forKey: .mode)) ?? .room
        alwaysOnTop = (try? container.decode(Bool.self, forKey: .alwaysOnTop)) ?? true
        dimmed = (try? container.decode(Bool.self, forKey: .dimmed)) ?? false
        windowX = try? container.decode(Double.self, forKey: .windowX)
        windowY = try? container.decode(Double.self, forKey: .windowY)
        if windowX?.isFinite != true { windowX = nil }
        if windowY?.isFinite != true { windowY = nil }
    }
}

private struct SaveEnvelope: Codable {
    var version = 1
    var game: GameState
    var settings: AppSettings
    var fishing: FishingRecord? = nil
}

@MainActor
final class GameStore: ObservableObject {
    @Published var game = GameState()
    @Published var settings = AppSettings()
    @Published var toast = ""
    @Published var reaction = ""
    @Published var offlineDew: Double = 0
    @Published var saveError = false
    @Published var hotkeyAvailable = true
    @Published var fishingRecord = FishingRecord()
    @Published var fishingSession: FishingSession? = nil
    @Published var selectedTab = 0
    @Published var now = Date()
    let saveURL: URL
    private var timer: AnyCancellable?
    private var lastTick = Date()
    private var saveCounter = 0
    private var toastSerial = 0
    private var reactionSerial = 0
    private let offlineLimit = 8.0 * 3600
    var onModeChange: ((DisplayMode) -> Void)?
    var onAppearanceChange: (() -> Void)?
    var onHide: (() -> Void)?
    var onQuit: (() -> Void)?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let isQA = Bundle.main.bundleIdentifier?.hasSuffix(".qa") == true
        let folder: URL
        if let testDirectory = ProcessInfo.processInfo.environment["CORNER_CAT_TEST_SAVE_DIR"] {
            folder = URL(fileURLWithPath: testDirectory, isDirectory: true)
        } else {
            folder = support.appendingPathComponent(isQA ? "CornerCat-QA" : "CornerCat", isDirectory: true)
        }
        saveURL = folder.appendingPathComponent("save.json")
        load()
        lastTick = Date()
        now = lastTick
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] date in
            self?.tick(date)
        }
    }

    private func load() {
        let candidates = [saveURL, saveURL.appendingPathExtension("backup")]
        var didLoad = false
        for url in candidates {
            guard let data = try? Data(contentsOf: url),
                  let saved = try? JSONDecoder().decode(SaveEnvelope.self, from: data), saved.version == 1 else { continue }
            game = saved.game
            game.sanitize()
            settings = saved.settings
            fishingRecord = saved.fishing ?? FishingRecord()
            let elapsed = max(0, min(offlineLimit, Date().timeIntervalSince(game.lastSaved)))
            let before = game.dew
            game.advance(seconds: elapsed)
            if elapsed >= 60 { offlineDew = max(0, game.dew - before) }
            if url != saveURL { toast = "已从备用存档恢复" }
            didLoad = true
            break
        }
        if !didLoad && FileManager.default.fileExists(atPath: saveURL.path) {
            // Preserve an unreadable save before the first automatic save.
            let preserved = saveURL.deletingLastPathComponent().appendingPathComponent("save-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: saveURL, to: preserved)
            toast = "旧存档无法读取，已保留副本"
        }
    }

    func tick(_ date: Date = Date()) {
        let delta = max(0, min(offlineLimit, date.timeIntervalSince(lastTick)))
        lastTick = date
        now = date
        let previousLevel = game.level
        game.advance(seconds: delta)
        if let session = fishingSession, !session.finished, date.timeIntervalSince(session.roundStartedAt) > 6 {
            castFishing(at: date)
        }
        if game.level > previousLevel { showToast("升到 Lv.\(game.level) 了，去看看新解锁吧") }
        saveCounter += 1
        if saveCounter >= 15 { save(); saveCounter = 0 }
    }

    func save() {
        game.lastSaved = lastTick
        do {
            let directory = saveURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(SaveEnvelope(game: game, settings: settings, fishing: fishingRecord))
            if let old = try? Data(contentsOf: saveURL), (try? JSONDecoder().decode(SaveEnvelope.self, from: old)) != nil {
                try? old.write(to: saveURL.appendingPathExtension("backup"), options: .atomic)
            }
            try data.write(to: saveURL, options: .atomic)
            saveError = false
        } catch {
            saveError = true
            showToast("存档暂时写入失败，请检查磁盘空间")
        }
    }

    func setMode(_ mode: DisplayMode) {
        settings.mode = mode
        onModeChange?(mode)
        save()
    }

    func pet() {
        tick()
        if game.pet(now: now) {
            react("heart")
            showToast("呼噜呼噜…  亲密度 +1")
            save()
        } else {
            react("heart")
            showToast("小猫蹭了蹭你的手，等一会儿再领亲密度")
        }
    }

    func feed() {
        tick()
        if game.feed(now: now) {
            react("feed")
            showToast("开饭啦！心情和亲密度提升")
            save()
        } else if game.dew < 12 {
            showToast("小鱼干需要 12 露珠，再攒一点吧")
        } else {
            showToast("小猫还在回味，稍等一下再喂")
        }
    }

    func setActivity(_ activity: ActivityKind) {
        tick()
        _ = game.setActivity(activity)
        save()
    }

    func buy(_ kind: UpgradeKind) {
        tick()
        if game.buyUpgrade(kind) {
            react("sparkle")
            showToast(kind == .cushion ? "猫窝更舒服了，心情恢复更快" : "升级完成，每分钟产量提升了")
            save()
        } else { showToast("再攒一点露珠，就能升级啦") }
    }

    func chooseDecor(_ id: String) {
        tick()
        if game.unlockedDecor.contains(id) {
            if game.equipDecor(id) { showToast("换好啦，角落又有点不一样了") }
        } else if game.buyDecor(id) {
            _ = game.equipDecor(id)
            showToast("新摆件到家！")
            react("sparkle")
        } else { showToast("达到需要的等级、攒够露珠就能带回家") }
        save()
    }

    func togglePin() { settings.alwaysOnTop.toggle(); onAppearanceChange?(); save() }
    func toggleDim() { settings.dimmed.toggle(); onAppearanceChange?(); save() }

    var fishingCooldown: Double { fishingRecord.cooldownRemaining(at: now) }

    func startFishing() {
        tick()
        guard fishingCooldown == 0 else { return }
        fishingRecord.lastStartedAt = now
        fishingSession = FishingSession(startedAt: now)
        save()
    }

    func castFishing(at date: Date = Date()) {
        guard var session = fishingSession, !session.finished else { return }
        guard session.cast(at: date) else { return }
        fishingSession = session
        if session.finished {
            let score = session.score
            game.awardFishing(score: score)
            fishingRecord.recordCompletion(score: score)
            react(score >= 4 ? "heart" : "feed")
            save()
        }
    }

    func leaveFishing() {
        if fishingSession?.finished == false { fishingSession = nil }
    }

    func showToast(_ text: String) {
        toastSerial += 1
        let serial = toastSerial
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard let self, self.toastSerial == serial else { return }
            self.toast = ""
        }
    }

    func react(_ value: String) {
        reactionSerial += 1
        let serial = reactionSerial
        reaction = value
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self, self.reactionSerial == serial else { return }
            self.reaction = ""
        }
    }
}
