import SwiftSyntaxMacros
import SwiftSyntax
import SwiftOperators
import SwiftDiagnostics

struct SimpleDiagnosticMessage: DiagnosticMessage, Error {
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity
}

extension SimpleDiagnosticMessage: FixItMessage {
  var fixItID: MessageID { diagnosticID }
}

public struct AddBlocker: ExpressionMacro {
  class AddVisitor: SyntaxRewriter {
    var diagnostics: [Diagnostic] = []

    override func visit(
      _ node: InfixOperatorExprSyntax
    ) -> ExprSyntax {
      if let binOp = node.operatorOperand.as(BinaryOperatorExprSyntax.self) {
        if binOp.operatorToken.text == "+" {
          let messageID = MessageID(domain: "silly", id: "addblock")
          diagnostics.append(
            Diagnostic(
              node: Syntax(node.operatorOperand),
              message: SimpleDiagnosticMessage(
                message: "blocked an add; did you mean to subtract?",
                diagnosticID: messageID,
                severity: .warning
              ),
              highlights: [
                Syntax(node.leftOperand),
                Syntax(node.rightOperand)
              ],
              fixIts: [
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
                  binOp.operatorToken.withKind(.binaryOperator("-"))
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
    guard let argument = node.argumentList.first?.expression else {
      fatalError("boom")
    }

    let visitor = AddVisitor()
    let result = visitor.visit(Syntax(node))

    for diag in visitor.diagnostics {
      context.diagnose(diag)
    }

    return result.asProtocol(FreestandingMacroExpansionSyntax.self)!.argumentList.first!.expression
  }
}
