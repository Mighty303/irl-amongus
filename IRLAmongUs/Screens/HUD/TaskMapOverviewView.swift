import CoreLocation
import SwiftUI

/// Fits every remaining task destination, leaving room around the outermost markers.
struct TaskMapViewport {
    let projection: LocalProjection

    init(points: [CGPoint], fallback: CGPoint, size: CGSize) {
        let points = points.filter { $0.x.isFinite && $0.y.isFinite && abs($0.x) <= 180 && abs($0.y) <= 90 }
        let anchor = points.first ?? fallback
        let meters = LocalProjection(anchor: anchor, pointsPerMeter: 1, origin: .zero)
        let local = points.isEmpty ? [CGPoint.zero] : points.map(meters.point)
        let minX = local.map(\.x).min() ?? 0, maxX = local.map(\.x).max() ?? 0
        let minY = local.map(\.y).min() ?? 0, maxY = local.map(\.y).max() ?? 0
        // A single station still gets a useful room-sized overview. Extra 20% gives the map breathing room.
        let width = max(24, (maxX - minX) * 1.2)
        let height = max(24, (maxY - minY) * 1.2)
        let scale = max(0.001, min(max(1, size.width - 96) / width, max(1, size.height - 96) / height))
        projection = LocalProjection(anchor: anchor, pointsPerMeter: scale,
            origin: CGPoint(x: size.width / 2 - (minX + maxX) / 2 * scale,
                            y: size.height / 2 - (minY + maxY) / 2 * scale))
    }
}

extension GameTask {
    var remainingStationIDs: [String] { completed ? [] : Array(steps.dropFirst(max(0, step))) }
}

/// Task overview: no fog or other players; yellow task markers remain visible across the whole venue.
struct TaskMapOverviewView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let state: GameState
    let selectTask: (String) -> Void

    private var destinations: [(station: Station, task: GameTask)] {
        var seen = Set<String>()
        return state.me.tasks.flatMap { task in
            task.remainingStationIDs.compactMap { id in
                guard let station = state.station(id), let lat = station.lat, let lng = station.lng,
                      CLLocationCoordinate2DIsValid(.init(latitude: lat, longitude: lng)),
                      seen.insert(id).inserted else { return nil }
                return (station: station, task: task)
            }
        }
    }

    private var ownPosition: CGPoint? {
        if let live = LocalMapTracking.coordinate(local: store.positions.estimate,
            positions: store.livePositions, playerID: state.me.id, serverNow: store.serverNow()) { return live }
        guard let station = state.station(state.me.lastCheckpoint?.stationId), let lat = station.lat, let lng = station.lng else { return nil }
        return CGPoint(x: lng, y: lat)
    }

    var body: some View {
        let targets = destinations
        let points = targets.map { CGPoint(x: $0.station.lng!, y: $0.station.lat!) }
        let campus = store.campusView(points: points, stations: state.stations, playArea: state.playArea)
        let allPoints = points + [ownPosition].compactMap { $0 }
        let fallbackBounds = POCMapBounds.covering(campus.rooms)
        let fallback = CGPoint(x: (fallbackBounds.minX + fallbackBounds.maxX) / 2,
                               y: (fallbackBounds.minY + fallbackBounds.maxY) / 2)
        VStack(spacing: 0) {
            HStack {
                Text("TASK MAP").font(.title2.bold())
                Spacer()
                Text("Yellow ! marks your remaining tasks").font(.caption)
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.title3.bold()).frame(width: 44, height: 44)
                        .background(.white.opacity(0.15), in: Circle())
                }
                .accessibilityLabel("Close task map").accessibilityIdentifier("taskMap.close")
            }.padding(.horizontal, 20).padding(.top, 8)
            if targets.isEmpty {
                ContentUnavailableView(state.me.tasks.allSatisfy(\.completed) ? "All tasks complete" : "No task locations yet",
                    systemImage: "map", description: Text("Task signs need a map location to appear here."))
            } else {
                GeometryReader { geo in
                    let projection = TaskMapViewport(points: allPoints, fallback: fallback, size: geo.size).projection
                    ZStack {
                        Canvas { context, _ in
                            for room in campus.rooms {
                                let path = projection.path(room)
                                context.fill(path, with: .color(.cyan.opacity(0.12)))
                                context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 1)
                            }
                        }.accessibilityHidden(true)
                        ForEach(targets, id: \.station.id) { target in
                            Button {
                                dismiss()
                                selectTask(target.task.id)
                            } label: {
                                VStack(spacing: 2) {
                                    AmongUsTaskMarker(size: 36)
                                    Text(target.station.name).font(.caption2.bold()).lineLimit(1)
                                    if let floor = target.station.floorId {
                                        Text([target.station.buildingId, floor].compactMap { $0 }.joined(separator: " · "))
                                            .font(.system(size: 9)).foregroundStyle(.white.opacity(0.8))
                                    }
                                }.frame(width: 92, height: 72)
                            }
                            .buttonStyle(.plain)
                            .zIndex(1) // Keep task markers visible when your position overlaps a station.
                            .position(projection.point(CGPoint(x: target.station.lng!, y: target.station.lat!)))
                            .accessibilityLabel("\(target.station.name), \(target.task.type.label)")
                            .accessibilityIdentifier("taskMap.station.\(target.station.id)")
                        }
                        if let ownPosition {
                            VStack(spacing: 0) {
                                Image(state.player(state.me.id)?.color?.lobbyAssetName ?? "PlayerMarker")
                                    .resizable().scaledToFit().frame(width: 30, height: 30)
                                Text("YOU").font(.system(size: 9, weight: .black)).foregroundStyle(.cyan)
                            }
                            .position(projection.point(ownPosition)).allowsHitTesting(false)
                        }
                    }.frame(width: geo.size.width, height: geo.size.height).clipped()
                }.accessibilityElement(children: .contain).accessibilityIdentifier("taskMap.overview")
            }
        }
        .foregroundStyle(.white)
        .background(Color(red: 0.04, green: 0.08, blue: 0.14).ignoresSafeArea())
        .onAppear { OrientationDelegate.requestLandscape() }
    }
}
