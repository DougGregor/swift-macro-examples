import XCTest
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import MacroExamplesPlugin

final class InitMacroTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "PublicInit" : PublicInitMacro.self,
        "InternalInit" : InternalInitMacro.self,
    ]

    func testEmpty() {
        assertMacroExpansion(
                """
                @PublicInit
                struct MyStruct {}
                """,
                expandedSource: """

                struct MyStruct {
                    public init() {
                    }
                }
                """,
                macros: testMacros
        )
    }

    func testInternal() {
        assertMacroExpansion(
                """
                @InternalInit
                struct MyStruct {}
                """,
                expandedSource: """

                struct MyStruct {
                    init() {
                    }
                }
                """,
                macros: testMacros
        )
    }

    func testStruct() {
        assertMacroExpansion(
                """
                @PublicInit
                struct MyStruct {
                    let firstParam: String
                    let secondParam: Int
                }
                """,
                expandedSource: """

                struct MyStruct {
                    let firstParam: String
                    let secondParam: Int
                    public init(firstParam: String, secondParam: Int) {
                        self.firstParam = firstParam
                        self.secondParam = secondParam
                    }
                }
                """,
                macros: testMacros
        )
    }

    func testClass() {
        assertMacroExpansion(
                """
                @PublicInit
                class MyClass {
                    let firstParam: String
                    let secondParam: Int
                }
                """,
                expandedSource: """

                class MyClass {
                    let firstParam: String
                    let secondParam: Int
                    public init(firstParam: String, secondParam: Int) {
                        self.firstParam = firstParam
                        self.secondParam = secondParam
                    }
                }
                """,
                macros: testMacros
        )
    }

    func testDefaultArgumentLet() {
        assertMacroExpansion(
                """
                @PublicInit
                class MyClass {
                    let value: Float = 0
                }
                """,
                expandedSource: """

                class MyClass {
                    let value: Float = 0
                    public init() {
                    }
                }
                """,
                macros: testMacros
        )
    }

    func testDefaultArgumentVar() {
        assertMacroExpansion(
                """
                @PublicInit
                class MyClass {
                    var value: Float = 0
                }
                """,
                expandedSource: """

                class MyClass {
                    var value: Float = 0
                    public init(value: Float = 0) {
                        self.value = value
                    }
                }
                """,
                macros: testMacros
        )
    }

    func testLazyVar() {
        assertMacroExpansion(
                """
                @PublicInit
                class MyClass {
                    lazy var value: Int = 0
                }
                """,
                expandedSource: """

                class MyClass {
                    lazy var value: Int = 0
                    public init() {
                    }
                }
                """,
                macros: testMacros
        )
    }

    func testComputedProperty() {
        assertMacroExpansion(
                """
                @PublicInit
                class MyClass {
                    var value: Int {
                        return 0
                    }
                }
                """,
                expandedSource: """

                class MyClass {
                    var value: Int {
                        return 0
                    }
                    public init() {
                    }
                }
                """,
                macros: testMacros
        )
    }

    func testPropertyWrapper() {
        assertMacroExpansion(
                """
                @PublicInit
                struct MyView {
                    @State var isOn: Bool
                }
                """,
                expandedSource: """

                struct MyView {
                    @State var isOn: Bool
                    public init() {
                    }
                }
                """,
                macros: testMacros
        )
    }

    func testEnum() {
        assertMacroExpansion(
                """
                @PublicInit
                enum MyEnum {
                    case some
                }
                """,
                expandedSource: """

                enum MyEnum {
                    case some
                }
                """,

                diagnostics: [.init(message: "@PublicInit can only be applied to struct or class", line: 1, column: 1)],
                macros: testMacros
        )
    }
}
