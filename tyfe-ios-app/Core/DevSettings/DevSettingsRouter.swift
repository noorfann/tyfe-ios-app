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
    func showCirclesGallery()
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

    func showCirclesGallery() {
        router.showScreen(.sheet) { router in
            builder.circlesGalleryView(router: router)
        }
    }
}
#endif
