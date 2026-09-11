# User Stories

## [Product name]

| | |
| --- | --- |
| **Version** | 0.1 |
| **Status** | Active backlog |
| **Date** | YYYY-MM-DD |
| **Author** | [Name] |
| **Related to** | Requirements Documentation v[X.X] |

### Version history

| Version | Date | Change | Author |
| --- | --- | --- | --- |
| 0.1 | YYYY-MM-DD | Extracted from Requirements Documentation §2.6 | [Name] |

---

## How to use this document

This document holds story detail only. Adopt it when the backlog passes roughly 20 active stories,
or when more than one person maintains it — before that, keep the stories in
`docs/02-requirements.md` §2.6 and do not create this file.

Everything that defines *how* a story is written stays in the Requirements Documentation, because it
changes rarely while this backlog changes constantly:

| Lives in `docs/02-requirements.md` | Lives here |
| --- | --- |
| Roles (§2.1) | Story detail, grouped by epic |
| Story quality bar and splitting rules (§2.2) | Acceptance criteria |
| Story lifecycle and Definition of Ready (§2.3) | Per-story status and size |
| Story map and release slices (§2.4) | |
| Epic overview (§2.5) | |
| Priority overview and traceability (§4–5) | |

When this file is adopted, replace §2.6 of the Requirements Documentation with a pointer to it. Do
not maintain stories in both places. If the backlog grows past what one file can hold comfortably,
shard it into one file per epic under `docs/stories/` and keep the epic overview in
`docs/02-requirements.md` §2.5 as the index.

**Status values:** Draft · Ready · In progress · In review · Done · Dropped.
A Dropped story keeps its ID and its reason; IDs are never reused.

---

## Epic: [Epic name – e.g. “User management”]

**Outcome:** [What the role can do once this epic is complete]
**Primary role:** R1 – [Role name]

---

### FR-001 · [Short story title]

| | |
| --- | --- |
| **Epic** | [Epic name] |
| **Role** | R1 – [Role name] |
| **Priority** | M / S / C / W |
| **Status** | Draft / Ready / In progress / In review / Done / Dropped |
| **Size** | XS / S / M / L *(L must be split before it is Ready)* |
| **Related NFR** | NFR-[ID] *(if applicable)* |
| **Depends on** | FR-[ID] *(if applicable)* |

**Story:**
As R1 – [role]
I want [capability]
so that [business value].

**Acceptance criteria:**

```text
AC-001-1:
  Given [precondition]
  When [action/event]
  Then [expected outcome]

AC-001-2:
  Given [precondition]
  When [action/event]
  Then [expected outcome]
```

**Out of scope for this story:** *(optional; prevents the story from growing during implementation)*
[What a reader might reasonably assume is included but is not, and where it is handled instead]

**Technical notes:** *(optional implementation notes, not requirements)*
[Technical considerations relevant to the story]

---

### FR-002 · [Short story title]

| | |
| --- | --- |
| **Epic** | [Epic name] |
| **Role** | R1 – [Role name] |
| **Priority** | M / S / C / W |
| **Status** | Draft / Ready / In progress / In review / Done / Dropped |
| **Size** | XS / S / M / L |

**Story:**
As R1 – [role]
I want [capability]
so that [business value].

**Acceptance criteria:**

```text
AC-002-1:
  Given [precondition]
  When [action/event]
  Then [expected outcome]
```

---

## Epic: [Next epic name]

**Outcome:** [What the role can do once this epic is complete]
**Primary role:** R2 – [Role name]

---

### FR-010 · [Short story title]

| | |
| --- | --- |
| **Epic** | [Next epic name] |
| **Role** | R2 – [Role name] |
| **Priority** | M / S / C / W |
| **Status** | Draft / Ready / In progress / In review / Done / Dropped |
| **Size** | XS / S / M / L |

**Story:**
As R2 – [role]
I want [capability]
so that [business value].

**Acceptance criteria:**

```text
AC-010-1:
  Given [precondition]
  When [action/event]
  Then [expected outcome]
```

---

## Dropped stories

> Retired IDs stay listed so that historical plans, commits, and test cases keep resolving.

| ID | Title | Dropped on | Reason | Decided by |
| --- | --- | --- | --- | --- |
| FR-0XX | [Title] | YYYY-MM-DD | [Why it was descoped] | [Name] |

---

*Next step: Keep the story map, epic overview, and traceability table in `docs/02-requirements.md`
aligned with this backlog whenever a story is added, split, or dropped.*

*Clarity Framework v4.0.0 – User Stories*
