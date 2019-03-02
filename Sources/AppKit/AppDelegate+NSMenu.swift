import AppKit
import Cake

extension AppDelegate: NSMenuDelegate {
    @objc func regenerate(sender: NSMenuItem) {
        guard let index = sender.parent?.tag else {
            return
        }
        do {
            let cake = kitchen.cakes[index]
            try cake.forceRegenerate()
            kitchen(regenerated: cake) // shows notification
        } catch {
            alert(error)
        }
    }

    func updateStatusItemMenu(cake: [CakeProject], notCake: [String]) {
        func notCakeMenu(index: Int) -> NSMenu {
            let menu = NSMenu()
            menu.addItem(withTitle: "Integrate Cake", action: #selector(integrateCake), keyEquivalent: "")
            return menu
        }
        func cakeMenu(for cake: CakeProject, index: Int) -> NSMenu {
            let menu = NSMenu()
            menu.addItem(withTitle: "Update Dependencies", action: #selector(updateDependencies), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Regenerate Cake.xcodeproj", action: #selector(regenerate), keyEquivalent: "")
            menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
//            menu.addItem(.separator())
//            menu.addItem(withTitle: "Deintegrate Cake", action: #selector(deintegrateCake), keyEquivalent: "").tag = index
            menu.delegate = self
            return menu
        }

        menu.removeAllItems()
        for (index, cake) in cake.enumerated() {
            let item = menu.addItem(withTitle: cake.name, action: nil, keyEquivalent: "")
            item.submenu = cakeMenu(for: cake, index: index)
            item.tag = index
        }
        for (index, item) in notCake.enumerated() {
            let item = menu.addItem(withTitle: item, action: nil, keyEquivalent: "")
            item.submenu = notCakeMenu(index: index)
            item.tag = index
        }
        if cake.isEmpty, notCake.isEmpty {
            menu.addItem(withTitle: "No Xcode projects open", action: nil, keyEquivalent: "")
        }
        fillMenuBottom()
    }

    func fillMenuBottom() {
        menu.addItem(.separator())
        let newCake = menu.addItem(withTitle: "New Cake", action: nil, keyEquivalent: "")

        let xcode = menu.addItem(withTitle: "Xcode", action: nil, keyEquivalent: "")
        xcode.submenu = {
            let menu = NSMenu(title: "Xcode")
            let item = menu.addItem(withTitle: "Open Active Project in Terminal", action: #selector(openActiveWorkspaceInTerminal), keyEquivalent: "t")
            item.keyEquivalentModifierMask = [.command, .option, .control]
            menu.addItem(.separator())
            menu.addItem(withTitle: "rm -rf 'Derived Data'", action: #selector(derivedDataDance), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit Xcode", action: #selector(quitXcode), keyEquivalent: "")
            return menu
        }()

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Cake \(Bundle.main.version)", action: #selector(NSApplication.terminate), keyEquivalent: "")

        newCake.submenu = NSMenu()
        newCake.submenu!.addItem(withTitle: "macOS", action: #selector(createNewCake), keyEquivalent: "")
        newCake.submenu!.addItem(withTitle: "iOS", action: #selector(createNewCake), keyEquivalent: "")
    }

    func menuWillOpen(_ menu: NSMenu) {
        let item = menu.items[3]
        let index = item.tag
        let time = kitchen.cakes[index].lastGenerationTime.relativeTimeString
        item.title = "Last generated \(time)"
    }
}

private extension Optional where Wrapped == Date {
    var relativeTimeString: String {
        switch self {
        case .none:
            return "never"
        case .some(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            formatter.doesRelativeDateFormatting = true
            formatter.formattingContext = .middleOfSentence
            return formatter.string(from: date)
        }
    }
}
