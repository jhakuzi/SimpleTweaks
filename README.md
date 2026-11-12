# SimpleTweaks

Ein kleines Addon für World of Warcraft: Forever mit einem bronzefarbenen Einstellungsfenster. Es bietet:

- Die Weltkarte beim Bewegen sichtbar halten.
- Makronamen auf den Blizzard-Aktionsleisten ausblenden.
- Einen Reichweitenpunkt am aktuellen Ziel für Jäger anzeigen.

Die Karten- und Makro-Funktionen sind standardmäßig aktiv; der Reichweitenindikator ist standardmäßig ausgeschaltet. Einstellungen werden gespeichert.

## Install

Kopiere den Ordner `SimpleTweaks` in `World of Warcraft/_forever_/Interface/AddOns`. Starte das Spiel neu oder verwende `/reload`.

Die TOC-Datei richtet sich an WoW Forever Interface `16001`.

## Use

Öffne das Einstellungsfenster über das Addon-Kompartiment oben rechts oder mit `/tweaks`.

- `/tweaks karte an|aus` schaltet das Ausblenden der Karte um.
- `/tweaks makros an|aus` schaltet das Ausblenden der Makronamen um.
- Das Einstellungsfenster enthält nur die Checkboxen der drei Funktionen und übernimmt Änderungen sofort.
- **Jäger Reichweitenindikator** zeigt nur am aktuellen feindlichen Ziel einen gefüllten Kreis links neben dem Lebensbalken: Rot außerhalb der Reichweite, Orange in Nahkampfreichweite und Grün in Auto-Schuss-Reichweite. Nahkampf wird mit einem 5-Yard-Gegenstandsreichweitentest geprüft, da Raptor Strike auf WoW Forever keine verlässliche Reichweitenabfrage liefert. Wenn der Client keinen eindeutigen Wert liefert, bleibt der Punkt verborgen.
