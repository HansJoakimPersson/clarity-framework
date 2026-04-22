# Kravdokumentation

## [Produktnamn]

| | |
| --- | --- |
| **Version** | 0.1 |
| **Status** | Utkast / Aktiv backlog |
| **Datum** | ÅÅÅÅ-MM-DD |
| **Författare** | [Namn] |
| **Kopplad till** | Vision & Scope v[X.X] |

### Versionshistorik

| Version | Datum | Förändring | Författare |
| --- | --- | --- | --- |
| 0.1 | ÅÅÅÅ-MM-DD | Initial version | [Namn] |

---

## 1. Icke-funktionella krav (NFR)

> NFR definieras **innan** de funktionella kraven specificeras i detalj – de styr arkitekturen.

### Prestanda

| ID | Krav | Mätetal | Målvärde | MoSCoW |
| --- | --- | --- | --- | --- |
| NFR-P01 | Svarstid för [huvudfunktion] | 95th percentile response time | < [X] ms | M |
| NFR-P02 | Systemet ska hantera [X] samtidiga användare | Concurrent users under load test | [X] | S |

### Tillgänglighet

| ID | Krav | Mätetal | Målvärde | MoSCoW |
| --- | --- | --- | --- | --- |
| NFR-A01 | Planerad drifttid | Uptime per månad | [X]% | M |
| NFR-A02 | Maximal återställningstid vid fel | RTO | < [X] min | S |

### Skalbarhet

| ID | Krav | MoSCoW |
| --- | --- | --- |
| NFR-S01 | Systemet ska stödja [X]% tillväxt i data under [Y] år utan omdesign | C |

### Underhållbarhet

| ID | Krav | MoSCoW |
| --- | --- | --- |
| NFR-M01 | All affärslogik ska vara enhetstestbar utan beroende till extern infrastruktur | M |
| NFR-M02 | Applikationsloggar ska vara strukturerade (JSON) med minst nivå INFO i produktion | S |

### Säkerhet (grundläggande)

| ID | Krav | MoSCoW |
| --- | --- | --- |
| NFR-SEC01 | All kommunikation ska ske över TLS 1.2 eller högre | M |
| NFR-SEC02 | Autentiserade endpoints ska kräva giltig session/token | M |

### Portabilitet / Miljökrav

| ID | Krav | MoSCoW |
| --- | --- | --- |
| NFR-PT01 | [Browserkompatibilitet / OS-krav / etc.] | [M/S/C] |

---

## 2. Funktionella krav – User Stories

> **Format:**  
> `Som [roll] vill jag [funktion] så att [affärsnytta]`  
> Varje story har ett unikt ID, MoSCoW-prioritet och acceptanskriterier.

---

### Epik: [Epiknamn – t.ex. "Användarhantering"]

---

#### FR-001 · [Kort storytitel]

**Story:**  
Som [roll]  
vill jag [funktion]  
så att [affärsnytta].

**Prioritet:** M / S / C / W  
**Kopplad NFR:** NFR-[ID] *(om tillämpligt)*

**Acceptanskriterier:**

```text
AC-001-1:
  Givet att [förutsättning]
  När [åtgärd/händelse]
  Så ska [förväntat utfall]

AC-001-2:
  Givet att [förutsättning]
  När [åtgärd/händelse]
  Så ska [förväntat utfall]
```

**Tekniska noter:** *(valfritt – implementationsanmärkningar, inte krav)*  
[Eventuella tekniska överväganden som är relevanta för storyn]

---

#### FR-002 · [Kort storytitel]

**Story:**  
Som [roll]  
vill jag [funktion]  
så att [affärsnytta].

**Prioritet:** M / S / C / W

**Acceptanskriterier:**

```text
AC-002-1:
  Givet att [förutsättning]
  När [åtgärd/händelse]
  Så ska [förväntat utfall]
```

---

### Epik: [Nästa epiknamn]

---

#### FR-010 · [Kort storytitel]

**Story:**  
Som [roll]  
vill jag [funktion]  
så att [affärsnytta].

**Prioritet:** M / S / C / W

**Acceptanskriterier:**

```text
AC-010-1:
  Givet att [förutsättning]
  När [åtgärd/händelse]
  Så ska [förväntat utfall]
```

---

## 3. Use Cases (för komplexa flöden)

> Används när ett flöde involverar flera aktörer, system eller har många felscenarios.  
> Hoppa över detta avsnitt om user stories täcker behovet.

---

### UC-001 · [Use case-titel]

| Fält | Värde |
| --- | --- |
| **ID** | UC-001 |
| **Primär aktör** | [Användare / System] |
| **Förutsättningar** | [Vad måste vara sant innan use caset startar] |
| **Eftervillkor (framgång)** | [Systemtillstånd efter lyckad körning] |
| **Eftervillkor (misslyckande)** | [Systemtillstånd om use caset avbryts] |

**Normflöde:**

1. [Aktör gör något]
2. [System svarar med något]
3. [Aktör gör nästa steg]
4. [System avslutar med...]

**Alternativa flöden:**

*Alt 3a – [Beskrivning av felfall]:*

1. [Vad händer istället]
2. [Hur hanteras det?]
3. Use caset [återupptas vid steg X / avslutas]

---

## 4. Prioriteringsoversikt (MoSCoW)

| Prioritet | Antal stories | Story-IDs |
| --- | --- | --- |
| **Must have** | [X] | FR-001, FR-002, ... |
| **Should have** | [X] | FR-010, ... |
| **Could have** | [X] | FR-020, ... |
| **Won't have (nu)** | [X] | FR-030, ... |

---

## 5. Kravspårbarhet (Traceability)

| Krav-ID | Kopplad komponent (SAD) | Testfall | Status |
| --- | --- | --- | --- |
| FR-001 | [Komponent i SAD] | TC-001 | Ej påbörjad / Implementerad / Testad |
| NFR-P01 | [Komponent i SAD] | TC-NFR-P01 | |

---

*Nästa steg: Påbörja SAD-utkast baserat på dessa krav, med särskilt fokus på NFR:erna.*
