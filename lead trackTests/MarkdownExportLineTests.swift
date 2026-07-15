import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The one-line renderings inside a week section: intentions with their
/// progress and closing word, check-ins with their rating, and moments kept
/// verbatim under their day.
struct MarkdownExportLineTests {
    private let calendar = Calendar.current

    #if canImport(SwiftData)
    /// Relationship arrays only sync through a context on Apple platforms;
    /// the Linux overlay compiles the models as plain classes instead.
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #endif

    // MARK: - Fixtures

    private func day(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    private func makeAspiration(_ title: String = "Grow wiser") -> Aspiration {
        let aspiration = Aspiration(title: title)
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    private func intend(
        _ title: String,
        under aspiration: Aspiration,
        target: Double? = nil,
        weekOf: Date = .now
    ) -> Intention {
        let intention = Intention(
            title: title,
            kind: target == nil ? .reflective : .counted,
            aspiration: aspiration,
            target: target,
            weekStart: Intention.weekStart(containing: weekOf, calendar: calendar)
        )
        #if canImport(SwiftData)
        context.insert(intention)
        #endif
        return intention
    }

    private func keep(_ text: String, under aspiration: Aspiration, at occurredAt: Date) -> Moment {
        let moment = Moment(text: text, aspiration: aspiration, occurredAt: occurredAt)
        #if canImport(SwiftData)
        context.insert(moment)
        #endif
        return moment
    }

    private func build(_ data: MarkdownExportData, range: ExportRange = .allTime) -> String {
        MarkdownExporter.buildMarkdown(data: data, range: range, calendar: calendar)
    }
}

// MARK: - Intentions

extension MarkdownExportLineTests {
    @Test
    func countedIntentionCarriesProgressAndOutcome() {
        let aspiration = makeAspiration("Friendship")
        let intention = intend("Call a friend", under: aspiration, target: 3)
        intention.tick(at: .now, calendar: calendar)
        intention.tick(at: .now, calendar: calendar)
        intention.close(outcome: .partly)

        let markdown = build(MarkdownExportData(intentions: [intention]))

        #expect(markdown.contains("**Intentions**"))
        #expect(markdown.contains("- \"Call a friend\" (Friendship): 2 of 3 — partly"))
    }

    @Test
    func reflectiveIntentionSkipsProgress() {
        let intention = intend("Be present", under: makeAspiration("Family"))
        intention.close(outcome: .done)

        let markdown = build(MarkdownExportData(intentions: [intention]))

        #expect(markdown.contains("- \"Be present\" (Family) — done"))
    }

    @Test
    func openAndRenewedIntentionsNameTheirState() {
        let aspiration = makeAspiration()
        let open = intend("Still going", under: aspiration)
        let renewed = intend("Set again", under: aspiration)
        renewed.close(outcome: nil)

        let markdown = build(MarkdownExportData(intentions: [open, renewed]))

        #expect(markdown.contains("- \"Still going\" (Grow wiser) — open"))
        #expect(markdown.contains("- \"Set again\" (Grow wiser) — renewed"))
    }

    @Test
    func derivedIntentionWithoutItsMetricReadsSourceRemoved() {
        let intention = Intention(
            title: "Morning pages",
            kind: .derived,
            aspiration: makeAspiration(),
            derivedMode: .sessionCount,
            weekStart: Intention.weekStart(containing: .now, calendar: calendar)
        )
        #if canImport(SwiftData)
        context.insert(intention)
        #endif

        let markdown = build(MarkdownExportData(intentions: [intention]))

        #expect(markdown.contains("- \"Morning pages\" (Grow wiser): source removed — open"))
    }

    @Test
    func intentionsFromWeeksBeforeTheCutoffStayOut() {
        let old = intend("Long past", under: makeAspiration(), weekOf: day(21))

        let markdown = build(MarkdownExportData(intentions: [old]), range: .last7Days)

        #expect(!markdown.contains("Long past"))
    }
}

// MARK: - Check-ins

extension MarkdownExportLineTests {
    @Test
    func checkInCarriesRatingAndNote() {
        let checkIn = AspirationCheckIn(
            aspiration: makeAspiration(),
            rating: .serving,
            weekStart: Intention.weekStart(containing: .now, calendar: calendar),
            note: "still true"
        )
        #if canImport(SwiftData)
        context.insert(checkIn)
        #endif

        let markdown = build(MarkdownExportData(checkIns: [checkIn]))

        #expect(markdown.contains("**Check-ins**"))
        #expect(markdown.contains("- Grow wiser: Serving the why — \"still true\""))
    }
}

// MARK: - Moments

extension MarkdownExportLineTests {
    @Test
    func momentRendersUnderItsDayWithProvenanceAndPlace() {
        let aspiration = makeAspiration()
        let metric = Metric(name: "Climbing")
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        let moment = Moment(
            text: "summit",
            aspiration: aspiration,
            occurredAt: day(1),
            metric: metric,
            latitude: 37.9,
            longitude: -122.6,
            placeName: "Mount Tam"
        )
        #if canImport(SwiftData)
        context.insert(moment)
        #endif

        let markdown = build(MarkdownExportData(metrics: [metric], moments: [moment]))

        #expect(markdown.contains("### \(MarkdownExportDates.dayHeading(day(1)))"))
        #expect(markdown.contains("- Moment (Grow wiser): \"summit\" (during Climbing; at Mount Tam)"))
    }

    @Test
    func bareMomentStaysBare() {
        let moment = keep("quiet note", under: makeAspiration(), at: day(1))

        let markdown = build(MarkdownExportData(moments: [moment]))

        #expect(markdown.contains("- Moment (Grow wiser): \"quiet note\"\n"))
        #expect(!markdown.contains("during"))
    }

    @Test
    func multiLineMomentBlockquotesItsContinuation() {
        // Blockquoted, not merely indented: a 2-space indent still parses
        // as an ATX heading, so testimony could forge document structure.
        let moment = keep("first line\nsecond line", under: makeAspiration(), at: day(1))

        let markdown = build(MarkdownExportData(moments: [moment]))

        #expect(markdown.contains("- Moment (Grow wiser): \"first line\n  > second line\""))
    }

    @Test
    func momentsBeforeTheCutoffStayOut() {
        let moment = keep("long ago", under: makeAspiration(), at: day(30))

        let markdown = build(MarkdownExportData(moments: [moment]), range: .last7Days)

        #expect(!markdown.contains("long ago"))
        #expect(markdown.contains("Moments: 0"))
    }
}
