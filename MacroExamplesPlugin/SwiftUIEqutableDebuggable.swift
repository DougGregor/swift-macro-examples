import SwiftSyntax
import SwiftSyntaxMacros

public struct SwiftUIEqutableDebuggable: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let declaration = declaration.as(StructDeclSyntax.self) else {
      return []
    }

    let memberList = declaration.memberBlock.members

    let dynamicProperties = [
      "AccessibilityFocusState",
      "AppStorage",
      "EnvironmentObject",
      "FocusState",
      "FocusedObject",
      "GestureState",
      "Namespace",
      "ScaledMetric",
      "SceneStorage",
      "State",
      "StateObject"
    ]

    let dynamicPropertiesWithArgument = [
      "Environment",
      "FetchRequest",
      "FocusedValue",
      "GestureState",
      "NSApplicationDelegateAdaptor",
      "ScaledMetric",
      "SectionedFetchRequest",
    ]

    let members: [String] = memberList.compactMap {
      // is a property
      guard
        let member = $0.decl.as(VariableDeclSyntax.self)
      else {
        return nil
      }

      // is SwiftUI dynamic property
      if member.attributes?.contains(where: {
        guard let name = $0.as(AttributeSyntax.self)?.attributeName else {
          return false
        }
        if let text = name.as(SimpleTypeIdentifierSyntax.self)?.name.text, dynamicProperties.contains(text) {
          return true
        }

        if let text = name.as(SimpleTypeIdentifierSyntax.self)?.name.text, dynamicPropertiesWithArgument.contains(text) {
          return true
        }

        return false
      }) ?? false {
        return nil
      }
      guard let binding = member.bindings.first else {
        return nil
      }
      if binding.accessor?.is(CodeBlockSyntax.self) ?? false {
        return nil
      }
      let propertyName = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
      return propertyName
    }
    let typeName = declaration.identifier.text
    let equalFunction: DeclSyntax =
    """
    
    static func == (lhs: \(raw: typeName), rhs: \(raw: typeName)) -> Bool {
    #if DEBUG
        func printChange<P>(keyPath: KeyPath<\(raw: typeName), P>) where P: Equatable{
            let lhsValue = lhs[keyPath: keyPath]
            let rhsValue = rhs[keyPath: keyPath]
            if lhsValue != rhsValue {
                let description =
                \"\"\"
                \\(keyPath) changed
                    from \\(String(describing: lhsValue))
                    to \\(String(describing: rhsValue))
                \"\"\"
                print(description)
            }
        }
        \(raw: members.map {
          "printChange(keyPath: \\.\($0))"
        }.joined(separator: "\n    "))
    #endif
    
        return \(raw: members.map {
          "lhs.\($0) == rhs.\($0)"
        }.joined(separator: " && "))
    }
    """

    return [
      equalFunction
    ]
  }
}
