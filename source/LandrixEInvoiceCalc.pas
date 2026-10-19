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
  rules that UBL and CII share. Totals are never recalculated implicitly;
  the mappings write the totals of the invoice model as they are.

  DE: Gemeinsame Fachschicht der Abbildungen, unabhaengig von der Syntax:
  Struktur der Unterpositionen, die XRechnung-Textform der
  Zahlungsbedingungen und Regeln, die UBL und CII teilen. Summen werden nie
  stillschweigend neu berechnet; die Abbildungen schreiben die Summen des
  Rechnungsmodells unveraendert. }

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

{ Payment terms as one text (BT-20) in the form XRechnung uses: the net
  note with '#' replaced by blanks, or one line per cash discount
  '#SKONTO#TAGE=n#PROZENT=p#[BASISBETRAG=b#]', each ended by LF. '' if the
  invoice has no payment terms text.
  DE: Zahlungsbedingungen als ein Text (BT-20) in der Form, die XRechnung
  verwendet: der Nettohinweis mit Leerzeichen statt '#' oder eine Zeile je
  Skonto '#SKONTO#TAGE=n#PROZENT=p#[BASISBETRAG=b#]', jeweils mit LF
  abgeschlossen. '' ohne Text fuer Zahlungsbedingungen. }
function LandrixEInvoicePaymentTermsText(AInvoice: TLandrixInvoice): TLandrixEInvoiceString;

{ Reads a payment terms text (BT-20): any text makes the terms net with the
  text as note; lines starting with '#SKONTO#' become cash discounts 1 to 3
  (days, percent, base amount). Unreadable numbers stay 0.
  DE: Liest einen Text fuer Zahlungsbedingungen (BT-20): jeder Text macht
  die Bedingungen netto mit dem Text als Hinweis; Zeilen, die mit
  '#SKONTO#' beginnen, werden zu Skonto 1 bis 3 (Tage, Prozent,
  Basisbetrag). Unlesbare Zahlen bleiben 0. }
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

implementation

uses
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
      Result := ReplaceChar(AInvoice.PaymentTermNetNote, '#', ' ');
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
    Result := '';
  end;
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
  Line: TLandrixEInvoiceString;
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
  for I := 1 to Length(AText) + 1 do
  begin
    if (I <= Length(AText)) and (AText[I] <> #10) and (AText[I] <> #13) then
      Continue;
    Line := TrimText(Copy(AText, Start, I - Start));
    Start := I + 1;
    if (Count = 3) or (Pos('#SKONTO#', Line) <> 1) then
      Continue;
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
  if ALine.StandardItemIdentifier <> '' then
  begin
    AValue := ALine.StandardItemIdentifier;
    AScheme := ALine.StandardItemIdentifierSchemeID;
    if (ALine.GlobalID_EAN_GTIN <> '') and ((ALine.GlobalID_EAN_GTIN <> AValue) or (AScheme <> '0160')) then
      AConflict := 'GTIN ' + ALine.GlobalID_EAN_GTIN + ' of line ' + ALine.ID +
        ' ignored: the item standard identifier ' + AValue + ' (scheme ' + AScheme + ') is written';
  end
  else if ALine.GlobalID_EAN_GTIN <> '' then
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

end.
