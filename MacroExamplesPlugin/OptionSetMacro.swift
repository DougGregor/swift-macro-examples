import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum OptionSetMacroDiagnostic {
  case requiresStruct
  case requiresStringLiteral(String)
  case requiresOptionsEnum(String)
  case requiresOptionsEnumRawType
  case itemInMacroExpansion
}

extension OptionSetMacroDiagnostic: DiagnosticMessage {
  func diagnose(at node: some SyntaxProtocol) -> Diagnostic {
    Diagnostic(node: Syntax(node), message: self)
  }

  var message: String {
    switch self {
    case .requiresStruct:
      return "'OptionSet' macro can only be applied to a struct"

    case .requiresStringLiteral(let name):
      return "'OptionSet' macro argument \(name) must be a string literal"

    case .requiresOptionsEnum(let name):
      return "'OptionSet' macro requires nested options enum '\(name)'"

    case .requiresOptionsEnumRawType:
      return "'OptionSet' macro requires a raw type"

    case .itemInMacroExpansion:
      return "'OptionSet' item cannot occur as a result of macro expansion"
    }
  }

  var severity: DiagnosticSeverity { .error }

  var diagnosticID: MessageID {
    MessageID(domain: "Swift", id: "OptionSet.\(self)")
  }
}


/// The label used for the OptionSet macro argument that provides the name of
/// the nested options enum.
private let optionsEnumNameArgumentLabel = "optionsName"

extension TupleExprElementListSyntax {
  /// Retrieve the first element with the given label.
  func first(labeled name: String) -> Element? {
    return first { element in
      if let label = element.label, label.text == name {
        return true
      }

      return false
    }
  }
}

public struct OptionSetMacro {
  /// Decodes the arguments to the macro expansion.
  ///
  /// - Returns: the important arguments used by the various roles of this
  /// macro inhabits, or nil if an error occurred.
  static func decodeExpansion(
    of attribute: AttributeSyntax,
    attachedTo decl: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) -> (StructDeclSyntax, TypeSyntax)? {
    // Only apply to structs.
    guard let structDecl = decl.as(StructDeclSyntax.self) else {
      context.diagnose(OptionSetMacroDiagnostic.requiresStruct.diagnose(at: decl))
      return nil
    }

    // Retrieve the raw type from the attribute.
    guard let genericArgs = attribute.attributeName.as(SimpleTypeIdentifierSyntax.self)?.genericArgumentClause,
          let rawType = genericArgs.arguments.first?.argumentType else {
      context.diagnose(OptionSetMacroDiagnostic.requiresOptionsEnumRawType.diagnose(at: attribute))
      return nil
    }


    return (structDecl, rawType)
  }
}

extension VariableDeclSyntax {
  /// Determine whether this variable has the syntax of a stored property.
  ///
  /// This syntactic check cannot account for semantic adjustments due to,
  /// e.g., accessor macros or property wrappers.
  func getOptionSetItemCandidateName(structName: TokenSyntax) -> TokenSyntax? {
    if bindings.count != 1 {
      return nil
    }

    // Make sure this is a static variable.
    guard let _ = modifiers?.first(where: {
      return $0.name.tokenKind == .keyword(.static)
    }) else {
      return nil
    }

    // If there is an initializer, do nothing.
    let binding = bindings.first!
    if binding.initializer != nil {
      print("\(self) -- Has initializer")
      return nil
    }

    // Make sure there are no non-observing getters.
    switch binding.accessor {
    case .none:
      break

    case .accessors(let node):
      for accessor in node.accessors {
        switch accessor.accessorKind.tokenKind {
        case .keyword(.willSet), .keyword(.didSet):
          // Observers can occur on a stored property.
          break

        default:
          // Other accessors make it a computed property.
          return nil
        }
      }
      break

    case .getter:
      return nil

    @unknown default:
      return nil
    }

    // Make sure the type is either Self or the struct.
    guard let type = binding.typeAnnotation?.type,
          type.trimmed.description == "Self" ||
            type.trimmed.description == structName.text else {
      print("\(self) -- wrong type \(binding.typeAnnotation?.description)")
      return nil
    }

    guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
      print("\(self) -- No identifier pattern")
      return nil
    }
    print("\(self) -- Yay: \(identifier)")

    return identifier
  }
}

extension OptionSetMacro: MemberAttributeMacro {
  public static func expansion(
    of attribute: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingAttributesFor member: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AttributeSyntax] {
    // Decode the expansion arguments.
    guard let (structDecl, _) = decodeExpansion(of: attribute, attachedTo: declaration, in: context) else {
      return []
    }

    // Make sure this is an option set item candidate.
    guard let property = member.as(VariableDeclSyntax.self),
          let propertyName = property.getOptionSetItemCandidateName(structName: structDecl.identifier)
    else {
      if member.is(VariableDeclSyntax.self) {
        print(member.recursiveDescription)
      }
      return []
    }

    // Count how many item candidates occurred before this one.
    var bit: Int = 0
    var found: Bool = false
    for otherMember in declaration.members.members {
      // Only consider the option set item candidates.
      guard let otherProperty = otherMember.decl.as(VariableDeclSyntax.self),
            let otherPropertyName = otherProperty.getOptionSetItemCandidateName(structName: structDecl.identifier) else {
        print("- skipping \(otherMember)")
        continue
      }

      if propertyName.text == otherPropertyName.text {
        print("- found \(otherMember)")
        found = true
        break
      }

      bit += 1
    }

    // If we did not found our member in the list, fail. This could happen
    // if the item came from another macro expansion.
    if !found {
      print("- COULD NOT FIND \(property)")
      context.diagnose(
        OptionSetMacroDiagnostic.itemInMacroExpansion.diagnose(at: property))
      return []
    }

    fatalError("Found it! Annotating \(property)")

    return ["@OptionSetItem(bit: \(literal: bit))"]
  }
}

extension OptionSetMacro: ConformanceMacro {
  public static func expansion(
    of attribute: AttributeSyntax,
    providingConformancesOf decl: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [(TypeSyntax, GenericWhereClauseSyntax?)] {
    // Decode the expansion arguments.
    guard let (structDecl, _) = decodeExpansion(of: attribute, attachedTo: decl, in: context) else {
      return []
    }

    // If there is an explicit conformance to OptionSet already, don't add one.
    if let inheritedTypes = structDecl.inheritanceClause?.inheritedTypeCollection,
       inheritedTypes.contains(where: { inherited in inherited.typeName.trimmedDescription == "OptionSet" }) {
      return []
    }

    return [("OptionSet", nil)]
  }
}

extension OptionSetMacro: MemberMacro {
  public static func expansion(
    of attribute: AttributeSyntax,
    providingMembersOf decl: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Decode the expansion arguments.
    guard let (_, rawType) = decodeExpansion(of: attribute, attachedTo: decl, in: context) else {
      return []
    }

    // Dig out the access control keyword we need.
    let access = decl.modifiers?.first(where: \.isNeededAccessLevelModifier)

    return [
      "\(access)typealias RawValue = \(rawType)",
      "\(access)var rawValue: RawValue",
      "\(access)init() { self.rawValue = 0 }",
      "\(access)init(rawValue: RawValue) { self.rawValue = rawValue }",
    ]
  }
}
