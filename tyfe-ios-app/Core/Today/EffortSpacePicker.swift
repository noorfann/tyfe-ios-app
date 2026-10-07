import SwiftUI
import SwiftfulUI

struct EffortSpacePicker: View {
    @Binding var projectId: String?
    let projects: [ProjectModel]

    var body: some View {
        Picker("Space", selection: $projectId) {
            Text("Other").tag(nil as String?)
            ForEach(projects) { project in Text(project.name).tag(Optional(project.id)) }
        }
        .pickerStyle(.menu)
    }
}
