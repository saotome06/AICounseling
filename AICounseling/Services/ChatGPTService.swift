import Foundation
import Supabase

struct TalkLog: Encodable {
    let log: [[String: String]]
    let last_updated_at: String
}

class ChatGPTService {
    static let shared = ChatGPTService() // (0)
    private var apiKey: String { // ここから（2）
        if let gptApiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String {
            return gptApiKey
        } else {
            return "not found"
        }
    }
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    private var conversationHistory: [String] = [] // （3）
    private let systemContent =
    """
        このチャットボットは心の悩みに関するカウンセリングを行います。
        20文字以内で返して。
    """.trimmingCharacters(in: .whitespacesAndNewlines)
    
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
    
    
    func fetchResponse(_ message: String, messages:[Message], completion: @escaping (Result<String, Error>) -> Void) { // （5）
        // ユーザーのメッセージを履歴に追加する
        conversationHistory.append(message) // （6）
        print("fetchResponse::::::::", messages)
        // APIリクエストを作成する
        guard let url = URL(string: apiURL) else { // （7）
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        // リクエストヘッダーを設定する
        var request = URLRequest(url: url) // ここから（8）
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") // ここまで（8）
        var messagesToSend = messages
        var messages: [[String: String]]

        if messagesToSend.isEmpty {
            messages = [["role": "system", "content": systemContent]] // （9）
            // 送信データ用のmessagesリストを作成する
        }else {
            // メッセージを[[String: String]]に変換する
            var convertedMessages: [[String: String]] = []
            for message in messagesToSend {
                let convertedMessage: [String: String] = [
                    "content": message.text,
                    "role": message.role
                ]
                convertedMessages.append(convertedMessage)
            }
            messages = convertedMessages
        }


        // 過去のメッセージをもとに、ユーザーとアシスタントのメッセージを交互に追加する
        for (i, message) in conversationHistory.enumerated() { // ここから（10）
            if i % 2 == 0 {
                messages.append(["role": "user", "content": message])
            } else {
                messages.append(["role": "assistant", "content": message])
            }
        } // ここまで（10）
        // 最後に現在のユーザーのメッセージを追加する
        // messages.append(["role": "user", "content": message]) // （11）
        
        let parameters: [String: Any] = [ // ここから（12）
            "model": "gpt-3.5-turbo",
            "messages": messages
        ] // ここまで（12）
        //print(messages)
        
        // リクエストボディを設定する
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters) // （13）
        
        // リクエストを送信する
        let task = URLSession.shared.dataTask(with: request) { data, response, error in // （14）
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // レスポンスデータを処理する
            guard let data = data else { // （15）
                completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                return
            }
            //            print("data: \(String(data: data, encoding: .utf8) ?? "")")
            
            do {
                // レスポンスデータをパースして、アシスタントのメッセージを取得する
                if let jsonResult = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], // ここから（16）
                   let text = jsonResult["choices"] as? [[String: Any]],
                   let firstChoice = text.first,
                   let message = firstChoice["message"] as? [String: String],
                   let content = message["content"] { // ここまで（16）
                    // アシスタントのメッセージを履歴に追加して、コールバックを呼び出す
                    self.conversationHistory.append(content) // ここから（17）
                    messages.append(message)
                    completion(.success(content)) // ここまで（17）
                } else {
                    print("test error")
                    let errorMessage = "エラーが発生しました。" // ここから（18）
                    self.conversationHistory.append(errorMessage)
                    completion(.failure(NSError(domain: "Invalid response format", code: 0, userInfo: ["message": errorMessage]))) // ここまで（18）
                }
            } catch {
                let errorMessage = "エラーが発生しました。" // ここから（19）
                self.conversationHistory.append(errorMessage)
                completion(.failure(NSError(domain: "Error", code: 0, userInfo: ["message": errorMessage]))) // ここまで（19）
            }
            self.saveLogToDatabase(log: messages)
        }
        
        task.resume()
    }
    func saveLogToDatabase(log: [[String: String]]) {
        let email = UserDefaults.standard.string(forKey: "user_email") ?? ""
        
        let currentTime = Date().iso8601String()
        
        let updates = TalkLog(
            log: log,
            last_updated_at: currentTime
        )
        Task {
            do {
                let jsonEncoder = JSONEncoder()
                let jsonData = try jsonEncoder.encode(updates)
                guard var jsonString = String(data: jsonData, encoding: .utf8) else {
                    // JSONデータを文字列に変換できない場合のエラーハンドリング
                    return
                }
                let formattedJsonString = try formatJSONString(jsonString)

                let _ = try await client
                    .from("users")
                    .update(["log_data": jsonString])
                    .eq("user_email", value: email)
                    .execute()
            } catch {
                // エラーハンドリング
                print("Error:", error)
            }
        }
    }
    func formatJSONString(_ jsonString: String) throws -> String {
        let jsonData = jsonString.data(using: .utf8)!
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        let formattedData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted])
        guard let formattedString = String(data: formattedData, encoding: .utf8) else {
            throw NSError(domain: "JSON formatting error", code: 0, userInfo: nil)
        }
        print(formattedString)
        return formattedString
    }
}

// ISO8601形式の文字列に変換するためのヘルパー
extension Date {
        func iso8601String() -> String {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
            return dateFormatter.string(from: self)
        }
}
