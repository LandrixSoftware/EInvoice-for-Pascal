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
    edk_SkippedExtension
  );

  { One diagnostic. Line, Column and Offset are 0 when there is no position
    (e.g. when writing).
    DE: Eine Meldung. Line, Column und Offset sind 0, wenn es keine Position
    gibt (z. B. beim Schreiben). }
  TLandrixEInvoiceDiagnostic = class(TObject)
  public
    Kind: TLandrixEInvoiceDiagnosticKind;
    { Element path, e.g. /rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:ID.
      DE: Elementpfad, z. B. /rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:ID. }
    Path: TLandrixEInvoiceString;
    Line: Integer;
    Column: Integer;
    Offset: Int64;
    { English message. DE: Meldungstext (englisch). }
    Message: TLandrixEInvoiceString;
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
    { All entries, one per line: "line:column kind path: message".
      DE: Alle Eintraege, einer je Zeile: "Zeile:Spalte Art Pfad: Text". }
    function ToText: TLandrixEInvoiceString;
  end;

{ Name of a kind for messages, e.g. 'UnknownElement'.
  DE: Name einer Art fuer Meldungen, z. B. 'UnknownElement'. }
function LandrixEInvoiceDiagnosticKindToStr(AKind: TLandrixEInvoiceDiagnosticKind): TLandrixEInvoiceString;

implementation

const
  KindNames: array[TLandrixEInvoiceDiagnosticKind] of TLandrixEInvoiceString = (
    'UnknownElement', 'DuplicateElement', 'UnexpectedText', 'UnknownAttribute',
    'InvalidValue', 'MissingElement', 'SkippedExtension');

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
      TLandrixEInvoiceString(IntToStr(D.Column)) + ' ' + KindNames[D.Kind] + ' ' +
      D.Path + ': ' + D.Message + #13#10;
  end;
end;

end.
