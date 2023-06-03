import XCTest
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import MacroExamplesPlugin


final class SwiftUIEqutableDebuggableTest: XCTestCase {
  let testMacros: [String: Macro.Type] = [
    "SwiftUIEqutableDebuggable": SwiftUIEqutableDebuggable.self
  ]

  func testBasic() throws {
    let sf: SourceFileSyntax =
      """
      @SwiftUIEqutableDebuggable
      struct TestView: View {
        @State var state1 = 0
        @Environment(\\.colorScheme) var env1

        let date = Date()
        let intValue = 1

        var body: some View {
          EmptyView()
        }
      }
      """

    let context = BasicMacroExpansionContext(
      sourceFiles: [sf: .init(moduleName: "MyModule", fullFilePath: "test.swift")]
    )

    let transformed = sf.expand(macros: testMacros, in: context)
    let diffleft = transformed.description
    let diffright =
        #"""
        struct TestView: View {
          @State var state1 = 0
          @Environment(\.colorScheme) var env1

          let date = Date()
          let intValue = 1

          var body: some View {
            EmptyView()
          }
        static func == (lhs: TestView, rhs: TestView) -> Bool {
        #if DEBUG
            func printChange<P>(keyPath: KeyPath<TestView, P>) where P: Equatable{
                let lhsValue = lhs[keyPath: keyPath]
                let rhsValue = rhs[keyPath: keyPath]
                if lhsValue != rhsValue {
                    let description =
                    """
                    \(keyPath) changed
                        from \(String(describing: lhsValue))
                        to \(String(describing: rhsValue))
                    """
                    print(description)
                }
            }
            printChange(keyPath: \.date)
            printChange(keyPath: \.intValue)
        #endif

            return lhs.date == rhs.date && lhs.intValue == rhs.intValue
        }
        }
        """#
    let lineLeft = diffleft.split(separator: "\n")
    let lineRight = diffright.split(separator: "\n")
    for index in 0..<lineLeft.count {
      XCTAssertEqual(lineLeft[index], lineRight[index])
    }
  }
}
