import AppKit
import Cake

extension AppDelegate {
    @objc func derivedDataDance(sender: NSMenuItem) {
        do {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dt.Xcode")
            for app in apps {
                let xcode = try Xcode(pid: app.processIdentifier)
                let dd = xcode.derivedData
                
                // sanity checks, shouldn’t happen, but we should be careful!
                guard dd != Path.root, dd != Path.home else { return }
                
                if xcode.isRunning {
                    let docs = xcode.documents
                    try xcode.quit()
                    try dd.delete()
                    xcode.open(documents: docs)
                } else {
                    try dd.delete()
                }
            }
        } catch {
            alert(error)
        }
    }

    @objc func quitXcode(sender: NSMenuItem) {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dt.Xcode")
        for app in apps {
            if !app.terminate() {
                print("warning: failed to terminate Xcode")
            }
        }
    }
}
