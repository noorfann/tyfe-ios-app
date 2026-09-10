import SwiftUI

@MainActor
protocol CirclesInteractor: GlobalInteractor { }

extension CoreInteractor: CirclesInteractor { }
