enum AdConfig {
    static let bannerUnitID: String = {
        #if DEBUG
                return "ca-app-pub-3940256099942544/2934735716" 
        #else
                return "ca-app-pub-7743096194062715/1151786131"
        #endif
            }()
            
}
