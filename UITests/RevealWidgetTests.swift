import XCTest

/// Navigates Springboard to the home-screen page containing our widget WITHOUT
/// launching the app (launching it would rewrite the App Group snapshot and spoil
/// the "widget read EventKit itself" proof). Used by render_widget_screenshots.sh
/// right before the `simctl io screenshot` capture.
final class RevealWidgetTests: XCTestCase {

    func testRevealWidgetPage() throws {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.activate()
        sleep(2)

        // Home-screen widgets are exposed as `icons` (NOT staticTexts).
        let widgetLabel = springboard.icons.matching(
            NSPredicate(format: "label CONTAINS[c] '3 Line'")).firstMatch

        var swipes = 0
        while !widgetLabel.exists && swipes < 3 {
            springboard.swipeLeft()
            swipes += 1
            sleep(1)
        }
        XCTAssertTrue(widgetLabel.exists, "widget not found on any home-screen page")
        sleep(3)   // let the page settle before the outer script captures
    }
}
