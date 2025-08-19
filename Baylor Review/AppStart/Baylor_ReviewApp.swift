import SwiftUI
import Firebase
import FirebaseAppCheck
import GoogleMobileAds

class YourAppCheckProvider: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    // App Attest only (no DeviceCheck fallback)
    return AppAttestProvider(app: app)
  }
}

@main
struct BaylorReviewApp: App {
  // Auth observable for the whole app
  @StateObject private var auth = AuthViewModel()

  init() {
    // 1) App Check provider MUST be set BEFORE FirebaseApp.configure()
    #if targetEnvironment(simulator)
      // Simulator: use Debug provider (App Attest not available)
      AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
    #else
      if #available(iOS 14.0, *) {
        AppCheck.setAppCheckProviderFactory(YourAppCheckProvider())
      } else {
        fatalError("This app requires iOS 14+ for App Attest.")
      }
    #endif

    // 2) Firebase
    FirebaseApp.configure()

    // 3) AdMob startup
      MobileAds.shared.start()
  }

  var body: some Scene {
    WindowGroup {
      Group {
        if auth.isSignedIn {
          // Show your app content behind the Terms/EULA gate
          LegalGate(
            content: { ContentView().environmentObject(auth) },
            // TODO: replace with your actual GitHub Pages links:
            termsURL:   URL(string: "https://willclo1.github.io/EULA"),
            privacyURL: URL(string: "https://willclo1.github.io/policy")
          )
          .environmentObject(auth) // optional; content already has it
        } else {
          EmailSignInView()
            .environmentObject(auth)
        }
      }
    }
  }
}

