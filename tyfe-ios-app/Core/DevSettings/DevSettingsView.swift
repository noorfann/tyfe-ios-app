//
//  DevSettingsView.swift
//  
//
//  
//
import SwiftUI
import SwiftfulUI

struct DevSettingsView: View {

    @State var presenter: DevSettingsPresenter

    var body: some View {
        List {
            abTestSection
            authSection
            userSection
            deviceSection
            #if MOCK || DEV
            designSystemSection
            #endif
        }
        .navigationTitle("Dev Settings")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                backButtonView
            }
        }
        .onFirstAppear {
            presenter.loadABTests()
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }
    
    private var backButtonView: some View {
        Image(systemName: "xmark")
            .font(.title2)
            .fontWeight(.black)
            .asButton {
                presenter.onBackButtonPressed()
            }
    }
            
    private var abTestSection: some View {
        Section {
            Toggle("Bool Test", isOn: $presenter.boolTest)
                .onChange(of: presenter.boolTest, presenter.handleBoolTestChange)

            Picker("Enum Test", selection: $presenter.enumTest) {
                ForEach(EnumTestOption.allCases, id: \.self) { option in
                    Text(option.rawValue)
                        .id(option)
                }
            }
            .onChange(of: presenter.enumTest, presenter.handleEnumTestChange)
        } header: {
            Text("AB Tests")
        }
        .font(.caption)
    }
    
    private var authSection: some View {
        Section {
            ForEach(presenter.authData, id: \.key) { item in
                itemRow(item: item)
            }
        } header: {
            Text("Auth Info")
        }
    }
    
    private var userSection: some View {
        Section {
            ForEach(presenter.userData, id: \.key) { item in
                itemRow(item: item)
            }
        } header: {
            Text("User Info")
        }
    }
    
    private var deviceSection: some View {
        Section {
            ForEach(presenter.utilitiesData, id: \.key) { item in
                itemRow(item: item)
            }
        } header: {
            Text("Device Info")
        }
    }

    #if MOCK || DEV
    private var designSystemSection: some View {
        Section {
            Text("Open component gallery")
                .font(.body.weight(.semibold))
                .asButton(.press) {
                    presenter.onDesignSystemGalleryPressed()
                }
            Text("Open Circles gallery")
                .font(.body.weight(.semibold))
                .asButton(.press) {
                    presenter.onCirclesGalleryPressed()
                }
        } header: {
            Text("Design System")
        } footer: {
            Text("Mock-only visual review. These fixtures do not touch remote services.")
        }
    }
    #endif
    
    private func itemRow(item: (key: String, value: Any)) -> some View {
        HStack {
            Text(item.key)
            Spacer(minLength: 4)
            
            if let value = String.convertToString(item.value) {
                Text(value)
            } else {
                Text("Unknown")
            }
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.3)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    
    return RouterView { router in
        builder.devSettingsView(router: router)
    }
}

extension CoreBuilder {
    
    func devSettingsView(router: AnyRouter) -> some View {
        DevSettingsView(
            presenter: DevSettingsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }

}

extension CoreRouter {
    
    func showDevSettingsView() {
        router.showScreen(.sheet) { router in
            builder.devSettingsView(router: router)
        }
    }

}
