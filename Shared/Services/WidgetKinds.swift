/// Stable identifiers shared by the app and its widget extension. The app
/// uses these to invalidate controls after a SwiftData save; the extension
/// uses the same value when registering the control with WidgetKit.
enum WidgetKinds {
    static let favoriteMetricControl = "FavoriteMetricControl"
}
