import SwiftUI

struct TyfeCirclePillRowView: View {
    let circles: [CircleModel]
    let selectedCircleId: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: TyfeSpacing.small) {
                ForEach(circles) { circle in
                    Button {
                        onSelect(circle.circleId)
                    } label: {
                        TyfePillView(
                            label: circle.name,
                            systemImage: selectedCircleId == circle.circleId ? "checkmark.circle.fill" : "person.3",
                            tone: selectedCircleId == circle.circleId ? .accent : .neutral
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
