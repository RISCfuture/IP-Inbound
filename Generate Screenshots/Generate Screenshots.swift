// swiftlint:disable prefer_nimble

import XCTest
import CoreLocation

@MainActor
final class Generate_Screenshots: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws { // swiftlint:disable:this empty_xctest_method
                                               // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testScreenshots_ground() throws {
        let app = launch()

        makeTarget(app: app, screenshot: true)
        
        setTimePicker(app: app, minutesFromNow: 10)
        snapshot("2-define-tot")

        XCUIDevice.shared.location = .init(location: LocationHelper.groundLocation())
        app.buttons["flyButton"].tap()
        XCTAssert(app.staticTexts["countdown"].waitForExistence(timeout: 60))

        snapshot("3-fly-ground")

        app.terminate()
    }

    @MainActor
    func testScreenshots_ipEarly() throws {
        let app = launch()

        makeTarget(app: app)
        setTimePicker(app: app, minutesFromNow: 10)

        XCUIDevice.shared.location = .init(location: LocationHelper.preIPLocation())
        app.buttons["flyButton"].tap()
        XCTAssert(app.staticTexts["cdi"].waitForExistence(timeout: 60))

        snapshot("4-fly-pre-ip-early")

        app.terminate()
    }
    
    @MainActor
    func testScreenshots_ip() throws {
        let app = launch()
        
        makeTarget(app: app)
        setTimePicker(app: app, minutesFromNow: 2)
        
        XCUIDevice.shared.location = .init(location: LocationHelper.preIPLocation())
        app.buttons["flyButton"].tap()
        XCTAssert(app.staticTexts["cdi"].waitForExistence(timeout: 60))
        
        snapshot("5-fly-pre-ip")
        
        app.terminate()
    }

    @MainActor
    func testScreenshots_ipLate() throws {
        let app = launch()

        makeTarget(app: app)
        setTimePicker(app: app, minutesFromNow: 1.5)
        
        XCUIDevice.shared.location = .init(location: LocationHelper.preIPLocation())
        app.buttons["flyButton"].tap()
        XCTAssert(app.staticTexts["cdi"].waitForExistence(timeout: 60))

        snapshot("6-fly-pre-ip-late")

        app.terminate()
    }
    
    @MainActor
    func testScreenshots_postIP() throws {
        let app = launch()
        
        makeTarget(app: app)
        setTimePicker(app: app, minutesFromNow: 1)
        
        XCUIDevice.shared.location = .init(location: LocationHelper.postIPLocation())
        app.buttons["flyButton"].tap()
        XCTAssert(app.staticTexts["cdi"].waitForExistence(timeout: 60))
        
        snapshot("4-fly-post-ip")
        
        app.terminate()
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication(),
            springboardApp = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        setupSnapshot(app, waitForAnimations: true)
        app.launch()

        if springboardApp.alerts.buttons["Allow While Using App"].waitForExistence(timeout: 5) {
            springboardApp.alerts.buttons["Allow While Using App"].tap()
        }

        return app
    }
    
    private func makeTarget(app: XCUIApplication, screenshot: Bool = false) {
        XCUIDevice.shared.location = .init(location: LocationHelper.targetLocation())
        
        if app.buttons["ToggleSidebar"].waitForExistence(timeout: 1) {
            app.buttons["ToggleSidebar"].tap()
        }
        
        app.buttons["addTargetButton"].firstMatch.tap()
        XCTAssert(app.textFields["targetNameField"].waitForExistence(timeout: 60))
        
        app.textFields["targetNameField"].tap()
        app.textFields["targetNameField"].tap(withNumberOfTaps: 3, numberOfTouches: 1)
        app.textFields["targetNameField"].typeText("Dog Bone Lake\n")
        sleep(5)
        
        if screenshot { snapshot("0-define-target") }
        
        app.buttons["defineIPButton"].tap()
        XCTAssert(app.textFields["offsetBearingField"].waitForExistence(timeout: 60))
        
        app.textFields["offsetBearingField"].doubleTap()
        app.textFields["offsetBearingField"].typeText("\(Int(LocationHelper.IPBearingTrue))")
        app.buttons["offsetBearingTrue"].tap()
        
        app.textFields["offsetDistanceField"].doubleTap()
        app.textFields["offsetDistanceField"].typeText("\(LocationHelper.IPDistanceNM)")
        
        app.textFields["targetGroundSpeedField"].doubleTap()
        app.textFields["targetGroundSpeedField"].typeText("\(LocationHelper.targetGroundSpeed)\n")
        
        if screenshot { snapshot("1-define-ip") }
        
        app.buttons["timeOnTargetButton"].tap()
    }

    private func setTimePicker(app: XCUIApplication, minutesFromNow: Double) {
        XCTAssert(app.datePickers["timeOnTargetPicker"].waitForExistence(timeout: 60))
        let date = LocationHelper.pickerComponents(minutesFromNow: minutesFromNow),
            pickerWheels = app.datePickers["timeOnTargetPicker"].pickerWheels
        pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: date.hour)
        pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: date.minute)
        pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: date.meridian)
    }
}

// swiftlint:enable prefer_nimble
