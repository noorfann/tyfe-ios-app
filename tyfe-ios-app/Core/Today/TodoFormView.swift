import SwiftUI
import SwiftfulUI

struct TodoFormView: View {
    @Binding var draft: TodoDraft
    let projects: [ProjectModel]
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.sectionGap) {
            TyfeSurfaceView(role: .paper) {
                VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                    TyfeTextFieldView(placeholder: "What needs doing?", text: $draft.title)
                        .accessibilityIdentifier("todo-title-field")
                    EffortSpacePicker(projectId: $draft.projectId, projects: projects)
                    EffortCreditPicker(creditValue: $draft.creditValue)
                }
            }
            TyfeSurfaceView(role: .paper) {
                VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                    Text("CHECKLIST · OPTIONAL").font(TyfeTypography.eyebrow)
                    ForEach($draft.items) { $item in
                        HStack(spacing: TyfeSpacing.relatedGap) {
                            TyfeTextFieldView(placeholder: "Checklist item", text: $item.title)
                            Image(systemName: "minus.circle")
                                .frame(minWidth: 44, minHeight: 44)
                                .asButton(.press) { draft.items.removeAll { $0.id == item.id } }
                                .accessibilityLabel("Remove checklist item")
                        }
                    }
                    Text("Add checklist item")
                        .font(TyfeTypography.interfaceStrong)
                        .frame(minHeight: 44)
                        .asButton(.press) {
                            draft.items.append(TodoChecklistItem(id: UUID().uuidString, title: ""))
                        }
                    Text("Complete every item to finish the task. Credits belong to the whole task.")
                        .font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
                }
            }
            TyfeActionButtonView(
                title: "Save To Do", systemImage: "checkmark",
                isEnabled: !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && draft.items.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                onTap: onSave
            )
        }
    }
}
