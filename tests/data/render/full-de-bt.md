# Rechnung

## Rechnungsangaben

- **Rechnungsnummer (BT-1):** R-2026-0815
- **Rechnungsdatum (BT-2):** 12.11.2026
- **Rechnungsart (BT-3):** Handelsrechnung (380)
- **Fälligkeitsdatum (BT-9):** 12.12.2026
- **Abrechnungszeitraum von (BT-73):** 01.10.2026
- **Abrechnungszeitraum bis (BT-74):** 31.10.2026
- **Rechnungswährung (BT-5):** Euro (EUR)
- **Käuferreferenz (BT-10):** 04011000-12345-34
- **Geschäftsprozess (BT-23):** urn:fdc:peppol.eu:2017:poacc:billing:01:1.0

## Beteiligte

### Verkäufer (BG-4)

- **Name (BT-27):** Muster \& Söhne GmbH
- **Straße (BT-35):** Hauptstraße 1
- **Postleitzahl (BT-38):** 10115
- **Ort (BT-37):** Berlin
- **Land (BT-40):** Deutschland (DE)
- **Umsatzsteuer-Identifikationsnummer (BT-31):** DE123456789
- **Elektronische Adresse (BT-34):** rechnung@example.com
- **Schema der elektronischen Adresse (BT-34-1):** Electronic mail (SMPT) (EM)
- **Ansprechpartner (BT-41):** Erika Muster
- **Telefon (BT-42):** +49 30 123456

### Käufer (BG-7)

- **Name (BT-44):** Beispiel AG
- **Straße (BT-50):** Ringweg 7
- **Postleitzahl (BT-53):** 80331
- **Ort (BT-52):** München
- **Land (BT-55):** Deutschland (DE)
- **Elektronische Adresse (BT-49):** einkauf@example.org
- **Schema der elektronischen Adresse (BT-49-1):** Electronic mail (SMPT) (EM)

### Zahlungsempfänger (BG-10)

- **Name (BT-59):** Factoring Bank

### Lieferung (BG-13)

- **Ort (BT-77):** Hamburg
- **Land (BT-80):** Deutschland (DE)
- **Lieferdatum (BT-72):** 20.10.2026

## Bezüge

- **Bestellnummer (BT-13):** B-4711
- **Vertragsnummer (BT-12):** V-2025-17

## Rechnungspositionen

* **Position (BT-126):** 1
  - **Artikel (BT-153):** Beratung
  - **Menge (BT-129):** 16
  - **Einheit (BT-130):** Stunde (HUR)
  - **Nettopreis (BT-146):** 95,00
  - **Steuerkategorie (BT-151):** Normalsatz (S)
  - **Steuersatz (BT-152):** 19 %
  - **Nettobetrag (BT-131):** 1.368,00
  - **Artikelbeschreibung (BT-154):**
    ```
    Workshop vor Ort,
    zwei Tage
    ```
  - **Artikelnummer des Verkäufers (BT-155):** SRV-01
  - **Abschläge und Zuschläge (BG-27/BG-28)**
    * **Abschlag oder Zuschlag:** Abschlag
      - **Grund (Code) (BT-140):** Rabatt (95)
      - **Grund (BT-139):** Rabatt
      - **Basisbetrag (BT-137):** 1.520,00
      - **Prozentsatz (BT-138):** 10 %
      - **Betrag (BT-136):** 152,00
  - **Artikeleigenschaften (BG-32)**
    * **Eigenschaft (BT-160):** Ort
      - **Wert (BT-161):** Berlin
* **Position (BT-126):** 2
  - **Artikel (BT-153):** Material
  - **Menge (BT-129):** 1
  - **Einheit (BT-130):** Einheit (C62)
  - **Nettopreis (BT-146):** 200,00
  - **Steuerkategorie (BT-151):** Normalsatz (S)
  - **Steuersatz (BT-152):** 7 %
  - **Nettobetrag (BT-131):** 200,00
  * **Position (BT-126):** 2.1
    - **Artikel (BT-153):** Kabel
    - **Menge (BT-129):** 12,5
    - **Einheit (BT-130):** Stück (H87)
    - **Nettopreis (BT-146):** 8,00
    - **Steuerkategorie (BT-151):** Normalsatz (S)
    - **Steuersatz (BT-152):** 7 %
    - **Nettobetrag (BT-131):** 100,00
  * **Position (BT-126):** 2.2
    - **Artikel (BT-153):** Stecker
    - **Menge (BT-129):** 50
    - **Einheit (BT-130):** Stück (H87)
    - **Nettopreis (BT-146):** 2,00
    - **Steuerkategorie (BT-151):** Normalsatz (S)
    - **Steuersatz (BT-152):** 7 %
    - **Nettobetrag (BT-131):** 100,00

## Abschläge und Zuschläge

* **Abschlag oder Zuschlag:** Zuschlag
  - **Grund (Code) (BT-105):** Fracht (FC)
  - **Grund (BT-104):** Versand
  - **Betrag (BT-99):** 10,00
  - **Steuerkategorie (BT-102):** Normalsatz (S)
  - **Steuersatz (BT-103):** 19 %

## Umsatzsteueraufschlüsselung

* **Steuerkategorie (BT-118):** Normalsatz (S)
  - **Steuersatz (BT-119):** 19 %
  - **Steuerbemessungsgrundlage (BT-116):** 1.378,00
  - **Steuerbetrag (BT-117):** 261,82
* **Steuerkategorie (BT-118):** Normalsatz (S)
  - **Steuersatz (BT-119):** 7 %
  - **Steuerbemessungsgrundlage (BT-116):** 200,00
  - **Steuerbetrag (BT-117):** 14,00

## Summen

- **Summe der Positionsnettobeträge (BT-106):** 1.568,00 EUR
- **Summe der Zuschläge (BT-108):** 10,00 EUR
- **Gesamtbetrag ohne Umsatzsteuer (BT-109):** 1.578,00 EUR
- **Umsatzsteuer gesamt (BT-110):** 275,82 EUR
- **Gesamtbetrag mit Umsatzsteuer (BT-112):** 1.853,82 EUR
- **Bereits gezahlt (BT-113):** 53,82 EUR
- **Zahlbetrag (BT-115):** 1.800,00 EUR

## Zahlung

- **Verwendungszweck (BT-83):** R-2026-0815
- **Gläubiger-Identifikationsnummer (BT-90):** DE98ZZZ09999999999

**Zahlungsanweisungen (BG-16)**

* **Zahlungsart (BT-81):** SEPA-Überweisung (58)
  - **Konto (BT-84/BT-91/BT-87):** DE02120300000000202051
  - **Kontoinhaber (BT-85/BT-88):** Muster \& Söhne GmbH
  - **BIC (BT-86):** BYLADEM1001

- **Zahlungsbedingungen:** ein Skonto
- **Skonto 1: Tage:** 10
- **Skonto 1: Prozent:** 2 %
- **Skonto 1: Basisbetrag:** 1.853,82 EUR

## Bemerkungen

* **Betreff (BT-21):** General information (AAI)
  - **Bemerkung (BT-22):** Vielen Dank für Ihren Auftrag.

## Rechnungsbegründende Unterlagen

* **Dokumentkennung (BT-17/BT-18/BT-122):** Stundenzettel
  - **Dokumentart (BT-17/BT-18/BT-122):** 916
  - **Beschreibung (BT-123):** Stundennachweis Oktober
  - **Dateiname (BT-125-2):** stunden.pdf
  - **MIME-Typ (BT-125-1):** application/pdf
  - **Eingebettete Datei (BT-125):** 13 Bytes

---

Erstellt mit EInvoice-for-Pascal @VERSION@
