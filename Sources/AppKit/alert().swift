import LegibleError
import Foundation
import AppKit

protocol TitledError: LocalizedError {
    var title: String { get }
}

private func _alert(error: Error, title: String?, file: StaticString, line: UInt) -> (String, String) {
    print("\(file):\(line)", error.legibleDescription, error)

    var computeTitle: String {
        switch (error as NSError).domain {
        case "SKErrorDomain":
            return "App Store Error"
        case "kCLErrorDomain":
            return "Core Location Error"
        case NSCocoaErrorDomain:
            return "Error"
        default:
            return "Unexpected Error"
        }
    }

    let title = title ?? (error as? TitledError)?.title ?? computeTitle

    return (error.legibleLocalizedDescription, title)
}

func alert(_ error: Error, title: String? = nil, file: StaticString = #file, line: UInt = #line) {
    let (msg, title) = _alert(error: error, title: title, file: file, line: line)

    // we cannot make SKError CancellableError sadly (still)
    let pair: (String, Int) = { ($0.domain, $0.code) }(error as NSError)
    guard ("SKErrorDomain", 2) != pair else { return } // user-cancelled
    guard ("NSOSStatusErrorDomain", -128) != pair else { return } // Apple Script user-cancelled

    alert(message: msg, title: title)
}

func alert(message: String, title: String) {
    func go() {
      #if os(macOS)
        let alert = NSAlert()
        alert.informativeText = message
        alert.messageText = title
        alert.addButton(withTitle: "OK")
        alert.runModal()
      #else

      #endif
    }
    if Thread.isMainThread {
        go()
    } else {
        DispatchQueue.main.async(execute: go)
    }
}

import PromiseKit

extension Promise {
    @discardableResult
    func alert(title: String? = nil, file: StaticString = #file, line: UInt = #line) -> PMKFinalizer {
        return self.catch {
            App.alert($0, title: title, file: file, line: line)
        }
    }
}
