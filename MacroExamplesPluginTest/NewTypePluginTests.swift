import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import MacroExamplesPlugin
import XCTest

final class NewTypePluginTests: XCTestCase {
  let testMacros: [String: Macro.Type] = [
    "NewType": NewTypeMacro.self
  ]

  func testNewType() {
    let sf: SourceFileSyntax =
      #"""
      @NewType(String.self)
      public struct MyString {
      }
      """#

    // print(sf.recursiveDescription)

    let context = BasicMacroExpansionContext(
      sourceFiles: [sf: .init(moduleName: "MyModule", fullFilePath: "test.swift")]
    )

    let transformed = sf.expand(macros: testMacros, in: context)

    // print(transformed.recursiveDescription)

    XCTAssertEqual(
      transformed.description,
      #"""

      public struct MyString {
      public typealias RawValue = String
      public var rawValue: RawValue
      public init(_ rawValue: RawValue) { self.rawValue = rawValue }
      }
      """#
    )
  }
}
