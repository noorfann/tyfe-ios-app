import SwiftUI
import SwiftfulUI

struct HomeDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct HomeView: View {

    @State var presenter: HomePresenter
    let delegate: HomeDelegate

    private var showDevSettingsButton: Bool {
        #if DEV || MOCK
        return true
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TyfeEditorialPalette.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    editorialHero
                    progressSection
                    circleSnapshot
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)

            if showDevSettingsButton {
                devSettingsButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("tyfe")
                .font(.system(.title, design: .serif, weight: .black))
                .tracking(-1.4)
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Today")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(TyfeEditorialPalette.muted)

            Text("T")
                .font(.headline.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(width: 36, height: 36)
                .background(TyfeEditorialPalette.lavender)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(TyfeEditorialPalette.ink, lineWidth: 2)
                }
                .shadow(color: TyfeEditorialPalette.ink, radius: 0, x: 3, y: 3)
                .accessibilityLabel("Profile")
        }
    }

    private var editorialHero: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(TyfeEditorialPalette.paper)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(TyfeEditorialPalette.ink, lineWidth: 2)
                }
                .shadow(color: TyfeEditorialPalette.ink, radius: 0, x: 5, y: 5)

            editorialMotifs
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 16) {
                Text(presenter.heroEyebrow)
                    .font(.caption2.weight(.black))
                    .tracking(1.4)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                Text(presenter.heroTitle)
                    .font(.system(.largeTitle, design: .serif, weight: .black))
                    .tracking(-1.8)
                    .lineSpacing(-3)
                    .foregroundStyle(TyfeEditorialPalette.ink)
                    .minimumScaleFactor(0.7)

                if presenter.canStartFocus {
                    Text(presenter.activityTitle)
                        .font(.headline.weight(.black))
                        .foregroundStyle(TyfeEditorialPalette.focus)
                }

                Text(presenter.heroSubtitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(TyfeEditorialPalette.ink.opacity(0.72))
                    .frame(maxWidth: 210, alignment: .leading)

                HStack(spacing: 8) {
                    Text(presenter.focusActionTitle)
                    Image(systemName: presenter.focusActionSystemImage)
                        .font(.subheadline.weight(.black))
                        .accessibilityHidden(true)
                }
                .font(.headline.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(TyfeEditorialPalette.focus)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(TyfeEditorialPalette.ink, lineWidth: 2)
                }
                .shadow(color: TyfeEditorialPalette.ink, radius: 0, x: 3, y: 3)
                .asButton(.press) {
                    presenter.onStartFocusPressed()
                }
                .disabled(!presenter.canStartFocus)
                .accessibilityLabel(presenter.focusActionAccessibilityLabel)
                .accessibilityHint(presenter.focusActionAccessibilityHint)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 372)
    }

    private var editorialMotifs: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(TyfeEditorialPalette.sky)
                .frame(width: 126, height: 126)
                .rotationEffect(.degrees(12))
                .offset(x: 56, y: 64)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TyfeEditorialPalette.sage)
                .frame(width: 62, height: 62)
                .rotationEffect(.degrees(10))
                .offset(x: 30, y: -32)

            editorialGrid
                .offset(x: 12, y: 54)
        }
        .frame(width: 150, height: 178)
        .offset(x: -8, y: 0)
    }

    private var editorialGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(14), spacing: 3), count: 3),
            spacing: 3
        ) {
            ForEach(Array(0..<9), id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(index == 1 || index == 7 ? TyfeEditorialPalette.amber : TyfeEditorialPalette.paper)
                    .frame(width: 14, height: 14)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(TyfeEditorialPalette.ink, lineWidth: 1.5)
                    }
            }
        }
        .padding(5)
        .background(TyfeEditorialPalette.orange)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TyfeEditorialPalette.ink, lineWidth: 2)
        }
        .rotationEffect(.degrees(7))
    }

    private var progressSection: some View {
        HStack(spacing: 12) {
            EditorialMetricCard(
                label: "DAILY PLAN",
                value: "\(presenter.planCompleted)/\(presenter.planTotal)",
                detail: "sessions complete",
                color: TyfeEditorialPalette.lavender
            )

            EditorialMetricCard(
                label: "CREDITS",
                value: "\(presenter.rewardCredits)",
                detail: "Reward Credits",
                color: TyfeEditorialPalette.amber
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today progress")
        .accessibilityValue(
            "\(presenter.planCompleted) of \(presenter.planTotal) sessions complete, "
                + "\(presenter.rewardCredits) Reward Credits"
        )
    }

    private var circleSnapshot: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Study Circle")
                    .font(.headline.weight(.bold))

                Text("2 of 3 shared progress · 1 focusing")
                    .font(.caption)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: -6) {
                CircleAvatar(letter: "A", color: TyfeEditorialPalette.sage)
                CircleAvatar(letter: "R", color: TyfeEditorialPalette.orange)
                CircleAvatar(letter: "T", color: TyfeEditorialPalette.sky)
            }
            .accessibilityHidden(true)
        }
        .padding(16)
        .background(TyfeEditorialPalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TyfeEditorialPalette.ink, lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Study Circle, 2 of 3 shared progress, 1 focusing")
    }

    private var devSettingsButton: some View {
        Text("DEV")
            .foregroundStyle(.white)
            .font(.callout)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .fixedSize(horizontal: true, vertical: false)
            .asButton(.press) {
                presenter.onDevSettingsPressed()
            }
    }
}

private struct EditorialMetricCard: View {
    let label: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption2.weight(.black))
                .tracking(1.1)

            Text(value)
                .font(.system(.largeTitle, design: .serif, weight: .black))
                .tracking(-1.4)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(detail)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(TyfeEditorialPalette.ink)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TyfeEditorialPalette.ink, lineWidth: 2)
        }
        .shadow(color: TyfeEditorialPalette.ink, radius: 0, x: 4, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value), \(detail)")
    }
}

private struct CircleAvatar: View {
    let letter: String
    let color: Color

    var body: some View {
        Text(letter)
            .font(.caption.weight(.black))
            .foregroundStyle(TyfeEditorialPalette.ink)
            .frame(width: 32, height: 32)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(TyfeEditorialPalette.paper, lineWidth: 2)
            }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = HomeDelegate()

    return RouterView { router in
        builder.homeView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func homeView(router: AnyRouter, delegate: HomeDelegate) -> some View {
        HomeView(
            presenter: HomePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showHomeView(delegate: HomeDelegate) {
        router.showScreen(.push) { router in
            builder.homeView(router: router, delegate: delegate)
        }
    }

}
