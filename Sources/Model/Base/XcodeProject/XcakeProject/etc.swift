import class Foundation.Bundle
import enum CakefileDescription.Platform
import Path

extension Path {
    public static var xcode: Path {
        //TODO use scripting bridge or something duh
        return Path.root/"Applications/Xcode.app"
    }

    fileprivate static func template(for os: Platform) -> Path {
        switch os {
        case .iOS:
            return xcode/"Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Xcode/Templates/Project Templates/iOS/Application/Cocoa Touch App Base.xctemplate"
        case .macOS:
            return xcode/"Contents/Developer/Library/Xcode/Templates/Project Templates/Mac/Application/Cocoa App Storyboard.xctemplate"
        }
    }
}

extension Platform {
    var storyboardName: String {
        switch self {
        case .iOS:
            return "LaunchScreen.storyboard"
        case .macOS:
            return "Main.storyboard"
        }
    }

    var storyboard: Path {
        switch self {
        case .macOS:
            return Path.template(for: self).join(storyboardName)
        case .iOS:
            return Bundle.main.resources/"iOS.Launchscreen.storyboard"
        }
    }

    var rpath: String {
        switch self {
        case .iOS:
            return "Frameworks"
        case .macOS:
            return "../Frameworks"
        }
    }

    var infoPlist: String {
        switch self {
        case .iOS:
            return """
                <?xml version="1.0" encoding="UTF-8"?>
                <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                <plist version="1.0">
                <dict>
                    <key>CFBundleDevelopmentRegion</key>
                    <string>$(DEVELOPMENT_LANGUAGE)</string>
                    <key>CFBundleExecutable</key>
                    <string>$(EXECUTABLE_NAME)</string>
                    <key>CFBundleIdentifier</key>
                    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
                    <key>CFBundleInfoDictionaryVersion</key>
                    <string>6.0</string>
                    <key>CFBundleName</key>
                    <string>$(PRODUCT_NAME)</string>
                    <key>CFBundlePackageType</key>
                    <string>APPL</string>
                    <key>CFBundleShortVersionString</key>
                    <string>$(SEMANTIC_PROJECT_VERSION)</string>
                    <key>CFBundleVersion</key>
                    <string>$(CURRENT_PROJECT_VERSION)</string>
                    <key>LSRequiresIPhoneOS</key>
                    <true/>
                    <key>UILaunchStoryboardName</key>
                    <string>LaunchScreen</string>
                    <key>UIRequiredDeviceCapabilities</key>
                    <array>
                        <string>armv7</string>
                    </array>
                    <key>UISupportedInterfaceOrientations</key>
                    <array>
                        <string>UIInterfaceOrientationPortrait</string>
                    </array>
                </dict>
                </plist>
                """
        case .macOS:
            return """
                <?xml version="1.0" encoding="UTF-8"?>
                <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                <plist version="1.0">
                <dict>
                    <key>CFBundleDevelopmentRegion</key>
                    <string>$(DEVELOPMENT_LANGUAGE)</string>
                    <key>CFBundleExecutable</key>
                    <string>$(EXECUTABLE_NAME)</string>
                    <key>CFBundleIconFile</key>
                    <string></string>
                    <key>CFBundleIdentifier</key>
                    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
                    <key>CFBundleInfoDictionaryVersion</key>
                    <string>6.0</string>
                    <key>CFBundleName</key>
                    <string>$(PRODUCT_NAME)</string>
                    <key>CFBundlePackageType</key>
                    <string>APPL</string>
                    <key>CFBundleShortVersionString</key>
                    <string>$(SEMANTIC_PROJECT_VERSION)</string>
                    <key>CFBundleVersion</key>
                    <string>$(CURRENT_PROJECT_VERSION)</string>
                    <key>LSMinimumSystemVersion</key>
                    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
                    <key>NSMainStoryboardFile</key>
                    <string>Main</string>
                    <key>NSPrincipalClass</key>
                    <string>NSApplication</string>
                </dict>
                </plist>
                """
        }
    }

    var appDelegate: String {
        switch self {
        case .iOS:
            return """
                import UIKit
                import Cake

                @UIApplicationMain
                class AppDelegate: UIResponder, UIApplicationDelegate {
                    var window: UIWindow?

                    func application(_: UIApplication, didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
                        window = UIWindow()
                        window!.rootViewController = UIViewController()
                        window!.makeKeyAndVisible()
                        return true
                    }
                }
                """
        case .macOS:
            return """
                import AppKit
                import Cake

                @NSApplicationMain
                class AppDelegate: NSObject, NSApplicationDelegate {
                    func applicationDidFinishLaunching(_ note: Notification) {

                    }
                }
                """
        }
    }
}

extension String {
    static var cakefileScript: String {
        return #"""
        import func Darwin.fputs
        import var Darwin.stderr
        import ScriptingBridge
        import AppKit

        func print(_ objs: Any...) {
            let str = objs.reduce(into: "") { $0.append(" \($1)") }
            fputs(str, stderr)
        }

        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "dev.mxcl.Cake")

        switch apps.count {
        case 0:
            print("warning: Cake.app not running, Cakefile changes will not take effect")
        case 1:
            guard let bundle = apps[0].bundleURL else {
                print("Failed to obtain Cake.app location")
                exit(1)
            }
            guard let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"] else {
                print("Failed to obtain PROJECT_DIR")
                exit(2)
            }
            let path = bundle.appendingPathComponent("Contents/MacOS/cake-build").path
            let task = Process()
            task.launchPath = path
            task.arguments = [String(apps[0].processIdentifier), projectDir]
            try task.run()
            task.waitUntilExit()
            exit(task.terminationStatus)
        default:
            print("error: More than one instance of Cake.app is running")
            exit(3)
        }

        """#
    }
}
