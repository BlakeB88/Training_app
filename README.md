# Strain Fitness Tracker

Strain Fitness Tracker is a SwiftUI-powered wellness companion that mirrors high-end recovery platforms with your own data. It pulls workouts, sleep, HRV, stress, and nutrition metrics from HealthKit, turns them into actionable insights, and keeps iPhone, Apple Watch, and complication experiences in sync.

## Features

### Deep HealthKit integration
* Reads an extensive set of workout, heart, sleep, stress, and nutrition samples through a centralized `HealthKitManager`, including HRV, resting heart rate, respiratory rate, and dietary summaries.
* Provides async and callback-based authorization helpers so the UI can immediately react to permission changes.

### Automatic data syncing
* Schedules quick, full, and targeted sync operations that aggregate workouts, sleep, stress, and strain into a Core Data store. 
* Refreshes stress data independently so the dashboard stays responsive even when other HealthKit reads are throttled.

### Adaptive stress and recovery analytics
* The main tab experience highlights recovery predictions, stress monitoring, and more screens with a custom tab bar.
* Stress dashboards visualize live stress history, distribution, and guidance fed by synced HealthKit samples.

### Solo Leveling hunter stat sheet
* A dedicated Hunter tab renders the Solo Leveling–style stat cards, XP bar, global Hunter Rank, and the swim mastery dashboard described in the system design.
* Stats are calculated with the in-app Hunter stat engine, which merges HealthKit-derived readiness data, body composition inputs, and logarithmic swim rankings.
* Daily buffs/debuffs, animated rank progress, and the log-based swim event tracker are all surfaced directly in SwiftUI with refreshable data.

### On-device machine learning
* Trains a CreateML boosted tree regressor directly on the device using rolling health metrics to predict tomorrow’s recovery.
* Surfaces recovery predictions, contributing factors, and guidance through the `MLPredictionView`.

### Persistent analytics store
* Persists aggregated daily metrics, workouts, and stress readings with Core Data for longitudinal insights.

## Project structure

```
StrainFitnessTracker/
├── App/                 # App entry point and HealthKit bootstrap
├── Core/                # HealthKit, AI, integration, and persistence layers
├── Models/              # Domain models for daily metrics and workouts
├── Services/            # Sync, ML training, background tasks, notifications
├── ViewModels/          # Observable objects backing SwiftUI views
├── Views/               # SwiftUI dashboard, stress, strain, and recovery UI
├── StrainComplicationExtension/   # WidgetKit complication targets
├── "StrainFitnessTrackerWatch Watch App"/   # watchOS companion interface
└── Tests/               # Unit and UI test targets
```

## Getting started

1. **Clone and open** – Clone the repository and open `StrainFitnessTracker.xcodeproj` in Xcode 15 or later.
2. **Update bundle identifiers** – Replace the placeholder bundle IDs and App Group (`group.com.blake.StrainFitnessTracker`) with values tied to your developer account so HealthKit, background delivery, and sharing entitlements resolve.
3. **Enable capabilities** – Confirm HealthKit, Background Modes, and App Groups are enabled for the iOS, watchOS, and complication targets before building.
4. **Adjust deployment targets if needed** – The project currently targets iOS/watchOS 26.0; lower the deployment target to match the OS versions available on your devices or simulators.
5. **Run on device** – Build and run the iOS app on a HealthKit-capable device, sign into your Apple Watch if available, and trigger a **Quick Sync** from the dashboard to populate data.

## Working with data

* **Initial sync:** Launching the app requests HealthKit permissions, kicks off an initial sync, and persists the results so dashboards load instantly afterward. 
* **Manual refresh:** Pull to refresh the stress tab or use toolbar actions to request new HealthKit samples on demand.
* **Machine learning:** After at least two weeks of data, tap **Predict Tomorrow’s Recovery** to train and evaluate the on-device model; progress and accuracy are reported live. 

## Testing

Run the unit and UI test suites from Xcode’s Test navigator. The project ships with iOS, watchOS, and complication targets so you can validate HealthKit authorization flows, data sync, and Watch communication end-to-end.

## Portfolio highlights

* HealthKit-first fitness analytics with a synchronized Apple Watch experience.
* On-device Core ML training for personalized recovery forecasting.
* Robust Core Data persistence that powers dashboards, complications, and watchOS widgets.

## Solo Leveling Hunter Stats (Design Add-On)

The repository now ships with a full design for integrating a Solo Leveling–style hunter stat sheet, XP loop, and logarithmic swim ranking system. The blueprint covers:

* Seven core stat categories powered by body composition, readiness, and swim data
* Daily buffs/debuffs tied to recovery, strain, and sleep quality
* Automatic top-three swim event selection with log-based performance indices
* XP, level, and Hunter Rank progression with Solo Leveling–inspired UI beats

👉 See [`StrainFitnessTracker/Docs/SoloLevelingStats.md`](StrainFitnessTracker/Docs/SoloLevelingStats.md) for the complete system design, data models, and integration steps.
