import SwiftUI

struct AutoPaySetupView: View {
    @EnvironmentObject var router: AppRouter
    
    @State private var selectedLoan = "Personal Loan • APP-9824-XT"
    @State private var selectedBank = "HDFC Bank •••• 4567"
    @State private var deductionDate = 5.0
    @State private var isConsentGiven = false
    @State private var showSuccessAlert = false
    
    let loans = ["Personal Loan • APP-9824-XT", "Auto Loan • APP-8821-AL"]
    let banks = ["HDFC Bank •••• 4567", "SBI Bank •••• 9012"]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Setup AutoPay")
                            .font(.largeTitle).bold()
                            .foregroundColor(.primary)
                        Text("Never miss an EMI. Automate your payments safely.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Form Card
                    VStack(alignment: .leading, spacing: 20) {
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Loan").font(.subheadline).foregroundColor(.secondary)
                            Picker("Loan", selection: $selectedLoan) {
                                ForEach(loans, id: \.self) { Text($0) }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.secondary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Bank Account").font(.subheadline).foregroundColor(.secondary)
                            Picker("Bank", selection: $selectedBank) {
                                ForEach(banks, id: \.self) { Text($0) }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.secondary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Monthly Deduction Date").font(.subheadline).foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(deductionDate))th of month").font(.headline).foregroundColor(.mainBlue)
                            }
                            Slider(value: $deductionDate, in: 1...28, step: 1)
                                .accentColor(.mainBlue)
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)
                    
                    // Info Banner
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "shield.fill")
                            .foregroundColor(Color(hex: "#00C48C"))
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bank Mandate Required")
                                .font(.subheadline).bold()
                            Text("You will be redirected to your bank's secure portal to authorize this mandate. No amount will be deducted today.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color(hex: "#00C48C").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    
                    // Custom Centered Consent UI
                    HStack(alignment: .center, spacing: 12) {
                        Button {
                            isConsentGiven.toggle()
                        } label: {
                            Image(systemName: isConsentGiven ? "checkmark.square.fill" : "square")
                                .font(.title2)
                                .foregroundColor(isConsentGiven ? .mainBlue : .secondary)
                        }
                        
                        Text("I authorize the platform to setup a standing instruction on my selected bank account for EMI deduction.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    
                    Spacer().frame(height: 100) // Sticky footer padding
                }
            }
            
            // Sticky Footer
            VStack {
                Divider()
                Button {
                    showSuccessAlert = true
                } label: {
                    Text("Authorize AutoPay")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isConsentGiven ? DS.primary : Color.secondary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isConsentGiven)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .alert("Not Available", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("AutoPay setup is not implemented in the backend yet. Please contact your branch to set up a standing instruction.")
        }
    }
}

struct AutoPaySetupView_Previews: PreviewProvider {
    static var previews: some View {
        AutoPaySetupView()
    }
}
