# Model Templates

Substitute `{ModelName}` (PascalCase), `{modelName}` (camelCase), and `{modelname}` (lowercase, no separator) throughout.

## Data Sync Model (used with DataManagers)

For models synced via `DocumentSyncEngine` or `CollectionSyncEngine`. Conforms to `DataSyncModelProtocol` which includes `StringIdentifiable`, `Codable`, `Sendable`.

```swift
import SwiftUI
import SwiftfulDataManagers

public struct {ModelName}Model: DataSyncModelProtocol {
    public var id: String {
        {modelName}Id
    }

    let {modelName}Id: String

    init(
        {modelName}Id: String
    ) {
        self.{modelName}Id = {modelName}Id
    }

    enum CodingKeys: String, CodingKey {
        case {modelName}Id = "{modelname}_id"
    }

    public var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "{modelname}_\(CodingKeys.{modelName}Id.rawValue)": {modelName}Id
        ]
        return dict.compactMapValues({ $0 })
    }

    static var mock: Self {
        mocks[0]
    }

    static var mocks: [Self] {
        [
            {ModelName}Model({modelName}Id: "mock_1"),
            {ModelName}Model({modelName}Id: "mock_2"),
            {ModelName}Model({modelName}Id: "mock_3")
        ]
    }
}
```

---

## Simple Model (not synced with DataManagers)

For local-only or config models that don't need database syncing.

```swift
import SwiftUI

struct {ModelName}Model: StringIdentifiable, Codable, Hashable {
    var id: String {
        {modelName}Id
    }

    let {modelName}Id: String

    init(
        {modelName}Id: String
    ) {
        self.{modelName}Id = {modelName}Id
    }

    enum CodingKeys: String, CodingKey {
        case {modelName}Id = "{modelname}_id"
    }

    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "{modelname}_\(CodingKeys.{modelName}Id.rawValue)": {modelName}Id
        ]
        return dict.compactMapValues({ $0 })
    }

    static var mock: Self {
        mocks[0]
    }

    static var mocks: [Self] {
        [
            {ModelName}Model({modelName}Id: "mock_1"),
            {ModelName}Model({modelName}Id: "mock_2"),
            {ModelName}Model({modelName}Id: "mock_3")
        ]
    }
}
```

---

## Enum Model

For models that represent a fixed set of options (e.g., AB test variants, categories).

```swift
import SwiftUI

enum {ModelName}: String, Codable, CaseIterable {
    case optionA, optionB

    static var `default`: Self {
        .optionA
    }
}
```
