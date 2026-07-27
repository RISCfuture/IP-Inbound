import XCTest

// swiftlint:disable prefer_nimble

final class TutorialTests: BaseTestCase {

  // MARK: - Test 35

  func testTutorial_ShowsTitle() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let tutorial = list.tapTutorial()

    XCTAssertTrue(
      tutorial.tutorialTitle.waitForExistence(timeout: 5),
      "'How to Use IP Inbound' title should be displayed"
    )
  }

  // MARK: - Test 36

  func testTutorial_ContainsSectionHeaders() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let tutorial = list.tapTutorial()

    XCTAssertTrue(tutorial.hasSectionTitle("Planning"), "'Planning' section should exist")
    XCTAssertTrue(tutorial.hasSectionTitle("Pre-IP"), "'Pre-IP' section should exist")
    XCTAssertTrue(
      tutorial.hasSectionTitle("IP-to-Target Run"),
      "'IP-to-Target Run' section should exist"
    )
    XCTAssertTrue(
      tutorial.hasSectionTitle("Late to Target"),
      "'Late to Target' section should exist"
    )
  }

  // MARK: - Test 37

  func testTutorial_DismissReturnToList() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let tutorial = list.tapTutorial()
    XCTAssertTrue(tutorial.isDisplayed)

    let returnedList = tutorial.dismiss()
    XCTAssertTrue(
      returnedList.addTargetButton.waitForExistence(timeout: 5),
      "addTargetButton should be on screen after dismissing tutorial"
    )
  }

  // MARK: - Test 38

  func testTutorial_DismissViaSwipeDown() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let tutorial = list.tapTutorial()
    XCTAssertTrue(tutorial.isDisplayed)

    let returnedList = tutorial.dismissViaSwipeDown()
    XCTAssertTrue(
      returnedList.addTargetButton.waitForExistence(timeout: 5),
      "addTargetButton should be on screen after swipe-down dismiss"
    )
  }
}

// swiftlint:enable prefer_nimble
