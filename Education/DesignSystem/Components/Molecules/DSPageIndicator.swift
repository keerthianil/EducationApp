import SwiftUI

/// Simple page indicator dots for onboarding / carousels.
struct DSPageIndicator: View {
    let totalPages: Int
    let currentPage: Int   // 0-based index
    
    var activeColor: Color = .black
    var inactiveColor: Color = Color.gray.opacity(0.4)
    var dotSize: CGFloat = 8
    var spacing: CGFloat = 8
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? activeColor : inactiveColor)
                    .frame(width: dotSize, height: dotSize)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        DSPageIndicator(totalPages: 3, currentPage: 0)
        DSPageIndicator(totalPages: 3, currentPage: 1)
        DSPageIndicator(totalPages: 3, currentPage: 2)
    }
    .padding()
}
