
@attached(
  member,
  names: named(RawValue),
  named(rawValue),
  arbitrary // should be named(init(_:)) but that doesn't compile as of swift-DEVELOPMENT-SNAPSHOT-2023-02-02-a
)
public macro NewType<T>(_: T.Type) = #externalMacro(module: "MacroExamplesPlugin", type: "NewTypeMacro")

public protocol NewTypeProtocol: RawRepresentable {
  init(_ rawValue: RawValue)
}

extension NewTypeProtocol {
  public init(rawValue: RawValue) { self.init(rawValue) }
}

// We can automate conformance of a `NewType` to an arbitrary protocol `P` by extending `NewTypeProtocol`. A small but common set of examples follow.

extension NewTypeProtocol where Self: Equatable, RawValue: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool { lhs.rawValue == rhs.rawValue }
}

extension NewTypeProtocol where Self: Comparable, RawValue: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

extension NewTypeProtocol where Self: Hashable, RawValue: Hashable {
  public func hash(into hasher: inout Hasher) { rawValue.hash(into: &hasher) }
}

extension NewTypeProtocol where Self: Encodable, RawValue: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension NewTypeProtocol where Self: Decodable, RawValue: Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(try container.decode(RawValue.self))
  }
}

extension NewTypeProtocol where Self: CustomStringConvertible, RawValue: CustomStringConvertible {
  public var description: String { rawValue.description }
}
