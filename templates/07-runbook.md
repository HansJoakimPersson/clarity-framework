# Runbook

## [Product name]

| | |
| --- | --- |
| **Version** | 0.1 |
| **Status** | Draft / Under review / Approved |
| **Date** | YYYY-MM-DD |
| **Author** | [Name] |
| **Related to** | Deployment View v[X.X] |

### Version history

| Version | Date | Change | Author |
| --- | --- | --- | --- |
| 0.1 | YYYY-MM-DD | Initial version | [Name] |

> Every command in this document must be tested and operational. The runbook must be usable by a
> new operator without relying on undocumented personal knowledge. Update it after every operational
> event that exposes a missing, ambiguous, or unsafe instruction.

---

## 1. Purpose, ownership, and operating model

**Purpose:** [What this system does and what this runbook covers.]
**Operating platform:** [VPS / AWS / Hetzner / Kubernetes / Other]
**Service owner:** [Name or team]
**Primary operator:** [Name or team]
**Backup operator:** [Name or team]
**Support hours:** [Hours and timezone]
**Escalation channel:** [Channel or incident system]

### Operational principles

- Confirm scope and impact before making changes.
- Prefer reversible, documented actions over improvisation.
- Record commands, timestamps, versions, decisions, and evidence during incidents.
- Do not expose secrets in shell history, logs, screenshots, or incident records.
- Stop and escalate when a step may cause data loss or documented assumptions do not hold.

---

## 2. System overview from an operational perspective

**Production host / account:** [Host, cloud account, or cluster]
**Primary hostname:** `[hostname]`
**SSH or console access:** `ssh [user]@[host]`
**Deployment directory:** `/opt/[product-name]`

### Running processes

| Process | Container / service | Port | Description | Dependency |
| --- | --- | --- | --- | --- |
| Reverse proxy | `proxy` | 80, 443 | TLS termination and routing | — |
| Application | `app` | 8080 internal | Application server | Database |
| Database | `db` | 5432 internal | PostgreSQL | Persistent volume |

### Critical paths and dashboards

| Purpose | Location |
| --- | --- |
| Production deployment configuration | `/opt/[product-name]/docker-compose.prod.yml` |
| Runtime configuration | `/opt/[product-name]/.env` or secret manager |
| Application logs | `docker compose logs app` / [log dashboard] |
| Database volume | `/data/db/` |
| Backup destination | `/backup/[product-name]/` |
| Monitoring dashboard | [URL] |
| Incident log | [URL or repository path] |

Do not store actual passwords, private keys, tokens, or personal data in this document.

---

## 3. Prerequisites and access

The operator must have the required CLI tools, account, role, network access, and temporary access
to the approved secret source. Document how to obtain and revoke access, but never record the
credentials themselves.

| Requirement | How to verify | Owner |
| --- | --- | --- |
| Repository access | [Safe verification command] | [Owner] |
| Production host or cluster access | [Safe verification command] | [Owner] |
| Container or deployment CLI | `[tool] --version` | [Owner] |
| Secret manager access | [Safe verification command] | [Owner] |
| Monitoring and incident system | Open [URL] | [Owner] |

Before any production operation, confirm the target environment, current version, maintenance
window, active incident status, and that a current rollback or recovery path exists.

---

## 4. Start, stop, and restart operations

### Normal startup

```bash
# 1. Connect to the approved host or cluster.
ssh [user]@[host]

# 2. Navigate to the deployment directory.
cd /opt/[product-name]

# 3. Start all services.
docker compose -f docker-compose.prod.yml up -d

# 4. Verify service state.
docker compose -f docker-compose.prod.yml ps

# 5. Verify application health.
curl -f https://[domain]/health

# 6. Check recent application logs.
docker compose -f docker-compose.prod.yml logs --tail=50 app
```

**Expected result:** All required services are running or healthy, the health endpoint returns the
documented response, and no new startup errors appear in the logs.

### Planned shutdown

```bash
# Gracefully stop services and allow active requests to finish.
docker compose -f docker-compose.prod.yml down --timeout 30

# Verify that services have stopped.
docker compose -f docker-compose.prod.yml ps
```

Do not stop the database or delete volumes unless the approved procedure explicitly requires it.

### Restart an individual service

```bash
# Restart the application only.
docker compose -f docker-compose.prod.yml restart app

# Verify health and logs after the restart.
curl -f https://[domain]/health
docker compose -f docker-compose.prod.yml logs --tail=100 app
```

Restarting the database can cause downtime and may affect active requests. Record the reason and
verify application recovery after the database restart.

---

## 5. Release and deployment procedure

### Release readiness checklist

```text
RELEASE READINESS
☐ Required tests pass in CI
☐ Staging smoke test passes
☐ Visual UX verification is complete for UI changes
☐ Release notes and Change Management entry are ready
☐ Database migrations have been tested in staging, if applicable
☐ Migration compatibility with rollback has been assessed
☐ Backup and rollback target are available
☐ Required reviewers have approved the release
☐ Maintenance communication is prepared, if needed
```

### Production deployment

```bash
# 1. Select the approved, manually created release tag.
export APP_VERSION=vX.Y.Z

# 2. Retrieve the approved application artifact.
docker compose -f docker-compose.prod.yml pull app

# 3. Run database migrations through the approved project command.
docker compose -f docker-compose.prod.yml run --rm app \
  [migration command]

# 4. Deploy the application.
docker compose -f docker-compose.prod.yml up -d app

# 5. Verify health after startup.
curl -f https://[domain]/health

# 6. Run the release smoke test.
./scripts/smoke-test.sh https://[domain]
```

Record the release tag, commit, migration result, deploy time, operator, smoke-test result, and
monitoring confirmation. If any verification fails, stop promotion and follow the rollback or
incident procedure.

### Rollback

```bash
# Identify the last approved working version.
git tag --list | sort -V | tail -10

# Deploy the approved previous version.
export APP_VERSION=[previous-version]
docker compose -f docker-compose.prod.yml up -d app

# Verify health and critical user journeys.
curl -f https://[domain]/health
./scripts/smoke-test.sh https://[domain]
```

Before rolling back, verify whether the release applied an irreversible database migration. If it
did, do not improvise a database rollback; escalate to the service owner and use the tested restore
or forward-fix procedure in the Data Model and Deployment documents.

---

## 6. Routine operations

### Check system status

```bash
# Service state
docker compose -f docker-compose.prod.yml ps

# Resource usage
docker stats --no-stream

# Disk usage
df -h
du -sh /data/db/

# Recent application logs
docker compose -f docker-compose.prod.yml logs --tail=100 app

# Follow application logs temporarily
docker compose -f docker-compose.prod.yml logs -f app
```

### Log rotation

Logs must have an explicit retention policy. Example Docker configuration:

```yaml
logging:
  driver: json-file
  options:
    max-size: 100m
    max-file: "5"
```

Do not run broad destructive cleanup commands in production without verifying the exact targets,
impact, and approved recovery path. If disk space is critical, preserve current logs and escalate
before removing images, volumes, or backups.

### Run a database migration manually

```bash
docker compose -f docker-compose.prod.yml run --rm app \
  [approved Flyway, Liquibase, or migration command]
```

Run migrations only after verifying the target version, backup status, lock behavior, and rollback
compatibility. Record the output and resulting schema version.

### Scale the application, if supported

```bash
# Replace X with the approved number of instances.
docker compose -f docker-compose.prod.yml up -d --scale app=X
```

Confirm that the application is stateless or that sessions, queues, and shared storage support the
new instance count before scaling.

---

## 7. Backup and restore

### Backup strategy

| Asset | Frequency | Retention | Destination | Restore test | Owner |
| --- | --- | --- | --- | --- | --- |
| Full database dump | Daily at [time] | 30 days | `/backup/[product-name]/db/` | [Schedule] | [Owner] |
| Weekly database dump | Weekly | 12 weeks | `/backup/[product-name]/db/weekly/` | [Schedule] | [Owner] |
| Object or file storage | [Schedule] | [Policy] | [Destination] | [Schedule] | [Owner] |
| Configuration | On change | [Policy] | Git / secret manager | [Schedule] | [Owner] |

Document encryption, off-site copies, access controls, recovery point objective (RPO), recovery
time objective (RTO), and the person responsible for verifying backup success.

### Manual database backup

```bash
# Use a task-specific timestamp and the approved backup destination.
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
docker exec db pg_dump -U [DB_USER] [DB_NAME] | \
  gzip > /backup/[product-name]/db/manual_${BACKUP_TIMESTAMP}.sql.gz

# Verify that the file exists and is non-empty.
ls -lh /backup/[product-name]/db/manual_${BACKUP_TIMESTAMP}.sql.gz
```

Verify checksum, permissions, available space, and (where required) upload to the protected backup
destination.

### Restore from backup

```bash
# 1. Stop the application but keep the database service available.
docker compose -f docker-compose.prod.yml stop app

# 2. Set the approved backup file.
BACKUP_FILE=/backup/[product-name]/db/[file-name].sql.gz

# 3. Restore using the approved database procedure.
zcat "$BACKUP_FILE" | docker exec -i db psql -U [DB_USER] [DB_NAME]

# 4. Start the application.
docker compose -f docker-compose.prod.yml start app

# 5. Verify health and critical data paths.
curl -f https://[domain]/health
./scripts/smoke-test.sh https://[domain]
```

Use a tested clean-database procedure when the backup requires replacement rather than additive
restore. Confirm the target database, backup timestamp, migration compatibility, permissions, and
expected data loss before executing a destructive restore.

---

## 8. Troubleshooting guide

Update this section after every incident or recurring operational problem.

### Symptom: HTTP 503 Service Unavailable

```bash
# 1. Is the application running?
docker compose -f docker-compose.prod.yml ps app

# 2. Is the database healthy?
docker compose -f docker-compose.prod.yml ps db
docker compose -f docker-compose.prod.yml logs --tail=100 db

# 3. Is the application under resource pressure?
docker stats --no-stream app

# 4. Is the disk full?
df -h
```

If a service has exited, capture logs and the current version before restarting it. If memory,
storage, or repeated crashes are involved, escalate rather than repeatedly restarting the service.

### Symptom: Application starts and then crashes

```bash
# Inspect the last application logs.
docker compose -f docker-compose.prod.yml logs --tail=200 app

# Inspect service state without printing secrets.
docker compose -f docker-compose.prod.yml ps app
docker inspect app --format '{{.State.Status}} {{.State.ExitCode}}'
```

Common causes include database connection failure, invalid configuration, unavailable dependencies,
port conflicts, incompatible migrations, and exhausted memory. Confirm each against evidence before
taking corrective action.

### Symptom: Database is unavailable

```bash
# Check status and logs.
docker compose -f docker-compose.prod.yml ps db
docker compose -f docker-compose.prod.yml logs --tail=100 db

# Check storage without exposing credentials.
df -h /data/db/
```

Do not delete database files or volumes to resolve a full disk or startup failure. Escalate for
storage expansion, cleanup approval, or restore.

### Symptom: [Add recurring symptom]

**Impact:** [What users observe]
**Checks:** [Safe commands or dashboards]
**Mitigation:** [Reversible action]
**Escalation:** [Stop condition and owner]

---

## 9. Incident response

### Severity classification

| Level | Description | Example | Initial response |
| --- | --- | --- | --- |
| **P1 – Critical** | System unavailable or severe data risk | Production returns 503 | Immediate |
| **P2 – High** | Critical function is broken or heavily degraded | Login unavailable | Within 1 hour |
| **P3 – Medium** | Degraded but usable function | Search is slow | Within 4 hours |
| **P4 – Low** | Cosmetic or non-critical issue | Incorrect UI text | Next planned work |

### Response steps

1. Confirm the symptom, start time, affected scope, current version, and severity.
2. Open or update the incident record and notify the responsible operator.
3. Check health, logs, metrics, recent changes, dependencies, and capacity.
4. Apply the least risky documented mitigation.
5. Escalate when a stop condition is met or when data loss is possible.
6. Communicate status and the next expected update to affected stakeholders.
7. Verify recovery with health checks and critical user journeys.
8. Record impact, timeline, actions, evidence, and follow-up work.

### Contacts

| Role | Name / team | Contact | Escalation condition |
| --- | --- | --- | --- |
| Primary operator | [Name] | [Email / phone / channel] | First response |
| Backup operator | [Name] | [Email / phone / channel] | No response after [time] |
| Product owner | [Name] | [Contact] | User or business impact |
| Infrastructure owner | [Name] | [Contact] | Host, network, or platform issue |

### Post-incident review

After every P1 or P2 incident, document:

1. Timeline — what happened and when.
2. Root cause or contributing factors.
3. User and business impact.
4. Detection and response quality.
5. Mitigation and recovery actions.
6. Preventive actions, owners, and due dates.

Store the review under
`[incident record location]/YYYY-MM-DD-[short-description].md`.

---

## 10. Production smoke-test checklist

Run after every production deployment and after recovery from a significant incident.

```text
SMOKE TEST – [Product name] v[VERSION] – [DATE]
Performed by: [Name]
Environment: [URL]

BASIC AVAILABILITY
☐ The production URL loads without an unexpected error.
☐ GET /health returns the documented healthy response.
☐ Authentication works with the approved test account, if applicable.

CRITICAL JOURNEYS
☐ [Critical journey 1]
☐ [Critical journey 2]
☐ [Critical journey 3]

INFRASTRUCTURE
☐ TLS certificate is valid and not near expiry.
☐ Disk usage is below the defined threshold.
☐ No unexpected ERROR logs appeared after deployment.
☐ Monitoring and alerting report the expected state.

UI VERIFICATION, IF APPLICABLE
☐ Target viewport and browser check completed.
☐ Changed screens and critical states render correctly.
☐ Accessibility and keyboard checks completed.

RESULT: ☐ Pass  ☐ Fail
Notes and evidence: _______________________________
```

---

## 11. Document completeness

- [ ] A new operator can access the system, deploy, verify, and roll back from this document.
- [ ] System ownership, topology, paths, dashboards, and escalation contacts are documented.
- [ ] Startup, shutdown, restart, release, rollback, and routine operations use tested commands.
- [ ] Backup, restore, RPO, RTO, and recovery verification are documented.
- [ ] Troubleshooting and incident procedures include stop conditions.
- [ ] Smoke-test evidence is recorded after deployment and recovery.
- [ ] No secrets, machine-specific credentials, or destructive unverified commands are included.

---

*Update this document immediately when an operational event exposes a gap.*

*Clarity Framework v3.6.0 – Runbook*
