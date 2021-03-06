//
//  TestFifoQueue.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 12.03.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

import XCTest
@testable import SwiftCoroutine

class TestFifoQueue: XCTestCase {
    
    func testPerformance() {
        var queue = FifoQueue<Int>()
        measure {
            DispatchQueue.concurrentPerform(iterations: 100_000) { index in
                queue.push(index)
                _ = queue.pop()
            }
        }
        queue.free()
    }
    
    func testFifoQueue() {
        let lock = NSLock()
        var set = Set<Int>()
        var queue = FifoQueue<Int>()
        DispatchQueue.concurrentPerform(iterations: 100_000) { index in
            if index % 3 == 0 {
                queue.insertAtStart(index)
            } else {
                queue.push(index)
            }
            var hasValue = false
            queue.forEach { _ in hasValue = true }
            XCTAssertTrue(hasValue)
            if let value = queue.pop() {
                lock.lock()
                set.insert(value)
                lock.unlock()
            } else {
                XCTFail()
            }
        }
        XCTAssertEqual(set.count, 100_000)
        XCTAssertNil(queue.pop())
        queue.free()
    }
    
    func testQueue() {
        let exp = expectation(description: "testQueue")
        DispatchQueue.global().async {
            var queue = FifoQueue<Int>()
            for i in 0..<100 { queue.push(i) }
            for i in 0..<50 { XCTAssertEqual(queue.pop(), i) }
            for i in 100..<200 { queue.push(i) }
            for i in 50..<200 { XCTAssertEqual(queue.pop(), i) }
            queue.free()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
    }
    
}
