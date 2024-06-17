import SwiftUI
import Speech
import OpenAISwift
import AVFoundation

struct VoiceChat: View {
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var voiceText: String = ""
    @State private var isRecording: Bool = false
    @ObservedObject private var speechRecorder = SpeechRecorder()
    @State private var showingAlert = false
    @ObservedObject private var viewModel = CreateAudioViewModel2()
    @ObservedObject private var interjectionModel = InterjectionVoice()
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var isMenuOpen = false
    
    let interjections = ["うーん", "あーー", "あ、はい", "えーーと", "ええ、", "ん〜〜と", "おお！", "うーん、うん"]
    
    var body: some View {
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
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Capsule()
                        .frame(width: CGFloat(viewModel.audioLevel) * 500, height: CGFloat(viewModel.audioLevel) * 500)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.purple.opacity(0.7), radius: 10, x: 0, y: 10)
                        .animation(.easeOut(duration: 0.2), value: viewModel.audioLevel)
                    
                    Spacer()
                }
                
                if viewModel.isLoadingTextToSpeechAudio == .finishedPlaying {
                    Text("話しかけてください")
                        .fontWeight(.semibold)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                } else {
                    Text("AIが話しています")
                        .fontWeight(.semibold)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.gray)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                
//                VStack {
//                    if audioRecorder.isRecording {
//                        Button(action: {
//                            audioRecorder.stopRecording()
//                            let wavFilePath = audioRecorder.getDocumentsDirectory().appendingPathComponent("recording.wav").path
//                            //                        analyzeWav(apiKey: apiKey, wavFilePath: wavFilePath)
//                        }) {
//                            Text("Stop Recording")
//                                .padding()
//                                .background(Color.red)
//                                .foregroundColor(.white)
//                                .cornerRadius(10)
//                        }
//                    } else {
//                        Button(action: {
//                            audioRecorder.startRecording()
//                        }) {
//                            Text("Start Recording")
//                                .padding()
//                                .background(Color.green)
//                                .foregroundColor(.white)
//                                .cornerRadius(10)
//                        }
//                    }
//                    
//                    if !audioRecorder.isRecording {
//                        Button(action: {
//                            let wavFilePath = audioRecorder.getDocumentsDirectory().appendingPathComponent("recording.wav")
//                            audioPlayer.playAudio(url: wavFilePath)
//                        }) {
//                            Text("Play Recording")
//                                .padding()
//                                .background(Color.blue)
//                                .foregroundColor(.white)
//                                .cornerRadius(10)
//                        }
//                        .disabled(audioRecorder.isRecording)
//                    }
//                    
//                    if audioPlayer.isPlaying {
//                        Button(action: {
//                            audioPlayer.stopAudio()
//                        }) {
//                            Text("Stop Playing")
//                                .padding()
//                                .background(Color.orange)
//                                .foregroundColor(.white)
//                                .cornerRadius(10)
//                        }
//                    }
//                }
//                .navigationBarTitle("Audio Recorder")
//                .navigationBarBackButtonHidden(true) // Backボタンを隠す
//                .navigationBarItems(leading: EmptyView())
                
                Text(self.speechRecorder.audioText)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(.vertical)
        }
        .onAppear {
            requestPermissions()
            if AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == .authorized &&
                SFSpeechRecognizer.authorizationStatus() == .authorized {
                self.showingAlert = false
                self.speechRecorder.toggleRecording()
            } else {
                self.showingAlert = true
            }
        }
        .onChange(of: self.speechRecorder.audioRunning) { newValue in
            if !newValue {
                if !self.speechRecorder.audioText.isEmpty {
                    prepareLoadingSound()
                    voiceText = self.speechRecorder.audioText
                    sendMessage()
                    print(voiceText)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    }
                    audioRecorder.stopRecording()
                }
            }
        }
        .onChange(of: viewModel.isLoadingTextToSpeechAudio) { newValue in
            print(viewModel.isLoadingTextToSpeechAudio)
            if newValue == .finishedPlaying {
                self.showingAlert = false
                self.speechRecorder.toggleRecording()
            }
        }
        .onChange(of: self.speechRecorder.audioText) { newValue in
            if self.speechRecorder.audioText.count == 3 {
                audioRecorder.startRecording()
            }
//            if self.speechRecorder.audioText.count == 30 {
//                audioRecorder.stopRecording()
//                let wavFilePath = audioRecorder.getDocumentsDirectory().appendingPathComponent("recording.wav").path
//                print("sddsfdsdfdd")
////                analyzeWav(apiKey: apiKey, wavFilePath: wavFilePath)
//            }
        }
        .navigationBarBackButtonHidden(true) // Backボタンを隠す
        .navigationBarItems(leading: EmptyView())
    }
    
    private func requestPermissions() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                SFSpeechRecognizer.requestAuthorization { authStatus in
                    switch authStatus {
                    case .authorized:
                        // 許可が与えられた場合の処理
                        print("Speech recognition authorized")
                    case .denied, .restricted, .notDetermined:
                        // 許可が拒否された場合の処理
                        print("Speech recognition not authorized")
                    @unknown default:
                        fatalError("Unexpected SFSpeechRecognizer authorization status")
                    }
                }
            } else {
                // マイクの使用許可が拒否された場合の処理
                print("Microphone access not authorized")
            }
        }
    }
    
    private func sendMessage() {
        if !voiceText.isEmpty {
            messages.append(Message(text: voiceText, isReceived: false, role:"assistant"))
            
            ChatGPTService.shared.fetchResponse(voiceText,messages:messages) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        messages.append(Message(text: response, isReceived: true, role:"assistant"))
                        Task {
                            do {
                                try await viewModel.createSpeech(input: response)
                            } catch {
                                print("Failed to create speech: \(error)")
                            }
                        }
                    case .failure(let error):
                        print("Error: \(error.localizedDescription)")
                        messages.append(Message(text: "エラーが発生しました。", isReceived: true, role:"assistant"))
                    }
                    voiceText = ""
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
    
    private func prepareLoadingSound() {
        let randomIndex = Int.random(in: 0..<interjections.count)
        let randomInterjection = interjections[randomIndex]
        Task {
            do {
                try await interjectionModel.createSpeech(input: randomInterjection)
            } catch {
                print("Failed to create speech: \(error)")
            }
        }
    }
}

struct VoiceChat_Previews: PreviewProvider {
    static var previews: some View {
        VoiceChat()
    }
}
