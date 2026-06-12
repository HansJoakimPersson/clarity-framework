# Driftdokumentation (Runbook)

## [Produktnamn]

| | |
| --- | --- |
| **Version** | 0.1 |
| **Status** | Aktiv |
| **Datum** | ÅÅÅÅ-MM-DD |
| **Författare** | [Namn] |
| **Kopplad till** | Deployment View v[X.X] |

### Versionshistorik

| Version | Datum | Förändring | Författare |
| --- | --- | --- | --- |
| 0.1 | ÅÅÅÅ-MM-DD | Initial version | [Namn] |

> **Princip:** Alla kommandon i detta dokument ska vara testade och fungerande. Inga "se källkoden" eller "fråga [person]" – denna runbook ska vara självständig.  
> **Uppdatera** detta dokument direkt efter varje drifthändelse som avslöjar en lucka.

---

## 1. Systemöversikt (driftperspektiv)

**Driftplattform:** [VPS / AWS / Hetzner / etc.]  
**Server-IP / Host:** [IP eller hostname]  
**SSH-åtkomst:** `ssh [user]@[host]`

**Körande processer:**

| Process | Container-namn | Port | Beskrivning |
| --- | --- | --- | --- |
| Reverse proxy | `proxy` | 80, 443 | TLS-terminering och routing |
| Applikation | `app` | 8080 (intern) | Spring Boot / applikationsserver |
| Databas | `db` | 5432 (intern) | PostgreSQL |

**Kritiska filsökvägar:**

| Syfte | Sökväg |
| --- | --- |
| Docker Compose (prod) | `/opt/[produktnamn]/docker-compose.prod.yml` |
| Environment-fil | `/opt/[produktnamn]/.env` |
| Applikationsloggar | `docker logs app` / `/var/log/[produktnamn]/` |
| Databas-volym | `/data/db/` |
| Backup-destination | `/backup/[produktnamn]/` |

---

## 2. Uppstart och nedstängning

### Normal uppstart

```bash
# 1. SSH till server
ssh [user]@[host]

# 2. Navigera till projektkatalogen
cd /opt/[produktnamn]

# 3. Starta alla containers
docker compose -f docker-compose.prod.yml up -d

# 4. Verifiera att alla containers körs
docker compose -f docker-compose.prod.yml ps

# 5. Verifiera hälsa
curl -f https://[domän]/health
# Förväntat svar: {"status":"UP"}

# 6. Kontrollera loggar för eventuella fel
docker compose -f docker-compose.prod.yml logs --tail=50 app
```

### Planerad nedstängning

```bash
# Graciös nedstängning (väntar på att aktiva requests avslutas)
docker compose -f docker-compose.prod.yml down --timeout 30

# Verifiera att allt är stoppat
docker compose -f docker-compose.prod.yml ps
# Förväntat: inga körande containers
```

### Omstart av enskild tjänst

```bash
# Starta om enbart applikationen (t.ex. vid minnesproblem)
docker compose -f docker-compose.prod.yml restart app

# Starta om databasen (OBS: orsakar kortvarig nedtid)
docker compose -f docker-compose.prod.yml restart db
```

---

## 3. Releaseprocess

### Förberedelse inför release

```text
FÖRBEREDELSECHECKLIST
☐ Alla tester passerar i CI
☐ Smoke test passerar i staging
☐ Releaseversion och releasekandidatens commit är fastställda
☐ CHANGELOG och GitHub-releasenoter är skrivna
☐ Breaking changes, migreringssteg och kända problem är dokumenterade
☐ Databasmigration är testad i staging (om tillämpligt)
☐ Rollback-plan är klar
☐ [Eventuell underhållssida är förberedd]
```

### Skapa release i GitHub

| Egenskap | Projektets val |
| --- | --- |
| Trigger | [Push av annoterad tagg / manuell körning av `release.yml`] |
| Workflow | `.github/workflows/release.yml` |
| Godkännare | [Roll eller namn] |

```bash
# 1. Kontrollera att rätt commit på main ska releasas
git switch main
git pull --ff-only origin main
git status --short
git log -1 --oneline

# 2. Skapa och pusha en annoterad versionstagg
git tag -a vX.Y.Z -m "[Produktnamn] vX.Y.Z"
git push origin vX.Y.Z

# 3. Verifiera att release-workflow och GitHub Release har skapats
# [Projektets gh-kommando eller URL till Actions och Releases]
```

Verifiera före deployment att GitHub-releasen pekar på avsedd commit, att artefakterna är kompletta och att
releasenoterna innehåller ändringar, migreringssteg, kända problem och länk till fullständig changelog.

### Deploy till produktion

```bash
# 1. Sätt APP_VERSION till ny release-tagg
export APP_VERSION=v1.2.3

# 2. Hämta ny image
docker compose -f docker-compose.prod.yml pull app

# 3. Kör databasmigrationer (om tillämpligt)
docker compose -f docker-compose.prod.yml run --rm app \
  java -jar app.jar --spring.batch.job.enabled=false migrate

# 4. Deploya ny version
docker compose -f docker-compose.prod.yml up -d app

# 5. Verifiera hälsa
sleep 10
curl -f https://[domän]/health

# 6. Kör smoke test
./scripts/smoke-test.sh https://[domän]
```

### Rollback

```bash
# Identifiera senaste fungerande version
docker images [registry]/[produktnamn] --format "{{.Tag}}" | sort -V

# Rulla tillbaka
export APP_VERSION=[föregående-version]
docker compose -f docker-compose.prod.yml up -d app

# Verifiera
curl -f https://[domän]/health
```

**OBS vid databasmigrationer:** Om den nya versionen innehöll en databasmigration som inte är reversibel, kontakta [ansvarig] innan rollback. Databasåterställning kräver backup-restore (se avsnitt 5).

### Dokumentera releaseutfall

Efter deployment:

- Markera deploymentresultat och smoke test i GitHub Release eller länka till workflow-körningen
- Registrera version, produktionsdatum och utfall i `docs/08-andringshantering.md`
- Dokumentera rollback, avbruten release eller kända produktionsproblem i samma releasepost
- Uppdatera Runbook och Deployment View om releasen avslöjade en processlucka

---

## 4. Vanliga driftuppgifter

### Kontrollera systemstatus

```bash
# Containers
docker compose -f docker-compose.prod.yml ps

# Resursanvändning
docker stats --no-stream

# Diskutrymme
df -h
du -sh /data/db/

# Applikationsloggar (senaste 100 rader)
docker logs --tail=100 app

# Följa loggar live
docker logs -f app
```

### Loggrotation

Loggar roteras automatiskt av Docker med följande konfiguration i `docker-compose.prod.yml`:

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "100m"
    max-file: "5"
```

Manuell rensning om diskutrymme är kritiskt:

```bash
docker system prune --volumes  # OBS: tar bort oanvända volumes
```

### Köra databasmigration manuellt

```bash
docker compose -f docker-compose.prod.yml run --rm app \
  [kommando för att köra Flyway/Liquibase manuellt]
```

### Skalning (om tillämpligt)

```bash
# Skala upp till X instanser av applikationen
docker compose -f docker-compose.prod.yml up -d --scale app=X
```

---

## 5. Backup och återställning

### Backup-strategi

| Vad | Frekvens | Retention | Destination |
| --- | --- | --- | --- |
| Databasdump (full) | Dagligen 02:00 | 30 dagar | `/backup/[produktnamn]/db/` |
| Databasdump (weekly) | Söndagar 02:00 | 12 veckor | `/backup/[produktnamn]/db/weekly/` |
| Konfigurationsfiler | Vid förändring | Permanent | Git-repo |

### Manuell backup

```bash
# Databasdump
DATUM=$(date +%Y%m%d_%H%M%S)
docker exec db pg_dump -U [DB_USER] [DB_NAME] | \
  gzip > /backup/[produktnamn]/db/manual_${DATUM}.sql.gz

# Verifiera att filen skapades
ls -lh /backup/[produktnamn]/db/manual_${DATUM}.sql.gz
```

### Återställning från backup

```bash
# 1. Stoppa applikationen (ej databasen)
docker compose -f docker-compose.prod.yml stop app

# 2. Återställ från backup
BACKUP_FIL=/backup/[produktnamn]/db/[filnamn].sql.gz
docker exec -i db psql -U [DB_USER] -c "DROP DATABASE [DB_NAME];"
docker exec -i db psql -U [DB_USER] -c "CREATE DATABASE [DB_NAME];"
zcat ${BACKUP_FIL} | docker exec -i db psql -U [DB_USER] [DB_NAME]

# 3. Starta applikationen igen
docker compose -f docker-compose.prod.yml start app

# 4. Verifiera
curl -f https://[domän]/health
```

---

## 6. Felsökningsguide

> Uppdatera detta avsnitt efter varje incident.

---

### SYMPTOM: HTTP 503 Service Unavailable

**Kontrollpunkter:**

```bash
# 1. Är applikationen igång?
docker compose -f docker-compose.prod.yml ps app
# Om "Exit" visas: starta om med 'docker compose up -d app'

# 2. Är databasen igång?
docker compose -f docker-compose.prod.yml ps db
# Om ej "healthy": kontrollera db-loggar: docker logs db

# 3. Minnesproblem?
docker stats --no-stream app
# Om mem > 90%: starta om 'docker compose restart app'

# 4. Diskutrymme fullt?
df -h
# Om > 90%: rensa gamla Docker-images: docker image prune -a
```

---

### SYMPTOM: Applikationen startar men kraschar efter några sekunder

```bash
# Kontrollera applikationsloggar
docker logs app --tail=200

# Vanliga orsaker:
# - Kan ej ansluta till databas → kontrollera DB_URL i .env
# - Port 8080 redan upptagen → kontrollera: ss -tlnp | grep 8080
# - Felaktig konfiguration → kontrollera miljövariabler: docker inspect app
```

---

### SYMPTOM: Databasen är otillgänglig

```bash
# Kontrollera status
docker compose -f docker-compose.prod.yml ps db
docker logs db --tail=100

# Försök ansluta manuellt
docker exec -it db psql -U [DB_USER] -c "\l"

# Om "no space left on device":
df -h /data/db/
# Åtgärd: Frigör diskutrymme eller utöka volym
```

---

### SYMPTOM: [Lägg till fler symptom löpande]

```bash
# Kontrollpunkter:
# ...
```

---

## 7. Incidenthantering

### Klassificering

| Nivå | Beskrivning | Exempel | Responstid |
| --- | --- | --- | --- |
| **P1 – Kritisk** | Systemet är helt otillgängligt | HTTP 503 på produktion | Omedelbart |
| **P2 – Hög** | Kritisk funktion bruten | Inloggning fungerar ej | < 1 timme |
| **P3 – Medel** | Degraderad funktion | Sökning långsam | < 4 timmar |
| **P4 – Låg** | Kosmetiskt / icke-kritiskt | Felaktig text i UI | Nästa sprint |

### Kontaktlista

| Roll | Namn | Kontakt |
| --- | --- | --- |
| Primär driftansvarig | [Namn] | [E-post / Telefon] |
| Backup driftansvarig | [Namn] | [E-post / Telefon] |

### Post-mortem-process

Efter varje P1- eller P2-incident dokumenteras:

1. **Tidslinje** – Vad hände och när?
2. **Grundorsak** – Varför inträffade det?
3. **Påverkan** – Hur många användare drabbades? Under hur lång tid?
4. **Åtgärder** – Vad gjordes för att lösa det?
5. **Preventiva åtgärder** – Vad görs för att förhindra upprepning?

*Post-mortem sparas i `/docs/incidents/ÅÅÅÅ-MM-DD-[kortbeskrivning].md`*

---

## 8. Smoke test-checklist

> Körs efter varje deployment till produktion.

```text
SMOKE TEST – [Produktnamn] v[VERSION] – [DATUM]
Utfört av: [Namn]

GRUNDLÄGGANDE
☐ https://[domän] laddar utan fel
☐ GET /health returnerar {"status":"UP"}
☐ Inloggning fungerar med testanvändare

KRITISKA FLÖDEN
☐ [Kritiskt flöde 1 – t.ex. "Kan skapa ett nytt recept"]
☐ [Kritiskt flöde 2 – t.ex. "Kan lägga till recept i veckoplan"]
☐ [Kritiskt flöde 3]

INFRASTRUKTUR
☐ SSL-certifikat är giltigt (ej snart utgående)
☐ Diskutrymme < 80%
☐ Inga ERROR-loggar i de senaste 5 minuterna

RESULTAT: ☐ Godkänt  ☐ Underkänt (beskriv nedan)
Anmärkningar: _______________
```

---

*Uppdatera detta dokument direkt när en drifthändelse avslöjar en lucka.*
