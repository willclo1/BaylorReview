import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
  let adUnitID: String

  func makeUIView(context: Context) -> BannerView {
    let width = UIScreen.main.bounds.width
    let size  = currentOrientationAnchoredAdaptiveBanner(width: width)

    let banner = BannerView(adSize: size)
    banner.adUnitID = adUnitID
    banner.rootViewController = rootVC()
    banner.load(Request())
    return banner
  }

  func updateUIView(_ banner: BannerView, context: Context) {
    let width = UIScreen.main.bounds.width
    let size  = currentOrientationAnchoredAdaptiveBanner(width: width)
    if banner.adSize.size != size.size {
      banner.adSize = size
      banner.load(Request())
    }
  }

  private func rootVC() -> UIViewController? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first(where: { $0.isKeyWindow })?
      .rootViewController
  }
}
