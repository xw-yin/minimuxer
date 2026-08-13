import Foundation
import XCTest
@testable import Minimuxer

final class FFIDispatcherTests: XCTestCase {
    private final class ConcurrencyProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var activeCount = 0
        private(set) var maximumActiveCount = 0

        func enter() {
            lock.withLock {
                activeCount += 1
                maximumActiveCount = max(maximumActiveCount, activeCount)
            }
        }

        func leave() {
            lock.withLock {
                activeCount -= 1
            }
        }
    }

    func testFFIWorkIsSerialized() async throws {
        let probe = ConcurrencyProbe()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    try await withFFIDispatch {
                        probe.enter()
                        defer { probe.leave() }
                        Thread.sleep(forTimeInterval: 0.02)
                    }
                }
            }
            try await group.waitForAll()
        }

        XCTAssertEqual(probe.maximumActiveCount, 1)
    }
}
