import SwiftUI
import SwiftfulUI

struct OnboardingDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct OnboardingView: View {

    @State private var presenter: OnboardingPresenter
    let delegate: OnboardingDelegate

    init(presenter: OnboardingPresenter, delegate: OnboardingDelegate) {
        _presenter = State(initialValue: presenter)
        self.delegate = delegate
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.canvas
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                pagePager
                footer
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

    private var pageSelection: Binding<Int> {
        Binding(
            get: { presenter.currentIndex },
            set: { presenter.onPageSelected(index: $0) }
        )
    }

    private var pagePager: some View {
        TabView(selection: pageSelection) {
            ForEach(Array(presenter.pages.enumerated()), id: \.offset) { index, page in
                pageView(page)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(TyfeMotion.normalAnimation, value: presenter.currentIndex)
        .accessibilityLabel("Onboarding")
        .accessibilityValue("Step \(presenter.currentIndex + 1) of \(presenter.pages.count)")
    }

    private var header: some View {
        HStack(spacing: TyfeSpacing.small) {
            if !presenter.isFirstPage {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.black))
                    .foregroundStyle(TyfeEditorialPalette.ink)
                    .frame(width: 44, height: 44)
                    .asButton(.press) {
                        presenter.goBack()
                    }
                    .accessibilityLabel("Back")
            }

            Text(presenter.pages[presenter.currentIndex].eyebrow)
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !presenter.isLastPage {
                Text("Skip")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)
                    .frame(minHeight: 44)
                    .asButton(.press) {
                        presenter.onSkipPressed()
                    }
                    .accessibilityLabel("Skip onboarding")
            }
        }
        .padding(.horizontal, TyfeSpacing.control)
        .padding(.top, TyfeSpacing.small)
    }

    private var footer: some View {
        VStack(spacing: TyfeSpacing.small) {
            TyfeProgressBarView(
                label: "Onboarding progress",
                current: presenter.currentIndex + 1,
                total: presenter.pages.count,
                accent: TyfeEditorialPalette.teal
            )

            TyfeActionButtonView(
                title: presenter.primaryButtonTitle,
                systemImage: presenter.isLastPage ? "plus" : "arrow.right",
                onTap: presenter.onPrimaryPressed
            )
        }
        .padding(.horizontal, TyfeSpacing.control)
        .padding(.bottom, TyfeSpacing.control)
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                artView(for: page)

                Text(page.title)
                    .font(TyfeTypography.display)
                    .tracking(-1.6)
                    .foregroundStyle(TyfeEditorialPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.8)
                    .accessibilityHeading(.h1)

                Text(page.body)
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let pills = page.pills {
                    pillsView(pills)
                }
            }
            .padding(.horizontal, TyfeSpacing.control)
            .padding(.top, TyfeSpacing.control)
            .padding(.bottom, TyfeSpacing.control)
        }
        .scrollIndicators(.hidden)
    }

    private func pillsView(_ pills: [String]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 120), spacing: TyfeSpacing.small, alignment: .leading)],
            alignment: .leading,
            spacing: TyfeSpacing.small
        ) {
            ForEach(pills, id: \.self) { pill in
                TyfePillView(label: pill, systemImage: "checkmark", tone: .accent)
            }
        }
    }

    @ViewBuilder
    private func artView(for page: OnboardingPage) -> some View {
        VStack(spacing: TyfeSpacing.control) {
            switch page.art {
            case .hero: heroArt
            case .focus: focusArt
            case .circles: circlesArt
            }
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(page.body))
    }

    private var heroArt: some View {
        VStack(spacing: TyfeSpacing.control) {
            HStack(spacing: TyfeSpacing.small) {
                TyfeMotifView(kind: .tile)
                TyfeMotifView(kind: .badge)
                TyfeMotifView(kind: .completion)
            }
            Text("PLAN → FOCUS → EARN → REST")
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private var focusArt: some View {
        TyfeSurfaceView(role: .focusChamber) {
            VStack(spacing: TyfeSpacing.small) {
                TyfePillView(label: "Focusing", systemImage: "timer", tone: .accent)
                Text("25:00")
                    .font(TyfeTypography.timer)
                    .monospacedDigit()
                    .foregroundStyle(TyfeEditorialPalette.focus)
                Text("Study Swift · One pause · up to 5 minutes")
                    .font(TyfeTypography.caption)
                    .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, TyfeSpacing.small)
        }
    }

    private var circlesArt: some View {
        VStack(spacing: TyfeSpacing.control) {
            iconTile(symbolName: "square.grid.2x2.fill", accent: TyfeEditorialPalette.slateBlue)
            Text("PLAN · XP · CIRCLES · OFFLINE")
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private func iconTile(symbolName: String, accent: Color) -> some View {
        RoundedRectangle(cornerRadius: TyfeRadius.control)
            .fill(accent)
            .frame(width: 72, height: 72)
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.control)
                    .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.standard)
                Image(systemName: symbolName)
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(TyfeEditorialPalette.ink)
            }
    }
}

#Preview("Onboarding") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return builder.onboardingFlow()
}

extension CoreBuilder {

    func onboardingFlow() -> some View {
        RouterView { router in
            onboardingView(router: router, delegate: OnboardingDelegate())
        }
    }

    func onboardingView(router: AnyRouter, delegate: OnboardingDelegate) -> some View {
        OnboardingView(
            presenter: OnboardingPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}
