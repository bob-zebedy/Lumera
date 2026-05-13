import SwiftUI

enum ControlTab: String, CaseIterable, Identifiable {
    case iso, shutter, focus, wb
    var id: String { rawValue }
    var label: String {
        switch self {
        case .iso: return "ISO"
        case .shutter: return "SS"
        case .focus: return "MF"
        case .wb: return "WB"
        }
    }
}

struct ManualControlPanel: View {
    @Bindable var model: CameraModel
    @State private var tab: ControlTab = .iso
    @State private var hapticGenerator = UISelectionFeedbackGenerator()

    var body: some View {
        VStack(spacing: 8) {
            tabPicker
            content.padding(.horizontal, 12)
        }
        .onAppear {
            snapToStops()
            hapticGenerator.prepare()
        }
        .onChange(of: tab) { _, newTab in
            if newTab == .iso || newTab == .shutter {
                hapticGenerator.prepare()
            }
        }
        .onChange(of: model.currentLens) { _, _ in snapToStops() }
        .onChange(of: model.minISO) { _, _ in snapToStops() }
        .onChange(of: model.minShutterSeconds) { _, _ in snapToStops() }
        .onChange(of: model.iso) { _, _ in snapToStops() }
        .onChange(of: model.shutterSeconds) { _, _ in snapToStops() }
    }

    private func snapToStops() {
        let snappedI = snappedISO(model.iso)
        if snappedI != model.iso { model.iso = snappedI }
        let snappedS = snappedShutter(model.shutterSeconds)
        if snappedS != model.shutterSeconds { model.shutterSeconds = snappedS }
    }

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(ControlTab.allCases) { t in
                tabSegment(t)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.15)))
        .clipShape(Capsule())
        .padding(.horizontal, 12)
    }

    private func tabSegment(_ t: ControlTab) -> some View {
        Text(t.label)
            .font(.caption.weight(.bold))
            .foregroundStyle(tab == t ? .black : .white)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(
                Capsule().fill(tab == t ? Color.yellow : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) { tab = t }
            }
    }

    @ViewBuilder
    private var content: some View {
        GlassyContainer(spacing: 10) {
            switch tab {
            case .iso:     isoSlider
            case .shutter: shutterSlider
            case .focus:   focusSlider
            case .wb:      wbSlider
            }
        }
    }

    private var isoSlider: some View {
        let stops = inRangeISOStops()
        let count = max(stops.count, 1)
        let currentIndex = stops.firstIndex(of: model.iso) ?? 0
        return ManualControlSlider(
            title: "ISO",
            valueText: String(format: "%.0f", model.iso),
            value: Binding(
                get: { Double(currentIndex) },
                set: { newValue in
                    guard !stops.isEmpty else { return }
                    let idx = max(0, min(stops.count - 1, Int(newValue.rounded())))
                    let next = stops[idx]
                    guard next != model.iso else { return }
                    hapticTick()
                    model.iso = next
                }
            ),
            range: 0 ... Double(count - 1),
            tickCount: count,
            minLabel: Text(verbatim: String(format: "%.0f", stops.first ?? model.minISO)),
            maxLabel: Text(verbatim: String(format: "%.0f", stops.last ?? model.maxISO))
        ) {
            model.applyManualExposureSync()
        }
    }

    private var shutterSlider: some View {

        let stops = inRangeShutterStops()
        let count = max(stops.count, 1)
        let currentIndex = stops.firstIndex(of: model.shutterSeconds) ?? 0
        return ManualControlSlider(
            title: "SHUTTER",
            valueText: shutterLabel(model.shutterSeconds),
            value: Binding(
                get: { Double(currentIndex) },
                set: { newValue in
                    guard !stops.isEmpty else { return }
                    let idx = max(0, min(stops.count - 1, Int(newValue.rounded())))
                    let next = stops[idx]
                    guard next != model.shutterSeconds else { return }
                    hapticTick()
                    model.shutterSeconds = next
                }
            ),
            range: 0 ... Double(count - 1),
            reversed: true,
            tickCount: count,
            minLabel: Text(verbatim: shutterLabel(stops.last ?? model.maxShutterSeconds)),
            maxLabel: Text(verbatim: shutterLabel(stops.first ?? model.minShutterSeconds))
        ) {
            model.applyManualExposureSync()
        }
    }

    private func inRangeISOStops() -> [Float] {
        Self.isoStops.filter { $0 >= model.minISO && $0 <= model.maxISO }
    }

    private func inRangeShutterStops() -> [Double] {
        Self.shutterStops.filter { $0 >= model.minShutterSeconds && $0 <= model.maxShutterSeconds }
    }

    private func hapticTick() {
        guard model.settings.hapticFeedbackEnabled else { return }
        hapticGenerator.selectionChanged()
        hapticGenerator.prepare()
    }

    private static let isoStops: [Float] = [
        25, 32, 40, 50, 64, 80,
        100, 125, 160, 200, 250, 320, 400, 500, 640, 800,
        1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000,
        10000, 12800
    ]

    private static let shutterStops: [Double] = {
        let fastFractions: [Double] = [
            1.0/8000, 1.0/6400, 1.0/5000, 1.0/4000, 1.0/3200, 1.0/2500,
            1.0/2000, 1.0/1600, 1.0/1250, 1.0/1000, 1.0/800, 1.0/640,
            1.0/500, 1.0/400, 1.0/320, 1.0/250, 1.0/200, 1.0/160,
            1.0/125, 1.0/100, 1.0/80, 1.0/60, 1.0/50, 1.0/40,
            1.0/30, 1.0/25, 1.0/20, 1.0/15, 1.0/13, 1.0/10,
            1.0/8, 1.0/6, 1.0/5, 1.0/4
        ]
        let longSeconds: [Double] = [
            0.3, 0.4, 0.5, 0.6, 0.8, 1.0, 1.3, 1.6, 2.0, 2.5, 3.2, 4.0,
            5.0, 6.0, 8.0, 10.0, 13.0, 15.0, 20.0, 25.0, 30.0
        ]
        return fastFractions + longSeconds
    }()

    private func snappedISO(_ value: Float) -> Float {
        snap(value: value, candidates: Self.isoStops, range: model.minISO ... model.maxISO)
    }

    private func snappedShutter(_ value: Double) -> Double {
        snap(value: value, candidates: Self.shutterStops, range: model.minShutterSeconds ... model.maxShutterSeconds)
    }

    private func snap<T: BinaryFloatingPoint>(
        value: T,
        candidates: [T],
        range: ClosedRange<T>
    ) -> T {
        var nearest: T?
        for c in candidates where range.contains(c) {
            if let n = nearest, abs(c - value) >= abs(n - value) { continue }
            nearest = c
        }
        return nearest ?? min(max(value, range.lowerBound), range.upperBound)
    }

    private var focusSlider: some View {
        ManualControlSlider(
            title: "FOCUS",
            valueText: String(format: "%.2f", model.focusLensPosition),
            value: Binding(
                get: { Double(model.focusLensPosition) },
                set: { model.focusLensPosition = Float($0) }
            ),
            range: 0 ... 1,
            minLabel: Text("Near"),
            maxLabel: Text("∞")
        ) {
            model.applyManualFocusSync()
        }
    }

    private var wbSlider: some View {
        ManualControlSlider(
            title: "WHITE BAL",
            valueText: String(format: "%.0fK", model.whiteBalanceTemperature),
            value: Binding(
                get: { Double(model.whiteBalanceTemperature) },
                set: { model.whiteBalanceTemperature = Float($0) }
            ),
            range: Double(WhiteBalanceRange.minTemperature) ... Double(WhiteBalanceRange.maxTemperature),
            minLabel: Text(verbatim: "\(Int(WhiteBalanceRange.minTemperature))K"),
            maxLabel: Text(verbatim: "\(Int(WhiteBalanceRange.maxTemperature))K")
        ) {
            model.applyManualWhiteBalanceSync()
        }
    }

    private func shutterLabel(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        if seconds >= 1 {
            return String(format: "%.1fs", seconds)
        }
        let denom = Int(round(1 / seconds))
        return "1/\(denom)"
    }
}
