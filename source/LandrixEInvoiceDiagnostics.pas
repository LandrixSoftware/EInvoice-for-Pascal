{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Diagnostics of readers and writers: what was skipped, duplicated, could
  not be converted or is missing, with the position in the document. Readers
  and writers add entries and continue; they never raise for these cases.

  DE: Meldungen von Lesern und Schreibern: was uebersprungen wurde, doppelt
  vorkam, nicht umgewandelt werden konnte oder fehlt, mit der Position im
  Dokument. Leser und Schreiber fuegen Eintraege hinzu und arbeiten weiter;
  in diesen Faellen loesen sie keine Ausnahme aus. }

unit LandrixEInvoiceDiagnostics;

{$I LandrixEInvoice.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixEInvoiceTypes;

type
  { Kind of a diagnostic.
    DE: Art einer Meldung. }
  TLandrixEInvoiceDiagnosticKind = (
    { An element the model does not know; it was skipped.
      DE: Ein Element, das das Modell nicht kennt; es wurde uebersprungen. }
    edk_UnknownElement,
    { A second occurrence of an element that may occur only once; the first
      one is kept, the others are skipped.
      DE: Ein zweites Vorkommen eines Elements, das nur einmal vorkommen
      darf; das erste gilt, die weiteren werden uebersprungen. }
    edk_DuplicateElement,
    { Text where only elements are allowed; it was ignored.
      DE: Text, wo nur Elemente erlaubt sind; er wurde ignoriert. }
    edk_UnexpectedText,
    { An attribute the model does not know; it was ignored.
      DE: Ein Attribut, das das Modell nicht kennt; es wurde ignoriert. }
    edk_UnknownAttribute,
    { A value that does not match its type (e.g. no decimal number); the
      text is kept as it was read.
      DE: Ein Wert, der nicht zu seinem Typ passt (z. B. keine Dezimalzahl);
      der Text bleibt wie gelesen erhalten. }
    edk_InvalidValue,
    { A required element or attribute is missing.
      DE: Ein Pflichtelement oder Pflichtattribut fehlt. }
    edk_MissingElement,
    { An extension block (UBL ext:UBLExtensions, e.g. a signature) that the
      model does not keep; it was skipped as a whole and is never written.
      DE: Ein Erweiterungsblock (UBL ext:UBLExtensions, z. B. eine Signatur),
      den das Modell nicht behaelt; er wurde als Ganzes uebersprungen und
      wird nie geschrieben. }
    edk_SkippedExtension,
    { Mapping: a text that is present could not be converted into the typed
      field of the invoice model (e.g. '19,00' as an amount, an invalid
      date); the field keeps its "not set" value. Also used when a value
      had to be rounded.
      DE: Abbildung: ein vorhandener Text liess sich nicht in das
      typisierte Feld des Rechnungsmodells umwandeln (z. B. '19,00' als
      Betrag, ein ungueltiges Datum); das Feld bleibt "nicht gesetzt". Auch
      wenn ein Wert gerundet werden musste. }
    edk_ConversionFailed,
    { Mapping: a well-formed code that the code list does not know; it is
      kept in the ...Other field next to the enumeration.
      DE: Abbildung: ein formal gueltiger Code, den die Codeliste nicht
      kennt; er bleibt im Feld ...Other neben der Aufzaehlung erhalten. }
    edk_UnknownCode,
    { Mapping: content of the syntax model that the invoice model has no
      place for; it remains available in the syntax model only.
      DE: Abbildung: Inhalt des Syntaxmodells, fuer den das Rechnungsmodell
      keinen Platz hat; er bleibt nur im Syntaxmodell erhalten. }
    edk_NotMapped,
    { Mapping: content of the invoice model that the target specification
      does not allow; it was left out.
      DE: Abbildung: Inhalt des Rechnungsmodells, den die
      Zielspezifikation nicht erlaubt; er wurde weggelassen. }
    edk_NotAllowed,
    { Check: the invoice violates a business rule of the target (RuleID
      names it, e.g. BR-DE-15; LX-... for rules of this library).
      DE: Pruefung: die Rechnung verletzt eine Geschaeftsregel des Ziels
      (RuleID nennt sie, z. B. BR-DE-15; LX-... fuer Regeln dieser
      Bibliothek). }
    edk_RuleViolation
  );

  { How serious a diagnostic is. Errors mean that data was lost or the
    output is invalid.
    DE: Wie schwer eine Meldung wiegt. Fehler bedeuten, dass Daten verloren
    gingen oder die Ausgabe ungueltig ist. }
  TLandrixEInvoiceDiagnosticSeverity = (
    { Information only, nothing is lost. DE: Nur zur Information, nichts
      geht verloren. }
    eds_Info,
    { Something was skipped, ignored or adjusted.
      DE: Etwas wurde uebersprungen, ignoriert oder angepasst. }
    eds_Warning,
    { Data was lost or the output is invalid.
      DE: Daten gingen verloren oder die Ausgabe ist ungueltig. }
    eds_Error
  );

  { One diagnostic. Line, Column and Offset are 0 when there is no position
    (e.g. when writing).
    DE: Eine Meldung. Line, Column und Offset sind 0, wenn es keine Position
    gibt (z. B. beim Schreiben). }
  TLandrixEInvoiceDiagnostic = class(TObject)
  public
    Kind: TLandrixEInvoiceDiagnosticKind;
    { Set from the kind (LandrixEInvoiceDiagnosticDefaultSeverity); may be
      changed by the code that adds the entry.
      DE: Wird aus der Art gesetzt (LandrixEInvoiceDiagnosticDefaultSeverity);
      der Code, der den Eintrag anlegt, darf sie aendern. }
    Severity: TLandrixEInvoiceDiagnosticSeverity;
    { Element path, e.g. /rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:ID.
      DE: Elementpfad, z. B. /rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:ID. }
    Path: TLandrixEInvoiceString;
    Line: Integer;
    Column: Integer;
    Offset: Int64;
    { English message. DE: Meldungstext (englisch). }
    Message: TLandrixEInvoiceString;
    { Identifier of the violated rule (edk_RuleViolation, e.g. BR-DE-15 or
      LX-CC-04); '' for the other kinds. Rule identifiers are stable.
      DE: Kennung der verletzten Regel (edk_RuleViolation, z. B. BR-DE-15
      oder LX-CC-04); '' bei den anderen Arten. Regelkennungen sind
      stabil. }
    RuleID: TLandrixEInvoiceString;
  end;

  { List of diagnostics (owns its entries).
    DE: Liste von Meldungen (besitzt ihre Eintraege). }
  TLandrixEInvoiceDiagnostics = class(TObjectList)
  protected
    function GetItem(Index: TLandrixEInvoiceListIndex): TLandrixEInvoiceDiagnostic;
  public
    property Items[Index: TLandrixEInvoiceListIndex]: TLandrixEInvoiceDiagnostic read GetItem; default;
    { Adds an entry and returns it. DE: Fuegt einen Eintrag hinzu und liefert
      ihn. }
    function AddDiagnostic(AKind: TLandrixEInvoiceDiagnosticKind;
      const APath: TLandrixEInvoiceString; ALine, AColumn: Integer; AOffset: Int64;
      const AMessage: TLandrixEInvoiceString): TLandrixEInvoiceDiagnostic;
    { Number of entries of one kind. DE: Anzahl der Eintraege einer Art. }
    function CountOf(AKind: TLandrixEInvoiceDiagnosticKind): Integer;
    { True if an entry has the severity eds_Error.
      DE: True, wenn ein Eintrag die Schwere eds_Error hat. }
    function HasErrors: Boolean;
    { All entries, one per line: "line:column kind path: message", with
      " [rule]" after the kind when RuleID is set.
      DE: Alle Eintraege, einer je Zeile: "Zeile:Spalte Art Pfad: Text",
      mit " [Regel]" nach der Art, wenn RuleID gesetzt ist. }
    function ToText: TLandrixEInvoiceString;
  end;

{ Default severity of a kind: eds_Error for edk_MissingElement,
  edk_ConversionFailed and edk_RuleViolation (invalid output, lost value;
  a rule check sets the severity of its rule), eds_Info for
  edk_UnknownCode, eds_Warning otherwise. Content a target does not allow
  (edk_NotAllowed) is a warning: it is left out and the output stays
  valid, so one invoice can be written to several targets.
  DE: Standard-Schwere einer Art: eds_Error fuer edk_MissingElement,
  edk_ConversionFailed und edk_RuleViolation (ungueltige Ausgabe, verlorener
  Wert; eine Regelpruefung setzt die Schwere ihrer Regel), eds_Info fuer
  edk_UnknownCode, sonst eds_Warning. Inhalt, den ein Ziel nicht erlaubt
  (edk_NotAllowed), ist eine Warnung: er wird weggelassen und die Ausgabe
  bleibt gueltig, so laesst sich eine Rechnung in mehrere Ziele
  schreiben. }
function LandrixEInvoiceDiagnosticDefaultSeverity(
  AKind: TLandrixEInvoiceDiagnosticKind): TLandrixEInvoiceDiagnosticSeverity;

{ Name of a kind for messages, e.g. 'UnknownElement'.
  DE: Name einer Art fuer Meldungen, z. B. 'UnknownElement'. }
function LandrixEInvoiceDiagnosticKindToStr(AKind: TLandrixEInvoiceDiagnosticKind): TLandrixEInvoiceString;

implementation

const
  KindNames: array[TLandrixEInvoiceDiagnosticKind] of TLandrixEInvoiceString = (
    'UnknownElement', 'DuplicateElement', 'UnexpectedText', 'UnknownAttribute',
    'InvalidValue', 'MissingElement', 'SkippedExtension', 'ConversionFailed',
    'UnknownCode', 'NotMapped', 'NotAllowed', 'RuleViolation');

  DefaultSeverities: array[TLandrixEInvoiceDiagnosticKind] of TLandrixEInvoiceDiagnosticSeverity = (
    eds_Warning, eds_Warning, eds_Warning, eds_Warning, eds_Warning, eds_Error, eds_Warning,
    eds_Error, eds_Info, eds_Warning, eds_Warning, eds_Error);

function LandrixEInvoiceDiagnosticDefaultSeverity(
  AKind: TLandrixEInvoiceDiagnosticKind): TLandrixEInvoiceDiagnosticSeverity;
begin
  Result := DefaultSeverities[AKind];
end;

function LandrixEInvoiceDiagnosticKindToStr(AKind: TLandrixEInvoiceDiagnosticKind): TLandrixEInvoiceString;
begin
  Result := KindNames[AKind];
end;

function TLandrixEInvoiceDiagnostics.GetItem(Index: TLandrixEInvoiceListIndex): TLandrixEInvoiceDiagnostic;
begin
  Result := TLandrixEInvoiceDiagnostic(inherited Items[Index]);
end;

function TLandrixEInvoiceDiagnostics.AddDiagnostic(AKind: TLandrixEInvoiceDiagnosticKind;
  const APath: TLandrixEInvoiceString; ALine, AColumn: Integer; AOffset: Int64;
  const AMessage: TLandrixEInvoiceString): TLandrixEInvoiceDiagnostic;
begin
  Result := TLandrixEInvoiceDiagnostic.Create;
  Result.Kind := AKind;
  Result.Severity := DefaultSeverities[AKind];
  Result.Path := APath;
  Result.Line := ALine;
  Result.Column := AColumn;
  Result.Offset := AOffset;
  Result.Message := AMessage;
  Add(Result);
end;

function TLandrixEInvoiceDiagnostics.CountOf(AKind: TLandrixEInvoiceDiagnosticKind): Integer;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    if Items[I].Kind = AKind then
      Inc(Result);
end;

function TLandrixEInvoiceDiagnostics.HasErrors: Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to Count - 1 do
    if Items[I].Severity = eds_Error then
      Exit;
  Result := False;
end;

function TLandrixEInvoiceDiagnostics.ToText: TLandrixEInvoiceString;
var
  I: TLandrixEInvoiceListIndex;
  D: TLandrixEInvoiceDiagnostic;
begin
  Result := '';
  for I := 0 to Count - 1 do
  begin
    D := Items[I];
    Result := Result + TLandrixEInvoiceString(IntToStr(D.Line)) + ':' +
      TLandrixEInvoiceString(IntToStr(D.Column)) + ' ' + KindNames[D.Kind];
    if D.RuleID <> '' then
      Result := Result + ' [' + D.RuleID + ']';
    Result := Result + ' ' + D.Path + ': ' + D.Message + #13#10;
  end;
end;

end.
