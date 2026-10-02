import Foundation

protocol VaultScalar {
    var vaultValue: VaultValue { get }
    static func decodeVault(_ value: VaultValue) throws -> Self
}

extension String: VaultScalar {
    var vaultValue: VaultValue {
        .string(self)
    }

    static func decodeVault(_ value: VaultValue) throws -> String {
        guard case let .string(text) = value else { throw VaultError.invalid("Expected text") }
        return text
    }
}

extension Double: VaultScalar {
    var vaultValue: VaultValue {
        .number(self)
    }

    static func decodeVault(_ value: VaultValue) throws -> Double {
        guard case let .number(number) = value, number.isFinite else {
            throw VaultError.invalid("Expected a finite number")
        }
        return number
    }
}

extension Int: VaultScalar {
    var vaultValue: VaultValue {
        .number(Double(self))
    }

    static func decodeVault(_ value: VaultValue) throws -> Int {
        let number = try Double.decodeVault(value)
        guard let integer = Int(exactly: number) else { throw VaultError.invalid("Expected an integer") }
        return integer
    }
}

extension Bool: VaultScalar {
    var vaultValue: VaultValue {
        .bool(self)
    }

    static func decodeVault(_ value: VaultValue) throws -> Bool {
        guard case let .bool(flag) = value else { throw VaultError.invalid("Expected a boolean") }
        return flag
    }
}

extension Date: VaultScalar {
    var vaultValue: VaultValue {
        .string(formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
    }

    static func decodeVault(_ value: VaultValue) throws -> Date {
        let text = try String.decodeVault(value)
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let ordinary = Date.ISO8601FormatStyle()
        guard text.hasSuffix("Z") || text.range(of: #"[+-]\d{2}:\d{2}$"#, options: .regularExpression) != nil,
              let date = (try? fractional.parse(text)) ?? (try? ordinary.parse(text)),
              date.timeIntervalSinceReferenceDate.isFinite
        else { throw VaultError.invalid("Expected an ISO8601 timestamp with timezone") }
        return date
    }
}

extension Optional: VaultScalar where Wrapped: VaultScalar {
    var vaultValue: VaultValue {
        map(\.vaultValue) ?? .null
    }

    static func decodeVault(_ value: VaultValue) throws -> Self {
        if value == .null { return nil }
        return try Wrapped.decodeVault(value)
    }
}

extension Array: VaultScalar where Element: VaultScalar {
    var vaultValue: VaultValue {
        .array(map(\.vaultValue))
    }

    static func decodeVault(_ value: VaultValue) throws -> Self {
        if value == .null { return [] }
        guard case let .array(values) = value else { throw VaultError.invalid("Expected a list") }
        return try values.map(Element.decodeVault)
    }
}

protocol VaultStringEnum: VaultScalar, RawRepresentable where RawValue == String {}

extension VaultStringEnum {
    var vaultValue: VaultValue {
        .string(rawValue)
    }

    static func decodeVault(_ value: VaultValue) throws -> Self {
        guard let result = try Self(rawValue: String.decodeVault(value)) else {
            throw VaultError.invalid("Unknown enum value")
        }
        return result
    }
}

extension MeasurementType: VaultStringEnum {}
extension ProjectStatus: VaultStringEnum {}

struct VaultModelField<Model> {
    let name: String
    let encode: (Model) -> VaultValue
    let apply: (Model, VaultValue) throws -> Void

    init<Value: VaultScalar>(_ name: String, _ keyPath: ReferenceWritableKeyPath<Model, Value>) {
        self.name = name
        encode = { $0[keyPath: keyPath].vaultValue }
        apply = { model, value in model[keyPath: keyPath] = try Value.decodeVault(value) }
    }
}

protocol VaultModel: AnyObject {
    var stableID: UUID? { get set }
    static var vaultKind: VaultKind { get }
    static var vaultFields: [VaultModelField<Self>] { get }
    static func emptyVaultModel() -> Self
    var vaultBody: String { get set }
    var vaultLabel: String { get }
}

extension VaultModel {
    var vaultBody: String {
        get { "" }
        set {}
    }

    func vaultRecord() -> VaultRecord {
        let id = stableID ?? UUID()
        if stableID == nil { stableID = id }
        var fields = Dictionary(uniqueKeysWithValues: Self.vaultFields.map { ($0.name, $0.encode(self)) })
        fields["aliases"] = .array([.string(vaultLabel)])
        return VaultRecord(id: id, kind: Self.vaultKind, fields: fields, body: vaultBody)
    }

    func applyVaultFields(_ record: VaultRecord) throws {
        for field in Self.vaultFields {
            let value = record.fields[field.name] ?? .null
            do { try field.apply(self, value) } catch {
                throw VaultError.invalid("Invalid \(record.kind.rawValue).\(field.name): \(error.localizedDescription)")
            }
        }
        vaultBody = record.body
    }
}
