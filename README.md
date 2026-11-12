# SimpleTweaks

Ein kleines Addon für World of Warcraft: Forever mit einem bronzefarbenen Einstellungsfenster. Es bietet:

- Die Weltkarte beim Bewegen sichtbar halten.
- Makronamen auf den Blizzard-Aktionsleisten ausblenden.
- Einen Reichweitenpunkt am aktuellen Ziel für Jäger anzeigen.
- Einen Text-Countdown bis zum nächsten Nahkampfschlag oder Fernkampfangriff.

Die Karten- und Makro-Funktionen sind standardmäßig aktiv. Der Reichweitenindikator und der Swing-Timer sind standardmäßig ausgeschaltet. Einstellungen werden gespeichert.

## Install

Kopiere den Ordner `SimpleTweaks` in `World of Warcraft/_forever_/Interface/AddOns`. Starte das Spiel neu oder verwende `/reload`.

Die TOC-Datei richtet sich an WoW Forever Interface `16001`.

## Use

Öffne das Einstellungsfenster über das Addon-Kompartiment oben rechts oder mit `/tweaks`.

- `/tweaks karte an|aus` schaltet das Ausblenden der Karte um.
- `/tweaks makros an|aus` schaltet das Ausblenden der Makronamen um.
- `/tweaks swing an|aus` schaltet den Swing-Timer um.
- Das Einstellungsfenster übernimmt Änderungen sofort. Neben dem Swing-Timer stehen Schriftgröße, Textfarbe und die Nachkommastellen (0, 1 oder 2).
- **Swing-Timer** zählt als Text bis zum nächsten eigenen Nahkampfschlag oder Fernkampfangriff herunter. Ohne laufenden Angriff bleibt er verborgen. Im Bearbeitungsmodus (Esc) lässt sich der Text verschieben; die Position wird pro Layout gespeichert.
- **Jäger Reichweitenindikator** zeigt nur am aktuellen feindlichen Ziel einen gefüllten Kreis links neben dem Lebensbalken: Rot außerhalb der Reichweite, Orange in Nahkampfreichweite und Grün in Auto-Schuss-Reichweite. Nahkampf wird mit einem 5-Yard-Gegenstandsreichweitentest geprüft, da Raptor Strike auf WoW Forever keine verlässliche Reichweitenabfrage liefert. Wenn der Client keinen eindeutigen Wert liefert, bleibt der Punkt verborgen.
