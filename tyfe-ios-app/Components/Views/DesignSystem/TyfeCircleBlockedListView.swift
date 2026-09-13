import SwiftUI

struct TyfeCircleBlockedListView: View {
    let blockedUserIds: [String]
    let onUnblock: (String) -> Void

    var body: some View {
        if !blockedUserIds.isEmpty {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("Blocked")
                    .font(TyfeTypography.interfaceStrong)

                TyfeSurfaceView(role: .paper) {
                    VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                        ForEach(blockedUserIds, id: \.self) { userId in
                            HStack {
                                Text(userId)
                                    .font(TyfeTypography.caption)
                                    .lineLimit(1)
                                Spacer()
                                Button("Unblock") { onUnblock(userId) }
                                    .font(TyfeTypography.caption)
                            }
                        }
                    }
                }
            }
        }
    }
}
