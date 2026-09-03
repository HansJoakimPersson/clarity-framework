# Change Management

## [Product name]

| | |
| --- | --- |
| **Version** | 0.1 |
| **Status** | Draft / Under review / Approved |
| **Date** | YYYY-MM-DD |
| **Author** | [Name] |

### Version history

| Version | Date | Change | Author |
| --- | --- | --- | --- |
| 0.1 | YYYY-MM-DD | Initial version | [Name] |

---

## Decision log

> Record a decision at the plan closeout that made it, not after the fact. Each entry is a single
> decision with the reasoning behind it — not a technical-debt compromise (§1) and not an ADR (which
> belongs in `docs/03-sad.md` §6); use this for the many smaller calls a build makes that are worth
> finding later but do not rise to architecture-decision weight.

### Decision record: [short topic]

| Field | Value |
| --- | --- |
| Date | YYYY-MM-DD |
| Status | Accepted / Superseded |
| Scope | [Component(s) or file(s) affected] |

[Prose: what was decided and why. State the alternative considered and rejected if there was one.]

---

## 1. Technical debt

> Document deliberate compromises. Visible technical debt is manageable. Always link to the ADR or
> story that motivated the compromise.

| ID | Description | Component | Reason | Impact | Planned action | Date added |
| --- | --- | --- | --- | --- | --- | --- |
| TD-001 | [Compromise or gap] | [Affected component] | [Why was it made?] | High / Medium / Low | [Sprint/version] | YYYY-MM-DD |
| TD-002 | | | | | | |

---

## 2. Superseded decisions

> An index of ADRs replaced by newer decisions. The ADRs themselves live in `docs/03-sad.md` §6 and
> are never deleted; this table is what keeps a supersession findable after the SAD is rewritten.

| ADR ID | Title | Superseded by | Date |
| --- | --- | --- | --- |
| ADR-001 | [Original decision] | ADR-[new] | YYYY-MM-DD |

---

## 3. Release history

> Link each version to its GitHub Release. Detailed release notes belong in the GitHub Release or
> `CHANGELOG.md`; this table records what reached production and the outcome.

| Version | Production date | Type | GitHub Release | Commit / artifact | Outcome | Summary |
| --- | --- | --- | --- | --- | --- | --- |
| v1.0.0 | YYYY-MM-DD | Major | [Link] | `[SHA / digest]` | Successful | Initial production release |
| v1.1.0 | YYYY-MM-DD | Minor | [Link] | `[SHA / digest]` | Successful | [New functionality] |
| v1.1.1 | YYYY-MM-DD | Patch | [Link] | `[SHA / digest]` | Rollback | [Bug fix and rollback reason] |

---

## 4. Incident log

> Short summaries of incidents. This table is the record; if an incident warrants a longer
> post-mortem, link to it here rather than assuming a location the framework does not define.

| Date | Severity | Description | Root cause | Resolved |
| --- | --- | --- | --- | --- |
| YYYY-MM-DD | P1 | [What happened?] | [Why?] | YYYY-MM-DD |

---

*Clarity Framework v3.4.0 – Change Management*
