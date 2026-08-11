# Change Log & Technical Debt

## [Product name]

| | |
| --- | --- |
| **Version** | 0.1 |
| **Date** | YYYY-MM-DD |
| **Author** | [Name] |

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

> ADRs replaced by newer decisions. Never delete them; the history has value.

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

> Short summaries of incidents. Full post-mortems belong in `/docs/incidents/`.

| Date | Severity | Description | Root cause | Resolved |
| --- | --- | --- | --- | --- |
| YYYY-MM-DD | P1 | [What happened?] | [Why?] | YYYY-MM-DD |
