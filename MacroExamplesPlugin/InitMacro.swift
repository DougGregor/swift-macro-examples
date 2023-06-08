import SwiftSyntaxMacros
import SwiftSyntax

enum PublicInitError: CustomStringConvertible, Error {
    case onlyApplicableToStructOrClass

    var description: String {
        switch self {
        case .onlyApplicableToStructOrClass: return "@PublicInit can only be applied to struct or class"
        }
    }
}

public class InitMacro: MemberMacro {
    class func modifier() -> String? { nil }

    public static func expansion(
        of attribute: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let members = if let structDecl = declaration.as(StructDeclSyntax.self) {
            Self.membersOfStruct(structDecl)
        } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
            Self.membersOfClass(classDecl)
        } else {
            throw PublicInitError.onlyApplicableToStructOrClass
        }

        let memListDecl = members?.compactMap { $0.decl.as(VariableDeclSyntax.self) } ?? []
        let bindings = memListDecl.filter {
            $0.modifiers?.contains { $0.name.text == "lazy" } != true
            && $0.attributes == nil
        }.flatMap { decl in
            decl.bindings.map {
                (binding: $0, isImmutable: decl.bindingKeyword.text == "let")
            }
        }

        let parameters = bindings.compactMap { item -> (name: TokenSyntax, type: TokenSyntax, defaultValue: ExprSyntax?)? in
            let (binding, isImmutable) = item
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
                  let type = binding.typeAnnotation?.type.as(SimpleTypeIdentifierSyntax.self),
                  binding.accessor == nil,
                  binding.initializer == nil || !isImmutable
            else {
                return nil
            }
            return (
                name: identifier,
                type: type.name,
                defaultValue: binding.initializer?.value
            )
        }

        let modifier = modifier().flatMap { "\($0) " } ?? ""

        let initParams = parameters.map { "\($0.name): \($0.type)\($0.defaultValue.flatMap { "= \($0)" } ?? "")" }.joined(separator: ",")
        let initializer = try InitializerDeclSyntax("\(raw: modifier)init(\(raw: initParams))") {
            CodeBlockItemListSyntax(
                parameters.compactMap {
                    CodeBlockItemSyntax(
                        item: .expr(ExprSyntax(stringLiteral: "self.\($0.name) = \($0.name)"))
                    )
                }
            )
        }

        return [DeclSyntax(initializer)]
    }

    static func membersOfStruct(_ declaration: StructDeclSyntax) -> MemberDeclListSyntax? {
        return declaration.memberBlock.members.as(MemberDeclListSyntax.self)
    }

    static func membersOfClass(_ declaration: ClassDeclSyntax) -> MemberDeclListSyntax? {
        return declaration.memberBlock.members.as(MemberDeclListSyntax.self)
    }
}

public class PublicInitMacro: InitMacro {
    override class func modifier() -> String? { "public" }
}

public class InternalInitMacro: InitMacro {
    override class func modifier() -> String? { nil }
}
