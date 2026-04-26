//
//  CommissionCard.swift
//  DirectSalesTeamApp
//
//  Created by Apple on 17/04/26.
//
import SwiftUI

struct CommissionCard: View {
    let earning: EarningDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Total Commission")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Text("₹\(Int(earning.commission))")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)
            
            HStack {
                Text("\(earning.commissionRate, specifier: "%.1f")%")
                Spacer()
                Text(earning.statusText)
            }
            .foregroundColor(.white)
            .font(.caption)
        }
        .padding()
        .background(Color.blue)
        .cornerRadius(16)
    }
}

extension EarningDetail {
    var statusText: String {
        switch status {
        case .paid: return "Paid"
        case .pending: return "Pending"
        case .processing: return "Processing"
        }
    }
}
