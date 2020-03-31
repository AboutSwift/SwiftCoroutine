//
//  CoFutureAwaitTests.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 17.03.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

import XCTest
@testable import SwiftCoroutine

class CoFutureAwaitTests: XCTestCase {

    func testOutCoroutineCall() {
        let promise = CoPromise<Int>()
        do {
            _ = try promise.await()
            XCTFail()
        } catch let error as CoroutineError {
            return XCTAssertEqual(error, .mustBeCalledInsideCoroutine)
        } catch {
            XCTFail()
        }
    }

    func testAwait() {
        let exp = expectation(description: "testAwait")
        let promise = CoPromise<Int>()
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
            promise.success(1)
        }
        DispatchQueue.main.startCoroutine {
            XCTAssertEqual(try promise.await(), 1)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
    }

    func testConcurrency() {
        let array = UnsafeMutableBufferPointer<Int>.allocate(capacity: 100_000)
        let exp = expectation(description: "testConcurrency")
        exp.expectedFulfillmentCount = array.count
        let queue = DispatchQueue.global()
        DispatchQueue.concurrentPerform(iterations: array.count) { index in
            let promise = CoPromise<Int>()
            queue.asyncAfter(deadline: .now() + .microseconds(index)) {
                promise.success(index)
            }
            queue.asyncAfter(deadline: .now() + .microseconds(array.count - index)) {
                queue.startCoroutine {
                    array[index] = try promise.await()
                    exp.fulfill()
                }
            }
        }
        wait(for: [exp], timeout: 10)
        XCTAssertTrue(array.enumerated().allSatisfy { $0.element == $0.offset })
        array.deallocate()
    }

    func testNestetAwaits() {
        let queue = DispatchQueue.global()
        let group = DispatchGroup()
        measure {
            group.enter()
            queue.coFuture {
                try (0..<100).map { _ in
                    queue.coFuture {
                        try (0..<100)
                            .map { _ in CoFuture(value: ()) }
                            .forEach { try $0.await() }
                    }
                }.forEach { try $0.await() }
                group.leave()
            }.whenFailure { _ in
                XCTFail()
                group.leave()
            }
            group.wait()
        }
    }

}
