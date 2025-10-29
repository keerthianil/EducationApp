//
//  A11yComponents.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//
import SwiftUI
import Combine

struct ScreenHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.largeTitle.bold())
            .accessibilityAddTraits(.isHeader)
            .accessibilityHeading(.h1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StepProgress: View {
    let current: Int, total: Int
    var body: some View {
        ProgressView(value: Double(current), total: Double(total))
            .progressViewStyle(.linear)
            .accessibilityLabel("Step \(current) of \(total)")
            .accessibilityValue("\(Int((Double(current)/Double(total))*100)) percent")
    }
}

struct SelectChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                Text(title).font(.body.weight(.medium))
                Spacer()
            }
            .padding()
            // FIX: use Color.accentColor instead of .accentColor (which isn't a ShapeStyle member)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.secondary, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
    }
}

struct Segmented<T: Hashable & CustomStringConvertible>: View {
    @Binding var selection: T
    let options: [T]
    var body: some View {
        Picker("Mode", selection: $selection) {
            ForEach(options, id: \.self) { Text($0.description).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityHint("Choose mode")
    }
}
