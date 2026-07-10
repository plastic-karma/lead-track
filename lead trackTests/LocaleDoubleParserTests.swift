import Foundation
import Testing
@testable import lead_track

struct LocaleDoubleParserTests {
    private let commaLocale = Locale(identifier: "de_DE")
    private let dotLocale = Locale(identifier: "en_US")

    @Test
    func parsesCommaDecimalInCommaLocale() {
        #expect(LocaleDoubleParser.parse("1,5", locale: commaLocale) == 1.5)
    }

    @Test
    func parsesDotDecimalInCommaLocale() {
        #expect(LocaleDoubleParser.parse("1.5", locale: commaLocale) == 1.5)
    }

    @Test
    func parsesDotDecimalInDotLocale() {
        #expect(LocaleDoubleParser.parse("1.5", locale: dotLocale) == 1.5)
    }

    @Test
    func parsesWholeNumbersInAnyLocale() {
        #expect(LocaleDoubleParser.parse("42", locale: commaLocale) == 42)
        #expect(LocaleDoubleParser.parse("42", locale: dotLocale) == 42)
    }

    @Test
    func trimsSurroundingWhitespace() {
        #expect(LocaleDoubleParser.parse(" 2,5 ", locale: commaLocale) == 2.5)
    }

    @Test
    func rejectsTextThatSpellsNoNumber() {
        #expect(LocaleDoubleParser.parse("", locale: commaLocale) == nil)
        #expect(LocaleDoubleParser.parse("abc", locale: commaLocale) == nil)
        #expect(LocaleDoubleParser.parse("1,5,5", locale: commaLocale) == nil)
        #expect(LocaleDoubleParser.parse("1,5", locale: dotLocale) == nil)
    }
}
