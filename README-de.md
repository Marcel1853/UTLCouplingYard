# UTL Coupling Yard

*Read in English: [README.md](README.md).*

Add-on für **Unified Train Logistics (UTL)**: An- und Abkuppeln. Züge lassen Wagen an Bahnhöfen stehen,
Rangierloks holen, bringen und stellen sie ab. Gedacht für schöne Bahnhöfe und Rollenspiel. Braucht UTLogistics
0.0.20 oder neuer.

## Rollen der Haltestelle

Wählbar im UTL-Stationsfenster, unter den UTL-Rollen.

- **Wagenbahnhof** – ein Zug hält hier,
  - **stellt** alle Wagen hinter seinen Loks **ab**,
  - **holt** die Wagen **ab**, die direkt vor ihm warten, und kuppelt sie an (Haltestelle so setzen, dass der Zug
    an den Wagen hält; Karteneinstellung „an wartende Wagen heranfahren“ lässt ihn bis 40 Kacheln langsam vorfahren),
  - und fährt dann mit seinem Fahrplan weiter. Wartebedingungen spielen an diesem Halt keine Rolle.

  Betriebsart je Station: abstellen und abholen, nur abstellen, nur abholen. **Zuglimit steuern**: Kein Zug kommt,
  solange dort noch Wagen stehen, wo er halten würde (abstellen), bzw. bis Wagen vor dem Halt warten (abholen).
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

Mehrere Wagenbahnhöfe dürfen gleich heißen (z. B. drei Gleise „Ladebucht“): Die Rangierlok nimmt ein freies.
Sie kommt mit den Wagen voran an, Stumpfgleise gehen also; falls nötig wechselt sie vorher an einer Wende die
Richtung.

## Staffel

Züge nur einen Teil der Strecke fahren lassen und die Wagen übergeben. Einem Wagenbahnhof eine
**Staffel-Nummer** geben (Stationsfenster) und das Signal [virtual-signal=ucy-relay] **Staffel** mit dieser Nummer an
die Haltestelle eines Abnehmers (oder Anbieters) legen. Lieferungen dorthin halten dann nach dem Laden am
Wagenbahnhof: Der Zug stellt seine Wagen ab – die Lieferung bleibt bei den Wagen – und seine Loks fahren zurück ins
Depot. Der nächste Zug, der die Wagen an einem Wagenbahnhof abholt, bringt die Lieferung zum Abnehmer.

## Szenario

„UTL Coupling Yard – Rangierbahnhof“ (Neues Spiel → Szenarien): großer Rangierbahnhof mit Greifarmen, die be- und
entladen, Vorführstrecken für Abstellen, Abholen, Tauschen, Übergabe auf einem Gleis und die Staffel, dazu eine
lange Strecke: Erzmine – Wagenbahnhof mit Voll- und Leer-Gleis – Entladebahnhof, an dem der Erzzug volle gegen
leere Wagen tauscht.

„UTL Coupling Yard – Großnetz“: eigenes Netz aus 4 × 3 Kreiseln mit zweigleisigen Strecken und Signalen, UTL-Bahnhöfe
und 33 UTL-Züge mit Lieferungen. In zwei Blöcken liegen eine Erzmine und eine Fabrik, jede mit Übergabebahnhof und
Rangierbahnhof: Der Streckenzug stellt seine Wagen ab, setzt um und holt die bereitgestellten; die Rangierlok bringt
die Wagen an die Lade- bzw. Entladegleise und zurück.

## Tipps

- Haltestellen wie gewohnt rechts in Fahrtrichtung bauen.
- Vor einem Wagenbahnhof Platz für wartende Wagen lassen und Signale setzen, damit Züge nicht auf abgestellte Wagen
  fahren.
- Übergabe auf einem Gleis: zwei Haltestellen gegenüber an derselben Stelle. Ein Zug schiebt die Wagen bis zu seinem Halt, kuppelt ab und fährt rückwärts weg; der andere kommt von der Gegenseite, kuppelt an und zieht sie weg. Beide brauchen Loks in beide Richtungen.
- UTL schickt Rangierloks nicht zum Tanken: viel Brennstoff mitgeben oder eine Unterbrechung „Brennstoff niedrig“.

## Leistung

Kein Takt, solange nicht rangiert wird. Alles startet über UTL-Ereignisse (Zug angekommen, Zug frei im Depot,
Auftrag fertig). Nur während ein Zug langsam zum Kuppeln vorfährt, läuft kurz ein Takt.

Jedes Kuppeln wird bei UTL angemeldet, Lieferungen und Fahrpläne überstehen es.

Mit Hilfe von KI (Claude von Anthropic) entstanden, getestet von Marcel171297.
