# What Goes In This Folder

Three files, produced during the Claude.ai ideation phase, imported here via
the `spec-ingest` skill (or manually dropped in):

## spec.md
What we're building and why. Goals, user stories, acceptance criteria written
as testable statements. Answers "what does done look like?"

## plan.md
Technical approach. Stack decisions, architecture, data flow, key libraries,
rationale for choices. Answers "how are we building it?"

## tasks.md
The ordered work list. Each task is small enough to finish in one context
window. Each task includes:
- A `- [ ]` checkbox (Ralph flips to `- [x]` when done)
- Acceptance criteria (what proves it works)
- A **verification command** (the exact shell command that returns non-zero
  if the task isn't actually done — e.g., `pnpm test path/to/test.spec.ts`)

The verification command is the backpressure. Without it, Ralph will declare
victory on incomplete work. With it, the loop converges.

---

**Do not commit this README to projects created from the template** — delete
it once the three real files are in place.
