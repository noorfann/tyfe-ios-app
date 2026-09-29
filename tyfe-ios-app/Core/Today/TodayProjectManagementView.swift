import SwiftUI
import SwiftfulUI

struct TodayProjectManagementView: View {

    @State private var presenter: TodayProjectManagementPresenter
    @State private var isProjectFormPresented = false
    @State private var editingProjectId: String?

    @Environment(\.dismiss) private var dismiss

    init(presenter: TodayProjectManagementPresenter) {
        _presenter = State(initialValue: presenter)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                TyfeEditorialPalette.canvas
                    .ignoresSafeArea()

                List {
                    activeProjectsSection
                    if !presenter.archivedProjects.isEmpty {
                        archivedProjectsSection
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .contentMargins(.bottom, 104, for: .scrollContent)

                addProjectButton
                    .padding(.trailing, TyfeSpacing.control)
                    .padding(.bottom, TyfeSpacing.control)
            }
            .navigationTitle("Spaces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityIdentifier("today-project-management-done")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
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

    private var activeProjectsSection: some View {
        Section {
            if presenter.activeProjects.isEmpty {
                emptyStateRow
            }

            ForEach(presenter.activeProjects, id: \.projectId) { project in
                projectRow(project)
            }
            .onMove { offsets, destination in
                _ = presenter.moveActiveProjects(fromOffsets: offsets, toOffset: destination)
            }
        } header: {
            sectionHeader("SPACES")
        }
    }

    private var archivedProjectsSection: some View {
        Section {
            ForEach(presenter.archivedProjects, id: \.projectId) { project in
                projectRow(project)
            }
        } header: {
            sectionHeader("ARCHIVED")
        }
    }

    private var emptyStateRow: some View {
        Text("Create a Space to group Activities into a deck.")
            .font(TyfeTypography.interface)
            .foregroundStyle(TyfeEditorialPalette.muted)
            .listRowBackground(TyfeEditorialPalette.paper)
    }

    private func projectRow(_ project: ProjectModel) -> some View {
        projectRowContent(project)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .asButton(.press) {
                presentProjectForm(projectId: project.projectId)
            }
            .accessibilityIdentifier("project-row-\(project.projectId)")
            .accessibilityLabel(
                "\(project.name), Space color \(ProjectColorOption.title(for: project.resolvedColorToken))"
            )
            .listRowBackground(TyfeEditorialPalette.paper)
            .listRowSeparatorTint(TyfeEditorialPalette.controlBorder.opacity(0.35))
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    presentProjectForm(projectId: project.projectId)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(TyfeEditorialPalette.teal)
                .accessibilityIdentifier("project-edit-\(project.projectId)")
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    presenter.onDeleteProjectPressed(project)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .accessibilityIdentifier("project-delete-\(project.projectId)")

                Button {
                    presenter.setProjectArchived(project, isArchived: !project.isArchived)
                } label: {
                    Label(
                        project.isArchived ? "Restore" : "Archive",
                        systemImage: project.isArchived ? "arrow.uturn.backward" : "archivebox"
                    )
                }
                .tint(TyfeEditorialPalette.olive)
                .accessibilityIdentifier("project-archive-\(project.projectId)")
            }
    }

    private func projectRowContent(_ project: ProjectModel) -> some View {
        HStack(spacing: TyfeSpacing.small) {
            RoundedRectangle(cornerRadius: 3)
                .fill(ProjectColorOption.color(for: project.resolvedColorToken))
                .frame(width: 14, height: 14)
                .accessibilityLabel("Space color, \(ProjectColorOption.title(for: project.resolvedColorToken))")

            Text(project.name)
                .font(TyfeTypography.interfaceStrong)
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(TyfeTypography.eyebrow)
            .tracking(1.1)
            .foregroundStyle(TyfeEditorialPalette.muted)
            .textCase(nil)
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
