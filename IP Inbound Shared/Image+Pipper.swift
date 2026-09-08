import Foundation
public import SwiftUI

extension Image {
  /// The app's logomark: the A-10C HUD pipper its icon draws, carrying the aiming dot, the ring,
  /// the range ticks and the moving target index.
  ///
  /// Stands for the app itself on the screens that have no run of their own to draw yet.
  public static var pipper: Image { Image("Pipper", bundle: Bundle.guidance) }
}
