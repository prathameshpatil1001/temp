//
//  PremiumChart.swift
//  lms_project
//
//  A premium, smooth line chart component with area gradients and markers.
//

import SwiftUI

struct PremiumLineChart: View {
    let data: [Double]
    let labels: [String]
    let accentColor: Color
    let showPoints: Bool
    var unit: String = ""
    
    @State private var hoveredIndex: Int? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let points = calculatePoints(in: geo.size)
            
            ZStack {
                // Background Area
                let topPadding: CGFloat = 25
                let bottomPadding: CGFloat = 25
                let paddingLeft: CGFloat = 35
                let paddingRight: CGFloat = 20
                let drawHeight = geo.size.height - topPadding - bottomPadding
                
                // Grid Lines & Y-Axis Labels
                let maxVal = data.max() ?? 1.0
                let minVal = data.min() ?? 0.0
                let drawRange = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal)
                
                ForEach(0..<5) { i in
                    let y = topPadding + drawHeight - (CGFloat(i) / 4) * drawHeight
                    let val = minVal + (Double(i) / 4.0) * drawRange
                    
                    Path { path in
                        path.move(to: CGPoint(x: paddingLeft, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width - paddingRight, y: y))
                    }
                    .stroke(Color.secondary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    
                    Text(String(format: "%.0f", val))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .position(x: paddingLeft - 15, y: y)
                }
                
                // X & Y Axis Lines
                Path { path in
                    path.move(to: CGPoint(x: paddingLeft, y: topPadding))
                    path.addLine(to: CGPoint(x: paddingLeft, y: geo.size.height - bottomPadding))
                    path.addLine(to: CGPoint(x: geo.size.width - paddingRight, y: geo.size.height - bottomPadding))
                }
                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)

                // Interaction Surface — responds to tap & drag anywhere on the chart
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.85)) {
                                    updateHoveredIndex(at: value.location, in: geo.size, toggle: false)
                                }
                            }
                            .onEnded { value in
                                // keep tooltip visible after lift; second tap dismisses
                            }
                    )
                    .onTapGesture { location in
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            updateHoveredIndex(at: location, in: geo.size, toggle: true)
                        }
                    }
                
                // Background Area
                let baselineY = geo.size.height - 25 // Tighter baseline for compact layout
                PremiumLineShape(points: points, closed: true, height: baselineY)
                    .fill(accentColor.opacity(0.12))
                
                // The Main Premium Line
                PremiumLineShape(points: points, closed: false)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                // Markers - Small filled circle for every point
                if showPoints {
                    ForEach(0..<points.count, id: \.self) { i in
                        Circle()
                            .fill(accentColor)
                            .frame(width: 6, height: 6)
                            .position(points[i])
                    }
                }
                
                ZStack {
                    ForEach(labels.indices, id: \.self) { i in
                        let paddingLeft: CGFloat = 35
                        let paddingRight: CGFloat = 20
                        let stepX = (geo.size.width - paddingLeft - paddingRight) / CGFloat(labels.count - 1)
                        let x = paddingLeft + CGFloat(i) * stepX
                        Text(labels[i])
                            .font(.system(size: 9, weight: .bold)) // Finer font for compact view
                            .foregroundStyle(.secondary.opacity(0.8))
                            .position(x: x, y: geo.size.height - 8)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                
                // Dynamic Tooltip Overlay
                if let index = hoveredIndex, index < points.count {
                    let point = points[index]
                    
                    // Vertical highlight line
                    Rectangle()
                        .fill(accentColor.opacity(0.3))
                        .frame(width: 1)
                        .position(x: point.x, y: (geo.size.height - 25) / 2 + 10) 
                        .frame(height: geo.size.height - 45) // Refined for tighter paddings
                    
                    // Glowing point indicator
                    Circle()
                        .fill(accentColor)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: accentColor.opacity(0.5), radius: 4)
                        .position(point)
                    
                    // Tooltip Box
                    VStack(spacing: 4) {
                        let valueString = unit.isEmpty ? String(format: "%.0f", data[index]) : (unit == "k" ? String(format: "%.1f", data[index]) + unit : String(format: "%.0f", data[index]) + " " + unit)
                        Text("\(labels[index]): \(valueString)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 2, height: 6)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .position(x: point.x, y: point.y - 35)
                }
            }
        }
    }
    
    private func updateHoveredIndex(at location: CGPoint, in size: CGSize, toggle: Bool) {
        guard data.count > 1 else { return }
        let paddingLeft: CGFloat = 35
        let paddingRight: CGFloat = 20
        let stepX = (size.width - paddingLeft - paddingRight) / CGFloat(data.count - 1)
        let index = Int(((location.x - paddingLeft) / stepX).rounded())
        if index >= 0 && index < data.count {
            if toggle && hoveredIndex == index {
                hoveredIndex = nil // tap same point again → dismiss
            } else {
                if hoveredIndex != index {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
                hoveredIndex = index
            }
        } else {
            if toggle { hoveredIndex = nil }
        }
    }
    
    private func calculatePoints(in size: CGSize) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        
        let maxVal = data.max() ?? 1.0
        let minVal = data.min() ?? 0.0
        let range = maxVal - minVal
        let drawRange = range == 0 ? 1.0 : range
        
        let paddingLeft: CGFloat = 35
        let paddingRight: CGFloat = 20
        let topPadding: CGFloat = 25    // Reduced for compact view
        let bottomPadding: CGFloat = 25 // Reduced for compact view
        
        let drawHeight = size.height - topPadding - bottomPadding
        let stepX = (size.width - paddingLeft - paddingRight) / CGFloat(data.count - 1)
        
        return data.enumerated().map { index, value in
            let x = paddingLeft + CGFloat(index) * stepX
            let normalizedY = CGFloat((value - minVal) / drawRange)
            let y = topPadding + drawHeight - (normalizedY * drawHeight)
            return CGPoint(x: x, y: y)
        }
    }
}

struct PremiumLineShape: Shape {
    let points: [CGPoint]
    var closed: Bool = false
    var height: CGFloat = 0
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        
        path.move(to: points[0])
        
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        if closed {
            path.addLine(to: CGPoint(x: points.last!.x, y: height))
            path.addLine(to: CGPoint(x: points.first!.x, y: height))
            path.closeSubpath()
        }
        
        return path
    }
}
