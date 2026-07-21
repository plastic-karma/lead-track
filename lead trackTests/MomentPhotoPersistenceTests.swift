#if canImport(SwiftData)
import Foundation
import SwiftData
import Testing
@testable import lead_track

struct MomentPhotoPersistenceTests {
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }

    @Test
    func severalPhotosPersistInTheirDisplayOrder() throws {
        let moment = makeMoment()
        let expected = (0 ..< 4).map { Data([UInt8($0)]) }

        MomentPhotoReconciler.sync(expected, with: moment, in: context)
        try context.save()

        #expect(try storedData() == expected)
    }

    @Test
    func reconciliationAddsAndRemovesPhotosWithContiguousIndexes() throws {
        let moment = makeMoment()
        let original = [Data([1]), Data([2]), Data([3])]
        MomentPhotoReconciler.sync(original, with: moment, in: context)
        try context.save()

        let revised = [original[0], original[2], Data([4])]
        MomentPhotoReconciler.sync(revised, with: moment, in: context)
        try context.save()

        let stored = try orderedPhotos()
        #expect(stored.map(\.data) == revised)
        #expect(stored.map(\.sortIndex) == [0, 1, 2])
    }

    @Test
    func unchangedPhotosKeepTheirExistingObjects() {
        let moment = makeMoment()
        let data = [Data([1]), Data([2])]
        MomentPhotoReconciler.sync(data, with: moment, in: context)
        let existing = moment.photos.sorted { $0.sortIndex < $1.sortIndex }

        MomentPhotoReconciler.sync(data, with: moment, in: context)

        let after = moment.photos.sorted { $0.sortIndex < $1.sortIndex }
        #expect(existing.count == after.count)
        #expect(zip(existing, after).allSatisfy { $0.0 === $0.1 })
    }

    @Test
    func deletingMomentCascadesItsPhotos() throws {
        let moment = makeMoment()
        MomentPhotoReconciler.sync(
            [Data([1]), Data([2]), Data([3])],
            with: moment,
            in: context
        )
        try context.save()

        context.delete(moment)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<MomentPhoto>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Aspiration>()).count == 1)
    }

    private func makeMoment() -> Moment {
        let aspiration = Aspiration(title: "Grow wiser")
        let moment = Moment(text: "A kept day", aspiration: aspiration)
        context.insert(aspiration)
        context.insert(moment)
        return moment
    }

    private func orderedPhotos() throws -> [MomentPhoto] {
        try context.fetch(FetchDescriptor<MomentPhoto>())
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    private func storedData() throws -> [Data] {
        try orderedPhotos().map(\.data)
    }
}
#endif
