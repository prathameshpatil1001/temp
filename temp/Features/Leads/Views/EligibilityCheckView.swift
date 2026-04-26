import SwiftUI

struct EligibilityCheckView: View {
    let vm: LeadDetailViewModel
    @Environment(\.dismiss) private var dismiss

    // Inputs
    @State private var monthlyIncome   = ""
    @State private var existingEMIs    = ""
    @State private var loanAmount      = ""
    @State private var propertyValue   = ""
    @State private var cibilScore: Double = 700

    // Result
    @State private var result: EligibilityResult? = nil
    @State private var showResult = false

    private var allFilled: Bool {
        !monthlyIncome.isEmpty && !existingEMIs.isEmpty && !loanAmount.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {

                    // ── Input fields ──
                    inputSection

                    // ── CIBIL Slider ──
                    cibilSlider

                    // ── Check button ──
                    Button { compute() } label: {
                        Text("Check Eligibility")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(allFilled ? Color.brandBlue : Color.brandBlue.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    }
                    .buttonStyle(.plain)
                    .disabled(!allFilled)

                    // ── Result ──
                    if showResult, let r = result {
                        resultSection(r)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(AppSpacing.md)
                .animation(.spring(response: 0.4), value: showResult)
            }
            .background(Color.surfaceSecondary.ignoresSafeArea())
            .navigationTitle("Eligibility Pre-Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(Color.surfaceTertiary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: AppSpacing.md) {
            numericField("Monthly Income",    text: $monthlyIncome,  prefix: "₹")
            numericField("Existing EMIs",     text: $existingEMIs,   prefix: "₹")
            numericField("Loan Amount",       text: $loanAmount,     prefix: "₹")
            numericField("Property/Vehicle Value", text: $propertyValue, prefix: "₹")
        }
    }

    private func numericField(_ label: String, text: Binding<String>, prefix: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.subheadMed())
                .foregroundColor(Color.textSecondary)

            HStack {
                if !prefix.isEmpty {
                    Text(prefix)
                        .font(AppFont.bodyMedium())
                        .foregroundColor(Color.textTertiary)
                }
                TextField("0", text: text)
                    .font(AppFont.body())
                    .foregroundColor(Color.textPrimary)
                    .keyboardType(.numberPad)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 14)
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .strokeBorder(Color.borderLight, lineWidth: 1)
            )
        }
    }

    // MARK: - CIBIL Slider
    private var cibilSlider: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("CIBIL Score: \(Int(cibilScore))")
                .font(AppFont.subheadMed())
                .foregroundColor(Color.textPrimary)

            ZStack(alignment: .leading) {
                // Track background
                Capsule().fill(Color(hex: "#1A1A2E")).frame(height: 12)

                // Fill
                GeometryReader { geo in
                    let pct = (cibilScore - 300) / (900 - 300)
                    Capsule()
                        .fill(cibilColor)
                        .frame(width: geo.size.width * pct, height: 12)
                }
                .frame(height: 12)
            }
            .frame(height: 12)
            .overlay(
                GeometryReader { geo in
                    let pct = (cibilScore - 300) / (900 - 300)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .position(x: geo.size.width * pct, y: 6)
                }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        let width = UIScreen.main.bounds.width - AppSpacing.md * 2
                        let pct = max(0, min(1, val.location.x / width))
                        cibilScore = 300 + pct * 600
                        showResult = false   // hide result on input change
                    }
            )

            HStack {
                Text("300").font(AppFont.caption()).foregroundColor(Color.textTertiary)
                Spacer()
                Text("900").font(AppFont.caption()).foregroundColor(Color.textTertiary)
            }
        }
    }

    private var cibilColor: Color {
        if cibilScore >= 750 { return Color.statusApproved }
        if cibilScore >= 650 { return Color.brandBlue }
        return Color.statusRejected
    }

    // MARK: - Result Section
    private func resultSection(_ r: EligibilityResult) -> some View {
        VStack(spacing: AppSpacing.md) {

            // Verdict card
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("ELIGIBILITY RESULT")
                    .font(AppFont.captionMed())
                    .foregroundColor(r.isEligible ? Color.statusApproved : Color.statusRejected)
                    .tracking(0.6)

                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(r.isEligible ? Color.statusApproved : Color.statusRejected)
                        .frame(width: 18, height: 18)
                    Text(r.isEligible ? "Eligible" : "Not Eligible")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(r.isEligible ? Color.statusApproved : Color.statusRejected)
                }

                Text(r.isEligible ? "Likely to be approved" : "Likely to be rejected")
                    .font(AppFont.subhead())
                    .foregroundColor(r.isEligible ? Color.statusApproved : Color.statusRejected)

                if !r.keyFactors.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 5) {
                        Text("KEY FACTORS:")
                            .font(AppFont.captionMed())
                            .foregroundColor(r.isEligible ? Color.statusApproved : Color.statusRejected)
                            .tracking(0.5)
                        ForEach(r.keyFactors, id: \.self) { f in
                            HStack(alignment: .top, spacing: 5) {
                                Text("•")
                                Text(f)
                            }
                            .font(AppFont.subhead())
                            .foregroundColor(r.isEligible ? Color.statusApproved : Color.statusRejected)
                        }
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(
                (r.isEligible ? Color.statusApprovedBg : Color.statusRejectedBg)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .strokeBorder(
                        (r.isEligible ? Color.statusApproved.opacity(0.3) : Color.statusRejected.opacity(0.3)),
                        lineWidth: 1
                    )
            )

            // Metrics grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                metricCell(
                    label: "FOIR",
                    value: String(format: "%.1f%%", r.foir * 100),
                    sub: "Limit: \(Int(r.foirLimit * 100))%",
                    color: r.foir > r.foirLimit ? Color.statusRejected : Color.textPrimary
                )
                metricCell(
                    label: "LTV",
                    value: r.ltv > 0 ? String(format: "%.1f%%", r.ltv * 100) : "N/A",
                    sub: "Ideal: <90%",
                    color: r.ltv > 0.90 ? Color.statusRejected : Color.textPrimary
                )
                metricCell(
                    label: "Proposed EMI",
                    value: formatRupee(r.proposedEMI),
                    sub: "Per month",
                    color: Color.textPrimary
                )
                metricCell(
                    label: "Total EMI",
                    value: formatRupee(r.totalEMI),
                    sub: "Per month",
                    color: Color.textPrimary
                )
            }
        }
    }

    private func metricCell(label: String, value: String, sub: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppFont.captionMed())
                .foregroundColor(Color.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
            Text(sub)
                .font(AppFont.caption())
                .foregroundColor(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .strokeBorder(Color.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Compute
    private func compute() {
        guard
            let income  = Double(monthlyIncome),
            let emi     = Double(existingEMIs),
            let loan    = Double(loanAmount)
        else { return }
        let prop = Double(propertyValue) ?? 0
        result = vm.calculateEligibility(
            monthlyIncome: income,
            existingEMIs: emi,
            loanAmount: loan,
            propertyValue: prop,
            cibilScore: Int(cibilScore)
        )
        withAnimation { showResult = true }
    }

    private func formatRupee(_ v: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 0
        return "₹\(fmt.string(from: NSNumber(value: v)) ?? "\(Int(v))")"
    }
}
