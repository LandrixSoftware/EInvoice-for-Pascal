# Sicherheit / Security

[Deutsch](#deutsch) | [English](#english)

## Deutsch

Stand: 15. Oktober 2026

### Eine Schwachstelle melden

Bitte melden Sie mögliche Sicherheitslücken in EInvoice-for-Pascal an
**[info@landrix.de](mailto:info@landrix.de)**, mit dem Betreff
`[Security] EInvoice-for-Pascal: kurze Beschreibung`.
Bitte eröffnen Sie für noch nicht behobene Schwachstellen zunächst kein öffentliches Issue
und veröffentlichen Sie keine ausnutzbaren Beispieldateien.

Hilfreich sind:

- Bibliotheksversion und möglichst Git-Commit (auch des Submoduls `external/landrix-xml`) sowie
  Angaben zu eigenen Änderungen.
- Compiler, Betriebssystem und Architektur.
- Betroffener Aufruf, aktivierte Optionen und gegebenenfalls Versionen externer Werkzeuge.
- Schritte zur Reproduktion, erwartetes und beobachtetes Verhalten sowie mögliche Auswirkungen.
- Eine minimale Beispieldatei mit künstlichen Daten; keine echten Rechnungen, Zugangsdaten oder
  personenbezogenen Daten.
- Hinweise auf eine bekannte aktive Ausnutzung und eine erreichbare Kontaktadresse, soweit möglich.

Für sensible Details zunächst nur eine kurze Beschreibung senden und einen geeigneten
Übertragungsweg abstimmen. Die E-Mail-Adresse ist ein privater Kontaktweg, keine Zusage einer
Ende-zu-Ende-verschlüsselten Übertragung oder einer rund um die Uhr besetzten Meldestelle.
Eine Meldung an das Projekt ersetzt keine gegebenenfalls erforderliche Behördenmeldung.

### Unterstützte Versionen und Bearbeitung

Das Projekt befindet sich in der Entwicklung; es gibt noch keine veröffentlichte Version und
keine Tabelle mit Sicherheits-Supportzeiträumen. Die unterstützten Compiler in der README
beschreiben technische Kompatibilität, keinen Sicherheits-Supportzeitraum.

Es werden hier keine festen Reaktionszeiten, Behebungsfristen oder Rückportierungen zugesagt.
Vertragliche Rechte und gesetzliche Pflichten bleiben unberührt; insbesondere ändert dieses
Dokument nicht die Lizenzbedingungen.

### Hinweise zur Integration

XML- und PDF-Eingaben sowie eingebettete Anhänge sind als nicht vertrauenswürdig zu behandeln.
Der XML-Parser verarbeitet keine DTDs und keine externen Entitäten und begrenzt die
Verschachtelungstiefe. Hersteller der einbindenden Anwendung sollten dennoch Ressourcenlimits,
Dateizugriffe und den Aufruf externer Werkzeuge prüfen. Rechnungsvalidierung ersetzt diese
Prüfungen nicht.

## English

As of 15 October 2026

### Reporting a vulnerability

Please report potential security vulnerabilities in EInvoice-for-Pascal to
**[info@landrix.de](mailto:info@landrix.de)**, using the subject
`[Security] EInvoice-for-Pascal: short description`.
Please do not initially open a public issue for an unresolved vulnerability or publish
files that demonstrate how to exploit it.

Useful information includes:

- Library version and preferably Git commit (including the `external/landrix-xml` submodule),
  together with details of local modifications.
- Compiler, operating system and architecture.
- Affected API call, enabled options and versions of any external tools involved.
- Reproduction steps, expected and observed behaviour, and potential impact.
- A minimal sample using synthetic data; no real invoices, credentials or personal data.
- Any known active exploitation and a contact address, where possible.

For sensitive details, initially send only a brief description and agree on a suitable
transfer method. The email address is a private contact channel, not a promise of end-to-end
encrypted transmission or a reporting service staffed around the clock.
Reporting to the project does not replace any required report to authorities.

### Supported versions and handling

The project is under development; there is no published release yet and no table of security
support periods. The supported compilers listed in the README describe technical
compatibility, not a security support period.

This document does not promise fixed response times, remediation deadlines or backports.
Contractual rights and statutory obligations remain unaffected; in particular, this document
does not change licence terms.

### Integration guidance

Treat XML and PDF input and embedded attachments as untrusted. The XML parser does not process
DTDs or external entities and limits the nesting depth. Manufacturers integrating the library
should still review resource limits, file access and external tool invocation. Invoice
validation does not replace these checks.
