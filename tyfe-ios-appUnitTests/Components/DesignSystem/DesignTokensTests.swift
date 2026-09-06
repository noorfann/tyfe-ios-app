import Testing
@testable import tyfe_ios_app

struct DesignTokensTests {

    @Test func foundationGeometryUsesFourPointRhythm() {
        #expect(TyfeSpacing.unit == 4)
        #expect(TyfeSpacing.control == 16)
        #expect(TyfeSpacing.card == 24)
        #expect(TyfeRadius.control == 16)
        #expect(TyfeRadius.card == 20)
        #expect(TyfeRadius.surface == 28)
        #expect(TyfeStroke.standard == 2)
        #expect(TyfeStroke.emphasis == 3)
    }

    @Test func motionProvidesReducedMotionAlternative() {
        #expect(TyfeMotion.normalDuration > TyfeMotion.reducedDuration)
        #expect(TyfeMotion.reducedDuration == 0)
    }
}
