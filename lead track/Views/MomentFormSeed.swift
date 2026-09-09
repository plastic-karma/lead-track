import Foundation
import SwiftUI

/// Imported content that starts a new composer. It carries no PhotoKit or
/// extension identifiers — only the same stripped JPEG bytes the ordinary
/// picker produces — so every capture route converges before persistence.
struct MomentFormSeed {
    let photos: [Data]
    let occurredAt: Date
    let importFailureCount: Int

    init(
        photos: [Data] = [],
        occurredAt: Date = .now,
        importFailureCount: Int = 0
    ) {
        self.photos = photos
        self.occurredAt = occurredAt
        self.importFailureCount = max(0, importFailureCount)
    }
}

extension MomentFormView {
    var aspirationSection: some View {
        let choices = allAspirations.unarchived.inDisplayOrder
        return Section {
            Picker("Aspiration", selection: aspirationSelection) {
                Text("Choose an aspiration").tag(Aspiration?.none)
                ForEach(choices) { option in
                    Label(option.title, systemImage: option.displayIcon)
                        .tag(Aspiration?.some(option))
                }
            }
        } footer: {
            if choices.isEmpty {
                Text("Create or bring back an aspiration before keeping this moment.")
            }
        }
        .onChange(of: aspiration?.isArchived) { _, archived in
            if archived == true {
                aspiration = nil
                principle = nil
            }
        }
    }

    private var aspirationSelection: Binding<Aspiration?> {
        Binding(
            get: { aspiration },
            set: { selected in
                aspiration = selected
                principle = nil
            }
        )
    }
}
