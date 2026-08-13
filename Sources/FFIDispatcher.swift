//
//  FFIDispatcher.swift
//  Minimuxer
//
//  Created by Magesh K on 12/8/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation

/*
 Offloads synchronous blocking C-FFI / kernel operations to a dedicated GCD queue,
 immediately suspending the Swift task to prevent thread pool starvation.

 IdeviceGateway owns shared adapter and handshake handles. Every operation touching
 those handles must be serialized so one request cannot invalidate a connection
 while another request is still using it.
 */
private let ffiDispatchQueue = DispatchQueue(
    label: "com.sidestore.minimuxer.idevice-ffi",
    qos: .default,
    autoreleaseFrequency: .workItem
)

@inline(__always)
internal func withFFIDispatch<T: Sendable>(
    _ body: @escaping @Sendable () throws -> T
) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        ffiDispatchQueue.async {
            do {
                let result = try body()
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// This is required since we want to dissociate the caller priority from what rust internally uses so that
// thread checker doesn't complain inversion of priority (ex: if caller was Task instantiated from MainThread,
// then it is of .userInitiated priority by default, but our rust tokio threads are at .background priority
//
@inline(__always)
internal func matchingPriority<T: Sendable>(
    priority: TaskPriority = .medium,
    _ body: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await Task.detached(priority: priority) {
        try await body()
    }.value
}
