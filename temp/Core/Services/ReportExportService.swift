//
//  ReportExportService.swift
//  lms_project
//
//  Generates PDF and CSV exports from real backend loan application data.
//

import UIKit
import UniformTypeIdentifiers

// MARK: - Report Data Models (used by both ViewModel and Service)

struct AppReportRow {
    let applicationId: String
    let borrowerName: String
    let loanType: String
    let amount: Double
    let status: String
    let risk: String
    let date: Date
}

struct AppReportSummary {
    let total: Int
    let approved: Int
    let pending: Int
    let rejected: Int
    let totalValue: Double
    let avgLoanSize: Double
    let npaRate: Double
}

// MARK: - Export Service

final class ReportExportService {

    // MARK: - PDF Generation

    static func generatePDF(
        rows: [AppReportRow],
        summary: AppReportSummary,
        reportName: String,
        filters: String,
        completion: @escaping (URL?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            print("[ReportExport] PDF generation started")

            let safeName = reportName.replacingOccurrences(of: " ", with: "_")
            let fileName = "\(safeName)_\(Int(Date().timeIntervalSince1970)).pdf"
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let outputURL = documentsDir.appendingPathComponent(fileName)

            print("[ReportExport] Writing PDF to: \(outputURL.path)")

            let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
            let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

            do {
                try renderer.writePDF(to: outputURL) { ctx in

                    // ── Constants ────────────────────────────────────────
                    let leftMargin: CGFloat   = 40
                    let pageWidth: CGFloat    = 595
                    let contentWidth: CGFloat = pageWidth - 80   // 515
                    let bottomMargin: CGFloat = 60
                    var yPos: CGFloat         = 40
                    var pageNumber            = 1

                    // ── Formatters ───────────────────────────────────────
                    let currencyFmt = NumberFormatter()
                    currencyFmt.numberStyle          = .currency
                    currencyFmt.currencySymbol        = "₹"
                    currencyFmt.maximumFractionDigits = 0
                    currencyFmt.locale                = Locale(identifier: "en_IN")
                    func fmt(_ v: Double) -> String {
                        currencyFmt.string(from: NSNumber(value: v)) ?? "₹\(Int(v))"
                    }

                    let headerDF = DateFormatter()
                    headerDF.dateFormat = "dd MMM yyyy, hh:mm a"
                    let rowDF = DateFormatter()
                    rowDF.dateFormat = "dd MMM yyyy"

                    // ── Text attribute sets ──────────────────────────────
                    let titleAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                        .foregroundColor: UIColor.black
                    ]
                    let subtitleAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11),
                        .foregroundColor: UIColor(white: 0.53, alpha: 1)
                    ]
                    let sectionAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                        .foregroundColor: UIColor.black
                    ]
                    let summaryValueAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                        .foregroundColor: UIColor.black
                    ]
                    let summaryLabelAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: UIColor(white: 0.53, alpha: 1)
                    ]
                    let colHeaderAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                        .foregroundColor: UIColor.black
                    ]
                    let rowAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: UIColor.black
                    ]
                    let footerAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: UIColor(white: 0.55, alpha: 1)
                    ]

                    // ── Colors ───────────────────────────────────────────
                    let grey220 = UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1)
                    let grey238 = UIColor(red: 238/255, green: 238/255, blue: 238/255, alpha: 1)

                    // ── Helper: horizontal rule ──────────────────────────
                    func hLine(y: CGFloat, color: UIColor = grey220, width: CGFloat = 0.5) {
                        let p = UIBezierPath()
                        p.move(to: CGPoint(x: leftMargin, y: y))
                        p.addLine(to: CGPoint(x: pageWidth - leftMargin, y: y))
                        p.lineWidth = width
                        color.setStroke()
                        p.stroke()
                    }

                    // ── Helper: footer ───────────────────────────────────
                    func drawFooter() {
                        let text = "Generated by LMS System  |  Page \(pageNumber)" as NSString
                        let sz   = text.size(withAttributes: footerAttrs)
                        text.draw(
                            at: CGPoint(x: (pageWidth - sz.width) / 2, y: 822),
                            withAttributes: footerAttrs
                        )
                        hLine(y: 812, color: UIColor(white: 0.75, alpha: 1))
                    }

                    // ── Table layout ─────────────────────────────────────
                    let colWidths: [CGFloat] = [70, 90, 75, 70, 60, 55, 95]
                    let colHeaders           = ["App ID", "Borrower", "Loan Type", "Amount", "Status", "Risk", "Date"]
                    let tableHeaderH: CGFloat = 24
                    let rowH: CGFloat          = 20

                    // ── Helper: table header row ─────────────────────────
                    func drawTableHeader(atY y: CGFloat) {
                        let rect = CGRect(x: leftMargin, y: y, width: contentWidth, height: tableHeaderH)
                        grey238.setFill()
                        UIBezierPath(rect: rect).fill()

                        var x = leftMargin
                        for (i, col) in colHeaders.enumerated() {
                            (col as NSString).draw(
                                at: CGPoint(x: x + 4, y: y + (tableHeaderH - 12) / 2),
                                withAttributes: colHeaderAttrs
                            )
                            x += colWidths[i]
                        }
                        hLine(y: y + tableHeaderH)
                    }
                    

                    // ── PAGE 1 ───────────────────────────────────────────
                    ctx.beginPage()

                    // ── HEADER ───────────────────────────────────────────
                    ("\(reportName) Report" as NSString)
                        .draw(at: CGPoint(x: leftMargin, y: yPos), withAttributes: titleAttrs)
                    yPos += 30
                    hLine(y: yPos, color: UIColor(white: 0.8, alpha: 1), width: 0.5)
                    yPos += 8

                    let filtersDisplay = filters.isEmpty
                        ? "All Loans | All Branches | Last 30 Days"
                        : filters
                    ("Generated on: \(headerDF.string(from: Date()))" as NSString)
                        .draw(at: CGPoint(x: leftMargin, y: yPos), withAttributes: subtitleAttrs)
                    yPos += 16
                    ("Filters: \(filtersDisplay)" as NSString)
                        .draw(at: CGPoint(x: leftMargin, y: yPos), withAttributes: subtitleAttrs)
                    yPos += 28

                    // ── SUMMARY ──────────────────────────────────────────
                    ("Summary" as NSString)
                        .draw(at: CGPoint(x: leftMargin, y: yPos), withAttributes: sectionAttrs)
                    yPos += 14

                    let cellW  = contentWidth / 3
                    let cellH: CGFloat = 44
                    let summaryItems: [(String, String)] = [
                        ("Total Applications", "\(summary.total)"),
                        ("Approved",           "\(summary.approved)"),
                        ("Pending",            "\(summary.pending)"),
                        ("Rejected",           "\(summary.rejected)"),
                        ("Total Disbursed",    fmt(summary.totalValue)),
                        ("Avg Loan Size",      fmt(summary.avgLoanSize))
                    ]
                    for (i, item) in summaryItems.enumerated() {
                        let col   = CGFloat(i % 3)
                        let row   = CGFloat(i / 3)
                        let cellX = leftMargin + col * cellW
                        let cellY = yPos + row * cellH
                        let rect  = CGRect(x: cellX, y: cellY, width: cellW, height: cellH)

                        UIColor(red: 200/255, green: 200/255, blue: 200/255, alpha: 1).setStroke()
                        let bp = UIBezierPath(rect: rect)
                        bp.lineWidth = 0.5
                        bp.stroke()

                        let vStr  = item.1 as NSString
                        let lStr  = item.0 as NSString
                        let vSize = vStr.size(withAttributes: summaryValueAttrs)
                        let lSize = lStr.size(withAttributes: summaryLabelAttrs)
                        vStr.draw(
                            at: CGPoint(x: cellX + (cellW - vSize.width) / 2, y: cellY + 8),
                            withAttributes: summaryValueAttrs
                        )
                        lStr.draw(
                            at: CGPoint(x: cellX + (cellW - lSize.width) / 2, y: cellY + 28),
                            withAttributes: summaryLabelAttrs
                        )
                    }
                    yPos += 2 * cellH + 20

                    // ── TABLE ────────────────────────────────────────────
                    ("Applications" as NSString)
                        .draw(at: CGPoint(x: leftMargin, y: yPos), withAttributes: sectionAttrs)
                    yPos += 14

                    drawTableHeader(atY: yPos)
                    yPos += tableHeaderH

                    for row in rows {
                        if yPos + rowH > 842 - bottomMargin {
                            drawFooter()
                            ctx.beginPage()
                            pageNumber += 1
                            yPos = 40
                            drawTableHeader(atY: yPos)
                            yPos += tableHeaderH
                        }

                        let cells = [
                            row.applicationId,
                            row.borrowerName,
                            row.loanType,
                            fmt(row.amount),
                            row.status,
                            row.risk,
                            rowDF.string(from: row.date)
                        ]

                        var x = leftMargin
                        for (i, val) in cells.enumerated() {
                            let maxW    = colWidths[i] - 8
                            let display = truncate(val, maxWidth: maxW, attrs: rowAttrs)
                            (display as NSString).draw(
                                at: CGPoint(x: x + 4, y: yPos + (rowH - 10) / 2),
                                withAttributes: rowAttrs
                            )
                            x += colWidths[i]
                        }

                        hLine(y: yPos + rowH)
                        yPos += rowH
                    }

                    // vertical column separators
                    var x = leftMargin
                    for w in colWidths.dropLast() {
                        x += w
                        let p = UIBezierPath()
                        p.move(to: CGPoint(x: x, y: 40))
                        p.addLine(to: CGPoint(x: x, y: yPos))
                        p.lineWidth = 0.5
                        grey220.setStroke()
                        p.stroke()
                    }

                    drawFooter()
                }

                print("[ReportExport] PDF successfully created at: \(outputURL.path)")
                DispatchQueue.main.async { completion(outputURL) }

            } catch {
                print("[ReportExport] PDF FAILED with error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    // MARK: - CSV Generation

    static func generateCSV(
        rows: [AppReportRow],
        completion: @escaping (URL) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            print("[ReportExport] CSV generation started")

            var lines = ["ApplicationID,Borrower,LoanType,Amount,Status,Risk,Date"]
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            for row in rows {
                let amountStr = String(format: "%.2f", row.amount)
                let csvRow = [
                    csvEscape(row.applicationId),
                    csvEscape(row.borrowerName),
                    csvEscape(row.loanType),
                    amountStr,
                    csvEscape(row.status),
                    csvEscape(row.risk),
                    df.string(from: row.date)
                ].joined(separator: ",")
                lines.append(csvRow)
            }
            let content = lines.joined(separator: "\n")
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsURL.appendingPathComponent("loan_report_\(Int(Date().timeIntervalSince1970)).csv")
            try? content.write(to: url, atomically: true, encoding: .utf8)
            print("[ReportExport] CSV successfully created at: \(url.path)")

            DispatchQueue.main.async {
                completion(url)
            }
        }
    }

    // MARK: - Audit Log CSV Generation

    static func generateAuditCSV(logs: [AuditLog]) -> URL {
        var lines = ["Timestamp,Action,Description,Actor,Entity"]
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        for log in logs {
            let csvRow = [
                df.string(from: log.timestamp),
                csvEscape(log.action),
                csvEscape(log.detail),
                csvEscape(log.user),
                csvEscape(log.id)
            ].joined(separator: ",")
            lines.append(csvRow)
        }
        let content = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit_log_\(timestamp()).csv")
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Private Helpers

    private static func timestamp() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        return df.string(from: Date())
    }

    private static func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }

    private static func formatCurrency(_ value: Double) -> String {
        if value == 0 { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func truncate(_ text: String, maxWidth: CGFloat, attrs: [NSAttributedString.Key: Any]) -> String {
        var result = text
        while (result as NSString).size(withAttributes: attrs).width > maxWidth && result.count > 2 {
            result = String(result.dropLast()) + "…"
        }
        return result
    }
}
