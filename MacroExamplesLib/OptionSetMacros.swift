/// Specifies the form of option set to which the option set macro is applied.
public enum OptionSetForm {
  /// Options are described via static variables within the struct, allow
  /// of which are expected to have the same type as `Self`.
  /// the option set macros.
  ///
  ///     @OptionSet<UInt8>
  ///     struct ShippingOptions {
  ///       static var nextDay: ShippingOptions
  ///       static var secondDay: ShippingOptions
  ///       static var priority: ShippingOptions
  ///       static var standard: ShippingOptions
  ///     }
  ///
  ///  Any static variable that has an initializer already will be ignored.
  case staticVariables

  /// Options are described via the cases of a nested enum with the given
  /// name.
  ///
  ///     @OptionSet<UInt8>
  ///     struct ShippingOptions {
  ///       private enum Options {
  ///         case nextDay
  ///         case secondDay
  ///         case priority
  ///         case standard
  ///       }
  ///     }
  ///
  ///  The cases will be used to indicate bit positions in the resulting
  ///  raw value, and the `OptionSet` macro will introduced static variables
  ///  of the type of the struct itself (similar to those that have are
  ///  written explicitly for the `staticVariables` form).
  case nestedOptionsEnum(String = "Options")

  /// Options are described via cases on the enum to which the option set
  /// macro is applied.
  ///
  ///     @OptionSet<UInt8>
  ///     enum ShippingOptions {
  ///       case nextDay
  ///       case secondDay
  ///       case priority
  ///       case standard
  ///     }
  ///
  /// As with `nestedEnum`, the cases provide the bit numbers for the
  /// corresponding options in the raw value. With this kind, a nested
  /// struct with the given name will be created that is itself an option
  /// set, e.g.,
  ///
  ///     struct Set: OptionSet {
  ///       var rawValue: UInt8
  ///       static var nextDay: Set = Set(rawValue: 1 << 0)
  ///       static var secondDay: Set = Set(rawValue: 1 << 1)
  ///       static var priority: Set = Set(rawValue: 1 << 2)
  ///       static var standard: Set = Set(rawValue: 1 << 3)
  ///     }
  case nestedOptionSet(String = "Set")
}

/// Create an bit-packed option set from a type that sketches the option names.
///
/// TODO: Update this
///
/// Attach this macro to a struct that contains a nested `Options` enum
/// with an integer raw value. The struct will be transformed to conform to
/// `OptionSet` by
///   1. Introducing a `rawValue` stored property to track which options are set,
///    along with the necessary `RawType` typealias and initializers to satisfy
///    the `OptionSet` protocol. The raw type is specified after `@OptionSet`,
///    e.g., `@OptionSet<UInt8>`.
///   2. Introducing static properties for each of the cases within the `Options`
///    enum, of the type of the struct.
///
/// The `Options` enum must have a raw value, where its case elements
/// each indicate a different option in the resulting option set. For example,
/// the struct and its nested `Options` enum could look like this:
///
///     @MyOptionSet<UInt8>
///     struct ShippingOptions {
///       private enum Options: Int {
///         case nextDay
///         case secondDay
///         case priority
///         case standard
///       }
///     }
@attached(member, names: named(RawValue), named(rawValue), named(`init`), arbitrary)
@attached(conformance)
@attached(memberAttribute)
public macro MyOptionSet<RawType>() = #externalMacro(module: "MacroExamplesPlugin", type: "OptionSetMacro")

@attached(accessor)
public macro Bitfield(bit: Int) = #externalMacro(module: "MacroExamplesPlugin", type: "BitfieldMacro")
