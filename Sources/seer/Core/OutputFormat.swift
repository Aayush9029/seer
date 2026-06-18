import ArgumentParser

enum OutputFormat: String, CaseIterable, ExpressibleByArgument, Sendable {
    case text
    case markdown
    case json
}
