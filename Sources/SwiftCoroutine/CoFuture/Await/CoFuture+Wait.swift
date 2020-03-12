//
//  CoFuture+Wait.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 30.12.2019.
//  Copyright © 2019 Alex Belozierov. All rights reserved.
//

import Dispatch

extension CoFuture {
    
    public func wait(timeout: DispatchTime? = nil) throws -> Value {
        assert(!Coroutine.isInsideCoroutine, "Use await inside coroutine")
        let group = DispatchGroup()
        group.enter()
        whenComplete { _ in group.leave() }
        if let timeout = timeout {
            if group.wait(timeout: timeout) == .timedOut {
                throw CoFutureError.timeout
            }
        } else {
            group.wait()
        }
        return try _result!.get()
    }
    
}
