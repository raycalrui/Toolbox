import Foundation

enum ToolFavorites {
    private static let defaultsKey = "favoriteToolIDs"

    static func load() -> Set<ToolboxTool> {
        let identifiers = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        return Set(identifiers.compactMap(ToolboxTool.init(rawValue:)))
    }

    static func save(_ tools: Set<ToolboxTool>) {
        let identifiers = tools
            .map(\.rawValue)
            .sorted()
        UserDefaults.standard.set(identifiers, forKey: defaultsKey)
    }
}
