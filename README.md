# Bäderauslastung München – API-Dokumentation

Inoffizielle OpenAPI-3.1-Beschreibung des JSON-Endpunkts, mit dem
<https://www.swm.de/baeder/auslastung> die Echtzeit-Auslastung der M-Bäder und M-Saunen lädt.

```
GET https://www.swm.de/.rest/bath/visitorCount?area_id=<id>
```

Die Spezifikation liegt in `openapi.yaml` (ein Endpunkt, alle Schemata, Randfälle, ID-Tabelle).

## Schnellstart

```sh
# Einzelnes Bad (Michaelibad Hallenbad)
curl 'https://www.swm.de/.rest/bath/visitorCount?area_id=3'

# Alle aktuell geöffneten Bäder und Bereiche (Live). Query-String ist Pflicht, sonst Cache-Snapshot!
curl 'https://www.swm.de/.rest/bath/visitorCount?area_id='

# Spec validieren
uvx openapi-spec-validator openapi.yaml
npx -y @redocly/cli lint openapi.yaml

# Live-Test gegen die API (4 req/s, Methoden-Probes aus, da TRACE einen TCP-Reset auslöst)
uvx schemathesis run openapi.yaml --url https://www.swm.de/.rest --rate-limit 4/s --checks all
```

Freie Kapazität in Prozent, wie auf der SWM-Seite angezeigt:
`100 - round(customer_amount / customer_amount_max * 100)`.

## Wichtigste Erkenntnisse (live verifiziert am 2026-10-25)

- Keine Authentifizierung, keine Cookies, kein Referer nötig. Nur `GET`/`HEAD`.
- **Ohne Query-String liefert der Server einen stundenalten Cache-Snapshot.** Jeder beliebige
  Query-Parameter (auch `?area_id=`) erzwingt Live-Daten.
- Nicht betriebene oder unbekannte Areas ergeben `{"return_code":"success","data":[]}`. Das Frontend zeigt dann
  „Aktuell geschlossen“. Die ungefilterte Antwort enthält nur Locations, die gerade Daten liefern
  (im Test fehlten abends Müller'sches Volksbad und Bad Giesing-Harlaching).
- CORS ist auf `https://www.swm.de` beschränkt. Fremder `Origin` ergibt 403 (JSON), leerer oder ungültiger
  `Origin` ergibt 403 (leer, `text/plain`). Ohne `Origin`-Header (serverseitig) kein Problem.
- Fehlerbehandlung ist PHP-typisch: nicht-numerische `area_id` → HTTP 200 mit `return_code: exception` und roher
  PHP-Meldung; `0`/negativ → HTTP 500 mit HTML-Seite; int64-Überlauf → Exception-Antwort; `3.5` → `3`;
  bei mehrfachem `area_id` zählt der erste Wert.
- `POST`/`PUT`/`DELETE`/`OPTIONS` → 401, `PATCH` → 403, `TRACE` → TCP-Reset. Pfad ist case-sensitiv.
- Das Frontend pollt nicht; ein Fetch pro Seitenaufruf.

Die vollständige Tabelle aller 28 bekannten `area_id`s mit `location_id` steht in `openapi.yaml`
(Parameter `area_id`). 17 davon werden auf der SWM-Seite angezeigt.

## Abdeckung und Vorbehalte

**Bestätigt live:** Endpunkt, Methoden, alle 17 im Frontend genutzten IDs plus die 11 weiteren aus der
Gesamtliste, Antwortschema (Felder, Typen, Pflichtfelder, keine Zusatzfelder), Randfälle, CORS, Caching.
Schemathesis (`--checks all`, 77 generierte Fälle) fand keine Abweichung zwischen Spec und Server außer zwei
Punkten, die beide dokumentiertes Serververhalten sind: HTTP 500 bei `area_id` ≤ 0 und HTTP 200 mit
`return_code: exception` bei int64-Überlauf.

**Abgeleitet, nicht bestätigt:**

- Bedeutung der Areas „XX - Sauna“ (IDs 102–120, immer 0 Besucher): vermutlich zweite Zählstellen oder Alt-IDs.
- Stabilität der IDs über Saisons hinweg und Aktualisierungsintervall der Zählstellen sind unbekannt.
- Der Web-Component-Code kennt einen zweiten Modus (`organizationUnitIds` → `personCount`/`maxPersonCount`),
  der auf der Auslastungsseite nicht genutzt wird; sein Endpunkt ist nicht bekannt und nicht dokumentiert.
- Rate-Limits wurden nicht ausgereizt (Tests liefen mit max. 4 req/s). Die SWM-Nutzungsbedingungen gelten.
