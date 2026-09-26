# Antwort an App Review (Resolution Center)

Einreichung 6755e3e4-fccc-439e-a141-2a7deae6af40 · Guideline 2.3.6 · Build 1.0 (7)
→ behoben durch Metadaten-Änderung, **kein neuer Build nötig**

## Was war los

In der Altersfreigabe war „Parental Controls" angehakt. Die App hat zwar eine Eltern-PIN,
sie schützt aber nur den Menüpunkt „Elternkontrolle" — und der Schalter zum Setzen der PIN
erscheint erst, wenn bereits eine Familien-Verbindung zu einem zweiten Gerät besteht.
Mit nur einem Gerät war die Funktion für den Reviewer nicht auffindbar.

Die Angabe steht jetzt auf „None" (per API gesetzt, in App Store Connect sichtbar).

## Text zum Kopieren

```
Hello,

thank you for pointing this out.

You are right — the app does not provide parental controls in the sense of the age rating
question. It has an optional PIN, but that PIN only protects one settings entry (the family
connection), and it is not a content or feature restriction.

We have therefore updated the Age Rating and set "Parental Controls" to "None", as you
suggested. No other age rating selections are set.

No binary change was needed, so build 1.0 (7) is unchanged and ready for review.

Thank you for your time.

Kind regards
Ralf Lohrmann
```

## Für Version 1.1 vorgemerkt

Der Schalter „Eltern-PIN festlegen" hängt heute an `appMode == .student && familyLink != nil`.
Das ist auch für echte Nutzer falsch: Man kann die PIN erst setzen, wenn die Verbindung schon
steht — dann ist es zu spät. Der Punkt gehört unabhängig davon in die Einstellungen.
