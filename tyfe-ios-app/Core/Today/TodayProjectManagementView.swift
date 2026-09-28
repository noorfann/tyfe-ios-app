import SwiftUI
import SwiftfulUI

struct TodayProjectManagementView: View {

    @State private var presenter: TodayProjectManagementPresenter
    @State private var isProjectFormPresented = false
    @State private var editingProjectId: String?
    @State private var draggingProjectId: String?
    @State private var targetedProjectId: String?
    @State private var lastReorderTargetId: String?

    @Environment(\.dismiss) private var dismiss

    init(presenter: TodayProjectManagementPresenter) {
        _presenter = State(initialValue: presenter)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                TyfeEditorialPalette.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                        projectListSection
                        if !presenter.archivedProjects.isEmpty {
                            archivedProjectListSection
                        }
                    }
                    .padding(.horizontal, TyfeSpacing.control)
                    .padding(.top, TyfeSpacing.control)
                    .padding(.bottom, 104)
                }
                .scrollIndicators(.hidden)

                addProjectButton
                    .padding(.trailing, TyfeSpacing.control)
                    .padding(.bottom, TyfeSpacing.control)
            }
            .navigationTitle("Spaces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("today-project-management-done")
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .tyfeBottomSheet(
            isPresented: $isProjectFormPresented,
            detents: [.fraction(0.8)],
            title: projectFormTitle,
            onClose: dismissProjectForm
        ) {
            projectForm
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .onChange(of: isProjectFormPresented) { _, isPresented in
            if !isPresented {
                editingProjectId = nil
            }
        }
    }

    private var projectListSection: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("SPACES")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                if presenter.activeProjects.isEmpty {
                    Text("Create a Space to group Activities into a deck.")
                        .font(TyfeTypography.interface)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                }

                ForEach(Array(presenter.activeProjects.enumerated()), id: \.element.projectId) { index, project in
                    projectRow(
                        project,
                        index: presenter.projects.firstIndex(where: { $0.projectId == project.projectId })
                    )
                    if index < presenter.activeProjects.count - 1 {
                        Rectangle()
                            .fill(TyfeEditorialPalette.controlBorder.opacity(0.35))
                            .frame(height: TyfeStroke.hairline)
                    }
                }
            }
        }
    }

    private var archivedProjectListSection: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("ARCHIVED")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                ForEach(Array(presenter.archivedProjects.enumerated()), id: \.element.projectId) { index, project in
                    projectRow(project, index: nil)
                    if index < presenter.archivedProjects.count - 1 {
                        Rectangle()
                            .fill(TyfeEditorialPalette.controlBorder.opacity(0.35))
                            .frame(height: TyfeStroke.hairline)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func projectRow(_ project: ProjectModel, index: Int?) -> some View {
        let row = projectRowContent(project, index: index)
        if index != nil {
            row
                .frame(minHeight: 52)
                .contentShape(Rectangle())
                .background {
                    if targetedProjectId == project.projectId {
                        RoundedRectangle(cornerRadius: TyfeRadius.control)
                            .fill(TyfeEditorialPalette.teal.opacity(0.14))
                    }
                }
                .dropDestination(for: String.self) { draggedProjectIds, _ in
                    guard draggedProjectIds.first == draggingProjectId else { return false }
                    draggingProjectId = nil
                    targetedProjectId = nil
                    lastReorderTargetId = nil
                    return true
                } isTargeted: { isTargeted in
                    updateDropTarget(isTargeted, projectId: project.projectId)
                }
        } else {
            row.frame(minHeight: 52)
        }
    }

    private func projectRowContent(_ project: ProjectModel, index: Int?) -> some View {
        HStack(spacing: TyfeSpacing.small) {
            if let index {
                reorderHandle(project, index: index)
            }
            RoundedRectangle(cornerRadius: 3)
                .fill(ProjectColorOption.color(for: project.resolvedColorToken))
                .frame(width: 14, height: 14)
                .accessibilityLabel("Space color, \(ProjectColorOption.title(for: project.resolvedColorToken))")
                .accessibilityIdentifier("project-color-\(project.projectId)")

            Text(project.name)
                .font(TyfeTypography.interfaceStrong)
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "pencil")
                .font(.headline.weight(.semibold))
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(width: 44, height: 44)
                .background(TyfeEditorialPalette.canvas)
                .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
                .asButton(.press) {
                    presentProjectForm(projectId: project.projectId)
                }
                .accessibilityLabel("Edit \(project.name)")
                .accessibilityIdentifier("project-edit-\(project.projectId)")

            archiveButton(for: project)

            Image(systemName: "trash")
                .font(.headline.weight(.semibold))
                .foregroundStyle(TyfeEditorialPalette.onError)
                .frame(width: 44, height: 44)
                .background(TyfeEditorialPalette.errorFill)
                .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
                .asButton(.press) {
                    presenter.onDeleteProjectPressed(project)
                }
                .accessibilityLabel("Delete \(project.name)")
                .accessibilityIdentifier("project-delete-\(project.projectId)")
        }
    }

    private func archiveButton(for project: ProjectModel) -> some View {
        Image(systemName: project.isArchived ? "arrow.uturn.backward" : "archivebox")
            .font(.headline.weight(.semibold))
            .foregroundStyle(TyfeEditorialPalette.ink)
            .frame(width: 44, height: 44)
            .background(TyfeEditorialPalette.canvas)
            .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
            .asButton(.press) {
                presenter.setProjectArchived(project, isArchived: !project.isArchived)
            }
            .accessibilityLabel("\(project.isArchived ? "Restore" : "Archive") \(project.name)")
            .accessibilityIdentifier("project-archive-\(project.projectId)")
    }

    private func reorderHandle(_ project: ProjectModel, index: Int) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.headline.weight(.semibold))
            .foregroundStyle(TyfeEditorialPalette.muted)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onDrag {
                draggingProjectId = project.projectId
                lastReorderTargetId = nil
                return NSItemProvider(object: project.projectId as NSString)
            }
            .accessibilityLabel("Reorder \(project.name)")
            .accessibilityHint("Drag to change its position, or use Move up and Move down actions.")
            .accessibilityIdentifier("project-reorder-\(project.projectId)")
            .accessibilityAction(named: Text("Move up")) {
                reorderProject(project.projectId, toIndex: index - 1)
            }
            .accessibilityAction(named: Text("Move down")) {
                reorderProject(project.projectId, toIndex: index + 1)
            }
    }

    private func updateDropTarget(_ isTargeted: Bool, projectId: String) {
        guard let draggingProjectId else { return }
        if isTargeted {
            targetedProjectId = projectId
            guard lastReorderTargetId != projectId else { return }
            lastReorderTargetId = projectId
            guard draggingProjectId != projectId,
                  let targetIndex = presenter.projects.firstIndex(where: {
                      $0.projectId == projectId
                  }) else { return }
            reorderProject(draggingProjectId, toIndex: targetIndex)
        } else if targetedProjectId == projectId {
            targetedProjectId = nil
        }
    }

    private func reorderProject(_ projectId: String, toIndex: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            _ = presenter.reorderProject(projectId: projectId, toIndex: toIndex)
        }
    }

    private var addProjectButton: some View {
        Image(systemName: "plus")
            .font(.title3.weight(.black))
            .foregroundStyle(TyfeEditorialPalette.onAccent)
            .frame(width: 60, height: 60)
            .background(TyfeEditorialPalette.teal, in: Circle())
            .overlay {
                Circle()
                    .stroke(TyfeEditorialPalette.controlBorder, lineWidth: TyfeStroke.hairline)
            }
            .asButton(.press) {
                presentProjectForm(projectId: nil)
            }
            .accessibilityLabel("Add Space")
            .accessibilityIdentifier("today-project-add-button")
    }

    private var projectFormTitle: String {
        editingProjectId == nil ? "Create Space" : "Edit Space"
    }

    @ViewBuilder
    private var projectForm: some View {
        if let editingProjectId {
            if let project = presenter.projects.first(where: { $0.projectId == editingProjectId }) {
                TodayProjectFormView(project: project) { name, colorToken in
                    presenter.saveProject(projectId: editingProjectId, name: name, colorToken: colorToken)
                }
            } else {
                ContentUnavailableView("Space not found", systemImage: "folder")
            }
        } else {
            TodayProjectFormView(project: nil) { name, colorToken in
                presenter.saveProject(projectId: nil, name: name, colorToken: colorToken)
            }
        }
    }

    private func presentProjectForm(projectId: String?) {
        editingProjectId = projectId
        isProjectFormPresented = true
    }

    private func dismissProjectForm() {
        isProjectFormPresented = false
    }
}

extension CoreBuilder {
    func todayProjectManagementView(
        router: AnyRouter,
        delegate: TodayProjectManagementDelegate
    ) -> some View {
        TodayProjectManagementView(
            presenter: TodayProjectManagementPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }
}

extension CoreRouter {
    func showProjectManagementView(delegate: TodayProjectManagementDelegate) {
        router.showScreen(.fullScreenCover) { router in
            builder.todayProjectManagementView(router: router, delegate: delegate)
        }
    }
}
