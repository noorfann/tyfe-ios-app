import SwiftUI
import SwiftfulUI

struct EffortCreditPicker: View {
    @Binding var creditValue: ChecklistCreditValue

    var body: some View {
        Picker("Reward Credits", selection: $creditValue) {
            ForEach(ChecklistCreditValue.allCases, id: \.self) { credit in Text(credit.creditLabel).tag(credit) }
        }
        .pickerStyle(.menu)
    }
}
