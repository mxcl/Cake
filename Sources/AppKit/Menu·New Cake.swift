import AppKit
import Cake

extension AppDelegate {
    @objc func createNewCake(sender: NSMenuItem) {
        do {
            //TODO figure out deployment targets from xcodebuild or something

            let platform: PlatformSpecification
            switch sender.menu?.index(of: sender) {
            case 0?:
                platform = PlatformSpecification(platform: .macOS, version: Version(10,14,0))
            case 1?:
                platform = PlatformSpecification(platform: .iOS, version: Version(12,0,0))
            default:
                return
            }

            let name = cakes.randomElement()!
            let prefix = Path.home/"Desktop"/name

            enum E: Error {
                case directoryNameConflict
            }

            if prefix.isDirectory {
                throw E.directoryNameConflict
            }

            let (proj, _) = try scaffold(.new(name: name, prefix, platform), cakeVersion: Bundle.main.version)
            NSWorkspace.shared.open(proj.path.url)
        } catch {
            alert(error)
        }
    }
}

private var cakes: [String] {
    return [
        "Madeira Cake",
        "Torte",
        "Savarin",

        "Cherry Cake",
        "Cheesecake",
        "Chocolate Cake",
        "Red Velvet Cake",
        "Key Lime Pie",
        "Pound Cake",
        "Sponge Cake",
        "Upside Down Cake",
        "Icecream Cake",
        "German Chocolate Cake",
        "Cupcake",
        "Strawberry Shortcake",
        "Fruitcake",
        "Bundt Cake",
        "Hummingbird Cake",
        "Black Forest Cake",
        "Angel Food Cake",
        "Carrot Cake",
        "Christmas Pudding",
        "Yule Log",
        "Bûche de Noël",
        "Devil’s Food Cake",
        "Pumpkin Roll",
        "Bread Pudding",
        "Coffee Cake",
        "Birthday Cake",
        "Pancake",
        "Chocolate Lava Cake",
        "Pineapple Upside‐down Cake"
    ]
}
