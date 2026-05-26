import Foundation

struct DeviceQRCodePayload: Equatable {
    let code: String
    let rawValue: String
}

enum DeviceQRCodeParserError: Error, Equatable {
    case empty
    case unsupported
}

enum DeviceQRCodeParser {
    private static let codeKeys: Set<String> = [
        "code",
        "deviceCode",
        "device_code",
        "bindCode",
        "bind_code",
        "bindingCode",
        "binding_code",
        "activationCode",
        "activation_code",
        "pairingCode",
        "pairing_code"
    ]

    static func parse(_ rawValue: String) throws -> DeviceQRCodePayload {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DeviceQRCodeParserError.empty
        }

        if let code = exactCode(trimmed)
            ?? codeFromJSON(trimmed)
            ?? codeFromURL(trimmed)
            ?? codeFromQueryString(trimmed)
            ?? firstCode(in: trimmed) {
            return DeviceQRCodePayload(code: code, rawValue: trimmed)
        }

        throw DeviceQRCodeParserError.unsupported
    }

    private static func exactCode(_ value: String) -> String? {
        value.range(of: #"^\d{6}$"#, options: .regularExpression).map { String(value[$0]) }
    }

    private static func codeFromJSON(_ value: String) -> String? {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return codeFromJSONObject(object)
    }

    private static func codeFromJSONObject(_ object: Any) -> String? {
        if let dictionary = object as? [String: Any] {
            for key in codeKeys {
                if let value = dictionary[key],
                   let code = codeFromJSONValue(value) {
                    return code
                }
            }

            for value in dictionary.values {
                if let code = codeFromJSONObject(value) {
                    return code
                }
            }
        }

        if let array = object as? [Any] {
            for value in array {
                if let code = codeFromJSONObject(value) {
                    return code
                }
            }
        }

        return codeFromJSONValue(object)
    }

    private static func codeFromJSONValue(_ value: Any) -> String? {
        if let string = value as? String {
            return exactCode(string) ?? firstCode(in: string)
        }
        if let number = value as? NSNumber {
            return exactCode(number.stringValue)
        }
        return nil
    }

    private static func codeFromURL(_ value: String) -> String? {
        var candidates: [URLComponents] = []

        if let components = URLComponents(string: value) {
            candidates.append(components)
        }

        if value.hasPrefix("/") || value.contains("?") {
            let normalizedPath = value.hasPrefix("/") ? value : "/\(value)"
            if let components = URLComponents(string: normalizedPath) {
                candidates.append(components)
            }
        }

        for components in candidates {
            if let code = codeFromQueryItems(components.queryItems) {
                return code
            }

            for part in [components.host, components.path, components.fragment] {
                if let part, let code = firstCode(in: part) {
                    return code
                }
            }
        }

        return nil
    }

    private static func codeFromQueryString(_ value: String) -> String? {
        guard value.contains("=") else {
            return nil
        }
        var components = URLComponents()
        components.query = value
        return codeFromQueryItems(components.queryItems)
    }

    private static func codeFromQueryItems(_ queryItems: [URLQueryItem]?) -> String? {
        guard let queryItems else {
            return nil
        }

        for item in queryItems where codeKeys.contains(item.name) {
            if let value = item.value,
               let code = exactCode(value) ?? firstCode(in: value) {
                return code
            }
        }

        for item in queryItems {
            if let value = item.value,
               let code = firstCode(in: value) {
                return code
            }
        }

        return nil
    }

    private static func firstCode(in value: String) -> String? {
        guard let range = value.range(of: #"(?<!\d)\d{6}(?!\d)"#, options: .regularExpression) else {
            return nil
        }
        return String(value[range])
    }
}
