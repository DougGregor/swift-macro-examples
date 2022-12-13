import SwiftSyntax
import SwiftSyntaxBuilder
import _SwiftSyntaxMacros
import MacroExamplesPlugin
import XCTest

extension MacroSystem {
  static var testSystem: MacroSystem {
    var system = MacroSystem()
    try! system.add(StringifyMacro.self, name: "stringify")
    return system
  }
}

final class MacroExamplesPluginTests: XCTestCase {
  func testStringify() {
    let sf: SourceFileSyntax =
      #"""
      let a = #stringify(x + y)
      let b = #stringify("Hello, \(name)")
      """#
    var context = MacroExpansionContext(
      moduleName: "MyModule", fileName: "test.swift"
    )
    let transformedSF = MacroSystem.testSystem.evaluateMacros(
      node: sf, in: &context
    )
    XCTAssertEqual(
      transformedSF.description,
      """
      let a = (x + y, "x + y")
      let b = ("Hello, \(name)", #""Hello, \(name)""#)
      """
    )
  }
}
