//
//  AdminReportsView.swift
//  lms_project
//
//  TAB 4 — Reports with categories, filters, export, custom builder
//

import SwiftUI

struct AdminReportsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var reportsVM: AdminReportsViewModel
    @Binding var showProfile: Bool

    @State private var selectedCategory = 0
    @State private var showExportSheet: ReportItem? = nil
    @State private var previewingReport: ReportItem? = nil
    @State private var shareItem: ShareItem? = nil
    @State private var showingBanner = false
    @State private var bannerMessage = ""
    @State private var dateRange = "Last 30 Days"
    @State private var loanTypeFilter = "All Types"
    @State private var regionFilter = "All Regions"
    @State private var statusFilter = "All"
    @State private var showCustomBuilder = false

    private let categories = ["Portfolio","Disbursement","Collection","NPA","Risk & Credit"]
    private let dateRanges = ["Last 7 Days","Last 30 Days","Last 90 Days","This FY"]
    private let loanTypes = ["All Types","Home Loan","Personal Loan","Business Loan","Vehicle Loan"]
    private let regions = ["All Regions","Mumbai","Delhi NCR","Bangalore","Chennai"]
    private let statuses = ["All","Active","Closed","NPA"]

    private let reports: [ReportItem] = [
        ReportItem(id:"RPT-PERF",title:"Portfolio Performance",description:"Total portfolio, disbursements, NPA summary",icon:"chart.bar.fill",color:Theme.Colors.primary,lastGenerated:"Apr 15, 2025",size:"2.4 MB"),
        ReportItem(id:"RPT-DISB",title:"Disbursement Report",description:"Loans disbursed by branch, type, and officer",icon:"arrow.up.right.circle.fill",color:Theme.Colors.success,lastGenerated:"Apr 14, 2025",size:"1.8 MB"),
        ReportItem(id:"RPT-COLL",title:"Collection Report",description:"EMI recovery, DPD buckets, outstanding analysis",icon:"indianrupeesign.circle.fill",color:Theme.Colors.primary,lastGenerated:"Apr 13, 2025",size:"3.1 MB"),
        ReportItem(id:"RPT-NPA",title:"NPA Report",description:"Non-performing assets, aging, provisioning",icon:"exclamationmark.triangle.fill",color:Theme.Colors.critical,lastGenerated:"Apr 12, 2025",size:"1.2 MB"),
        ReportItem(id:"RPT-RISK",title:"Risk & Credit Report",description:"CIBIL distribution, FOIR analysis, fraud flags",icon:"shield.lefthalf.filled",color:Theme.Colors.warning,lastGenerated:"Apr 10, 2025",size:"2.8 MB"),
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment:.top) {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 0. Filter Strip
                        filterStrip
                        
                        // 1. Custom Report Builder Module
                        Button {
                            showCustomBuilder = true
                        } label: {
                            customReportBuilderCard
                        }
                        .buttonStyle(.plain)
                        
                        // 2. All Reports List
                        allReportsSection
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                
                if showingBanner { exportBanner.padding(.top,8).transition(.move(edge:.top).combined(with:.opacity)) }
            }
            .animation(.spring(response:0.35,dampingFraction:0.8),value:showingBanner)
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { 
                ToolbarItem(placement: .topBarTrailing) { ProfileNavButton(showProfile: $showProfile) }
            }
            .onAppear {
                reportsVM.loadData()
            }
            .sheet(item:$showExportSheet) { report in
                ExportOptionsSheet(report:report,onExport:{format in triggerExport(report:report,format:format)})
            }
            .sheet(item:$previewingReport) { report in
                ReportPreviewSheet(report:report,onExport:{format in triggerExport(report:report,format:format)})
                    .environmentObject(reportsVM)
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(activityItems: [item.url])
            }
            .sheet(isPresented: $showCustomBuilder) {
                AdminCustomReportBuilderSheet()
            }
        }
    }

    // MARK: - Native Filters Strip
    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                filterChip(selection: $dateRange, options: dateRanges, icon: "calendar")
                filterChip(selection: $loanTypeFilter, options: loanTypes, icon: "briefcase")
                filterChip(selection: $regionFilter, options: regions, icon: "mappin.and.ellipse")
                filterChip(selection: $statusFilter, options: statuses, icon: "flag")
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }
    
    private func filterChip(selection: Binding<String>, options: [String], icon: String) -> some View {
        Menu {
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                Text(selection.wrappedValue).font(Theme.Typography.caption.weight(.medium)).foregroundStyle(.primary)
                Image(systemName: "chevron.down").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.gray.opacity(0.15), lineWidth: 1))
        }
    }

    // MARK: - Custom Report Builder
    private var customReportBuilderCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Report Builder")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.white)
                    Text("Combine metrics across Portfolio, Risk, and Collections into a single dynamic export.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }
                Spacer()
                ZStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 48, height: 48)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.adaptivePrimary(colorScheme))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Theme.Colors.adaptivePrimary(colorScheme).opacity(0.08), radius: 4, x: 0, y: 2)
    }

    // MARK: - All Reports List
    private var allReportsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "All Reports", icon: "folder.fill")
            
            VStack(spacing: 0) {
                ForEach(reports) { report in
                    AdminReportItemRow(
                        report: report, 
                        onPreview: { previewingReport = report },
                        onExport: { showExportSheet = report }
                    )
                    if report.id != reports.last?.id {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        }
    }




    // MARK: - Export
    private var exportBanner: some View {
        HStack(spacing:Theme.Spacing.sm) {
            ProgressView().progressViewStyle(.circular).scaleEffect(0.8).tint(.white)
            Text(bannerMessage).font(Theme.Typography.subheadline).fontWeight(.medium).foregroundStyle(.white)
        }.frame(maxWidth:.infinity).padding(.vertical,12).background(Theme.Colors.adaptivePrimary(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius:Theme.Radius.md)).padding(.horizontal,Theme.Spacing.lg)
    }

    private func triggerExport(report:ReportItem,format:ExportFormat) {
        bannerMessage = "Generating \(report.title) as \(format.displayName)…"
        withAnimation{showingBanner=true}
        
        DispatchQueue.main.asyncAfter(deadline:.now()+1.5) {
            withAnimation{showingBanner=false}
            
            let fileName = "\(report.title.replacingOccurrences(of: " ", with: "_")).\(format.rawValue)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            let content = reportsVM.exportContent(for: report.id, format: format.rawValue)
            try? content.write(to: tempURL, atomically: true, encoding: .utf8)
            
            self.shareItem = ShareItem(url: tempURL)
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Admin Report Item Row
private struct AdminReportItemRow: View {
    let report: ReportItem
    let onPreview: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        Button(action: onPreview) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(report.color.opacity(0.1)).frame(width: 48, height: 48)
                    Image(systemName: report.icon).font(.system(size: 20)).foregroundStyle(report.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.title).font(Theme.Typography.headline)
                    Text(report.description).font(Theme.Typography.caption).foregroundStyle(.secondary).lineLimit(1)
                    
                    HStack(spacing: 12) {
                        Label(report.lastGenerated, systemImage: "clock").font(Theme.Typography.caption2).foregroundStyle(.tertiary)
                        Label(report.size, systemImage: "doc").font(Theme.Typography.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.top, 2)
                }
                
                Spacer()
                
                Menu {
                    Button(action: onPreview) {
                        Label("Preview Data", systemImage: "eye")
                    }
                    Divider()
                    Button(action: onExport) {
                        Label("Export PDF", systemImage: "doc.fill")
                    }
                    Button(action: onExport) {
                        Label("Export Excel", systemImage: "tablecells.fill")
                    }
                    Button(action: onExport) {
                        Label("Export CSV", systemImage: "list.bullet")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.Colors.primary.opacity(0.8))
                        .padding(8)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Report Builder Modal
struct AdminCustomReportBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedSource = "Portfolio Data"
    private let sources = ["Portfolio Data", "Active Collections", "Risk Flags", "Disbursement Logs"]
    
    @State private var columns: [String: Bool] = [
        "Applicant Name": true,
        "Loan Amount": true,
        "Interest Rate": false,
        "Current DPD": true,
        "CIBIL Score": false,
        "Origination Date": true,
        "Risk Classification": false
    ]
    
    @State private var selectedFormat: ExportFormat = .csv
    @State private var isGenerating = false
    @State private var shareItem: ShareItem? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Base Dataset")) {
                    Picker("Data Source", selection: $selectedSource) {
                        ForEach(sources, id: \.self) { Text($0).tag($0) }
                    }
                }
                
                Section(header: Text("Data Columns")) {
                    ForEach(Array(columns.keys.sorted()), id: \.self) { key in
                        Toggle(key, isOn: Binding(
                            get: { self.columns[key] ?? false },
                            set: { self.columns[key] = $0 }
                        ))
                        .tint(Theme.Colors.primary)
                    }
                }
                
                Section(header: Text("Export Format")) {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Custom Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    generateReport()
                } label: {
                    if isGenerating {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Generate Report")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .foregroundStyle(.white)
                .background(Theme.Colors.primary)
                .cornerRadius(16)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.Colors.adaptiveBackground(colorScheme).shadow(color: .black.opacity(0.05), radius: 10, y: -5))
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(activityItems: [item.url]) // Let them share immediately
                    .onDisappear {
                        // After share sheet closes, dismiss the whole builder
                        dismiss()
                    }
            }
        }
    }
    
    private func generateReport() {
        isGenerating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isGenerating = false
            let fileName = "Custom_\(selectedSource.replacingOccurrences(of: " ", with: "_")).\(selectedFormat.rawValue)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try? "Mock dynamically generated data for \(selectedSource)".write(to: tempURL, atomically: true, encoding: .utf8)
            shareItem = ShareItem(url: tempURL)
        }
    }
}

// MARK: - Export Options Sheet
private struct ExportOptionsSheet: View {
    let report:ReportItem; let onExport:(ExportFormat)->Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .pdf
    @State private var dateRange = 0
    private let dateRanges = ["This Month","Last 3 Months","Last 6 Months","This FY"]
    var body: some View {
        NavigationStack {
            Form {
                Section("Report") { LabeledContent("Type",value:report.title); LabeledContent("Size",value:report.size) }
                Section("Format") {
                    Picker("Format",selection:$selectedFormat) {
                        ForEach(ExportFormat.allCases,id:\.self) { Text($0.displayName).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("Date Range") {
                    Picker("Period",selection:$dateRange) {
                        ForEach(dateRanges.indices,id:\.self) { Text(dateRanges[$0]).tag($0) }
                    }
                }
            }
            .navigationTitle("Export Options").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Cancel"){dismiss()} }
                ToolbarItem(placement:.confirmationAction) { Button("Generate"){dismiss();onExport(selectedFormat)}.fontWeight(.semibold) }
            }
        }
    }
}



// MARK: - Data Models
struct ReportItem: Identifiable {
    let id:String; let title:String; let description:String; let icon:String; let color:Color; let lastGenerated:String; let size:String
}

enum ExportFormat: String, CaseIterable {
    case pdf="pdf",excel="excel",csv="csv"
    var displayName: String { switch self { case .pdf: return "PDF"; case .excel: return "Excel"; case .csv: return "CSV" } }
}

// MARK: - Report Preview Sheet
private struct ReportPreviewSheet: View {
    let report: ReportItem
    let onExport: (ExportFormat) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var reportsVM: AdminReportsViewModel

    private var table: (columns: [String], rows: [[String]]) {
        reportsVM.previewTable(for: report.id)
    }
    
    private var statsRows: [ReportRow] {
        AdminReportsViewModel.liveReportRows(
            for: reportsVM.normalizedReportID(report.id),
            from: reportsVM.applications
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Report header
                    HStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .fill(report.color.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: report.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(report.color)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(report.title).font(Theme.Typography.headline)
                            Text(report.description).font(Theme.Typography.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Last: \(report.lastGenerated)").font(Theme.Typography.caption).foregroundStyle(.secondary)
                            Text(report.size).font(Theme.Typography.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .cardStyle(colorScheme: colorScheme)

                    // Data table
                    VStack(spacing: 0) {
                        // Table header
                        HStack(spacing: 0) {
                            ForEach(table.columns, id: \.self) { col in
                                Text(col)
                                    .font(Theme.Typography.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 10)
                            }
                        }
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))

                        // Table rows
                        ForEach(table.rows.indices, id: \.self) { rowIdx in
                            HStack(spacing: 0) {
                                ForEach(table.rows[rowIdx].indices, id: \.self) { colIdx in
                                    Text(table.rows[rowIdx][colIdx])
                                        .font(Theme.Typography.caption)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 10)
                                }
                            }
                            if rowIdx < table.rows.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .cardStyle(colorScheme: colorScheme)

                    // Summary stats
                    HStack(spacing: Theme.Spacing.md) {
                        previewStat(label: statsRows.first?.label ?? "Total", value: statsRows.first?.value ?? "—", color: Theme.Colors.primary)
                        previewStat(label: statsRows.dropFirst().first?.label ?? "Approved", value: statsRows.dropFirst().first?.value ?? "—", color: Theme.Colors.success)
                        previewStat(label: statsRows.dropFirst(2).first?.label ?? "Pending", value: statsRows.dropFirst(2).first?.value ?? "—", color: Theme.Colors.warning)
                        previewStat(label: statsRows.dropFirst(3).first?.label ?? "Rejected", value: statsRows.dropFirst(3).first?.value ?? "—", color: Theme.Colors.critical)
                    }

                    // Export actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export Options").font(Theme.Typography.subheadline).foregroundStyle(.secondary).padding(.leading, 4)
                        
                        HStack(spacing: 16) {
                            exportButton("PDF", icon: "doc.text.fill", format: .pdf, color: .red)
                            exportButton("Excel", icon: "tablecells.fill", format: .excel, color: .green)
                            exportButton("CSV", icon: "list.bullet.rectangle.fill", format: .csv, color: Theme.Colors.adaptivePrimary(colorScheme))
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Colors.adaptiveBackground(colorScheme))
            .navigationTitle("Preview: \(report.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func previewStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(Theme.Typography.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.sm)
        .cardStyle(colorScheme: colorScheme)
    }

    private func exportButton(_ label: String, icon: String, format: ExportFormat, color: Color) -> some View {
        Button {
            dismiss()
            onExport(format)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(color.opacity(0.1)).frame(width: 50, height: 50)
                    Image(systemName: icon).font(.system(size: 22)).foregroundStyle(color)
                }
                Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
