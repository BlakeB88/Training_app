import SwiftUI

struct HealthChatView: View {
    @StateObject private var viewModel: HealthChatViewModel
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0  // ← TRACKS KEYBOARD HEIGHT
    
    init(apiKey: String = AppConstants.geminiAPIKey) {
        _viewModel = StateObject(wrappedValue: HealthChatViewModel(apiKey: apiKey))
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Messages
                messagesView
                
                // Error banner (if any)
                if let error = viewModel.errorMessage {
                    ErrorBannerView(message: error) {
                        viewModel.errorMessage = nil
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Input Bar
                inputBar
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // ← KEYBOARD OBSERVERS START HERE
        .onAppear {
            // Listen for keyboard show
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation {
                        keyboardHeight = keyboardFrame.height
                    }
                }
            }
            
            // Listen for keyboard hide
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                withAnimation {
                    keyboardHeight = 0
                }
            }
        }
        // ← KEYBOARD OBSERVERS END HERE
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Health Chat")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
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
    }
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        EmptyStateView(onPromptTap: { prompt in
                            viewModel.inputText = prompt
                            viewModel.sendMessage(prompt)
                        })
                    } else {
                        ForEach(viewModel.messages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                    }
                    
                    if viewModel.isLoading {
                        LoadingMessageView()
                    }
                    
                    // Small padding at bottom
                    Color.clear.frame(height: 20)
                }
                .padding()
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation {
                        scrollProxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Input Bar (with Dynamic Keyboard Adjustment)
    
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField("Ask about your health...", text: $viewModel.inputText, axis: .vertical)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...5)
                    .disabled(viewModel.isLoading)
                    .submitLabel(.send)
                    .focused($isFocused)
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading ? Color.gray.opacity(0.3) : Color.blue)
                            .frame(width: 36, height: 36)
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            // ← DYNAMIC PADDING: Changes based on keyboard visibility
            .padding(.bottom, keyboardHeight > 0 ? 350 : 100)
            .background(Color(.systemBackground))
        }
    }
    
    private func sendMessage() {
        let trimmed = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && !viewModel.isLoading else { return }
        viewModel.sendMessage(trimmed)
        isFocused = false
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

// MARK: - Loading Message View

struct LoadingMessageView: View {
    @State private var animationAmount = 1.0
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .opacity(animationAmount)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animationAmount
                    )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .onAppear { animationAmount = 0.3 }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let onPromptTap: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            Text("Your Health Coach")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Ask me about your fitness, recovery, sleep, or any health metrics. I have access to all your tracked data.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            VStack(spacing: 8) {
                SamplePrompt("How's my recovery looking?", onTap: onPromptTap)
                SamplePrompt("Should I rest or train today?", onTap: onPromptTap)
                SamplePrompt("What's my sleep trend?", onTap: onPromptTap)
            }
            .padding(.top, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sample Prompt View

struct SamplePrompt: View {
    let text: String
    let onTap: (String) -> Void
    
    init(_ text: String, onTap: @escaping (String) -> Void) {
        self.text = text
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: { onTap(text) }) {
            Text(text)
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
        }
    }
}

// MARK: - Error Banner View

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.white)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(3)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .padding()
        .background(Color.red)
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview {
    HealthChatView(apiKey: "demo-key")
}
