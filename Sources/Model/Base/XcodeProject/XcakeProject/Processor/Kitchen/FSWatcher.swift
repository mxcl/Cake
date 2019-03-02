import Foundation

protocol FSWatcherDelegate: class {
    func fsWatcherRescanRequired()
    func fsWatcher(paths: [String], events: [FSWatcher.Event])
}

class FSWatcher {

    private var stream: FSEventStreamRef?

    weak var delegate: FSWatcherDelegate? {
        didSet {
            if delegate == nil {
                pause()
            } else {
                resume()
            }
        }
    }

    deinit {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    var watchingPaths: Set<String> = [] {
        didSet {
            guard watchingPaths != oldValue else { return }

            pause()
            stream = nil
            start()
        }
    }

    private func start() {
        guard stream == nil, !watchingPaths.isEmpty else {
            return
        }

        let paths = Array(watchingPaths) as CFArray

        var context = FSEventStreamContext(version: 0, info: UnsafeMutableRawPointer(mutating: Unmanaged.passUnretained(self).toOpaque()), retain: nil, release: nil, copyDescription: nil)
        stream = FSEventStreamCreate(kCFAllocatorDefault, innerEventCallback, &context, paths, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0, UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents))
        FSEventStreamScheduleWithRunLoop(stream!, RunLoop.current.getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream!)
    }

    func resume() {
        _ = stream.map(FSEventStreamStart)
    }

    func pause() {
        stream.map(FSEventStreamStop)
    }

    private let innerEventCallback: FSEventStreamCallback = { (stream, contextInfo, numEvents, eventPaths, eventFlags, eventIds) in
        let fsWatcher = unsafeBitCast(contextInfo, to: FSWatcher.self)
        func path(at: Int) -> String {
            return unsafeBitCast(eventPaths, to: NSArray.self)[at] as! String
        }

        var paths: [String] = []
        var events: [Event] = []

        for x in 0..<numEvents {
            let flags = Flag(rawValue: eventFlags[x])

            if flags.contains(.rescan) {
                fsWatcher.delegate?.fsWatcherRescanRequired()
                return
            }

            var event: Event? {
                if flags.contains(.removed) {
                    return .deleted
                } else if flags.contains(.created) {
                    return .created
                } else if flags.contains(.renamed) {
                    return .renamed
                } else if flags.contains(.modified) {
                    return .modified
                } else {
                    return nil
                }
            }
            if let e = event {
                paths.append(path(at: x))
                events.append(e)
            }
        }

        assert(paths.count == events.count)

        if !paths.isEmpty {
            fsWatcher.delegate?.fsWatcher(paths: paths, events: events)
        }
    }

    enum Event {
        case created
        case modified
        case deleted
        case renamed
    }
}

private struct Flag: OptionSet {
    let rawValue: FSEventStreamEventFlags
    init(rawValue: FSEventStreamEventFlags) {
        self.rawValue = rawValue
    }
    init(_ value: Int) {
        self.rawValue = FSEventStreamEventFlags(value)
    }

    // we don’t care about most events

    static let created = Flag(kFSEventStreamEventFlagItemCreated)
    static let modified = Flag(kFSEventStreamEventFlagItemModified)
    static let removed = Flag(kFSEventStreamEventFlagItemRemoved)
    static let renamed = Flag(kFSEventStreamEventFlagItemRenamed)

    static let rescan = Flag(kFSEventStreamEventFlagMustScanSubDirs)
}
