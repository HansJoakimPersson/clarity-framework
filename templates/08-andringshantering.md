# Ändringslogg & Teknisk Skuld

## [Produktnamn]

| | |
| --- | --- |
| **Version** | 0.1 |
| **Datum** | ÅÅÅÅ-MM-DD |
| **Författare** | [Namn] |

---

## 1. Teknisk skuld

> Dokumentera medvetna kompromisser. Teknisk skuld som är synlig är hanterbar.  
> Länka alltid till det ADR eller den story som motiverade kompromissen.

| ID | Beskrivning | Komponent | Orsak | Påverkan | Planerad åtgärd | Datum tillagd |
| --- | --- | --- | --- | --- | --- | --- |
| TD-001 | [Kompromiss eller brist] | [Berörd komponent] | [Varför gjordes kompromissen?] | Hög / Medel / Låg | [Sprint/version] | ÅÅÅÅ-MM-DD |
| TD-002 | | | | | | |

---

## 2. Föråldrade beslut

> ADR:er som ersatts av nyare beslut. Tas aldrig bort – historiken har värde.

| ADR-ID | Titel | Ersatt av | Datum |
| --- | --- | --- | --- |
| ADR-001 | [Ursprungligt beslut] | ADR-[nytt] | ÅÅÅÅ-MM-DD |

---

## 3. Releasehistorik

> Länka varje version till dess GitHub Release. Detaljerade releasenoter hör hemma i GitHub Release eller
> `CHANGELOG.md`; tabellen registrerar vad som faktiskt nådde produktion och utfallet av releasen.

| Version | Produktionsdatum | Typ | GitHub Release | Commit / artefakt | Utfall | Sammanfattning |
| --- | --- | --- | --- | --- | --- | --- |
| v1.0.0 | ÅÅÅÅ-MM-DD | Major | [Länk] | `[SHA / digest]` | Lyckad | Initial produktionsrelease |
| v1.1.0 | ÅÅÅÅ-MM-DD | Minor | [Länk] | `[SHA / digest]` | Lyckad | [Ny funktionalitet] |
| v1.1.1 | ÅÅÅÅ-MM-DD | Patch | [Länk] | `[SHA / digest]` | Rollback | [Buggfix och orsak till rollback] |

---

## 4. Incidentlogg

> Korta sammanfattningar av inträffade incidenter. Fullständiga post-mortems i `/docs/incidents/`.

| Datum | Allvarlighet | Beskrivning | Grundorsak | Åtgärdad |
| --- | --- | --- | --- | --- |
| ÅÅÅÅ-MM-DD | P1 | [Vad hände?] | [Varför?] | ÅÅÅÅ-MM-DD |
