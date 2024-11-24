import XCTest

final class IP_InboundUITestsLaunchTests: XCTestCase {

    override static var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testNew() throws {
        let app = XCUIApplication()
        app.activate()
        app.otherElements/*@START_MENU_TOKEN@*/.containing(.button, identifier: "defineIPButton").firstMatch/*[[".element(boundBy: 18)",".containing(.link, identifier: \"Legal\").firstMatch",".containing(.button, identifier: \"Tracking\").firstMatch",".containing(.button, identifier: \"defineIPButton\").firstMatch"],[[[-1,3],[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

        let targetNameFieldTextField = app/*@START_MENU_TOKEN@*/.textFields["targetNameField"]/*[[".otherElements",".textFields[\"New Target\"]",".textFields[\"targetNameField\"]",".textFields.firstMatch"],[[[-1,2],[-1,1],[-1,3],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        targetNameFieldTextField.tap()
        targetNameFieldTextField.tap()
        targetNameFieldTextField.tap()
        targetNameFieldTextField.tap()
        app/*@START_MENU_TOKEN@*/.staticTexts["Define IP"]/*[[".buttons",".staticTexts.firstMatch",".staticTexts[\"Define IP\"]"],[[[-1,2],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()

        let offsetBearingFieldTextField = app/*@START_MENU_TOKEN@*/.textFields["offsetBearingField"]/*[[".otherElements",".textFields[\"0\"]",".textFields[\"offsetBearingField\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        offsetBearingFieldTextField.tap()
        offsetBearingFieldTextField.tap()
        offsetBearingFieldTextField.tap()
        offsetBearingFieldTextField.tap()

        let offsetDistanceFieldTextField = app/*@START_MENU_TOKEN@*/.textFields["offsetDistanceField"]/*[[".otherElements",".textFields[\"4\"]",".textFields[\"offsetDistanceField\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        offsetDistanceFieldTextField.tap()
        offsetDistanceFieldTextField.tap()
        app/*@START_MENU_TOKEN@*/.staticTexts["Time on Target"]/*[[".buttons[\"timeOnTargetButton\"].staticTexts.firstMatch",".buttons.staticTexts[\"Time on Target\"]",".staticTexts[\"Time on Target\"]"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        app/*@START_MENU_TOKEN@*/.buttons["flyButton"]/*[[".buttons",".containing(.image, identifier: \"chevron.forward\").firstMatch",".containing(.staticText, identifier: \"Fly!\").firstMatch",".otherElements",".buttons[\"Fly!\"]",".buttons[\"flyButton\"]"],[[[-1,5],[-1,4],[-1,3,2],[-1,0,1]],[[-1,2],[-1,1]],[[-1,5],[-1,4]]],[0]]@END_MENU_TOKEN@*/.tap()
    }
}
