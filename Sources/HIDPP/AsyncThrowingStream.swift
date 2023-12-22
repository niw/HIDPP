//
//  AsyncThrowingStream.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/21/23.
//

import Foundation

/*
MIT License

Copyright (c) 2023 Point-Free

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

extension AsyncThrowingStream where Failure == Error {
    init<S: AsyncSequence>(_ sequence: S) where S.Element == Element {
        let lock = NSLock()
        var iterator: S.AsyncIterator?
        self.init {
            lock.withLock {
                if iterator == nil {
                    iterator = sequence.makeAsyncIterator()
                }
            }
            return try await iterator?.next()
        }
    }
}

extension AsyncSequence {
    func eraseToThrowingStream() -> AsyncThrowingStream<Element, any Error> {
        AsyncThrowingStream(self)
    }
}
