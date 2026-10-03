import SwiftUI
import SwiftfulUI
import UIKit

struct TyfeCircleMemberRowView: View {
    let member: CircleMemberModel
    var photoURL: URL?
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
                    cheerRow
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: TyfeSpacing.small) {
            avatar
            Text(isSelf ? "Me" : member.displayName)
                .font(TyfeTypography.interfaceStrong)
            if member.role == .owner {
                TyfePillView(label: "Owner", systemImage: "crown.fill", tone: .warning)
            }
            Spacer()
            if let focusStatus {
                TyfeFocusStatusPillView(status: focusStatus)
            }
            if isViewerOwner && !isSelf {
                removeButton
            }
        }
    }

    private var avatar: some View {
        Group {
            if let photoURL, photoURL.isFileURL {
                if let image = UIImage(contentsOfFile: photoURL.path) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    avatarFallback
                }
            } else {
                AsyncImage(url: photoURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        avatarFallback
                    }
                }
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var avatarFallback: some View {
        Text(member.avatarFallbackText)
            .font(TyfeTypography.interfaceStrong)
            .foregroundStyle(TyfeEditorialPalette.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TyfeEditorialPalette.canvas)
    }

    private var removeButton: some View {
        Image(systemName: "trash")
            .font(TyfeTypography.interfaceStrong)
            .foregroundStyle(TyfeEditorialPalette.muted)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .asButton(.press, action: onRemove)
            .accessibilityLabel("Remove \(member.displayName)")
    }

    @ViewBuilder
    private var progressText: some View {
        if let progress {
            Text("Today \(progress.todayCompleted)/\(progress.todayPlanned) · 7 days \(progress.sevenDayCompleted)")
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private var cheerRow: some View {
        HStack(spacing: TyfeSpacing.small) {
            ForEach(CheerKind.allCases, id: \.self) { kind in
                cheerButton(for: kind)
            }
        }
    }

    private func cheerButton(for kind: CheerKind) -> some View {
        let isSent = sentKinds.contains(kind)
        return Text(kind.emoji)
            .font(.system(size: 22))
            .opacity(isSent ? 0.45 : 1)
            .frame(width: 44, height: 44)
            .background(TyfeEditorialPalette.canvas)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(
                        isSent ? TyfeEditorialPalette.border : TyfeEditorialPalette.controlBorder,
                        lineWidth: TyfeStroke.standard
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                if isSent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(TyfeEditorialPalette.onAccent, TyfeEditorialPalette.focus)
                        .offset(x: -2, y: -2)
                }
            }
            .contentShape(Circle())
            .asButton(.press) {
                guard !isSent else { return }
                onCheer(kind)
            }
            .disabled(isSent)
            .accessibilityLabel(isSent ? "\(kind.displayName), sent" : "Cheer with \(kind.displayName)")
            .accessibilityAddTraits(.isButton)
    }
}
