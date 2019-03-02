import PromiseKit
import AppKit
import Cake

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let menu = NSMenu()
    let statusBarItem = NSStatusBar.system.statusItem(withLength: 22)
    let kitchen = Kitchen(cake: Bundle.main.version)
    let updater = AppUpdater(owner: "mxcl", repo: "Cake")
    var hotKey: HotKey!

    override func awakeFromNib() {
        statusBarItem.button?.appearsDisabled = true
        statusBarItem.button?.image = NSImage(named: "NSStatusBarItem")
        statusBarItem.menu = menu

        PromiseKit.conf.Q.map = .global()

        let name = Notification.Name(rawValue: "dev.mxcl.Cake.build")
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(build), name: name, object: nil)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        kitchen.delegate = self

        hotKey = HotKey(key: .t, modifiers: [.command, .option, .control])
        hotKey.keyDownHandler = { [weak self] in
            self?.openActiveWorkspaceInTerminal()
        }
    }
}

extension AppDelegate: KitchenDelegate {
    func xcode(isRunning: Bool) {
        statusBarItem.button?.appearsDisabled = !isRunning

        menu.removeAllItems()
        menu.addItem(withTitle: isRunning ? "Loading…" : "Xcode not open", action: nil, keyEquivalent: "")
        fillMenuBottom()
    }

    func kitchen(cake: [CakeProject], notCake: [String]) {
        updateStatusItemMenu(cake: cake, notCake: notCake)
    }

    func kitchen(error: Error) {
        alert(error)
    }

    func kitchen(regenerated cake: CakeProject) {
        let note = NSUserNotification()
        note.title = "Regenerated \(cake.name)’s Cake"
        NSUserNotificationCenter.default.deliver(note)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            NSUserNotificationCenter.default.removeDeliveredNotification(note)
        }
    }

    @objc func build(note: Notification) {
        enum E: Error {
            case noPROJECT_DIR
        }
        var userInfo: [String: Any]!
        do {
            guard let path = note.userInfo?["PROJECT_DIR"] as? String else {
                throw E.noPROJECT_DIR
            }
            try kitchen.generate(for: Path.root.join(path).parent)
        } catch {
            userInfo = .init()
            userInfo["error"] = error.legibleLocalizedDescription
            userInfo["error.userInfo"] = (error as NSError).userInfo
        }
        let name = Notification.Name(rawValue: "dev.mxcl.Cake.built")
        DistributedNotificationCenter.default().postNotificationName(name, object: nil, userInfo: userInfo, options: .deliverImmediately)
    }

    @objc func openActiveWorkspaceInTerminal() {
        guard let path = kitchen.activeWorkspace?.parent else {
            NSSound.beep()
            return
        }

        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", "Terminal", path.string]
        task.launch(.promise).alert()
    }
}
