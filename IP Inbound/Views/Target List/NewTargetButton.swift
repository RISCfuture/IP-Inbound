import CoreLocation
import MeasurementKitLocation
import SwiftData
import SwiftUI

struct NewTargetButton: View {
  /// How long a new target waits for a fix to seed its coordinate with. Long enough for a stream
  /// started at the tap to produce a first fix, short enough that a pilot who taps “Add Target” and
  /// starts typing is never made to wait on the GPS.
  private static let seedTimeout = Duration.seconds(2)

  @Binding var selectedTarget: Target?

  @Environment(\.modelContext)
  private var modelContext

  @Environment(\.previewLocation)
  private var previewLocation

  @Environment(\.services)
  private var services

  var body: some View {
    Button {
      let target = Target(name: String(localized: "New Target"), coordinate: placeholderCoordinate)
      modelContext.insert(target)
      selectedTarget = target
      Task { await seedPresentPosition(into: target) }
    } label: {
      Label("Add Target", systemImage: "plus")
    }
    .accessibilityIdentifier("addTargetButton")
  }

  /// Where a new target sits until a fix arrives to move it: the previewed position under a preview,
  /// and Null Island otherwise. Creating a target never requires a location — the pilot enters the
  /// real coordinates next, and the target opens on this immediately rather than waiting.
  private var placeholderCoordinate: Coordinate {
    guard let previewCoordinate = previewLocation?.location?.coordinate else {
      return .init(latitude: 0, longitude: 0)
    }
    return .init(previewCoordinate)
  }

  /// Races the stream's first located event against a deadline, so a GPS that never answers costs
  /// the new target `timeout` and nothing more.
  private static func firstFix(
    from provider: any LocationProviding,
    within timeout: Duration
  ) async -> Coordinate? {
    await withTaskGroup(of: Coordinate?.self) { group in
      group.addTask {
        guard let stream = await provider.eventStream() else { return nil }
        return await firstCoordinate(in: stream)
      }
      group.addTask {
        try? await Task.sleep(for: timeout)
        return nil
      }
      defer { group.cancelAll() }
      return await group.next().flatMap(\.self)
    }
  }

  private static func firstCoordinate(
    in stream: AsyncThrowingStream<LocationEvent, any Error>
  ) async -> Coordinate? {
    do {
      for try await event in stream {
        if let coordinate = event.coordinate { return coordinate }
      }
    } catch {
      // A stream that has failed has no fix to seed with, and the placeholder already stands in for
      // one.
    }
    return nil
  }

  /// Moves a new target to the aircraft's present position, if one can be had promptly.
  ///
  /// The target is already on screen by the time this runs, so nothing waits on the GPS: the seed
  /// lands if it arrives inside ``seedTimeout``, and the target keeps its placeholder if it does
  /// not — which is equally what a refusal, a restriction, or a device that cannot place itself
  /// produces. Asking for the stream here is what raises the authorization prompt, at the tap that
  /// engages the feature rather than at launch.
  ///
  /// The hold is released on every path out. This is the app whose ``LocationStreamer/stop()``
  /// carries a floor because an unbalanced release once wedged the stream for the life of the
  /// process; an unbalanced *acquire* is the same wound the other way round, and would leave the
  /// airborne configuration running with nothing on screen reading it.
  private func seedPresentPosition(into target: Target) async {
    let provider = services.location
    await provider.start()
    defer { Task { await provider.stop() } }

    guard let coordinate = await presentPosition(from: provider),
      selectedTarget?.id == target.id
    else { return }
    target.coordinate = coordinate
  }

  /// The fix already in hand, or failing that the first one to arrive before the seed gives up.
  private func presentPosition(from provider: any LocationProviding) async -> Coordinate? {
    if let coordinate = await provider.currentEvent()?.coordinate { return coordinate }
    return await Self.firstFix(from: provider, within: Self.seedTimeout)
  }
}

#Preview {
  let helper = PreviewHelper()
  NewTargetButton(selectedTarget: .constant(helper.target()))
    .modelContainer(helper.modelContainer)
    .environment(\.previewLocation, helper.preIPEvent)
}
