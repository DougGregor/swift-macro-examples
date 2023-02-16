import SwiftSyntax
import SwiftSyntaxMacros


public struct AddAsyncMacro: PeerMacro {
  public static func expansion<
    Context: MacroExpansionContext,
    Declaration: DeclSyntaxProtocol
  >(
    of node: AttributeSyntax,
    providingPeersOf declaration: Declaration,
    in context: Context
  ) throws -> [DeclSyntax] {
  
    // Only on functions at the moment.
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      throw CustomError.message("@addAsync only works on functions")
    }
    
    // This only makes sense for non async functions.
    if funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil {
      throw CustomError.message(
        "@addAsync requires an non async function"
      )
    }
    
    // This only makes sense void functions
    if funcDecl.signature.output?.returnType.with(\.leadingTrivia, []).with(\.trailingTrivia, []).description != "Void" {
      throw CustomError.message(
        "@addAsync requires an function that returns void"
      )
    }
    
    // Requires a completion handler block as last parameter
    guard let completionHandlerParameterAttribute = funcDecl.signature.input.parameterList.last?.type?.as(AttributedTypeSyntax.self),
    let completionHandlerParameter = completionHandlerParameterAttribute.baseType.as(FunctionTypeSyntax.self) else {
      throw CustomError.message(
        "@addAsync requires an function that has a completion handler as last parameter"
      )
    }
    
    // Completion handler needs to return Void
    if completionHandlerParameter.output.returnType.with(\.leadingTrivia, []).with(\.trailingTrivia, []).description != "Void" {
      throw CustomError.message(
        "@addAsync requires an function that has a completion handler that returns Void"
      )
    }
    
    let returnType = completionHandlerParameter.arguments.first?.type
    
    let isResultReturn = returnType?.children(viewMode: .all).first?.description == "Result"
    let successReturnType = isResultReturn ? returnType!.as(SimpleTypeIdentifierSyntax.self)!.genericArgumentClause?.arguments.first!.argumentType : returnType
    
    // Remove completionHandler and comma from the previous parameter
    var newParameterList = funcDecl.signature.input.parameterList.removingLast()
    let newParameterListLastParameter = newParameterList.last!
    newParameterList = newParameterList.removingLast()
    newParameterList = newParameterList.appending(newParameterListLastParameter.with(\.trailingTrivia, []).with(\.trailingComma, nil))
    
    
    // Drop the @addAsync attribute from the new declaration.
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
    
    let callArguments: [String] = try newParameterList.map { param in
      guard let argName = param.secondName ?? param.firstName else {
        throw CustomError.message(
          "@addAsync argument must have a name"
        )
      }
      
      if let paramName = param.firstName, paramName.text != "_" {
        return "\(paramName.text): \(argName.text)"
      }
      
      return "\(argName.text)"
    }
    
    let switchBody: ExprSyntax =
    """
      switch returnValue {
      case .success(let value):
          continuation.resume(returning: value)
      case .failure(let error):
          continuation.resume(throwing: error)
      }
    """

    let newBody: ExprSyntax =
      """
      
        \(isResultReturn ? "try await withCheckedThrowingContinuation { continuation in" : "await withCheckedContinuation { continuation in")
          \(funcDecl.identifier)(\(raw: callArguments.joined(separator: ", "))) { \(returnType != nil ? "returnValue in" : "")
        
          \(isResultReturn ? switchBody : "continuation.resume(returning: \(returnType != nil ? "returnValue" : "()"))")
            
          }
        }
      
      """

    let newFunc =
    funcDecl
      .with(
        \.signature,
         funcDecl.signature
          .with(
            \.effectSpecifiers,
             DeclEffectSpecifiersSyntax(leadingTrivia: .space, asyncSpecifier: "async", throwsSpecifier: isResultReturn ? " throws" : nil)  // add async
          )
          .with(\.output, successReturnType != nil ? ReturnClauseSyntax(leadingTrivia: .space, returnType: successReturnType!.with(\.leadingTrivia, .space)) : nil)  // add result type
          .with(
            \.input,
             funcDecl.signature.input.with(\.parameterList, newParameterList) // drop completion handler
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



