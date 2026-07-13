import XCTest

/// Adds the real widget to the simulator home screen by driving Springboard.
/// Run via scripts/render_widget_screenshots.sh (which pre-grants calendar access);
/// after the test the widget stays on the home screen, so the script can capture it
/// with `simctl io screenshot` — and, with the snapshot cleared and the demo fallback
/// disabled, whatever the widget shows comes from the appex's own EventKit read.
final class WidgetHomeScreenTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAddMediumWidgetToHomeScreen() throws {
        // 1. Launch the app once: seeds EventKit demo events (calendar access was
        //    pre-granted via simctl privacy) and writes the snapshot.
        let app = XCUIApplication()
        app.launchArguments = ["-SeedEventKit"]
        app.launch()
        sleep(3)
        XCUIDevice.shared.press(.home)
        sleep(1)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        // 2. Enter jiggle mode: long-press EMPTY wallpaper (pressing an icon would
        //    open its context menu instead). Lower third of the screen is empty on
        //    a fresh simulator.
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            .press(forDuration: 2.5)
        sleep(1)

        // 3. Open the widget gallery. Entry point differs across iOS versions:
        //    iOS 17: a "+" top-left; iOS 18+/26: "Edit" top-left -> "Add Widget".
        let direct = springboard.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Add Widget'")).firstMatch
        if direct.waitForExistence(timeout: 2) {
            direct.tap()
        } else {
            let edit = springboard.buttons["Edit"]
            XCTAssertTrue(edit.waitForExistence(timeout: 5), "no jiggle-mode Edit button")
            edit.tap()
            let addWidget = springboard.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Add Widget'")).firstMatch
            XCTAssertTrue(addWidget.waitForExistence(timeout: 5), "no Add Widget menu item")
            addWidget.tap()
        }

        // 4. Search for the app in the gallery and open its widget page.
        let search = springboard.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 6), "no gallery search field")
        search.tap()
        search.typeText("3 Line")
        sleep(1)
        let hit = springboard.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] '3 Line'")).firstMatch
        XCTAssertTrue(hit.waitForExistence(timeout: 6), "app not found in widget gallery")
        // The result row's text reports as not-hittable; a coordinate tap works anyway.
        hit.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(2)

        // 5. Make sure the widget DETAIL page opened (anchored by the widget's
        //    display name) — the gallery entry menu also has an element labeled
        //    "Add Widget", so a blind firstMatch can hit a stale element.
        let detailAnchor = springboard.staticTexts["Next 3 Events"]
        XCTAssertTrue(detailAnchor.waitForExistence(timeout: 5), "widget detail page did not open")
        springboard.swipeLeft()   // small -> medium family
        sleep(1)
        let candidates = springboard.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Add Widget'")).allElementsBoundByIndex
        guard let confirm = candidates.last(where: { $0.isHittable }) ?? candidates.last else {
            XCTFail("no Add Widget confirm button"); return
        }
        confirm.tap()
        sleep(1)

        // 6. Leave jiggle mode.
        XCUIDevice.shared.press(.home)
        sleep(2)

        // 7. Verify the widget actually landed on a page, and end the test there
        //    so an immediate outer screenshot shows it. Home-screen widgets are
        //    exposed as `icons` (NOT staticTexts) in Springboard's tree.
        let placed = springboard.icons.matching(
            NSPredicate(format: "label CONTAINS[c] '3 Line'")).firstMatch
        var swipes = 0
        while !placed.exists && swipes < 3 {
            springboard.swipeLeft()
            swipes += 1
            sleep(1)
        }
        XCTAssertTrue(placed.exists, "widget not on any home-screen page after adding")
        sleep(4)   // let WidgetKit render the timeline
    }
}
