import SwiftUI

struct Message: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isReceived: Bool
}

struct MessageView: View { // （2）
    let message: Message
    
    var body: some View {
        HStack {
            if message.isReceived { // （3）
                Text(message.text) // ここから（4）
                    .padding(10)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                Spacer() // ここまで（4）
            } else {
                Spacer() // ここから（5）
                Text(message.text)
                    .padding(10)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(10) // ここまで（5）
            }
        }
        .padding(.horizontal) // （6）
    }
}

#Preview {
    MessageView(message: Message(text: "Hello", isReceived: false))
}
