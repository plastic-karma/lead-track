import Foundation
import Testing
@testable import lead_track

struct ProjectReflectionTests {
    @Test
    func setAsideMetricOwnerSuppressesReflectionUntilBroughtBack() throws {
        let fixture = try ModelFixture()
        let metric = fixture.makeMetric()
        let project = fixture.makeProject("A book", of: metric)
        let owner = fixture.makeAspiration("Grow wiser")
        let unrelated = fixture.makeAspiration("Stay active")
        owner.metrics = [metric]
        owner.archive()

        #expect(ProjectService.closingMomentOwners(for: project, among: [owner, unrelated]).isEmpty)

        owner.unarchive()
        let choices = ProjectService.closingMomentOwners(for: project, among: [owner, unrelated])
        #expect(choices.map(\.stableIdentity) == [owner.stableIdentity])
    }

    @Test
    func sharedProjectKeepsItsActiveReflectionOwner() throws {
        let fixture = try ModelFixture()
        let metric = fixture.makeMetric()
        let project = fixture.makeProject("A book", of: metric)
        let shelved = fixture.makeAspiration("Study the classics")
        let active = fixture.makeAspiration("Read together")
        shelved.metrics = [metric]
        active.projects = [project]
        active.metrics = [metric]
        shelved.archive()

        let choices = ProjectService.closingMomentOwners(for: project, among: [shelved, active])

        #expect(choices.map(\.stableIdentity) == [active.stableIdentity])
    }

    @Test
    func unattachedProjectCanChooseAnActiveAspiration() throws {
        let fixture = try ModelFixture()
        let project = fixture.makeProject("A book", of: fixture.makeMetric())
        let shelved = fixture.makeAspiration("Study the classics")
        let active = fixture.makeAspiration("Grow wiser")
        shelved.archive()

        let choices = ProjectService.closingMomentOwners(for: project, among: [shelved, active])

        #expect(choices.map(\.stableIdentity) == [active.stableIdentity])
    }
}
