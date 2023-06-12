import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import MacroExamplesPlugin
import XCTest

var testMacros: [String: Macro.Type] = [
  "stringify" : StringifyMacro.self,
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

  func testURL() throws {
    let sf: SourceFileSyntax =
        #"""
        let invalid = #URL("not a url")
        let valid = #URL("https://swift.org/")
        """#
    let context = BasicMacroExpansionContext.init(
      sourceFiles: [sf: .init(moduleName: "MyModule", fullFilePath: "test.swift")]
    )
    let transformedSF = sf.expand(macros: ["URL" : URLMacro.self], in: context)
    XCTAssertEqual(
      transformedSF.description,
        #"""
        let invalid = #URL("not a url")
        let valid = URL(string: "https://swift.org/")!
        """#
    )
    XCTAssertEqual(context.diagnostics.count, 1)
    let diagnostic = try XCTUnwrap(context.diagnostics.first)
    XCTAssertEqual(diagnostic.message, #"malformed url: "not a url""#)
    XCTAssertEqual(diagnostic.diagMessage.severity, .error)
  }
}
