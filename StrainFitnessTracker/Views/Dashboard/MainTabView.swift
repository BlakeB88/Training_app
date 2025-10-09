//
//  MainTabView.swift
//  StrainFitnessTracker
//
//  Main tab bar navigation matching Whoop design
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    
    enum Tab {
        case home
        case health
        case community
        case more
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .home:
                    DashboardView()
                case .health:
                    HealthView()
                case .community:
                    CommunityView()
                case .more:
                    MoreView()
                }
            }
            
            // Custom Tab Bar
            HStack(spacing: 0) {
                TabBarButton(
                    icon: "house.fill",
                    label: "Home",
                    isSelected: selectedTab == .home
                ) {
                    selectedTab = .home
                }
                
                TabBarButton(
                    icon: "heart.text.square.fill",
                    label: "Health",
                    isSelected: selectedTab == .health
                ) {
                    selectedTab = .health
                }
                
                TabBarButton(
                    icon: "person.3.fill",
                    label: "Community",
                    isSelected: selectedTab == .community
                ) {
                    selectedTab = .community
                }
                
                TabBarButton(
                    icon: "line.3.horizontal",
                    label: "More",
                    isSelected: selectedTab == .more
                ) {
                    selectedTab = .more
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .background(
                Color.cardBackground
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .accentBlue : .secondaryText)
                
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .accentBlue : .secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Placeholder Views
struct HealthView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Health Monitor")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primaryText)
                
                Text("Detailed health metrics and trends")
                    .font(.system(size: 16))
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

struct CommunityView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Community")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primaryText)
                
                Text("Connect with other users and teams")
                    .font(.system(size: 16))
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

struct MoreView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                List {
                    Section {
                        NavigationLink(destination: Text("Profile")) {
                            Label("Profile", systemImage: "person.fill")
                        }
                        
                        NavigationLink(destination: Text("Settings")) {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        
                        NavigationLink(destination: Text("Notifications")) {
                            Label("Notifications", systemImage: "bell.fill")
                        }
                    }
                    
                    Section {
                        NavigationLink(destination: Text("Help & Support")) {
                            Label("Help & Support", systemImage: "questionmark.circle.fill")
                        }
                        
                        NavigationLink(destination: Text("About")) {
                            Label("About", systemImage: "info.circle.fill")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
