
/// "Stringify" the provided value and produce a tuple that includes both the
/// original value as well as the source code that generated it.
public macro stringify<T>(_ value: T) -> (T, String) = MacroExamplesPlugin.StringifyMacro
