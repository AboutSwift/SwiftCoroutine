//
//  DispatchSourceTimer.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 04.01.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

import Dispatch

extension DispatchSource {
    
    @inlinable internal
    static func createTimer(timeout: DispatchTime,
                            handler: @escaping () -> Void) -> DispatchSourceTimer {
        let timer = makeTimerSource()
        timer.schedule(deadline: timeout)
        timer.setEventHandler(handler: handler)
        return timer
    }
    
}
