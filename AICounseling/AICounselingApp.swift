import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
struct AICounselingApp: App {
    @StateObject private var sessionManager = SessionManager()

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                if sessionManager.isLoggedIn {
                    if sessionManager.isUserDataComplete {
                        MainView()
                    } else {
                        UserRegistView()
                    }
                } else {
                    LoginView()
                }
            }
            .onAppear {
//                UserDefaultsを削除してデバッグしたいときは以下コメントを外す
//                let appDomain = Bundle.main.bundleIdentifier
//                UserDefaults.standard.removePersistentDomain(forName: appDomain!)
                sessionManager.checkSession()
            }
            .navigationBarItems(leading: EmptyView())
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // 通知の許可を求める
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            print("Permission granted: \(granted)")
        }

        application.registerForRemoteNotifications()
        Messaging.messaging().delegate = self

        return true
    }
    // APNsトークンをFirebaseに登録
    // didRegisterForRemoteNotificationsWithDeviceTokenが呼ばれる = デバイストークンがAPNsに登録されたと言うこと
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let deviceTokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs Device Token: \(deviceTokenString)")

        Messaging.messaging().apnsToken = deviceToken
    }

    // FCMトークンを取得
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        // ここでトークンをサーバーに送信する処理を追加できます
    }

    // 通知を受信したときの処理
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([[.alert, .sound, .badge]])
    }
}
