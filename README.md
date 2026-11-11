# SimpleTweaks

Ein kleines Addon für World of Warcraft: Forever mit einem bronzefarbenen Einstellungsfenster. Es bietet:

- Die Weltkarte beim Bewegen sichtbar halten.
- Makronamen auf den Blizzard-Aktionsleisten ausblenden.
- Eine durchsuchbare Liste der vom Client gemeldeten Konsolenbefehle; CVar-Einträge lassen sich anklicken und bearbeiten.
- Eine Grafikseite mit Reglern für Gras, Sichtweite, Beleuchtung, Sonnenstrahlen und Schatten.

Beide Funktionen sind standardmäßig aktiv und werden gespeichert.

## Install

Kopiere den Ordner `SimpleTweaks` in `World of Warcraft/_forever_/Interface/AddOns`. Starte das Spiel neu oder verwende `/reload`.

Die TOC-Datei richtet sich an WoW Forever Interface `16001`.

## Use

Öffne das Einstellungsfenster über das Addon-Kompartiment oben rechts oder mit `/tweaks`.

- `/tweaks karte an|aus` schaltet das Ausblenden der Karte um.
- `/tweaks makros an|aus` schaltet das Ausblenden der Makronamen um.
- Die Checkboxen im Fenster übernehmen Änderungen sofort.
- Im **CVar-Browser** kannst du Konsolenbefehle nach Namen oder Beschreibung durchsuchen. Erkennbare CVars zeigen ihren aktuellen Wert und lassen sich per Klick bearbeiten.
- **Grafik** enthält Regler für `groundEffectDensity`, `groundEffectDist`, `graphicsGroundClutter`, `graphicsViewDistance`, `graphicsLightMode`, `sunshafts` und `shadowNumCascades`.

Die Grafikregler verwenden praktische Wertebereiche. Für `groundEffectDist` ist 600 als allgemeiner Maximalwert dokumentiert, für `graphicsGroundClutter` ist der allgemeine Reglerbereich 0–9 dokumentiert. Diese Grenzen sind nicht eigens im WoW-Forever-Client verifiziert. Auch die übrigen Reglerobergrenzen sind im Client nicht verifiziert; die angezeigten Grenzen sind keine Zusicherung der tatsächlichen Engine-Maxima.
