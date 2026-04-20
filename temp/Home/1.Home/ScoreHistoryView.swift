import SwiftUI
import Charts

struct ScoreData: Identifiable {
    let id = UUID()
    let month: String
    let score: Int
}

struct ScoreHistoryView: View {
    let history: [ScoreData] = [
        ScoreData(month: "Nov", score: 680),
        ScoreData(month: "Dec", score: 695),
        ScoreData(month: "Jan", score: 702),
        ScoreData(month: "Feb", score: 715),
        ScoreData(month: "Mar", score: 724)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Score History")
                        .font(.largeTitle).bold()
                    Text("Your progress over the last 5 months.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("+44 Points")
                            .font(.headline)
                            .foregroundColor(Color(hex: "#00C48C"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#00C48C").opacity(0.1))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    
                    Chart {
                        ForEach(history) { item in
                            LineMark(
                                x: .value("Month", item.month),
                                y: .value("Score", item.score)
                            )
                            .foregroundStyle(Color.secondaryBlue)
                            .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                            
                            PointMark(
                                x: .value("Month", item.month),
                                y: .value("Score", item.score)
                            )
                            .foregroundStyle(Color.mainBlue)
                            .annotation(position: .top) {
                                Text("\(item.score)")
                                    .font(.caption2).bold()
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 250)
                    .chartYScale(domain: 650...750)
                }
                .padding(24)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)
                
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
