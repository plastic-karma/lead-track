#if canImport(SwiftData)
import Foundation
import SwiftData

/// Device-local acknowledgment saved atomically with an imported vault graph.
@Model
final class VaultSyncReceipt {
    var destination: String
    var transactionID: UUID

    init(destination: String, transactionID: UUID) {
        self.destination = destination
        self.transactionID = transactionID
    }
}
#endif
