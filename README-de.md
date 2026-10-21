# UTL Coupling Yard

*Read in English: [README.md](README.md).*

Add-on für **Unified Train Logistics (UTL)**: An- und Abkuppeln. Züge lassen Wagen an Bahnhöfen stehen,
Rangierloks holen, bringen und stellen sie ab. Gedacht für schöne Bahnhöfe und Rollenspiel. Braucht UTLogistics
0.0.20 oder neuer.

## Rollen der Haltestelle

Wählbar im UTL-Stationsfenster, unter den UTL-Rollen.

- **Wagenbahnhof** – ein Zug hält hier,
  - **stellt** alle Wagen hinter seinen Loks **ab**,
  - **holt** die Wagen **ab**, die vor ihm warten (bis 40 Kacheln): Er fährt langsam vor und kuppelt sie an,
  - und fährt dann mit seinem Fahrplan weiter. Wartebedingungen spielen an diesem Halt keine Rolle.

  Betriebsart je Station: abstellen und abholen, nur abstellen, nur abholen.
- **Rangierdepot** – Depot für Rangierloks. UTL vermittelt sie nie. Eine Rangierlok muss in beide Richtungen
  fahren: mindestens eine Lok je Richtung (z. B. eine nach links, eine nach rechts). Ohne Fahrplan bekommt sie das
  Depot als einzigen Halt.
- **Wende** – nutzen Rangierloks, wenn sie ein Ziel nur nach einem Richtungswechsel erreichen.

## Rangieren

Im Stationsfenster eines Wagenbahnhofs bei **Wagen rangieren nach:** den Namen eines anderen Wagenbahnhofs
eintragen und wählen, wann: sofort, wenn leer oder wenn voll. Werden dort Wagen abgestellt, fährt eine freie
Rangierlok ans Ende der Wagen, kuppelt sie an, bringt sie zum Ziel, kuppelt ab und fährt zurück ins Depot.

Beispiel: Der Zug stellt volle Wagen in „Ankunft“ ab → die Rangierlok bringt sie zu „Entladen“ → wenn leer, weiter
nach „Abfahrt“ → der nächste Zug holt sie dort ab.

## Tipps

- Haltestellen wie gewohnt rechts in Fahrtrichtung bauen.
- Vor einem Wagenbahnhof Platz für wartende Wagen lassen und Signale setzen, damit Züge nicht auf abgestellte Wagen
  fahren.
- Kommt ein Zug mit den Wagen voran (geschoben), bleiben sie angekuppelt.

## Leistung

Kein Takt, solange nicht rangiert wird. Alles startet über UTL-Ereignisse (Zug angekommen, Zug frei im Depot,
Auftrag fertig). Nur während ein Zug langsam zum Kuppeln vorfährt, läuft kurz ein Takt.

Jedes Kuppeln wird bei UTL angemeldet, Lieferungen und Fahrpläne überstehen es.

Mit Hilfe von KI (Claude von Anthropic) entstanden, getestet von Marcel171297.
