import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct AddCompletionHandlerMacro: PeerMacro {
  public static func expansion<
    Context: MacroExpansionContext,
    Declaration: DeclSyntaxProtocol
  >(
    of node: AttributeSyntax,
    providingPeersOf declaration: Declaration,
    in context: Context
  ) throws -> [DeclSyntax] {
    // Only on functions at the moment. We could handle initializers as well
    // with a bit of work.
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      throw CustomError.message("@addCompletionHandler only works on functions")
    }

    // This only makes sense for async functions.
    if funcDecl.signature.effectSpecifiers?.asyncSpecifier == nil {
      let newEffects: FunctionEffectSpecifiersSyntax
      if let existingEffects = funcDecl.signature.effectSpecifiers {
        newEffects = existingEffects.with(\.asyncSpecifier, "async ")
      } else {
        newEffects = FunctionEffectSpecifiersSyntax(asyncSpecifier: "async ")
      }

      let newSignature = funcDecl.signature.with(\.effectSpecifiers, newEffects)
      let messageID = MessageID(domain: "MacroExamples", id: "MissingAsync")

      let diag = Diagnostic(
        // Where the error should go (on the "+").
        node: Syntax(funcDecl.funcKeyword),
        // The warning message and severity.
        message: SimpleDiagnosticMessage(
          message: "can only add a completion-handler variant to an 'async' function",
          diagnosticID: messageID,
          severity: .error
        ),
        fixIts: [
          // Fix-It to replace the '+' with a '-'.
          FixIt(
            message: SimpleDiagnosticMessage(
              message: "add 'async'",
              diagnosticID: messageID,
              severity: .error
            ),
            changes: [
              FixIt.Change.replace(
                oldNode: Syntax(funcDecl.signature),
                newNode: Syntax(newSignature)
              )
            ]
          ),
        ]
      )

      context.diagnose(diag)
      return []
    }

    // Form the completion handler parameter.
    let resultType: TypeSyntax? = funcDecl.signature.output?.returnType.with(\.leadingTrivia, []).with(\.trailingTrivia, [])

    let completionHandlerParam =
      FunctionParameterSyntax(
        firstName: .identifier("completionHandler"),
        colon: .colonToken(trailingTrivia: .space),
        type: "@escaping (\(resultType ?? "")) -> Void" as TypeSyntax
      )

    // Add the completion handler parameter to the parameter list.
    let parameterList = funcDecl.signature.input.parameterList
    let newParameterList: FunctionParameterListSyntax
    if let lastParam = parameterList.last {
      // We need to add a trailing comma to the preceding list.
      newParameterList = parameterList.removingLast()
        .appending(
          lastParam.with(
            \.trailingComma,
            .commaToken(trailingTrivia: .space)
          )
        )
        .appending(completionHandlerParam)
    } else {
      newParameterList = parameterList.appending(completionHandlerParam)
    }

    let callArguments: [String] = parameterList.map { param in
      let argName = param.secondName ?? param.firstName

      let paramName = param.firstName
      if paramName.text != "_" {
        return "\(paramName.text): \(argName.text)"
      }

      return "\(argName.text)"
    }

    let call: ExprSyntax =
      "\(funcDecl.identifier)(\(raw: callArguments.joined(separator: ", ")))"

    // FIXME: We should make CodeBlockSyntax ExpressibleByStringInterpolation,
    // so that the full body could go here.
    let newBody: ExprSyntax =
      """

        Task {
          completionHandler(await \(call))
        }

      """

    // Drop the @addCompletionHandler attribute from the new declaration.
    let newAttributeList = AttributeListSyntax(
      funcDecl.attributes?.filter {
        guard case let .attribute(attribute) = $0,
              let attributeType = attribute.attributeName.as(SimpleTypeIdentifierSyntax.self),
              let nodeType = node.attributeName.as(SimpleTypeIdentifierSyntax.self)
        else {
          return true
        }

        return attributeType.name.text != nodeType.name.text
      } ?? []
    )

    let newFunc =
      funcDecl
      .with(
        \.signature,
        funcDecl.signature
          .with(
            \.effectSpecifiers,
            funcDecl.signature.effectSpecifiers?.with(\.asyncSpecifier, nil)  // drop async
          )
          .with(\.output, nil)  // drop result type
          .with(
            \.input,  // add completion handler parameter
            funcDecl.signature.input.with(\.parameterList, newParameterList)
              .with(\.trailingTrivia, [])
          )
      )
      .with(
        \.body,
        CodeBlockSyntax(
          leftBrace: .leftBraceToken(leadingTrivia: .space),
          statements: CodeBlockItemListSyntax(
            [CodeBlockItemSyntax(item: .expr(newBody))]
          ),
          rightBrace: .rightBraceToken(leadingTrivia: .newline)
        )
      )
      .with(\.attributes, newAttributeList)
      .with(\.leadingTrivia, .newlines(2))

    return [DeclSyntax(newFunc)]
  }
}

