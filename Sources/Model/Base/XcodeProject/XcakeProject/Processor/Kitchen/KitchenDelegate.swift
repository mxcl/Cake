public protocol KitchenDelegate: class {
    func xcode(isRunning: Bool)
    func kitchen(cake: [CakeProject], notCake: [String])
    func kitchen(error: Error)
    func kitchen(regenerated: CakeProject)
}
