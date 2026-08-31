import Foundation

public enum LayoutNameProblem: Equatable, Sendable {
    case empty
    case duplicate(String)

    public var message: String? {
        switch self {
        case .empty:
            nil
        case let .duplicate(name):
            "A layout named \"\(name)\" already exists."
        }
    }
}

public enum LayoutNameValidator {
    public static func defaultName(existingCount: Int) -> String {
        "Layout \(existingCount + 1)"
    }

    public static func problem(for raw: String, existing: [String]) -> LayoutNameProblem? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        let taken = existing.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard !taken.contains(trimmed.lowercased()) else {
            return .duplicate(trimmed)
        }
        return nil
    }
}
