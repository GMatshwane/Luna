import XCTest
@testable import Luna

final class ScorePolicyTests: XCTestCase {
    func testPointsDefaultAndMinimum() {
        XCTAssertEqual(ScorePolicy.normalizedPoints(0), 1)
        XCTAssertEqual(ScorePolicy.normalizedPoints(-4), 1)
        XCTAssertEqual(ScorePolicy.normalizedPoints(1), 1)
        XCTAssertEqual(ScorePolicy.normalizedPoints(5), 5)
        XCTAssertEqual(ScorePolicy.normalizedPoints(200), ScorePolicy.maximumPoints)
        XCTAssertEqual(ScorePolicy.defaultPoints, 1)
    }

    func testDailyGoalDefaultAndMinimum() {
        XCTAssertEqual(ScorePolicy.normalizedGoal(0), 1)
        XCTAssertEqual(ScorePolicy.normalizedGoal(10), 10)
        XCTAssertEqual(ScorePolicy.normalizedGoal(5000), ScorePolicy.maximumDailyGoal)
        XCTAssertEqual(ScorePolicy.defaultDailyGoal, 10)
    }

    func testScoreSumsOnlyCompletedPoints() {
        struct Row { var points: Int; var isCompleted: Bool }
        let items = [
            Row(points: 1, isCompleted: true),
            Row(points: 3, isCompleted: true),
            Row(points: 5, isCompleted: false),
            Row(points: 2, isCompleted: true)
        ]
        XCTAssertEqual(
            ScorePolicy.earnedPoints(from: items, points: { $0.points }, isCompleted: { $0.isCompleted }),
            6
        )
    }

    func testUncompletedItemsContributeZero() {
        struct Row { var points: Int; var isCompleted: Bool }
        let items = [Row(points: 8, isCompleted: false)]
        XCTAssertEqual(
            ScorePolicy.earnedPoints(from: items, points: { $0.points }, isCompleted: { $0.isCompleted }),
            0
        )
    }

    func testProgressCapsAtOneButLabelShowsOverflow() {
        let overflow = ScorePolicy.score(earned: 12, goal: 10)
        XCTAssertEqual(overflow.label, "12 / 10")
        XCTAssertEqual(overflow.progress, 1, accuracy: 0.0001)
        XCTAssertTrue(overflow.isMet)

        let partial = ScorePolicy.score(earned: 8, goal: 10)
        XCTAssertEqual(partial.label, "8 / 10")
        XCTAssertEqual(partial.progress, 0.8, accuracy: 0.0001)
        XCTAssertFalse(partial.isMet)
    }

    func testEmptyDayIsZeroTowardGoal() {
        struct Row { var points: Int; var isCompleted: Bool }
        let earned = ScorePolicy.earnedPoints(from: [Row](), points: { $0.points }, isCompleted: { $0.isCompleted })
        let score = ScorePolicy.score(earned: earned, goal: 10)
        XCTAssertEqual(score.label, "0 / 10")
        XCTAssertEqual(score.progress, 0)
    }
}
