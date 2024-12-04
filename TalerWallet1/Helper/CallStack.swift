//
//  Copyright © 2018-2023 Marc Stibane
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

struct CallStackItem {
#if DEBUG
    let file: String
    let function: String
#endif
    let message: String
}

#if DEBUG
extension CallStackItem: Identifiable {
    var id: String { file }
}
extension CallStackItem: Equatable {
    static func == (lhs: CallStackItem, rhs: CallStackItem) -> Bool {
        lhs.file == rhs.file
    }
}
#endif


struct CallStack {
    private var stack = [CallStackItem]()
    func peek() -> CallStackItem? { stack.first }
    func push(item: CallStackItem) -> CallStack {
        return CallStack(stack: [item] + stack)
    }
}

#if DEBUG
fileprivate func filePath2Name(_ file: String) -> String {
    let filePath = NSString(string: file)
    return filePath.lastPathComponent
}
#endif

extension CallStack {
#if DEBUG
    init(_ message: String = EMPTYSTRING,
          funcName: String = #function,
          filePath: String = #file,
              line: UInt = #line) {
        let item = CallStackItem(file: filePath2Name(filePath) + ":\(line)", function: funcName, message: message)
        self.stack = [item]
    }
#else
    init(_ message: String = EMPTYSTRING) {
        let item = CallStackItem(message: message)
        self.stack = [item]
    }
#endif
#if DEBUG
    public func push(_ message: String = EMPTYSTRING,
                      funcName: String = #function,
                      filePath: String = #file,
                          line: UInt = #line) -> CallStack {
        let item = CallStackItem(file: filePath2Name(filePath) + ":\(line)", function: funcName, message: message)
        return push(item: item)
    }
#else
    public func push(_ message: String = EMPTYSTRING) -> CallStack {
        let item = CallStackItem(message: message)
        return push(item: item)
    }
#endif
    public func print() -> String {
        var result: String = EMPTYSTRING
        for (item) in stack {
#if DEBUG
            result += item.file + SPACE + item.function + "; "
#else
            result += item.message + "; "
#endif
        }
        return result
    }
}

//extension CallStack: Equatable {
//    static func == (lhs: CallStack, rhs: CallStack) -> Bool { lhs.storage == rhs.storage }
//}
