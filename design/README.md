# Tyfe Pen design library

[tyfe.lib.pen](tyfe.lib.pen) contains shared variables, reusable component origins, state examples, and native behavior contracts. [tyfe.pen](tyfe.pen) imports that library and contains the preserved Today canvas and app composition examples. Pen specifies visual design; SwiftUI remains the runtime implementation. This migration changes no Swift source, business logic, component API, navigation, persistence, widgets, or Live Activities.

The former workspace-root canvas was relocated into this repository. Its three Today compositions retain their original screen IDs: Session `vvgGg`, To Do `YdsWT`, and Habit `kxcK4`. Their component references now point to the shared library. The original empty frame is preserved. Component IDs below belong to `tyfe.lib.pen` unless explicitly marked as a composition. The importing document currently qualifies them with `7:`; that import alias is document-local and is not part of a component's stable ID. The library contains 201 reusable origins/reference cards and 127 variables; the composition file has 813 linked instances and no local duplicate origins.

## Library organization

| Board | ID | Contents |
| --- | --- | --- |
| Existing Today origins | `Wjtp2` | Original header, selectors, chrome, card, metric, date navigator and actions |
| 01 Foundations and primitives | `zdLT3` | Surfaces, actions, fields, pills and sheet shell |
| 02 Habit periods and completion states | `f9zVva` | Compact cards, date tiles, calendars, Year strip and readable history |
| 03 Feedback and activity patterns | `pDMkh` | Loading/empty/offline/error, activity cards, badges, motifs and coachmark |
| 04 Focus and Rest | `P2iMT` | Timer dial, lifecycle states and four daypart backgrounds |
| 05 Rewards and claims | `fxGrr` | Coupon availability and claim lifecycle states |
| 06 Circles | `ewCRk` | Enable, member rows, owner controls, name validation, invite and errors |
| 07 Streak | `iIIJG` | Hero outcomes, growth tiles, stats, freeze bank, week and month activity |
| 08 Today, forms and identity | `U6AjC` | Plan/To Do states, checklist, To Do repeat, avatars and metrics |
| 09 Native controls and behavior contracts | `IAlGK` | Explicit native controls, motion, gestures, crop, presentation and typography references |
| 10 Habit width/theme/accessibility examples | `QOm3E` | 320/390 viewport widths, Light/Dark, all three periods, long labels, archived/new/unscheduled and expanded history |
| 11 Family verification examples | `n1mDX` | Shared families at 320/390 component widths in Light/Dark |
| 12 Accessibility family examples | `r6HG7A` | Expanded fields, actions, activity/plan/claim cards, rows, feedback, stats and modal |
| 13 To Do forms, history and recovery | `l5GdU` | To Do form and sheets, checklist editor, history records, native menus, recovery, and task states |
| 14 Habit and Session feature patterns | `sWR1l` | Habit settings/repeat/form/history, Session count/add/edit/checklist forms, Focus outcomes and native confirmations |
| 15 To Do repeat | `au5Fo` | Daily/weekday forms, invalid weekdays, narrow/Dark/accessibility repeat layouts, and carry-forward/credit contracts |
| 16 Minimal tab summaries | `DQxce` | Shared 28-point progress ring; empty, partial, complete, and accessibility summary rows; width and theme examples |
| Today / Minimal summary verification | `K3dI1c` in `tyfe.pen` | Linked rows at 320/390 points, Light/Dark, long counts, accessibility, and skipped-only states |
| App composition examples | `ufqdv` in `tyfe.pen` | Filled Today, Focus/Rest, Rewards, Circles and Streak assembled from library instances |
| To Do / Feature flow | `kSrz3` in `tyfe.pen` | Creation, editing, completion, history/reopening, failures, native contracts, and layout examples |
| Habit / Feature flow | `A3SGZ` in `tyfe.pen` | Creation, repeat, Week/Month/Year, complete/undo, skip/undo, history/edit, archive/restore, failures and accessibility |
| Session / Feature flow | `X0YnvD` in `tyfe.pen` | Creation/count/deck, edit/remove, Focus/confirmation/completion/rest, rewards, abandon, existing checklists, historical days and failures |

## Minimal tab summaries

The top summary cards in the three Today compositions and their feature flows have been replaced by 63 linked transparent rows. SwiftUI implements the same pattern through `TyfeSummaryRowView`. Individual Session, To Do, and Habit content cards remain unchanged. Historical Session checklist counts use the same row pattern. Existing screen IDs, board positions, count wording, Spaces, selectors, and actions are preserved. The older metric origins remain available for unrelated compositions and the design-system gallery.

Each row has a 28-point progress ring with a 3-point band, a label, and a trailing readable count. Eight-point gaps and eight-point vertical padding give a 44-point minimum height without a background, border, shadow, or decorative icon. Counts may wrap when narrow; at accessibility sizes, the label and count stack beside the ring. The ring is display-only and belongs to the same accessibility summary as the readable count.

Session progress is completed divided by planned; legacy checklist progress is checked divided by planned items. To Do progress is done divided by done plus open in the selected Space. Habit progress is completed divided by due, excluding skipped, while the count retains the skipped value. Fill starts at twelve o'clock and advances clockwise, clamped to 0–100%; a zero denominator, including skipped-only Habits, uses an empty subdued ring. Session/Habit use teal; To Do/checklist use saffron. All colors and typography reference existing library variables.

Reusable origins are the small ring `tPIRK`, empty row `bhdfB`, partial row `d2PXs`, complete row `AJhno`, and accessibility row `L3wuRq`. Board `DQxce` holds the library examples. Composition board `K3dI1c` covers all three labels, Light/Dark at 320/390-point widths, long counts, empty/partial/complete/skipped-only states, and stacked accessibility text. Both files are verified through resolved layout checks and renders, then saved and reopened to confirm shared references.

Session no longer displays the time-of-day greeting or the accompanying focus guidance; historical day overview text remains. Focus daypart greetings remain unchanged. Session, To Do, Habit, Reward, Space, and Circle creation sheets use the 80% native detent, with scrollable content. To Do and Habit edit forms retain their large detent; Session details and other non-creation sheets retain their existing detents. Pen sheet content is expanded for inspection rather than clipped to the native viewport. SwiftUI previews cover normal and accessibility summary rows; runtime execution remains opt-in under repository policy.

## Foundations

The library defines Light and Dark on the `mode` theme axis. Imported variables and theme axes acquire the importing document's alias, for example `$p:tyfe-paper` and `p:mode`. Select the appropriate theme on the containing frame; do not replace themed fills with fixed colors. Brand accents and Streak Board stay constant where the Swift palette does.

| Swift foundation | Pen variables / reference | Contract |
| --- | --- | --- |
| `TyfeEditorialPalette` | `tyfe-canvas`, `paper`, `ink`, `muted`, `navy`, `charcoal`, `border`, `control-border`, `success`, `warning`, `error`, `disabled-fill`, `disabled-ink`; semantic roles `iBHkO` | Adaptive foreground/background/border colors preserve the current Light/Dark palette |
| Brand and contrast colors | `tyfe-focus`, `olive`, `slate-blue`, `terracotta`, `saffron`, `teal`, `on-accent`, `board`, `on-board`, `error-fill`, `on-error` | Preserve existing accents and their contrasting foregrounds |
| Compatibility aliases | `tyfe-slate`, `disabled`, `sage`, `lavender`, `sky`, `orange`, `amber`, `magenta`, `cyan`, `on-light` | Alias existing variables rather than introducing independent values |
| `TyfeSpacing` | `tyfe-unit=4`, `small=8`, `compact=12`, `control=16`, `card=24`, `section=32`; semantic `tight-gap`, `related-gap`, `item-gap`, `section-gap`, `major-gap`, `screen-inset`, `card-inset`, `compact-card-inset` | Semantic values are 4/8/16/24/32/16/24/12; legacy section remains 32. See [spacing guidance](../docs/spacing.md) |
| `TyfeRadius`, `TyfeStroke` | `tyfe-control-radius=16`, `card-radius=20`, `surface-radius=28`, `phone-radius=40`; `hairline=1`, `stroke=2`, `emphasis=3` | Control/card shapes and native geometry remain distinct |
| `TyfeShadow` | `tyfe-shadow-x=3`, `shadow-y=4`, `shadow-radius=0`, `shadow-opacity=.16`, `shadow-color=#00000029` | Existing hard offset shadow |
| `TyfeTypography` | `tyfe-heading-font`, `interface-font`, `timer-font`; display/interface/caption size variables; `gsxot` | Fraunces substitutes for system serif display; Nunito Sans substitutes for rounded interface; Roboto Mono substitutes for monospaced timer digits. Runtime semantic styles and Dynamic Type remain authoritative |
| `TyfeMotion` | `tyfe-motion-normal-duration=.28`, `motion-reduced-duration=0`; `V5dOR9` | Ease-in/out and Reduce Motion contracts are documented, not executed by Pen |
| `TyfeSurfaceRole` | `z7CFZU`, `P9d8vX`, `Wm0q3`, `IEgn5`, `m8lIT`, `Cp1vZ`, `UZ5Pz` | Warm Canvas, Paper, Disabled, Focus Chamber, Celebration, Warning, Streak Board; compact inset variant `aBEiW` |
| `FocusDaypart`, `FocusDaypartVisualStyle`, `FocusDaypartPalette` | `focus-{morning,midday,afternoon,night}-*`; `BGxls`, `NimCa`, `WISRH`, `E0qXQ` | Daypart card colors, focus accents and background base/highlight/depth/horizon values; afternoon/night include radial overlay examples |
| Named geometry | `tyfe-touch-target=44`, `field-height=52`, `habit-numbered-tile=28`, `habit-year-tile=10`, `heatmap-gap=2` | Preserve source geometry; spacing tokens do not replace geometry constants |

Material Symbols Rounded are the existing editable SF Symbol substitutions. Emoji rendering differs from Apple Color Emoji. Native materials, SF fonts, symbol palettes, system controls, animation and Dynamic Type are specified through examples and contracts, not exact raster substitutes. Use the corresponding Swift symbol for the native equivalent.

## Shared component inventory

Status **Linked** means a reusable component origin exists and compositions can instantiate it. **Native** and **Behavior** mean an explicit reusable reference card accounts for platform rendering or executable behavior. All dependencies inherit foundations unless additional dependencies are listed. Swift files are under `tyfe-ios-app/Components/`; names identify their existing declarations without relocating runtime code.

| Swift symbol | Pen IDs | Implemented variants | Additional dependencies | Status |
| --- | --- | --- | --- | --- |
| `TyfeSurfaceView` | `z7CFZU`, `P9d8vX`, `Wm0q3`, `IEgn5`, `m8lIT`, `Cp1vZ`, `UZ5Pz`, `aBEiW` | Seven roles; 24pt default and 12pt compact; glass/Reduce Transparency contract | Content slot; native material | Linked |
| `TyfeActionButtonView` | `thouy`, `p1ZTyz`, `pGQQ4`, `L5nJ4q`, `IMbWe` | Primary, secondary, destructive, disabled; optional icon | 44pt minimum action height | Linked |
| `TyfeTextFieldView` | `FAoxC`, `F6LRe`, `fysk6` | Empty, filled, secure; native focus/keyboard | Native TextField/SecureField | Linked + Native `OtA9i` |
| `TyfePillView`, `TyfePillTone` | `CxYgd`, `LtqLm`, `NyYcO`, `iK9dp`, `DeXYu`, `QVhdR` | Neutral, accent, success, warning, error, dark; optional symbol | 28pt pill, semantic foreground/tints | Linked |
| `TyfeStateBadgeView` | `zLqSK`, `WmT00`, `ODEcF`, `dEUlo` | Ready, focusing, completed, abandoned | Pill tones | Linked |
| `TyfeStatusView`, `TyfeStatusKind` | `avUVy`, `PKEX7`, `k3oRh`, `m8CuA` | Loading, empty, offline, error; optional retry/create action | Surface, Action; native spinner | Linked |
| `TyfeProgressStatusBarView` | `oFHWv` | Progress and native menu/action behavior | Preserve existing 40pt bar; native menu | Linked + Native `OtA9i` |
| `TyfeBottomSheet` | `F6hzZa` | Generic content slot, native detents and dismiss | Surface/slot `BlX8h`, presentation `b4HmbT` | Linked + Native |
| `CustomModalView` | `xzgKv` | Title, optional subtitle, primary and secondary actions | Native background/accent/system font; min44pt actions | Linked |
| `TyfeActivityCardView` | `Jr4Mu`, `SJkmy` | Flexible and scheduled metadata; Start Focus | Surface, Action, 48pt icon tile | Linked |
| `TyfeMetricCardView` | `thcrs`, `zNpyp` | Centered/no detail and leading/detail; retained for existing runtime and unrelated library examples | Surface, optional symbol/detail | Linked |
| `TyfeSummaryRowView` | `tPIRK`, `bhdfB`, `d2PXs`, `AJhno`, `L3wuRq` | 28-point ring; empty, partial, complete, and stacked accessibility rows | Existing colors, interface typography, 8-point gaps; display-only | Linked |
| `TyfeCoachmarkView` | `UacLr` | Deck guidance and optional navigation hint | Motif, Surface | Linked |
| `TyfeMotifView`, `TyfeMotifKind` | `eh2x1`, `x16BF`, `tjOcB` | Tile, badge, completion decoration | Native SF Symbol substitution | Linked |
| `TyfeTierLegendView` | `c6I6Yw` | Credit/minute tiers | Metadata typography | Linked |
| `TyfeTimerDialView` | `ytEgR` | Ready/running/finished progress, time/caption overrides | 248pt nominal dial, 10pt track, 18pt inner inset; native accessibility label/value | Linked |
| `TyfeFocusTimerView` | `UPNmn`, `B0z7vs`, `nlyaH`, `Eu7mJ` | Ready, running, completed, abandoned; daypart colors | Dial, Action, Pill, Surface; motion contract | Linked |
| `TyfeRestTimerView` | `M6DI98` | Rest countdown and Finish Rest | Dial, Action, daypart colors | Linked |
| `TyfeFocusStatusPillView` | `Q5pbOn`, `r7qJL` | Available and focusing | Pill | Linked |
| `FocusDaypartBackground` | `BGxls`, `NimCa`, `WISRH`, `E0qXQ` | Morning, midday, afternoon, night | Daypart variables; decorative/accessibility-hidden | Linked |
| `FocusConfettiView` | `V5dOR9` | Completion overlay and existing Reduce Motion behavior | Native transient particles | Behavior |
| `TyfeRewardCardView` | `IwWVF`, `mQ2YS`, `ETGIv`, `VpGBf` | Available, insufficient balance, unavailable, Focus active | Coupon, Pill, Action; scaled92pt stub | Linked |
| `TyfeCouponShape`, `TyfePerforationLine` | `IwWVF` outline `dX2R7`; reusable coupon family above | 20pt corners, 10pt tear notches, stub offset; perforation5/4; unavailable border7/5 | Editable outline path and repeated dash primitives | Linked; native dashed border contract |
| `TyfeClaimCardView` | `E8uX89`, `Ruefe`, `sYqXn`, `sI0jz` | Ready, ready blocked by Focus, active, expired | Surface, Action, timer typography | Linked |
| `TyfeCircleEnableCardView` | `BS7kH` | Enable/private progression explanation | Surface, Action | Linked |
| `TyfeCirclePillRowView` | `T97u2N` | Circle selection row | Pill/selection styling | Linked |
| `TyfeCircleNameSheetCardView` | `L89Vcw`, `oFVYt` | Empty/disabled and valid/save | Field, Action, Surface | Linked |
| `TyfeCircleErrorCardView` | `U8dI50` | Social errors and retry | Surface, Action | Linked |
| `TyfeCircleMemberRowView` | `BDNj1`, `QNCgV`, `Djfmw`, `G93fx` | Self, member, viewer-owner removal, missing progress; unsent/sent cheers | 40pt avatar, Pill, three44pt cheer targets; native images | Linked |
| `TyfeCircleInviteCardView` | `HnWj3`, `tlRjT` | Code and copied; single use, expiry text | Surface, Action; copy feedback resets after2s | Linked |
| `CheerRainView` | `V5dOR9` | Transient cheer overlay | Native emoji/animation | Behavior |
| `DeckSwipeGesture` | `mBfBt` | Drag navigation and existing spring/threshold contract | Native gesture; card/scroll interactions | Behavior |
| `ImageLoaderView` | `JGe4x` | Loading, success, failure; remote image/resize | Native image phases | Native |
| `TyfeDesignSystemGalleryView` | Boards01–09 | Component composition gallery | Linked families | Composition |
| `TyfeCirclesGalleryView` | `ewCRk` | Circles composition gallery | Linked Circles family | Composition |

## Feature-local pattern inventory

Swift files are under `tyfe-ios-app/Core/`. The existing symbols remain feature-owned. Grouped rows describe composed patterns rather than new runtime abstractions.

| Swift symbol / pattern | Pen IDs | Variants and behavior | Dependencies | Status |
| --- | --- | --- | --- | --- |
| `HabitCardView` | `xiVEy`, `K8wPSf`, `jZDkc`, `yOkFQ`, `JPfNi`, `pKIvn`, `PNBtK` | Week/Month/Year; completed/new/archived/unscheduled; long title/schedule; compact footer and stacked fallback | Compact Surface, history,44pt Complete/Skip | Linked |
| `HabitCardHistoryView` | `lPB4Y`, `xgQNy`, `GL7LY`, `HWIRy`, `DXQEK` | Monday–Sunday; Monday-first month with subdued padding; Jan–Dec scrolling week columns; month-grouped accessible date/status text | Tile family, local calendar; display-only | Linked + Behavior |
| `HabitTileView` | `jhMlA`, `I0Pg4y`, `wWKzg`, `cUmmU`, `zTvrm`, `OhwGg`, `AEz3I`, `k8Iu5M` | Completed/pending/skipped/missed/future/unscheduled; today outline | 28pt numbered tiles; centered 1pt skipped mark with 2pt inset; future/unscheduled opacity 0.35; completed text onAccent | Linked |
| `HabitHeatmapView` | `DXQEK`, `GL7LY` | Detail retains12pt tiles and2pt gaps; Today Year uses10pt. Detail month selection stays independent | Native scrolling/paging; tile states | Behavior/reference |
| `TodayHabitView` period selector, archive control and completion legend | `McAep`, `c3gDA`, `DXQEK` | Week/Month/Year selection, active/archived lists; accessibility options44pt | Cards; native archive control | Linked + Native |
| `TodayPlanCardView` | `NypLR`, `i8AfO`, `QiZjT`, `k2qDRy`, `YyMxO`, `jsJXn` | Next/in progress/complete/reward blocked/historical/checklist | Action, Surface, metadata | Linked |
| `TodayTodoView.taskCard` and checklist rows | `kr24y`, `NoUX8`, `vr4kC`, `RchEe`, `m3nWGm`, `StKZ5` | Open/completed/checklist, partial/final checklist, retained award | Surface, injected completion actions; 44pt controls | Linked |
| `TodayActivityDeckView` | `mBfBt`, `ufqdv` composition | Card deck and swipe transitions | Plan cards, native gesture | Behavior + Composition |
| `TodayProjectDeckTabsView` | `jiFXn` | Spaces and selected accent; management action | Pills, native horizontal scrolling | Linked |
| `TodayDateNavigatorView` | `RhPFr` | Current/historical dates; previous/next controls | Native local date labels/actions | Linked |
| `TodayHistoricalEmptyView` | `AyTeU`, `wR4L9` | No activity; no completions | Surface | Linked |
| `ChecklistItemsEditorView` | `x3ukGu` | Locked/open item, add/delete and incomplete draft guidance | Field,44pt actions; native focus | Linked |
| `TodoRepeatPickerView`, `TodoRepeatPickerPreview` | `jkAaq`, `MdsII`, `xZ29J`, `YaXNK` | Never/every day/certain days/invalid | Surface, adaptive 44pt choices/weekdays, locale weekday order | Linked |
| Former `ActivityTypePickerView` | Former `ZcuBI` | Unreachable Session/Checklist conversion selector | Source and unreferenced origin removed | Removed |
| `EffortCreditPicker`, `EffortSpacePicker` | `OtA9i`, `ETP39`, `FWYkM` | Native menu/picker choices and selected value; To Do default 0.5, choices 0.5/1/1.5/2 | Native Menu/Picker | Linked + Native |
| `TodayProjectFormView` | `KGgSl` | Name validation, preset3-column colors, custom ColorPicker, Save/Cancel | Fields, native Form/ColorPicker | Native composition |
| `HabitFormView` | `GC5fQ`, `piS9S`, `yO0ds`, `CqmTN`, `QBlX6`, `I9bS6a`, `L4Bj4`, `meUob` | Title/Space/icon/color/credit/repeat; blank/valid/weekday validation; edit/archive from tomorrow | Fields, repeat, native picker/toggle | Linked + Native |
| `TodoFormView` | `KorMI`, `DEm9q`, `prE1l`, `HRqdH`, `Qbag2`, `Du4wn`, `U5gUm` | Blank/valid/checklist/invalid sheets; optional item addition/removal; title and empty-item validation | Field, Action, Surface, Sheet, native pickers; no per-item credits | Linked + Native |
| `TodayAddActivitySheet`, `TodayActivityDetailSheet`, `TodayEffortSheets` | `g9c3ar`, `NYq7J`, `mZFkZ`, `i1cKAV`, `ZeBcw`, `RQinv`, `xC2HB`, `h9kno`, `XdnC2`, `cmdvt`, `gyihT`, `F6hzZa` | Session add/edit/count, existing checklist editing, native large detents | Field, Surface, Action, Session checklist, native Space picker | Linked + Native |
| `HabitDetailView` | `rXyRw`, `JwZnD`, `xnQtC`, `DXQEK`, `c3gDA` | Historical month paging, edit, streak counters, full-history heatmap,36pt month cells and today actions | Native navigation/sheets; detail history | Linked + Native |
| `TodayProjectManagementView` | `gyihT`, `OtA9i` | Native Space management/edit/delete confirmation, floating control clearance | Native List/alert, Space selector | Native composition |
| `RewardsCreateRewardSheet` | `KGgSl`, `gyihT` | Name, duration tier/cost and Save/Cancel | Native Form/Picker; Field | Native composition |
| `TyfeStreakHeroView` | `xRJ6F`, `uDHgm`, `w0VnaA`, `AerGZ`, `HuEOH` | Start/secured/open/rebuild/rest | Streak Board, count, fire/fallback | Linked |
| `TyfeStreakFireView`, `TyfeStreakGrowthTilesView` | `k8Czg`, `V5dOR9` | Existing fire loop0.8 speed, static growth fallback | Decorative native animation; hidden from accessibility | Linked + Behavior |
| `TyfeStreakStatsView` | `gL2im` | Longest run | Surface, display typography | Linked |
| `TyfeStreakFreezeBankView` | `Q6G2z`, `iloUU`, `X66nr` | 0/2/3 freezes | Surface, slot geometry | Linked |
| `TyfeStreakWeekTrailView`, `TyfeStreakDayTile` | `cvD31`, `Qrmze`, `JAXul`, `S0js7`, `FQOnQ`, `pMhiQ` | Focus/freeze/open today/rest/empty | Native date/accessibility labels | Linked |
| `StreakMonthCalendarView`, `StreakDayCell` | `K2ugQh`, `OtA9i` | Month activity, selected/current date; native loading/error/paging |32pt days,14pt event symbols; native actions | Linked + Native |
| `EditorialMetricCard` | `vpd2p` | Home value, detail and native symbol | Surface, typography | Linked |
| `CircleAvatar` | `IDDX6` | Circle initial/avatar32pt | Native image/fallback | Linked |
| `ProfileAvatarView` | `zPttF`, `JGe4x` | Profile image or initials64pt | Native image phases | Linked + Native |
| `ProfileCropEditor`, `CropCircleMask` | `JGe4x` | Pinch/drag/clamp, crop mask and PhotosPicker | Native image/gestures/permission presentation | Native + Behavior |
| `ProgressItemCard`, `ProgressExampleView` | `PDE1i`, `gyihT` | Development record, progress, metadata, timestamps and native delete | Native progress/gray/blue styling; no production redesign | Linked + Native composition |

## To Do flow and component inventory

`To Do / Feature flow` (`kSrz3`) starts at x=2406, y=641 in `tyfe.pen`. The existing Today compositions remain in place. Main screens use 390pt Light layouts and 120pt connector gutters. Screens show expanded scrolling content; native sheet detents, keyboards, menu placement, safe areas, and system alerts are documented beside the flow rather than simulated as an interactive prototype.

| Swift source / pattern | Library origin IDs | Variants and dependencies | Status |
| --- | --- | --- | --- |
| `TodoFormView` content | `KorMI` | Task settings, optional checklist, Save; Surface, Field, Action, native pickers | Linked |
| `TodoFormView` checklist section | `Du4wn`, `U5gUm` | Item field/remove target, Add item, explanation; populated/empty; no per-item credits | Linked |
| `TodayEffortSheets` To Do presentation | `DEm9q`, `prE1l`, `HRqdH`, `Qbag2` | Blank, valid, checklist, invalid checklist; composed Sheet shell and form | Linked + Native |
| `EffortSpacePicker`, `EffortCreditPicker` | `ETP39`, `FWYkM` | Selected values and separate native menu choices; device-native rendering | Linked + Native |
| `TodayTodoView.historyRow` | `HlGcZ`, `lYCHK` | Title snapshot, local date/time, optional Undone suffix | Linked |
| `TodayTodoView` empty open list | `ZljDJ` | Guidance and Add To Do; Surface and Action | Linked |
| `TodayTodoView` history disclosure | `F8UOcA` | Collapsed/expanded label overrides; minimum44pt action | Linked |
| `TodayTodoView.taskCard` state variants | `RchEe`, `m3nWGm`, `StKZ5` | Partial checklist, completed checklist, reopened retained award; existing To Do card origins | Linked |
| `TodayView` preparation failure | `jYXGr` | Existing error copy and Try again; Surface and Action | Linked |
| `TodayEffortPresenter` save alert | `u8YM7` | Native Could not save alert, OK, representative save failure or exact insufficient-credit undo message | Linked + Native |

All 18 added origins live on board `l5GdU`. The To Do checklist uses its own source-specific editor; `x3ukGu` remains the separate Session checklist editor with its existing behavior.

| Flow row | Composition ID | Covered transitions |
| --- | --- | --- |
| 01 Creation | `p8m28` | Empty list, Add To Do/FAB, blank sheet, title input, Save, open card |
| 02 Optional checklist | `AXkFi` | Add blank item, disabled Save, enter item title, add another item and Save; separate minus/removal branch restores an empty optional checklist and enabled Save |
| 03 Editing | `jgwWF` | Pencil, prefilled sheet, edit/Save, updated list; separate Close/swipe branch `HA9AZ` preserves the original task |
| 04 Simple completion | `zvhe5` | Circle, completed state, history disclosure, completed card and dated record |
| 05 Checklist completion | `g7ElyL` | Disabled parent control, first item, partial checklist, final item, parent completion |
| 06 History and reopening | `XfEO9` | Newest-first records, Undone, parent reopen, reset checklist, same-day reversal; labeled alternative for retained previous-day award and Already rewarded; hide history |
| 07 Failures and recovery | `dY9mH` | Invalid draft, save failure retaining the form, OK/retry, insufficient-credit undo preserving completion, preparation failure with Try again and disabled FAB |
| 08 Native menus and contracts | `cu2AT` | Space/credit choices and adjacent native interaction, scrolling, dismissal, and credit rules |
| 09 Layout/accessibility examples | `CJmRP` | Dark390, Light320, Dark320, long task/item/history labels, invalid/partial states, and expanded accessibility typography |

Tasks stay filtered by Space and ordered by creation time; completed history stays newest first. The default task credit is0.5, with0.5/1/1.5/2 choices. Credits belong to the whole task. All checklist items must complete before the parent completes; reopening clears all item completion. Same-day reopening reverses that award and marks its record Undone. Previous-day awards remain, so the reopened card reads Already rewarded and later completion does not grant another award. Insufficient balance prevents undo atomically. Title and item fields use native single-line editing, including horizontal scrolling; task and history labels wrap. Save is disabled for a trimmed empty title or any blank checklist title.

Resolved visible-layout checks found no unintended clipping in the new library family or flow. The native undo alert intentionally clips its retained, expanded underlying scroll content to the390×844 viewport; the alert itself fits. Disabled descendants are excluded from visible-layout checks. Narrow picker rows expand to52pt to accommodate wrapped labels, and accessibility examples retain at least44pt actions with expanded rows. Pen renders cover forms, task/checklist states, history, native alerts, both themes, narrow widths, and expanded text. These examples document current SwiftUI behavior; no runtime APIs or features were changed.

## Habit and Session flows

`Habit / Feature flow` (`A3SGZ`, x=5004, y=641) and `Session / Feature flow` (`X0YnvD`, x=7602, y=641) continue to the right of To Do. Each board is2478pt wide with390pt Light main examples and120pt connector gutters. Existing compositions remain untouched. These two flows use an October7,2026 local-date fixture; separate branch annotations identify alternatives and next-day transitions. The source files remain the authority for executable behavior.

The following26 additional reusable origins live on board `sWR1l`. All are linked to existing foundations and component instances; native menus, alerts, toggle rendering, text editing, gestures, scrolling and motion remain documented platform behavior.

| Swift symbol / pattern | Origin IDs | States and dependencies | Status |
| --- | --- | --- | --- |
| `HabitFormView` settings | `GC5fQ` | Title, Space, Icon, Color and task-level credit; Surface, Field, native menu rows | Linked + Native |
| `HabitFormView` repeat/archive section | `piS9S` | Every day, adaptive selected weekdays,44pt weekday targets, native archive toggle and tomorrow rule | Linked + Native |
| `HabitFormView` content | `yO0ds` | Settings, repeat, Save Habit; source title/day validation | Linked |
| `TodayEffortSheets` Habit form | `CqmTN`, `QBlX6`, `I9bS6a`, `L4Bj4`, `meUob` | Blank, valid, selected weekdays, invalid empty weekdays, edit/archive; Sheet shell and Habit form | Linked + Native |
| `TodayHabitView` empty list | `jvY8b` | Active/archived text override and Add Habit; Surface and Action | Linked |
| `HabitDetailView` content/calendar/presentation | `rXyRw`, `xnQtC`, `JwZnD` | Title/edit, current/best streak,12pt full-history tile sample,36pt numbered calendar, today Complete/Skip; large history sheet | Linked + Native |
| Session activity settings | `g9c3ar` | `TodayAddActivitySheet`/`TodayActivityDetailSheet` title, existing activity type label and native Space menu | Linked + Native |
| Session count/duration control | `NYq7J` |48pt plus/minus, planned count/minutes and completed count; disabled minimum | Linked |
| `TodayAddActivitySheet` content/presentation | `mZFkZ`, `i1cKAV`, `ZeBcw` | Blank/valid, count and Add to Today; large Sheet shell | Linked + Native |
| `TodayActivityDetailSheet` content/presentation | `RQinv`, `xC2HB`, `h9kno` | Editable/with progress, count minimum, Save Changes, Remove only before completion | Linked + Native |
| Existing Session checklist details | `XdnC2`, `cmdvt` | Session checklist editor `x3ukGu`, native per-item credit menus, checked-item delete lock, Save | Linked + Native |
| `FocusView` outcome | `s7sIo`, `OoWoc` | Completed/rest pending or completed, abandoned; Surface, Actions, static native artwork equivalent | Linked + Behavior |
| `FocusPresenter` native confirmations | `l8LDP0`, `ZGjgh` | Exact Begin Focus and Abandon alert copy and actions; native system rendering | Linked + Native |

| Habit row | Composition ID | Covered behavior |
| --- | --- | --- |
|01 Creation | `VlZ2x` | Empty list, Add Habit/FAB, blank/valid form, saved new habit; defaults Growth/Teal/0.5/Every day |
|02 Repeat | `HUrVH` | Every day, no weekday validation, selected weekdays, Save and pending scheduled day |
|03 Periods | `GieoH` | Week, Month, horizontally scrolling Year; shared remembered preference and preserved today actions |
|04 Complete/undo | `GLlZi` | Pending, completed metric/tile/streak, award and reversal |
|05 Skip/undo skip | `lT5GP` | Skipped dash, skipped denominator, Undo skip and pending restoration |
|06 History/edit | `ftPj2`, `b3KItg` | Title entry, current-month history, Pencil/dismiss handoff, Save; previous month and close preserve Today period |
|07 Archive/restore | `m1vUE` | Archive from tomorrow, next-day active/archived lists, historical browsing and unarchive draft |
|08 Failures/contracts | `LAS4K` | Retained form error, atomic insufficient-credit undo, preparation Retry/FAB disabled, native menu choices and local-date contracts |
|09 Layout/accessibility | `gvYpC` | Light320 adaptive weekday grid, Dark390/320, long titles, archived/unscheduled cards, expanded selector and readable month-grouped history |

Habit edits update title, icon, color and Space immediately; schedule, credit and archive revisions start tomorrow and preserve today's occurrence. Today periods remain current-calendar and display-only. Detail history pages from creation month to current month; its selected month does not change Today dates. Only current scheduled occurrences expose today actions. A skipped day preserves the streak; reversing completion through Undo or Skip requires sufficient available credits. Native Close/swipe dismisses draft editing without saving. Preparation failure hides feature content and disables Add.

| Session row | Composition ID | Covered behavior |
| --- | --- | --- |
|01 Creation | `aUKfX` | First Activity/FAB, blank/valid add sheet, one Session saved |
|02 Count/deck | `Nc0A9` | Two sessions/50 minutes, manual Add to Today, second Activity and swipe coachmark |
|03 Edit/remove | `qSAsz`, `maYik` | Save Changes, completed-count minimum, Remove absent after progress; direct Remove from Today branch |
|04 Focus lifecycle | `aHy3p` | Today Start, Ready, native start confirmation/Cancel, running25-minute timer, completion |
|05 Rest/another | `J8IOo` | Pending5-minute rest, active rest, automatic rest completion, Start another and skip-rest contract |
|06 Exit/rewards | `yDz25` | Back to Today with completed plan; Claim Reward selects existing Rewards tab without automatically claiming |
|07 Abandon | `HJtgA` | Running, native destructive confirmation, abandoned outcome and unfinished plan |
|08 Existing checklist | `A1MrT` | Per-item awards, partial progress, checked delete lock, editing and item undo; retains existing40pt row geometry |
|09 Recorded days | `nS0GH` | Previous/Next bounded date browsing; read-only history, disabled management and no historical FAB |
|10 Failures | `rmxKP` | Reward disables Start, reward-race alert, Focus persistence alert, preparation Retry/FAB disabled |
|11 Layout/accessibility | `ypzCn` | Light320 long form/card, Dark390 Focus, Dark320 progress form/history, expanded form and232pt accessible dial |

The current Session add/edit forms display an activity type label without exposing a conversion selector. The checklist branch therefore starts with an existing stored checklist Activity. Session checklist items own individual credits, unlike To Do. Item undo can fail atomically; the Today presenter does not introduce a new alert for that failure. Session-form save guards likewise do not use the Effort Could not save alert. Focus uses its exact existing reward/persistence alerts. Each completed25-minute Focus Session awards1 credit once; abandoning does not award a completed unit. An active running session resumes regardless of another selected Activity; a different ready session is replaced. Running Focus disables Minimize and interactive dismissal, while phone lock/background preserves absolute-time progress. Rest lasts5 minutes and does not award another Session credit. Mock-only Mark complete, system sound, daypart transitions, confetti/Lottie, Reduce Motion and native lifecycle behavior are documented, not simulated.

Visible resolved-layout checks and Pen renders cover the added families and flow examples. Intentional bounds exceptions are the Year scrolling strip, the dimmed expanded Habit screen beneath a390×844 native alert, and coupon notch halves in the existing Rewards destination component. Larger sheet content is expanded on the canvas to document scrolling. Native single-line fields show abbreviated text where appropriate; full long names remain in cards and annotations. Session repeat controls and transitions have been removed. The subsequent To Do repeat change updates SwiftUI and Pen together; runtime verification remains opt-in.

## Navigation, screens and remaining native patterns

Every remaining View/Shape below is accounted for by composition or a named native/behavior reference. These are not promoted into duplicate component origins.

| Swift symbols | Pen reference | Accounted behavior | Status |
| --- | --- | --- | --- |
| `TodayView`, `TodayTodoView`, `TodayHabitView` | `vvgGg`, `YdsWT`, `kxcK4` in `tyfe.pen`; `v9Bn7`, `KM3g5`, `CsXgc`, `wnkKY` | Header/page selector/floating add/DEV badge; screen lists and actions | Preserved compositions + Linked patterns |
| `HomeView`, `FocusView`, `RewardsView`, `CirclesView`, `StreakView` | `ufqdv` in `tyfe.pen`; `gyihT` | Composition examples and native scrolling/navigation contracts | Composition |
| `TabBarView` | `u2fmOo`, `Elzaz`, `b4HmbT` | Native bottom navigation/status/safe areas; canvas chrome remains illustrative | Linked + Native |
| `ProfileView`, `SettingsView`, `DevSettingsView` | `gyihT`, `OtA9i`, `JGe4x` | Native List/Form/Toggle, alerts, profile editing/crop and developer settings | Native composition |
| `DailyPlanView`, `StarterActivityView` | `gyihT`, `OtA9i`, `Jr4Mu`, `SJkmy` | Existing plan setup, selection and native picker/navigation presentation | Native composition |
| `WelcomeView`, `OnboardingView`, `SignInView`, `SignUpView` | `gyihT`, `OtA9i`, `b4HmbT` | Native page/navigation presentation, text/secure fields, authentication/loading/errors; existing actions and routes | Native composition |
| `SplashView`, `LaunchBrandMask` | `V5dOR9`, `b4HmbT` | Existing launch brand mask and motion; decorative platform animation, not a new logo | Behavior |
| `AppView`, `ModuleWrapperView`, `AppViewForUITesting` | `b4HmbT`, `gyihT` | Runtime wrappers/test harness; system presentation, no independent visual origin | Native/runtime reference |

## State, layout and accessibility contracts

Habit cards use12pt inset,8pt section gaps and16pt list separation. Week has seven evenly distributed labeled columns with tiles capped at28×28. Month uses28×28 days,4pt grid gaps, Monday-first headings, and subdued adjacent-month dates. Year uses10×10 days and2pt gaps in horizontally scrolling week columns, month labels, blank outside-year padding and initial positioning near today. Today outline remains visible. The preserved calendar fixture is October7,2026, matching the original canvas; it is illustrative rather than live data.

All habit titles continue opening existing detail. Complete/undo and Skip/undo skip preserve44×44 minimum targets. Unscheduled cards retain disabled completion controls and metadata, with no Skip action. New cards show pending/faint history. Long labels use stacked footer examples. Accessibility history expands into full date/status text; Year groups by month. The canvas shows representative date lines rather than hundreds of spoken labels. SwiftUI generates all actual local-calendar dates and accessibility labels.

To Do repeat uses adaptive 44-point actions and weekday targets. Choices stack when their intrinsic width does not fit; weekdays use an adaptive grid, with wider short-name labels at accessibility text sizes. Light/Dark 320- and 390-point examples demonstrate these layouts. The native 40-point progress bar remains unchanged.

Coupons retain stub/notch/perforation geometry. Narrow examples override outline geometry and detail width together to keep the tear line aligned. The unavailable7/5 dashed outline is a native stroke contract; Pen's editable outline is solid because its stroke schema has no dash array. Native material blending, rounded trim caps, emoji/SF font rendering, image/crop interactions, animations, scrolling and semantic text scaling also remain runtime contracts. Accessibility examples demonstrate expansion; they are not evidence from a running iOS preview.

## Verification and maintenance

Resolved-layout checks and Pen renders were used for migrated families, preserved Today screens, compact periods, narrow widths, both themes, long labels and accessibility examples. Disabled descendants are excluded from visible-layout checks. Intentional exceptions are coupon notch halves at the edge and the Year strip beyond its scrolling viewport. Native sizing and rendering exceptions are described above. Component references and variable bindings are checked through Pen tooling; `.pen` files must not be inspected or rewritten with text/JSON tools.

For a future visual change:

1. Update shared variables/component origins in `tyfe.lib.pen` and affected composition instances in `tyfe.pen`.
2. Make the corresponding SwiftUI change in the same reviewed change. Preserve aliases, API behavior and intentional instance overrides.
3. Update this inventory when symbols, origins, variants, dependencies or native contracts change.
4. Inspect resolved layout and renders at320/390 points in Light/Dark, with long labels, relevant states and accessibility layouts. Check44pt action targets and readable today outlines.
5. Save and reopen both documents; verify library import, linked references and the three existing Today compositions. Do not remove old origins before all references are verified.
6. Run diff checks and strict non-rewriting SwiftLint for Swift changes. Builds, tests, SwiftUI previews and simulator verification remain opt-in under [repository policy](../AGENTS.md).

Final static accounting covered all 97 Swift View, Shape, and ViewModifier symbols in the shared Components, Core, and Root inventory and the original150 reusable Pen origin IDs. To Do adds18 origins; Habit/Session adds26, the later repeat change removes one unused type-selector origin and adds three To Do sheet origins, giving196 origins,127 shared variables, and801 linked canvas instances. Pen renders and resolved layouts were inspected; intentional year scrolling, coupon notch clipping, and native alert viewport clipping are documented above. Calendar fill-column arithmetic can produce subpixel boundary warnings without visible clipping.

The initial library migration required no Swift changes. The subsequent Session/To Do repeat change updates SwiftUI, models, migration, and test sources together with Pen. Strict non-rewriting SwiftLint and syntax checks were run; runtime verification was not run. The source inventory includes shared Components and reusable Core patterns; widgets and Live Activities are explicitly excluded.


## Session simplification and To Do repeat

Session creation and editing now contain title, Space, count, and actions. Session plans are manually added to each day. Repeat state, live recurrence APIs, automatic plan generation, and unreachable type-conversion controls were removed. Stored checklist rendering and historical plans remain supported; Habit scheduling is unchanged.

| Swift pattern | Pen origin or composition | Variants and dependencies | Status |
| --- | --- | --- | --- |
| `TodoFormView` repeat | `KorMI` repeat slot `l0IMr`; `jkAaq`, `MdsII`, `xZ29J`, `YaXNK` | Never, daily, weekdays, invalid; adaptive 44-point controls | Linked |
| Repeating To Do sheets | `AaQK9`, `GjXZ7`, `vFPAX` | Daily, weekdays, invalid weekdays; linked Sheet shell, form, repeat, and Save | Linked |
| To Do schedule metadata | `kr24y` label `yhW7A`, `vr4kC` label `EqS02`, `NoUX8` label `i29wo` | Current schedule and pending next-day text; inherited by checklist/history card variants | Linked |
| Repeat setup flow | `q6UzB` in `tyfe.pen` | Daily, weekdays, empty-day validation, and immediately visible saved task | Linked |
| Carry-forward and reset flow | `Up6K2` in `tyfe.pen` | Partial work carried across scheduled days; completion then next scheduled cycle with preserved history | Linked |
| Edit/stop repeat flow | `bnvl6` in `tyfe.pen` | Current schedule, edit, pending tomorrow change, and Never | Linked |
| Repeat layout checks | `wndQq` in `tyfe.pen`; library `UAukH`, `aJPCg` | Light320, Dark390/320, accessibility390; stacked choices and adaptive weekday rows | Linked |

New tasks default to Never and appear immediately even on a nonmatching day. Unfinished tasks stay open with their checklist progress; no duplicate or overdue occurrences are created. A completed task resets on its next scheduled local day while retaining its task ID, creation order, title, Space, credit value, and completion history. After several days away, it reopens once without synthetic history or retroactive credits. Reset clears completion, ticks, and award eligibility without rewriting the ledger. Same-day undo uses the awarded amount and remains atomic; previous-day reopening retains its award until the current cycle finishes and a later scheduled cycle begins.

Schedule edits take effect tomorrow. Repeated edits replace tomorrow's pending revision. Cards show the current schedule plus “From tomorrow” when a change is pending; the editor explains that today's progress and reward stay intact. Title, Space, checklist, and credit edits retain existing semantics.

Snapshot version 9 decodes missing To Do schedules as Never. Preparation resolves legacy Session fallback counts through yesterday before clearing compatibility recurrence; recorded plans, Focus sessions, effort counts, and ledger entries remain intact. Migration and recurring-task preparation are transactional and retryable through the existing preparation-error flow. The first file migration preserves the exact previous file at `local-app-snapshot-v1.txt.pre-v9-backup`. To roll back, restore that backup with the previous app version; the previous version cannot read a version 9 snapshot. Existing repeating Sessions are not converted into To Dos.

The canvas preserves the user's current board positions. Intentional clipping is limited to scrolling Year strips, native-alert viewport content, and coupon notch halves. New repeat families have no visible resolved-layout clipping. Focused test sources cover scheduling, progress, credits, persistence, retirement, and backup preservation. Builds, test execution, previews, and simulators were intentionally not run under repository policy.
