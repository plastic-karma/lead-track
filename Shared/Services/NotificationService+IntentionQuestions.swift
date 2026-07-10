#if canImport(UserNotifications)
import Foundation
import SwiftData
import UserNotifications

/// The daily-question notifications an active intention asks: one one-shot
/// per remaining day of its week, re-armed by `rescheduleAll`'s
/// wipe-and-rebuild sweep on every foreground pass — so closed, expired, and
/// deleted intentions self-heal out, and the explicit cancels below only
/// cover the gap until the next pass.
extension NotificationService {
    private static let intentionQuestionPrefix = "intention-question-"
    /// `userInfo` key carrying the owning aspiration's `stableID`, so a tap
    /// can deep-link into its detail.
    static let aspirationDeepLinkKey = "aspirationStableID"

    /// Whether a delivered notification is an intention's daily question, so
    /// the responder can route the tap to the owning aspiration.
    static func isIntentionQuestion(id: String) -> Bool {
        id.hasPrefix(intentionQuestionPrefix)
    }

    /// Re-arms every active intention's question inside `rescheduleAll`'s
    /// sweep; `scheduleQuestion` itself filters out the ineligible.
    static func scheduleAllIntentionQuestions(in context: ModelContext) {
        let intentions: [Intention]
        do {
            intentions = try context.fetch(FetchDescriptor<Intention>())
        } catch {
            NotifyLog.error("intention fetch failed: \(error.localizedDescription)")
            return
        }
        for intention in intentions {
            scheduleQuestion(for: intention)
        }
    }

    /// Schedules the intention's question once per remaining day of its week
    /// — at most `IntentionQuestionPlanner.maxSlotsPerWeek` one-shots, each
    /// at a seeded-random minute inside the daily window.
    static func scheduleQuestion(for intention: Intention, now: Date = .now) {
        guard let question = intention.question,
              let stableID = intention.stableID,
              intention.isOpen, intention.isInCurrentWeek(now: now)
        else { return }
        let dates = IntentionQuestionPlanner.fireDates(
            for: question,
            week: intention.weekInterval(),
            seed: stableID.stableSeed,
            now: now
        )
        let content = questionContent(for: intention, question: question)
        for (index, date) in dates.enumerated() {
            schedule(id: questionID(stableID, index), content: content, trigger: calendarTrigger(for: date))
        }
    }

    /// Cancel + schedule, for edits from the question sheet.
    static func rescheduleQuestion(for intention: Intention) {
        cancelQuestion(for: intention)
        scheduleQuestion(for: intention)
    }

    /// Sweeps every slot the planner could have filled — the range is the
    /// planner's own ceiling, so scheduled IDs can never outrun the cancel.
    static func cancelQuestion(for intention: Intention) {
        guard let stableID = intention.stableID else { return }
        let ids = (0 ..< IntentionQuestionPlanner.maxSlotsPerWeek)
            .map { questionID(stableID, $0) }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Explicit cancel for an aspiration about to be deleted — the cascade
    /// takes its intentions with no per-row hook.
    static func cancelQuestions(for aspiration: Aspiration) {
        for intention in aspiration.intentions {
            cancelQuestion(for: intention)
        }
    }

    private static func questionID(_ stableID: UUID, _ index: Int) -> String {
        "\(intentionQuestionPrefix)\(stableID.uuidString)-\(index)"
    }

    /// The banner reads "<intention title> / <the user's question>" — or two
    /// generic lines when the app lock calls for discreet banners.
    private static func questionContent(
        for intention: Intention,
        question: IntentionQuestion
    ) -> UNMutableNotificationContent {
        let content = makeContent(questionCopy(
            title: intention.title,
            question: question.text,
            discreet: NotificationPrivacy.isDiscreet()
        ))
        if let aspirationID = intention.aspiration?.stableID {
            content.userInfo = [aspirationDeepLinkKey: aspirationID.uuidString]
        }
        return content
    }
}
#endif
