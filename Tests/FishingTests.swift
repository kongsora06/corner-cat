import Foundation

@main
struct FishingTests {
    static var assertions = 0
    static let start = Date(timeIntervalSince1970: 1_700_000_000)

    static func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        guard value() else { fatalError("FAIL: \(message)") }
    }

    static func near(_ value: Double, _ expected: Double, _ message: String) {
        expect(value.isFinite && abs(value - expected) < 0.00001, "\(message): \(value) != \(expected)")
    }

    static func main() throws {
        testScoring()
        testEarlyCastAndClockRollback()
        testTimeouts()
        testRoundPeriods()
        try testRecordAndCooldown()
        print("PASS: \(assertions) fishing assertions across scoring, timing, cooldowns and persistence")
    }

    static func testScoring() {
        for desiredScore in 0...2 {
            var session = FishingSession(startedAt: start)
            for round in 0..<3 {
                let position = desiredScore == 2 ? session.target : desiredScore == 1 ? session.target + 0.08 : 0.95
                let date = session.roundStartedAt.addingTimeInterval(position * session.roundPeriod)
                expect(session.cast(at: date), "round \(round) accepts a valid cast")
                expect(session.catches.last == desiredScore, "round \(round) awards expected quality \(desiredScore)")
                expect(session.finished == (round == 2), "exactly three casts complete a session")
            }
            expect(session.score == desiredScore * 3, "three catches sum to the total score")
            let previousCatches = session.catches
            let previousStart = session.roundStartedAt
            expect(!session.cast(at: previousStart.addingTimeInterval(1)), "fourth catch rejected")
            expect(session.catches == previousCatches && session.roundStartedAt == previousStart, "fourth catch cannot alter a completed award")
        }
        var mixed = FishingSession(startedAt: start)
        _ = mixed.cast(at: mixed.roundStartedAt.addingTimeInterval(mixed.target * mixed.roundPeriod))
        _ = mixed.cast(at: mixed.roundStartedAt.addingTimeInterval((mixed.target + 0.08) * mixed.roundPeriod))
        _ = mixed.cast(at: mixed.roundStartedAt.addingTimeInterval(0.95 * mixed.roundPeriod))
        expect(mixed.catches == [2, 1, 0] && mixed.score == 3, "mixed quality accumulates correctly")
    }

    static func testEarlyCastAndClockRollback() {
        var session = FishingSession(startedAt: start)
        for delta in [-500.0, 0, 0.1, 0.179] {
            expect(!session.cast(at: start.addingTimeInterval(delta)), "early/rollback cast is ignored")
            expect(session.catches.isEmpty && session.roundStartedAt == start, "ignored cast does not consume a round")
        }
        near(session.cursor(at: start.addingTimeInterval(-1)), 0, "clock rollback keeps cursor on track")
        expect(session.cast(at: start.addingTimeInterval(0.1801)), "cast after minimum delay accepted")
        let secondStart = session.roundStartedAt
        expect(!session.cast(at: secondStart.addingTimeInterval(0.1)), "new round restarts click delay")
        expect(session.catches.count == 1, "rapid double-click cannot consume a second catch")
        for invalid in [Double.infinity, -Double.infinity, Double.nan] {
            let date = Date(timeIntervalSince1970: invalid)
            expect(!session.cast(at: date), "invalid date cannot consume a catch")
            near(session.cursor(at: date), 0, "invalid date cannot generate a nonfinite cursor")
        }
    }

    static func testTimeouts() {
        var session = FishingSession(startedAt: start)
        for delta in [6.0, 6.01, 3_600.0] {
            expect(session.cast(at: session.roundStartedAt.addingTimeInterval(delta)), "timeout consumes a round")
            expect(session.catches.last == 0, "timeout always misses")
        }
        expect(session.finished && session.score == 0, "three timeouts finish with zero score")
        var lateTarget = FishingSession(startedAt: start)
        // The cursor is exactly on the target after two complete sweeps, but
        // the six-second deadline still overrides an otherwise perfect catch.
        let latePerfect = (4 + lateTarget.target) * lateTarget.roundPeriod
        near(lateTarget.cursor(at: start.addingTimeInterval(latePerfect)), lateTarget.target, "late cursor reaches target")
        expect(lateTarget.cast(at: start.addingTimeInterval(latePerfect)), "late target cast accepted as timeout")
        expect(lateTarget.score == 0, "deadline overrides cursor accuracy")
    }

    static func testRoundPeriods() {
        var session = FishingSession(startedAt: start)
        for (index, period) in [1.8, 1.62, 1.44].enumerated() {
            near(session.roundPeriod, period, "round \(index) gets its own speed")
            near(session.targetWidth, 0.25 - Double(index) * 0.025, "target narrows with successive rounds")
            for (fraction, expected) in [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0), (1.5, 0.5), (2.0, 0.0)] {
                near(session.cursor(at: session.roundStartedAt.addingTimeInterval(period * fraction)), expected, "cursor follows forward and reverse sweep")
            }
            _ = session.cast(at: session.roundStartedAt.addingTimeInterval(session.target * period))
        }
        expect(session.score == 6, "all changing round speeds remain winnable")
    }

    static func testRecordAndCooldown() throws {
        var record = FishingRecord()
        near(record.cooldownRemaining(at: start), 0, "new player has no cooldown")
        record.lastStartedAt = start
        near(record.cooldownRemaining(at: start), 45, "cooldown begins at session start")
        near(record.cooldownRemaining(at: start.addingTimeInterval(20)), 25, "cooldown counts elapsed seconds")
        near(record.cooldownRemaining(at: start.addingTimeInterval(45)), 0, "exact cooldown boundary unlocks play")
        near(record.cooldownRemaining(at: start.addingTimeInterval(100)), 0, "expired cooldown remains zero")
        near(record.cooldownRemaining(at: start.addingTimeInterval(-100)), 45, "clock rollback cannot bypass cooldown")
        near(record.cooldownRemaining(at: Date(timeIntervalSince1970: .nan)), 45, "invalid clock keeps cooldown finite")
        record.recordCompletion(score: 4)
        record.recordCompletion(score: 2)
        expect(record.bestScore == 4 && record.completedRounds == 2, "record keeps the best score and counts sessions")
        let saved = try JSONEncoder().encode(record)
        let restored = try JSONDecoder().decode(FishingRecord.self, from: saved)
        expect(restored.bestScore == 4 && restored.completedRounds == 2 && restored.lastStartedAt == start, "record round trips through persistence")
        let corrupt = Data(#"{"bestScore":999,"completedRounds":9223372036854775807}"#.utf8)
        var repaired = try JSONDecoder().decode(FishingRecord.self, from: corrupt)
        expect(repaired.bestScore == 6 && repaired.completedRounds == FishingRecord.maximumCompletedRounds, "corrupt record is bounded on decode")
        repaired.recordCompletion(score: Int.max)
        expect(repaired.completedRounds == FishingRecord.maximumCompletedRounds, "completion counter cannot overflow")
        let sparse = try JSONDecoder().decode(FishingRecord.self, from: Data(#"{"bestScore":"broken"}"#.utf8))
        expect(sparse.bestScore == 0 && sparse.completedRounds == 0, "missing or wrong field types use defaults")
    }
}
