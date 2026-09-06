//
//  DevSettingsRouter.swift
//  
//
//  
//

@MainActor
protocol DevSettingsRouter: GlobalRouter {
    #if MOCK || DEV
    func showDesignSystemGallery()
    #endif
}

extension CoreRouter: DevSettingsRouter { }

#if MOCK || DEV
extension CoreRouter {
    func showDesignSystemGallery() {
        router.showScreen(.sheet) { router in
            builder.designSystemGalleryView(router: router)
        }
    }
}
#endif
