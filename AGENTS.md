# Repository Agent Operating Rules

> Version: 1.1  
> Applies to: every AI agent, automation, coding assistant, and subagent working in this repository  
> Default delivery target: a tested, documented, ready-for-human-review Pull Request—not an unreviewed merge or production deployment

This file is the repository's executable AI policy. Follow it for every task without requiring the user to repeat it. `GITHUB_TEAM_WORKFLOW.md` contains the longer human-readable rationale and governance details; this file contains the rules that must be in working context on every run.

---

## 0. Rule language and precedence

- **MUST / MUST NOT**: mandatory. Do not bypass without an explicit, recorded emergency exception.
- **SHOULD / SHOULD NOT**: default. Deviations require a concrete reason in the Issue or PR.
- **MAY**: optional when it improves the result without expanding risk or scope.

When instructions conflict, follow this order:

1. Platform safety, legal, organization, and repository-enforced controls.
2. Explicit instructions in the current user request.
3. The closest applicable nested `AGENTS.md` for files in its subtree.
4. This root `AGENTS.md`.
5. `GITHUB_TEAM_WORKFLOW.md` and other repository documentation.
6. Existing conventions inferred from code.

Never use a lower-priority instruction to weaken a higher-priority security or safety boundary. If a material conflict remains, stop the risky action, show the conflict, and ask for a decision.

---

## 1. Project context and immutable boundaries

This directory may be a local mirror of the ChatGPT project “final”.

- Treat every file under `sources/` as read-only reference material.
- MUST NOT edit, rename, move, delete, generate into, or reformat anything under `sources/`.
- Synced project files may be replaced on a future task. Store new deliverables outside `sources/`.
- Preserve all pre-existing user changes, untracked files, and unrelated work. A dirty worktree is not permission to clean it.
- MUST NOT use destructive Git or filesystem operations to remove work unless the user explicitly authorizes the exact targets after they are identified.
- Never expose secrets, credentials, personal data, customer data, private source content, or sensitive logs in prompts, commits, Issues, PRs, comments, screenshots, artifacts, or final responses.

If the task concerns repository administration, permissions, CI/CD, releases, security, incidents, or an ambiguous governance decision, read the relevant section of `GITHUB_TEAM_WORKFLOW.md` before acting.

---

## 2. Mission and default autonomy

Act as an implementation owner, not a code-completion tool. Given an authorized task, carry it from understanding through implementation, validation, self-review, and a clear handoff. Humans should not need to edit files manually.

Default endpoint by request type:

| User intent | Required endpoint |
|---|---|
| Explain, inspect, review, diagnose | Evidence-backed report; no writes unless separately requested |
| Plan or turn an idea into work | Well-formed Issue/specification and implementation plan; no implementation unless requested |
| Implement, build, fix, refactor | Complete local change with tests and documentation; report results |
| “完成到 PR”, “实现这个 Issue”, “直接做完并提交 PR” | Issue if needed → branch → implementation → tests → commits → push → ready PR; do not merge |
| Fix PR comments or CI | Update the existing PR branch, verify, push, and report; do not merge unless explicitly requested |
| Merge | Merge only after all required checks and independent human approvals pass; do not deploy unless separately requested |
| Deploy/release | Deploy only the explicitly named version/commit to the explicitly named environment after its gates pass |

An instruction to implement does **not** authorize merging, production deployment, permission changes, secret access, data mutation, deletion, billing changes, or external announcements.

Make reasonable, reversible assumptions when they preserve the stated outcome. Ask before proceeding only when a missing decision would materially change product behavior, security, data, cost, public API, or production state.

---

## 3. Authorization levels

### L0 — Read-only, always allowed for an in-scope task

- Inspect repository files, Git history/status/diffs, tests, and documentation.
- Read linked Issue/PR metadata and checks.
- Search official documentation when needed.
- Diagnose, review, plan, and report.

### L1 — Local implementation, allowed when the user asks for a change

- Edit in-scope files outside protected read-only paths.
- Add or update tests and documentation.
- Run safe builds, linters, tests, and local validation.
- Create a task branch if currently on a protected branch.

### L2 — GitHub delivery, allowed only when requested to complete to a PR or equivalent

- Create/clarify an Issue when no adequate Issue exists.
- Create a task branch, make intentional commits, push it, and open/update a Draft or ready PR.
- Add the required links, labels, evidence, and reviewers.
- Respond to review comments and push corrections.

### L3 — Sensitive repository changes, require explicit authorization

- Change Actions workflows, repository settings, Rulesets, CODEOWNERS, dependency policy, permissions, apps, webhooks, secrets, environments, release settings, or security controls.
- Create or publish a Release.
- Rotate or revoke credentials.

These actions require exact target restatement and a human review of the resulting change.

### L4 — Production or destructive operations, require explicit one-time authorization

- Merge using an administrator bypass.
- Deploy or roll back production.
- Run database migrations against shared/production data.
- Delete branches, tags, releases, environments, Issues, repositories, artifacts, or data outside normal post-merge branch cleanup.
- Rewrite shared history, force-push a shared branch, or remove material files.

Confirm exact target, environment, version, impact, recovery path, and required approvers immediately before acting. Never infer L4 authority from broad phrases such as “fix it” or “finish everything”.

---

## 4. Start-of-task protocol

Before editing, the agent MUST:

1. Read this file completely and read any closer nested `AGENTS.md` applying to target files.
2. Identify the repository root, current branch, remotes, worktree status, and relevant existing changes.
3. Read the relevant Issue/specification, README, nearby implementation, tests, and recent related history.
4. Search for an existing Issue, branch, or PR to avoid duplicate work when GitHub context is available.
5. Restate internally or in a concise update: goal, scope, non-goals, acceptance criteria, risk, and validation plan.
6. Determine whether the request authorizes only local changes or full delivery to a PR.
7. For complex work, create a short stepwise plan with one active step at a time. Skip ceremony for a trivial safe edit.

Before any Git operation, inspect status again. Do not assume the working tree is clean. If unrelated modifications overlap target files, preserve them and work around them; if safe separation is impossible, stop and explain the exact overlap.

---

## 5. Readiness, ambiguity, and task shaping

A task is ready for implementation when the following are discoverable from the request, Issue, or repository:

- The problem or user outcome.
- In-scope and out-of-scope behavior.
- Testable acceptance criteria.
- Important design, data, API, compatibility, security, and performance constraints.
- The target repository and, for release work, the target environment/version.

If the user provides a rough idea and asks to “vibecode it”:

1. Inspect the repository and infer safe defaults from existing patterns.
2. Convert the idea into a concise Issue/spec with acceptance criteria.
3. Ask only the smallest set of product questions whose answers materially change the result.
4. If the user authorized end-to-end delivery, continue to a PR once blocking questions are resolved.
5. Record assumptions in the Issue and PR; implementation must not silently redefine the request.

Split work when it has multiple independently valuable outcomes, spans unrelated systems, or cannot be reviewed coherently. Use one primary owner, one branch, and one PR per atomic outcome.

---

## 6. Risk classification and required gates

Classify every change:

- **Low**: documentation, copy, non-behavioral cleanup, isolated styling.
- **Medium**: ordinary features, bug fixes, internal APIs, routine dependency updates.
- **High**: authentication, authorization, billing, privacy, encryption, secrets, public APIs, data deletion/migration, infrastructure, CI/CD, deployment, production configuration, or broad dependency/supply-chain changes.
- **Emergency**: active severe outage, exploited vulnerability, or unacceptable ongoing data risk.

Minimum gates:

| Risk | Independent approval | Validation |
|---|---:|---|
| Low | 1 non-author human | Relevant basic checks |
| Medium | 1 non-author human | Unit/integration/build checks proportional to change |
| High | 2 humans, including relevant Code Owner | Explicit security, rollback, deployment, and regression evidence |
| Emergency | Fastest available knowledgeable human + recorded exception | Minimum safe regression test, immediate verification, later full review |

AI review and AI self-review are additional signals; they never count as the required human approval. If the team cannot satisfy a gate, report the blocker. Do not silently lower the risk level or bypass protection.

---

## 7. Standard delivery lifecycle

For a task authorized through PR delivery, follow this order:

1. **Issue**: use an existing Issue or create one with context, goal, scope/non-goals, acceptance criteria, risk, validation, dependencies, and rollback notes.
2. **Branch**: branch from the latest protected default branch.
3. **Implement**: make the smallest coherent change; include tests, docs, migration, observability, and recovery work required by the acceptance criteria.
4. **Validate continuously**: start with targeted checks, then broaden before handoff.
5. **Draft PR early** when work exceeds roughly half a day, crosses modules, needs preview/CI, or has design uncertainty.
6. **Self-review** the entire diff, not only the last edited file.
7. **Ready PR**: complete the PR description and evidence, resolve known failures/conflicts, then mark ready and request the right reviewers.
8. **Review loop**: address every blocking comment, re-run affected checks, and re-request review after material changes.
9. **Merge** only when separately authorized and every server-side gate passes.
10. **Release/deploy** only when separately authorized; verify and report the deployed immutable version.
11. **Close loop**: close/link the Issue, record deviations, and create separate follow-up Issues for out-of-scope work.

Do not continue coding when a newly discovered requirement invalidates the accepted scope. Update the Issue/spec first.

---

## 8. Git and branch rules

- The default branch is `main` unless the repository proves otherwise.
- MUST NOT commit or push directly to `main` or another protected branch.
- MUST NOT force-push, rebase, reset, or rewrite shared/protected history.
- Task branch format: `<type>/<issue-id>-<short-kebab-description>`.
- Allowed types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `spike`, `hotfix`.
- Start from the latest `main`; before final validation, synchronize with the target branch according to repository policy.
- Resolve conflicts by preserving both sides' intended behavior. Never choose one side blindly.
- Stage explicit files. Review both unstaged and staged diffs before committing.
- Do not commit caches, local `.env`, debug output, generated junk, unrelated formatting, large binaries, secrets, or personal/customer data.
- Commit messages SHOULD follow `<type>(<scope>): <imperative summary>` and explain why when the reason is not obvious.
- Use `Refs: #123` in intermediate commits when helpful. The PR MUST use `Closes #123` or the appropriate link.
- Default merge method is Squash Merge. The PR title must be suitable as the final commit title.
- Delete the task branch after a successful merge using the repository's normal automatic cleanup.

Safe task-branch history cleanup MAY use `--force-with-lease` only when the agent has confirmed the branch is not shared. Never use plain `--force`.

MUST NOT run destructive commands such as hard resets, broad cleans, recursive deletion, or checkout-based discarding of changes unless the user explicitly asks for the exact destructive result and targets have been verified.

---

## 9. Implementation quality rules

- Follow existing architecture, naming, formatting, dependency, and error-handling conventions unless the task explicitly changes them.
- Prefer the smallest complete solution. Do not add speculative abstractions, unrelated refactors, or new dependencies for convenience.
- Preserve backwards compatibility unless a breaking change is explicitly accepted and documented.
- Validate all trust boundaries: inputs, authentication, authorization, paths, commands, network data, file uploads, and serialized data.
- Design retries, webhooks, jobs, and mutations for idempotency where duplicates are possible.
- Handle success, empty, loading, error, denied, timeout, concurrency, and boundary states relevant to the feature.
- Avoid silent exception swallowing and misleading fallback behavior. Errors must be actionable without leaking sensitive data.
- Update public API/schema/types, migration, configuration examples, user docs, Runbooks, and observability in the same PR when behavior changes.
- UI changes must consider narrow screens, keyboard use, accessible names/focus, loading/empty/error states, and visual evidence.
- Data migrations must be deploy-order safe, observable, and recoverable. Prefer backwards-compatible expand/migrate/contract sequences.

Never “make tests pass” by weakening assertions, deleting coverage, hard-coding expected output, hiding errors, or skipping valid gates.

---

## 10. Testing and evidence

Discover actual commands from the repository; do not invent them. Use the narrowest relevant check first, then run the broader required suite before PR handoff.

As applicable, validate:

- Formatting, lint, types, compilation, and build.
- Unit tests for business rules and boundaries.
- Integration/contract tests for databases, queues, files, services, and APIs.
- E2E or smoke tests for critical user journeys.
- Dependency, secret, and code-security scans.
- Migration behavior, backward compatibility, rollback/recovery, and realistic data volume.
- UI behavior with screenshots or recordings when visual output changes.

Bug fixes SHOULD add a regression test that fails before the fix and passes afterward. If automation is impractical, document exact manual reproduction and verification.

Evidence rules:

- Report the exact checks actually run and their results.
- Never claim an unrun check passed.
- Report environment limitations, skipped tests, known flakes, and unrelated failures separately.
- Do not repeatedly rerun a failure until it happens to pass. Preserve evidence, investigate, and open/associate a flaky-test Issue when appropriate.
- If a required check cannot run, state why, the risk, the alternative evidence, and the human decision still required.

---

## 11. Pull Request contract

A PR MUST contain:

```markdown
## Purpose
Why this is needed. Closes #<issue>

## Changes
- User/system behavior changed
- Explicit non-goals

## Implementation notes
Key design choices, compatibility, migrations, and reviewer reading order.

## Verification
- Exact automated checks and results
- Manual scenarios and results
- Screenshots/recordings for UI changes

## Risk and rollback
Risk level, failure signals, disable/revert/recovery path.

## AI use
What AI produced, what was independently checked, and remaining uncertainty.
```

Before marking ready, the agent MUST confirm:

- Scope matches the Issue and all acceptance criteria have evidence.
- The entire diff was self-reviewed; no unrelated files, debug code, secrets, or accidental generated changes exist.
- Required tests, docs, migrations, monitoring, and rollback notes are present.
- Branch conflicts and known CI failures are resolved or transparently documented.
- Correct reviewers and Code Owners are requested.
- The PR is small enough to review. If large, explain why it cannot be split and give a reading order.

Draft PR means incomplete or seeking early feedback. Ready PR means the author believes it can merge once independent review and server-side checks pass.

---

## 12. Review rules

When reviewing, inspect in this order:

1. Intent and acceptance criteria.
2. Correctness, edge cases, concurrency, failure handling, and idempotency.
3. Security, privacy, authorization, secrets, and dependency risk.
4. Data migration, compatibility, API contracts, and rollback.
5. Test quality and evidence.
6. Maintainability, observability, documentation, and deployment safety.

Prefix actionable comments:

- `blocker:` correctness, security, data, or acceptance failure; must resolve.
- `major:` important design/test/maintenance risk; blocks by default.
- `minor:` worthwhile non-blocking improvement.
- `nit:` optional style detail.
- `question:` clarification needed; blocking status depends on answer.

Every blocking thread must close through a change, a sufficient evidence-based explanation, or an explicitly accepted follow-up Issue. Re-request review after material changes. Do not approve a revision that has not been read and understood.

---

## 13. GitHub tool usage

- Resolve the exact repository, Issue, PR, branch, and target before acting.
- Prefer the configured GitHub connector/app for structured repository, Issue, PR, comment, label, reviewer, and PR-creation operations.
- Use local Git for worktree/branch/commit operations.
- Use `gh` only for connector gaps such as current-branch PR discovery, push-adjacent operations, and GitHub Actions check/log inspection.
- Never claim Actions logs were inspected unless they were actually retrieved through an appropriate tool.
- Restate the exact external object before any sensitive GitHub write.
- If authentication or permissions are missing, finish safe local work, report the precise missing capability, and do not invent a successful push/PR.

Do not create duplicate Issues or PRs. Link all GitHub objects so the Issue is the task record, the PR is the change record, and the Release/deployment is the production record.

---

## 14. Security, secrets, Actions, and dependencies

### Secrets and data

- Secrets never enter Git. Commit only `.env.example` placeholders, never real values.
- Use environment/repository secret stores with the narrowest scope. Use variables only for non-sensitive configuration.
- Do not print secrets in logs or store them in artifacts/caches.
- Treat a committed secret as compromised even in a private repository: stop exposure, notify the security owner, rotate/revoke first, then remove from code and coordinate any history cleanup.
- Do not use real customer data for development or AI prompts. Use synthetic or properly anonymized fixtures.

### GitHub Actions

- Workflow token permissions default to read-only or `{}`; grant minimum permissions per job.
- Treat every third-party Action as a supply-chain dependency. Prefer trusted sources and pin immutable full commit SHAs for high-security workflows.
- Workflow changes require relevant Code Owner review.
- Never expose secrets to untrusted PR code. Treat `pull_request_target`, script interpolation, self-hosted runners, and downloaded artifacts as high risk.
- Prefer OIDC short-lived cloud credentials over long-lived cloud keys.
- Production jobs must use the protected production Environment and its approval/branch restrictions when available.

### Dependencies

- Add a dependency only when value exceeds maintenance, security, size, and license cost.
- Review direct and transitive risk, maintenance status, permissions, license, bundle/runtime impact, and lockfile changes.
- Dependabot or bot PRs still require relevant CI and human review; never blindly auto-merge high-risk updates.
- Do not suppress a vulnerability alert merely because remediation is inconvenient. Record owner, decision, mitigation, and deadline.

---

## 15. Merge, release, deployment, and rollback

- Merge only the reviewed commit set after required status checks, conversations, Code Owners, and human approvals pass.
- Never use admin bypass for ordinary delivery.
- Build once and promote the same immutable artifact/commit through environments.
- `staging` and `production` are deployment Environments, not long-lived development branches.
- Release tags are immutable and SHOULD use `vMAJOR.MINOR.PATCH` when semantic versioning fits the product.
- A Release must document user-visible changes, migrations/configuration, breaking changes, known issues, and rollback.
- Before production: identify version, owner, approval, migration order, health checks, observability, failure threshold, and recovery path.
- After deployment: verify health, critical journeys, errors/latency, background work, and data correctness; record version/time/result.
- On unacceptable failure, prefer a tested rollback, previous immutable artifact, or safe feature flag. Revert through Git; never rewrite `main`.
- Database recovery must follow an explicit migration/backup plan. Never assume a destructive migration can be reversed automatically.

“Merge” does not mean “deploy”. “Deploy to staging” does not mean “deploy to production”. Each transition needs explicit authorization.

---

## 16. Emergency changes

Emergency flow is only for an active severe outage, exploited vulnerability, or ongoing data risk:

1. Create/associate a P0/P1 incident record without exposing security secrets.
2. Identify Incident Commander, impact, production version, and immediate mitigation.
3. Branch from the production-aligned point and make the smallest safe fix.
4. Preserve PR review; obtain the fastest knowledgeable human approval available.
5. Record every bypass, skipped gate, approver, substitute validation, and recovery plan.
6. Deploy only with explicit production authority; verify immediately.
7. Within 24–72 hours, complete tests, normal review, documentation, root-cause analysis, and owned follow-up Issues.

Urgency alone is not an emergency exception.

---

## 17. Parallel agents and collaboration

- One Issue has one primary owner and one integration branch/PR.
- Agents may parallelize only independent, bounded work with explicit file/interface ownership.
- Two agents MUST NOT concurrently edit the same file or logic area without a designated integrator.
- Agree on public contracts before parallel implementation.
- Each editing agent uses an isolated branch/worktree. Shared working branches require explicit coordination and MUST NOT be force-pushed.
- The integrator owns conflict resolution, combined tests, final diff, and PR evidence.
- Agents must preserve work they did not create. Never reset, overwrite, or clean another agent's changes.
- Before spawning/delegating, confirm the subtask is independent and improves completion; do not delegate simple sequential work.

---

## 18. Communication and reporting

During work:

- Give short updates for long-running tasks: current outcome, important discovery, next action, and any non-blocking assumption.
- Lead with evidence when raising a concern. Do not ask the user to make decisions the repository can answer.
- Ask concise questions only for material choices; continue safe independent work when possible.
- Never hide failure, uncertainty, incomplete tests, permission limits, or scope changes.

Final handoff MUST state:

1. Outcome and user-visible behavior.
2. Files/components changed.
3. Validation run and exact results.
4. Issue/branch/PR/release links or identifiers when created.
5. Risks, assumptions, unverified items, and required human decision.
6. Whether the endpoint is local-only, Draft PR, ready PR, merged, staged, or production.

Do not overwhelm the user with raw command logs. Summarize what the evidence proves.

---

## 19. Definition of Done

A change is done only when all applicable conditions are met:

- Acceptance criteria are satisfied with visible evidence.
- The implementation is minimal, understandable, and self-reviewed.
- Relevant automated and manual validation passed, or limitations are explicitly accepted by a human.
- Tests, docs, schemas, configuration examples, migration, observability, Runbooks, and rollback are updated as required.
- No secrets, debug remnants, unrelated changes, unresolved blockers, or unexplained compatibility risks remain.
- For PR delivery: branch is pushed, PR is complete and ready, correct reviewers are requested, and CI state is reported.
- For merge: all independent approvals and server-side protections pass.
- For release/deployment: the exact immutable version is deployed and post-deploy verification passes.
- Out-of-scope follow-ups have linked Issues with owners or a clear triage state.

Near-complete is not complete. When blocked, finish every safe in-scope step and report the smallest exact unblock needed.

---

## 20. Absolute prohibitions

The agent MUST NOT:

- Direct-push to or rewrite protected branches.
- Fabricate a test, review, approval, log, screenshot, link, metric, deployment, or success claim.
- Weaken tests or security controls to obtain a green result.
- Commit, reveal, request unnecessarily, or transmit secrets/private data.
- Modify `sources/` or discard unrelated work.
- Merge its own change without required independent human approval.
- Deploy production, mutate production/shared data, change permissions, or perform destructive actions without exact explicit authority.
- Use administrator bypass as a convenience.
- Silently expand scope or introduce speculative dependencies/architecture.
- Resolve a conflict by discarding behavior it does not understand.
- Continue after evidence indicates the requested action targets the wrong repository, branch, environment, version, or data.

---

## 21. Repository defaults

Use these defaults unless repository settings or an explicit accepted decision are stricter:

```yaml
default_branch: main
branch_model: short-lived task branches
merge_method: squash
delete_branch_after_merge: true
issue_required: true
ordinary_human_approvals: 1
high_risk_human_approvals: 2
code_owner_required_for_high_risk: true
direct_push_to_main: forbidden
force_push_to_main: forbidden
ai_review_counts_as_human_approval: false
default_implementation_endpoint: ready_pull_request
production_deploy_requires_explicit_authority: true
sources_directory_mode: read_only
```

If these documented defaults differ from actual GitHub enforcement, report the gap and recommend the corresponding Ruleset/CI configuration. Documentation guides behavior; server-side protection enforces it.

---

## 22. Maintaining this policy

- Change this file only through a dedicated, reviewed PR unless the user is initially bootstrapping the repository.
- Changes to authorization, security, merge, release, or production rules require Maintainer and relevant Code Owner approval.
- Keep this root file practical and within the agent instruction-loading budget. Put detailed rationale, onboarding, examples, and governance in `GITHUB_TEAM_WORKFLOW.md`.
- Add nested `AGENTS.md` files only for real directory-specific commands or constraints. They may tighten local rules but must not weaken root safety boundaries.
- When the same agent mistake recurs, perform a short retrospective and propose the smallest precise rule or automated gate that prevents recurrence.
- Prefer mechanical enforcement—Rulesets, required checks, CODEOWNERS, Environment protection, secret scanning—over relying only on prose.

---

## 23. Mandatory Godot collaboration policy

For every task involving Godot project creation or modification, an agent MUST read `GODOT_COLLABORATION.md` completely before planning, editing, moving resources, resolving conflicts, validating, exporting, or publishing changes.

A task is Godot-related if it touches or proposes to touch any of the following:

- `project.godot`;
- `.gd`, `.tscn`, `.tres`, `.res`, `.uid`, shader, tile, theme, animation, localization, or import-related files;
- Godot assets, resource paths, project settings, input actions, autoloads, audio buses, save data, addons, tests, or export presets;
- engine version, renderer, target platform, scene architecture, or Godot repository layout.

`GODOT_COLLABORATION.md` is mandatory operational policy under this root file. It may tighten Godot-specific collaboration and validation rules but cannot weaken this file's safety, authorization, GitHub delivery, human-review, security, or destructive-action requirements.

If the Godot policy is missing, unreadable, or materially inconsistent with the actual project, stop before risky shared-file work, report the exact gap, and request or propose a dedicated policy repair.

