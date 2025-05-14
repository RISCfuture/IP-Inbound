@testable import IP_Inbound
import SwiftUI
import Testing

@Suite("Extensions")
struct ExtensionsTests {

    // MARK: - CGSize Extensions

    @Test("CGSize, center, returns correct point")
    func testCGSizeCenter() throws {
        let size = CGSize(width: 100, height: 200)
        let center = size.center

        #expect(center.x == 50)
        #expect(center.y == 100)
    }

    @Test("CGSize, minDimension, returns correct value")
    func testCGSizeMinDimension() throws {
        let size1 = CGSize(width: 100, height: 200)
        #expect(size1.minDimension == 100)

        let size2 = CGSize(width: 300, height: 200)
        #expect(size2.minDimension == 200)
    }

    @Test("CGSize, maxDimension, returns correct value")
    func testCGSizeMaxDimension() throws {
        let size1 = CGSize(width: 100, height: 200)
        #expect(size1.maxDimension == 200)

        let size2 = CGSize(width: 300, height: 200)
        #expect(size2.maxDimension == 300)
    }

    // MARK: - CGRect Extensions

    @Test("CGRect, center, returns correct point")
    func testCGRectCenter() throws {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 200)
        let center = rect.center

        #expect(center.x == 60)
        #expect(center.y == 120)
    }

    // MARK: - CGPoint Extensions

    @Test("CGPoint, offset, returns correct point when offset in x direction")
    func testCGPointOffsetX() throws {
        let point = CGPoint(x: 10, y: 20)
        let offsetPoint = point.offset(dx: 5)

        #expect(offsetPoint.x == 15)
        #expect(offsetPoint.y == 20)
    }

    @Test("CGPoint, offset, returns correct point when offset in y direction")
    func testCGPointOffsetY() throws {
        let point = CGPoint(x: 10, y: 20)
        let offsetPoint = point.offset(dy: 5)

        #expect(offsetPoint.x == 10)
        #expect(offsetPoint.y == 25)
    }

    @Test("CGPoint, offset, returns correct point when offset in both directions")
    func testCGPointOffsetBoth() throws {
        let point = CGPoint(x: 10, y: 20)
        let offsetPoint = point.offset(dx: 5, dy: 10)

        #expect(offsetPoint.x == 15)
        #expect(offsetPoint.y == 30)
    }

    // MARK: - String Extensions

    @Test("String, slice, with single index, returns correct substring")
    func testStringSliceSingleIndex() throws {
        let string = "Hello, World!"
        let slice = string.slice(1)

        #expect(String(slice) == "e")
    }

    @Test("String, slice, with range, returns correct substring")
    func testStringSliceRange() throws {
        let string = "Hello, World!"
        let slice = string.slice(0...4)

        #expect(String(slice) == "Hello")
    }

    @Test("String, slice, with range, handles different integer types")
    func testStringSliceRangeIntegerTypes() throws {
        let string = "Hello, World!"

        // Test with Int8
        let range: ClosedRange<Int8> = 7...11
        let slice = string.slice(range)

        #expect(String(slice) == "World")
    }
}
