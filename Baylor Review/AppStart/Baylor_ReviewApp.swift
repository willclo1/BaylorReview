import SwiftUI
import Firebase
import FirebaseAppCheck   // make sure this is in your Podfile / SPM deps

@main
struct BaylorReviewApp: App {
  init() {
    #if DEBUG
    // Use the *debug* provider factory (name changed in Firebase 12+)
    AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
    #endif

    FirebaseApp.configure()
  }

  @StateObject private var auth = AuthViewModel()

  var body: some Scene {
    WindowGroup {
      Group {
        if auth.isSignedIn {
          ContentView()
            .environmentObject(auth)
        } else {
          EmailSignInView()
            .environmentObject(auth)
        }
      }
    }
  }
}
