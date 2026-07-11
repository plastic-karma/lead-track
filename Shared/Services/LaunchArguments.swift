import Foundation

/// Launch arguments the app honors, spelled once: a typo in a re-spelled
/// literal would silently break UI-test isolation instead of failing to
/// compile. The UI-test target cannot import this module, so its runner
/// keeps a mirrored literal pointing back here.
enum LaunchArguments {
    static let uiTest = "-uitest"

    static var isUITest: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTest)
    }
}
