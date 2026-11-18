import Foundation
import Testing
@testable import Tanga

struct CalcInputTests {
    @Test func typingReplacesSeededValue() {
        var input = CalcInput(text: "650", replaceOnType: true)
        input.digit(1)
        #expect(input.text == "1")
    }

    @Test func leadingZeroIsReplaced() {
        var input = CalcInput(text: "0", replaceOnType: false)
        input.digit(0)
        input.digit(5)
        #expect(input.text == "5")
    }

    @Test func operatorPrecedence() {
        #expect(CalcInput(text: "2+3*4", replaceOnType: false).value == 14)
        #expect(CalcInput(text: "10-6/3", replaceOnType: false).value == 8)
    }

    @Test func trailingOperatorIsIgnored() {
        #expect(CalcInput(text: "10+", replaceOnType: false).value == 10)
    }

    @Test func operatorReplacesOperator() {
        var input = CalcInput(text: "10", replaceOnType: false)
        input.apply(.add)
        input.apply(.multiply)
        #expect(input.text == "10*")
    }

    @Test func operatorContinuesSeededValue() {
        var input = CalcInput(text: "650", replaceOnType: true)
        input.apply(.add)
        input.digit(5)
        #expect(input.text == "650+5")
        #expect(input.value == 655)
    }

    @Test func divisionByZeroGivesNil() {
        #expect(CalcInput(text: "5/0", replaceOnType: false).value == nil)
    }

    @Test func singleDecimalPointPerNumber() {
        var input = CalcInput(text: "1.5", replaceOnType: false)
        input.decimalPoint()
        #expect(input.text == "1.5")
        input.apply(.add)
        input.decimalPoint()
        #expect(input.text == "1.5+0.")
    }

    @Test func backspaceFallsBackToZero() {
        var input = CalcInput(text: "7", replaceOnType: false)
        input.backspace()
        #expect(input.text == "0")
    }

    @Test func negativeSeedIsSign() {
        #expect(CalcInput(text: "-5+2", replaceOnType: false).value == -3)
    }

    @Test func displayGroupsDigits() {
        let input = CalcInput(text: "1172084.21+5", replaceOnType: false)
        #expect(input.display(locale: Locale(identifier: "en_US")) == "1,172,084.21 + 5")
    }
}
