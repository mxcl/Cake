import CakefileDescription
import XCTest

//TODO good opportunity to use cake’s test generators
// eg. could replace warning() so it injects, thus making it testable
// eg. could make the variables not global

class CakefileDescriptionTests: XCTestCase {
    func test() {
        let cakefile = """
            import Cakefile

            dependencies = [
                .github("mxcl/PromiseKit" ~> 6)
            ]

            platforms = [.macOS ~> 10.14, .iOS ~> 12]
            """
        _ = cakefile
        //TODO
    }
}
