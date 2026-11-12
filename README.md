# SimpleTweaks

Ein kleines Addon für World of Warcraft: Forever mit einem bronzefarbenen Einstellungsfenster. Es bietet:

- Die Weltkarte beim Bewegen sichtbar halten.
- Makronamen auf den Blizzard-Aktionsleisten ausblenden.
- Einen Reichweitenpunkt am aktuellen Ziel für Jäger anzeigen.
- Einen Schwungtimer, entweder als Text oder als Kreis.

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
- **Schwungtimer** zählt bis zum nächsten eigenen Nahkampfschlag oder Fernkampfangriff. Die Darstellung ist ein Text oder ein Kreis. Der Kreis ist ein Kuchen, abnehmend oder zunehmend, von halber Deckkraft bis ganz deckend. Rand, Füllfarbe, Größe und ein Funke an der Drehkante lassen sich einstellen. Die Standardgröße entspricht dem Reichweitenpunkt. Ohne laufenden Angriff bleibt die Anzeige verborgen. Text und Kreis sitzen an derselben Stelle und lassen sich im Bearbeitungsmodus (Esc) verschieben; die Position wird pro Layout gespeichert.
- **Jäger Reichweitenindikator** zeigt nur am aktuellen feindlichen Ziel einen gefüllten Kreis links neben dem Lebensbalken: Rot außerhalb der Reichweite, Orange in Nahkampfreichweite und Grün in Auto-Schuss-Reichweite. Nahkampf wird mit einem 5-Yard-Gegenstandsreichweitentest geprüft, da Raptor Strike auf WoW Forever keine verlässliche Reichweitenabfrage liefert. Wenn der Client keinen eindeutigen Wert liefert, bleibt der Punkt verborgen.
