import Foundation

enum UpgradeKind: String, CaseIterable, Codable {
    case planter, watering, cushion

    var title: String {
        switch self {
        case .planter: return "苔藓花盆"
        case .watering: return "自动浇水"
        case .cushion: return "软软坐垫"
        }
    }

    var detail: String {
        switch self {
        case .planter: return "每级增加 55% 基础产量"
        case .watering: return "每级增加 30% 花园效率"
        case .cushion: return "提高舒适底线，午睡恢复更快"
        }
    }

    var symbol: String {
        switch self {
        case .planter: return "leaf.fill"
        case .watering: return "drop.fill"
        case .cushion: return "bed.double.fill"
        }
    }

    var requiredLevel: Int {
        switch self {
        case .planter: return 1
        case .watering: return 2
        case .cushion: return 3
        }
    }
}

enum ActivityKind: String, CaseIterable, Codable {
    case garden, explore, nap

    var title: String {
        switch self {
        case .garden: return "照料花园"
        case .explore: return "角落探险"
        case .nap: return "晒太阳午睡"
        }
    }

    var detail: String {
        switch self {
        case .garden: return "慢慢收集露珠，舒舒服服成长"
        case .explore: return "露珠较少，成长更快；外出探索容易犯困"
        case .nap: return "恢复心情，同时收集少量露珠"
        }
    }

    var symbol: String {
        switch self {
        case .garden: return "leaf.fill"
        case .explore: return "map.fill"
        case .nap: return "moon.zzz.fill"
        }
    }

    var requiredLevel: Int { self == .explore ? 2 : 1 }
    var cycleSeconds: Double {
        switch self {
        case .garden: return 60
        case .explore: return 120
        case .nap: return 90
        }
    }
}

struct Decoration: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let requiredLevel: Int
    let price: Double
    let symbol: String
}

/// A Foundation-only, persistent simulation. XP is lifetime XP, not the current
/// level's remainder. Advancing time neither reads the wall clock nor saves files.
struct GameState: Codable {
    static let maximumAdvanceSeconds: Double = 7 * 24 * 60 * 60
    static let maximumUpgradeLevel = 50
    static let petCooldown: Double = 15
    static let feedCooldown: Double = 30
    static let feedCost: Double = 12
    private static let economicLimit: Double = 1_000_000_000_000
    private static let xpLimit: Double = 1_000_000_000

    static let decorations: [Decoration] = [
        Decoration(id: "none", name: "小小角落", detail: "给自己留一点空白", requiredLevel: 1, price: 0, symbol: "square.dashed"),
        Decoration(id: "plant", name: "一株新绿", detail: "窗边冒出了一点生机", requiredLevel: 2, price: 60, symbol: "leaf.fill"),
        Decoration(id: "rug", name: "柔软地毯", detail: "踩上去，都是好心情", requiredLevel: 3, price: 120, symbol: "square.fill"),
        Decoration(id: "lamp", name: "暖黄小灯", detail: "深夜也有一盏灯陪你", requiredLevel: 4, price: 240, symbol: "lamp.desk.fill"),
        Decoration(id: "stars", name: "星星挂饰", detail: "把一小片夜空带回家", requiredLevel: 6, price: 450, symbol: "sparkles")
    ]

    var dew: Double = 30
    var totalEarned: Double = 30
    var xp: Double = 0
    var bond: Int = 0
    var mood: Double = 85
    var upgrades: [String: Int] = [:]
    var activity: ActivityKind = .garden
    var unlockedDecor: [String] = ["none"]
    var equippedDecor: String = "none"
    var lastSaved: Date = Date()
    var lastPet: Date?
    var lastFeed: Date?
    var totalPlaySeconds: Double = 0

    init() {}

    // Costs increase by 18 XP each level: 30, 48, 66, ... . Using the closed
    // form keeps a large offline gain independent of simulation tick size.
    var level: Int {
        let safeXP = Self.bounded(xp, upper: Self.xpLimit)
        return 1 + Int(floor((sqrt(441 + 36 * safeXP) - 21) / 18))
    }

    var xpInLevel: Double {
        let completed = Double(level - 1)
        return max(0, Self.bounded(xp, upper: Self.xpLimit) - (9 * completed * completed + 21 * completed))
    }

    var xpForNextLevel: Double { 30 + Double(level - 1) * 18 }

    var productionPerMinute: Double {
        baseProductionPerMinute * (0.7 + 0.003 * Self.bounded(mood, upper: 100))
    }

    var currentRate: Double { productionPerMinute }

    var activityProgress: Double {
        Self.bounded(totalPlaySeconds, upper: Self.economicLimit)
            .truncatingRemainder(dividingBy: activity.cycleSeconds) / activity.cycleSeconds
    }

    var nextUnlock: String {
        switch level {
        case 1: return "Lv.2 解锁角落探险、自动浇水和绿植"
        case 2: return "Lv.3 解锁软软坐垫和地毯"
        case 3: return "Lv.4 解锁暖黄小灯"
        case 4...5: return "Lv.6 解锁星星挂饰"
        default: return "角落已全部解锁，继续陪伴它成长"
        }
    }

    private var baseProductionPerMinute: Double {
        let planter = 1 + 0.55 * Double(upgradeLevel(.planter))
        let watering = 1 + 0.30 * Double(upgradeLevel(.watering))
        let multiplier: Double
        switch activity {
        case .garden: multiplier = 1
        case .explore: multiplier = 0.65
        case .nap: multiplier = 0.55
        }
        return 6 * planter * watering * multiplier
    }

    /// Advances at most seven days per call. Non-finite, zero and negative
    /// intervals are ignored. The app separately caps an offline award at 8h.
    /// Mood moves linearly to a comfortable resting point, and its effect on
    /// income is integrated exactly, including when it reaches that point.
    mutating func advance(seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        sanitize()
        let elapsed = min(seconds, Self.maximumAdvanceSeconds)
        let comfort = Double(upgradeLevel(.cushion))
        let target: Double
        let speed: Double
        let xpPerMinute: Double
        switch activity {
        case .garden:
            target = min(85, 55 + comfort * 2)
            speed = mood > target ? 0.0025 : 0.012
            xpPerMinute = 8
        case .explore:
            target = min(80, 35 + comfort * 3)
            speed = 0.01
            xpPerMinute = 18
        case .nap:
            target = 100
            speed = 0.12 * (1 + comfort * 0.15)
            xpPerMinute = 5
        }
        let movingSeconds = min(elapsed, abs(target - mood) / speed)
        let slope = mood < target ? speed : -speed
        let moodIntegral = mood * movingSeconds
            + 0.5 * slope * movingSeconds * movingSeconds
            + target * (elapsed - movingSeconds)
        let earned = baseProductionPerMinute / 60 * (0.7 * elapsed + 0.003 * moodIntegral)
        mood = movingSeconds < elapsed ? target : min(100, max(35, mood + slope * movingSeconds))
        addEarnings(earned)
        xp = min(Self.xpLimit, xp + elapsed / 60 * xpPerMinute)
        totalPlaySeconds = min(Self.economicLimit, totalPlaySeconds + elapsed)
    }

    func upgradeLevel(_ kind: UpgradeKind) -> Int {
        min(Self.maximumUpgradeLevel, max(0, upgrades[kind.rawValue] ?? 0))
    }

    func upgradeCost(_ kind: UpgradeKind) -> Double {
        let base: Double
        switch kind {
        case .planter: base = 25
        case .watering: base = 55
        case .cushion: base = 75
        }
        return min(Self.economicLimit, (base * pow(1.48, Double(upgradeLevel(kind)))).rounded(.up))
    }

    func upgradeUnlocked(_ kind: UpgradeKind) -> Bool { level >= kind.requiredLevel }

    @discardableResult
    mutating func buyUpgrade(_ kind: UpgradeKind) -> Bool {
        sanitize()
        let cost = upgradeCost(kind)
        guard upgradeUnlocked(kind), upgradeLevel(kind) < Self.maximumUpgradeLevel, dew >= cost else { return false }
        dew -= cost
        upgrades[kind.rawValue] = upgradeLevel(kind) + 1
        return true
    }

    func activityUnlocked(_ kind: ActivityKind) -> Bool { level >= kind.requiredLevel }

    @discardableResult
    mutating func setActivity(_ kind: ActivityKind) -> Bool {
        guard activityUnlocked(kind) else { return false }
        activity = kind
        return true
    }

    func petCooldownRemaining(now: Date) -> Double {
        Self.cooldownRemaining(last: lastPet, now: now, duration: Self.petCooldown)
    }

    func feedCooldownRemaining(now: Date) -> Double {
        Self.cooldownRemaining(last: lastFeed, now: now, duration: Self.feedCooldown)
    }

    @discardableResult
    mutating func pet(now: Date) -> Bool {
        guard now.timeIntervalSince1970.isFinite, petCooldownRemaining(now: now) == 0 else { return false }
        sanitize()
        lastPet = now
        mood = min(100, mood + 5)
        bond = min(1_000_000, bond + 1)
        xp = min(Self.xpLimit, xp + 6)
        addEarnings(2)
        return true
    }

    @discardableResult
    mutating func feed(now: Date) -> Bool {
        guard now.timeIntervalSince1970.isFinite, feedCooldownRemaining(now: now) == 0 else { return false }
        sanitize()
        guard dew >= Self.feedCost else { return false }
        dew -= Self.feedCost
        lastFeed = now
        mood = min(100, mood + 18)
        bond = min(1_000_000, bond + 2)
        xp = min(Self.xpLimit, xp + 10)
        return true
    }

    /// The presentation layer owns fishing sessions and cooldowns and calls
    /// this once for a completed game. Even a missed catch gives a small reward.
    mutating func awardFishing(score: Int) {
        sanitize()
        let safeScore = min(6, max(0, score))
        addEarnings(Double(3 + 3 * safeScore))
        xp = min(Self.xpLimit, xp + Double(4 + 2 * safeScore))
        mood = min(100, mood + 3)
        if safeScore >= 4 { bond = min(1_000_000, bond + 1) }
    }

    @discardableResult
    mutating func buyDecor(_ id: String) -> Bool {
        sanitize()
        guard let decoration = Self.decorations.first(where: { $0.id == id }),
              !unlockedDecor.contains(id), level >= decoration.requiredLevel,
              dew >= decoration.price else { return false }
        dew -= decoration.price
        unlockedDecor.append(id)
        equippedDecor = id
        return true
    }

    @discardableResult
    mutating func equipDecor(_ id: String) -> Bool {
        guard Self.decorations.contains(where: { $0.id == id }), unlockedDecor.contains(id) else { return false }
        equippedDecor = id
        return true
    }

    /// Repairs old or hand-edited saves without granting unknown upgrades or
    /// decorations. No absence penalty, currency loss, or pet death exists.
    mutating func sanitize() {
        dew = Self.bounded(dew, upper: Self.economicLimit)
        totalEarned = max(dew, Self.bounded(totalEarned, upper: Self.economicLimit))
        xp = Self.bounded(xp, upper: Self.xpLimit)
        bond = min(1_000_000, max(0, bond))
        mood = mood.isFinite ? min(100, max(35, mood)) : 85
        totalPlaySeconds = Self.bounded(totalPlaySeconds, upper: Self.economicLimit)
        upgrades = Dictionary(uniqueKeysWithValues: UpgradeKind.allCases.map { ($0.rawValue, upgradeLevel($0)) })
        let knownDecor = Set(Self.decorations.map(\.id))
        var seen: Set<String> = ["none"]
        unlockedDecor = ["none"] + unlockedDecor.filter { knownDecor.contains($0) && seen.insert($0).inserted }
        if !unlockedDecor.contains(equippedDecor) { equippedDecor = "none" }
        if !lastSaved.timeIntervalSince1970.isFinite { lastSaved = Date() }
        if let value = lastPet, !value.timeIntervalSince1970.isFinite { lastPet = nil }
        if let value = lastFeed, !value.timeIntervalSince1970.isFinite { lastFeed = nil }
        if !activityUnlocked(activity) { activity = .garden }
    }

    private mutating func addEarnings(_ amount: Double) {
        let safeAmount = Self.bounded(amount, upper: Self.economicLimit)
        dew = min(Self.economicLimit, dew + safeAmount)
        totalEarned = min(Self.economicLimit, totalEarned + safeAmount)
    }

    private static func bounded(_ value: Double, upper: Double) -> Double {
        value.isFinite ? min(upper, max(0, value)) : 0
    }

    private static func cooldownRemaining(last: Date?, now: Date, duration: Double) -> Double {
        guard let last else { return 0 }
        let elapsed = now.timeIntervalSince(last)
        // Moving the system clock backwards cannot bypass an interaction cooldown.
        guard elapsed.isFinite else { return duration }
        return min(duration, max(0, duration - elapsed))
    }

    private enum CodingKeys: String, CodingKey {
        case dew, totalEarned, xp, bond, mood, upgrades, activity, unlockedDecor,
             equippedDecor, lastSaved, lastPet, lastFeed, totalPlaySeconds
    }

    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        dew = (try? values.decode(Double.self, forKey: .dew)) ?? dew
        totalEarned = (try? values.decode(Double.self, forKey: .totalEarned)) ?? totalEarned
        xp = (try? values.decode(Double.self, forKey: .xp)) ?? xp
        bond = (try? values.decode(Int.self, forKey: .bond)) ?? bond
        mood = (try? values.decode(Double.self, forKey: .mood)) ?? mood
        upgrades = (try? values.decode([String: Int].self, forKey: .upgrades)) ?? upgrades
        activity = (try? values.decode(ActivityKind.self, forKey: .activity)) ?? activity
        unlockedDecor = (try? values.decode([String].self, forKey: .unlockedDecor)) ?? unlockedDecor
        equippedDecor = (try? values.decode(String.self, forKey: .equippedDecor)) ?? equippedDecor
        lastSaved = (try? values.decode(Date.self, forKey: .lastSaved)) ?? lastSaved
        lastPet = try? values.decode(Date.self, forKey: .lastPet)
        lastFeed = try? values.decode(Date.self, forKey: .lastFeed)
        totalPlaySeconds = (try? values.decode(Double.self, forKey: .totalPlaySeconds)) ?? totalPlaySeconds
        sanitize()
    }
}
