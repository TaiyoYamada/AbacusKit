// AbacusKit - SingleRowRecognizerTests
// Swift 6.2

import XCTest
@testable import AbacusKit

final class SingleRowRecognizerTests: XCTestCase {
    // MARK: - SingleRowConfiguration Tests

    func testDefaultConfiguration() {
        let config = SingleRowConfiguration.default
        XCTAssertEqual(config.startDigitPosition, 0)
        XCTAssertNil(config.expectedLaneCount)
        XCTAssertEqual(config.minLaneCount, 1)
        XCTAssertEqual(config.maxLaneCount, 13)
        XCTAssertEqual(config.guideAspectRatio, 8.0)
        XCTAssertEqual(config.confidenceThreshold, 0.7)
    }

    func testFixedLaneCountConfiguration() {
        let config = SingleRowConfiguration.fixed(laneCount: 5)
        XCTAssertEqual(config.expectedLaneCount, 5)
        XCTAssertEqual(config.startDigitPosition, 0)
    }

    func testConfigurationEquality() {
        let config1 = SingleRowConfiguration()
        let config2 = SingleRowConfiguration()
        XCTAssertEqual(config1, config2)

        var config3 = SingleRowConfiguration()
        config3.startDigitPosition = 2
        XCTAssertNotEqual(config1, config3)
    }

    // MARK: - SingleRowResult Tests

    func testResultValueCalculation() {
        // Create lanes representing [3, 2, 1] at position 0
        let digit1 = SorobanDigit(
            position: 2,
            upperBead: .upper,
            lowerBeads: [.lower, .lower, .lower, .upper],
            confidence: 1.0,
            boundingBox: .zero
        )
        let digit2 = SorobanDigit(
            position: 1,
            upperBead: .upper,
            lowerBeads: [.lower, .lower, .upper, .upper],
            confidence: 1.0,
            boundingBox: .zero
        )
        let digit3 = SorobanDigit(
            position: 0,
            upperBead: .upper,
            lowerBeads: [.lower, .upper, .upper, .upper],
            confidence: 1.0,
            boundingBox: .zero
        )

        let lanes = [
            SorobanLane(digit: digit1, roi: .zero),
            SorobanLane(digit: digit2, roi: .zero),
            SorobanLane(digit: digit3, roi: .zero),
        ]

        let result = SingleRowResult(
            lanes: lanes,
            startPosition: 0,
            confidence: 1.0,
            roi: .zero
        )

        XCTAssertEqual(result.laneCount, 3)
        XCTAssertEqual(result.value, 321)  // 3×100 + 2×10 + 1×1
        XCTAssertEqual(result.digitValues, [3, 2, 1])
    }

    func testResultWithOffsetPosition() {
        // Create lanes representing [5] at position 2 (hundreds place)
        let digit = SorobanDigit(
            position: 2,
            upperBead: .lower,  // 5
            lowerBeads: [.upper, .upper, .upper, .upper],
            confidence: 1.0,
            boundingBox: .zero
        )

        let result = SingleRowResult(
            lanes: [SorobanLane(digit: digit, roi: .zero)],
            startPosition: 2,
            confidence: 1.0,
            roi: .zero
        )

        XCTAssertEqual(result.value, 500)
    }

    func testResultIsValid() {
        let validDigit = SorobanDigit(
            position: 0,
            upperBead: .lower,
            lowerBeads: [.lower, .lower, .upper, .upper],
            confidence: 1.0,
            boundingBox: .zero
        )

        let validResult = SingleRowResult(
            lanes: [SorobanLane(digit: validDigit, roi: .zero)],
            startPosition: 0,
            confidence: 1.0,
            roi: .zero
        )
        XCTAssertTrue(validResult.isValid)

        let invalidDigit = SorobanDigit(
            position: 0,
            upperBead: .empty,
            lowerBeads: [.empty, .empty, .empty, .empty],
            confidence: 0.0,
            boundingBox: .zero
        )

        let invalidResult = SingleRowResult(
            lanes: [SorobanLane(digit: invalidDigit, roi: .zero)],
            startPosition: 0,
            confidence: 0.0,
            roi: .zero
        )
        XCTAssertFalse(invalidResult.isValid)
    }

    // MARK: - Guide Rect Tests

    func testGuideRectCalculation() async {
        let recognizer = SingleRowRecognizer()
        let viewSize = CGSize(width: 390, height: 844)

        let guide = await recognizer.guideRect(in: viewSize)

        // Guide should be horizontally centered with inset
        let expectedInset = viewSize.width * 0.05  // default inset ratio
        XCTAssertEqual(guide.origin.x, expectedInset, accuracy: 0.01)

        // Guide should fill width minus insets
        let expectedWidth = viewSize.width - (expectedInset * 2)
        XCTAssertEqual(guide.width, expectedWidth, accuracy: 0.01)

        // Guide should have correct aspect ratio (8:1)
        let expectedHeight = expectedWidth / 8.0
        XCTAssertEqual(guide.height, expectedHeight, accuracy: 0.01)

        // Guide should be vertically centered
        let expectedY = (viewSize.height - expectedHeight) / 2
        XCTAssertEqual(guide.origin.y, expectedY, accuracy: 0.01)
    }

    func testNormalizedGuideROI() async {
        let recognizer = SingleRowRecognizer()
        let viewSize = CGSize(width: 400, height: 800)

        let normalizedROI = await recognizer.normalizedGuideROI(in: viewSize)

        // All values should be in 0-1 range
        XCTAssertGreaterThanOrEqual(normalizedROI.origin.x, 0)
        XCTAssertLessThanOrEqual(normalizedROI.origin.x + normalizedROI.width, 1.0)
        XCTAssertGreaterThanOrEqual(normalizedROI.origin.y, 0)
        XCTAssertLessThanOrEqual(normalizedROI.origin.y + normalizedROI.height, 1.0)
    }

    // MARK: - Configuration Update Tests

    func testRecognizerConfigurationUpdate() async {
        let recognizer = SingleRowRecognizer()

        var newConfig = SingleRowConfiguration()
        newConfig.startDigitPosition = 3
        newConfig.expectedLaneCount = 7

        await recognizer.configure(newConfig)

        let current = await recognizer.currentConfiguration
        XCTAssertEqual(current.startDigitPosition, 3)
        XCTAssertEqual(current.expectedLaneCount, 7)
    }
}
