# SimpleTweaks

Ein kleines Addon für World of Warcraft: Forever mit einem bronzefarbenen Einstellungsfenster. Es bietet:

- Die Weltkarte beim Bewegen sichtbar halten.
- Makronamen auf den Blizzard-Aktionsleisten ausblenden.
- Die Haltungsanzeige ausblenden.
- Bei freundlichen NSCs Lebensbalken und Stufenanzeige ausblenden. Der Name bleibt der von Blizzard. Spieler, Feinde und neutrale Einheiten bleiben unverändert.
- Einen Reichweitenpunkt am aktuellen Ziel für Jäger anzeigen.
- Einen dauerhaften FPS-Zähler unten rechts anzeigen, den normalen von Blizzard. Im deutschen Client steht dort FPS statt BPS.
- Combo-Punkte unter der feindlichen Namensplakette als rote Kreise mit 1px schwarzem Rand anzeigen.
- FarmHUD zeigt die Minimap-Markierungen ohne Gelände in der Bildschirmmitte.
- Einen Schwungtimer als Kreis.
- Die 5-Sekunden-Regel als Kreis: nach einem Zauber, der Mana kostet, zählt er 5 Sekunden herunter, bis die Spirit-Regeneration wieder einsetzt. Manafreie Zauber lösen sie nicht aus.

Die Karten- und Makro-Funktionen sind standardmäßig aktiv. Haltungsanzeige, NSC-Namen, FPS-Anzeige, Combo-Punkte, Reichweitenindikator, FarmHUD, Schwungtimer und 5-Sekunden-Regel sind standardmäßig ausgeschaltet. Einstellungen werden gespeichert.

## Install

Kopiere den Ordner `SimpleTweaks` in `World of Warcraft/_forever_/Interface/AddOns`. Starte das Spiel neu oder verwende `/reload`.

Die TOC-Datei richtet sich an WoW Forever Interface `16001`.

Die Funktionen liegen in eigenen Dateien: `SimpleTweaksMap`, `SimpleTweaksMacros`, `SimpleTweaksStance`, `SimpleTweaksFps`, `SimpleTweaksRange`, `SimpleTweaksNpc`, `SimpleTweaksCombo`, `SimpleTweaksSwing`, `SimpleTweaksFiveSec`, `SimpleTweaksFarmHud` und `SimpleTweaksOptions`. `SimpleTweaks.lua` hält nur die gemeinsamen Helfer, `SimpleTweaksEvents.lua` die Ereignisse.

## Use

Öffne das Einstellungsfenster über das Addon-Kompartiment oben rechts oder mit `/tweaks`.

- `/tweaks karte an|aus` schaltet das Ausblenden der Karte um.
- `/tweaks makros an|aus` schaltet das Ausblenden der Makronamen um.
- `/tweaks haltung an|aus` schaltet das Ausblenden der Haltungsanzeige um.
- `/tweaks nsc an|aus` blendet bei freundlichen NSCs Lebensbalken und Stufenanzeige aus.
- `/tweaks fps an|aus` schaltet die FPS-Anzeige unten rechts um. Die Einstellung bleibt nach `/reload` und erneutem Einloggen erhalten.
- `/tweaks combo an|aus` zeigt Combo-Punkte als rote Kreise unter der feindlichen Namensplakette.
- Die Checkbox **FarmHUD** blendet den Umschalter ein oder aus. Ein Linksklick auf den Umschalter verschiebt die Minimap in die Bildschirmmitte und der nächste Linksklick bringt sie zurück. Die aktiven Kräuter-, Erz- und Questmarkierungen bleiben sichtbar. Außerhalb des Umschalters gehen Klicks und das Mausrad durch das HUD hindurch. Mit **Einstellungen** lässt sich die Größe wählen. Ein Wechsel im Kampf wird bis zum Kampfende vorgemerkt.
- Mit der rechten Maustaste lässt sich der FarmHUD-Umschalter am normalen Minimap-Rand entlangziehen und bei aktiver Projektion frei platzieren. Beide Positionen werden separat gespeichert.
- In den FarmHUD-Einstellungen kann der Spielerpfeil oben bleiben, während sich die Karte mit der Blickrichtung dreht. Beim Schließen des HUDs wird die vorherige Minimap-Ausrichtung wiederhergestellt.
- `/tweaks schwung an|aus` schaltet den Schwungtimer um.
- `/tweaks regel an|aus` schaltet die 5-Sekunden-Regel um.
- Die Kreiseinstellungen von Schwungtimer und 5-Sekunden-Regel stehen nicht mehr im Hauptfenster. Neben der Checkbox öffnet **Einstellungen** ein kleines Fenster dafür.
- Im Bearbeitungsmodus erscheinen nur die aktivierten Timer.
- Das Einstellungsfenster übernimmt Änderungen sofort und ist auf Deutsch. Neben den Schwungtimer-Einstellungen steht **Vorschau** in einem kleinen, etwas helleren Kasten im Hauptfenster.
- **Schwungtimer** zeigt einen Kreis bis zum nächsten eigenen Nahkampfschlag oder Fernkampfangriff. Eine Linie auf dem Radius dreht sich um die Mitte: **Abnehmend** leert den Kreis, **Zunehmend** füllt ihn. Die Füllung läuft dabei von halber Deckkraft bis ganz deckend; diese Deckkraft wird mit der eigenen Füllfarbe multipliziert. Füllfarbe, Rand und Hintergrund haben je eine Farbe mit eigener Deckkraft. **Rahmen** stellt die Randdicke ein, **Linie** die Deckkraft der Radiuslinie und **Dicke** ihre Strichstärke. **Funke** ist ein eigener Glanzpunkt am Ende dieser Linie und ändert die Linie nicht. Die Standardgröße entspricht dem Reichweitenpunkt. Ohne laufenden Angriff bleibt die Anzeige verborgen. Im Bearbeitungsmodus (Esc) lässt sich der Kreis verschieben; sein Mittelpunkt ist der Anker und bleibt beim Schließen an derselben Stelle. Die Position wird pro Layout gespeichert.
- **Jäger Reichweitenindikator** zeigt nur am aktuellen feindlichen Ziel einen gefüllten Kreis links neben dem Lebensbalken: Rot außerhalb der Reichweite, Orange in Nahkampfreichweite und Grün in Auto-Schuss-Reichweite. Nahkampf wird mit einem 5-Yard-Gegenstandsreichweitentest geprüft, da Raptor Strike auf WoW Forever keine verlässliche Reichweitenabfrage liefert. Wenn der Client keinen eindeutigen Wert liefert, bleibt der Punkt verborgen.
