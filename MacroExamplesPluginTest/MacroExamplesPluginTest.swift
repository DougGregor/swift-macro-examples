import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import MacroExamplesPlugin
import XCTest

var testMacros: [String: Macro.Type] = [
  "stringify" : StringifyMacro.self,
  "OptionSet" : OptionSetMacro.self,
  "Bitfield" : BitfieldMacro.self,
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

  func testOptionSetWithStaticVariables() {
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
        static let all: ShippingOptions = [.express, .priority, .standard]
      typealias RawValue = UInt8
      var rawValue: RawValue
      init() { self.rawValue = 0 }
      init(rawValue: RawValue) { self.rawValue = rawValue }

      }
      """#
    )
  }

  func testOptionSetWithNestedOptionsEnum() {
    let sf: SourceFileSyntax =
      """
      @OptionSet<UInt8>
      struct ShippingOptions {
        private enum Options {
          case nextDay, secondDay
          case priority, standard
        }

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
        private enum Options {
          case nextDay, secondDay
          case priority, standard
        }

        static let express: ShippingOptions = [.nextDay, .secondDay]
        static let all: ShippingOptions = [.express, .priority, .standard]
      typealias RawValue = UInt8
      var rawValue: RawValue
      init() { self.rawValue = 0 }
      init(rawValue: RawValue) { self.rawValue = rawValue }
       static let nextDay: Self =
        Self(rawValue: 1 << Options.nextDay.rawValue)
       static let secondDay: Self =
        Self(rawValue: 1 << Options.secondDay.rawValue)
       static let priority: Self =
        Self(rawValue: 1 << Options.priority.rawValue)
       static let standard: Self =
        Self(rawValue: 1 << Options.standard.rawValue)

      }
      """#
    )
  }

  func testOptionSetWithNestedOptionSet() {
    let sf: SourceFileSyntax =
      """
      @OptionSet<UInt8>
      enum ShippingOptions {
        case nextDay, secondDay
        case priority, standard
      }
      """
    let context = BasicMacroExpansionContext.init(
      sourceFiles: [sf: .init(moduleName: "MyModule", fullFilePath: "test.swift")]
    )
    let transformedSF = sf.expand(macros: testMacros, in: context)
    XCTAssertEqual(
      transformedSF.description,
      #"""

      enum ShippingOptions {
        case nextDay, secondDay
        case priority, standard
      struct Set: OptionSet {
      typealias RawValue = UInt8
      var rawValue: RawValue
      init() { self.rawValue = 0 }
      init(rawValue: RawValue) { self.rawValue = rawValue }
       static let nextDay: Self =
        Self(rawValue: 1 << ShippingOptions.nextDay.rawValue)
       static let secondDay: Self =
        Self(rawValue: 1 << ShippingOptions.secondDay.rawValue)
       static let priority: Self =
        Self(rawValue: 1 << ShippingOptions.priority.rawValue)
       static let standard: Self =
        Self(rawValue: 1 << ShippingOptions.standard.rawValue)
      }
      }
      """#
    )
  }
}
