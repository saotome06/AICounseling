import SwiftUI
import Supabase
struct TextChat: View {
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    
    private var supabaseURL: URL {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL not found in Info.plist or is not a valid URL")
        }
        return url
    }
    private var supabaseKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as? String else {
            fatalError("SUPABASE_KEY not found in Info.plist")
        }
        return key
    }

    private var client: SupabaseClient {
        return SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack {
                            ForEach(messages, id: \.self) { message in
                                MessageView(message: message)
                            }
                        }
                        .onChange(of: messages.count) {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
                
                Spacer()
                
                HStack {
                    TextEditor(text: $inputText)
                        .padding(5)
                        .frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 15).stroke(Color.gray, lineWidth: 3))
                        .padding(.trailing, 10)
                    
                    Button(action: {
                        sendMessage()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .padding(5)
                            .shadow(color: .gray, radius: 5, x: 0, y: 2)
                    }
                }
                .padding()
                .cornerRadius(30)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: VoiceChat()) { // 通話画面に遷移するボタン
                        Image(systemName: "phone.fill") // 通話アイコン
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 25, height: 25) // アイコンのサイズを調整
                            .foregroundColor(.blue)
                            .padding()
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true) // Backボタンを隠す
        .navigationBarItems(leading: EmptyView())
        .onAppear {
            fetchLogData()
        }
    }
    func fetchLogData() {
        guard let email = UserDefaults.standard.string(forKey: "user_email") else { return }
        
        Task {
            do {
                let response = try await client.from("users")
                    .select("log_data")
                    .eq("user_email", value: email)
                    .execute()
                
                let data = response.data
                let logData = String(decoding: data, as: UTF8.self)
                parseLogData(logData)
            } catch {
                print("Error fetching log data: \(error)")
            }
        }
    }
    
    func parseLogData(_ logData: String) {
        do {
            let jsonData = try JSONSerialization.jsonObject(with: Data(logData.utf8), options: []) as? [[String: String]]
            guard let log = jsonData?.first?["log_data"],
                  let logJSONData = log.data(using: .utf8),
                  let logDict = try JSONSerialization.jsonObject(with: logJSONData, options: []) as? [String: Any],
                  let logArray = logDict["log"] as? [[String: String]] else {
                print("Log data not found")
                return
            }
            
            for entry in logArray {
                if let content = entry["content"], let role = entry["role"] {
                    let message = Message(text: content, isReceived: role == "assistant", role: role)
                    messages.append(message)
                }
            }
        } catch {
            print("Error decoding log data: \(error)")
        }
    }
    
    private func sendMessage() {
        if !inputText.isEmpty {
            print("sendmessage: ", messages)
            messages.append(Message(text: inputText, isReceived: false, role: "user"))
            
            ChatGPTService.shared.fetchResponse(inputText,messages: messages) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        messages.append(Message(text: response, isReceived: true, role: "assistant"))
                    case .failure(let error):
                        print("Error: \(error.localizedDescription)")
                        messages.append(Message(text: "エラーが発生しました。", isReceived: true, role: "assistant"))
                    }
                    inputText = ""

                }
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = messages.last else { return }
        withAnimation {
            proxy.scrollTo(lastMessage, anchor: .bottom)
        }
    }
}

struct TextChat_Previews: PreviewProvider {
    static var previews: some View {
        TextChat()
    }
}
