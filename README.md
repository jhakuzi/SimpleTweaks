# SimpleTweaks

Ein kleines Addon für World of Warcraft: Forever mit einem bronzefarbenen Einstellungsfenster. Es bietet:

- Die Weltkarte beim Bewegen sichtbar halten.
- Makronamen auf den Blizzard-Aktionsleisten ausblenden.
- Einen Reichweitenpunkt am aktuellen Ziel für Jäger anzeigen.
- Einen Schwungtimer als Kreis.

Die Karten- und Makro-Funktionen sind standardmäßig aktiv. Der Reichweitenindikator und der Schwungtimer sind standardmäßig ausgeschaltet. Einstellungen werden gespeichert.

## Install

Kopiere den Ordner `SimpleTweaks` in `World of Warcraft/_forever_/Interface/AddOns`. Starte das Spiel neu oder verwende `/reload`.

Die TOC-Datei richtet sich an WoW Forever Interface `16001`.

## Use

Öffne das Einstellungsfenster über das Addon-Kompartiment oben rechts oder mit `/tweaks`.

- `/tweaks karte an|aus` schaltet das Ausblenden der Karte um.
- `/tweaks makros an|aus` schaltet das Ausblenden der Makronamen um.
- `/tweaks schwung an|aus` schaltet den Schwungtimer um.
- Das Einstellungsfenster übernimmt Änderungen sofort und ist auf Deutsch.
- **Schwungtimer** zeigt einen Kreis bis zum nächsten eigenen Nahkampfschlag oder Fernkampfangriff. Eine Linie auf dem Radius dreht sich um die Mitte: **Abnehmend** leert den Kreis, **Zunehmend** füllt ihn. Die Füllung läuft dabei von halber Deckkraft bis ganz deckend; diese Deckkraft wird mit der eigenen Füllfarbe multipliziert. Füllfarbe, Rand und Hintergrund haben je eine Farbe mit eigener Deckkraft. Die Linie ist immer da, **Funke** macht sie dicker und heller, und ihre Deckkraft stellt die Zeile **Linie** ein. Die Standardgröße entspricht dem Reichweitenpunkt. Ohne laufenden Angriff bleibt die Anzeige verborgen. Im Bearbeitungsmodus (Esc) erscheint sie als beschrifteter Rahmen über der übrigen Oberfläche und lässt sich verschieben; die Position wird pro Layout gespeichert.
- **Jäger Reichweitenindikator** zeigt nur am aktuellen feindlichen Ziel einen gefüllten Kreis links neben dem Lebensbalken: Rot außerhalb der Reichweite, Orange in Nahkampfreichweite und Grün in Auto-Schuss-Reichweite. Nahkampf wird mit einem 5-Yard-Gegenstandsreichweitentest geprüft, da Raptor Strike auf WoW Forever keine verlässliche Reichweitenabfrage liefert. Wenn der Client keinen eindeutigen Wert liefert, bleibt der Punkt verborgen.
