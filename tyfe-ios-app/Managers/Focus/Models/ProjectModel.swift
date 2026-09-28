import Foundation

struct ProjectModel: Identifiable, Codable, Hashable {
    static let defaultIconToken = "folder.fill"
    static let defaultColorToken = "teal"

    let projectId: String
    let name: String
    let iconToken: String?
    let colorToken: String?

    var id: String {
        projectId
    }

    init(
        projectId: String,
        name: String,
        iconToken: String? = ProjectModel.defaultIconToken,
        colorToken: String? = ProjectModel.defaultColorToken
    ) {
        self.projectId = projectId
        self.name = name
        self.iconToken = iconToken
        self.colorToken = colorToken
    }

    var resolvedIconToken: String {
        iconToken.flatMap { $0.isEmpty ? nil : $0 } ?? Self.defaultIconToken
    }

    var resolvedColorToken: String {
        colorToken.flatMap { $0.isEmpty ? nil : $0 } ?? Self.defaultColorToken
    }

    static var mock: Self {
        ProjectModel(projectId: "project-writing", name: "Writing")
    }

    static var mocks: [Self] {
        [mock, ProjectModel(projectId: "project-home", name: "Home")]
    }
}
