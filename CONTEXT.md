# lead track

A personal effort-tracking app, shipped under the display name **LeadStone**
("lead track" is the internal project and bundle name). The core hierarchy is
Metric → Project → Session; an Aspiration is a lens layered above it. This
glossary pins the terms that are specific to the domain.

## Language

**Metric**:
A tracked thing — either duration (timer-based) or count (with a unit like
"pages"). Owns its projects and sessions, plus goals, reminders, icon, color.

**Health-linked metric**:
A metric whose sessions are filled from Apple Health instead of recorded by
hand: one mirrored value-session per day for the chosen source (active
calories, exercise minutes, stand minutes, workout count, workout time).
Read-only on every surface — no timers, manual logging, projects, watch
actions, or imports. Created only by explicit choice, and Health read access
is requested at that moment, never up front.
_Avoid_: health measurement type (it is a link on a metric, not a fourth
measurement type).

**Project**:
An optional sub-grouping inside a single metric (e.g. Reading → "War and
Peace"). Owns its own sessions; has a status and dates.
_Avoid_: sub-metric, category.

**Session**:
One recording — a timer run (duration) or a logged value (count). The unit of
data every total is computed from.
_Avoid_: entry, record, log (as nouns).

**Goal**:
A daily or weekly *target* on a metric, with pace and streak. Time-bound and
completable.
_Avoid_: using "goal" for an Aspiration — they are opposites (target vs
target-free).

**Goal season**:
The lifespan a goal is created for — N weeks, then a deliberate renew /
adjust / retire decision at the Weekly Review. A lapsed season changes
nothing: the goal keeps working and wears a quiet "past season" tag.
Retiring a target is a first-class positive act; tracking continues.
_Avoid_: deadline, expiry (the goal never stops by itself).

**Aspiration**:
An ongoing, never-"done" theme you pour effort into over a lifetime, with no
target and no deadline. A lens that aggregates the effort of the metrics and
projects attached to it; it owns no sessions and never moves data.
_Avoid_: goal, theme, area, category.

**Attachment**:
The many-to-many link from an aspiration to a metric or a project. Fluid —
added or removed at any time, non-destructively. An attached *metric* pulls in
all its sessions (including its projects'); an attached *project* pulls in only
its own.
_Avoid_: membership (use only informally), assignment.

**Rollup**:
The live, recomputed aggregate of an aspiration's effort across its current
attachments. Never stored as a running tally. Presented as a breakdown, not one
number, because units differ.
_Avoid_: total, summary (the rollup is many totals).

**Contribution**:
One attachment's share of a rollup. The per-attachment breakdown lists each
contribution with its own unit and total.

**Lifetime / Recent**:
The two figures every rollup total is shown as. Lifetime is the cumulative,
only-grows total; Recent is the trailing 30-day window showing current momentum.

**Principle**:
A short vow held under exactly one aspiration ("Pages before feeds.") — the
why distilled into a sentence that can be lived. Target-free and
deadline-free, with no machinery of its own: intentions name the principle
they serve, moments name the principle they live. Its only record is the
living underline — which of the trailing twelve weeks saw an intention
serving it actually advance — counting weeks of service, never outcomes.
_Avoid_: rule, habit, motto, goal (a principle carries no target).

**Intention**:
A small, week-scoped commitment under exactly one aspiration — the middle
timescale between the day and the lifetime. Born in a calendar week, closed
at the next Weekly Review, then history as narrative only: no completion
rate, streak, or cross-week aggregate is ever computed over outcomes. While
open, an intention may carry an optional **daily question** in the user's own
words, landing once per day at a random time inside a chosen window (e.g.
8am–8pm) — the app's only per-intention notification; tapping it opens the
owning aspiration. It may also hold concrete **scheduled actions** inside its
week and export them together as an `.ics` calendar file. These are calendar
blocks only: they have no completion state, overdue state, reminders, or
cross-week carryover.
_Avoid_: turning actions into tasks or todos; weekly goal.

**Alignment check-in**:
The weekly, always-skippable pulse on one aspiration — the app's only
subjective series. Asks "is this effort still serving the why?" on a
three-point scale (drifting / unsure / serving); never streaked, counted, or
nagged — absence is silence.
_Avoid_: rating the week, performance score.

**Moment**:
A kept piece of testimony under exactly one aspiration: evidence, in the
user's words (with optional photos and a place), that the becoming is
happening. It occurs at a user-set time distinct from when it was kept, may
point at the metric or project where it happened, and is witnessed, never
measured — no counts, totals, or streaks; an explicit project finish may offer
one optional reflection prompt, and only the explicit, user-triggered markdown
export includes moments (text, place label, provenance) and a range count.
_Avoid_: milestone, achievement, win, highlight, memory, journal entry.
