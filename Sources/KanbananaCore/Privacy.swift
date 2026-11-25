import Foundation

package struct PrivacyOptions: Codable, Sendable, Equatable {
    package init() {}
    package var disabledProviders: Set<String> = ["chatgpt"]
    // Explicit opt-in replaces 0.4.8’s automatic experimental monitoring.
    package var chatGPTOptIn: Bool? = nil
    package var excludedSummaryProjects: Set<String> = []
    package var dailySummaryLimit = 100
    package var codexHome: String? = nil
    package var claudeHome: String? = nil

    private enum CodingKeys: String, CodingKey {
        case disabledProviders, chatGPTOptIn, excludedSummaryProjects, dailySummaryLimit, codexHome, claudeHome
    }
    package init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        disabledProviders = try values.decodeIfPresent(Set<String>.self, forKey: .disabledProviders) ?? []
        chatGPTOptIn = try values.decodeIfPresent(Bool.self, forKey: .chatGPTOptIn)
        if chatGPTOptIn != true { disabledProviders.insert("chatgpt") }
        excludedSummaryProjects = try values.decodeIfPresent(Set<String>.self, forKey: .excludedSummaryProjects) ?? []
        dailySummaryLimit = try values.decodeIfPresent(Int.self, forKey: .dailySummaryLimit) ?? 100
        codexHome = try values.decodeIfPresent(String.self, forKey: .codexHome)
        claudeHome = try values.decodeIfPresent(String.self, forKey: .claudeHome)
    }
}
package struct SummaryUsage: Codable, Sendable, Equatable {
    package init(day: String, attempts: Int) { self.day = day; self.attempts = attempts }
    package var day: String
    package var attempts: Int
    package static func today(_ date: Date = Date()) -> String {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
