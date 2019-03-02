import Foundation
import Base
import Path

func createFixture(_ files: String..., body: (Path, [Path]) throws -> Void) throws {
    try createFixture(files: files, body: body)
}

func createFixture(files: [String], body: (Path, [Path]) throws -> Void) throws {
    try Path.mktemp { root in
        let paths = files.map{ root/$0 }
        for path in paths {
            try path.parent.mkdir(.p)
            try path.touch()
        }
        try body(root, paths)
    }
}
