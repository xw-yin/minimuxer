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

 Device gateways own shared adapter and handshake handles. Serialize operations
 touching those handles so one request cannot invalidate an in-flight connection.
 */
private let ffiDispatchQueue = DispatchQueue(
    label: "com.sidestore.minimuxer.idevice-ffi",
    qos: .default,
    autoreleaseFrequency: .workItem
)

/// Synchronous variant of withFFIDispatch for non-async callers such as
/// protocol property getters. Blocks the calling thread until the FFI serial
/// queue runs the body. Must never be called from within a withFFIDispatch
/// body: the queue is serial and that would deadlock.
@inline(__always)
public func withFFIDispatchSync<T: Sendable>(
    _ body: @escaping @Sendable () throws -> T
) rethrows -> T {
    try ffiDispatchQueue.sync(execute: body)
}

@inline(__always)
public func withFFIDispatch<T: Sendable>(
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
public func matchingPriority<T: Sendable>(
    priority: TaskPriority = .medium,
    _ body: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await Task.detached(priority: priority) {
        try await body()
    }.value
}
