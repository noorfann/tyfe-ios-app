//
//  AppViewForUITesting.swift
//  tyfe-ios-app
//
//  
//
import SwiftUI
import SwiftfulUI

struct AppViewForUITesting: View {
    
    var container: DependencyContainer
    
    private var builder: CoreBuilder {
        CoreBuilder(interactor: CoreInteractor(container: container))
    }
    
    private func processInfoContains(_ value: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(value)
    }

    var body: some View {
        if processInfoContains("PHASE1_FLOW") {
            NavigationStack {
                RouterView { router in
                    builder.todayView(router: router, delegate: TodayDelegate())
                }
            }
        } else if processInfoContains("DESIGN_SYSTEM_GALLERY") {
            NavigationStack {
                TyfeDesignSystemGalleryView(presenter: TyfeDesignSystemGalleryPresenter())
            }
        } else if processInfoContains("STARTSCREEN_[ADDSCREENNAME]") {
            RouterView { _ in
                Text("Screen")
            }
        } else {
            builder.build()
        }
    }
}
