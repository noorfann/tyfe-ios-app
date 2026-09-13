import SwiftUI

struct TyfeCircleMemberRowView: View {
    let member: CircleMemberModel
    let progress: CircleMemberProgressModel?
    let focusStatus: CircleFocusStatus?
    let isSelf: Bool
    let isViewerOwner: Bool
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
            Text(member.displayName)
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
                Button {
                    onCheer(kind)
                } label: {
                    Label(kind.displayName, systemImage: kind.symbolName)
                }
            }
        } label: {
            Label("Cheer", systemImage: "hands.clap")
                .font(TyfeTypography.caption)
        }
    }
}
