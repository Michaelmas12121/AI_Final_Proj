# Life City: First Breath v0.1.0

## Player-visible changes

- Explore one compact body-city as a maintenance worker.
- Restore the Lung District through a physical power, intake, and chamber sequence.
- Align the pulmonary route at the Heart Hub.
- Observe simulated oxygen become trapped when only the lungs are active.
- Recover from critical oxygen and trigger a city-wide relighting sequence.
- Play with keyboard or mouse at a 640×360 internal pixel-art resolution.

## Requirements

- Windows 10 or Windows 11, 64-bit.
- Extract the complete ZIP before launching the executable.
- No network connection, account, or installation is required.

## Known limitations

- Placeholder procedural art; no final audio.
- One scenario only.
- No saving, accessibility settings menu, or localization.
- The executable is not code-signed, so Windows SmartScreen may display a warning.
- Physiological behavior is simplified for education and is not medical guidance.

## Verification

- Godot 4.7.1 stable import and parser check.
- 28 deterministic simulation scenarios.
- 5 accepted exploration scenarios.
- 6 gameplay-clarity scenarios covering the eight puzzle/recovery requirements.
- Windows release export and exported-executable smoke launch.
- Manual 640×360 first-time, wrong-order, critical-state, and recovery checks.

## Rollback

Do not publish the release if the executable fails to launch, required files are
missing from the ZIP, or the default scene is not the Exploration Clarity prototype.
If a published build is unacceptable, mark the release as a pre-release or remove
the release asset through normal repository administration, then publish a newly
reviewed immutable build. Do not replace a tagged artifact silently.
