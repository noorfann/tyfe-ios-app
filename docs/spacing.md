# Spacing roles

The shared variables in `design/tyfe.lib.pen` specify the spacing scale; `TyfeSpacing` in `Components/Views/TyfeDesignTokens.swift` implements it at runtime. Apply the semantic role by relationship, not by whichever numeric value happens to look close. Swift points and pen.dev logical pixels use identical values. See [the design library inventory](../design/README.md) for component mappings and native behavior contracts.

| Swift role | Points | Canvas variable | Use |
| --- | ---: | --- | --- |
| tightGap | 4 | tyfe-tight-gap | Title/caption, tightly related text |
| relatedGap | 8 | tyfe-related-gap | Related controls, icon/label pairs |
| itemGap | 16 | tyfe-item-gap | Cards, fields, list items |
| sectionGap | 24 | tyfe-section-gap | Separate content sections |
| majorGap | 32 | tyfe-major-gap | Explicit major transitions |
| screenInset | 16 | tyfe-screen-inset | Custom screen and sheet gutters |
| cardInset | 24 | tyfe-card-inset | Standard surface padding |
| compactCardInset | 12 | tyfe-compact-card-inset | Dense surfaces such as Habit cards |

The compatible primitives remain `unit = 4`, `small = 8`, `control = 16`, `card = 24`, and `section = 32`; `compact = 12` extends the scale. The old `section` primitive is 32, while the semantic `sectionGap` is 24. New layout callers use semantic names. Canvas keeps the old variables for compatibility and adds `tyfe-compact`.

Use explicit spacing on custom stacks and grids. A shared `TyfeSurfaceView` owns its inset; callers specify relationships between content and do not add another surface inset. The design-system gallery demonstrates title/caption, related controls, item spacing, and standard/compact surfaces.

## Habit grouping

The metric sits 24 pt above the content block. Archive control, period selector, and legend form one controls block with 8 pt internal gaps. Cards or the empty-state surface begin 16 pt below it; cards are 16 pt apart. The archive control retains its minimum 44 pt height. Active and archived data use the same layout. Accessibility period options retain 44 pt targets and 8 pt gaps; history text expands vertically.

## Intentional exceptions

Spacing tokens do not define control sizes, tile sizes, border widths, artwork offsets, or touch targets. Native List/Form rows, segmented controls, tab bars, safe areas, and their system-managed metrics retain platform layout. Live Activities are outside this migration. Space management reserves 104 pt for its floating control.

Named local geometry remains unchanged: 2 pt heatmap gaps in `HabitCardHistoryView`/`HabitHeatmapView`, 2 pt skipped-mark and scroll-indicator insets, 18 pt timer inner-ring inset, 1 pt crop-outline inset, and the Home motif's 3 pt gap/5 pt inset. Explicit zero gaps join contiguous artwork or progress segments. Today reserves 96 pt for floating controls; it is clearance rather than an item gap. Timer, crop, card-deck, and decorative dimensions retain their geometry.

Canvas's native status/navigation chrome keeps its device dimensions. Fraunces and Nunito Sans remain the existing Apple-font substitutions; Material Symbols Rounded remain the editable SF Symbol equivalents.

## Maintenance

Pen is the visual specification and SwiftUI is the runtime implementation. Update the shared variables or component origins in `design/tyfe.lib.pen`, the affected compositions in `design/tyfe.pen`, and corresponding SwiftUI together in one reviewed change. Preserve compatibility aliases and instance overrides. Use Pen tooling for all `.pen` changes, then inspect resolved layout and renders in both themes, at narrow widths and accessibility text sizes. Reopen both files to verify saved imports and references. Token tests cover semantic values and compatibility aliases. Non-rewriting strict SwiftLint and source inspection are the default checks for Swift changes; builds, tests, previews, and simulator runs require explicit authorization under repository policy.
