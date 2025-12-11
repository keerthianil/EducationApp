//
//  HamburgerMenuView.swift
//  Education
//
//  Hamburger side menu for Flow 3
//

import SwiftUI

struct HamburgerMenuView: View {
    @Binding var isShowing: Bool
    @EnvironmentObject var haptics: HapticService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var menuWidth: CGFloat {
        horizontalSizeClass == .regular ? 400 : 390
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
                .accessibilityHidden(true)
            
            // Menu panel (Figma: Width 390, slides from right)
            HStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    menuContent
                }
                .frame(width: menuWidth)
                .background(Color.white)
            }
        }
        .accessibilityAddTraits(.isModal)
    }
    
    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with close button (Figma: 32x32 circle with X)
            menuHeader
            
            ScrollView {
                VStack(spacing: 0) {
                    // Profile section (Figma: 72px height, #F9F9F9 bg)
                    profileSection
                    
                    // Primary menu items
                    primaryMenuItems
                    
                    Spacer().frame(height: 40)
                    
                    // Secondary menu items
                    secondaryMenuItems
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Header (Figma: "Menu" centered + X button)
    private var menuHeader: some View {
        HStack {
            Spacer()
            
            Text("Menu")
                .font(.custom("Arial", size: 18).weight(.bold))
                .foregroundColor(Color(hex: "#0D141C"))
            
            Spacer()
            
            Button {
                haptics.tapSelection()
                withAnimation(.easeInOut(duration: 0.3)) {
                    isShowing = false
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#E8EDF2"))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#0D141C"))
                }
            }
            .accessibilityLabel("Close menu")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Profile Section (Figma: 56x56 avatar, #F9F9F9 bg)
    private var profileSection: some View {
        Button {
            haptics.tapSelection()
            // Navigate to profile
        } label: {
            HStack(spacing: 16) {
                // Profile avatar (Figma: 56x56 circle)
                ZStack {
                    Circle()
                        .fill(Color(hex: "#F9F9F9"))
                        .frame(width: 56, height: 56)
                    
                    if UIImage(named: "profile-avatar") != nil {
                        Image("profile-avatar")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "#E8EDF2"))
                    }
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Profile")
                        .font(.custom("Arial", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "#0D141C"))
                    
                    Text("View and edit your profile")
                        .font(.custom("Arial", size: 14))
                        .foregroundColor(Color(hex: "#4D7399"))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(height: 72)
            .background(Color(hex: "#F9F9F9"))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile. View and edit your profile")
    }
    
    // MARK: - Primary Menu Items (Figma: 56px height each, #F9F9F9 bg)
    private var primaryMenuItems: some View {
        VStack(spacing: 0) {
            menuRow(icon: "accessibility", title: "Accessibility")
            menuRow(icon: "bell", title: "Notifications")
            menuRow(icon: "play.rectangle", title: "Tutorial")
            menuRow(icon: "gearshape", title: "Settings")
        }
    }
    
    // MARK: - Secondary Menu Items (Figma: white bg)
    private var secondaryMenuItems: some View {
        VStack(spacing: 0) {
            menuRow(icon: "questionmark.circle", title: "Help", bgColor: .white)
            menuRow(icon: "flag", title: "Feedback", bgColor: .white)
            menuRow(icon: "arrow.backward", title: "Logout", bgColor: .white)
        }
    }
    
    // MARK: - Menu Row (Figma: 40x40 icon container, #E8EDF2 icon bg)
    private func menuRow(icon: String, title: String, bgColor: Color = Color(hex: "#F9F9F9")) -> some View {
        Button {
            haptics.tapSelection()
            // Handle menu item tap
        } label: {
            HStack(spacing: 16) {
                // Icon container (Figma: 40x40, #E8EDF2, radius 8)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#E8EDF2"))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#0D141C"))
                }
                
                Text(title)
                    .font(.custom("Arial", size: 16))
                    .foregroundColor(Color(hex: "#0D141C"))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(bgColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

#Preview {
    HamburgerMenuView(isShowing: .constant(true))
        .environmentObject(HapticService())
}
