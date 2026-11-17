# LCNC-Cyclo – Installation für Tester

Dieses Repo enthält nur das Installationsskript. LCNC-Cyclo selbst liegt in einem privaten Repo,
für das jeder Tester einen eigenen Lesezugang bekommt.

Voraussetzung: Debian 13 (Trixie), nativ oder unter WSL2 auf Windows. Das Skript baut LinuxCNC
mit LCNC-Cyclo in einem eigenen Ordner (`~/lcnc-cyclo`). Ein schon installiertes LinuxCNC bleibt
unberührt, beide sollten aber nicht gleichzeitig laufen.

## Installation

Skript holen und ausführbar machen:

    cd ~
    wget https://raw.githubusercontent.com/Slayer1000/lcnc-cyclo-tester/main/lcnc-cyclo-tester.sh
    chmod +x lcnc-cyclo-tester.sh

Starten (als normaler Benutzer, nicht als root):

    ./lcnc-cyclo-tester.sh

Beim ersten Start erzeugt das Skript einen Zugangsschlüssel und zeigt eine Zeile an, die mit
`ssh-ed25519` beginnt. Unter WSL liegt sie schon in der Windows-Zwischenablage. Diese Zeile an den
Projektverantwortlichen schicken und warten, bis der Zugang freigeschaltet ist.

Danach im Skript Enter drücken oder es später einfach noch einmal starten. Sobald das Repo
erreichbar ist, holt das Skript alles, installiert die nötigen Pakete und baut LinuxCNC mit
LCNC-Cyclo. Das dauert beim ersten Mal je nach Rechner 10 bis 30 Minuten.

Anderer Zielordner:

    CYCLO_DIR=~/test/lcnc-cyclo ./lcnc-cyclo-tester.sh

Nur prüfen, ob der Zugang klappt:

    ./lcnc-cyclo-tester.sh --check

## Starten

    cyclo-mock         Oberfläche ohne LinuxCNC, schnellster Test
    cyclo-MikronSIM    Simulation einer Mikron VCE 1000 (XYZ mit B-Schwenkkopf)
    cyclo-4achs        Simulation 4 Achsen
    cyclo-5achs        Simulation 5 Achsen

Aktualisieren:

    cyclo-update

## Entfernen

    rm -rf ~/lcnc-cyclo
    rm -f ~/.local/bin/cyclo-* && sudo rm -f /usr/local/bin/cyclo-*

Der Zugangsschlüssel liegt in `~/.ssh/lcnc_cyclo_ed25519` und kann ebenfalls gelöscht werden.

## Hinweise

- Ist im eigenen Netz Port 22 gesperrt, weicht das Skript selbst auf Port 443 aus.
- Eigene Maschinenkonfigurationen nur als Kopie mit `cyclo-start <ini>` starten, weil LCNC-Cyclo
  in die INI schreibt.
- Rückmeldungen und Fehler bitte im Discord melden.
