import Foundation
import XCTest
@testable import NicoMirrorConnection

final class AnnexBResynchronizerTests: XCTestCase {
    private let keyframe = Data([0, 0, 0, 1, 0x67, 0x42, 0x11, 0, 0, 0, 1, 0x68, 0x22, 0, 0, 1, 0x65, 0x33])

    func testResumesAtSPSForEveryPossibleTCPSplit() {
        let garbage = Data([0x99, 0x88, 0, 0, 1, 0x41, 0x44])
        let stream = garbage + keyframe
        for split in 0...stream.count {
            var parser = AnnexBResynchronizer()
            let first = parser.append(Data(stream.prefix(split))) ?? Data()
            let second = parser.append(Data(stream.dropFirst(split))) ?? Data()
            XCTAssertEqual(first + second, keyframe, "split \(split)")
        }
    }

    func testByteAtATimePreservesWholeStreamAfterSPS() {
        var parser = AnnexBResynchronizer()
        var result = Data()
        for byte in keyframe {
            result.append(parser.append(Data([byte])) ?? Data())
        }
        XCTAssertEqual(result, keyframe)
    }

    func testThreeBytePrefixesAndReset() {
        var parser = AnnexBResynchronizer()
        let sps = Data([0, 0, 1, 0x67, 0x42])
        XCTAssertEqual(parser.append(sps), sps)
        XCTAssertEqual(parser.append(Data([0x11, 0x22])), Data([0x11, 0x22]))
        parser.reset()
        XCTAssertNil(parser.append(Data([0x11, 0x22])))
        XCTAssertEqual(parser.append(sps), sps)
    }

    func testLongNonKeyframeDataDoesNotSynchronize() {
        var parser = AnnexBResynchronizer()
        XCTAssertNil(parser.append(Data(repeating: 0x41, count: 1_000_000)))
        XCTAssertNil(parser.append(Data()))
        XCTAssertEqual(parser.append(keyframe), keyframe)
    }
}
