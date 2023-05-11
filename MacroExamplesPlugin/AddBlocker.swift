import SwiftSyntaxMacros
import SwiftSyntax
import SwiftOperators
import SwiftDiagnostics

/// Implementation of the `addBlocker` macro, which demonstrates how to
/// produce detailed diagnostics from a macro implementation for an utterly
/// silly task: warning about every "add" (binary +) in the argument, with a
/// Fix-It that changes it to a "-".
public struct AddBlocker: ExpressionMacro {
  class AddVisitor: SyntaxRewriter {
    var diagnostics: [Diagnostic] = []

    override func visit(
      _ node: InfixOperatorExprSyntax
    ) -> ExprSyntax {
      // Identify any infix operator + in the tree.
      if let binOp = node.operatorOperand.as(BinaryOperatorExprSyntax.self) {
        if binOp.operatorToken.text == "+" {
          // Form the warning
          let messageID = MessageID(domain: "silly", id: "addblock")
          diagnostics.append(
            Diagnostic(
              // Where the warning should go (on the "+").
              node: Syntax(node.operatorOperand),
              // The warning message and severity.
              message: SimpleDiagnosticMessage(
                message: "blocked an add; did you mean to subtract?",
                diagnosticID: messageID,
                severity: .warning
              ),
              // Highlight the left and right sides of the `+`.
              highlights: [
                Syntax(node.leftOperand),
                Syntax(node.rightOperand)
              ],
              fixIts: [
                // Fix-It to replace the '+' with a '-'.
                FixIt(
                  message: SimpleDiagnosticMessage(
                    message: "use '-'",
                    diagnosticID: messageID,
                    severity: .error
                  ),
                  changes: [
                    FixIt.Change.replace(
                      oldNode: Syntax(binOp.operatorToken),
                      newNode: Syntax(
                        TokenSyntax(
                          .binaryOperator("-"),
                          leadingTrivia: binOp.operatorToken.leadingTrivia,
                          trailingTrivia: binOp.operatorToken.trailingTrivia,
                          presence: .present
                        )
                      )
                    )
                  ]
                ),
              ]
            )
          )

          return ExprSyntax(
            node.with(
              \.operatorOperand,
              ExprSyntax(
                binOp.with(
                  \.operatorToken,
                   binOp.operatorToken.with(\.tokenKind, .binaryOperator("-"))
                )
              )
            )
          )
        }
      }

      return ExprSyntax(node)
    }
  }

  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    let visitor = AddVisitor()
    let result = visitor.visit(Syntax(node))

    for diag in visitor.diagnostics {
      context.diagnose(diag)
    }

    return result.asProtocol(FreestandingMacroExpansionSyntax.self)!.argumentList.first!.expression
  }
}
