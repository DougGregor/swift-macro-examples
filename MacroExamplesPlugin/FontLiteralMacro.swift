import SwiftSyntax
import _SwiftSyntaxMacros

/// Replace the label of the first element in the tuple with the given
/// new label.
private func replaceFirstLabel(
  of tuple: TupleExprElementListSyntax,
  with newLabel: String
) -> TupleExprElementListSyntax {
  guard let firstElement = tuple.first else {
    return tuple
  }

  return tuple.replacing(
    childAt: 0,
    with: firstElement.withLabel(.identifier(newLabel))
  )
}

public struct FontLiteralMacro: ExpressionMacro {
  public static func expansion(
    of macro: MacroExpansionExprSyntax,
    in context: inout MacroExpansionContext
  ) -> ExprSyntax {
    let argList = replaceFirstLabel(
      of: macro.argumentList,
      with: "fontLiteralName"
    )
    let initSyntax: ExprSyntax = ".init(\(argList))"
    if let leadingTrivia = macro.leadingTrivia {
      return initSyntax.withLeadingTrivia(leadingTrivia)
    }
    return initSyntax
  }
}
