//
//  CommissionAnalyticsCard.swift
//  DirectSalesTeamApp
//
//  Created by Apple on 17/04/26.
//
import SwiftUI

struct CommissionAnalyticsCard: View {
    let breakdown: [CommissionComponent]
    
    var total: Double {
        breakdown.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        HStack(spacing: 20) {
            
            // DONUT
            ZStack {
                ForEach(Array(breakdown.enumerated()), id: \.offset) { index, item in
                    Circle()
                        .trim(from: startAngle(for: index),
                              to: endAngle(for: index))
                        .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .foregroundColor(color(for: index))
                        .rotationEffect(.degrees(-90))
                }
                
                Text("₹\(Int(total))")
                    .font(AppFont.subheadMed())
            }
            .frame(width: 90, height: 90)
            
            // BREAKDOWN TEXT
            VStack(alignment: .leading, spacing: 8) {
                Text("Breakdown")
                    .font(AppFont.headline())
                
                ForEach(Array(breakdown.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Circle()
                            .fill(color(for: index))
                            .frame(width: 8, height: 8)
                        
                        Text(item.title)
                            .font(AppFont.subhead())
                        
                        Spacer()
                        
                        Text("₹\(Int(item.amount))")
                            .font(AppFont.subheadMed())
                    }
                }
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(AppRadius.lg)
        .cardShadow()
    }
    
    // MARK: - Helpers
    
    func startAngle(for index: Int) -> CGFloat {
        let prev = breakdown.prefix(index).reduce(0) { $0 + $1.amount }
        return prev / total
    }
    
    func endAngle(for index: Int) -> CGFloat {
        let curr = breakdown.prefix(index + 1).reduce(0) { $0 + $1.amount }
        return curr / total
    }
    
    func color(for index: Int) -> Color {
        let colors: [Color] = [.brandBlue, .statusApproved, .statusPending]
        return colors[index % colors.count]
    }
}
