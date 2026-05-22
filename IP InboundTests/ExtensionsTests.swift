import SwiftUI
import Testing

@testable import IP_Inbound

@Suite("Extensions")
struct ExtensionsTests {

  // MARK: - String Extensions

  @Test("String, slice, with single index, returns correct substring")
  func stringSliceSingleIndex() throws {
    let string = "Hello, World!"
    let slice = string.slice(1)

    #expect(String(slice) == "e")
  }

  @Test("String, slice, with range, returns correct substring")
  func stringSliceRange() throws {
    let string = "Hello, World!"
    let slice = string.slice(0...4)

    #expect(String(slice) == "Hello")
  }

  @Test("String, slice, with range, handles different integer types")
  func stringSliceRangeIntegerTypes() throws {
    let string = "Hello, World!"

    // Test with Int8
    let range: ClosedRange<Int8> = 7...11
    let slice = string.slice(range)

    #expect(String(slice) == "World")
  }
}
