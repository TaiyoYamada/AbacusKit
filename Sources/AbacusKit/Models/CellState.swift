// AbacusKit - CellState
// Swift 6.2

import Foundation

/// そろばん珠（ビーズ）の状態
///
/// 各セルは上位置（Upper）、下位置（Lower）、または検出不能（Empty）のいずれか。
///
/// ## そろばんの構造
/// ```
/// ┌─────────────────┐
/// │  ○  Upper (0点) │  上珠が上にある = カウントしない
/// │  ●  Lower (5点) │  上珠が下にある = 5点
/// ├─────────────────┤
/// │  ●  Lower (1点) │  下珠が上にある = 1点ずつ
/// │  ●  Lower (1点) │
/// │  ○  Upper (0点) │  下珠が下にある = カウントしない
/// │  ○  Upper (0点) │
/// └─────────────────┘
/// ```
public enum CellState: Int, Sendable, Codable, Hashable, CaseIterable {
    /// 上位置（カウントしない）
    case upper = 0
    
    /// 下位置（カウントする）
    case lower = 1
    
    /// 検出不能
    case empty = 2
    
    /// この状態が有効な値を持つか
    public var isValid: Bool {
        self != .empty
    }
    
    /// 日本語名
    public var localizedName: String {
        switch self {
        case .upper: return "上"
        case .lower: return "下"
        case .empty: return "不明"
        }
    }
}

extension CellState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .upper: return "Upper"
        case .lower: return "Lower"
        case .empty: return "Empty"
        }
    }
}
