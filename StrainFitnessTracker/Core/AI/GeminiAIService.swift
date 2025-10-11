import Foundation

class GeminiAIService {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    
    private let session = URLSession.shared
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func chat(
        userMessage: String,
        healthContext: String,
        conversationHistory: [ChatMessage]
    ) async throws -> String {
        // Build the full prompt with health context
        let systemPrompt = buildSystemPrompt(healthContext: healthContext)
        let messages = buildMessages(systemPrompt: systemPrompt, history: conversationHistory, userMessage: userMessage)
        
        let requestBody = GeminiRequest(contents: [GeminiContent(parts: messages)])
        
        var request = URLRequest(url: URL(string: baseURL + "?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw AIServiceError.encodingFailed("Failed to encode request: \(error.localizedDescription)")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                throw AIServiceError.apiError(errorData.error?.message ?? "Unknown error")
            }
            throw AIServiceError.httpError(httpResponse.statusCode)
        }
        
        let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let content = decodedResponse.candidates.first?.content,
              let textPart = content.parts.first?.text else {
            throw AIServiceError.invalidResponse
        }
        
        return textPart
    }
    
    private func buildSystemPrompt(healthContext: String) -> String {
        return """
        You are a knowledgeable health and fitness coach assisting a user with their fitness tracking app.
        
        IMPORTANT GUIDELINES:
        - You have access to the user's real health data below. Use this data to provide personalized insights.
        - Always be encouraging and supportive while remaining honest about health metrics.
        - If the user asks about medical conditions, advise them to consult a healthcare professional.
        - Provide actionable, specific recommendations based on their data.
        - Be concise but thorough in your responses (2-3 paragraphs typical).
        
        USER'S CURRENT HEALTH DATA:
        \(healthContext)
        
        Remember: You are a coach/assistant, not a doctor. Always recommend professional medical consultation for serious concerns.
        """
    }
    
    private func buildMessages(
        systemPrompt: String,
        history: [ChatMessage],
        userMessage: String
    ) -> [GeminiPart] {
        var parts: [GeminiPart] = []
        
        // Add system prompt as the first message
        parts.append(GeminiPart(text: systemPrompt))
        
        // Add conversation history
        for message in history {
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
        case .encodingFailed(let message):
            return message
        case .invalidURL:
            return "Invalid URL"
        }
    }
}
