---
name: creating-model
description: Scaffold a Codable data model with CodingKeys, eventParameters, and mock data. Use when the user asks to create a new model, data type, struct, or enum for the app. Supports both DataSyncModelProtocol models (for database syncing) and simple Codable models.
---

# Creating Model

Scaffold a data model with the correct conformances, CodingKeys, analytics parameters, and mock data.

## Steps

1. Get the model name from the user (PascalCase, e.g., "Post", "Message", "Avatar")
2. Determine the model type (see below)
3. Read [references/templates.md](references/templates.md) for the templates
4. Substitute `{ModelName}`, `{modelName}`, and `{modelname}` throughout
5. Determine the folder location (see below)
6. Create the file

## Choosing the Model Type

| Type | When to Use | Conformances |
|------|-------------|-------------|
| **Data Sync Model** | Model will be synced to/from a database via DataManagers | `DataSyncModelProtocol` (`StringIdentifiable`, `Codable`, `Sendable`) |
| **Simple Model** | Local config, UI state, or API response that isn't database-synced | `StringIdentifiable, Codable, Hashable` |
| **Enum Model** | Fixed set of options (AB test variants, categories, status) | `String, Codable, CaseIterable` |

If unclear, ask the user whether the model will be synced to a database.

## Folder Location

Models live under their related manager: `Managers/{ManagerName}/Models/`

- Check existing managers in `Managers/` to determine which manager owns this model
- If the model belongs to a new manager, suggest creating the manager first
- If unclear, ask the user which manager this model belongs to

## Key Patterns

- **Naming**: File and struct are `{ModelName}Model.swift` / `{ModelName}Model` — enum models omit the `Model` suffix
- **Data sync models must be `public struct`** with `public var id: String` — required by `DataSyncModelProtocol`
- **CodingKeys always use snake_case** raw values (e.g., `case firstName = "first_name"`)
- **`eventParameters`** — computed property mapping each property to a prefixed analytics key using CodingKeys raw values. Prefix with the model's lowercase name, max 8 characters (e.g., `"user_\(CodingKeys.email.rawValue)"`). Check existing models in `Managers/**/Models/` to ensure no other model uses the same prefix — if there's a conflict, abbreviate (e.g., "avatar" → "avtr", "message" → "msg")
- **`static var mock`** returns `mocks[0]` — `static var mocks` returns an array of realistic test instances
- **All properties should be optional** (with `?`) unless truly required — models from a database may have missing fields
- **`init` with all properties as parameters** — use default values of `nil` for optionals
- **`import SwiftfulDataManagers`** only for data sync models — simple models just need `import SwiftUI`
