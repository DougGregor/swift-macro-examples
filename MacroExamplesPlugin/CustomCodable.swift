import SwiftSyntax
import SwiftSyntaxMacros

public struct CustomCodable: MemberMacro {
  
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    
    let memberList = declaration.memberBlock.members
    
    let cases = memberList.compactMap({ member -> String? in
      // is a property
      guard
        let propertyName = member.decl.as(VariableDeclSyntax.self)?.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
        return nil
      }
      
      // if it has a CodableKey macro on it
      if let customKeyMacro = member.decl.as(VariableDeclSyntax.self)?.attributes?.first(where: { element in
        element.as(AttributeSyntax.self)?.attributeName.as(SimpleTypeIdentifierSyntax.self)?.description == "CodableKey"
      }) {
        
        // Uses the value in the Macro
        let customKeyValue = customKeyMacro.as(AttributeSyntax.self)!.argument!.as(TupleExprElementListSyntax.self)!.first!.expression
        
        return "case \(propertyName) = \(customKeyValue)"
      } else {
        return "case \(propertyName)"
      }
    })
    
    let codingKeys: DeclSyntax = """
    
      enum CodingKeys: String, CodingKey {
        \(raw: cases.joined(separator: "\n"))
      }

    """
    
    return [
      codingKeys
    ]
  }
}
