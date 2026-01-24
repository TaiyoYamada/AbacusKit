// AbacusKit - CellState
// Swift 6.2

import Foundation

/// Represents the state of a single soroban bead (cell).
///
/// Each bead on a soroban can be in one of three states:
/// - **Upper**: The bead is positioned away from the counting bar (not counted).
/// - **Lower**: The bead is positioned against the counting bar (counted).
/// - **Empty**: The bead state could not be determined.
///
/// ## Soroban Structure
///
/// A soroban consists of upper beads (worth 5 points each) and lower beads
/// (worth 1 point each). The counting bar separates the two sections:
///
/// ```
/// ┌─────────────────────┐
/// │  ○  Upper (0 points)│  Upper bead away from bar = not counted
/// │  ●  Lower (5 points)│  Upper bead against bar = 5 points
/// ├─────────────────────┤  ← Counting Bar
/// │  ●  Lower (1 point) │  Lower bead against bar = 1 point each
/// │  ●  Lower (1 point) │
/// │  ○  Upper (0 points)│  Lower bead away from bar = not counted
/// │  ○  Upper (0 points)│
/// └─────────────────────┘
/// ```
///
/// ## Example
///
/// ```swift
/// let state: CellState = .lower
/// print(state.isValid)  // true
/// print(state.description)  // "Lower"
/// ```
public enum CellState: Int, Sendable, Codable, Hashable, CaseIterable {
    /// The bead is in the upper position (away from counting bar).
    ///
    /// When a bead is in the upper position, it is not counted toward the digit value.
    /// - For upper beads: 0 points
    /// - For lower beads: 0 points
    case upper = 0

    /// The bead is in the lower position (against the counting bar).
    ///
    /// When a bead is in the lower position, it contributes to the digit value.
    /// - For upper beads: 5 points
    /// - For lower beads: 1 point each
    case lower = 1

    /// The bead state could not be determined.
    ///
    /// This typically occurs when the image quality is poor or the bead
    /// is occluded. Recognition results containing empty states should
    /// be treated as unreliable.
    case empty = 2

    /// Returns whether this state represents a valid, detected bead position.
    ///
    /// A state is valid if it is either `.upper` or `.lower`.
    /// The `.empty` state indicates detection failure.
    ///
    /// - Returns: `true` if the state is `.upper` or `.lower`; `false` for `.empty`.
    public var isValid: Bool {
        self != .empty
    }

    /// Returns a localized display name for this state.
    ///
    /// Useful for displaying bead states in user interfaces.
    public var localizedName: String {
        switch self {
        case .upper: "Upper"
        case .lower: "Lower"
        case .empty: "Unknown"
        }
    }
}

extension CellState: CustomStringConvertible {
    /// A textual representation of this cell state.
    public var description: String {
        switch self {
        case .upper: "Upper"
        case .lower: "Lower"
        case .empty: "Empty"
        }
    }
}
