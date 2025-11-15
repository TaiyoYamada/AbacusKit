import XCTest
@testable import AbacusKit

final class VersionCheckerTests: XCTestCase {
    
    // MARK: - Test Successful JSON Decoding
    
    func testFetchRemoteVersionDecodesJSON() async throws {
        // Create mock JSON response
        let jsonString = """
        {
            "version": 5,
            "model_url": "https://s3.amazonaws.com/bucket/models/model_v5.pt",
            "updated_at": "2025-11-15T10:30:00Z"
        }
        """
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            XCTFail("Failed to create JSON data")
            return
        }
        
        // Create mock URLSession
        let mockSession = MockURLSession(data: jsonData, response: createSuccessResponse())
        
        // Create VersionChecker with mock session
        let versionChecker = VersionChecker(urlSession: mockSession)
        
        // Fetch remote version
        let url = URL(string: "https://example.com/version.json")!
        let modelVersion = try await versionChecker.fetchRemoteVersion(from: url)
        
        // Verify decoded values
        XCTAssertEqual(modelVersion.version, 5)
        XCTAssertEqual(
            modelVersion.modelURL.absoluteString,
            "https://s3.amazonaws.com/bucket/models/model_v5.pt"
        )
        XCTAssertNotNil(modelVersion.updatedAt)
    }
    
    func testFetchRemoteVersionDecodesJSONWithoutOptionalFields() async throws {
        // Create mock JSON response without optional fields
        let jsonString = """
        {
            "version": 3,
            "model_url": "https://s3.amazonaws.com/bucket/models/model_v3.pt"
        }
        """
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            XCTFail("Failed to create JSON data")
            return
        }
        
        // Create mock URLSession
        let mockSession = MockURLSession(data: jsonData, response: createSuccessResponse())
        
        // Create VersionChecker with mock session
        let versionChecker = VersionChecker(urlSession: mockSession)
        
        // Fetch remote version
        let url = URL(string: "https://example.com/version.json")!
        let modelVersion = try await versionChecker.fetchRemoteVersion(from: url)
        
        // Verify decoded values
        XCTAssertEqual(modelVersion.version, 3)
        XCTAssertEqual(
            modelVersion.modelURL.absoluteString,
            "https://s3.amazonaws.com/bucket/models/model_v3.pt"
        )
        XCTAssertNil(modelVersion.updatedAt)
    }
    
    // MARK: - Test Network Error Handling
    
    func testFetchRemoteVersionHandlesNetworkError() async throws {
        // Create mock URLSession that throws an error
        let mockSession = MockURLSession(error: URLError(.notConnectedToInternet))
        
        // Create VersionChecker with mock session
        let versionChecker = VersionChecker(urlSession: mockSession)
        
        // Attempt to fetch remote version
        let url = URL(string: "https://example.com/version.json")!
        
        do {
            _ = try await versionChecker.fetchRemoteVersion(from: url)
            XCTFail("Expected error to be thrown")
        } catch {
            // Verify error is thrown
            XCTAssertTrue(error is URLError)
        }
    }
    
    func testFetchRemoteVersionHandlesBadServerResponse() async throws {
        // Create mock JSON response
        let jsonData = "{}".data(using: .utf8)!
        
        // Create mock URLSession with 404 response
        let mockSession = MockURLSession(
            data: jsonData,
            response: createErrorResponse(statusCode: 404)
        )
        
        // Create VersionChecker with mock session
        let versionChecker = VersionChecker(urlSession: mockSession)
        
        // Attempt to fetch remote version
        let url = URL(string: "https://example.com/version.json")!
        
        do {
            _ = try await versionChecker.fetchRemoteVersion(from: url)
            XCTFail("Expected error to be thrown")
        } catch {
            // Verify error is thrown
            XCTAssertTrue(error is URLError)
        }
    }
    
    func testFetchRemoteVersionHandlesInvalidJSON() async throws {
        // Create invalid JSON response
        let invalidJSON = "{ invalid json }".data(using: .utf8)!
        
        // Create mock URLSession
        let mockSession = MockURLSession(data: invalidJSON, response: createSuccessResponse())
        
        // Create VersionChecker with mock session
        let versionChecker = VersionChecker(urlSession: mockSession)
        
        // Attempt to fetch remote version
        let url = URL(string: "https://example.com/version.json")!
        
        do {
            _ = try await versionChecker.fetchRemoteVersion(from: url)
            XCTFail("Expected decoding error to be thrown")
        } catch {
            // Verify decoding error is thrown
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSuccessResponse() -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com/version.json")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    }
    
    private func createErrorResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com/version.json")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}

// MARK: - Mock URLSession

class MockURLSession: URLSession {
    private let mockData: Data?
    private let mockResponse: URLResponse?
    private let mockError: Error?
    
    init(data: Data? = nil, response: URLResponse? = nil, error: Error? = nil) {
        self.mockData = data
        self.mockResponse = response
        self.mockError = error
    }
    
    override func data(from url: URL) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        
        guard let data = mockData, let response = mockResponse else {
            throw URLError(.unknown)
        }
        
        return (data, response)
    }
}
