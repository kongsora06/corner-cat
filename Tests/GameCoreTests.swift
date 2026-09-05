import Foundation

@main
struct GameCoreTests {
    static var assertions = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        guard condition() else { fatalError("FAIL: \(message)") }
    }

    static func near(_ value: Double, _ expected: Double, _ message: String, tolerance: Double = 0.000001) {
        expect(value.isFinite && abs(value - expected) <= tolerance, "\(message): \(value) != \(expected)")
    }

    static func main() throws {
        try testPersistenceAndRepair()
        testElapsedTimeInvariance()
        testInvalidElapsedTime()
        testProgressionAndPurchases()
        testInteractions()
        testFishingAwards()
        print("PASS: \(assertions) assertions across persistence, time integration, economy, unlocks, cooldowns and fishing")
    }

    static func testElapsedTimeInvariance() {
        for activity in ActivityKind.allCases {
            for initialMood in [35.0, 55.0, 85.0, 100.0] {
                var whole = GameState()
                whole.xp = 200
                whole.activity = activity
                whole.mood = initialMood
                whole.upgrades = ["planter": 2, "watering": 1, "cushion": 1]
                var pieces = whole
                whole.advance(seconds: 8 * 3600)
                for _ in 0..<960 { pieces.advance(seconds: 30) }
                near(whole.dew, pieces.dew, "\(activity) / \(initialMood) interval-independent dew")
                near(whole.totalEarned, pieces.totalEarned, "interval-independent lifetime earnings")
                near(whole.xp, pieces.xp, "interval-independent XP")
                near(whole.mood, pieces.mood, "interval-independent mood")
                near(whole.totalPlaySeconds, pieces.totalPlaySeconds, "interval-independent playtime")
                expect(whole.mood >= 35 && whole.mood <= 100, "mood remains comfortable")
            }
        }
        var resting = GameState()
        resting.mood = 35
        resting.activity = .nap
        resting.advance(seconds: 1000)
        near(resting.mood, 100, "nap restores full mood")
        var exploring = GameState()
        exploring.xp = 30
        exploring.activity = .explore
        exploring.advance(seconds: 86_400)
        near(exploring.mood, 35, "exploration has a nonzero mood floor")
        expect(exploring.productionPerMinute > 0, "pet continues earning at the mood floor")

        var garden = GameState()
        garden.xp = 30
        var explorer = garden
        explorer.activity = .explore
        near(explorer.productionPerMinute, garden.productionPerMinute * 0.65, "exploration trades income for growth")
        garden.advance(seconds: 60)
        explorer.advance(seconds: 60)
        near(garden.xp, 38, "garden earns eight XP per minute")
        near(explorer.xp, 48, "exploration earns eighteen XP per minute")
        expect(explorer.dew < garden.dew, "garden earns more dew than exploration")
    }

    static func testInvalidElapsedTime() {
        var state = GameState()
        for delta in [-100.0, 0, Double.nan, Double.infinity, -Double.infinity] {
            state.advance(seconds: delta)
            near(state.dew, 30, "invalid delta does not change income")
            near(state.totalPlaySeconds, 0, "invalid delta does not add playtime")
        }
        var capped = GameState()
        state.advance(seconds: Double.greatestFiniteMagnitude)
        capped.advance(seconds: GameState.maximumAdvanceSeconds)
        near(state.dew, capped.dew, "pathological delta uses documented cap")
        near(state.totalPlaySeconds, GameState.maximumAdvanceSeconds, "time uses documented cap")
        expect(state.dew.isFinite && state.xp.isFinite, "huge time cannot overflow economics")
    }

    static func testProgressionAndPurchases() {
        var state = GameState()
        expect(state.level == 1 && state.xpInLevel == 0, "initial level")
        near(state.xpForNextLevel, 30, "first level threshold")
        near(state.upgradeCost(.planter), 25, "first purchase affordable immediately")
        let oldRate = state.productionPerMinute
        expect(state.buyUpgrade(.planter), "can buy first planter")
        near(state.dew, 5, "upgrade deducts exact cost")
        near(state.productionPerMinute, oldRate * 1.55, "planter improves income")
        expect(!state.buyUpgrade(.planter), "cannot spend unavailable dew")
        expect(!state.setActivity(.explore), "exploration starts locked")
        state.dew = 10000
        expect(!state.buyUpgrade(.watering), "watering requires level two")
        expect(!state.buyUpgrade(.cushion), "cushion requires level three")
        state.xp = 30
        expect(state.level == 2 && state.xpInLevel == 0, "exact level boundary")
        near(state.xpForNextLevel, 48, "second threshold")
        expect(state.setActivity(.explore), "level two unlocks exploration")
        expect(state.buyUpgrade(.watering), "level two unlocks watering")
        expect(!state.buyDecor("rug"), "higher-level decoration remains locked")
        expect(state.buyDecor("plant"), "can buy available decoration")
        expect(state.equippedDecor == "plant", "new decoration automatically equipped")
        let afterDecor = state.dew
        expect(!state.buyDecor("plant"), "cannot buy duplicate decoration")
        near(state.dew, afterDecor, "duplicate purchase does not spend")
        expect(state.equipDecor("none"), "can restore default look")
        expect(!state.equipDecor("stars"), "cannot equip unowned item")
        expect(!state.buyDecor("unknown"), "unknown decoration rejected")
        state.xp = 78
        expect(state.level == 3 && state.buyUpgrade(.cushion), "level three unlocks cushion")
        state.upgrades["planter"] = GameState.maximumUpgradeLevel
        state.dew = 1_000_000_000_000
        expect(!state.buyUpgrade(.planter), "maximum upgrade level enforced")
        expect(state.upgradeCost(.planter).isFinite, "maximum cost remains finite")
    }

    static func testInteractions() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var state = GameState()
        expect(state.pet(now: now), "first pet succeeds")
        near(state.dew, 32, "pet gives small dew reward")
        expect(state.bond == 1 && state.xp == 6, "pet improves bond and XP")
        expect(!state.pet(now: now), "repeated pet blocked")
        near(state.petCooldownRemaining(now: now.addingTimeInterval(7)), 8, "pet countdown")
        expect(!state.pet(now: now.addingTimeInterval(-500)), "clock rollback cannot bypass cooldown")
        near(state.petCooldownRemaining(now: now.addingTimeInterval(-500)), 15, "rollback cooldown stays bounded")
        expect(state.pet(now: now.addingTimeInterval(15)), "pet at cooldown boundary succeeds")
        expect(state.feed(now: now), "feeding succeeds")
        near(state.dew, 22, "feeding deducts twelve dew")
        expect(state.bond == 4, "feeding improves bond")
        expect(!state.feed(now: now.addingTimeInterval(29.999)), "feed cooldown enforced")
        expect(state.feed(now: now.addingTimeInterval(30)), "feed cooldown boundary succeeds")
        state.dew = 0
        expect(!state.feed(now: now.addingTimeInterval(60)), "feeding cannot create negative balance")
        near(state.feedCooldownRemaining(now: now.addingTimeInterval(60)), 0, "failed purchase does not consume cooldown")
        expect(!state.pet(now: Date(timeIntervalSince1970: .nan)), "invalid interaction date rejected")
    }

    static func testFishingAwards() {
        for (input, score) in [(Int.min, 0), (-1, 0), (0, 0), (3, 3), (4, 4), (6, 6), (7, 6), (Int.max, 6)] {
            var state = GameState()
            state.awardFishing(score: input)
            near(state.dew, 33 + Double(3 * score), "fishing dew for score \(input)")
            near(state.totalEarned, state.dew, "fishing contributes to total earnings")
            near(state.xp, 4 + Double(2 * score), "fishing XP for score \(input)")
            near(state.mood, 88, "fishing improves mood")
            expect(state.bond == (score >= 4 ? 1 : 0), "good fishing alone awards bond")
        }
        var capped = GameState()
        capped.dew = 1_000_000_000_000
        capped.xp = 1_000_000_000
        capped.mood = 99
        capped.bond = 1_000_000
        capped.awardFishing(score: Int.max)
        near(capped.dew, 1_000_000_000_000, "fishing respects balance cap")
        near(capped.xp, 1_000_000_000, "fishing respects XP cap")
        near(capped.mood, 100, "fishing mood is capped")
        expect(capped.bond == 1_000_000, "fishing bond is capped")
        var corrupted = GameState()
        corrupted.dew = .nan
        corrupted.xp = .infinity
        corrupted.awardFishing(score: 6)
        near(corrupted.dew, 21, "fishing repairs corrupt balance before reward")
        near(corrupted.xp, 16, "fishing repairs corrupt XP before reward")
    }

    static func testPersistenceAndRepair() throws {
        var state = GameState()
        state.xp = 300
        state.dew = 700
        state.activity = .explore
        state.lastSaved = Date(timeIntervalSince1970: 1_700_000_000)
        _ = state.buyUpgrade(.planter)
        _ = state.buyDecor("lamp")
        _ = state.pet(now: state.lastSaved)
        state.advance(seconds: 211.5)
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        near(restored.dew, state.dew, "saved balance round trip")
        near(restored.xp, state.xp, "saved XP round trip")
        near(restored.mood, state.mood, "saved mood round trip")
        expect(restored.activity == .explore && restored.equippedDecor == "lamp", "activity and decoration round trip")
        expect(restored.lastPet == state.lastPet && restored.lastSaved == state.lastSaved, "timestamps round trip")
        let oldSave = Data(#"{"dew":-20,"xp":78,"mood":-400,"activity":"futureActivity","upgrades":{"planter":-4,"watering":999999,"unknown":8},"unlockedDecor":["lamp","lamp","unknown"],"equippedDecor":"unknown"}"#.utf8)
        let repaired = try JSONDecoder().decode(GameState.self, from: oldSave)
        near(repaired.dew, 0, "negative balance repaired")
        near(repaired.mood, 35, "mood floor repaired")
        expect(repaired.activity == .garden, "unknown activity falls back safely")
        expect(repaired.upgradeLevel(.planter) == 0 && repaired.upgradeLevel(.watering) == 50, "upgrade bounds repaired")
        expect(repaired.upgrades["unknown"] == nil, "unknown upgrades removed")
        expect(repaired.unlockedDecor == ["none", "lamp"] && repaired.equippedDecor == "none", "decorations repaired and deduplicated")
        let sparse = try JSONDecoder().decode(GameState.self, from: Data(#"{"dew":"broken","mood":null}"#.utf8))
        near(sparse.dew, 30, "wrong field type uses safe default")
        near(sparse.mood, 85, "missing field uses safe default")
        var corrupted = GameState()
        corrupted.dew = .infinity
        corrupted.xp = .nan
        corrupted.totalEarned = -40
        corrupted.mood = .nan
        corrupted.totalPlaySeconds = .infinity
        corrupted.bond = Int.max
        corrupted.sanitize()
        expect(corrupted.dew.isFinite && corrupted.xp.isFinite && corrupted.totalPlaySeconds.isFinite, "nonfinite fields repaired")
        expect(corrupted.level == 1 && corrupted.bond == 1_000_000, "integer computations remain bounded")
        _ = try JSONEncoder().encode(corrupted)
    }
}
