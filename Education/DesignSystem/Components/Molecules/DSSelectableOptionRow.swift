import SwiftUI

/// Generic selectable row used for choices in onboarding/questions.
/// The left square behaves like a checkbox.
struct DSSelectableOptionRow: View {
    let title: String
    let isSelected: Bool
    
    var activeColor: Color = ColorTokens.primary
    var inactiveBorder: Color = Color.gray.opacity(0.4)
    var cornerRadius: CGFloat = 10
    var leadingSize: CGFloat = 26
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox square (visual only)
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    isSelected ? activeColor : inactiveBorder,
                    lineWidth: 1
                )
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected
                              ? activeColor
                              : Color.gray.opacity(0.25))
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(isSelected ? 1 : 0)
                )
                .frame(width: leadingSize, height: leadingSize)
                .accessibilityHidden(true)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? activeColor : .black)
                .lineLimit(1)
                .accessibilityHidden(true)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(isSelected ? activeColor.opacity(0.08) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    isSelected ? activeColor : inactiveBorder,
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        // Accessibility as a single control
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Double tap to select this option")
    }
}

#Preview {
    VStack(spacing: 16) {
        DSSelectableOptionRow(title: "( 12–18 Yrs ) High School", isSelected: true)
        DSSelectableOptionRow(title: "( 18–45 Yrs ) Adult", isSelected: false)
    }
    .padding()
}
