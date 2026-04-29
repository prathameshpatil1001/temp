import Foundation

struct BorrowerSanctionLetterContent {
    let applicationNumber: String
    let sanctionDate: String
    let applicantName: String
    let mobileNumber: String
    let loanType: String
    let sanctionedAmount: String
    let referenceInterestRate: String
    let floatingInterestRate: String
    let loanTenor: String
    let processingCharges: String
    let originationFee: String
    let validity: String
    let emiAmount: String
    let propertyAddress: String
    let conditions: [String]
}

enum BorrowerSanctionLetterSupport {
    static func statusTitle(for application: BorrowerLoanApplication) -> String {
        if application.status == .managerApproved {
            return "Sanction Pending"
        }
        return application.status.displayName
    }

    static func makeLetter(
        for application: BorrowerLoanApplication,
        borrowerName: String,
        mobileNumber: String
    ) -> BorrowerSanctionLetterContent {
        let rate = normalizedInterestRate(from: application.offeredInterestRate)
        let emi = calculateEMI(
            principal: Double(application.requestedAmount) ?? 0,
            annualRate: Double(rate) ?? 9.5,
            tenureMonths: application.tenureMonths
        )

        return BorrowerSanctionLetterContent(
            applicationNumber: application.referenceNumber,
            sanctionDate: displayDate(from: application.updatedAt),
            applicantName: borrowerName.isEmpty ? "Borrower" : borrowerName,
            mobileNumber: mobileNumber.isEmpty ? "9876543210" : mobileNumber,
            loanType: application.loanProductName,
            sanctionedAmount: formatCurrency(application.requestedAmount),
            referenceInterestRate: "\(rate)% per annum (Interest Type: Floating | Periodicity: Monthly)",
            floatingInterestRate: "Reference rate applicable at disbursement time - \(rate)% per annum",
            loanTenor: "\(max(application.tenureMonths / 12, 1)) year\(application.tenureMonths >= 24 ? "s" : "")",
            processingCharges: "Up to 0.5% of the total loan amount",
            originationFee: "2,500",
            validity: "180 days from the date of sanction",
            emiAmount: formatCurrency(emi),
            propertyAddress: application.branchName.isEmpty ? "Address to be confirmed before disbursal" : "Property verification aligned with \(application.branchName) branch records",
            conditions: [
                "Repayment account setup with the bank before release of funds.",
                "Legal vetting and search report to be completed.",
                "Collateral and supporting NOC documents to be validated.",
                "Final identity confirmation and signed acceptance to be recorded."
            ]
        )
    }

    private static func normalizedInterestRate(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "9.50" : trimmed
    }

    private static func calculateEMI(principal: Double, annualRate: Double, tenureMonths: Int) -> Double {
        guard principal > 0, annualRate > 0, tenureMonths > 0 else { return principal }
        let monthlyRate = annualRate / 1200
        let factor = pow(1 + monthlyRate, Double(tenureMonths))
        return principal * monthlyRate * factor / (factor - 1)
    }

    private static func displayDate(from raw: String) -> String {
        let parsed = ISO8601DateFormatter().date(from: raw) ?? Date()
        return parsed.formatted(date: .numeric, time: .omitted)
    }

    private static func formatCurrency(_ raw: String) -> String {
        guard let amount = Double(raw) else { return raw }
        return formatCurrency(amount)
    }

    private static func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹\(Int(amount))"
    }
}
