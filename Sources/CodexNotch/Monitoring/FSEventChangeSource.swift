import CoreServices
import Foundation

final class FSEventChangeSource {
    static let deliveryLatency: TimeInterval = 0.1
    let rootURL: URL
    var onChange: (([URL]) -> Void)?

    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.david.codexnotch.fs-events")

    init(rootURL: URL) {
        self.rootURL = rootURL
    }

    func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, count, eventPaths, eventFlags, _ in
            guard let info else { return }
            let source = Unmanaged<FSEventChangeSource>
                .fromOpaque(info)
                .takeUnretainedValue()
            let recoveryFlags = FSEventStreamEventFlags(
                kFSEventStreamEventFlagMustScanSubDirs
                    | kFSEventStreamEventFlagUserDropped
                    | kFSEventStreamEventFlagKernelDropped
                    | kFSEventStreamEventFlagEventIdsWrapped
                    | kFSEventStreamEventFlagRootChanged
            )
            let paths = eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
            var urls: [URL] = []
            for index in 0..<count {
                if eventFlags[index] & recoveryFlags != 0 {
                    urls = [source.rootURL]
                    break
                }
                urls.append(URL(fileURLWithPath: String(cString: paths[index])))
            }
            source.onChange?(urls)
        }
        let paths = [rootURL.path] as CFArray
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        )

        guard let newStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            Self.deliveryLatency,
            flags
        ) else {
            return
        }

        stream = newStream
        FSEventStreamSetDispatchQueue(newStream, queue)
        if !FSEventStreamStart(newStream) {
            FSEventStreamInvalidate(newStream)
            FSEventStreamRelease(newStream)
            stream = nil
        }
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }
}
