import SwiftUI
import SwiftfulUI

struct TodayProjectDeckTabsView: View {

    let projects: [ProjectModel]
    let showsUnassigned: Bool
    let selectedProjectId: String?
    let isManagementEnabled: Bool
    let onSelect: (String?) -> Void
    let onManage: () -> Void

    var body: some View {
        HStack(spacing: TyfeSpacing.small) {
            ScrollView(.horizontal) {
                HStack(spacing: TyfeSpacing.small) {
                    if showsUnassigned {
                        projectTab(project: nil)
                    }
                    ForEach(projects) { project in
                        projectTab(project: project)
                    }
                }
            }
            .scrollIndicators(.hidden)

            if isManagementEnabled {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(TyfeEditorialPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(TyfeEditorialPalette.paper)
                    .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
                    .overlay {
                        RoundedRectangle(cornerRadius: TyfeRadius.control)
                            .stroke(TyfeEditorialPalette.controlBorder, lineWidth: TyfeStroke.hairline)
                    }
                    .asButton(.press, action: onManage)
                    .accessibilityLabel("Manage Spaces and Activities")
                    .accessibilityIdentifier("today-project-management-button")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Space decks")
    }

    private func projectTab(project: ProjectModel?) -> some View {
        let title = project?.name ?? "Other"
        let projectId = project?.projectId
        let isSelected = selectedProjectId == projectId
        let projectColor = ProjectColorOption.color(for: project?.resolvedColorToken)
        let accessibilityValue = project.map {
            "\(isSelected ? "Selected" : "Not selected"), color \(ProjectColorOption.title(for: $0.resolvedColorToken))"
        } ?? (isSelected ? "Selected" : "Not selected")

        return HStack(spacing: TyfeSpacing.small) {
            if project != nil {
                RoundedRectangle(cornerRadius: 2)
                    .fill(projectColor)
                    .frame(width: 9, height: 9)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(TyfeTypography.interfaceStrong)
                .lineLimit(1)
        }
        .foregroundStyle(TyfeEditorialPalette.ink)
        .padding(.horizontal, TyfeSpacing.control)
        .frame(minHeight: 44)
        .background(TyfeEditorialPalette.paper)
        .clipShape(Capsule())
        .overlay {
            if isSelected {
                Capsule()
                    .strokeBorder(projectColor, lineWidth: TyfeStroke.hairline)
                    .overlay {
                        Capsule()
                            .inset(by: TyfeStroke.hairline)
                            .strokeBorder(projectColor, lineWidth: TyfeStroke.emphasis)
                    }
            } else {
                Capsule()
                    .strokeBorder(TyfeEditorialPalette.controlBorder, lineWidth: TyfeStroke.hairline)
            }
        }
        .asButton(.press) {
            onSelect(projectId)
        }
        .accessibilityLabel("\(title) space deck")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Shows planned Activities in this deck")
        .accessibilityIdentifier("today-project-tab-\(projectId ?? "unassigned")")
    }
}

#Preview("Space deck tabs") {
    TodayProjectDeckTabsView(
        projects: ProjectModel.mocks,
        showsUnassigned: true,
        selectedProjectId: ProjectModel.mock.projectId,
        isManagementEnabled: true,
        onSelect: { _ in },
        onManage: { }
    )
    .padding()
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Space deck tabs variety") {
    VStack(alignment: .leading, spacing: TyfeSpacing.control) {
        TodayProjectDeckTabsView(
            projects: [],
            showsUnassigned: false,
            selectedProjectId: nil,
            isManagementEnabled: false,
            onSelect: { _ in },
            onManage: { }
        )
        TodayProjectDeckTabsView(
            projects: ProjectModel.mocks,
            showsUnassigned: false,
            selectedProjectId: nil,
            isManagementEnabled: true,
            onSelect: { _ in },
            onManage: { }
        )
    }
    .padding()
    .background(TyfeEditorialPalette.canvas)
}
