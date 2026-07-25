# Godot Collaboration Protocol for AI_Final_Proj

> Version: 1.0  
> Status: Mandatory repository policy for every human contributor, AI agent, automation, and subagent working on the Godot project  
> Applies to: Godot project setup, GDScript, scenes, resources, imported assets, project settings, tests, exports, releases, and any Git/GitHub work involving those files  
> Read with: the root `AGENTS.md`, which remains authoritative for security, authorization, GitHub delivery, review, and destructive-action rules

This document defines how the team collaborates on the Godot project without losing work, breaking resource references, creating unmergeable scenes, or allowing `main` to become unplayable. It is operational policy, not optional advice.

---

## 1. Instruction precedence and activation

For Godot-related work, follow instructions in this order:

1. Platform safety, legal, organization, and repository-enforced controls.
2. Explicit instructions in the current user request.
3. The closest applicable nested `AGENTS.md`.
4. The root `AGENTS.md`.
5. This document.
6. Existing project conventions and task-specific documentation.

This document MUST be read completely before an agent:

- creates or edits `project.godot`;
- creates or edits any `.gd`, `.tscn`, `.tres`, `.res`, `.godot`, `.uid`, import, asset, localization, audio, animation, shader, tile, test, or export-related file;
- reorganizes the Godot directory tree;
- changes input actions, autoloads, project settings, rendering, physics, display, or export configuration;
- resolves a Godot merge conflict;
- imports, moves, renames, replaces, or deletes a Godot resource;
- diagnoses a Godot parser, load, import, scene, resource, runtime, or export failure.

If the Godot project has not yet been created, this policy applies to its creation.

---

## 2. Locked project defaults

Until a reviewed decision changes them, use:

```yaml
engine_family: Godot 4.x
engine_version_policy: exact patch version shared by all contributors
language: GDScript
renderer: Compatibility
primary_targets:
  - Web
  - Desktop
resource_format: text where available
default_branch: main
merge_method: squash
development_model: short-lived feature branches
main_must_remain_playable: true
```

Before the first implementation PR, record the exact engine version in both `README.md` and the project onboarding section. All contributors MUST use that version. An agent MUST NOT upgrade or downgrade Godot, change renderer, or rewrite imported resources with a different engine version unless the user explicitly requests a version change and the change has a compatibility and rollback plan.

If the exact version is not recorded:

1. Inspect `project.godot`, recent commits, and CI/export configuration.
2. Infer the version only when evidence is strong.
3. Otherwise ask the project owner to select one stable Godot 4.x patch version.
4. Do not silently open and resave the whole project using an arbitrary version.

---

## 3. Non-negotiable collaboration principles

1. `main` MUST always open successfully and run the agreed smoke-test flow.
2. One task has one primary owner, one task branch, and one integration PR.
3. One shared scene or shared project-setting area has one active editor at a time.
4. Contributors MUST divide work by scene, script, data resource, or asset directory—not by simultaneously editing one large scene.
5. The main scene is composition-only. Domain logic, organ behavior, UI modules, effects, and content belong in separate files.
6. Godot-generated cache files MUST NOT enter Git.
7. Source assets, text scenes, scripts, resources, `.uid` files, and intentional import metadata MUST be preserved according to this policy.
8. Resource moves and renames MUST be performed carefully and verified in Godot because paths and UIDs are project contracts.
9. A merge is not complete until the combined project is imported, parsed, launched, and smoke-tested.
10. No agent may discard another contributor's work to make a conflict disappear.

---

## 4. Mandatory start-of-session protocol

Before planning or editing a Godot task, the agent MUST:

1. Read the root `AGENTS.md` and this document completely.
2. Identify the repository root and locate `project.godot`.
3. Inspect the current branch, remotes, Git status, staged diff, unstaged diff, and untracked files.
4. Confirm the exact Godot version expected by the repository.
5. Inspect the relevant Issue/PR, acceptance criteria, nearby scenes/scripts/resources, and recent related commits.
6. Identify every file likely to be edited.
7. Classify each target as:
   - exclusive shared file;
   - module-owned file;
   - binary asset;
   - generated/cache file;
   - configuration/export file.
8. Check whether another active task, branch, PR, or ownership notice covers the same files or behavior.
9. State a concise implementation contract:
   - goal;
   - in-scope behavior;
   - non-goals;
   - target files/modules;
   - public signals/methods/data contracts affected;
   - validation plan;
   - conflict risk.
10. Stop before editing if two contributors are actively changing the same exclusive file and no integrator has been designated.

An agent MUST NOT assume a clean worktree, an unused scene, or an available file merely because no conflict is visible locally.

---

## 5. Repository layout

Unless an established project structure already provides a stronger convention, use:

```text
/
├── AGENTS.md
├── GODOT_COLLABORATION.md
├── README.md
├── project.godot
├── addons/
├── assets/
│   ├── audio/
│   ├── fonts/
│   ├── icons/
│   ├── sprites/
│   ├── tiles/
│   └── source/
├── autoload/
├── data/
│   ├── balance/
│   ├── content/
│   └── schemas/
├── scenes/
│   ├── main/
│   ├── organs/
│   ├── routes/
│   ├── ui/
│   ├── effects/
│   └── tests/
├── scripts/
│   ├── simulation/
│   ├── interaction/
│   ├── persistence/
│   └── utilities/
├── tests/
├── docs/
└── builds/
```

Rules:

- `builds/` is ignored unless the repository intentionally versions release artifacts.
- Original editable art files such as `.aseprite`, `.psd`, or large audio project files belong in `assets/source/` only if the team decides to version them.
- Runtime-ready assets belong in the relevant runtime asset directories.
- Do not duplicate the same source of truth across multiple directories.
- Do not create catch-all directories such as `misc/`, `new/`, `temp/`, or `final_final/`.
- Directory and file names use lowercase `snake_case` unless a documented existing convention differs.
- Paths MUST avoid spaces, inconsistent capitalization, and names differing only by letter case.

---

## 6. Scene architecture and ownership

### 6.1 Scene boundaries

Create a separate scene when a component:

- has independent behavior;
- is reused;
- has its own animation or interaction;
- can be tested independently;
- is owned by a different contributor;
- would otherwise cause repeated edits to a shared parent scene.

For Metabolis, expected boundaries include:

```text
scenes/main/main.tscn
scenes/organs/placenta.tscn
scenes/organs/heart.tscn
scenes/organs/lungs.tscn
scenes/organs/body_district.tscn
scenes/routes/vessel_route.tscn
scenes/ui/resource_bar.tscn
scenes/ui/organ_panel.tscn
scenes/ui/tutorial_panel.tscn
scenes/effects/resource_flow.tscn
```

The main scene SHOULD instantiate these scenes. It SHOULD NOT contain the complete internal node trees of every module.

### 6.2 Exclusive shared files

Treat these as exclusive by default:

- `project.godot`;
- the configured main scene;
- global input actions;
- autoload registration;
- shared theme resources;
- shared tile sets;
- export presets;
- central save schema;
- central event bus or game-state interface.

Only the assigned owner or designated integrator may modify an exclusive file during an active task window. Other contributors propose changes through a small patch, Issue, or explicit handoff.

### 6.3 Scene reservation

Before editing a shared `.tscn`, `.tres`, tile set, theme, animation library, or project setting, the contributor MUST announce:

```text
RESERVE
Owner: <name>
Task/Issue: <id or short description>
Files: <exact paths>
Contract affected: <signals/methods/data>
Expected release time: <time>
```

When work is pushed or handed off:

```text
RELEASE
Owner: <name>
Branch/PR: <branch or link>
Files changed: <exact paths>
Validation: <checks performed>
Follow-up: <remaining concern or none>
```

If the team does not maintain a live reservation channel, use the Issue or Draft PR as the reservation record.

### 6.4 Editing restrictions

- Do not reorder unrelated nodes or properties in a scene.
- Do not rename nodes used by scripts, animations, or `NodePath` references without updating and testing all consumers.
- Do not make cosmetic Inspector changes in a scene owned by another task.
- Do not use “editable children” on an instanced scene as a substitute for a clear component API unless the customization is intentionally local and documented.
- Prefer exported properties, configuration resources, signals, and explicit methods over deep edits to instantiated children.
- Avoid brittle paths such as `../../../../SomeNode`.
- Do not place unrelated game logic in `main.gd`.

---

## 7. File ownership matrix

The team SHOULD maintain this table in the active project documentation:

| Area | Primary owner | Backup/integrator | Exclusive files | Active branch/PR |
|---|---|---|---|---|
| Main composition | Unassigned | Unassigned | `scenes/main/main.tscn` | None |
| Simulation/state | Unassigned | Unassigned | game-state contract | None |
| UI/tutorial | Unassigned | Unassigned | shared UI theme | None |
| Art/animation | Unassigned | Unassigned | tile set/animation library | None |
| Audio/effects | Unassigned | Unassigned | audio buses | None |
| Persistence/export | Unassigned | Unassigned | save schema/export presets | None |

An AI agent MUST NOT invent human ownership. If ownership is unrecorded, it may perform an explicitly requested isolated task, but it must identify exclusive files and ask for coordination before broad shared-file changes.

Ownership means responsibility for integration and review; it does not grant permission to bypass PR review or overwrite others.

---

## 8. Git workflow for Godot work

### 8.1 Branches

Use short-lived branches:

```text
feat/<issue>-<system>
fix/<issue>-<problem>
docs/<issue>-<topic>
refactor/<issue>-<scope>
test/<issue>-<scope>
spike/<issue>-<question>
```

Examples:

```text
feat/12-birth-state-machine
feat/18-resource-bar
fix/23-lung-activation
docs/7-godot-onboarding
```

Never work directly on `main`. Never share a feature branch unless an integrator and push protocol are explicitly agreed.

### 8.2 Before work

1. Fetch remote state.
2. Inspect existing branches and PRs for overlap.
3. Start from the current approved `main`.
4. Create one branch for one coherent outcome.
5. Open a Draft PR early when work spans multiple scenes, lasts more than half a day, or establishes a shared contract.

### 8.3 Commits

Commit small, coherent, runnable steps. Use:

```text
<type>(<scope>): <imperative summary>
```

Examples:

```text
feat(simulation): add fetal oxygen supply state
feat(ui): display resource flow warnings
fix(birth): prevent placenta supply after transition
test(smoke): cover birth without active lungs
docs(godot): record scene ownership protocol
```

Do not commit with messages such as `update`, `stuff`, `final`, `changes`, or `fix`.

Before each commit:

1. Save intended Godot files.
2. Close any scene that may still contain unsaved editor state.
3. Review `git status`.
4. Review the full diff.
5. Confirm no cache, build, secret, unrelated asset, or accidental scene rewrite is included.
6. Stage explicit paths.
7. Run the narrowest relevant validation.

### 8.4 Pull requests

Every behavior-changing Godot PR MUST include:

- purpose and linked Issue;
- player-visible result;
- exact scenes/scripts/resources changed;
- public signals, methods, resource schemas, input actions, or save fields changed;
- screenshots or short recording for visual changes;
- exact Godot version used;
- automated checks;
- manual smoke-test steps and results;
- known limitations;
- conflict-sensitive files;
- rollback/revert path.

The author or AI that produced the change cannot count as the independent human reviewer.

---

## 9. Version-controlled and ignored Godot files

### 9.1 Commit

Commit intentional source files, including:

- `project.godot`;
- `.gd`;
- `.tscn`;
- `.tres`;
- required `.uid` files;
- shaders;
- source PNG/SVG/audio/font files used by the project;
- localization source files;
- intentional import sidecar files when generated and required by the project;
- test files;
- documentation;
- export configuration that contains no secrets.

### 9.2 Ignore

At minimum for Godot 4.1+:

```gitignore
.godot/
*.translation
builds/
```

Also ignore OS/editor-local files, temporary recordings, local logs, crash dumps, and machine-specific export output.

Do not blindly copy ignore rules from Godot 3.x or another engine version. Validate them against the locked Godot version.

### 9.3 Resource formats

- Prefer text `.tscn` and `.tres` for mergeability.
- Avoid binary `.scn` and `.res` unless a feature requires them and ownership/backup is explicit.
- Do not manually edit internal resource IDs or UIDs merely to make a diff look smaller.
- Do not delete `.uid` files without proving they are obsolete and verifying all references.
- Do not commit `.godot/` to “fix” another contributor's import problem.

---

## 10. Asset and import workflow

Every runtime asset needs:

- a stable lowercase path;
- a clear source/author;
- license and attribution when external;
- intended native dimensions/sample rate;
- import settings appropriate to pixel art or audio;
- an owner;
- verification in the running project.

For pixel art:

- disable filtering where required by the art direction;
- use lossless settings appropriate for crisp sprites;
- use integer scaling and consistent native resolution;
- do not resize source sprites destructively in the Godot editor;
- verify atlas/frame boundaries and transparent padding;
- keep naming stable after animation integration.

For audio:

- choose `.ogg` or `.wav` intentionally;
- normalize responsibly without clipping;
- separate music, ambience, UI, and effects through audio buses;
- do not commit large raw recordings unless the project explicitly versions them;
- log license and attribution.

For binary assets:

- only one contributor edits a given file at a time;
- binary conflicts are resolved by selecting an authoritative version and reapplying the other work manually;
- Git LFS is introduced only through an explicit repository decision after evaluating storage, bandwidth, collaborator setup, and CI support.

When moving or renaming an asset:

1. Confirm no overlapping branch is modifying it.
2. Move it through the Godot FileSystem dock when practical.
3. Update all references.
4. Allow import to complete.
5. Search for the old path.
6. Open every affected scene.
7. Run the relevant flow.
8. Review the Git diff for unintended delete/add explosions.

---

## 11. GDScript standards

Use typed GDScript for public contracts and state-bearing logic.

Preferred order:

```gdscript
class_name Example
extends Node

signal state_changed(previous_state: int, current_state: int)

enum State { INACTIVE, ACTIVE, FAILED }

const MAX_OXYGEN: float = 100.0

@export var supply_rate: float = 5.0

var current_state: State = State.INACTIVE

@onready var status_label: Label = %StatusLabel

func _ready() -> void:
    pass

func activate() -> void:
    pass

func _update_display() -> void:
    pass
```

Rules:

- Use `snake_case` for files, variables, signals, and functions.
- Use `PascalCase` for classes and enums.
- Add return types and parameter types to public methods.
- Keep functions focused; extract domain calculations from UI scripts.
- Prefer explicit state transitions over loosely related booleans.
- Use constants or data resources for balance values; do not scatter magic numbers.
- Do not use `get_tree().root` searches or global node lookups as ordinary dependency injection.
- Do not call private methods across module boundaries.
- Do not suppress errors with empty `if`, silent `pass`, or broad fallback behavior.
- Errors and warnings must identify the failing resource or state without exposing secrets.
- Comments explain why or a biological/gameplay simplification, not what obvious syntax does.
- Every simplified biological rule SHOULD state its gameplay purpose and scientific limitation in nearby documentation or data notes.

---

## 12. Contracts between modules

Agree on contracts before parallel implementation.

Preferred communication:

1. Direct typed method call when one component clearly owns another.
2. Signal when a component announces an event.
3. Shared typed data/resource when multiple systems read configuration.
4. Minimal autoload service for genuinely global lifecycle/state.

Avoid:

- hard-coded deep scene paths;
- UI directly changing simulation variables;
- simulation scripts searching for UI nodes;
- circular signal dependencies;
- a global event bus containing every event;
- one autoload that becomes the entire game.

For every shared signal, record:

```text
Signal:
Emitter:
Payload types:
Meaning:
Allowed listeners:
Emission timing:
Whether repeated emissions are possible:
```

For every shared method, record:

```text
Method:
Owner:
Inputs:
Return:
Preconditions:
Side effects:
Failure behavior:
```

Changing a shared contract requires updating all consumers and tests in the same PR, or an explicitly staged backward-compatible migration.

---

## 13. Game state and biological simulation

The simulation owns truth. UI and animation visualize state but do not define it.

Expected high-level phases:

```text
SETUP
FETAL_SUPPORT
SYSTEM_TEST
BIRTH_TRANSITION
POST_BIRTH
COMPLETE
```

State transitions MUST:

- have one explicit owner;
- validate preconditions;
- be idempotent where repeated input is possible;
- emit a clear event;
- update saveable state consistently;
- provide player feedback;
- have failure and recovery behavior;
- be testable without final art or audio.

Do not model physiology beyond the accepted educational scope. Prefer a small deterministic causal model over a complex simulation that cannot be explained or tested.

Balance values SHOULD live in typed custom Resources or clearly structured data, not inside UI scenes.

---

## 14. Save data

Save data is a versioned public contract.

Minimum envelope:

```json
{
  "schema_version": 1,
  "game_version": "0.1.0",
  "phase": "FETAL_SUPPORT",
  "resources": {},
  "modules": {},
  "routes": {},
  "settings": {}
}
```

Rules:

- Never serialize live Node references.
- Save stable IDs and plain values.
- Validate types, ranges, missing fields, and unknown fields on load.
- Handle absent, empty, truncated, corrupt, and older-version saves.
- Write atomically where practical.
- Do not overwrite the only valid save until the new data is successfully encoded.
- Provide a safe reset path.
- A schema change requires migration or an explicit compatibility-breaking decision.
- Tests must cover save, reload, corrupt data, missing data, and at least one older schema once migrations exist.

---

## 15. Project settings, input, autoloads, and export

Changes to `project.godot`, input actions, autoloads, audio buses, display, physics, rendering, or export presets are exclusive shared changes.

Before changing them:

1. Identify every affected contributor and branch.
2. Record the intended setting and reason.
3. Make the smallest change.
4. Review the text diff.
5. Open and run the project using the locked engine version.
6. Verify Web and Desktop implications where relevant.

Input actions:

- use semantic names such as `confirm`, `cancel`, `select_module`, and `open_status`;
- do not bind gameplay logic directly to raw key codes when an input action is appropriate;
- preserve keyboard accessibility;
- document required mouse-only behavior and provide alternatives when feasible.

Autoloads:

- must have a narrow purpose;
- must not depend on a particular active scene unless documented;
- must be safe during tests and scene-by-scene execution;
- must not silently retain stale state between test runs.

Export presets:

- must not contain credentials, signing keys, tokens, or machine-specific secret paths;
- must be tested from a clean checkout before final release;
- must include required non-resource files such as JSON/CSV when the game loads them at runtime.

---

## 16. UI, animation, accessibility, and feedback

UI code consumes simulation state through public contracts. It MUST NOT directly mutate internal simulation fields.

Every important state must remain understandable without relying only on color. Use combinations of:

- icon shape;
- text;
- route pattern;
- animation speed;
- outline or fill;
- audio;
- spatial direction.

Visual PRs require screenshots or a recording at the intended viewport size. Verify:

- no clipping or overlap;
- readable text;
- stable anchors and containers;
- correct pixel scaling;
- keyboard focus where applicable;
- healthy, warning, and critical states;
- behavior with animation or audio disabled;
- understandable resource direction.

Animation events MUST NOT be the sole authority for a critical state transition unless the architecture explicitly requires and tests that timing. The simulation should complete reliably even when a cosmetic animation is skipped.

---

## 17. Testing and validation

### 17.1 Validation layers

Use the narrowest applicable check first, then broaden:

1. Static review of the changed diff.
2. Godot import and parser check.
3. Unit or scene-level test.
4. Run the changed scene.
5. Run the main scene.
6. Execute the complete smoke flow.
7. Export and run the target build when export behavior changed.

Use the repository's documented Godot binary/command. Typical headless checks, when supported by the locked version, are:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --quit
```

Do not claim these commands passed unless they were actually run. If no Godot binary is available, report that limitation and provide exact manual validation steps.

### 17.2 Mandatory Metabolis smoke flow

Once implemented, the core smoke test is:

1. Project opens with no missing-resource or parser errors.
2. Main scene launches.
3. Initial fetal-support state appears.
4. Placenta supply is visible.
5. Heart can be activated or built.
6. A route can connect supply, pump, and body demand.
7. System test gives understandable success or failure feedback.
8. Birth transition disables maternal supply.
9. Lungs become the oxygen source.
10. Missing or late lung activation produces a recoverable warning state.
11. Post-birth choice changes an intended value and visible feedback.
12. Save and reload reproduce the accepted state, once persistence exists.
13. Restart/reset returns to a valid initial state.

Test at least:

- normal flow;
- action attempted in the wrong phase;
- missing connection;
- insufficient supply;
- repeated activation input;
- repeated birth input;
- load with no save;
- corrupt save, once persistence exists;
- missing optional art/audio.

### 17.3 Definition of validated

“Runs on my machine” is insufficient. A Godot change is validated only when:

- the exact engine version is known;
- imports completed;
- no new parser/load errors appear;
- the affected scene works;
- the main scene still works;
- the relevant smoke cases pass;
- the diff contains no accidental editor rewrite;
- another contributor can reproduce the result from the branch or PR.

---

## 18. Conflict prevention and resolution

### 18.1 Prevention

- Reserve shared scenes and settings.
- Keep modules in separate scenes.
- Integrate at least twice per development day.
- Pull/fetch before starting and before handoff.
- Use small PRs and commits.
- Avoid broad resource renames during active parallel development.
- Establish signals and data contracts before implementing both sides.

### 18.2 GDScript conflicts

1. Understand both implementations.
2. Preserve intended behavior from both sides.
3. Reconcile public contracts deliberately.
4. Run parser, targeted, and smoke tests.
5. Ask the original owner when intent is uncertain.

### 18.3 Scene/resource conflicts

Never resolve `.tscn` or `.tres` conflicts by blindly choosing “ours”, “theirs”, or “both”.

Preferred procedure:

1. Identify the authoritative base scene.
2. Compare node, resource, connection, and property changes.
3. Select one structurally valid base.
4. Reapply the smaller independent change through the Godot editor.
5. Open the scene and inspect missing references.
6. Run the scene.
7. Run the main smoke flow.
8. Review the final text diff.

If both changes are large, stop and assign one integrator. Do not improvise a text merge without understanding Godot's serialized structure.

### 18.4 Binary conflicts

Binary files cannot be meaningfully line-merged. Select the authoritative source, preserve the rejected version outside the target path if recovery is needed, and manually recreate or export the missing work. Record the decision in the PR.

### 18.5 Broken imports or references

Do not commit `.godot/` or regenerate unrelated resources as a first response.

Instead:

1. Confirm correct branch and engine version.
2. Confirm source file exists with exact case.
3. Inspect moved/renamed paths and `.uid` files.
4. Reimport locally.
5. Search for stale paths.
6. Open affected scenes.
7. Commit only intentional source/import metadata changes.

---

## 19. Daily team cadence

For a one-week project:

### Start of day

- synchronize `main`;
- confirm build status;
- assign file/scene ownership;
- record reservations;
- identify the day's integration points;
- restate the core playable outcome.

### Midday integration

- merge completed small PRs;
- import with the locked Godot version;
- run the main scene;
- execute the affected smoke steps;
- resolve contract mismatch before more parallel work.

### End-of-day integration

- freeze optional changes;
- merge only reviewed, testable work;
- run the complete available smoke flow;
- export a checkpoint when practical;
- tag or record the last known good commit;
- release file reservations;
- document blockers and the next day's first action.

Do not allow four long-lived branches to diverge for multiple days.

---

## 20. AI-specific operating rules

An AI agent working on this project MUST:

- read both policy files before Godot action;
- inspect before editing;
- state the target files and validation plan;
- preserve unrelated human and agent work;
- prefer isolated modules over shared-scene edits;
- use existing Godot patterns when present;
- make the smallest coherent change;
- validate using the locked engine version when available;
- report exact checks and limitations;
- disclose any project file, shared contract, resource path, UID, input, autoload, save schema, or export change;
- leave a clear handoff for the next human or AI.

An AI agent MUST NOT:

- create or switch engine versions silently;
- open and resave many scenes only to normalize formatting;
- edit `project.godot` casually;
- modify a reserved scene;
- invent ownership or claim coordination occurred;
- add plugins, addons, dependencies, or Git LFS without explicit review;
- move or rename assets as incidental cleanup;
- delete `.uid` files to resolve warnings;
- commit `.godot/`, builds, logs, or machine-local files;
- place all logic in one autoload or main scene;
- weaken tests or remove warnings to report success;
- fabricate Godot execution, visual inspection, export, or multiplayer/collaboration evidence;
- commit, push, open a PR, merge, or release beyond the authorization level in root `AGENTS.md`.

If an agent cannot run Godot, it may still implement a narrowly reviewable change, but the handoff must say:

```text
Godot runtime validation: NOT RUN
Reason:
Static checks performed:
Manual validation required:
Risk:
```

---

## 21. Definition of Done for Godot changes

A Godot task is complete only when all applicable conditions hold:

- accepted behavior is implemented;
- files stay within agreed ownership and scope;
- relevant scenes and scripts are modular;
- shared contracts are documented and all consumers updated;
- resource paths and UIDs are intact;
- imports and parsing succeed;
- changed scenes run;
- the main scene and relevant smoke flow pass;
- save compatibility is handled when applicable;
- visual changes have evidence;
- export changes are tested on the target;
- no generated cache, secret, unrelated rewrite, or debug artifact is included;
- documentation and onboarding are updated;
- the PR explains risk, tests, conflict-sensitive files, and rollback;
- a human reviewer can reproduce the result.

If any required check cannot be completed, the task is not silently “done”; it is handed off with the exact missing validation and risk.

---

## 22. Required handoff format

Every AI or human implementation handoff SHOULD use:

```markdown
## Outcome
What now works from the player's perspective.

## Scope
- Changed:
- Intentionally unchanged:

## Godot files
- Scenes:
- Scripts:
- Resources/assets:
- Project/input/autoload/export settings:

## Contracts
- Signals/methods/data/save fields added or changed:

## Validation
- Godot version:
- Import/parser:
- Scene tests:
- Main smoke flow:
- Export:
- Visual evidence:

## Collaboration
- Branch/PR:
- Reserved files released:
- Conflict-sensitive files:

## Remaining risk
- Known limitations:
- Manual follow-up:
```

---

## 23. Initial setup checklist

Before the first gameplay implementation begins:

- [ ] Select and record one exact stable Godot 4.x patch version.
- [ ] Confirm Compatibility renderer and target platforms.
- [ ] Generate Godot Git metadata.
- [ ] Verify `.godot/` and build outputs are ignored.
- [ ] Create the modular directory structure.
- [ ] Create a minimal main scene.
- [ ] Create separate placeholder organ, route, UI, and effect scenes.
- [ ] Establish the game-state contract and phase enum.
- [ ] Record file ownership and backup integrators.
- [ ] Confirm every team member can clone, import, run, commit, push, and open a PR.
- [ ] Complete one practice PR per contributor.
- [ ] Run the first clean-checkout smoke test.
- [ ] Record the last known good commit.

No large feature should begin until all contributors can complete the collaboration loop successfully.

---

## 24. Policy maintenance

- Change this document through a dedicated reviewed PR.
- Godot-specific nested `AGENTS.md` files may tighten rules for their subtrees but may not weaken root safety, authorization, review, or this protocol's conflict protections.
- When the same collaboration failure occurs twice, add the smallest enforceable rule or automated check that prevents recurrence.
- Prefer automated enforcement—Git ignore rules, CI import checks, tests, PR templates, ownership checks—over relying only on memory.
- Review this protocol after the first playable vertical slice and before final release.
