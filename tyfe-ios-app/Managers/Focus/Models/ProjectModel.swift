import Foundation

struct ProjectModel: Identifiable, Codable, Hashable {
    static let defaultIconToken = "folder.fill"
    static let defaultColorToken = "teal"

    let projectId: String
    let name: String
    let iconToken: String?
    let colorToken: String?
    let isArchived: Bool

    private enum CodingKeys: String, CodingKey {
        case projectId, name, iconToken, colorToken, isArchived
    }

    var id: String {
        projectId
    }

    init(
        projectId: String,
        name: String,
        iconToken: String? = ProjectModel.defaultIconToken,
        colorToken: String? = ProjectModel.defaultColorToken,
        isArchived: Bool = false
    ) {
        self.projectId = projectId
        self.name = name
        self.iconToken = iconToken
        self.colorToken = colorToken
        self.isArchived = isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            projectId: try container.decode(String.self, forKey: .projectId),
            name: try container.decode(String.self, forKey: .name),
            iconToken: try container.decodeIfPresent(String.self, forKey: .iconToken),
            colorToken: try container.decodeIfPresent(String.self, forKey: .colorToken),
            isArchived: try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        )
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
