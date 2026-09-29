import SwiftUI
import SwiftfulUI

struct ChecklistItemsEditorView: View {

    @Binding var items: [ChecklistItemDraft]
    var lockedItemIds: Set<String> = []

    @State private var newItemTitle = ""
    @State private var newItemCreditValue: ChecklistCreditValue = .halfCredit

    private var canAddItem: Bool {
        !newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("CHECKLIST ITEMS")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                ForEach($items) { $item in
                    itemRow(item: $item)
                }

                addRow
            }
        }
    }

    private func itemRow(item: Binding<ChecklistItemDraft>) -> some View {
        let draft = item.wrappedValue
        let isLocked = draft.itemId.map { lockedItemIds.contains($0) } ?? false
        return HStack(spacing: TyfeSpacing.small) {
            TyfeTextFieldView(placeholder: "Item title", text: item.title)
                .accessibilityIdentifier("checklist-item-title")

            creditMenu(selection: item.creditValue)

            iconButton(
                systemImage: "trash",
                isEnabled: !isLocked,
                accessibilityLabel: isLocked ? "Checked today, uncheck to delete" : "Delete item"
            ) {
                items.removeAll { $0.id == draft.id }
            }
        }
    }

    private var addRow: some View {
        HStack(spacing: TyfeSpacing.small) {
            TyfeTextFieldView(placeholder: "Add an item", text: $newItemTitle)
                .accessibilityIdentifier("checklist-new-item-field")

            creditMenu(selection: $newItemCreditValue)

            iconButton(
                systemImage: "plus",
                isEnabled: canAddItem,
                accessibilityLabel: "Add checklist item"
            ) {
                items.append(
                    ChecklistItemDraft(
                        title: newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                        creditValue: newItemCreditValue
                    )
                )
                newItemTitle = ""
                newItemCreditValue = .halfCredit
            }
        }
    }

    private func creditMenu(selection: Binding<ChecklistCreditValue>) -> some View {
        Menu {
            ForEach(ChecklistCreditValue.allCases, id: \.self) { value in
                Button {
                    selection.wrappedValue = value
                } label: {
                    Text("\(value.displayName) credit\(value.creditValue == 1 ? "" : "s")")
                }
            }
        } label: {
            Text(selection.wrappedValue.displayName)
                .font(TyfeTypography.interfaceStrong)
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(minWidth: 44, minHeight: 44)
                .background(TyfeEditorialPalette.canvas)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(TyfeEditorialPalette.controlBorder, lineWidth: TyfeStroke.hairline)
                }
        }
        .accessibilityLabel("Credit value")
        .accessibilityValue(selection.wrappedValue.creditLabel)
    }

    private func iconButton(
        systemImage: String,
        isEnabled: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.black))
            .foregroundStyle(isEnabled ? TyfeEditorialPalette.ink : TyfeEditorialPalette.disabledInk)
            .frame(width: 44, height: 44)
            .background(isEnabled ? TyfeEditorialPalette.canvas : TyfeEditorialPalette.disabledFill)
            .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.control)
                    .stroke(TyfeEditorialPalette.controlBorder, lineWidth: TyfeStroke.hairline)
            }
            .contentShape(Rectangle())
            .asButton(.press) {
                guard isEnabled else { return }
                action()
            }
            .disabled(!isEnabled)
            .accessibilityLabel(accessibilityLabel)
    }
}
