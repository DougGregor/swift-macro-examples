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

// Mirrored from the library because I'm too lazy to factor it out right now
private enum OptionSetForm: Equatable {
  case staticVariables
  case nestedOptionsEnum(String = "Options")
  case nestedOptionSet(String = "Set")
}

public struct OptionSetMacro {
  /// Decode a "form:" argument to the option set macro, if present.
  private static func decodeOptionSetFormArgument(
    of attribute: AttributeSyntax,
    in context: some MacroExpansionContext
  ) -> OptionSetForm? {
    // Dig out the "form" argument, if there is one.
    guard case let .argumentList(arguments) = attribute.argument,
          let formArgument = arguments.first(labeled: "form")?.expression else {
      // No argument, this is fine.
      return nil
    }

    // If it was explicitly `nil`, then we've been asked to infer the form from
    // the structure.
    if formArgument.is(NilLiteralExprSyntax.self) {
      return nil
    }

    // If there is a call (e.g., for .nestedOptionsEnum("Flags")), dig out
    // the argument string ("Flags") and look through the call.
    let enumElement: ExprSyntax
    let callArgument: String?
    if let call = formArgument.as(FunctionCallExprSyntax.self) {
      if call.argumentList.isEmpty {
        callArgument = nil
      } else if call.argumentList.count == 1,
                let firstArg = call.argumentList.first,
                let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
                stringLiteral.segments.count == 1,
                case let .stringSegment(stringArgument)? = stringLiteral.segments.first {
        callArgument = stringArgument.content.text
      } else {
        // FIXME: Diagnose extra/wrong arguments.
        return nil
      }

      enumElement = call.calledExpression
    } else {
      callArgument = nil
      enumElement = formArgument
    }

    // Make sure we have `.<something>` or `OptionSetForm.<something>`.
    guard let memberAccess = enumElement.as(MemberAccessExprSyntax.self),
          memberAccess.base == nil ||
            memberAccess.base?.trimmedDescription == "OptionSetForm"
    else {
      // FIXME: Produce an error; we don't recognize the argument.
      return nil
    }

    switch memberAccess.name.text {
    case "staticVariables":
      return .staticVariables

    case "nestedOptionsEnum":
      return .nestedOptionsEnum(callArgument ?? "Options")

    case "nestedOptionSet":
      return .nestedOptionSet(callArgument ?? "Set")

    default:
      // FIXME: Produce an error; we don't recognize the enum case.
      return nil
    }
  }

  /// Find a nested enum with the given name in the given declaration.
  static func findNestedEnum(named: String, in decl: some DeclGroupSyntax) -> EnumDeclSyntax? {
    return decl.members.members.lazy.compactMap { member in
      if let enumDecl = member.decl.as(EnumDeclSyntax.self),
         enumDecl.identifier.text == named {
        return enumDecl
      }

      return nil
    }.first
  }

  /// Infer the form of the option set from from declaration to which the
  /// option set macro is attached.
  private static func inferOptionSetForm(_ decl: some DeclGroupSyntax) -> OptionSetForm? {
    // If the macro is attached to an enum, produce a nested option set struct.
    if decl.is(EnumDeclSyntax.self) {
      return .nestedOptionSet()
    }

    // If the macro is attached to something other than a struct, we can't
    // infer anything.
    guard let structDecl = decl.as(StructDeclSyntax.self) else {
      return nil
    }

    // If there is a nested "Options" enum, use it.
    if let _ = findNestedEnum(named: "Options", in: structDecl) {
      return .nestedOptionsEnum()
    }

    // If there is at least one static variable that meets the criteria, we
    // can update static variables.
    for member in structDecl.members.members {
      if let varDecl = member.decl.as(VariableDeclSyntax.self),
         let _ = varDecl.getOptionSetItemCandidateName(structName: structDecl.identifier) {
        return .staticVariables
      }
    }

    // There isn't enough structure to infer the form of the option set.
    return nil
  }

  /// Decodes the arguments to the macro expansion.
  ///
  /// - Returns: the important arguments used by the various roles of this
  /// macro inhabits, or nil if an error occurred.
  fileprivate static func decodeExpansion(
    of attribute: AttributeSyntax,
    attachedTo decl: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) -> (TypeSyntax, OptionSetForm)? {
    // Only apply to structs.
    // Retrieve the raw type from the attribute.
    guard let genericArgs = attribute.attributeName.as(SimpleTypeIdentifierSyntax.self)?.genericArgumentClause,
          let rawType = genericArgs.arguments.first?.argumentType else {
      context.diagnose(OptionSetMacroDiagnostic.requiresOptionsEnumRawType.diagnose(at: attribute))
      return nil
    }

    let form: OptionSetForm
    if let specifiedForm = decodeOptionSetFormArgument(of: attribute, in: context) {
      form = specifiedForm
    } else if let inferredForm = inferOptionSetForm(decl) {
      form = inferredForm
    } else {
      // FIXME: produce an error
      return nil
    }

    return (rawType, form)
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
      return nil
    }

    guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
      return nil
    }

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
    //
    // The member-attribute expansion of the OptionSet macro only applies to the static-variables
    // form of the option set, where the static variables already exist and need to be
    // annotated with the appropriate `@Bitfield` attribute.
    guard let (_, form) = decodeExpansion(of: attribute, attachedTo: declaration, in: context),
          form == .staticVariables,
          let structDecl = declaration.as(StructDeclSyntax.self) else {
      return []
    }

    // Make sure this is an option set item candidate.
    guard let property = member.as(VariableDeclSyntax.self),
          let propertyName = property.getOptionSetItemCandidateName(structName: structDecl.identifier)
    else {
      return []
    }

    // Count how many item candidates occurred before this one.
    var bit: Int = 0
    var found: Bool = false
    for otherMember in declaration.members.members {
      // Only consider the option set item candidates.
      guard let otherProperty = otherMember.decl.as(VariableDeclSyntax.self),
            let otherPropertyName = otherProperty.getOptionSetItemCandidateName(structName: structDecl.identifier) else {
        continue
      }

      if propertyName.text == otherPropertyName.text {
        found = true
        break
      }

      bit += 1
    }

    // If we did not find our member in the list, fail. This could happen
    // if the item came from another macro expansion.
    if !found {
      context.diagnose(
        OptionSetMacroDiagnostic.itemInMacroExpansion.diagnose(at: property))
      return []
    }

    return ["@Bitfield(bit: \(literal: bit))"]
  }
}

extension OptionSetMacro: ConformanceMacro {
  public static func expansion(
    of attribute: AttributeSyntax,
    providingConformancesOf decl: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [(TypeSyntax, GenericWhereClauseSyntax?)] {
    // Decode the expansion arguments.
    //
    // The conformance expansion is only relevant to the nested-options-enum
    // and static-variables forms, which add the conformance. In both cases,
    // we are dealing with a struct.
    guard let (_, form) = decodeExpansion(of: attribute, attachedTo: decl, in: context),
          let structDecl = decl.as(StructDeclSyntax.self) else {
      return []
    }

    switch form {
    case .nestedOptionSet:
      // The nested option set form doesn't add any conformances; the conformance
      // is on the inner type.
      return []

    case .nestedOptionsEnum, .staticVariables:
      break
    }

    // If there is an explicit conformance to OptionSet already, don't add one.
    if let inheritedTypes = structDecl.inheritanceClause?.inheritedTypeCollection,
       inheritedTypes.contains(where: { inherited in inherited.typeName.trimmedDescription == "OptionSet" }) {
      return []
    }

    return [("OptionSet", nil)]
  }
}

extension EnumDeclSyntax {
  /// Retrieve a flattened set of all of the case elements in the enum.
  var allCaseElements: [EnumCaseElementSyntax] {
    return members.members.flatMap { member in
      guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
        return Array<EnumCaseElementSyntax>()
      }

      return Array(caseDecl.elements)
    }
  }
}

extension OptionSetMacro: MemberMacro {
  /// Create the set of static variables that provided the option values, using the
  /// cases of the given enum as input.
  private static func makeStaticVariables(
    forCasesOf enumDecl: EnumDeclSyntax,
    access: ModifierListSyntax.Element?
  ) -> [DeclSyntax] {
    let allCases = enumDecl.allCaseElements
    return allCases.map { (element) -> DeclSyntax in
      """
      
      \(access) static let \(element.identifier.trimmed): Self =
        Self(rawValue: 1 << \(enumDecl.identifier.trimmed).\(element.identifier).rawValue)
      """
    }
  }

  public static func expansion(
    of attribute: AttributeSyntax,
    providingMembersOf decl: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Decode the expansion arguments.
    guard let (rawType, form) = decodeExpansion(of: attribute, attachedTo: decl, in: context) else {
      return []
    }

    // Dig out the access control keyword we need.
    let access = decl.modifiers?.first(where: \.isNeededAccessLevelModifier)

    // Across all forms, the raw value members are the same.
    // FIXME: We should filter out any of these that were already provided.
    let rawValueMembers: [DeclSyntax] = [
      "\n\(access)typealias RawValue = \(rawType)",
      "\n\(access)var rawValue: RawValue",
      "\n\(access)init() { self.rawValue = 0 }",
      "\n\(access)init(rawValue: RawValue) { self.rawValue = rawValue }",
    ]

    switch form {
    case .staticVariables:
      // When annotating static variables, we only need the raw-value members.
      // Everything else has already been declared.
      return rawValueMembers

    case .nestedOptionsEnum(let optionsSetEnumName):
      guard let optionSetEnum = findNestedEnum(named: optionsSetEnumName, in: decl) else {
        // FIXME: Diagnose missing option enum
        return rawValueMembers
      }

      return rawValueMembers + makeStaticVariables(forCasesOf: optionSetEnum, access: access)

    case .nestedOptionSet(_):
      guard let enumDecl = decl.as(EnumDeclSyntax.self) else {
        // FIXME: Diagnose not-on-an-enum
        return rawValueMembers
      }

      return [
        """
        
        \(access)struct Set: OptionSet {\(raw: (rawValueMembers + makeStaticVariables(forCasesOf: enumDecl, access: access)).map {
            $0.description
          }.joined(separator: ""))
        }
        """
      ]
    }
  }
}
