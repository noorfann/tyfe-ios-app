---
name: creating-extension
description: Create a Swift extension file with the Type+EXT.swift naming convention in the Extensions/ folder. Use when the user asks to add an extension, add a helper method to an existing type, or extend a Foundation/SwiftUI/custom type.
---

# Creating Extension

Create a Swift extension file following the project's naming and folder conventions.

## Steps

1. Identify the type being extended (e.g., `String`, `Color`, `Array`, a custom model type)
2. Check if `Extensions/{TypeName}+EXT.swift` already exists — if so, add to that file instead of creating a new one
3. If new, create the file in `tyfe-ios-app/Extensions/`

## File Naming

All extension files follow: `{TypeName}+EXT.swift`

Examples: `String+EXT.swift`, `Color+EXT.swift`, `Date+EXT.swift`, `UserModel+EXT.swift`

## Template

```swift
import SwiftUI

extension {TypeName} {

}
```

## Key Patterns

- **Always check first** if `{TypeName}+EXT.swift` already exists — add to it rather than creating a duplicate
- **One file per type** — group all extensions for a type in a single `+EXT` file
- **Multiple extension blocks** in the same file are fine for grouping related functionality
- **Import**: use `import SwiftUI` (covers Foundation) unless the extension only needs `import Foundation`
- **Access level**: use `public` only if the type itself is public (e.g., `public extension Color`), otherwise use default internal access
- **No business logic** — extensions add convenience methods, computed properties, and static helpers, not app logic
- **Prefer after-object notation** — `myValue.doSomething()` over `DoSomething(myValue)` (instance methods over free functions)
- **Prefer computed properties** when there are no parameters — `myValue.asString` over `myValue.asString()`
- **Be explicit with naming** — do NOT abbreviate or shorten names, clarity over brevity (e.g., `replaceSpacesWithUnderscores` not `replaceSpaces`)
