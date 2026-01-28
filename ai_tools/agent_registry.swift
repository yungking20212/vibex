import Foundation

struct AgentTool {
    let id: String
    let name: String
    let description: String
}

final class AgentRegistry {
    static let shared = AgentRegistry()
    private(set) var tools: [AgentTool] = []

    private init() {
        register(AgentTool(id: "placeholder", name: "Placeholder Tool", description: "Example tool for Vibex AI."))
    }

    func register(_ tool: AgentTool) {
        tools.append(tool)
    }
}
