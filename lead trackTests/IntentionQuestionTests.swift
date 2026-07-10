import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The daily-question bridge on `Intention`: stored fields ⇄ the
/// `IntentionQuestion` value type, plus the renewal carrying a question into
/// the next week's clone.
struct IntentionQuestionTests {
    /// A UTC calendar keeps hour/minute assertions independent of the host
    /// time zone.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }

    #if canImport(SwiftData)
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #endif

    // MARK: - Fixtures

    private func time(_ hour: Int, _ minute: Int = 0) -> Date {
        ReminderSchedule.time(hour: hour, minute: minute, calendar: calendar)
    }

    private func makeIntention() throws -> Intention {
        let aspiration = Aspiration(title: "Vitality")
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return try Intention.make(title: "be present", kind: .reflective, aspiration: aspiration)
    }

    private func question(_ text: String) -> IntentionQuestion {
        IntentionQuestion(text: text, windowStart: time(8), windowEnd: time(20))
    }

    // MARK: - Bridge

    @Test
    func aFreshIntentionAsksNoQuestion() throws {
        let intention = try makeIntention()
        #expect(intention.question == nil)
        #expect(intention.questionText == nil)
    }

    @Test
    func applyQuestionRoundTripsTrimmed() throws {
        let intention = try makeIntention()
        intention.applyQuestion(question("  Did you rest today?  "))
        let loaded = try #require(intention.question)
        #expect(loaded.text == "Did you rest today?")
        #expect(loaded.windowStart == time(8))
        #expect(loaded.windowEnd == time(20))
    }

    @Test
    func applyingNilClearsEveryStoredField() throws {
        let intention = try makeIntention()
        intention.applyQuestion(question("Did you rest today?"))
        intention.applyQuestion(nil)
        #expect(intention.question == nil)
        #expect(intention.questionText == nil)
        #expect(intention.questionWindowStart == nil)
        #expect(intention.questionWindowEnd == nil)
    }

    @Test
    func aBlankQuestionAppliesAsOff() throws {
        let intention = try makeIntention()
        intention.applyQuestion(question("   \n"))
        #expect(intention.question == nil)
        #expect(intention.questionWindowStart == nil)
    }

    @Test
    func theWindowKeepsItsHourAndMinute() throws {
        let intention = try makeIntention()
        intention.applyQuestion(
            IntentionQuestion(text: "Out at dawn?", windowStart: time(7, 15), windowEnd: time(21, 45))
        )
        let loaded = try #require(intention.question)
        let start = calendar.dateComponents([.hour, .minute], from: loaded.windowStart)
        let end = calendar.dateComponents([.hour, .minute], from: loaded.windowEnd)
        #expect(start.hour == 7)
        #expect(start.minute == 15)
        #expect(end.hour == 21)
        #expect(end.minute == 45)
    }

    // MARK: - Renewal

    @Test
    func setAgainCarriesTheQuestionForward() throws {
        let source = try makeIntention()
        source.applyQuestion(question("Did you rest today?"))

        let renewed = IntentionRenewal.setAgain(source, calendar: calendar)

        #expect(renewed.question == source.question)
        #expect(renewed.question?.text == "Did you rest today?")
    }

    @Test
    func setAgainCarriesNoQuestionAsNoQuestion() throws {
        let source = try makeIntention()

        let renewed = IntentionRenewal.setAgain(source, calendar: calendar)

        #expect(renewed.question == nil)
    }
}
