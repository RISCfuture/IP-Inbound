import Foundation

enum Errors: Error {
    case TOTNotConfigured(target: String)
}

extension Errors: LocalizedError {
    var errorDescription: String? {
        switch self {
            case .TOTNotConfigured:
                return String(localized: "Can’t use a target without setting Time on Target first.")
        }
    }

    var failureReason: String? {
        switch self {
            case let .TOTNotConfigured(target):
                return String(localized: "Target “\(target)” does not have a Time on Target configured.")
        }
    }

    var recoverySuggestion: String? {
        switch self {
            case .TOTNotConfigured:
                return String(localized: "Edit the target and set the Time on Target.")
        }
    }
}
