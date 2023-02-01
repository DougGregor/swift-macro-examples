
/// "Stringify" the provided value and produce a tuple that includes both the
/// original value as well as the source code that generated it.
@freestanding(expression) public macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MacroExamplesPlugin", type: "StringifyMacro")

/// Macro that produces a warning on "+" operators within the expression, and
/// suggests changing them to "-".
@freestanding(expression) public macro addBlocker<T>(_ value: T) -> T = #externalMacro(module: "MacroExamplesPlugin", type: "AddBlocker")

/// Macro that produces a warning, as a replacement for the built-in
/// #warning("...").
@freestanding(expression) public macro myWarning(_ message: String) = #externalMacro(module: "MacroExamplesPlugin", type: "WarningMacro")

public enum FontWeight {
  case thin
  case normal
  case medium
  case semiBold
  case bold
}

public protocol ExpressibleByFontLiteral {
  init(fontLiteralName: String, size: Int, weight: FontWeight)
}

/// Font literal similar to, e.g., #colorLiteral.
@freestanding(expression) public macro fontLiteral<T>(name: String, size: Int, weight: FontWeight) -> T = #externalMacro(module: "MacroExamplesPlugin", type: "FontLiteralMacro")
  where T: ExpressibleByFontLiteral
