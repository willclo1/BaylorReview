import SwiftUI
import Firebase
import FirebaseAppCheck

import GoogleMobileAds

class YourAppCheckProvider: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    return AppAttestProvider(app: app)
  }
}

@main
struct BaylorReviewApp: App {
  init() {
    FirebaseApp.configure()

    // App Check providers
    #if targetEnvironment(simulator)
      // Simulator cannot do App Attest; allow only simulator via Debug provider.
      AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
    #else
      // Physical devices: App Attest only (no DeviceCheck fallback)
      if #available(iOS 14.0, *) {
          let providerFactory = YourAppCheckProvider()
          AppCheck.setAppCheckProviderFactory(providerFactory)
      } else {
        // If you really mean "App Attest only", hard-stop older OSes:
        fatalError("This app requires iOS 14+ for App Attest.")
      }
    #endif

    // (Unrelated to App Check) Start AdMob if you use it
    MobileAds.shared.start()
  }

  @StateObject private var auth = AuthViewModel()
  var body: some Scene {
    WindowGroup {
      Group {
        if auth.isSignedIn {
          ContentView().environmentObject(auth)
        } else {
          EmailSignInView().environmentObject(auth)
        }
      }
    }
  }
}
