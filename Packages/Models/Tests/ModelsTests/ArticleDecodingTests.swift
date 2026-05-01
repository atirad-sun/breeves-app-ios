import XCTest
@testable import Models

final class ArticleDecodingTests: XCTestCase {
    func testDecodesSchemaJSON() throws {
        let json = """
        {
          "id": "a1",
          "headline": "Test headline",
          "estimated_read_time_minutes": 4,
          "source": "Bloomberg",
          "universal_mode": {
            "gist": "g", "ripple_effect": "r", "personal_impact": "p", "key_metric": "k"
          },
          "topic_specific_mode": {
            "bullet_1_header": "h1", "bullet_1_text": "t1",
            "bullet_2_header": "h2", "bullet_2_text": "t2",
            "bullet_3_header": "h3", "bullet_3_text": "t3"
          },
          "executive_mode": {
            "the_intel": "i", "why_flagged": "f", "open_questions": "q", "decision_action": "d"
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder.briefing.decode(Article.self, from: json)
        XCTAssertEqual(decoded.headline, "Test headline")
        XCTAssertEqual(decoded.estimatedReadTimeMinutes, 4)
        XCTAssertEqual(decoded.universalMode.keyMetric, "k")
        XCTAssertEqual(decoded.topicSpecificMode.bullet2Header, "h2")
        XCTAssertEqual(decoded.executiveMode.decisionAction, "d")
    }

    func testReadingLensRawValues() {
        XCTAssertEqual(ReadingLens.universal.rawValue, "universal")
        XCTAssertEqual(ReadingLens.topicSpecific.rawValue, "topic_specific")
        XCTAssertEqual(ReadingLens.executive.rawValue, "executive")
    }

    func testUniversalBulletsOrder() {
        let m = UniversalMode(gist: "1", rippleEffect: "2", personalImpact: "3", keyMetric: "4")
        XCTAssertEqual(m.orderedBullets, ["1", "2", "3", "4"])
    }
}
