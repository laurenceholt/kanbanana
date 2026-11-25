import Foundation
import Testing
import KanbananaCore

@Test func chatGPTRequiresExplicitOptInOnNewAndOlderBoards() throws {
    #expect(PrivacyOptions().disabledProviders == ["chatgpt"])
    let legacy = Data(#"{"disabledProviders":["claude"],"excludedSummaryProjects":["private"],"dailySummaryLimit":25,"codexHome":"/example/codex"}"#.utf8)
    let restored = try JSONDecoder().decode(PrivacyOptions.self, from: legacy)
    #expect(restored.disabledProviders == ["claude", "chatgpt"])
    #expect(restored.excludedSummaryProjects == ["private"])
    #expect(restored.dailySummaryLimit == 25 && restored.codexHome == "/example/codex")
}

@Test func experimentalConsentSurvivesRestartWithoutReenablingDisabledSource() throws {
    var consented = PrivacyOptions()
    consented.chatGPTOptIn = true
    consented.disabledProviders.remove("chatgpt")
    let restored = try JSONDecoder().decode(PrivacyOptions.self, from: JSONEncoder().encode(consented))
    #expect(!restored.disabledProviders.contains("chatgpt"))
    consented.disabledProviders.insert("chatgpt")
    let disabled = try JSONDecoder().decode(PrivacyOptions.self, from: JSONEncoder().encode(consented))
    #expect(disabled.disabledProviders.contains("chatgpt"))
}
