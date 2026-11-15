import SwiftUI
import PianoCore

enum KeyMark: Equatable {
    case expected      // press this next
    case correct       // held and right
    case wrong         // held and not wanted
    case neutral       // held, not being judged
    case shown         // highlighted in a lesson picture
}

/// A drawing of the piano keys. States use shapes as well as colours so they can be told apart without colour vision.
struct KeyboardView: View {
    var lowest: Int = 48
    var highest: Int = 84
    var marks: [Int: KeyMark] = [:]
    var labels: [Int: String] = [:]
    var onTap: ((Int) -> Void)? = nil

    private static let blackClasses: Set<Int> = [1, 3, 6, 8, 10]
    private func isBlack(_ note: Int) -> Bool { KeyboardView.blackClasses.contains(((note % 12) + 12) % 12) }

    private var range: ClosedRange<Int> {
        var low = min(lowest, highest), high = max(lowest, highest)
        while isBlack(low) { low -= 1 }
        while isBlack(high) { high += 1 }
        return low...high
    }

    private func color(_ mark: KeyMark) -> Color {
        switch mark {
        case .expected: return Color.blue
        case .correct: return Color.green
        case .wrong: return Color.red
        case .neutral: return Color.gray
        case .shown: return Color.orange
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let whites = range.filter { !isBlack($0) }
            let whiteWidth = geometry.size.width / CGFloat(max(whites.count, 1))
            let height = geometry.size.height
            ZStack(alignment: .topLeading) {
                ForEach(Array(whites.enumerated()), id: \.element) { index, note in
                    keyShape(note: note, black: false, width: whiteWidth, height: height)
                        .offset(x: CGFloat(index) * whiteWidth)
                }
                ForEach(Array(whites.enumerated()), id: \.element) { index, note in
                    if isBlack(note + 1) && note + 1 <= range.upperBound {
                        keyShape(note: note + 1, black: true, width: whiteWidth * 0.62, height: height * 0.62)
                            .offset(x: CGFloat(index + 1) * whiteWidth - whiteWidth * 0.31)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private func keyShape(note: Int, black: Bool, width: CGFloat, height: CGFloat) -> some View {
        let mark = marks[note]
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3)
                .fill(mark.map { $0 == .expected ? (black ? Color.black : Color.white) : color($0).opacity(black ? 0.95 : 0.55) } ?? (black ? Color.black : Color.white))
            RoundedRectangle(cornerRadius: 3)
                .stroke(mark == .expected ? Color.blue : Color.black.opacity(0.55), lineWidth: mark == .expected ? 3 : 1)
            VStack(spacing: 2) {
                if let mark {
                    switch mark {
                    case .expected: Circle().fill(Color.blue).frame(width: min(width * 0.5, 16), height: min(width * 0.5, 16))
                    case .correct: Image(systemName: "checkmark").font(.system(size: min(width * 0.5, 15), weight: .bold)).foregroundColor(black ? .white : .black)
                    case .wrong: Image(systemName: "xmark").font(.system(size: min(width * 0.5, 15), weight: .bold)).foregroundColor(black ? .white : .black)
                    case .neutral, .shown: EmptyView()
                    }
                }
                if let label = labels[note] {
                    Text(label).font(.system(size: min(max(width * 0.42, 9), 14), weight: .semibold)).foregroundColor(black ? .white : .black)
                        .minimumScaleFactor(0.6).lineLimit(1)
                } else if !black && note % 12 == 0 {
                    Text("C\(note / 12 - 1)").font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 5)
        }
        .frame(width: max(width - 1, 2), height: height)
        .contentShape(Rectangle())
        .onTapGesture { onTap?(note) }
    }

    private var accessibilityText: String {
        let expected = marks.filter { $0.value == .expected || $0.value == .shown }.keys.sorted().map { MIDINote.name($0) }
        let wrong = marks.filter { $0.value == .wrong }.keys.sorted().map { MIDINote.name($0) }
        var parts: [String] = ["Piano keyboard."]
        if !expected.isEmpty { parts.append("Highlighted: \(expected.joined(separator: ", ")).") }
        if !wrong.isEmpty { parts.append("Wrong keys held: \(wrong.joined(separator: ", ")).") }
        return parts.joined(separator: " ")
    }
}
