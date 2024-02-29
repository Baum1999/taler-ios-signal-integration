//
//    Copyright 2020 Robert Salesas
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
//  and associated documentation files (the "Software"), to deal in the Software without restriction,
//  including without limitation the rights to use, copy, modify, merge, publish, distribute,
//  sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or
//  substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
//  BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
import Foundation

/// `CStringArray` represents a C null-terminated array of pointers to C strings.
///
/// The lifetime of the C strings will correspond to the lifetime of the `CStringArray`
/// instance so be careful about copying the buffer as it may contain dangling pointers.

public struct CStringArray {
    public let pointer: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    public let count: Int
    private var data: Data

    public init(_ array: [String]) {
        let count = array.count

        // Allocate memory to hold the CStrings and a terminating nil
        let pointer = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: count + 1)
        pointer.initialize(repeating: nil, count: count + 1)  // Implicit terminating nil at the end of the array

        // Populate the allocated memory with pointers to CStrings
        var e = 0
        array.forEach {
            pointer[e] = strdup($0)
            e += 1
        }

        // This uses the deallocator available on the data structure as a solution to the fact that structs do not have `deinit`
        self.data = Data(bytesNoCopy: pointer, count: MemoryLayout<UnsafeMutablePointer<CChar>>.size * count, deallocator: .custom({_,_ in
            for i in 0...count - 1 {
                free(pointer[i])
            }
            pointer.deallocate()
        }))

        self.pointer = pointer
        self.count = array.count
    }

    public subscript(index: Data.Index) -> UnsafeMutablePointer<CChar>? {
        get {
            precondition(index >= 0 && index < count, "Index out of range")
            return pointer[index]
        }
    }

    public subscript(index: Data.Index) -> String? {
        get {
            precondition(index >= 0 && index < count, "Index out of range")
            if let pointee = pointer[index] {
                return String(cString: pointee)
            }

            return nil
        }
    }
}
