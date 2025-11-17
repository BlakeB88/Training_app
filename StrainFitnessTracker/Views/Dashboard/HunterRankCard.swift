//
//  HunterRankCard.swift
//  StrainFitnessTracker
//
//  Tappable rank card for dashboard navigation to Hunter Stats
//

import SwiftUI

struct HunterRankCard: View {
    let snapshot: HunterStatsSnapshot?
    
    var body: some View {
        NavigationLink(destination: HunterStatsView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RANK")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondaryText)
                            .tracking(1)
                        
                        if let snapshot = snapshot {
                            HStack(alignment: .bottom, spacing: 8) {
                                Text(snapshot.hunterRank.displayName)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(snapshot.hunterRank.color)
                                
                                if snapshot.awakenStateActive {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 10))
                                        Text("Awakened")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.15))
                                    .cornerRadius(12)
                                }
                            }
                        } else {
                            Text("--")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondaryText)
                }
                
                if let snapshot = snapshot {
                    // XP Progress Bar
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Level \(snapshot.xpState.level)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primaryText)
                            
                            Spacer()
                            
                            Text("+\(snapshot.xpState.earnedToday) XP today")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.accentBlue)
                        }
                        
                        ProgressView(value: snapshot.xpState.progress)
                            .tint(.accentBlue)
                            .frame(height: 6)
                        
                        HStack {
                            Text("\(snapshot.xpState.currentXP) / \(snapshot.xpState.xpToNextLevel) XP")
                                .font(.system(size: 11))
                                .foregroundColor(.secondaryText)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.warningOrange)
                                Text("\(snapshot.consistencyStreak)d streak")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondaryText)
                            }
                        }
                    }
                    
                    Divider()
                        .background(Color.secondaryText.opacity(0.2))
                    
                    // Quick Stats Row
                    HStack(spacing: 0) {
                        quickStat(title: "Daily Score", value: String(format: "%.0f", snapshot.dailyScore))
                        
                        Spacer()
                        
                        quickStat(title: "Overall PI", value: String(format: "%.0f", snapshot.overallPerformanceIndex))
                        
                        Spacer()
                        
                        quickStat(title: "Swim Rank", value: snapshot.swimMasteryRank.displayName)
                    }
                }
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func quickStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primaryText)
        }
    }
}

struct HunterRankCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            HunterRankCard(snapshot: nil)
                .padding()
        }
        .background(Color.appBackground)
    }
}
