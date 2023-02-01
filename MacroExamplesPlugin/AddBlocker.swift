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
              Syntax(node.leftOperand.with(\.leadingTrivia, []).with(\.trailingTrivia, [])),
              Syntax(node.rightOperand.with(\.leadingTrivia, []).with(\.trailingTrivia, []))
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
                    oldNode: Syntax(binOp.operatorToken.with(\.leadingTrivia, []).with(\.trailingTrivia, [])),
                    newNode: Syntax(
                      TokenSyntax(
                        .binaryOperator("-"),
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

public struct AddBlocker: ExpressionMacro {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    guard let argument = node.argumentList.first?.expression else {
      let messageID = MessageID(domain: "example", id: "missingArg")
      throw SimpleDiagnosticMessage(message: "missing argument",
                                    diagnosticID: messageID,
                                    severity: .error)
    }

    let opTable = OperatorTable.standardOperators
    let foldedArgument = opTable.foldAll(argument) { error in
      context.diagnose(error.asDiagnostic)
    }

    // Link the folded argument back into the tree.
    let node = node.with(\.argumentList, node.argumentList.replacing(childAt: 0, with: node.argumentList.first!.with(\.expression, foldedArgument.as(ExprSyntax.self)!)))

    let visitor = AddVisitor()
    let result = visitor.visit(Syntax(node))

    for diag in visitor.diagnostics {
      context.diagnose(diag)
    }

    return result.as(MacroExpansionExprSyntax.self)!.argumentList.first!.expression
  }
}
