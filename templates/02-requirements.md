# Requirements Documentation

## [Product name]

| | |
| --- | --- |
| **Version** | 0.1 |
| **Status** | Draft / Active backlog |
| **Date** | YYYY-MM-DD |
| **Author** | [Name] |
| **Related to** | Vision & Scope v[X.X] |

### Versionshistorik

| Version | Date | Change | Author |
| --- | --- | --- | --- |
| 0.1 | YYYY-MM-DD | Initial version | [Name] |

---

## 1. Non-functional requirements (NFRs)

> Define NFRs **before** specifying functional requirements in detail; they shape the architecture.

### Performance

| ID | Requirement | Metric | Target | MoSCoW |
| --- | --- | --- | --- | --- |
| NFR-P01 | Response time for [main function] | 95th percentile response time | < [X] ms | M |
| NFR-P02 | The system must handle [X] concurrent users | Concurrent users under load test | [X] | S |

### Availability

| ID | Requirement | Metric | Target | MoSCoW |
| --- | --- | --- | --- | --- |
| NFR-A01 | Planned uptime | Uptime per month | [X]% | M |
| NFR-A02 | Maximum recovery time after failure | RTO | < [X] min | S |

### Scalability

| ID | Krav | MoSCoW |
| --- | --- | --- |
| NFR-S01 | The system must support [X]% data growth over [Y] years without redesign | C |

### Maintainability

| ID | Krav | MoSCoW |
| --- | --- | --- |
| NFR-M01 | All business logic must be unit-testable without external infrastructure | M |
| NFR-M02 | Application logs must be structured JSON with at least INFO level in production | S |

### Security (baseline)

| ID | Krav | MoSCoW |
| --- | --- | --- |
| NFR-SEC01 | All communication must use TLS 1.2 or higher | M |
| NFR-SEC02 | Authenticated endpoints must require a valid session/token | M |

### Portability / Environment requirements

| ID | Krav | MoSCoW |
| --- | --- | --- |
| NFR-PT01 | [Browserkompatibilitet / OS-krav / etc.] | [M/S/C] |

---

## 2. Functional requirements – User Stories

> **Format:**
> `As a [role], I want [function] so that [business value]`
> Each story has a unique ID, a MoSCoW priority, and acceptance criteria.

---

### Epic: [Epic name – e.g. “User management”]

---

#### FR-001 · [Kort storytitel]

**Story:**
As a [role]
I want [function]
so that [business value].

**Prioritet:** M / S / C / W
**Related NFR:** NFR-[ID] *(if applicable)*

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

**Technical notes:** *(optional implementation notes, not requirements)*
[Technical considerations relevant to the story]

---

#### FR-002 · [Short story title]

**Story:**
As a [role]
I want [function]
so that [business value].

**Prioritet:** M / S / C / W

**Acceptance criteria:**

```text
AC-002-1:
  Given [precondition]
  When [action/event]
  Then [expected outcome]
```

---

### Epic: [Next epic name]

---

#### FR-010 · [Short story title]

**Story:**
As a [role]
I want [function]
so that [business value].

**Prioritet:** M / S / C / W

**Acceptance criteria:**

```text
AC-010-1:
  Given [precondition]
  When [action/event]
  Then [expected outcome]
```

---

## 3. Use Cases (for complex flows)

> Use this when a flow involves multiple actors or systems, or has many failure scenarios.
> Skip this section when user stories cover the need.

---

### UC-001 · [Use case title]

| Field | Value |
| --- | --- |
| **ID** | UC-001 |
| **Primary actor** | [User / System] |
| **Preconditions** | [What must be true before the use case starts] |
| **Postconditions (success)** | [System state after successful execution] |
| **Postconditions (failure)** | [System state if the use case is aborted] |

**Main flow:**

1. [Actor does something]
2. [System responds]
3. [Actor takes the next step]
4. [System finishes with...]

**Alternative flows:**

*Alt 3a – [Description of failure case]:*

1. [What happens instead]
2. [How is it handled?]
3. The use case [resumes at step X / ends]

---

## 4. Priority overview (MoSCoW)

| Priority | Number of stories | Story IDs |
| --- | --- | --- |
| **Must have** | [X] | FR-001, FR-002, ... |
| **Should have** | [X] | FR-010, ... |
| **Could have** | [X] | FR-020, ... |
| **Won't have (now)** | [X] | FR-030, ... |

---

## 5. Requirements traceability

| Requirement ID | Related component (SAD) | Test case | Status |
| --- | --- | --- | --- |
| FR-001 | [Component in SAD] | TC-001 | Not started / Implemented / Tested |
| NFR-P01 | [Komponent i SAD] | TC-NFR-P01 | |

---

*Next step: Start the SAD draft based on these requirements, with particular focus on the NFRs.*
