import Foundation
import Combine

@MainActor
class HealthChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var inputText = ""
    
    private let aiService: GeminiAIService
    private let contextBuilder: HealthContextBuilder
    private let healthKitManager: HealthKitManager
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        apiKey: String,
        contextBuilder: HealthContextBuilder? = nil,
        healthKitManager: HealthKitManager? = nil
    ) {
        self.aiService = GeminiAIService(apiKey: apiKey)
        self.contextBuilder = contextBuilder ?? HealthContextBuilder()
        self.healthKitManager = healthKitManager ?? HealthKitManager.shared
        
        // Load conversation history if it exists
        loadConversationHistory()
    }
    
    // MARK: - Public Methods
    
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isLoading else { return }
        
        let userMessage = ChatMessage(
            content: text,
            isUser: true,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        inputText = ""
        
        Task {
            await fetchAIResponse(to: userMessage)
        }
    }
    
    func clearConversation() {
        messages.removeAll()
        saveConversationHistory()
    }
    
    // MARK: - Private Methods
    
    private func fetchAIResponse(to userMessage: ChatMessage) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Build health context
                let healthContext = try await contextBuilder.buildHealthContext()
                
                // Get AI response
                let response = try await aiService.chat(
                    userMessage: userMessage.content,
                    healthContext: healthContext,
                    conversationHistory: messages.dropLast() // Exclude the current user message
                )
                
                let aiMessage = ChatMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date()
                )
                
                messages.append(aiMessage)
                saveConversationHistory()
                
            } catch {
                errorMessage = error.localizedDescription
                print("❌ AI Error: \(error.localizedDescription)")
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Persistence
    
    private func saveConversationHistory() {
        do {
            let encoded = try JSONEncoder().encode(messages)
            UserDefaults.standard.set(encoded, forKey: "healthChatHistory")
        } catch {
            print("Failed to save chat history: \(error)")
        }
    }
    
    private func loadConversationHistory() {
        if let data = UserDefaults.standard.data(forKey: "healthChatHistory") {
            do {
                messages = try JSONDecoder().decode([ChatMessage].self, from: data)
            } catch {
                print("Failed to load chat history: \(error)")
                messages = []
            }
        }
    }
}

// MARK: - ChatMessage Codable Conformance

extension ChatMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case id, content, isUser, timestamp
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(isUser, forKey: .isUser)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let content = try container.decode(String.self, forKey: .content)
        let isUser = try container.decode(Bool.self, forKey: .isUser)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        self.init(id: id, content: content, isUser: isUser, timestamp: timestamp)
    }
}
