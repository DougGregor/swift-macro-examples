import XCTest
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import MacroExamplesPlugin

final class CaseMacroTests: XCTestCase {
  let testMacros: [String: Macro.Type] = [
    "MetaEnum": MetaEnumMacro.self
  ]

  func testBasic() throws {
    let sf: SourceFileSyntax = """
      @MetaEnum enum Cell {
        case integer(Int)
        case text(String)
        case boolean(Bool)
        case null
      }
      """

    let context = BasicMacroExpansionContext(
      sourceFiles: [sf: .init(moduleName: "MyModule", fullFilePath: "test.swift")]
    )

    let transformed = sf.expand(macros: testMacros, in: context)
    XCTAssertEqual(transformed.description, """
        enum Cell {
          case integer(Int)
          case text(String)
          case boolean(Bool)
          case null
          enum Meta {
            case integer
            case text
            case boolean
            case null

            init(_ __macro_local_6parentfMu_: Cell) {
              switch __macro_local_6parentfMu_ {
              case .integer:
                self = .integer
              case .text:
                self = .text
              case .boolean:
                self = .boolean
              case .null:
                self = .null
              }
            }
          }
        }
        """)
  }

  func testPublic() throws {
    let sf: SourceFileSyntax = """
      @MetaEnum public enum Cell {
        case integer(Int)
        case text(String)
        case boolean(Bool)
      }
      """

    let context = BasicMacroExpansionContext(
      sourceFiles: [sf: .init(moduleName: "MyModule", fullFilePath: "test.swift")]
    )

    let transformed = sf.expand(macros: testMacros, in: context)
    XCTAssertEqual(transformed.description, """
        public enum Cell {
          case integer(Int)
          case text(String)
          case boolean(Bool)
          public enum Meta {
            case integer
            case text
            case boolean

            public init(_ __macro_local_6parentfMu_: Cell) {
              switch __macro_local_6parentfMu_ {
              case .integer:
                self = .integer
              case .text:
                self = .text
              case .boolean:
                self = .boolean
              }
            }
          }
        }
        """)
  }

  func testNonEnum() throws {
    let sf: SourceFileSyntax = """
      @MetaEnum struct Cell {
        let integer: Int
        let text: String
        let boolean: Bool
      }
      """

    let context = BasicMacroExpansionContext(
      sourceFiles: [sf: .init(moduleName: "MyModule", fullFilePath: "test.swift")]
    )

    let transformed = sf.expand(macros: testMacros, in: context)
    XCTAssertEqual(transformed.description, """
      struct Cell {
        let integer: Int
        let text: String
        let boolean: Bool
      }
      """)

    XCTAssertEqual(context.diagnostics.count, 1)
    let diag = try XCTUnwrap(context.diagnostics.first)
    XCTAssertEqual(diag.message, "'@MetaEnum' can only be attached to an enum, not a struct")
    XCTAssertEqual(diag.diagMessage.severity, .error)
  }
}
