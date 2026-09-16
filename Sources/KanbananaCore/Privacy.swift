import Foundation

package struct PrivacyOptions: Codable, Sendable, Equatable {
    package init() {}
    package var disabledProviders: Set<String> = []
    package var excludedSummaryProjects: Set<String> = []
    package var dailySummaryLimit = 100
    package var codexHome: String? = nil
    package var claudeHome: String? = nil
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
