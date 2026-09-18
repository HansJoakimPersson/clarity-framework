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

> Record a decision at the plan closeout that made it, not after the fact. Keep only decisions that
> still constrain current work in this hot document. When a decision is superseded and no longer
> informs active implementation, move its full record to `docs/archive/decisions/YYYY.md` and leave
> only a compact pointer if needed. This is not a technical-debt compromise (§1) and not an ADR
> (which belongs in `docs/03-sad.md` §6).

### Decision record: [short topic]

| Field | Value |
| --- | --- |
| Date | YYYY-MM-DD |
| Status | Accepted / Superseded |
| Scope | [Component(s) or file(s) affected] |

[Prose: what was decided and why. State the alternative considered and rejected if there was one.]

---

## 1. Technical debt

> Document unresolved deliberate compromises. Visible technical debt is manageable. When debt is
> resolved, move its closed record to `docs/archive/debt/YYYY.md` and keep the active table focused
> on debt that can still affect a decision. Always link to the ADR or story that motivated it.

| ID | Description | Component | Reason | Impact | Planned action | Date added |
| --- | --- | --- | --- | --- | --- | --- |
| TD-001 | [Compromise or gap] | [Affected component] | [Why was it made?] | High / Medium / Low | [Sprint/version] | YYYY-MM-DD |
| TD-002 | | | | | | |

---

## 2. Superseded decisions

> An index of ADRs replaced by newer decisions. Full superseded ADR bodies move to
> `docs/archive/adr/`; this compact index keeps their lineage findable without making obsolete
> reasoning part of normal architecture context.

| ADR ID | Title | Superseded by | Date |
| --- | --- | --- | --- |
| ADR-001 | [Original decision] | ADR-[new] | YYYY-MM-DD |

---

## 3. Release history

> Keep the current release window here and link each version to its GitHub Release. Detailed release
> notes belong in the GitHub Release or `CHANGELOG.md`. Move older closed release rows to
> `docs/archive/releases/YYYY.md`; this table is operationally useful state, not an append-only
> duplicate of Git history.

| Version | Production date | Type | GitHub Release | Commit / artifact | Outcome | Summary |
| --- | --- | --- | --- | --- | --- | --- |
| v1.0.0 | YYYY-MM-DD | Major | [Link] | `[SHA / digest]` | Successful | Initial production release |
| v1.1.0 | YYYY-MM-DD | Minor | [Link] | `[SHA / digest]` | Successful | [New functionality] |
| v1.1.1 | YYYY-MM-DD | Patch | [Link] | `[SHA / digest]` | Rollback | [Bug fix and rollback reason] |

---

## 4. Incident log

> Keep open/recent incident summaries here. Move closed historical incidents to
> `docs/archive/incidents/YYYY.md`; if one warrants a longer post-mortem, link to its archived
> record. Do not make every future run carry old incident detail.

| Date | Severity | Description | Root cause | Resolved |
| --- | --- | --- | --- | --- |
| YYYY-MM-DD | P1 | [What happened?] | [Why?] | YYYY-MM-DD |

---

*Clarity Framework v4.3.0 – Change Management*
