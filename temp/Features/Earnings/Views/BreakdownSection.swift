//
//  BreakdownSection.swift
//  DirectSalesTeamApp
//
//  Created by Apple on 17/04/26.
//


import SwiftUI

struct BreakdownSection: View {
    let breakdown: [CommissionComponent]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Commission Breakdown")
                .font(.headline)
            
            ForEach(breakdown, id: \.title) { item in
                HStack {
                    Text(item.title)
                    Spacer()
                    Text("₹\(Int(item.amount))")
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
