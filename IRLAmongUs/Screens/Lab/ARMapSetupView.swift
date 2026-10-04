import SwiftUI

/// A local measured map, shared by setup and the live AR HUD. No GPS projection.
struct ARMeasuredMap: View {
    let layout: ARMapLayout
    var player: SIMD2<Float>?
    var selectedID: String = "electrical"
    var completed: Set<String> = []
    var tracking = false
    var heading: Float = 0
    var onPlace: ((SIMD2<Float>) -> Void)?

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 18
            let width = max(1, geo.size.width - inset * 2)
            let height = max(1, geo.size.height - inset * 2)
            let scale = min(width, height) / 12
            let left = (geo.size.width - 12 * scale) / 2
            let bottom = (geo.size.height + 12 * scale) / 2
            ZStack {
                Canvas { context, _ in
                    func project(_ point: SIMD2<Float>) -> CGPoint {
                        CGPoint(x: left + CGFloat(point.x + 6) * scale, y: bottom - CGFloat(point.y) * scale)
                    }
                    var grid = Path()
                    for metres in stride(from: 0, through: 12, by: 2) {
                        let x = left + CGFloat(metres) * scale
                        let y = bottom - CGFloat(metres) * scale
                        grid.move(to: CGPoint(x: x, y: bottom - 12 * scale)); grid.addLine(to: CGPoint(x: x, y: bottom))
                        grid.move(to: CGPoint(x: left, y: y)); grid.addLine(to: CGPoint(x: left + 12 * scale, y: y))
                    }
                    context.stroke(grid, with: .color(.white.opacity(0.2)), lineWidth: 1)
                    for task in layout.tasks {
                        let centre = project(task.point)
                        let colour: Color = completed.contains(task.id) ? .green : (task.id == selectedID ? .yellow : .cyan)
                        if task.id == selectedID {
                            let radius = CGFloat(NearbyTaskGate.interactionRadius) * scale
                            context.stroke(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)),
                                           with: .color(colour.opacity(0.5)), lineWidth: 1)
                        }
                        context.fill(Path(ellipseIn: CGRect(x: centre.x - 4, y: centre.y - 4, width: 8, height: 8)), with: .color(colour))
                        context.draw(Text(task.name).font(.system(size: 9, weight: .bold)).foregroundStyle(colour),
                                     at: CGPoint(x: centre.x, y: centre.y - 12))
                    }
                    let marker = project(.zero)
                    context.fill(Path(CGRect(x: marker.x - 6, y: marker.y - 3, width: 12, height: 6)), with: .color(.white))
                    context.draw(Text("MARKER").font(.system(size: 8, weight: .bold)).foregroundStyle(.white),
                                 at: CGPoint(x: marker.x, y: marker.y + 9))
                    if let player {
                        let centre = project(player)
                        var arrow = Path()
                        let angle = CGFloat(heading)
                        for (index, p) in [CGPoint(x: 0, y: -8), CGPoint(x: -5, y: 6), CGPoint(x: 5, y: 6)].enumerated() {
                            let rotated = CGPoint(x: centre.x + p.x * cos(angle) - p.y * sin(angle),
                                                  y: centre.y + p.x * sin(angle) + p.y * cos(angle))
                            if index == 0 { arrow.move(to: rotated) } else { arrow.addLine(to: rotated) }
                        }
                        arrow.closeSubpath()
                        context.fill(arrow, with: .color(tracking ? .cyan : .gray))
                        context.stroke(arrow, with: .color(.black), lineWidth: 1)
                        context.draw(Text("YOU").font(.system(size: 9, weight: .bold)).foregroundStyle(.cyan),
                                     at: CGPoint(x: centre.x + 16, y: centre.y))
                    }
                }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { value in
                    let x = Float((value.location.x - left) / scale) - 6
                    let y = Float((bottom - value.location.y) / scale)
                    guard (-6...6).contains(x), (0...12).contains(y) else { return }
                    onPlace?(SIMD2((x * 4).rounded() / 4, (y * 4).rounded() / 4))
                })
                .accessibilityLabel("Measured task map, twelve metres square")
                .accessibilityIdentifier("arWalking.measuredMap")
            }
        }
    }
}

struct ARMapSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ARMapLayout
    @State private var selected = "electrical"
    @State private var printable: URL?
    let save: (ARMapLayout) -> Void

    init(layout: ARMapLayout, save: @escaping (ARMapLayout) -> Void) {
        _draft = State(initialValue: layout)
        self.save = save
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("12 × 12 m · grid every 2 m").font(.caption.bold())
                    ARMeasuredMap(layout: draft, selectedID: selected, onPlace: moveSelected)
                        .background(.black, in: RoundedRectangle(cornerRadius: 12))
                    Text("Select a task, then tap the map. Pins snap to 0.25 m.")
                        .font(.caption2).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Map origin: floor below the marker. Right is right when facing it; away points into the room.")
                            .font(.caption)
                        ForEach(draft.tasks) { task in
                            Button { selected = task.id } label: {
                                HStack {
                                    Image(systemName: selected == task.id ? "checkmark.circle.fill" : "circle")
                                    Text(task.name)
                                    Spacer()
                                    Text(String(format: "%.2f, %.2f m", task.x, task.y)).monospacedDigit()
                                }
                            }.accessibilityIdentifier("arWalking.edit.\(task.id)")
                        }
                        coordinateField("Right (m)", axis: \.x)
                        coordinateField("Away (m)", axis: \.y)
                        HStack {
                            Text("Marker width (m)")
                            TextField("Width", value: $draft.markerWidthM, format: .number)
                                .keyboardType(.decimalPad).textFieldStyle(.roundedBorder).frame(width: 76)
                                .accessibilityIdentifier("arWalking.markerWidth")
                        }
                        HStack {
                            Text("Centre height (m)")
                            TextField("Height", value: $draft.markerCentreHeightM, format: .number)
                                .keyboardType(.decimalPad).textFieldStyle(.roundedBorder).frame(width: 76)
                                .accessibilityIdentifier("arWalking.markerHeight")
                        }
                        Text("Measure the entire printed image width and its centre height above the floor.")
                            .font(.caption2)
                        if let printable {
                            ShareLink(item: printable) { Label("Print / share ALIGN marker", systemImage: "printer") }
                        }
                        Text("PDF: 20 cm square at Actual Size / 100%. Mount upright on a fixed vertical wall.")
                            .font(.caption2)
                        Button("Restore sample layout") { draft = ARMapLayout(); selected = "electrical" }
                            .accessibilityIdentifier("arWalking.defaults")
                        if !draft.isValid {
                            Text("Use right −6…6 m, away 0…12 m, width 0.05…0.4 m, and centre height 0.2…2.5 m.")
                                .font(.caption2).foregroundStyle(.red)
                        }
                    }
                    .font(.callout)
                }.frame(maxWidth: .infinity)
            }
            .padding(12)
            .navigationTitle("Preset task map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save map") { save(draft); dismiss() }
                        .disabled(!draft.isValid).accessibilityIdentifier("arWalking.saveMap")
                }
            }
            .task {
                guard let data = NSDataAsset(name: "ARAlignmentPrintable")?.data else { return }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("print-marker-20cm.pdf")
                do { try data.write(to: url, options: .atomic); printable = url } catch { printable = nil }
            }
        }
    }

    private func moveSelected(_ point: SIMD2<Float>) {
        guard let index = draft.tasks.firstIndex(where: { $0.id == selected }) else { return }
        draft.tasks[index].x = point.x
        draft.tasks[index].y = point.y
    }

    private func coordinateField(_ title: String, axis: WritableKeyPath<ARMapTask, Float>) -> some View {
        HStack {
            Text(title)
            TextField(title, value: Binding(
                get: { draft.tasks.first(where: { $0.id == selected })?[keyPath: axis] ?? 0 },
                set: { value in
                    if let index = draft.tasks.firstIndex(where: { $0.id == selected }) { draft.tasks[index][keyPath: axis] = value }
                }), format: .number)
            .keyboardType(.numbersAndPunctuation).textFieldStyle(.roundedBorder).frame(width: 76)
            .accessibilityIdentifier(axis == \.x ? "arWalking.taskX" : "arWalking.taskY")
        }
    }
}
