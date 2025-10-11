import Foundation

class GeminiAIService {
    private let apiKey: String
    
    // ✅ CORRECT models for your API key (Oct 2025)
    // Based on your available models that support generateContent
    private let modelNames = [
        "gemini-flash-latest",       // Always points to latest stable
        "gemini-2.5-flash",           // Stable Gemini 2.5 Flash (June 2025)
        "gemini-2.0-flash",           // Stable Gemini 2.0 Flash
        "gemini-2.5-pro",             // More powerful but slower
        "gemini-pro-latest"           // Pro version fallback
    ]
    
    private var workingModel: String?
    private let session = URLSession.shared
    
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
        // Build the full prompt with health context
        let systemPrompt = buildSystemPrompt(healthContext: healthContext)
        let messages = buildMessages(systemPrompt: systemPrompt, history: conversationHistory, userMessage: userMessage)
        
        let requestBody = GeminiRequest(contents: [GeminiContent(parts: messages)])
        
        // If we have a working model, use it. Otherwise try each model until one works
        let modelsToTry = workingModel != nil ? [workingModel!] : modelNames
        
        for modelName in modelsToTry {
            do {
                let baseURL = getBaseURL(for: modelName)
                var request = URLRequest(url: URL(string: baseURL + "?key=\(apiKey)")!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                request.httpBody = try JSONEncoder().encode(requestBody)
                
                let (data, response) = try await session.data(for: request)
                
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
                    continue
                } else {
                    if let errorData = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                        throw AIServiceError.apiError(errorData.error?.message ?? "Unknown error")
                    }
                    throw AIServiceError.httpError(httpResponse.statusCode)
                }
            } catch let error as AIServiceError {
                // If it's a definitive error (not 404), throw it
                throw error
            } catch {
                // Try next model
                continue
            }
        }
        
        // If we get here, none of the models worked
        throw AIServiceError.apiError("No compatible Gemini models found. Please check your API key and enabled models at https://aistudio.google.com")
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
