# Understanding Soroban Structure

Learn how the Japanese soroban works and how AbacusKit recognizes its values.

@Metadata {
    @PageKind(article)
}

## Overview

The soroban (Japanese abacus) uses a unique bead system that makes mental
calculation both visual and tactile. Understanding this structure helps you
work effectively with AbacusKit's recognition results.

## Soroban Anatomy

A soroban consists of:

- **Frame**: The rectangular boundary containing all beads
- **Rods/Lanes**: Vertical columns, each representing a digit place
- **Counting Bar**: The horizontal divider separating upper and lower beads
- **Upper Beads**: One bead per lane, worth 5 points each
- **Lower Beads**: Four beads per lane, worth 1 point each

```
┌─────────────────────────────────────────────────────┐
│  ○    ○    ●    ○    ○  │  Upper Beads (5 each)   │
├─────────────────────────│─ Counting Bar ───────────┤
│  ●    ●    ●    ●    ○  │                          │
│  ●    ●    ●    ●    ○  │  Lower Beads (1 each)   │
│  ●    ○    ●    ○    ○  │                          │
│  ○    ○    ○    ○    ○  │                          │
└─────────────────────────────────────────────────────┘
   9    7    9    6    0   = 97,960
```

## Reading Bead Positions

### Upper Bead

The single upper bead in each lane contributes 5 points when moved down
against the counting bar:

| Position | Points |
|----------|--------|
| **Up** (away from bar) | 0 |
| **Down** (against bar) | 5 |

### Lower Beads

Each of the four lower beads contributes 1 point when moved up against
the counting bar:

| Beads Against Bar | Points |
|-------------------|--------|
| 0 beads | 0 |
| 1 bead | 1 |
| 2 beads | 2 |
| 3 beads | 3 |
| 4 beads | 4 |

## Calculating Digit Values

The value of each digit (0-9) is the sum of:
- Upper bead contribution (0 or 5)
- Lower beads contribution (0-4)

### Example Values

| Upper | Lower Beads | Value |
|-------|-------------|-------|
| ○ (up) | ○○○○ | 0 |
| ○ (up) | ●●●○ | 3 |
| ● (down) | ○○○○ | 5 |
| ● (down) | ●●○○ | 7 |
| ● (down) | ●●●● | 9 |

## AbacusKit Representation

AbacusKit uses ``CellState`` to represent individual bead positions:

```swift
public enum CellState {
    case upper  // Bead in upper position (not counted)
    case lower  // Bead in lower position (counted)
    case empty  // Could not determine position
}
```

Each ``SorobanDigit`` contains:
- One `upperBead: CellState`
- Four `lowerBeads: [CellState]`
- The calculated `value: Int`

```swift
let digit = result.lanes[0].digit
print("Upper bead: \(digit.upperBead)")     // .lower (5 points)
print("Lower beads: \(digit.lowerBeads)")   // [.lower, .lower, .upper, .upper]
print("Value: \(digit.value)")               // 7
```

## Lane Ordering

AbacusKit returns lanes in right-to-left order, matching standard
abacus reading:

- **Position 0**: Ones place (rightmost)
- **Position 1**: Tens place
- **Position 2**: Hundreds place
- And so on...

```swift
let result = // ... recognition result for 1,234

for lane in result.lanes.sorted(by: { $0.position > $1.position }) {
    print("Position \(lane.position): \(lane.value)")
}
// Output:
// Position 3: 1
// Position 2: 2
// Position 1: 3
// Position 0: 4
```

Use ``SorobanResult/digitValues`` for a left-to-right array:

```swift
print(result.digitValues)  // [1, 2, 3, 4]
print(result.value)        // 1234
```

## Variable Lane Support

Traditional sorobans typically have 13-27 lanes. AbacusKit supports
any configuration from 1 to 27 lanes, configured via:

```swift
var config = AbacusConfiguration.default
config.minLaneCount = 5   // Reject sorobans with fewer lanes
config.maxLaneCount = 17  // Reject sorobans with more lanes
```
