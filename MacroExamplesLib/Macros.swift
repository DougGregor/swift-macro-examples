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


/// Apply the specified attribute to each of the stored properties within the
/// type or member to which the macro is attached. The string can be
/// any attribute (without the `@`).
@attached(memberAttribute)
public macro wrapStoredProperties(_ attributeName: String) = #externalMacro(module: "MacroExamplesPlugin", type: "WrapStoredPropertiesMacro")

/// Wrap up the stored properties of the given type in a dictionary,
/// turning them into computed properties.
///
/// This macro composes three different kinds of macro expansion:
///   * Member-attribute macro expansion, to put itself on all stored properties
///     of the type it is attached to.
///   * Member macro expansion, to add a `_storage` property with the actual
///     dictionary.
///   * Accessor macro expansion, to turn the stored properties into computed
///     properties that look for values in the `_storage` property.
@attached(accessor)
@attached(member, names: named(_storage))
@attached(memberAttribute)
public macro DictionaryStorage() = #externalMacro(module: "MacroExamplesPlugin", type: "DictionaryStorageMacro")
