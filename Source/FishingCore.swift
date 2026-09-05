import Foundation

struct FishingRecord: Codable {
    static let cooldown: Double = 45
    static let maximumCompletedRounds = 1_000_000

    var lastStartedAt: Date? = nil
    var bestScore = 0
    var completedRounds = 0

    init() {}

    func cooldownRemaining(at date: Date) -> Double {
        guard let lastStartedAt else { return 0 }
        let elapsed = date.timeIntervalSince(lastStartedAt)
        guard elapsed.isFinite else { return Self.cooldown }
        return min(Self.cooldown, max(0, Self.cooldown - elapsed))
    }

    mutating func recordCompletion(score: Int) {
        sanitize()
        bestScore = max(bestScore, min(6, max(0, score)))
        completedRounds = min(Self.maximumCompletedRounds, completedRounds + 1)
    }

    mutating func sanitize() {
        bestScore = min(6, max(0, bestScore))
        completedRounds = min(Self.maximumCompletedRounds, max(0, completedRounds))
        if let date = lastStartedAt, !date.timeIntervalSince1970.isFinite { lastStartedAt = nil }
    }

    private enum CodingKeys: String, CodingKey { case lastStartedAt, bestScore, completedRounds }

    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        lastStartedAt = try? values.decode(Date.self, forKey: .lastStartedAt)
        bestScore = (try? values.decode(Int.self, forKey: .bestScore)) ?? bestScore
        completedRounds = (try? values.decode(Int.self, forKey: .completedRounds)) ?? completedRounds
        sanitize()
    }
}

/// Three independent, timed catches. The store grants a reward once it observes
/// finished; further casts cannot alter a completed session.
struct FishingSession {
    static let minimumCastDelay: Double = 0.18
    static let roundTimeLimit: Double = 6

    let startedAt: Date
    private(set) var roundStartedAt: Date
    private(set) var catches: [Int] = []

    init(startedAt: Date) {
        self.startedAt = startedAt
        self.roundStartedAt = startedAt
    }

    var finished: Bool { catches.count >= 3 }
    var score: Int { catches.reduce(0, +) }
    private var roundIndex: Int { min(2, catches.count) }
    var target: Double { [0.36, 0.71, 0.48][roundIndex] }
    var targetWidth: Double { 0.25 - Double(roundIndex) * 0.025 }
    var roundPeriod: Double { 1.8 - Double(roundIndex) * 0.18 }

    func cursor(at date: Date) -> Double {
        let rawElapsed = date.timeIntervalSince(roundStartedAt)
        guard rawElapsed.isFinite else { return 0 }
        let elapsed = max(0, rawElapsed)
        let phase = (elapsed / roundPeriod).truncatingRemainder(dividingBy: 2)
        return phase <= 1 ? phase : 2 - phase
    }

    @discardableResult
    mutating func cast(at date: Date) -> Bool {
        let elapsed = date.timeIntervalSince(roundStartedAt)
        guard !finished, elapsed.isFinite, elapsed >= Self.minimumCastDelay else { return false }
        let distance = abs(cursor(at: date) - target)
        let score = elapsed >= Self.roundTimeLimit ? 0 : distance <= 0.04 ? 2 : distance <= targetWidth / 2 ? 1 : 0
        catches.append(score)
        roundStartedAt = date
        return true
    }
}
