import AppKit
import Cake

extension AppDelegate {
    @objc func integrateCake(sender: NSMenuItem) {
        guard let index = sender.parent?.tag else {
            return
        }
        do {
            let path = kitchen.notCakes[index]
            let proj = try XcodeProject(existing: path)
            let (_,_) = try scaffold(.existing(proj), cakeVersion: Bundle.main.version)

            //TODO update menu items

        } catch {
            alert(error)
        }
    }

    @objc func deintegrateCake(sender: NSMenuItem) {
        guard let index = sender.parent?.tag else {
            return
        }
        do {
            let item = kitchen.cakes[index]
            let proj = try XcodeProject(existing: item.xcodeproj)
            let cake = try XcakeProject(existing: item.prefix/".cake/Cake.xcodeproj")
            try cake.deintegrate(proj)

        } catch {
            alert(error)
        }
    }

    @objc func updateDependencies(sender: NSMenuItem) {
        guard let index = sender.parent?.tag else {
            return
        }
        do {
            try kitchen.cakes[index].updateDependencies()
        } catch {
            alert(error)
        }
    }
}
