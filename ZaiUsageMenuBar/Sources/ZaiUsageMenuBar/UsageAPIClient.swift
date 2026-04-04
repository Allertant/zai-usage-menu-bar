import Foundation

class UsageAPIClient {
    static let shared = UsageAPIClient()
    
    private static let modelUsageUrl = "https://open.bigmodel.cn/api/monitor/usage/model-usage"
    private static let toolUsageUrl = "https://open.bigmodel.cn/api/monitor/usage/tool-usage"
    private static let quotaLimitUrl = "https://open.bigmodel.cn/api/monitor/usage/quota/limit"
    
    private init() {}
    
    func fetchUsage() async throws -> UsageData {
        guard let authToken = UserDefaults.standard.string(forKey: "anthropicAuthToken"), !authToken.isEmpty else {
            throw UsageError.missingAuthToken
        }
        
        let now = Date()
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        let endDate = now
        
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour], from: startDate)
        let endComponents = calendar.dateComponents([.year, .month, .day, .hour], from: endDate)
        
        let startTime = String(format: "%04d-%02d-%02d %02d:00:00",
                               startComponents.year!, startComponents.month!, startComponents.day!, startComponents.hour!)
        let endTime = String(format: "%04d-%02d-%02d %02d:59:59",
                             endComponents.year!, endComponents.month!, endComponents.day!, endComponents.hour!)
        
        async let modelUsageTask = fetchJSON(url: Self.modelUsageUrl, startTime: startTime, endTime: endTime, authToken: authToken)
        async let toolUsageTask = fetchJSON(url: Self.toolUsageUrl, startTime: startTime, endTime: endTime, authToken: authToken)
        async let quotaLimitTask = fetchJSON(url: Self.quotaLimitUrl, startTime: nil, endTime: nil, authToken: authToken)
        
        let (modelUsageRaw, toolUsageRaw, quotaLimitRaw) = try await (modelUsageTask, toolUsageTask, quotaLimitTask)
        
        let modelUsageResponse = try JSONDecoder().decode(APIResponse<ModelUsageData>.self, from: modelUsageRaw)
        let toolUsageResponse = try JSONDecoder().decode(APIResponse<ToolUsageData>.self, from: toolUsageRaw)
        let quotaLimitResponse = try JSONDecoder().decode(APIResponse<QuotaLimitData>.self, from: quotaLimitRaw)
        
        return UsageData(
            modelUsage: modelUsageResponse.data,
            toolUsage: toolUsageResponse.data,
            quotaLimits: quotaLimitResponse.data,
            lastUpdated: Date()
        )
    }
    
    private func fetchJSON(url: String, startTime: String?, endTime: String?, authToken: String) async throws -> Data {
        var components = URLComponents(string: url)!
        
        if let startTime = startTime, let endTime = endTime {
            components.queryItems = [
                URLQueryItem(name: "startTime", value: startTime),
                URLQueryItem(name: "endTime", value: endTime)
            ]
        }
        
        guard let requestUrl = components.url else {
            throw UsageError.invalidURL
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw UsageError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        return data
    }
}

struct UsageData {
    let modelUsage: ModelUsageData
    let toolUsage: ToolUsageData
    let quotaLimits: QuotaLimitData
    let lastUpdated: Date
}

enum UsageError: Error, LocalizedError {
    case missingAuthToken
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    
    var errorDescription: String? {
        switch self {
        case .missingAuthToken:
            return "Missing authentication token. Please configure it in Settings."
        case .invalidURL:
            return "Invalid URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let statusCode, let data):
            if let errorMessage = String(data: data, encoding: .utf8) {
                return "HTTP Error \(statusCode): \(errorMessage)"
            }
            return "HTTP Error \(statusCode)"
        }
    }
}
