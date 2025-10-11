import SwiftUI

struct HealthChatView: View {
    @StateObject private var viewModel: HealthChatViewModel
    @FocusState private var isFocused: Bool
    
    init(apiKey: String = AppConstants.geminiAPIKey) {
        _viewModel = StateObject(wrappedValue: HealthChatViewModel(apiKey: apiKey))
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Health Chat")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("AI-powered health insights")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if !viewModel.messages.isEmpty {
                            Button(action: { viewModel.clearConversation() }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .padding(.bottom)
                .background(Color(.systemGray6))
                
                // Messages
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if viewModel.messages.isEmpty {
                                EmptyStateView()
                            } else {
                                ForEach(viewModel.messages) { message in
                                    ChatMessageView(message: message)
                                        .id(message.id)
                                }
                            }
                            
                            if viewModel.isLoading {
                                LoadingMessageView()
                            }
                        }
                        .padding()
                        .onChange(of: viewModel.messages.count) {
                            withAnimation {
                                scrollProxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                }
                
                // Error message
                if let error = viewModel.errorMessage {
                    ErrorBannerView(message: error)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Input area
                ChatInputView(
                    text: $viewModel.inputText,
                    isLoading: viewModel.isLoading,
                    onSend: { viewModel.sendMessage($0) }
                )
                .focused($isFocused)
            }
        }
    }
}

// MARK: - Chat Message View

struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(12)
                .background(Color.blue)
                .cornerRadius(16)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Chat Input View

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: (String) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Ask about your health...", text: $text)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .disabled(isLoading)
                
                Button(action: { onSend(text) }) {
                    if isLoading {
                        ProgressView()
                            .tint(.blue)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .padding(.trailing, 4)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Loading Message View

struct LoadingMessageView: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                        value: UUID()
                    )
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Your Health Coach")
                .font(.headline)
            
            Text("Ask me about your fitness, recovery, sleep, or any health metrics. I have access to all your tracked data.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                SamplePrompt("How's my recovery looking?")
                SamplePrompt("Should I rest or train today?")
                SamplePrompt("What's my sleep trend?")
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Sample Prompt View

struct SamplePrompt: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.blue)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
    }
}

// MARK: - Error Banner View

struct ErrorBannerView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.white)
            
            Text(message)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(Color.red)
        .cornerRadius(8)
        .padding()
    }
}

#Preview {
    HealthChatView(apiKey: "demo-key")
}
