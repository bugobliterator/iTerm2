//
//  CarbonKeystrokePreferenceTests.swift
//  iTerm2XCTests
//
//  Tests the rule NSEvent.keyDown(forCharacter:) uses to choose among several
//  keystrokes that produce the same string on the active layout. The US layout
//  maps Shift+Arrow to = / * +, and those keystrokes must not displace the
//  ordinary keys, or a CSI u encoder reports the arrow key instead.
//

import XCTest
import Carbon
@testable import iTerm2SharedARC

final class CarbonKeystrokePreferenceTests: XCTestCase {
    private let shift = UInt32(shiftKey)
    private let option = UInt32(optionKey)

    private func keystroke(_ keyCode: Int, _ modifiers: UInt32 = 0) -> CarbonKeystroke {
        return CarbonKeystroke(keyCode: UInt16(keyCode), modifiers: modifiers)
    }

    /// Mirrors how the reverse map is built: keep the first candidate, then replace
    /// it with each later one that is preferred.
    private func winner(_ candidates: [CarbonKeystroke]) -> CarbonKeystroke? {
        var best: CarbonKeystroke?
        for candidate in candidates {
            if let existing = best, !candidate.isPreferred(over: existing) {
                continue
            }
            best = candidate
        }
        return best
    }

    private func assertWinner(_ candidates: [CarbonKeystroke],
                              _ expected: CarbonKeystroke,
                              file: StaticString = #filePath,
                              line: UInt = #line) {
        // The result must not depend on visiting order.
        for order in [candidates, Array(candidates.reversed())] {
            let actual = winner(order)
            XCTAssertEqual(actual?.keyCode, expected.keyCode, file: file, line: line)
            XCTAssertEqual(actual?.modifiers, expected.modifiers, file: file, line: line)
        }
    }

    func testUnmodifiedKeyBeatsShiftedArrow() {
        // “/” and “=”: the plain key has fewer modifiers than Shift+Arrow.
        assertWinner([keystroke(kVK_ANSI_Slash), keystroke(kVK_UpArrow, shift)],
                     keystroke(kVK_ANSI_Slash))
        assertWinner([keystroke(kVK_ANSI_Equal), keystroke(kVK_DownArrow, shift)],
                     keystroke(kVK_ANSI_Equal))
    }

    func testEqualModifiersPreferLowerKeyCode() {
        // “*” and “+”: Shift+8 and Shift+= tie with Shift+Arrow on modifiers.
        assertWinner([keystroke(kVK_ANSI_8, shift), keystroke(kVK_RightArrow, shift)],
                     keystroke(kVK_ANSI_8, shift))
        assertWinner([keystroke(kVK_ANSI_Equal, shift), keystroke(kVK_LeftArrow, shift)],
                     keystroke(kVK_ANSI_Equal, shift))
    }

    func testFullCandidateSetForAsterisk() {
        assertWinner([keystroke(kVK_ANSI_KeypadMultiply),
                      keystroke(kVK_ANSI_8, shift),
                      keystroke(kVK_RightArrow, shift),
                      keystroke(kVK_ANSI_KeypadMultiply, shift)],
                     keystroke(kVK_ANSI_8, shift))
    }

    func testNonKeypadBeatsKeypadEvenWithMoreModifiers() {
        assertWinner([keystroke(kVK_ANSI_KeypadPlus), keystroke(kVK_ANSI_Equal, shift)],
                     keystroke(kVK_ANSI_Equal, shift))
    }

    func testFewerModifiersBeatsMore() {
        assertWinner([keystroke(kVK_ANSI_A, shift | option), keystroke(kVK_ANSI_S, option)],
                     keystroke(kVK_ANSI_S, option))
    }

    func testShiftBeatsOption() {
        assertWinner([keystroke(kVK_ANSI_A, option), keystroke(kVK_ANSI_S, shift)],
                     keystroke(kVK_ANSI_S, shift))
    }

    func testNotPreferredOverItself() {
        let k = keystroke(kVK_ANSI_Slash)
        XCTAssertFalse(k.isPreferred(over: k))
    }
}
