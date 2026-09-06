import SwiftUI
import SwiftfulUI

struct StarterActivityDelegate {
    var eventParameters: [String: Any]? { nil }
}

struct StarterActivityView: View {

    @State private var presenter: StarterActivityPresenter
    let delegate: StarterActivityDelegate

    init(presenter: StarterActivityPresenter, delegate: StarterActivityDelegate) {
        _presenter = State(initialValue: presenter)
        self.delegate = delegate
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                    header
                    intro
                    existingActivities
                    activityForm
                    TyfeActionButtonView(
                        title: "Continue to today’s plan",
                        systemImage: "arrow.right",
                        isEnabled: presenter.canContinue,
                        onTap: presenter.onContinuePressed
                    )
                }
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.top, TyfeSpacing.control)
                .padding(.bottom, TyfeSpacing.section)
            }
            .scrollIndicators(.hidden)
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
        HStack(spacing: TyfeSpacing.small) {
            Image(systemName: "chevron.left")
                .font(.headline.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(width: 44, height: 44)
                .asButton(.press) {
                    presenter.onBackPressed()
                }
                .accessibilityLabel("Back")

            Text("STARTER ACTIVITY")
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text("One clear thing\nfor today.")
                .font(TyfeTypography.display)
                .tracking(-1.6)
                .foregroundStyle(TyfeEditorialPalette.ink)

            Text("Choose an activity, then we’ll shape a small plan around it.")
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private var existingActivities: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text("YOUR ACTIVITIES")
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)

            ForEach(presenter.activities) { activity in
                Text(activity.name)
                    .font(TyfeTypography.interfaceStrong)
                    .foregroundStyle(TyfeEditorialPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44, alignment: .leading)
                    .padding(.horizontal, TyfeSpacing.control)
                    .background(
                        presenter.activityName == activity.name
                            ? TyfeEditorialPalette.teal.opacity(0.25)
                            : TyfeEditorialPalette.paper
                    )
                    .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
                    .overlay {
                        RoundedRectangle(cornerRadius: TyfeRadius.control)
                            .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.hairline)
                    }
                    .asButton(.press) {
                        presenter.select(activity: activity)
                    }
                    .accessibilityLabel("Use \(activity.name)")
            }
        }
    }

    private var activityForm: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("NAME YOUR ACTIVITY")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.2)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                TextField("Study Swift", text: $presenter.activityName)
                    .font(TyfeTypography.interfaceStrong)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .padding(.horizontal, TyfeSpacing.control)
                    .frame(minHeight: 52)
                    .background(TyfeEditorialPalette.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
                    .overlay {
                        RoundedRectangle(cornerRadius: TyfeRadius.control)
                            .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.hairline)
                    }

                Picker("Category", selection: $presenter.selectedCategory) {
                    ForEach(ActivityCategory.allCases, id: \.self) { category in
                        Text(category.displayName)
                            .tag(category)
                    }
                }
                .pickerStyle(.menu)
                .tint(TyfeEditorialPalette.ink)
                .frame(minHeight: 44, alignment: .leading)
            }
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.starterActivityView(router: router, delegate: StarterActivityDelegate())
    }
}

extension CoreBuilder {
    func starterActivityView(router: AnyRouter, delegate: StarterActivityDelegate) -> some View {
        StarterActivityView(
            presenter: StarterActivityPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showStarterActivityView(delegate: StarterActivityDelegate = StarterActivityDelegate()) {
        router.showScreen(.push) { router in
            builder.starterActivityView(router: router, delegate: delegate)
        }
    }
}
