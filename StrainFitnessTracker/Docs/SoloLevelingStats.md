# Solo-Leveling Hunter Stat & Swim Ranking System

This document explains how to integrate the Solo Leveling–inspired stat engine, XP loop, and logarithmic swimming rankings into Strain Fitness Tracker. It maps every deliverable to concrete data inputs, Swift models, and UI surfaces so the system can be implemented incrementally without blocking existing HealthKit sync flows.

## 1. Core Data Flow

```text
HealthKit + Core Data + Manual PR inputs
            │
            ▼
   `StatInputAggregator` (new service)
            │  (normalizes inputs + applies modifiers)
            ├──▶ `StatComputationEngine`
            │        ├─ body composition stats (Vitality/Strength/Physique)
            │        ├─ readiness-driven stats (Endurance/Agility/Metabolic Power)
            │        └─ swim mastery stats (Top 3 events)
            │
            ├──▶ `DailyModifierService`
            │
            ├──▶ `SwimRankingService`
            │
            ▼
       `HunterProfileStore` (persisted via Core Data)
            │
            └──▶ SwiftUI views (Stats Tab, Swim Tab, Level Up overlays)
```

* HealthKit and Core Data already provide the bulk of metrics. The only new manual inputs are swim PRs and optional world record overrides.
* Each new service is pure Swift and can live in `StrainFitnessTracker/Core` with Combine publishers so Watch/iOS stay in sync.

## 2. Underlying Inputs

`StatInputAggregator` exposes a struct with the following metrics after unit conversions and smoothing (7-day EMA by default):

| Category | Metrics | Source |
| --- | --- | --- |
| Body composition | weight, bodyFat %, visceralFat, subcutaneous %, muscleMass (lb & %), fatFreeMass, bodyWater %, boneMass, BMI, BMR, metabolicAge, protein % | Scale import or manual entries stored in Core Data |
| Cardio + readiness | HRV, restingHR, sleepQuality, VO₂Max (if available), strainScore, recoveryScore, cadence/steps | HealthKit samples + ML prediction outputs |
| Swim | swimTimes (distance, time, date) | Manual entry view or CSV import |

Missing metrics fall back to historical averages so ranks are stable.

## 3. Stat Computation Logic

Each stat produces:
* **score** (0–100 normalized value)
* **trend** (7-day delta)
* **letter rank** (E → S+)
* **reason** text (fed by the explanation engine)

### Vitality
* Inputs: bodyFat %, visceralFat, sleepQuality, HRV.
* Score = 0.35·(100 − bodyFat%) + 0.25·(HRV percentile) + 0.20·sleep score + 0.20·(100 − visceralFat index).
* Buff: Good sleep streak (+5 to score for next day).

### Strength
* Inputs: muscleMass %, fatFreeMass, strain peaks.
* Score = 0.6·muscle percentile + 0.2·fatFree percentile + 0.2·(max strain/target).
* Buff: High strain day grants temporary +1 rank.

### Endurance
* Inputs: VO₂Max, long swim performance index, sleep debt.
* Score = 0.5·VO₂ percentile + 0.3·longest-event PI + 0.2·(1 − sleep debt).
* Debuff: Low recovery subtracts 7 points (one rank tier).

### Agility
* Inputs: sprint swim PI, cadence, resting HR trend.
* Score = 0.5·sprint PI + 0.3·cadence percentile + 0.2·(100 − restingHR percentile).
* Buff: High recovery adds +1 rank for 24 h.

### Physique
* Inputs: BMI, bodyFat %, muscle/fat ratio, protein %.
* Score blends closeness to target BMI (20–24), bodyFat slope, and muscle dominance.

### Metabolic Power
* Inputs: BMR, metabolic age, HRV, body water %.
* Buff: Good sleep streak shares same +5 as Vitality.

### Swim Mastery
* Score = average PI of top three swim events.

## 4. Letter Rank Thresholds

| Rank | Score Range |
| --- | --- |
| S+ | 90–100 |
| S  | 80–89 |
| A  | 70–79 |
| B  | 55–69 |
| C  | 40–54 |
| D  | 25–39 |
| E  | <25 |

Daily modifiers apply after raw score → before clamping to 0–100.

## 5. Daily Modifiers (Buffs / Debuffs)

`DailyModifierService` inspects ML recovery predictions, strain totals, and sleep quality:

| Condition | Trigger | Effect |
| --- | --- | --- |
| High recovery | recoveryScore ≥ 85 | +1 rank to Agility, “Awakened State” banner |
| High strain | strain ≥ target +15% | +1 rank to Strength |
| Low recovery | recoveryScore ≤ 40 | −1 rank to Endurance |
| Good sleep streak | ≥3 nights sleepScore ≥ 80 | +5 points to Vitality & Metabolic Power |

Modifiers expire at midnight local.

## 6. Logarithmic Swim Ranking System

`SwimRankingService` maintains `SwimEvent` structs and exposes derived metrics.

### Event Selection
1. Group swim workouts by distance (e.g., 50m, 100m, 200m, 400m, 800m, 1500m).
2. Compute best PR per distance.
3. Sort by performance index (highest first) and pick top 3 distances. Ties broken by most recent improvement.

### Performance Math
Let `PR` = user best time (seconds) and `WR` = reference world/national record. Compute:

```swift
let ratio = PR / WR
let logScore = -log(ratio)
let performanceIndex = exp(logScore * 5) * 100 // k = 5
```

### Rank Tiers (PI)
* S+: 90–100
* S: 70–<90
* A: 55–<70
* B: 40–<55
* C: 25–<40
* D: 10–<25
* E: <10

### Cross-Stat Integration
* Agility uses the sprint (shortest distance) event PI.
* Endurance uses the longest distance PI.
* Swim Mastery = average PI of selected events.

## 7. XP & Leveling

`HunterProgressionEngine` tracks XP, level, and Hunter Rank.

* **XP Sources**
  * +250 XP new swim PR
  * +150 XP improved body composition milestone
  * +100 XP hitting strain goal
  * +50 XP daily wellness habit completion
  * +variable XP for improved performance indices (5 × PI delta)
* **Level Curve** – Level `n` requires `500 + 150·(n−1)^1.25` XP. Clamp at level cap 60.
* **Hunter Rank** – Weighted average of stat letter ranks (S+=7 … E=1). Display as `Hunter Rank: A (Level 18)`.
* **Events** – When `levelUp == true`, fire `LevelUpEvent` overlay using Solo Leveling visuals; when PI improves, show PR toast.

## 8. Stat Explanation Engine

`StatExplanationEngine` takes the latest `StatSnapshot` and produces text:

* `positiveContributors`: sorted metrics where user beats 7-day average.
* `negativeContributors`: metrics dragging score down.
* `trendSummary`: uses 7-day vs 30-day delta.
* `nextRankRequirement`: “Reach VO₂Max ≥ 46 to unlock Rank A.”
* `reason`: templated string referencing top contributors.

Implementation tip: store explanation tokens (metric id, direction, magnitude) so localization becomes trivial later.

## 9. Aggregation & Derived Stats

* `hunterRank`: map average stat score to letter.
* `overallPerformanceIndex`: blend stat scores 50% and Swim Mastery 50%.
* `dailyReadinessScore`: average of Vitality, Endurance, Metabolic Power after modifiers.
* `consistencyStreaks`: count consecutive days hitting XP target and swim logging.

## 10. UI / UX Surfaces

### Main Stats Tab
* Player card header with avatar, level, XP bar, Hunter Rank chip.
* Grid of seven `StatCardView`s using `StatSnapshot`.
* Tap to open `StatDetailSheet` featuring explanation text and “Next Rank” progress bar.

### Swim Stats Tab
* `SwimMasteryHeader` (rank, average PI, improvement arrow).
* `TopSwimEventsView` with three cards: distance, PR, WR, PI, rank, “+X PI to reach next rank”.

### Daily Modifier Banner
* `DailyBuffBannerView` showing icon (buff/debuff), short explanation (“High Strain grants Strength boost”).

### Level-Up / PR Pop-Up
* Reuse `OverlayWindowController` to present Solo Leveling–style animation with XP gains and stat highlights.

## 11. Data Models (Swift Skeletons)

```swift
struct SwimEvent: Identifiable, Codable {
    var id: UUID
    var distance: Measurement<UnitLength>
    var worldRecord: TimeInterval
    var userPR: TimeInterval
    var performanceIndex: Double
    var rank: StatRank
    var lastUpdated: Date
}

struct StatsModel: Codable {
    var vitality: StatSnapshot
    var strength: StatSnapshot
    var endurance: StatSnapshot
    var agility: StatSnapshot
    var physique: StatSnapshot
    var metabolicPower: StatSnapshot
    var swimMastery: StatSnapshot
    var hunterRank: StatRank
    var level: Int
    var xp: Int
}

struct DailyModifiers: Codable {
    var recoveryBuff: StatModifier?
    var strainBuff: StatModifier?
    var sleepBuff: StatModifier?
}

struct StatSnapshot: Codable {
    var score: Double
    var trend: Double
    var rank: StatRank
    var explanation: StatExplanation
}
```

## 12. Integration Rules

1. **Swim updates** → recompute Swim Mastery + dependent stats → update `StatsModel` → persist + publish via Combine → UI refresh. If rank changes, enqueue XP event.
2. **Body composition updates** → trigger `StatComputationEngine` for Vitality/Strength/Physique → update Hunter Rank + XP.
3. **Recovery & strain** → `DailyModifierService` updates modifiers at midnight and after syncs → affected stat cards animate rank shift.

## 13. Implementation Roadmap

1. Build `StatInputAggregator` and `StatComputationEngine` with unit tests for each stat formula.
2. Implement `SwimRankingService` with sample WR table and manual PR entry UI.
3. Layer `DailyModifierService` + `HunterProgressionEngine` to emit Combine publishers for buffs, XP, and levels.
4. Update SwiftUI views (Stats tab, Swim tab, overlays) to consume the new models.
5. Add Core Data entities or JSON cache for persistence to keep watchOS and complications aligned.

With these components in place, the Solo Leveling stat fantasy, XP loop, and swim rankings become first-class citizens in Strain Fitness Tracker without breaking existing HealthKit infrastructure.
