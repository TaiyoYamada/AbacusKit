// AbacusKit Tests
// Swift 6.2

import XCTest
@testable import AbacusKit

final class AbacusKitTests: XCTestCase {
    // MARK: - CellState Tests

    func testCellStateValues() {
        XCTAssertEqual(CellState.upper.rawValue, 0)
        XCTAssertEqual(CellState.lower.rawValue, 1)
        XCTAssertEqual(CellState.empty.rawValue, 2)
    }

    func testCellStateIsValid() {
        XCTAssertTrue(CellState.upper.isValid)
        XCTAssertTrue(CellState.lower.isValid)
        XCTAssertFalse(CellState.empty.isValid)
    }

    // MARK: - SorobanDigit Tests

    func testSorobanDigitValueCalculation() {
        // 0: 上珠=上, 下珠=全て下
        let digit0 = SorobanDigit(
            position: 0,
            upperBead: .upper,
            lowerBeads: [.upper, .upper, .upper, .upper],
            confidence: 1.0,
            boundingBox: .zero
        )
        XCTAssertEqual(digit0.value, 0)

        // 5: 上珠=下, 下珠=全て下
        let digit5 = SorobanDigit(
            position: 0,
            upperBead: .lower,
            lowerBeads: [.upper, .upper, .upper, .upper],
            confidence: 1.0,
            boundingBox: .zero
        )
        XCTAssertEqual(digit5.value, 5)

        // 3: 上珠=上, 下珠=3つ上
        let digit3 = SorobanDigit(
            position: 0,
            upperBead: .upper,
            lowerBeads: [.lower, .lower, .lower, .upper],
            confidence: 1.0,
            boundingBox: .zero
        )
        XCTAssertEqual(digit3.value, 3)

        // 9: 上珠=下, 下珠=4つ上
        let digit9 = SorobanDigit(
            position: 0,
            upperBead: .lower,
            lowerBeads: [.lower, .lower, .lower, .lower],
            confidence: 1.0,
            boundingBox: .zero
        )
        XCTAssertEqual(digit9.value, 9)
    }

    // MARK: - SorobanInterpreter Tests

    func testInterpreterSingleDigit() {
        let interpreter = SorobanInterpreter()

        let digit = SorobanDigit(
            position: 0,
            upperBead: .lower,
            lowerBeads: [.lower, .lower, .upper, .upper],
            confidence: 1.0,
            boundingBox: .zero
        )
        let lane = SorobanLane(digit: digit, roi: .zero)

        let value = interpreter.interpret(lanes: [lane])
        XCTAssertEqual(value, 7) // 5 + 2
    }

    func testInterpreterMultipleDigits() {
        let interpreter = SorobanInterpreter()

        // 123 を表現
        let digit1 = SorobanDigit(
            position: 2,
            upperBead: .upper,
            lowerBeads: [.lower, .upper, .upper, .upper],
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
            lowerBeads: [.lower, .lower, .lower, .upper],
            confidence: 1.0,
            boundingBox: .zero
        )

        let lanes = [
            SorobanLane(digit: digit1, roi: .zero),
            SorobanLane(digit: digit2, roi: .zero),
            SorobanLane(digit: digit3, roi: .zero),
        ]

        let value = interpreter.interpret(lanes: lanes)
        XCTAssertEqual(value, 123)
    }

    // MARK: - AbacusConfiguration Tests

    func testDefaultConfiguration() {
        let config = AbacusConfiguration.default
        XCTAssertEqual(config.minLaneCount, 1)
        XCTAssertEqual(config.maxLaneCount, 27)
        XCTAssertEqual(config.confidenceThreshold, 0.7)
    }

    func testFastConfiguration() {
        let config = AbacusConfiguration.fast
        XCTAssertEqual(config.frameSkipInterval, 2)
        XCTAssertEqual(config.maxInputResolution, 720)
    }

    // MARK: - AbacusError Tests

    func testErrorIsRetryable() {
        XCTAssertTrue(AbacusError.frameNotDetected.isRetryable)
        XCTAssertTrue(AbacusError.lowConfidence(confidence: 0.3, threshold: 0.7).isRetryable)
        XCTAssertFalse(AbacusError.modelNotLoaded.isRetryable)
        XCTAssertFalse(AbacusError.invalidConfiguration(reason: "test").isRetryable)
    }

    // MARK: - AbacusRecognizer Tests

    func testRecognizerInitialization() async {
        let recognizer = AbacusRecognizer()
        let config = await recognizer.currentConfiguration
        XCTAssertEqual(config.minLaneCount, 1)
    }

    func testRecognizerCustomConfiguration() async {
        let customConfig = AbacusConfiguration(confidenceThreshold: 0.9)
        let recognizer = AbacusRecognizer(configuration: customConfig)
        let config = await recognizer.currentConfiguration
        XCTAssertEqual(config.confidenceThreshold, 0.9)
    }
}
