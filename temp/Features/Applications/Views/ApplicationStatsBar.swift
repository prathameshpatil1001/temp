import SwiftUI

struct ApplicationStatsBar: View {
    let stats: ApplicationStats
    var onTap: ((ApplicationStatus?) -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            ApplicationStatCell(
                value: stats.total,
                label: "Total",
                valueColor: Color.textPrimary
            ) { onTap?(nil) }

            divider

            ApplicationStatCell(
                value: stats.underReview,
                label: "Under Review",
                valueColor: Color(hex: "#D97706")
            ) { onTap?(.underReview) }

            divider

            ApplicationStatCell(
                value: stats.approved,
                label: "Approved",
                valueColor: Color(hex: "#057A55")
            ) { onTap?(.approved) }

            divider

            ApplicationStatCell(
                value: stats.disbursed,
                label: "Disbursed",
                valueColor: Color(hex: "#2563EB")
            ) { onTap?(.disbursed) }
        }
        .frame(maxWidth: .infinity)
        .background(Color.surfacePrimary)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.borderLight)
            .frame(width: 1, height: 40)
    }
}

// MARK: - Individual stat cell
private struct ApplicationStatCell: View {
    let value: Int
    let label: String
    let valueColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(value)")
                    .font(.system(size: 26, weight: .bold, design: .default))
                    .foregroundColor(valueColor)
                    .contentTransition(.numericText())

                Text(label)
                    .font(AppFont.caption())
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ApplicationStatsBar(stats: ApplicationStats(total: 4, underReview: 1, approved: 1, disbursed: 1))
        .padding()
}
