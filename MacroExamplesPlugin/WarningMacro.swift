import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

enum CustomError: Error, CustomStringConvertible {
   case message(String)

   var description: String {
     switch self {
     case .message(let text):
       return text
     }
   }
 }

 public struct WarningMacro: ExpressionMacro {
   public static func expansion(
     of macro: some FreestandingMacroExpansionSyntax,
     in context: some MacroExpansionContext
   ) throws -> ExprSyntax {
     guard let firstElement = macro.argumentList.first,
       let stringLiteral = firstElement.expression
         .as(StringLiteralExprSyntax.self),
       stringLiteral.segments.count == 1,
       case let .stringSegment(messageString)? = stringLiteral.segments.first
     else {
       throw CustomError.message("#myWarning macro requires a string literal")
     }

     context.diagnose(
       Diagnostic(
         node: Syntax(macro),
         message: SimpleDiagnosticMessage(
           message: messageString.content.description,
           diagnosticID: MessageID(domain: "test", id: "error"),
           severity: .warning
         )
       )
     )

     return "()"
   }
 }
