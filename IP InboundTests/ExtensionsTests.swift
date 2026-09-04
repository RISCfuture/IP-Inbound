import SwiftUI
import Testing

@testable import IP_Inbound

@Suite
struct `Extensions tests` {

  // MARK: - String Extensions

  @Test
  func `String, slice, with single index, returns correct substring`() throws {
    let string = "Hello, World!"
    let slice = string.slice(1)

    #expect(String(slice) == "e")
  }

  @Test
  func `String, slice, with range, returns correct substring`() throws {
    let string = "Hello, World!"
    let slice = string.slice(0...4)

    #expect(String(slice) == "Hello")
  }

  @Test
  func `String, slice, with range, handles different integer types`() throws {
    let string = "Hello, World!"

    // Test with Int8
    let range: ClosedRange<Int8> = 7...11
    let slice = string.slice(range)

    #expect(String(slice) == "World")
  }
}
