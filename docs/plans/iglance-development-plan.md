# iGlance Development Plan

## 1. Document Goal

This document defines a full implementation plan for `iGlance`, a pure macOS menu bar app.

The goal is not to provide source code, but to provide a development blueprint detailed enough that an engineer can build the app directly from this plan without depending on any external plugin guidance.

Core product constraints:

- Pure menu bar utility.
- No main window.
- No Dock icon.
- Clicking the menu bar icon opens an `NSPopover`.
- All product functionality lives inside the popover.
- SwiftUI is the primary UI layer.
- AppKit is used only where SwiftUI is not sufficient or would become awkward.

## 2. Product Summary

`iGlance` is a lightweight system utility that compresses three categories of information into a single menu bar popover:

- `Monitor`: real-time CPU, GPU, memory, and temperature status.
- `Status`: system sleep-prevention controls and a read-only global sleep-disabled indicator.
- `Tasks`: a human-readable overview of hidden scheduled background jobs.

The menu bar icon itself is dynamic. It reflects a synthesized load index derived from CPU usage, GPU usage, memory pressure, and peak temperature. This lets the user estimate machine load without opening the popover.

## 3. High-Level Architecture

The app should be built as five layers:

1. App lifecycle layer
2. Status item and popover layer
3. State and orchestration layer
4. Data provider layer
5. SwiftUI presentation layer

Responsibility split:

- The lifecycle layer boots the app, configures accessory behavior, and handles cleanup.
- The status item layer owns the menu bar icon, click handling, and popover anchoring.
- The state layer coordinates timers, snapshots, tab selection, and view-facing models.
- The data layer reads system metrics, assertions, and scheduled tasks.
- The presentation layer renders the UI and consumes already-shaped models rather than calling low-level APIs directly.

This split matters because the app has two independent refresh loops:

- The menu bar icon must keep updating even when the popover is closed.
- The full monitor UI should only refresh while the popover is visible.

If everything is kept in one view model, those two lifecycles become tangled and harder to test.

## 4. Recommended File Structure

Use a multi-file structure from the start. Do not build this as a single-file SwiftUI sample.

Recommended layout:

- `iGlance/App/iGlanceApp.swift`
- `iGlance/App/AppDelegate.swift`
- `iGlance/App/AppEnvironment.swift`
- `iGlance/Controllers/StatusItemController.swift`
- `iGlance/Controllers/PopoverController.swift`
- `iGlance/Stores/AppStore.swift`
- `iGlance/Stores/MonitorStore.swift`
- `iGlance/Stores/StatusStore.swift`
- `iGlance/Stores/TasksStore.swift`
- `iGlance/Models/AppSection.swift`
- `iGlance/Models/SystemSnapshot.swift`
- `iGlance/Models/CPUSnapshot.swift`
- `iGlance/Models/GPUSnapshot.swift`
- `iGlance/Models/MemorySnapshot.swift`
- `iGlance/Models/TemperatureSnapshot.swift`
- `iGlance/Models/ProcessMetric.swift`
- `iGlance/Models/TaskEntry.swift`
- `iGlance/Models/TaskSource.swift`
- `iGlance/Models/PowerAssertionState.swift`
- `iGlance/Services/SystemInfoProvider.swift`
- `iGlance/Services/CPUUsageProvider.swift`
- `iGlance/Services/GPUUsageProvider.swift`
- `iGlance/Services/MemoryProvider.swift`
- `iGlance/Services/TemperatureProvider.swift`
- `iGlance/Services/PowerAssertionService.swift`
- `iGlance/Services/TaskDiscoveryService.swift`
- `iGlance/Services/MenuBarIconRenderer.swift`
- `iGlance/Services/MenuBarIconAnimator.swift`
- `iGlance/Services/ProcessRunner.swift`
- `iGlance/Support/LoadIndexCalculator.swift`
- `iGlance/Support/ColorInterpolation.swift`
- `iGlance/Support/HistoryBuffer.swift`
- `iGlance/Support/Formatters.swift`
- `iGlance/Support/TaskRuleFormatter.swift`
- `iGlance/Views/PopoverView.swift`
- `iGlance/Views/SectionSwitcherView.swift`
- `iGlance/Views/Monitor/MonitorView.swift`
- `iGlance/Views/Monitor/MonitorGridView.swift`
- `iGlance/Views/Monitor/MonitorCardView.swift`
- `iGlance/Views/Monitor/CPUCardView.swift`
- `iGlance/Views/Monitor/GPUCardView.swift`
- `iGlance/Views/Monitor/MemoryCardView.swift`
- `iGlance/Views/Monitor/TemperatureCardView.swift`
- `iGlance/Views/Status/StatusView.swift`
- `iGlance/Views/Tasks/TasksView.swift`
- `iGlance/Views/Reusable/CardSurfaceView.swift`
- `iGlance/Views/Reusable/OpenArcGaugeView.swift`
- `iGlance/Views/Reusable/SparklineView.swift`
- `iGlance/Views/Reusable/TemperatureBarView.swift`
- `iGlance/Resources/Assets.xcassets`
- `docs/plans/iglance-development-plan.md`

Why this structure:

- App entry and AppKit bridge stay isolated.
- Providers stay independent from UI.
- Each top-level tab gets a dedicated store and view folder.
- Reusable drawing and card chrome do not leak into business logic files.

## 5. Scene and Lifecycle Design

### 5.1 App Type

`iGlance` should behave as an accessory app:

- no main window
- no Dock icon
- menu bar only

Implementation direction:

- Use a SwiftUI app entry point.
- Install an app delegate adaptor if needed for launch-time configuration and cleanup.
- Keep the activation policy in accessory mode.

This must be an explicit product choice documented in code comments or project notes so it is not mistaken for an app launch bug.

### 5.2 Status Item

The menu bar presence should be owned by a dedicated controller.

Responsibilities:

- create `NSStatusItem`
- assign a custom icon image
- handle click action
- show or close the popover
- accept new rendered icon frames from the state layer

Do not place status item creation inside a random SwiftUI view. It is platform glue and should stay in a controller.

### 5.3 Popover

Use `NSPopover` instead of a menu for the main UI because:

- the UI is card-based and visual
- it contains tabs
- it includes animated gauges and charts
- it is closer to an app panel than a short text menu

Popover responsibilities:

- host the root SwiftUI `PopoverView`
- anchor to the status item button
- notify the state layer when shown or closed

When the popover opens:

- start detailed monitoring refresh
- refresh status page data
- refresh scheduled tasks

When the popover closes:

- stop detailed refresh timers
- preserve latest snapshot for immediate re-display next time

## 6. State Ownership Plan

Use narrow ownership. Do not put every property into one massive global object.

Recommended split:

- `AppStore`
  - owns the active section
  - owns popover visibility state
  - owns the menu bar icon state
  - coordinates stores and shared services

- `MonitorStore`
  - owns current monitor snapshot
  - owns 60-second histories
  - owns flip state of CPU/GPU/Memory cards
  - starts and stops detailed refresh loop

- `StatusStore`
  - owns the two assertion toggles
  - owns the read-only `SleepDisabled` indicator
  - performs assertion commands via service

- `TasksStore`
  - owns the current task list
  - owns loading and degraded states
  - refreshes only when the popover is visible or user switches to the tab

### 6.1 Store Interaction Rules

- Views do not call shell commands.
- Views do not parse plist files.
- Views do not calculate the menu bar icon.
- Stores should call services, then map service output into view-friendly models.
- Shared services may be injected through an environment container or initializer injection.

## 7. Core Data Models

Define stable models early. This reduces rework when wiring views.

### 7.1 `AppSection`

Enum with three cases:

- `monitor`
- `status`
- `tasks`

Each case should also provide:

- SF Symbol name
- localized display title
- accessibility label

### 7.2 `SystemSnapshot`

Represents one full monitor sampling cycle.

Suggested fields:

- timestamp
- cpu snapshot
- gpu snapshot
- memory snapshot
- temperature snapshot
- load index

### 7.3 CPU, GPU, Memory, Temperature Models

Each metric should have its own snapshot type instead of a generic dictionary-like structure.

Examples of fields:

- percentage or normalized value
- availability flag
- subtitle text
- supporting values such as model name, VRAM usage, pressure level, or temperatures

### 7.4 `ProcessMetric`

For top process lists:

- process name
- pid if available
- percentage value
- ranking field

### 7.5 `TaskEntry`

For the task list, define a normalized structure that works across all sources.

Suggested fields:

- id
- source
- label
- rule description
- raw rule text
- running state
- next trigger description if derivable
- notes for degraded parsing or unavailable status

## 8. Refresh and Scheduling Strategy

The app has two refresh channels.

### 8.1 Menu Bar Icon Refresh Loop

Purpose:

- update the menu bar icon every 2 seconds
- keep working even if popover is closed

Reads:

- CPU usage
- GPU usage if available
- memory pressure or usage
- highest known temperature

Writes:

- new load index
- interpolated render state for the icon

### 8.2 Detailed Popover Refresh Loop

Purpose:

- refresh visible monitor data
- update process lists and 60-second charts
- refresh status and tasks when appropriate

Suggested cadence:

- monitor data every 2 seconds while popover is open
- tasks data on popover open, on entering the tasks tab, and optionally manual refresh
- `SleepDisabled` status on popover open and on entering the status tab

### 8.3 History Buffer

Use a fixed-size ring buffer for 60-second sparkline history.

If sampling every 2 seconds:

- 30 samples represent 60 seconds

Each metric should have its own history buffer:

- CPU utilization history
- GPU utilization history
- memory utilization or pressure history

Do not append to unbounded arrays.

## 9. Load Index Design

Define the required function:

- `func loadIndex(cpu: Double, gpu: Double, memory: Double, maxTemp: Double) -> Double`

The function should return a normalized 0 to 100 value used only by the menu bar icon.

### 9.1 Why a Synthesized Index is Needed

The icon must convey overall machine strain, not just a single metric.

If the icon tracks only CPU:

- high GPU load would be invisible
- memory pressure spikes would be invisible
- thermally constrained states would be underrepresented

### 9.2 Suggested Weighting

Start with explicit weights:

- CPU: 0.35
- GPU: 0.25
- memory: 0.20
- max temperature: 0.20

This is only a starting point. Keep the weights centralized so they can be tuned after real use.

### 9.3 Temperature Normalization

Raw temperature is not already a percentage. It needs mapping.

A simple first pass:

- below 45 C: low contribution
- 45 C to 70 C: medium range
- above 70 C: high contribution
- 90 C and above: clamp near 100

The exact curve can be linear at first and replaced with a smoother piecewise curve later.

## 10. Menu Bar Icon Rendering Plan

### 10.1 Visual Structure

The icon contains:

- a fixed solid pupil
- an outer open arc
- an optional very faint guide ring

Rules:

- the pupil size never changes
- the outer arc starts from the top and grows symmetrically left and right
- the bottom gap remains about 60 degrees
- at 0 percent load the arc is very short
- at 100 percent load the arc sweeps roughly 300 degrees
- icon is monochrome template style only
- no colored icon states

### 10.2 Rendering Implementation

Use a dedicated renderer service. Do not mix icon drawing code into the status item controller.

Recommended responsibilities:

- compute arc angles from load index
- generate `NSImage`
- mark image as template when appropriate
- provide images at the correct menu bar scale

### 10.3 Animation Strategy

The menu bar icon is refreshed every 2 seconds, but it should not jump.

Use a lightweight interpolation approach:

- store previous displayed value
- animate toward the new target value over a shorter interval than the sampling period
- use an ease-in-out curve

Do not overengineer this into a complex frame scheduler on day one. A simple interpolator between snapshots is enough.

## 11. Monitor Tab Design

### 11.1 Layout

The monitor page contains four square cards in a 2 by 2 grid:

- CPU
- GPU
- Memory
- Temperature

The grid should have:

- equal spacing
- stable card sizes
- enough internal padding for text and charts
- a fixed popover width and height tuned for readability

### 11.2 Card Styling

All cards share one chrome system:

- rounded corners
- translucent material
- thin border
- soft shadow

Create one reusable surface wrapper so visual tuning happens in one place.

### 11.3 Flip Cards

Only three cards flip:

- CPU
- GPU
- Memory

Temperature does not flip.

Implementation guidance:

- use one generic flip-card container
- keep card front and card back as separate subviews
- store flip state outside the reusable view so state survives redraws cleanly

The flip should feel crisp, not theatrical. A restrained 3D rotation is enough.

## 12. Open Arc Gauge Design

This gauge is central to the monitor tab and should be implemented once, then reused.

### 12.1 Functional Requirements

- open arc shape
- bottom gap retained
- rounded line caps
- percentage text at center
- optional subtitle below
- support animated value updates
- support dynamic color interpolation

### 12.2 Color Interpolation

Use smooth interpolation across load thresholds:

- low usage: muted green
- mid usage: soft yellow
- high usage: muted red

Avoid:

- abrupt color jumps
- overly saturated warning colors
- neon gradients

The color function should be isolated in `ColorInterpolation.swift`.

### 12.3 Gauge Inputs

The reusable gauge should accept:

- current value
- normalized range
- line width
- foreground color or value-driven color function
- optional center label
- optional subtitle

## 13. CPU Card Plan

### 13.1 Front

Display:

- open arc gauge
- current CPU utilization percentage
- CPU model name underneath

CPU model name source:

- `sysctl`

### 13.2 Back

Display:

- top 5 CPU-consuming processes
- 60-second CPU sparkline

Suggested process source:

- start with a shell-based approach using `ps` or `top`
- if needed later, replace with lower-level APIs for efficiency

The first version should prioritize reliability and readability over extreme optimization.

## 14. GPU Card Plan

### 14.1 Front

Display:

- open arc gauge
- current GPU utilization percentage

### 14.2 Back

Display:

- 60-second GPU history sparkline
- current GPU temperature
- current VRAM usage such as `4.2 GB / 8 GB`

### 14.3 GPU Data Caveat

GPU telemetry is the most platform-sensitive part of this app.

The plan should anticipate three possible states:

- fully available
- partially available
- unavailable

The UI must support all three without breaking layout.

Suggested implementation policy:

- define optional fields in the GPU snapshot
- provide human-readable fallback text
- keep the card visible even when GPU metrics are incomplete

## 15. Memory Card Plan

### 15.1 Front

Display:

- open arc gauge
- memory pressure or used percentage

Prefer a signal closer to pressure than raw allocation when possible, because it better reflects user-perceived strain.

### 15.2 Back

Display:

- top 5 memory-consuming processes
- 60-second memory history sparkline

Memory source candidates:

- `host_statistics`
- `vm_stat`
- `ps` for per-process memory usage

## 16. Temperature Card Plan

This card does not flip.

Display:

- CPU average temperature
- GPU temperature
- SSD temperature

Presentation:

- three compact bars
- each bar labeled
- number shown near bar
- bar color interpolates green to yellow to red

### 16.1 Temperature Source

Temperature reading should be isolated behind a dedicated SMC service.

Implementation options:

- integrate a small SMC helper implementation
- embed a minimal subset of an SMC reader
- write a custom SMC wrapper only for required keys

Do not let raw SMC access spread across views or stores.

### 16.2 Degraded States

Some sensors may not be available.

Each temperature line should support:

- value available
- sensor unavailable
- temporary read failure

## 17. Status Tab Plan

The status page contains three rows:

- Prevent System Sleep toggle
- Prevent Display Sleep toggle
- SleepDisabled read-only indicator

### 17.1 Prevent System Sleep

Uses:

- `IOPMAssertionTypePreventSystemSleep`

Behavior:

- enabling creates an assertion
- disabling releases it
- the toggle reflects actual assertion state, not just intended state

### 17.2 Prevent Display Sleep

Uses:

- `IOPMAssertionTypePreventUserIdleDisplaySleep`

Behavior:

- enabling creates an assertion
- disabling releases it

### 17.3 SleepDisabled Indicator

Read-only. This reflects a broader system-level state, not the app's own assertions.

Data source:

- parse `pmset -g`
- fallback to `pmset -g custom` if needed

Display:

- status text: enabled or disabled
- colored status dot
- note that it is a system-level setting

### 17.4 Cleanup Requirement

On app termination:

- release all active assertions
- do not leave system sleep prevention behind

This is a hard requirement.

## 18. Tasks Tab Plan

This page is meant to expose hidden scheduled work in a compact way.

### 18.1 Sources

Collect from:

- user `LaunchAgents`
- system `LaunchDaemons`
- `crontab -l`
- `atq`

### 18.2 Launchd Parsing

Look for plist files that define:

- `StartInterval`
- `StartCalendarInterval`

Required outputs:

- label
- source type
- readable schedule rule
- running state if obtainable

For runtime state:

- use `launchctl list`

### 18.3 Cron Parsing

Read:

- `crontab -l`

Output:

- command or summary label
- original cron rule
- readable rule description

### 18.4 At Job Parsing

Read:

- `atq`

Output:

- job identifier
- scheduled time
- basic status if derivable

### 18.5 UI Rules

The list should stay minimal:

- one icon
- one primary label
- one secondary rule line
- one running state marker

Do not build a complex inspector for tasks in version one.

## 19. Command Execution and Parsing

Shell commands are acceptable for this app in clearly bounded places. Put all such calls behind `ProcessRunner`.

Use `ProcessRunner` to:

- execute a command
- collect stdout and stderr
- return termination status
- avoid direct `Process` code in stores and views

Parsing rules:

- prefer small source-specific parsers over one giant parser
- keep raw outputs out of UI
- attach parse failure notes to models for debugging

## 20. UI Composition Plan

### 20.1 Popover Root

The popover should contain:

- top icon-based section switcher
- main content panel below

Recommended section switcher behavior:

- three icon tabs
- strong selection affordance
- compact enough for a popover

### 20.2 Visual Style

Use system visual language:

- ultra-thin or thin material backgrounds
- native typography
- restrained borders and shadows

Do not simulate glass with custom blur stacks when system materials are enough.

### 20.3 Popover Size

Set a deliberate fixed or semi-fixed size. Do not let content autosize unpredictably.

A practical first target:

- width around 420 to 480 points
- height around 500 to 560 points

Tune after the first visual pass.

## 21. Accessibility and Usability

Even for a utility app, add basic accessibility from the start.

Required considerations:

- the menu bar icon has an accessibility label
- tabs have explicit labels, not icons only
- toggles expose state correctly
- charts and gauges have text equivalents
- task rows can be understood without depending only on color

## 22. Error Handling Strategy

Every subsystem should define failure behavior.

Examples:

- GPU unavailable: show unavailable state but keep card visible
- temperature sensor missing: show placeholder on that row only
- `pmset` parse failure: show unknown system-level state
- `launchctl` unavailable or denied: show task status as unknown
- assertion creation failure: toggle reverts and optionally shows inline failure text

The goal is degradation, not silence.

## 23. Performance Considerations

This is a menu bar utility. Its idle overhead matters.

Requirements:

- stop heavy refresh work when popover is closed
- keep the icon loop lightweight
- avoid repeatedly recreating expensive formatters
- keep history buffers bounded
- avoid shelling out more often than needed for slow-changing data such as tasks

Practical policy:

- metrics: every 2 seconds
- tasks: on-demand or low-frequency
- CPU-heavy parsing: keep off the main thread
- UI updates: marshal back to the main actor only after snapshots are prepared

## 24. Phased Implementation Plan

### Phase 1: Project Skeleton

Deliverables:

- Xcode macOS app target
- accessory-style launch behavior
- app entry point
- app delegate if needed
- folder structure created

Exit criteria:

- app launches without a main window
- no Dock icon appears

### Phase 2: Status Item and Popover

Deliverables:

- `NSStatusItem`
- click handling
- `NSPopover`
- root SwiftUI popover content

Exit criteria:

- clicking the menu bar icon opens and closes the popover reliably

### Phase 3: Shared State and Refresh Orchestration

Deliverables:

- app store
- monitor store
- timer orchestration
- popover open/close lifecycle hooks

Exit criteria:

- detailed refresh starts and stops with popover visibility
- app remains stable across repeated open/close cycles

### Phase 4: Dynamic Menu Bar Icon

Deliverables:

- load index calculator
- icon renderer
- icon interpolation behavior

Exit criteria:

- icon visibly changes with test values
- updates continue when popover is closed

### Phase 5: Monitor Data Providers

Deliverables:

- CPU provider
- memory provider
- initial GPU provider
- initial temperature provider

Exit criteria:

- one system snapshot can be produced on demand
- unavailable metrics degrade cleanly

### Phase 6: Monitor UI

Deliverables:

- 2x2 grid
- reusable gauge
- reusable card chrome
- CPU, GPU, memory, temperature cards
- card flip interaction
- 60-second sparkline support

Exit criteria:

- all four cards render correctly
- histories update over time

### Phase 7: Status UI and Power Assertions

Deliverables:

- assertion service
- status tab
- `SleepDisabled` parsing

Exit criteria:

- both toggles work independently
- app releases assertions on quit

### Phase 8: Tasks Discovery

Deliverables:

- task discovery service
- plist parsing
- cron parsing
- at queue parsing
- running state checks

Exit criteria:

- task list shows normalized entries from available sources

### Phase 9: Polish

Deliverables:

- animation tuning
- spacing and typography tuning
- degraded-state UX
- accessibility pass

Exit criteria:

- app feels stable, legible, and native

## 25. Testing Plan

Even if formal unit tests are deferred, test by subsystem.

### 25.1 Manual Functional Tests

- launch app and verify no Dock icon
- click icon and verify popover presentation
- close popover and verify monitor loop pauses
- leave app running and verify icon continues updating
- toggle both sleep assertions independently
- quit app and confirm assertions are not left active
- switch between tabs rapidly and verify state remains stable
- test on a machine with incomplete GPU or temperature data

### 25.2 Parser Tests

Create sample fixtures for:

- launchd plist with `StartInterval`
- launchd plist with `StartCalendarInterval`
- cron line variations
- `atq` output variations
- `pmset -g` output variations

Use parser tests where possible because string parsing is the most fragile part of this app.

### 25.3 Visual Verification

Verify:

- gauge geometry
- icon arc growth shape
- card flip readability
- sparkline clarity at popover scale
- low and high load color transitions

## 26. Key Risks and Mitigations

Risk: GPU metrics vary by hardware and OS.

Mitigation:

- design the GPU card for partial availability
- isolate the GPU provider behind a protocol or single service

Risk: SMC access can be hardware-sensitive.

Mitigation:

- keep temperature reads optional
- never let one sensor failure block all sampling

Risk: launchd and cron parsing can be messy.

Mitigation:

- normalize early into `TaskEntry`
- keep source-specific parsers small and testable

Risk: menu bar apps can leak timers or assertions.

Mitigation:

- centralize start/stop control
- ensure app termination cleanup path is explicit

## 27. Final Acceptance Checklist

The project is ready when all of the following are true:

- app launches as a pure menu bar utility
- no main window is shown
- no Dock icon is shown
- clicking the status item opens an `NSPopover`
- the menu bar icon is monochrome and dynamically reflects load
- the popover shows three sections: Monitor, Status, Tasks
- the Monitor page shows four cards in a stable 2 by 2 grid
- CPU, GPU, and Memory cards can flip and show history data
- the Temperature card shows three temperature bars
- the Status page can independently manage both power assertions
- `SleepDisabled` is shown as a read-only system-level indicator
- the Tasks page shows normalized scheduled job entries
- popover-close pauses detailed refresh
- menu bar icon continues updating while popover is closed
- quitting the app releases all app-owned power assertions

## 28. Suggested First Build Order

If implementation starts immediately, build in this exact order:

1. App entry, accessory behavior, status item, popover
2. App store and popover lifecycle hooks
3. Static popover UI skeleton with the three tabs
4. Load index calculator and static icon renderer
5. CPU and memory providers
6. Monitor cards and gauge component
7. History buffers and sparklines
8. Power assertion service and status tab
9. Task discovery service and tasks tab
10. GPU and temperature refinement
11. Animation, fallback states, and accessibility

This order minimizes blockers because it gets the shell of the app working first, then builds out the highest-value features, and leaves the most platform-sensitive telemetry work for after the architecture is stable.
