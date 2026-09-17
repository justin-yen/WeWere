# Feature validation policy

Run the full simulator walkthrough when the user asks to implement a feature end to end **and validate it**, or explicitly asks to validate completed work. Do not run the full walkthrough for every code change. For other changes, choose proportionate checks.

When this policy is triggered:
1. Build the current implementation, install it on a local iOS simulator, and launch it.
2. Click through the changed feature and the core journeys below. Unit tests and static screen renders are supporting evidence, not substitutes for interaction.
3. Test failure/retry, background/relaunch, and repeated taps where they threaten data or navigation.
4. Fix regressions caused by the change and rerun affected journeys. Identify unrelated pre-existing failures separately.
5. Report each journey as passed, failed, or blocked; distinguish simulated/stubbed API coverage from real service integration. Never claim camera hardware, remote uploads, OTP delivery, or photo-library saves were verified unless actually exercised.

Core journeys:
- Sign in → Home; relaunch restores session; an invite opened before sign-in survives authentication.
- Create → event → invitation sharing; immediate/future start; end time present/absent.
- Join by code/deep link → preview → membership → correct live/upcoming destination; invalid-code recovery; repeated join preserves membership and host role.
- Open the named event's camera → capture → return; multiple events never mix captures; denied permission has recovery.
- Photos stay hidden while live, including from hosts; upcoming events cannot capture; open-ended events have no countdown.
- Host ends event → capture closes → pending uploads remain safe → develop → shared album; guests cannot end events.
- Ready film / past event / memory → correct album → photo → back; saving photos and its permissions recover properly.
- Sign out → another account; no previous-account events, photos, or pending navigation remain.

Highest-priority invariants: never lose a saved capture, attach it to the wrong event, reveal it early, or expose another account's data.

Unresolved product decision: whether a joined attendee who captured no personal photos may develop and view the shared roll. Preserve current behavior until explicitly decided.
