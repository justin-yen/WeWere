# WeWere project instructions

Read `CLAUDE.md` for the shared project context and workflow instructions.

## Linear progress tracking

When working on Linear tickets, proactively update their status and progress in Linear to reflect the actual current state. Update when work starts, at meaningful milestones, when blocked, and before handing work back to the user. Do not wait for the user to request these updates.

Use the team's existing statuses. Include concise progress notes in the issue description covering implementation, validation evidence, and remaining work or blockers; preserve the original requirements. Distinguish local implementation, staging verification, and production rollout. Mark a ticket Done only when its acceptance criteria and required validation/rollout are complete. If Linear cannot be updated, tell the user what remains unsynchronized.

## Validation scope

Follow [the feature validation policy](docs/FEATURE_VALIDATION.md). Run the full simulator/core-journey walkthrough only for explicit end-to-end implementation-and-validation requests or requests to validate completed work. Do not apply it to every code change.

## Simulator isolation

Every task/thread that uses the iOS simulator must create and boot its own uniquely named simulator device before testing. Reuse that device only within the same task; never use another task's simulator or assume the currently booted/foreground simulator belongs to you.

Record the device name and UDID, pass its unique name to `scripts/run.sh --sim`, and use its explicit UDID for all `simctl` operations instead of `booted`. Before UI interactions, verify that the selected Simulator window belongs to that device. Separate staging/production app bundle IDs do not isolate simulator UI control. Do not shut down, reset, or delete another task's device.
