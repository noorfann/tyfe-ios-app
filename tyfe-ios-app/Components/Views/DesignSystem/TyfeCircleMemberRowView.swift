import SwiftUI

struct TyfeCircleMemberRowView: View {
    let member: CircleMemberModel
    let progress: CircleMemberProgressModel?
    let focusStatus: CircleFocusStatus?
    let isSelf: Bool
    let isViewerOwner: Bool
    let sentKinds: Set<CheerKind>
    let onCheer: (CheerKind) -> Void
    let onRemove: () -> Void

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                header
                progressText
                if !isSelf {
                    actions
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(isSelf ? "Me" : member.displayName)
                .font(TyfeTypography.interfaceStrong)
            if member.role == .owner {
                TyfePillView(label: "Owner", systemImage: "crown.fill", tone: .warning)
            }
            Spacer()
            if let focusStatus {
                TyfePillView(
                    label: focusStatus.displayName,
                    systemImage: focusStatus.symbolName,
                    tone: focusStatus == .focusing ? .accent : .neutral
                )
            }
        }
    }

    @ViewBuilder
    private var progressText: some View {
        if let progress {
            Text("Today \(progress.todayCompleted)/\(progress.todayPlanned) · 7 days \(progress.sevenDayCompleted)")
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private var actions: some View {
        HStack(spacing: TyfeSpacing.small) {
            cheerMenu
            if isViewerOwner {
                Button("Remove", role: .destructive, action: onRemove)
                    .font(TyfeTypography.caption)
            }
        }
    }

    private var cheerMenu: some View {
        Menu {
            ForEach(CheerKind.allCases, id: \.self) { kind in
                if sentKinds.contains(kind) {
                    Button {} label: {
                        Label("\(kind.displayName) · Sent", systemImage: "checkmark")
                    }
                    .disabled(true)
                } else {
                    Button {
                        onCheer(kind)
                    } label: {
                        Label(kind.displayName, systemImage: kind.symbolName)
                    }
                }
            }
        } label: {
            Label(cheerMenuTitle, systemImage: cheerMenuSymbolName)
                .font(TyfeTypography.caption)
        }
        .disabled(sentKinds.count == CheerKind.allCases.count)
    }

    private var cheerMenuTitle: String {
        sentKinds.count == CheerKind.allCases.count ? "Cheered" : "Cheer"
    }

    private var cheerMenuSymbolName: String {
        sentKinds.count == CheerKind.allCases.count ? "checkmark.circle.fill" : "hands.clap"
    }
}
