{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Shared business layer of the mappings, independent of the syntax: sub
  invoice line structure, the XRechnung text form of payment terms and
  rules that UBL and CII share, and the calculation of line amounts and
  totals on request. Totals are never recalculated implicitly; the mappings
  write the totals of the invoice model as they are.

  DE: Gemeinsame Fachschicht der Abbildungen, unabhaengig von der Syntax:
  Struktur der Unterpositionen, die XRechnung-Textform der
  Zahlungsbedingungen, Regeln, die UBL und CII teilen, und die Berechnung
  von Positionsbetraegen und Summen auf Aufruf. Summen werden nie
  stillschweigend neu berechnet; die Abbildungen schreiben die Summen des
  Rechnungsmodells unveraendert. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceCalc;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  Contnrs,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceInvoice;

{ Line status (BT-X-8) of a line: a value set in the model wins; otherwise
  a line with sub lines is a group (GROUP) and a sub line without sub lines
  is a detail line (DETAIL); a top-level line without sub lines has none.
  DE: Positionsstatus (BT-X-8) einer Position: ein im Modell gesetzter Wert
  gewinnt; sonst ist eine Position mit Unterpositionen eine Gruppe (GROUP)
  und eine Unterposition ohne Unterpositionen eine Detailposition (DETAIL);
  eine Position der obersten Ebene ohne Unterpositionen hat keinen. }
function LandrixEInvoiceLineStatusOf(ALine: TLandrixInvoiceLine;
  AIsSubLine: Boolean): TLandrixInvoiceLineStatusReasonCode;

{ Payment terms as one text (BT-20) in the form XRechnung uses: one line
  per cash discount '#SKONTO#TAGE=n#PROZENT=p#[BASISBETRAG=b#]', each ended
  by LF, followed by the net note with '#' replaced by blanks (BR-DE-18
  allows free text after the discount lines). '' if the invoice has no
  payment terms text.
  DE: Zahlungsbedingungen als ein Text (BT-20) in der Form, die XRechnung
  verwendet: eine Zeile je Skonto '#SKONTO#TAGE=n#PROZENT=p#[BASISBETRAG=b#]',
  jeweils mit LF abgeschlossen, danach der Nettohinweis mit Leerzeichen
  statt '#' (BR-DE-18 erlaubt freien Text nach den Skontozeilen). '' ohne
  Text fuer Zahlungsbedingungen. }
function LandrixEInvoicePaymentTermsText(AInvoice: TLandrixInvoice): TLandrixEInvoiceString;

{ Reads a payment terms text (BT-20): any text makes the terms net; lines
  starting with '#SKONTO#' become cash discounts 1 to 3 (days, percent,
  base amount), the other lines (and further discount lines, which become
  plain text when written, '#' replaced) are the net note, without white
  space at the edges (a text without discount line stays unchanged).
  Unreadable numbers stay 0.
  DE: Liest einen Text fuer Zahlungsbedingungen (BT-20): jeder Text macht
  die Bedingungen netto; Zeilen, die mit '#SKONTO#' beginnen, werden zu
  Skonto 1 bis 3 (Tage, Prozent, Basisbetrag), die uebrigen Zeilen (und
  weitere Skontozeilen, die beim Schreiben zu Text werden, '#' ersetzt)
  sind der Nettohinweis, ohne Leerraum am Rand (ein Text ohne Skontozeile
  bleibt unveraendert).
  Unlesbare Zahlen bleiben 0. }
procedure LandrixEInvoiceReadPaymentTermsText(AInvoice: TLandrixInvoice;
  const AText: TLandrixEInvoiceString);

{ True if a cash discount level that PaymentTermsType uses has a text
  (PaymentTermCashDiscount1Note to 3Note).
  DE: True, wenn eine Skontostufe, die PaymentTermsType verwendet, einen
  Text hat (PaymentTermCashDiscount1Note bis 3Note). }
function LandrixEInvoiceCashDiscountNotesSet(AInvoice: TLandrixInvoice): Boolean;

{ Builds the sub line tree from the flat CII line list (Factur-X EXTENDED,
  BT-X-304): ALines holds the lines in document order as they were added
  to AInvoice.InvoiceLines, AParentIDs the parent line identifier of each
  ('' for a top-level line), ANoAmountLines the lines without line net
  amount (both lists do not own the lines). A line moves below the first other line whose identifier equals
  its parent identifier (compared like XPath normalize-space()); with an
  unknown parent or a cycle it stays where it is and a diagnostic is added.
  A parent line without status whose sub lines have one is a detail line
  (it counts in the totals). A group line without amount gets the sum of
  its detail and group sub lines (BR-FXEXT-08).
  DE: Baut den Baum der Unterpositionen aus der flachen CII-Positionsliste
  (Factur-X EXTENDED, BT-X-304): ALines enthaelt die Positionen in
  Dokumentreihenfolge, wie sie an AInvoice.InvoiceLines angehaengt wurden,
  AParentIDs die Kennung der Oberposition je Position ('' fuer die oberste
  Ebene), ANoAmountLines die Positionen ohne Nettobetrag. Eine Position
  wandert unter die erste andere Position, deren Kennung ihrer
  Oberpositionskennung entspricht (verglichen wie XPath normalize-space());
  bei unbekannter Oberposition oder Zyklus bleibt sie, wo sie ist, und es
  gibt eine Meldung. Eine Oberposition ohne Status, deren Unterpositionen
  einen haben, ist eine Detailposition (sie zaehlt in den Summen). Eine
  Gruppenposition ohne Betrag erhaelt die Summe ihrer Detail- und
  Gruppen-Unterpositionen (BR-FXEXT-08). }
procedure LandrixEInvoiceBuildSubLines(AInvoice: TLandrixInvoice; ALines: TObjectList;
  AParentIDs: TLandrixEInvoiceStringList; ANoAmountLines: TObjectList;
  ADiagnostics: TLandrixEInvoiceDiagnostics);

{ BT-157 of a line as written: StandardItemIdentifier with its scheme when
  set, otherwise GlobalID_EAN_GTIN with scheme 0160. False if neither is
  set. AConflict describes an ignored GlobalID_EAN_GTIN that differs from
  the identifier written ('' otherwise).
  DE: BT-157 einer Position, wie geschrieben: StandardItemIdentifier mit
  seinem Schema, wenn gesetzt, sonst GlobalID_EAN_GTIN mit Schema 0160.
  False, wenn keines gesetzt ist. AConflict beschreibt ein uebergangenes
  GlobalID_EAN_GTIN, das von der geschriebenen Kennung abweicht (sonst ''). }
function LandrixEInvoiceStandardItemIdentifierOf(ALine: TLandrixInvoiceLine;
  out AValue, AScheme, AConflict: TLandrixEInvoiceString): Boolean;

{ BT-8 VAT point date code: the model holds UNTDID 2005 (3, 35, 432), CII
  uses UNTDID 2475 (5, 29, 72; EN 16931-3-3). Other codes pass unchanged
  and the functions return False.
  DE: BT-8 Code fuer das Steuerdatum: das Modell haelt UNTDID 2005 (3, 35,
  432), CII verwendet UNTDID 2475 (5, 29, 72; EN 16931-3-3). Andere Codes
  bleiben unveraendert, die Funktionen liefern dann False. }
function LandrixEInvoiceTaxPointDateCodeToCII(const ACode: TLandrixEInvoiceString;
  out ACIICode: TLandrixEInvoiceString): Boolean;
function LandrixEInvoiceTaxPointDateCodeFromCII(const ACIICode: TLandrixEInvoiceString;
  out ACode: TLandrixEInvoiceString): Boolean;

{ Calculation on request (TLandrixEInvoice.CalculateLineAmounts and
  CalculateTotals). Both compute everything first and change AInvoice only
  when there is no error; they return the number of errors, with the
  reasons in ADiagnostics. Amounts are rounded to cents half away from
  zero, as the writers round.
  LandrixEInvoiceCalculateLineAmounts sets BT-131 of every line: quantity x
  net price / base quantity (0 counts as 1), minus line allowances, plus
  line charges; a group (a line with sub lines) gets the sum of its DETAIL
  and GROUP sub lines.
  LandrixEInvoiceCalculateTotals sets the VAT breakdown (BG-23, grouped by
  category and rate, tax per group on its taxable amount; existing
  breakdowns keep their exemption reasons, missing ones are added, unused
  ones removed) and the document totals BT-106 to BT-110, BT-112 and BT-115 from
  the line amounts as they are. BT-111, BT-113 and BT-114 stay as given.
  DE: Berechnung auf Aufruf (TLandrixEInvoice.CalculateLineAmounts und
  CalculateTotals). Beide rechnen zuerst alles aus und aendern AInvoice nur,
  wenn kein Fehler auftritt; sie liefern die Anzahl der Fehler, die Gruende
  stehen in ADiagnostics. Betraege werden halb weg von null auf Cent
  gerundet, wie die Writer runden.
  LandrixEInvoiceCalculateLineAmounts setzt BT-131 jeder Position: Menge x
  Nettopreis / Basismenge (0 gilt als 1), minus Positionsnachlaesse, plus
  Positionszuschlaege; eine Gruppe (Position mit Unterpositionen) erhaelt
  die Summe ihrer DETAIL- und GROUP-Unterpositionen.
  LandrixEInvoiceCalculateTotals setzt die Steueraufschluesselung (BG-23,
  nach Kategorie und Satz gruppiert, Steuer je Gruppe auf ihre
  Bemessungsgrundlage; vorhandene Eintraege behalten ihre Befreiungsgruende,
  fehlende kommen dazu, nicht benutzte werden entfernt) und die Belegsummen
  BT-106 bis BT-110, BT-112 und BT-115 aus den Positionsbetraegen, wie sie sind.
  BT-111, BT-113 und BT-114 bleiben wie gegeben. }
function LandrixEInvoiceCalculateLineAmounts(AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
function LandrixEInvoiceCalculateTotals(AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;

implementation

uses
  LandrixEInvoiceCodes,
  LandrixEInvoiceLexical;

function LandrixEInvoiceLineStatusOf(ALine: TLandrixInvoiceLine;
  AIsSubLine: Boolean): TLandrixInvoiceLineStatusReasonCode;
begin
  Result := ALine.LineStatusReasonCode;
  if Result <> ilsrc_None then
    Exit;
  if ALine.SubInvoiceLines.Count > 0 then
    Result := ilsrc_Group
  else if AIsSubLine then
    Result := ilsrc_Detail;
end;

function IntText(AValue: Integer): TLandrixEInvoiceString;
var
  N: Int64;
  Negative: Boolean;
begin
  Result := '';
  Negative := AValue < 0;
  N := Abs(Int64(AValue));
  repeat
    Result := WideChar(Ord('0') + Integer(N mod 10)) + Result;
    N := N div 10;
  until N = 0;
  if Negative then
    Result := '-' + Result;
end;

function ReplaceChar(const S: TLandrixEInvoiceString; AFrom, ATo: WideChar): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if Result[I] = AFrom then
      Result[I] := ATo;
end;

function DiscountText(ADays: Integer; APercent: Double; ABase: Currency): TLandrixEInvoiceString;
begin
  Result := '#SKONTO#TAGE=' + IntText(ADays) + '#PROZENT=' + LandrixEInvoiceDecimalToLexical(APercent, 2) + '#';
  if ABase <> 0 then
    Result := Result + 'BASISBETRAG=' + LandrixEInvoiceAmountToLexical(ABase) + '#';
  Result := Result + #10;
end;

function LandrixEInvoicePaymentTermsText(AInvoice: TLandrixInvoice): TLandrixEInvoiceString;
begin
  case AInvoice.PaymentTermsType of
    iptt_Net:
      Result := '';
    iptt_CashDiscount1:
      Result := DiscountText(AInvoice.PaymentTermCashDiscount1Days, AInvoice.PaymentTermCashDiscount1Percent,
        AInvoice.PaymentTermCashDiscount1Base);
    iptt_CashDiscount2:
      Result := DiscountText(AInvoice.PaymentTermCashDiscount1Days, AInvoice.PaymentTermCashDiscount1Percent,
        AInvoice.PaymentTermCashDiscount1Base) +
        DiscountText(AInvoice.PaymentTermCashDiscount2Days, AInvoice.PaymentTermCashDiscount2Percent,
        AInvoice.PaymentTermCashDiscount2Base);
    iptt_CashDiscount3:
      Result := DiscountText(AInvoice.PaymentTermCashDiscount1Days, AInvoice.PaymentTermCashDiscount1Percent,
        AInvoice.PaymentTermCashDiscount1Base) +
        DiscountText(AInvoice.PaymentTermCashDiscount2Days, AInvoice.PaymentTermCashDiscount2Percent,
        AInvoice.PaymentTermCashDiscount2Base) +
        DiscountText(AInvoice.PaymentTermCashDiscount3Days, AInvoice.PaymentTermCashDiscount3Percent,
        AInvoice.PaymentTermCashDiscount3Base);
  else
    begin
      Result := '';
      Exit;
    end;
  end;
  Result := Result + ReplaceChar(AInvoice.PaymentTermNetNote, '#', ' ');
end;

function IsSpace(C: WideChar): Boolean;
begin
  Result := (C = ' ') or (C = #9) or (C = #10) or (C = #13);
end;

function TrimText(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  First, Last: Integer;
begin
  First := 1;
  Last := Length(S);
  while (First <= Last) and IsSpace(S[First]) do
    Inc(First);
  while (Last >= First) and IsSpace(S[Last]) do
    Dec(Last);
  Result := Copy(S, First, Last - First + 1);
end;

{ Value after 'NAME=' up to the next '#' in ALine ('' if missing).
  DE: Wert nach 'NAME=' bis zum naechsten '#' in ALine ('' wenn fehlend). }
function FieldValue(const ALine, AName: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  P, I: Integer;
  Key: TLandrixEInvoiceString;
begin
  Result := '';
  Key := '#' + AName + '=';
  P := Pos(Key, ALine);
  if P = 0 then
    Exit;
  I := P + Length(Key);
  while (I <= Length(ALine)) and (ALine[I] <> '#') do
  begin
    Result := Result + ALine[I];
    Inc(I);
  end;
end;

function TextToInt(const S: TLandrixEInvoiceString): Integer;
var
  D: Double;
begin
  if LandrixEInvoiceTryLexicalToDouble(S, D) and (D >= -MaxInt) and (D <= MaxInt) then
    Result := Integer(Trunc(D))
  else
    Result := 0;
end;

function TextToDouble(const S: TLandrixEInvoiceString): Double;
begin
  if not LandrixEInvoiceTryLexicalToDouble(S, Result) then
    Result := 0;
end;

function TextToCurrency(const S: TLandrixEInvoiceString): Currency;
var
  Rounded: Boolean;
begin
  if not LandrixEInvoiceTryLexicalToCurrency(S, Result, Rounded) then
    Result := 0;
end;

procedure LandrixEInvoiceReadPaymentTermsText(AInvoice: TLandrixInvoice;
  const AText: TLandrixEInvoiceString);
var
  Start, I, Count: Integer;
  Line, Note: TLandrixEInvoiceString;
  Days: Integer;
  Percent: Double;
  Base: Currency;
begin
  if AText = '' then
    Exit;
  AInvoice.PaymentTermsType := iptt_Net;
  AInvoice.PaymentTermNetNote := AText;
  if Pos('#SKONTO#', AText) = 0 then
    Exit;
  Count := 0;
  Start := 1;
  Note := '';
  for I := 1 to Length(AText) + 1 do
  begin
    if (I <= Length(AText)) and (AText[I] <> #10) and (AText[I] <> #13) then
      Continue;
    Line := Copy(AText, Start, I - Start);
    Start := I + 1;
    if (Count = 3) or (Pos('#SKONTO#', TrimText(Line)) <> 1) then
    begin
      { CR LF counts as one line break }
      if (I > 1) and (I <= Length(AText)) and (AText[I] = #10) and (AText[I - 1] = #13) then
        Continue;
      if Note <> '' then
        Note := Note + #10;
      Note := Note + Line;
      Continue;
    end;
    Line := TrimText(Line);
    Inc(Count);
    Days := TextToInt(FieldValue(Line, 'TAGE'));
    Percent := TextToDouble(FieldValue(Line, 'PROZENT'));
    Base := TextToCurrency(FieldValue(Line, 'BASISBETRAG'));
    case Count of
      1:
        begin
          AInvoice.PaymentTermsType := iptt_CashDiscount1;
          AInvoice.PaymentTermCashDiscount1Days := Days;
          AInvoice.PaymentTermCashDiscount1Percent := Percent;
          AInvoice.PaymentTermCashDiscount1Base := Base;
        end;
      2:
        begin
          AInvoice.PaymentTermsType := iptt_CashDiscount2;
          AInvoice.PaymentTermCashDiscount2Days := Days;
          AInvoice.PaymentTermCashDiscount2Percent := Percent;
          AInvoice.PaymentTermCashDiscount2Base := Base;
        end;
    else
      begin
        AInvoice.PaymentTermsType := iptt_CashDiscount3;
        AInvoice.PaymentTermCashDiscount3Days := Days;
        AInvoice.PaymentTermCashDiscount3Percent := Percent;
        AInvoice.PaymentTermCashDiscount3Base := Base;
      end;
    end;
  end;
  AInvoice.PaymentTermNetNote := TrimText(Note);
end;

{ XPath normalize-space(): white space at the edges removed, inner runs
  collapsed to one blank (BR-FXEXT-08 and -11 compare like this).
  DE: XPath normalize-space(): Leerraum am Rand entfernt, innere Folgen zu
  einem Leerzeichen zusammengefasst (so vergleichen BR-FXEXT-08 und -11). }
function NormalizeSpace(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I: Integer;
  Pending: Boolean;
begin
  Result := '';
  Pending := False;
  for I := 1 to Length(S) do
    if IsSpace(S[I]) then
      Pending := True
    else
    begin
      if Pending and (Result <> '') then
        Result := Result + ' ';
      Result := Result + S[I];
      Pending := False;
    end;
end;

function ContainsLine(ALine, ACandidate: TLandrixInvoiceLine): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALine.SubInvoiceLines.Count - 1 do
    if (ALine.SubInvoiceLines[I] = ACandidate) or ContainsLine(ALine.SubInvoiceLines[I], ACandidate) then
      Exit;
  Result := False;
end;

function GroupAmount(ALine: TLandrixInvoiceLine; ANoAmountLines: TObjectList): Currency;
var
  I: TLandrixEInvoiceListIndex;
begin
  if (ANoAmountLines.IndexOf(ALine) < 0) or (ALine.LineStatusReasonCode <> ilsrc_Group) then
  begin
    Result := ALine.LineAmount;
    Exit;
  end;
  Result := 0;
  for I := 0 to ALine.SubInvoiceLines.Count - 1 do
    if LandrixEInvoiceLineStatusOf(ALine.SubInvoiceLines[I], True) in [ilsrc_Detail, ilsrc_Group] then
      Result := Result + GroupAmount(ALine.SubInvoiceLines[I], ANoAmountLines);
end;

procedure LandrixEInvoiceBuildSubLines(AInvoice: TLandrixInvoice; ALines: TObjectList;
  AParentIDs: TLandrixEInvoiceStringList; ANoAmountLines: TObjectList;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
var
  I, J, K: TLandrixEInvoiceListIndex;
  Line, Parent: TLandrixInvoiceLine;
  ParentID: TLandrixEInvoiceString;
  ChildHasCode: Boolean;
begin
  for I := 0 to ALines.Count - 1 do
  begin
    ParentID := NormalizeSpace(AParentIDs[I]);
    if ParentID = '' then
      Continue;
    Line := TLandrixInvoiceLine(ALines[I]);
    Parent := nil;
    for J := 0 to ALines.Count - 1 do
      if (J <> I) and (NormalizeSpace(TLandrixInvoiceLine(ALines[J]).ID) = ParentID) then
      begin
        Parent := TLandrixInvoiceLine(ALines[J]);
        Break;
      end;
    if (Parent = nil) or ContainsLine(Line, Parent) then
    begin
      if ADiagnostics <> nil then
        ADiagnostics.AddDiagnostic(edk_ConversionFailed,
          '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:IncludedSupplyChainTradeLineItem/' +
          'ram:AssociatedDocumentLineDocument/ram:ParentLineID', 0, 0, 0,
          'parent line ' + ParentID + ' of line ' + Line.ID +
          ' not found or a cycle; the line stays on its level').Severity := eds_Warning;
      Continue;
    end;
    AInvoice.InvoiceLines.Extract(Line);
    Parent.SubInvoiceLines.Add(Line);
  end;
  for I := 0 to ALines.Count - 1 do
  begin
    Line := TLandrixInvoiceLine(ALines[I]);
    if (Line.SubInvoiceLines.Count = 0) or (Line.LineStatusReasonCode <> ilsrc_None) then
      Continue;
    ChildHasCode := False;
    for K := 0 to Line.SubInvoiceLines.Count - 1 do
      if Line.SubInvoiceLines[K].LineStatusReasonCode <> ilsrc_None then
        ChildHasCode := True;
    if ChildHasCode then
      Line.LineStatusReasonCode := ilsrc_Detail;
  end;
  for I := 0 to ANoAmountLines.Count - 1 do
    TLandrixInvoiceLine(ANoAmountLines[I]).LineAmount :=
      GroupAmount(TLandrixInvoiceLine(ANoAmountLines[I]), ANoAmountLines);
end;

function LandrixEInvoiceCashDiscountNotesSet(AInvoice: TLandrixInvoice): Boolean;
begin
  case AInvoice.PaymentTermsType of
    iptt_CashDiscount1:
      Result := AInvoice.PaymentTermCashDiscount1Note <> '';
    iptt_CashDiscount2:
      Result := (AInvoice.PaymentTermCashDiscount1Note <> '') or (AInvoice.PaymentTermCashDiscount2Note <> '');
    iptt_CashDiscount3:
      Result := (AInvoice.PaymentTermCashDiscount1Note <> '') or (AInvoice.PaymentTermCashDiscount2Note <> '') or
        (AInvoice.PaymentTermCashDiscount3Note <> '');
  else
    Result := False;
  end;
end;

function LandrixEInvoiceStandardItemIdentifierOf(ALine: TLandrixInvoiceLine;
  out AValue, AScheme, AConflict: TLandrixEInvoiceString): Boolean;
begin
  AConflict := '';
  if not LandrixEInvoiceIsBlank(ALine.StandardItemIdentifier) then
  begin
    AValue := ALine.StandardItemIdentifier;
    AScheme := ALine.StandardItemIdentifierSchemeID;
    if not LandrixEInvoiceIsBlank(ALine.GlobalID_EAN_GTIN) and
       ((ALine.GlobalID_EAN_GTIN <> AValue) or (AScheme <> '0160')) then
      AConflict := 'GTIN ' + ALine.GlobalID_EAN_GTIN + ' of line ' + ALine.ID +
        ' ignored: the item standard identifier ' + AValue + ' (scheme ' + AScheme + ') is written';
  end
  else if not LandrixEInvoiceIsBlank(ALine.GlobalID_EAN_GTIN) then
  begin
    AValue := ALine.GlobalID_EAN_GTIN;
    AScheme := '0160';
  end
  else
  begin
    AValue := '';
    AScheme := '';
  end;
  Result := AValue <> '';
end;

type
  TTaxPointCodePair = record
    Code: string;
    CIICode: string;
  end;

const
  { EN 16931-3-3, BT-8 }
  TaxPointCodes: array[0..2] of TTaxPointCodePair = (
    (Code: '3'; CIICode: '5'),
    (Code: '35'; CIICode: '29'),
    (Code: '432'; CIICode: '72')
  );

function LandrixEInvoiceTaxPointDateCodeToCII(const ACode: TLandrixEInvoiceString;
  out ACIICode: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
begin
  for I := Low(TaxPointCodes) to High(TaxPointCodes) do
    if ACode = TLandrixEInvoiceString(TaxPointCodes[I].Code) then
    begin
      ACIICode := TLandrixEInvoiceString(TaxPointCodes[I].CIICode);
      Result := True;
      Exit;
    end;
  ACIICode := ACode;
  Result := False;
end;

function LandrixEInvoiceTaxPointDateCodeFromCII(const ACIICode: TLandrixEInvoiceString;
  out ACode: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
begin
  for I := Low(TaxPointCodes) to High(TaxPointCodes) do
    if ACIICode = TLandrixEInvoiceString(TaxPointCodes[I].CIICode) then
    begin
      ACode := TLandrixEInvoiceString(TaxPointCodes[I].Code);
      Result := True;
      Exit;
    end;
  ACode := ACIICode;
  Result := False;
end;

{ --- calculation on request ----------------------------------------------------- }

type
  TLineResult = record
    Line: TLandrixInvoiceLine;
    Amount: Currency;
  end;

  TCalcState = record
    Lines: array of TLineResult;
    LineCount: Integer;
    Errors: Integer;
    Diagnostics: TLandrixEInvoiceDiagnostics;
  end;

  { One VAT group of the breakdown: category, rate and what goes into it.
    DE: Eine Gruppe der Steueraufschluesselung: Kategorie, Satz und was
    hineinfliesst. }
  TVatGroup = record
    Category: TLandrixInvoiceDutyTaxFeeCategoryCode;
    CategoryOther: TLandrixEInvoiceString;
    RateKey: Int64;
    Rate: Double;
    Taxable: Currency;
    Reason: TLandrixEInvoiceString;
    Matched: Boolean;
  end;
  TVatGroups = array of TVatGroup;

procedure CalcError(var AState: TCalcState; const APath, AMessage: TLandrixEInvoiceString);
begin
  Inc(AState.Errors);
  if AState.Diagnostics <> nil then
    AState.Diagnostics.AddDiagnostic(edk_InvalidValue, APath, 0, 0, 0, AMessage).Severity := eds_Error;
end;

procedure CalcWarning(var AState: TCalcState; const APath, AMessage: TLandrixEInvoiceString);
begin
  if AState.Diagnostics <> nil then
    AState.Diagnostics.AddDiagnostic(edk_InvalidValue, APath, 0, 0, 0, AMessage).Severity := eds_Warning;
end;

{ AValue rounded to cents, half away from zero (as the writers round), not
  with Round (banker's rounding). A tiny margin absorbs the binary error of
  products like 0.285 x 100. False for NaN and values beyond the Currency
  range.
  DE: AValue auf Cent gerundet, halb weg von null (wie die Writer runden),
  nicht mit Round (Banker's Rounding). Ein kleiner Zuschlag faengt den
  Binaerfehler von Produkten wie 0.285 x 100 ab. False bei NaN und Werten
  ausserhalb des Currency-Bereichs. }
function RoundCents(AValue: Double; out ACents: Currency): Boolean;
var
  Limit, Margin: Double;
  N: Int64;
begin
  Result := False;
  ACents := 0;
  Limit := 900000000;
  Limit := Limit * 1000000;
  Margin := 1;
  Margin := Margin / 10000000;
  if (AValue <> AValue) or (Abs(AValue) > Limit) then
    Exit;
  N := Trunc(Abs(AValue) * 100 + 0.5 + Margin);
  if AValue < 0 then
    N := -N;
  PInt64(@ACents)^ := N * 100;
  Result := True;
end;

function CentsOf(AValue: Currency): Currency;
begin
  if not RoundCents(AValue, Result) then
    Result := AValue;
end;

function LineLabel(ALine: TLandrixInvoiceLine): TLandrixEInvoiceString;
begin
  Result := 'line ' + ALine.ID;
end;

{ BT-131 of a line without sub lines: quantity x net price / base quantity
  (0 counts as 1) rounded to cents, minus the line allowances, plus the line
  charges (each as written, in cents).
  DE: BT-131 einer Position ohne Unterpositionen: Menge x Nettopreis /
  Basismenge (0 gilt als 1), auf Cent gerundet, minus Positionsnachlaesse,
  plus Positionszuschlaege (jeweils wie geschrieben, in Cent). }
function PricedAmount(ALine: TLandrixInvoiceLine; var AState: TCalcState; out AAmount: Currency): Boolean;
var
  Base: Double;
  I: TLandrixEInvoiceListIndex;
  Item: TLandrixInvoiceAllowanceCharge;
begin
  Result := False;
  AAmount := 0;
  Base := ALine.BaseQuantity;
  if Base = 0 then
    Base := 1;
  if Base < 0 then
  begin
    CalcError(AState, 'BT-149', LineLabel(ALine) + ': negative price base quantity');
    Exit;
  end;
  if not RoundCents(ALine.Quantity * ALine.NetPriceAmount / Base, AAmount) then
  begin
    CalcError(AState, 'BT-131', LineLabel(ALine) + ': quantity x price is out of range');
    Exit;
  end;
  for I := 0 to ALine.AllowanceCharges.Count - 1 do
  begin
    Item := ALine.AllowanceCharges[I];
    if Item.ChargeIndicator then
      AAmount := AAmount + CentsOf(Item.Amount)
    else
      AAmount := AAmount - CentsOf(Item.Amount);
  end;
  Result := True;
end;

{ Computes BT-131 of ALines and their sub lines into AState (nothing is
  assigned yet). A group (a line with sub lines) is the sum of its DETAIL and
  GROUP sub lines (BR-FXEXT-08); a line with sub lines and another status is
  not supported.
  DE: Berechnet BT-131 von ALines und ihren Unterpositionen in AState (noch
  ohne Zuweisung). Eine Gruppe (Position mit Unterpositionen) ist die Summe
  ihrer DETAIL- und GROUP-Unterpositionen (BR-FXEXT-08); eine Position mit
  Unterpositionen und anderem Status wird nicht unterstuetzt. }
procedure CalcLines(ALines: TLandrixInvoiceLines; AIsSubLine: Boolean; var AState: TCalcState);
var
  I, K: TLandrixEInvoiceListIndex;
  Line, Sub: TLandrixInvoiceLine;
  Amount: Currency;
  First, J: Integer;
  Ok: Boolean;
begin
  for I := 0 to ALines.Count - 1 do
  begin
    Line := ALines[I];
    Amount := 0;
    if Line.SubInvoiceLines.Count > 0 then
    begin
      First := AState.LineCount;
      CalcLines(Line.SubInvoiceLines, True, AState);
      Ok := LandrixEInvoiceLineStatusOf(Line, AIsSubLine) = ilsrc_Group;
      if not Ok then
        CalcError(AState, 'BT-X-8', LineLabel(Line) + ': a line with sub lines must be a group (GROUP)')
      else
        for K := 0 to Line.SubInvoiceLines.Count - 1 do
        begin
          Sub := Line.SubInvoiceLines[K];
          if LandrixEInvoiceLineStatusOf(Sub, True) in [ilsrc_Detail, ilsrc_Group] then
            for J := First to AState.LineCount - 1 do
              if AState.Lines[J].Line = Sub then
                Amount := Amount + AState.Lines[J].Amount;
        end;
    end
    else
      Ok := PricedAmount(Line, AState, Amount);
    if Ok then
    begin
      if AState.LineCount = Length(AState.Lines) then
        SetLength(AState.Lines, 2 * AState.LineCount + 8);
      AState.Lines[AState.LineCount].Line := Line;
      AState.Lines[AState.LineCount].Amount := Amount;
      Inc(AState.LineCount);
    end;
  end;
end;

function LandrixEInvoiceCalculateLineAmounts(AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
var
  State: TCalcState;
  I: Integer;
begin
  State.LineCount := 0;
  State.Errors := 0;
  State.Diagnostics := ADiagnostics;
  CalcLines(AInvoice.InvoiceLines, False, State);
  Result := State.Errors;
  if Result > 0 then
    Exit;
  for I := 0 to State.LineCount - 1 do
    State.Lines[I].Line.LineAmount := State.Lines[I].Amount;
end;

function RateKeyOf(ARate: Double): Int64;
begin
  if ARate < 0 then
    Result := -Trunc(-ARate * 10000 + 0.5)
  else
    Result := Trunc(ARate * 10000 + 0.5);
end;

function CategoryLabel(ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode;
  const AOther: TLandrixEInvoiceString; ARate: Double): TLandrixEInvoiceString;
begin
  if ACategory = idtfcc_None then
    Result := AOther
  else
    Result := LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(ACategory);
  Result := Result + ' ' + LandrixEInvoiceAmountToLexical(ARate);
end;

function FindGroup(const AGroups: TVatGroups; ACount: Integer;
  ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode; const AOther: TLandrixEInvoiceString; ARate: Double): Integer;
var
  Key: Int64;
  I: Integer;
begin
  Key := RateKeyOf(ARate);
  for I := 0 to ACount - 1 do
    if (AGroups[I].Category = ACategory) and (AGroups[I].RateKey = Key) and
       ((ACategory <> idtfcc_None) or (AGroups[I].CategoryOther = AOther)) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

{ The leaf lines below a group must share its category and rate: the
  breakdown takes the top-level line, Factur-X EXTENDED the DETAIL lines.
  DE: Die Blattpositionen unter einer Gruppe muessen deren Kategorie und
  Satz teilen: die Aufschluesselung nimmt die oberste Position, Factur-X
  EXTENDED die DETAIL-Positionen. }
function SubLinesMatch(ALine: TLandrixInvoiceLine; ATop: TLandrixInvoiceLine): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  Sub: TLandrixInvoiceLine;
begin
  Result := True;
  for I := 0 to ALine.SubInvoiceLines.Count - 1 do
  begin
    Sub := ALine.SubInvoiceLines[I];
    if LandrixEInvoiceLineStatusOf(Sub, True) = ilsrc_Information then
      Continue;
    if (Sub.TaxCategory <> ATop.TaxCategory) or (RateKeyOf(Sub.TaxPercent) <> RateKeyOf(ATop.TaxPercent)) or
       ((Sub.TaxCategory = idtfcc_None) and (Sub.TaxCategoryOther <> ATop.TaxCategoryOther)) or
       not SubLinesMatch(Sub, ATop) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

{ The VAT category of a group without one: that of its first leaf line
  that is no INFORMATION line (Factur-X EXTENDED allows a GROUP line
  without VAT data).
  DE: Die Umsatzsteuerkategorie einer Gruppe ohne eigene: die ihrer ersten
  Blattposition, die keine INFORMATION-Position ist (Factur-X EXTENDED
  erlaubt eine GROUP-Position ohne Steuerangaben). }
function TaxSource(ALine: TLandrixInvoiceLine): TLandrixInvoiceLine;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := ALine;
  if (ALine.SubInvoiceLines.Count = 0) or (ALine.TaxCategory <> idtfcc_None) or
     not LandrixEInvoiceIsBlank(ALine.TaxCategoryOther) then
    Exit;
  for I := 0 to ALine.SubInvoiceLines.Count - 1 do
    if LandrixEInvoiceLineStatusOf(ALine.SubInvoiceLines[I], True) <> ilsrc_Information then
    begin
      Result := TaxSource(ALine.SubInvoiceLines[I]);
      Exit;
    end;
end;

{ BR-AE-10, BR-E-10, BR-G-10, BR-IC-10 and BR-O-10: a VAT breakdown of these
  categories needs an exemption reason (BT-120) or its code (BT-121).
  DE: BR-AE-10, BR-E-10, BR-G-10, BR-IC-10 und BR-O-10: eine
  Steueraufschluesselung dieser Kategorien braucht einen Befreiungsgrund
  (BT-120) oder dessen Code (BT-121). }
function NeedsExemptionReason(ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode): Boolean;
begin
  Result := ACategory in [idtfcc_AE_VATReverseCharge, idtfcc_E_ExemptFromTax,
    idtfcc_G_FreeExportItemTaxNotCharged, idtfcc_K_VATExemptForEEAIntracommunitySupplyOfGoodsAndServices,
    idtfcc_O_ServicesOutsideScopeOfTax];
end;

procedure AddToGroup(var AGroups: TVatGroups; var ACount: Integer;
  ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode; const AOther: TLandrixEInvoiceString; ARate: Double;
  AAmount: Currency; const AReason: TLandrixEInvoiceString);
var
  G: Integer;
begin
  G := FindGroup(AGroups, ACount, ACategory, AOther, ARate);
  if G < 0 then
  begin
    G := ACount;
    Inc(ACount);
    AGroups[G].Category := ACategory;
    AGroups[G].CategoryOther := AOther;
    AGroups[G].RateKey := RateKeyOf(ARate);
    AGroups[G].Rate := ARate;
    AGroups[G].Taxable := 0;
    AGroups[G].Reason := '';
    AGroups[G].Matched := False;
  end;
  AGroups[G].Taxable := AGroups[G].Taxable + AAmount;
  if (AGroups[G].Reason = '') and (AReason <> '') then
    AGroups[G].Reason := AReason;
end;

function LandrixEInvoiceCalculateTotals(AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
var
  State: TCalcState;
  Groups: TVatGroups;
  GroupCount, G, I, J: Integer;
  Taxes: array of Currency;
  Existing: array of Integer;
  Line, Source: TLandrixInvoiceLine;
  Item: TLandrixInvoiceAllowanceCharge;
  Sub: TLandrixInvoiceTaxAmount;
  Lines, Allowances, Charges, TaxTotal, Amount, Payable: Currency;
begin
  State.LineCount := 0;
  State.Errors := 0;
  State.Diagnostics := ADiagnostics;
  Groups := nil;
  Existing := nil;
  Taxes := nil;
  SetLength(Groups, AInvoice.InvoiceLines.Count + AInvoice.AllowanceCharges.Count);
  GroupCount := 0;
  Lines := 0;
  Allowances := 0;
  Charges := 0;

  { BT-106 and the line part of BG-23: the top-level lines, without
    INFORMATION lines (they do not count in Factur-X EXTENDED and are not
    allowed elsewhere)
    DE: BT-106 und der Positionsanteil von BG-23: die Positionen der
    obersten Ebene ohne INFORMATION-Positionen (sie zaehlen in Factur-X
    EXTENDED nicht und sind sonst nicht erlaubt) }
  for I := 0 to Integer(AInvoice.InvoiceLines.Count) - 1 do
  begin
    Line := AInvoice.InvoiceLines[I];
    case LandrixEInvoiceLineStatusOf(Line, False) of
      ilsrc_Information:
        Continue;
      ilsrc_Detail:
        if Line.SubInvoiceLines.Count > 0 then
        begin
          CalcError(State, 'BT-X-8', LineLabel(Line) + ': a line with sub lines must be a group (GROUP)');
          Continue;
        end;
    else
      ;
    end;
    Source := TaxSource(Line);
    if (Source.TaxCategory = idtfcc_None) and LandrixEInvoiceIsBlank(Source.TaxCategoryOther) then
    begin
      CalcError(State, 'BT-151', LineLabel(Line) + ': no VAT category');
      Continue;
    end;
    if not SubLinesMatch(Line, Source) then
    begin
      CalcError(State, 'BT-151', LineLabel(Line) + ': the sub lines have another VAT category or rate');
      Continue;
    end;
    Amount := CentsOf(Line.LineAmount);
    Lines := Lines + Amount;
    AddToGroup(Groups, GroupCount, Source.TaxCategory, Source.TaxCategoryOther, Source.TaxPercent, Amount,
      Source.TaxExemptionReason);
  end;

  { BG-20 and BG-21 }
  for I := 0 to Integer(AInvoice.AllowanceCharges.Count) - 1 do
  begin
    Item := AInvoice.AllowanceCharges[I];
    Amount := CentsOf(Item.Amount);
    if (Item.TaxCategory = idtfcc_None) and LandrixEInvoiceIsBlank(Item.TaxCategoryOther) then
    begin
      CalcError(State, 'BT-95', 'allowance or charge ' + LandrixEInvoiceAmountToLexical(Item.Amount) +
        ': no VAT category');
      Continue;
    end;
    if Item.ChargeIndicator then
      Charges := Charges + Amount
    else
    begin
      Allowances := Allowances + Amount;
      Amount := -Amount;
    end;
    AddToGroup(Groups, GroupCount, Item.TaxCategory, Item.TaxCategoryOther, Item.TaxPercent, Amount, '');
  end;

  { the existing breakdowns: one per category and rate }
  SetLength(Existing, AInvoice.TaxAmountSubtotals.Count);
  for I := 0 to Integer(AInvoice.TaxAmountSubtotals.Count) - 1 do
  begin
    Sub := AInvoice.TaxAmountSubtotals[I];
    Existing[I] := FindGroup(Groups, GroupCount, Sub.TaxCategory, Sub.TaxCategoryOther, Sub.TaxPercent);
    for J := 0 to I - 1 do
      if (AInvoice.TaxAmountSubtotals[J].TaxCategory = Sub.TaxCategory) and
         (RateKeyOf(AInvoice.TaxAmountSubtotals[J].TaxPercent) = RateKeyOf(Sub.TaxPercent)) and
         ((Sub.TaxCategory <> idtfcc_None) or (AInvoice.TaxAmountSubtotals[J].TaxCategoryOther = Sub.TaxCategoryOther)) then
        CalcError(State, 'BG-23', 'VAT breakdown ' + CategoryLabel(Sub.TaxCategory, Sub.TaxCategoryOther,
          Sub.TaxPercent) + ' occurs twice');
  end;

  { BT-117 per group: the taxable amount x rate, rounded once }
  SetLength(Taxes, GroupCount);
  TaxTotal := 0;
  for G := 0 to GroupCount - 1 do
  begin
    if not RoundCents(Groups[G].Taxable * Groups[G].Rate / 100, Taxes[G]) then
      CalcError(State, 'BT-117', 'VAT of ' + CategoryLabel(Groups[G].Category, Groups[G].CategoryOther,
        Groups[G].Rate) + ' is out of range');
    TaxTotal := TaxTotal + Taxes[G];
  end;

  Result := State.Errors;
  if Result > 0 then
    Exit;

  { assign: update or remove the existing breakdowns, then add the new ones }
  for I := Integer(AInvoice.TaxAmountSubtotals.Count) - 1 downto 0 do
  begin
    Sub := AInvoice.TaxAmountSubtotals[I];
    G := Existing[I];
    if G < 0 then
    begin
      CalcWarning(State, 'BG-23', 'VAT breakdown ' + CategoryLabel(Sub.TaxCategory, Sub.TaxCategoryOther,
        Sub.TaxPercent) + ' removed: no line, allowance or charge has this category and rate');
      AInvoice.TaxAmountSubtotals.Delete(I);
      Continue;
    end;
    Groups[G].Matched := True;
    Sub.TaxableAmount := Groups[G].Taxable;
    Sub.TaxAmount := Taxes[G];
  end;
  for G := 0 to GroupCount - 1 do
    if not Groups[G].Matched then
    begin
      Sub := AInvoice.TaxAmountSubtotals.AddTaxAmount;
      Sub.TaxCategory := Groups[G].Category;
      Sub.TaxCategoryOther := Groups[G].CategoryOther;
      Sub.TaxPercent := Groups[G].Rate;
      Sub.TaxableAmount := Groups[G].Taxable;
      Sub.TaxAmount := Taxes[G];
      Sub.TaxExemptionReason := Groups[G].Reason;
      if NeedsExemptionReason(Sub.TaxCategory) and LandrixEInvoiceIsBlank(Sub.TaxExemptionReason) then
        CalcWarning(State, 'BT-120', 'VAT breakdown ' + CategoryLabel(Sub.TaxCategory, Sub.TaxCategoryOther,
          Sub.TaxPercent) + ' needs an exemption reason (BT-120 or BT-121)');
    end;

  { BG-22; BT-113, BT-114 and BT-111 stay as given }
  AInvoice.LineAmount := Lines;
  AInvoice.AllowanceTotalAmount := Allowances;
  AInvoice.ChargeTotalAmount := Charges;
  AInvoice.TaxExclusiveAmount := Lines - Allowances + Charges;
  AInvoice.TaxAmountTotal := TaxTotal;
  AInvoice.TaxInclusiveAmount := AInvoice.TaxExclusiveAmount + TaxTotal;
  Payable := AInvoice.TaxInclusiveAmount - CentsOf(AInvoice.PrepaidAmount) + CentsOf(AInvoice.PayableRoundingAmount);
  for I := 0 to Integer(AInvoice.PrepaidPayments.Count) - 1 do
    Payable := Payable + CentsOf(AInvoice.PrepaidPayments[I].PaidAmount);
  AInvoice.PayableAmount := Payable;
end;

end.
