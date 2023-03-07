import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct OptionSetItemMacro { }

extension OptionSetItemMacro: AccessorMacro {
  public static func expansion(
    of attribute: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard case let .argumentList(arguments) = attribute.argument,
        let bitArg = arguments.first(labeled: "bit"),
        let bit = bitArg.expression.as(IntegerLiteralExprSyntax.self)?.digits else {
      return []
    }

    return [
      """
      
        get {
          Self(rawValue: 1 << \(bit))
        }
      """
    ]
  }
}
