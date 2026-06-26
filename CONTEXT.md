# lead track

A personal effort-tracking app. The core hierarchy is Metric → Project →
Session; an Aspiration is a lens layered above it. This glossary pins the terms
that are specific to the domain.

## Language

**Metric**:
A tracked thing — either duration (timer-based) or count (with a unit like
"pages"). Owns its projects and sessions, plus goals, reminders, icon, color.

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
