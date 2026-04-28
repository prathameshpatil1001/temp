//
//  FilterRangeSheet.swift
//  lms_project
//
//  Created by Apple on 28/04/26.
//

import SwiftUI

struct FilterRangeSheet: View {
    @ObservedObject var applicationsVM: ApplicationsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount Range (₹)") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Min: \(Int(applicationsVM.minAmount).currencyFormatted)")
                            Spacer()
                            Text("Max: \(Int(applicationsVM.maxAmount).currencyFormatted)")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading) {
                            Text("Minimum Amount").font(.caption2).foregroundStyle(.tertiary)
                            Slider(value: $applicationsVM.minAmount, in: 0...5_000_000, step: 50_000)
                        }

                        VStack(alignment: .leading) {
                            Text("Maximum Amount").font(.caption2).foregroundStyle(.tertiary)
                            Slider(value: $applicationsVM.maxAmount, in: 50_000...10_000_000, step: 100_000)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Date range") {
                    DatePicker("Show from", selection: $applicationsVM.startDate, displayedComponents: .date)
                }
                
                Section {
                    Button("Reset Filters", role: .destructive) {
                        applicationsVM.resetFiltersToAll()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Advanced Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
