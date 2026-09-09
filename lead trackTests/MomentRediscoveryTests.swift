import Foundation
import Testing
@testable import lead_track

struct MomentRediscoveryTests {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)
    private var period: DateInterval {
        DateInterval(start: start, duration: 7 * 86400)
    }

    private var oldDate: Date {
        start.addingTimeInterval(-100 * 86400)
    }

    @Test
    func sparseOrUnrelatedHistoryStaysSilent() throws {
        let fixture = try RetrospectiveFixture()
        let oldOwner = fixture.aspiration()
        _ = fixture.moment(under: oldOwner, at: oldDate)
        let currentOwner = fixture.aspiration()
        _ = fixture.moment(under: currentOwner, at: start)
        var preferences = MomentRediscoveryPreferences()
        prepare(fixture, preferences: &preferences)
        #expect(selected(fixture, preferences: preferences) == nil)
        _ = fixture.moment(under: oldOwner, at: start)
        prepare(fixture, preferences: &preferences)
        #expect(selected(fixture, preferences: preferences) == nil)
    }

    @Test
    func selectionSurvivesReorderingAndNewerEligibleMemories() throws {
        let fixture = try RetrospectiveFixture()
        let aspiration = fixture.aspiration()
        _ = fixture.intention(under: aspiration, week: start)
        let original = fixture.moment(under: aspiration, at: oldDate)
        var preferences = MomentRediscoveryPreferences()
        prepare(fixture, preferences: &preferences)
        #expect(selected(fixture, preferences: preferences) === original)
        _ = fixture.moment(under: aspiration, at: oldDate.addingTimeInterval(86400))
        aspiration.moments.reverse()
        prepare(fixture, preferences: &preferences)
        #expect(selected(fixture, preferences: preferences) === original)
    }

    @Test
    func tiedDatesHaveDeterministicIdentityOrder() throws {
        let fixture = try RetrospectiveFixture()
        let aspiration = fixture.aspiration()
        _ = fixture.note(under: aspiration, week: start)
        let first = fixture.moment(under: aspiration, at: oldDate)
        first.stableID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        let second = fixture.moment(under: aspiration, at: oldDate)
        second.stableID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")
        var initial = MomentRediscoveryPreferences()
        prepare(fixture, preferences: &initial)
        aspiration.moments.reverse()
        var reopened = MomentRediscoveryPreferences()
        prepare(fixture, preferences: &reopened)
        #expect(selected(fixture, preferences: initial) === first)
        #expect(selected(fixture, preferences: reopened) === first)
    }

    @Test
    func minimumAgeAndAuthoredContentAreRequired() throws {
        let fixture = try RetrospectiveFixture()
        let aspiration = fixture.aspiration()
        _ = fixture.moment(under: aspiration, at: start)
        let cutoff = start.addingTimeInterval(-90 * 86400)
        _ = fixture.moment(under: aspiration, at: cutoff.addingTimeInterval(1))
        let blank = fixture.moment(under: aspiration, at: oldDate)
        blank.text = " \n "
        var preferences = MomentRediscoveryPreferences()
        prepare(fixture, preferences: &preferences)
        #expect(selected(fixture, preferences: preferences) == nil)
        let oldEnough = fixture.moment(under: aspiration, at: cutoff)
        var freshReview = MomentRediscoveryPreferences()
        prepare(fixture, preferences: &freshReview)
        #expect(selected(fixture, preferences: freshReview) === oldEnough)
    }

    @Test
    func optOutAndShelvingSuppressAnAlreadySelectedMoment() throws {
        let fixture = try RetrospectiveFixture()
        let aspiration = fixture.aspiration()
        _ = fixture.moment(under: aspiration, at: start)
        let older = fixture.moment(under: aspiration, at: oldDate)
        var preferences = MomentRediscoveryPreferences()
        prepare(fixture, preferences: &preferences)
        #expect(selected(fixture, preferences: preferences) === older)
        #expect(MomentRediscovery.selected(
            history: fixture.history, period: period, preferences: preferences, enabled: false
        ) == nil)
        aspiration.archive(at: start)
        #expect(selected(fixture, preferences: preferences) == nil)
        aspiration.unarchive()
        #expect(selected(fixture, preferences: preferences) === older)
    }

    @Test
    func dismissalPersistsWithoutReplacementRoulette() throws {
        let fixture = try RetrospectiveFixture()
        let aspiration = fixture.aspiration()
        _ = fixture.moment(under: aspiration, at: start)
        _ = fixture.moment(under: aspiration, at: oldDate)
        _ = fixture.moment(under: aspiration, at: oldDate.addingTimeInterval(-86400))
        var preferences = MomentRediscoveryPreferences()
        prepare(fixture, preferences: &preferences)
        preferences.dismiss(period: period)
        let encoded = try #require(preferences.encoded())
        var reopened = try #require(MomentRediscoveryPreferences.decode(encoded))
        prepare(fixture, preferences: &reopened)
        #expect(selected(fixture, preferences: reopened) == nil)
        let manual = RetrospectiveReader.read(
            history: fixture.history, period: DateInterval(start: oldDate.addingTimeInterval(-86400), end: start)
        )
        #expect(manual.moments.map(\.text) == aspiration.moments.filter { $0.occurredAt < start }
            .sorted { $0.occurredAt < $1.occurredAt }.map(\.text))
    }

    @Test
    func sensitiveExclusionPersistsAcrossPeriodsAndNeverDeletesHistory() throws {
        let fixture = try RetrospectiveFixture()
        let aspiration = fixture.aspiration()
        _ = fixture.moment(under: aspiration, at: start)
        let sensitive = fixture.moment(under: aspiration, at: oldDate)
        var preferences = MomentRediscoveryPreferences()
        prepare(fixture, preferences: &preferences)
        preferences.exclude(sensitive, period: period)
        let encoded = try #require(preferences.encoded())
        var reopened = try #require(MomentRediscoveryPreferences.decode(encoded))
        #expect(selected(fixture, preferences: reopened) == nil)
        let next = DateInterval(start: period.end, duration: period.duration)
        _ = fixture.moment(under: aspiration, at: next.start)
        MomentRediscovery.prepare(history: fixture.history, period: next, preferences: &reopened, enabled: true)
        #expect(MomentRediscovery.selected(
            history: fixture.history, period: next, preferences: reopened, enabled: true
        ) == nil)
        let manual = RetrospectiveReader.read(
            history: fixture.history, period: DateInterval(start: oldDate, end: start)
        )
        #expect(manual.moments.map(\.stableID) == [sensitive.stableID])
    }

    @Test
    func disabledPreparationAndUnreadablePrivacyStateFailClosed() throws {
        let fixture = try RetrospectiveFixture()
        let aspiration = fixture.aspiration()
        _ = fixture.moment(under: aspiration, at: start)
        _ = fixture.moment(under: aspiration, at: oldDate)
        var preferences = try #require(MomentRediscoveryPreferences.decode(Data()))
        MomentRediscovery.prepare(
            history: fixture.history, period: period, preferences: &preferences, enabled: false
        )
        #expect(selected(fixture, preferences: preferences) == nil)
        #expect(MomentRediscoveryPreferences.decode(Data("unreadable".utf8)) == nil)
    }

    @Test
    func liveWeekEndTimesKeepSelectionAndDismissalForTheSameReview() throws {
        let fixture = try RetrospectiveFixture()
        let aspiration = fixture.aspiration()
        _ = fixture.moment(under: aspiration, at: start)
        let original = fixture.moment(under: aspiration, at: oldDate)
        let day = Calendar.current.startOfDay(for: period.end)
        let morning = DateInterval(start: start, end: day.addingTimeInterval(3600))
        let evening = DateInterval(start: start, end: day.addingTimeInterval(7200))
        var preferences = MomentRediscoveryPreferences()
        MomentRediscovery.prepare(history: fixture.history, period: morning, preferences: &preferences, enabled: true)
        _ = fixture.moment(under: aspiration, at: oldDate.addingTimeInterval(86400))
        MomentRediscovery.prepare(history: fixture.history, period: evening, preferences: &preferences, enabled: true)
        #expect(MomentRediscovery.selected(
            history: fixture.history, period: evening, preferences: preferences, enabled: true
        ) === original)
        var excluding = preferences
        preferences.dismiss(period: morning)
        MomentRediscovery.prepare(history: fixture.history, period: evening, preferences: &preferences, enabled: true)
        #expect(MomentRediscovery.selected(
            history: fixture.history, period: evening, preferences: preferences, enabled: true
        ) == nil)
        excluding.exclude(original, period: morning)
        MomentRediscovery.prepare(history: fixture.history, period: evening, preferences: &excluding, enabled: true)
        #expect(MomentRediscovery.selected(
            history: fixture.history, period: evening, preferences: excluding, enabled: true
        ) == nil)
    }

    private func prepare(_ fixture: RetrospectiveFixture, preferences: inout MomentRediscoveryPreferences) {
        MomentRediscovery.prepare(history: fixture.history, period: period, preferences: &preferences, enabled: true)
    }

    private func selected(_ fixture: RetrospectiveFixture, preferences: MomentRediscoveryPreferences) -> Moment? {
        MomentRediscovery.selected(history: fixture.history, period: period, preferences: preferences, enabled: true)
    }
}
