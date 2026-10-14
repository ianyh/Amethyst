@testable import Amethyst
import Cocoa
import Nimble
import Quick
import Silica

class SIWindowAmethystTests: QuickSpec {
    override func spec() {
        describe("a window whose frame cannot be read") {
            // An element of a process that does not exist answers no Accessibility request, so its frame is null.
            let window = AXWindow(axElement: AXUIElementCreateApplication(pid_t(999_999)))
            let floatSmallWindowsKey = "float-small-windows"
            var savedFloatSmallWindows: Any?

            beforeEach {
                savedFloatSmallWindows = UserDefaults.standard.object(forKey: floatSmallWindowsKey)
                UserDefaults.standard.set(true, forKey: floatSmallWindowsKey)
            }

            afterEach {
                UserDefaults.standard.set(savedFloatSmallWindows, forKey: floatSmallWindowsKey)
            }

            it("reports a null frame") {
                expect(window.frame().isNull).to(beTrue())
            }

            it("is not treated as a small window") {
                expect(window.shouldFloat()).to(beFalse())
            }

            it("leaves the float decision open") {
                let application = SIApplication(runningApplication: NSRunningApplication.current)
                expect(application.defaultFloatForWindow(window)).to(equal(.unreliable(.notFloating)))
            }
        }

        describe("approximate rect comparison") {
            it("tolerates some provided error") {
                let rect = CGRect(x: 100, y: 100, width: 100, height: 100)
                let tolerance = CGRect(x: 10, y: 10, width: 10, height: 10)
                let translations = [
                    CGAffineTransform(translationX: 5, y: 5),
                    CGAffineTransform(translationX: 5, y: 0),
                    CGAffineTransform(translationX: 5, y: -5),
                    CGAffineTransform(translationX: 0, y: 5),
                    CGAffineTransform(translationX: 0, y: -5),
                    CGAffineTransform(translationX: -5, y: 5),
                    CGAffineTransform(translationX: -5, y: 0),
                    CGAffineTransform(translationX: -5, y: -5),

                    CGAffineTransform(scaleX: 1.05, y: 1.05),
                    CGAffineTransform(scaleX: 1.05, y: 0.95),
                    CGAffineTransform(scaleX: 0.95, y: 1.05),
                    CGAffineTransform(scaleX: 0.95, y: 0.95)
                ]

                translations.forEach {
                    expect(rect.applying($0).approximatelyEqual(to: rect, within: tolerance)).to(beTrue(), description: "\($0)")
                }
            }
        }
    }
}
