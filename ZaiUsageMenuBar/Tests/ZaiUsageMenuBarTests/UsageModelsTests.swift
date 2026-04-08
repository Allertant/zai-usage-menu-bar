import XCTest
@testable import ZaiUsageMenuBar

final class UsageModelsTests: XCTestCase {
    func testDecodeModelDataList() throws {
        let json = """
        {
            "x_time": ["2026-04-09 10:00", "2026-04-09 11:00"],
            "modelCallCount": [5, 10],
            "tokensUsage": [1000, 2000],
            "totalUsage": {
                "totalModelCallCount": 15,
                "totalTokensUsage": 3000
            },
            "modelDataList": [
                {
                    "modelName": "GLM-5.1",
                    "sortOrder": 1,
                    "tokensUsage": [800, 1500],
                    "totalTokens": 2300
                },
                {
                    "modelName": "GLM-4.7",
                    "sortOrder": 2,
                    "tokensUsage": [200, 500],
                    "totalTokens": 700
                }
            ],
            "modelSummaryList": [
                {"modelName": "GLM-5.1", "totalTokens": 2300, "sortOrder": 1}
            ],
            "granularity": "hourly"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ModelUsageData.self, from: json)
        XCTAssertEqual(decoded.modelDataList?.count, 2)
        XCTAssertEqual(decoded.modelDataList?[0].modelName, "GLM-5.1")
        XCTAssertEqual(decoded.modelDataList?[0].tokensUsage, [800, 1500])
        XCTAssertEqual(decoded.modelSummaryList?.count, 1)
        XCTAssertEqual(decoded.granularity, "hourly")
    }
}
