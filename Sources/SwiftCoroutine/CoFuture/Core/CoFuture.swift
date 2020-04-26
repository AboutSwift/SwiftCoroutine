//
//  CoFuture2.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 26.01.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

private protocol _CoFutureCancellable: class {

    func cancel()
    
}

/// Holder for a result that will be provided later.
///
/// `CoFuture` and its subclass `CoPromise` are the implementation of the Future/Promise approach.
/// They allow to launch asynchronous tasks and immediately return` CoFuture` with its future results.
/// The available result can be observed by the `whenComplete()` callback
/// or by `await()` inside a coroutine without blocking a thread.
///
/// ```
/// func makeFutureOne(args) -> CoFuture<Response> {
///     let promise = CoPromise<Response>()
///     someAsyncFuncWithCallback { response in
///         . . . do some work . . .
///         promise.success(response)
///     }
///     return promise
/// }
///
/// func makeFutureTwo(args) -> CoFuture<Response> {
///     queue.coroutineFuture {
///         let future = makeFutureOne(args)
///         . . . do some work . . .
///         let response = try future.await()
///         . . . create result using response . . .
///         return result
///     }
///  }
///
/// func performSomeWork(args) {
///     let future = makeFutureTwo(args)
///     mainQueue.startCoroutine {
///         . . . do some work . . .
///         let result = try future.await()
///         . . . do some work using result . . .
///     }
/// }
/// ```
public class CoFuture<Value> {
    
    private struct Node {
        let callback: Callback
        var next = 0
    }
    
    private var nodeList, resultState: AtomicInt
    private var _result: Optional<Result<Value, Error>>
    private var parent: UnownedCancellable?
    
    @usableFromInline internal init(_result: Result<Value, Error>?) {
        if let result = _result {
            self._result = result
            resultState = AtomicInt(value: 1)
            nodeList = AtomicInt(value: -1)
        } else {
            self._result = nil
            resultState = AtomicInt()
            nodeList = AtomicInt()
        }
    }
    
    deinit {
        if nodeList.value > 0 {
            completeCallbacks(with: .failure(CoFutureError.canceled))
        }
    }
    
}

extension CoFuture: _CoFutureCancellable {

    /// Starts a new coroutine and initializes future with its result.
    /// ```
    /// func sum(future1: CoFuture<Int>, future2: CoFuture<Int>) -> CoFuture<Int> {
    ///     CoFuture { try future1.await() + future2.await() }
    /// }
    /// ```
    /// - Parameter task: The closure that will be executed inside the coroutine.
    public convenience init(task: @escaping () throws -> Value) {
        self.init(_result: nil)
        Coroutine.start { self.setResult(Result(catching: task)) }
    }
    
    /// Initializes a future with result.
    /// - Parameter result: The result provided by this future.
    public convenience init(result: Result<Value, Error>) {
        self.init(_result: result)
    }
    
    // MARK: - result
    
    /// Returns completed result or nil if this future has not been completed yet.
    public var result: Result<Value, Error>? {
        nodeList.value < 0 ? _result : nil
    }
    
    @usableFromInline internal func setResult(_ result: Result<Value, Error>) {
        guard resultState.update(1) == 0 else { return }
        _result = result
        parent = nil
        completeCallbacks(with: result)
    }
    
    private func completeCallbacks(with result: Result<Value, Error>) {
        var nodeAddress = nodeList.update(-1)
        while nodeAddress > 0, let pointer = UnsafeMutablePointer<Node>(bitPattern: nodeAddress) {
            nodeAddress = pointer.pointee.next
            pointer.pointee.callback(result)
            pointer.deinitialize(count: 1)
            pointer.deallocate()
        }
    }
    
    // MARK: - Callback
    
    internal typealias Callback = (Result<Value, Error>) -> Void
    
    @usableFromInline
    internal func addCallback(_ callback: @escaping (Result<Value, Error>) -> Void) {
        var pointer: UnsafeMutablePointer<Node>!
        let new = nodeList.update {
            if $0 < 0 { return $0 }
            if pointer == nil {
                pointer = .allocate(capacity: 1)
                pointer.initialize(to: Node(callback: callback))
            }
            pointer.pointee.next = $0
            return Int(bitPattern: pointer)
        }.new
        if new < 0 {
            pointer?.deinitialize(count: 1)
            pointer?.deallocate()
            _result.map(callback)
        }
    }
    
    internal func addChild<T>(future: CoFuture<T>, callback: @escaping Callback) {
        future.parent = .init(cancellable: self)
        addCallback(callback)
    }
    
    // MARK: - cancel
    
    private struct UnownedCancellable {
        unowned(unsafe) let cancellable: _CoFutureCancellable
    }

    /// Returns `true` when the current future is canceled.
    @inlinable public var isCanceled: Bool {
        if case .failure(let error as CoFutureError)? = result {
            return error == .canceled
        }
        return false
    }
    
    /// Cancels the current future.
    public func cancel() {
        if let parent = parent {
            parent.cancellable.cancel()
        } else {
            setResult(.failure(CoFutureError.canceled))
        }
    }
    
}
