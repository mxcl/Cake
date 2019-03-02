import AppKit

/**
 Using distributed notifications.

 We tried AppleEvents (ie. AppleScript) but due to the AEpocalypse
 this was extremely fickle.

 Which is a pity.

 If there’s a better XPC system that allows blocking that we can use,
 please let us know.
 */

let pid = pid_t(CommandLine.arguments[1])!
let PROJECT_DIR = CommandLine.arguments[2]

guard let app = NSRunningApplication(processIdentifier: pid) else {
    fputs("error: no such pid: \(pid)\n", stderr)
    exit(1)
}

let name = Notification.Name(rawValue: "dev.mxcl.Cake.build")
let center = DistributedNotificationCenter.default()
let userInfo = ["PROJECT_DIR": PROJECT_DIR]
center.postNotificationName(name, object: nil, userInfo: userInfo, options: .deliverImmediately)

class Waiter: NSObject {
    override init() {
        super.init()
        let name = Notification.Name(rawValue: "dev.mxcl.Cake.built")
        center.addObserver(self, selector: #selector(result), name: name, object: nil)
    }

    @objc func result(notification: Notification) {
        if let userInfo = notification.userInfo, let error = userInfo["error"] as? String {
            fputs("error: \(error)\n", stderr)
            if let userInfo = userInfo["error.userInfo"] {
                fputs("notice: \(userInfo)\n", stderr)
            }
            exit(2)
        } else {
            exit(0)
        }
    }
}

let waiter = Waiter()
RunLoop.main.run()
