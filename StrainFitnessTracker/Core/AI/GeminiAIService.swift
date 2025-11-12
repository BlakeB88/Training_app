import Foundation

class GeminiAIService {
    private let apiKey: String
    
    // ✅ Prioritize Flash models for better rate limits
    private let modelNames = [
        "gemini-2.5-flash",           // 15 RPM, 250K TPM - BEST for free tier
    ]
    
    private var workingModel: String?
    private let session = URLSession.shared
    
    // Rate limiting
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 5 // 4.5 seconds between requests
    
    // ✅ NEW: Retry configuration
    private let maxRetries = 3
    private let initialRetryDelay: TimeInterval = 2.0 // Start with 2 seconds
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    private func getBaseURL(for model: String) -> String {
        return "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
    }
    
    func chat(
        userMessage: String,
        healthContext: String,
        conversationHistory: [ChatMessage]
    ) async throws -> String {
        // Rate limiting: Wait if we're making requests too quickly
        if let lastTime = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastTime)
            if timeSinceLastRequest < minimumRequestInterval {
                let waitTime = minimumRequestInterval - timeSinceLastRequest
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        
        // Build optimized messages
        let messages = buildOptimizedMessages(
            systemPrompt: buildSystemPrompt(healthContext: healthContext),
            history: conversationHistory,
            userMessage: userMessage
        )
        
        let requestBody = GeminiRequest(contents: [GeminiContent(parts: messages)])
        
        // If we have a working model, use it. Otherwise try each model until one works
        let modelsToTry = workingModel != nil ? [workingModel!] : modelNames
        
        for modelName in modelsToTry {
            // ✅ NEW: Try with retries for rate limits
            for attempt in 0..<maxRetries {
                do {
                    let baseURL = getBaseURL(for: modelName)
                    var request = URLRequest(url: URL(string: baseURL + "?key=\(apiKey)")!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    request.httpBody = try JSONEncoder().encode(requestBody)
                    
                    let (data, response) = try await session.data(for: request)
                    
                    // Update last request time
                    lastRequestTime = Date()
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continue
                    }
                    
                    if httpResponse.statusCode == 200 {
                        let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
                        
                        guard let content = decodedResponse.candidates.first?.content,
                              let textPart = content.parts.first?.text else {
                            throw AIServiceError.invalidResponse
                        }
                        
                        // Save the working model for future requests
                        workingModel = modelName
                        print("✅ Using model: \(modelName)")
                        
                        return textPart
                        
                    } else if httpResponse.statusCode == 404 {
                        // Model not found, try next one
                        print("⚠️ Model \(modelName) not found, trying next...")
                        break // Exit retry loop, try next model
                        
                    } else if httpResponse.statusCode == 429 {
                        // ✅ FIXED: Rate limit hit - retry with exponential backoff
                        if let errorData = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                            print("⚠️ Rate limit hit (attempt \(attempt + 1)/\(maxRetries)): \(errorData.error?.message ?? "Rate limited")")
                        }
                        
                        // If this is our last attempt, throw the error
                        if attempt == maxRetries - 1 {
                            throw AIServiceError.rateLimitExceeded("Rate limit exceeded. Please wait a moment and try again.")
                        }
                        
                        // Calculate exponential backoff delay
                        let delay = initialRetryDelay * pow(2.0, Double(attempt))
                        print("   ⏳ Waiting \(Int(delay)) seconds before retry...")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        
                        // Continue to next retry attempt
                        continue
                        
                    } else {
                        if let errorData = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                            throw AIServiceError.apiError(errorData.error?.message ?? "Unknown error")
                        }
                        throw AIServiceError.httpError(httpResponse.statusCode)
                    }
                } catch let error as AIServiceError {
                    // If it's a rate limit error and we have retries left, continue
                    if case .rateLimitExceeded = error, attempt < maxRetries - 1 {
                        continue
                    }
                    // Otherwise throw the error
                    throw error
                } catch {
                    // Network or other errors - try next model
                    print("⚠️ Request error: \(error.localizedDescription)")
                    break // Exit retry loop, try next model
                }
            }
        }
        
        // If we get here, none of the models worked
        throw AIServiceError.apiError("No compatible Gemini models found. Please check your API key and enabled models at https://aistudio.google.com")
    }
    
    private func buildSystemPrompt(healthContext: String) -> String {
        // ✅ SHORTER system prompt - only essential info
        return """
        You are a helpful health coach. Keep responses concise (2-3 paragraphs).
        
        Current metrics:
        \(healthContext)
        
        Note: Recommend consulting healthcare professionals for medical concerns.
        """
    }
    
    private func buildOptimizedMessages(
        systemPrompt: String,
        history: [ChatMessage],
        userMessage: String
    ) -> [GeminiPart] {
        var parts: [GeminiPart] = []
        
        // Add system prompt ONCE at the start
        parts.append(GeminiPart(text: systemPrompt))
        
        // ✅ LIMIT conversation history to last 6 messages (3 exchanges)
        // This prevents token bloat while maintaining context
        let recentHistory = Array(history.suffix(6))
        
        for message in recentHistory {
            let prefix = message.isUser ? "User: " : "Assistant: "
            parts.append(GeminiPart(text: prefix + message.content))
        }
        
        // Add current user message
        parts.append(GeminiPart(text: "User: " + userMessage))
        
        return parts
    }
}

// MARK: - Models

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

// MARK: - Gemini API Models

struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
}

struct GeminiContent: Encodable {
    let parts: [GeminiPart]
}

struct GeminiPart: Encodable {
    let text: String
}

struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]
}

struct GeminiCandidate: Decodable {
    let content: GeminiContentResponse
}

struct GeminiContentResponse: Decodable {
    let parts: [GeminiPartResponse]
}

struct GeminiPartResponse: Decodable {
    let text: String
}

struct GeminiErrorResponse: Decodable {
    let error: GeminiError?
}

struct GeminiError: Decodable {
    let message: String
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case rateLimitExceeded(String)
    case encodingFailed(String)
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .httpError(let code):
            return "HTTP Error \(code)"
        case .apiError(let message):
            return "AI Service Error: \(message)"
        case .rateLimitExceeded(let message):
            return "Rate limit: \(message)"
        case .encodingFailed(let message):
            return message
        case .invalidURL:
            return "Invalid URL"
        }
    }
}
