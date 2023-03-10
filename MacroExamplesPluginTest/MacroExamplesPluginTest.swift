import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import MacroExamplesPlugin
import XCTest

var testMacros: [String: Macro.Type] = [
  "stringify" : StringifyMacro.self,
  "OptionSet" : OptionSetMacro.self,
  "OptionSetItem" : OptionSetItemMacro.self,
]

final class MacroExamplesPluginTests: XCTestCase {
  func testStringify() {
    let sf: SourceFileSyntax =
      #"""
      let a = #stringify(x + y)
      let b = #stringify("Hello, \(name)")
      """#
    let context = BasicMacroExpansionContext.init(
      sourceFiles: [sf: .init(moduleName: "MyModule", fullFilePath: "test.swift")]
    )
    let transformedSF = sf.expand(macros: testMacros, in: context)
    XCTAssertEqual(
      transformedSF.description,
      #"""
      let a = (x + y, "x + y")
      let b = ("Hello, \(name)", #""Hello, \(name)""#)
      """#
    )
  }

  func testOptionSet() {
    let sf: SourceFileSyntax =
      """
      @OptionSet<UInt8>
      struct ShippingOptions {
        static var nextDay: ShippingOptions
        static var secondDay: ShippingOptions
        static var priority: ShippingOptions
        static var standard: ShippingOptions

        static let express: ShippingOptions = [.nextDay, .secondDay]
        static let all: ShippingOptions = [.express, .priority, .standard]

      }
      """
    let context = BasicMacroExpansionContext.init(
      sourceFiles: [sf: .init(moduleName: "MyModule", fullFilePath: "test.swift")]
    )
    let transformedSF = sf.expand(macros: testMacros, in: context)
    XCTAssertEqual(
      transformedSF.description,
      #"""

      struct ShippingOptions {
        static var nextDay: ShippingOptions {
        get {
          Self(rawValue: 1 << 0)
        }
      }
        static var secondDay: ShippingOptions {
        get {
          Self(rawValue: 1 << 1)
        }
      }
        static var priority: ShippingOptions {
        get {
          Self(rawValue: 1 << 2)
        }
      }
        static var standard: ShippingOptions {
        get {
          Self(rawValue: 1 << 3)
        }
      }

        static let express: ShippingOptions = [.nextDay, .secondDay]
        static let all: ShippingOptions = [.express, .priority, .standard]typealias RawValue = UInt8var rawValue: RawValueinit() { self.rawValue = 0 }init(rawValue: RawValue) { self.rawValue = rawValue }

      }
      """#
    )

  }
}
