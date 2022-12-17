
/// "Stringify" the provided value and produce a tuple that includes both the
/// original value as well as the source code that generated it.
public macro stringify<T>(_ value: T) -> (T, String) = MacroExamplesPlugin.StringifyMacro

/// Macro that produces a warning on "+" operators within the expression, and
/// suggests changing them to "-".
public macro addBlocker<T>(_ value: T) -> T = MacroExamplesPlugin.AddBlocker

/// Macro that produces a warning, as a replacement for the built-in
/// #warning("...").
public macro myWarning(_ message: String) = MacroExamplesPlugin.WarningMacro

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
public macro fontLiteral<T>(name: String, size: Int, weight: FontWeight) -> T = MacroExamplesPlugin.FontLiteralMacro
  where T: ExpressibleByFontLiteral
