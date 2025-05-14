@testable import IP_Inbound
import Testing

@Suite("IP Inbound Core Tests")
struct IP_InboundTests {
    
    @Test("Application initializes correctly")
    func testApplicationInitialization() throws {
        // Basic sanity test that constants are defined as expected
        #expect(Target.allowableSpeedVariance == 0.1)
    }
}