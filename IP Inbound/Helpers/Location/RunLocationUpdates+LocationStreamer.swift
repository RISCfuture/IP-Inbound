extension RunLocationUpdates {
  /// Drives the app's shared ``LocationStreamer``. Its `start()`/`stop()` are listener-counted, so a
  /// stream a relaunch puts back is released by the run that ends, and the view layer's own pairs are
  /// left to balance themselves.
  static var locationStreamer: Self {
    .init(
      resume: { Task { await LocationStreamer.shared.start() } },
      suspend: { Task { await LocationStreamer.shared.stop() } }
    )
  }
}
