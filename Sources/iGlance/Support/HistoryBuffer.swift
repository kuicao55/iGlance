import Foundation

class HistoryBuffer {
    let capacity: Int

    init(capacity: Int = 30) {
        self.capacity = capacity
    }

    func append(value: Double, to buffer: [Double]) -> [Double] {
        var newBuffer = buffer
        newBuffer.append(value)

        // Keep only the last 'capacity' elements
        if newBuffer.count > capacity {
            newBuffer = Array(newBuffer.suffix(capacity))
        }

        return newBuffer
    }

    func append(contentsOf values: [Double], to buffer: [Double]) -> [Double] {
        var newBuffer = buffer
        newBuffer.append(contentsOf: values)

        if newBuffer.count > capacity {
            newBuffer = Array(newBuffer.suffix(capacity))
        }

        return newBuffer
    }
}
