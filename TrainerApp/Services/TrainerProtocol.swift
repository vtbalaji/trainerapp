import Foundation
import Combine

/// Protocol that all trainer implementations must conform to.
/// This allows supporting Tacx (FTMS), Wahoo (proprietary), Elite, etc.
/// Views only depend on this protocol — never on a specific trainer brand.
@MainActor
protocol TrainerProtocol {

    /// Real-time data stream from the trainer
    var trainerData: TrainerData { get }

    /// Request control of the trainer (must be called before sending commands)
    func requestControl()

    /// Set target power in watts (ERG mode)
    func setTargetPower(watts: Int16)

    /// Set resistance level (0-100%)
    func setResistanceLevel(percent: Double)

    /// Set simulation parameters (grade, wind, rolling resistance, wind speed)
    func setSimulationParameters(
        grade: Double,          // percent grade (-40 to +40)
        windSpeed: Double,      // m/s
        rollingResistance: Double,  // coefficient (default ~0.004)
        windResistance: Double      // kg/m (default ~0.51)
    )

    /// Start or resume the trainer
    func start()

    /// Stop or pause the trainer
    func stop()

    /// Reset the trainer
    func reset()
}
