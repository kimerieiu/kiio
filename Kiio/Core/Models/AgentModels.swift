import Foundation

struct AgentDTO: Decodable, Identifiable, Equatable {
    let id: String
    let agentName: String?
    let ttsModelName: String?
    let ttsVoiceName: String?
    let llmModelName: String?
    let vllmModelName: String?
    let memModelId: String?
    let systemPrompt: String?
    let summaryMemory: String?
    let lastConnectedAt: String?
    let deviceCount: Int?

    var displayName: String {
        agentName?.isEmpty == false ? agentName! : "Kiio Agent"
    }
}
