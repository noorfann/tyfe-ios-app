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

                ScrollView {
                    VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                        projectListSection
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

                if presenter.projects.isEmpty {
                    Text("Create a Space to group Activities into a deck.")
                        .font(TyfeTypography.interface)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                }

                ForEach(presenter.projects) { project in
                    projectRow(project)
                    if project.id != presenter.projects.last?.id {
                        Rectangle()
                            .fill(TyfeEditorialPalette.controlBorder.opacity(0.35))
                            .frame(height: TyfeStroke.hairline)
                    }
                }
            }
        }
    }

    private func projectRow(_ project: ProjectModel) -> some View {
        HStack(spacing: TyfeSpacing.small) {
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
        .frame(minHeight: 52)
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
