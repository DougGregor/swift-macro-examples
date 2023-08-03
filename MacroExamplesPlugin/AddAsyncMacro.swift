import SwiftSyntax
import SwiftSyntaxMacros

extension SyntaxCollection {
  mutating func removeLast() {
    self.remove(at: self.index(before: self.endIndex))
  }
}

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
    if funcDecl.signature.returnClause?.type.with(\.leadingTrivia, []).with(\.trailingTrivia, []).description != "Void" {
      throw CustomError.message(
        "@addAsync requires an function that returns void"
      )
    }
    
    // Requires a completion handler block as last parameter
    guard let completionHandlerParameterAttribute = funcDecl.signature.parameterClause.parameters.last?.type.as(AttributedTypeSyntax.self),
    let completionHandlerParameter = completionHandlerParameterAttribute.baseType.as(FunctionTypeSyntax.self) else {
      throw CustomError.message(
        "@addAsync requires an function that has a completion handler as last parameter"
      )
    }
    
    // Completion handler needs to return Void
    if completionHandlerParameter.returnClause.type.with(\.leadingTrivia, []).with(\.trailingTrivia, []).description != "Void" {
      throw CustomError.message(
        "@addAsync requires an function that has a completion handler that returns Void"
      )
    }
    
    let returnType = completionHandlerParameter.parameters.first?.type
    
    let isResultReturn = returnType?.children(viewMode: .all).first?.description == "Result"
    let successReturnType = isResultReturn ? returnType!.as(IdentifierTypeSyntax.self)!.genericArgumentClause?.arguments.first!.argument : returnType
    
    // Remove completionHandler and comma from the previous parameter
    var newParameterList = funcDecl.signature.parameterClause.parameters
    newParameterList.removeLast()
    let newParameterListLastParameter = newParameterList.last!
    newParameterList.removeLast()
    newParameterList.append(newParameterListLastParameter.with(\.trailingTrivia, []).with(\.trailingComma, nil))

    
    // Drop the @addAsync attribute from the new declaration.
    let newAttributeList = AttributeListSyntax(
      funcDecl.attributes?.filter {
        guard case let .attribute(attribute) = $0,
              let attributeType = attribute.attributeName.as(IdentifierTypeSyntax.self),
              let nodeType = node.attributeName.as(IdentifierTypeSyntax.self)
        else {
          return true
        }
        
        return attributeType.name.text != nodeType.name.text
      } ?? []
    )
    
    let callArguments: [String] = newParameterList.map { param in
      let argName = param.secondName ?? param.firstName
      
      let paramName = param.firstName
      if paramName.text != "_" {
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
          \(funcDecl.name)(\(raw: callArguments.joined(separator: ", "))) { \(returnType != nil ? "returnValue in" : "")
        
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
             FunctionEffectSpecifiersSyntax(leadingTrivia: .space, asyncSpecifier: "async", throwsSpecifier: isResultReturn ? " throws" : nil)  // add async
          )
          .with(\.returnClause, successReturnType != nil ? ReturnClauseSyntax(leadingTrivia: .space, type: successReturnType!.with(\.leadingTrivia, .space)) : nil)  // add result type
          .with(
            \.parameterClause,
             funcDecl.signature.parameterClause.with(\.parameters, newParameterList) // drop completion handler
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



