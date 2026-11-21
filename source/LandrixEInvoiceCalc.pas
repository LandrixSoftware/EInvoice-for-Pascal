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
  reasons in ADiagnostics. They compute exactly with the numbers as the
  writers write them (quantity 4 to 10 decimals, price 2 or 4, base
  quantity up to 10, rates 2 to 4) and round amounts to cents half away from zero, as the
  writers round; an amount above 9e14 or a sum beyond Currency is an
  error.
  LandrixEInvoiceCalculateLineAmounts sets BT-131 of every line: quantity x
  net price / base quantity (0 counts as 1), minus line allowances, plus
  line charges; a group (a line with sub lines) gets the sum of its DETAIL
  and GROUP sub lines.
  LandrixEInvoiceCalculateTotals sets the VAT breakdown (BG-23, grouped by
  category and rate as written, tax per group on its taxable amount;
  category O counts without rate, BR-O-09; existing breakdowns keep their
  exemption reasons and get the one of the lines if they have none, missing
  ones are added, unused ones removed) and the document totals BT-106 to
  BT-110, BT-112 and BT-115 from the line amounts as they are. BT-111,
  BT-113 and BT-114 stay as given. An invoice without lines (MINIMUM,
  BASIC WL) is an error: its totals cannot be calculated.
  DE: Berechnung auf Aufruf (TLandrixEInvoice.CalculateLineAmounts und
  CalculateTotals). Beide rechnen zuerst alles aus und aendern AInvoice nur,
  wenn kein Fehler auftritt; sie liefern die Anzahl der Fehler, die Gruende
  stehen in ADiagnostics. Sie rechnen genau mit den Zahlen, wie die Writer
  sie schreiben (Menge 4 bis 10 Nachkommastellen, Preis 2 oder 4,
  Basismenge bis 10, Saetze 2 bis 4), und runden Betraege halb weg von null auf Cent, wie die
  Writer runden; ein Betrag ueber 9e14 oder eine Summe jenseits von
  Currency ist ein Fehler.
  LandrixEInvoiceCalculateLineAmounts setzt BT-131 jeder Position: Menge x
  Nettopreis / Basismenge (0 gilt als 1), minus Positionsnachlaesse, plus
  Positionszuschlaege; eine Gruppe (Position mit Unterpositionen) erhaelt
  die Summe ihrer DETAIL- und GROUP-Unterpositionen.
  LandrixEInvoiceCalculateTotals setzt die Steueraufschluesselung (BG-23,
  nach Kategorie und Satz wie geschrieben gruppiert, Steuer je Gruppe auf
  ihre Bemessungsgrundlage; Kategorie O zaehlt ohne Satz, BR-O-09;
  vorhandene Eintraege behalten ihre Befreiungsgruende und erhalten den der
  Positionen, wenn sie keinen haben, fehlende kommen dazu, nicht benutzte
  werden entfernt) und die Belegsummen BT-106 bis BT-110, BT-112 und BT-115
  aus den Positionsbetraegen, wie sie sind. BT-111, BT-113 und BT-114
  bleiben wie gegeben. Eine Rechnung ohne Positionen (MINIMUM, BASIC WL)
  ist ein Fehler: ihre Summen lassen sich nicht berechnen. }
function LandrixEInvoiceCalculateLineAmounts(AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
function LandrixEInvoiceCalculateTotals(AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;

implementation

uses
  LandrixXmlBase,
  LandrixEInvoiceCodes,
  LandrixEInvoiceLexical,
  LandrixEInvoiceExact;

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
  I, N: Integer;
  Pending: Boolean;
begin
  { one buffer: appending a character at a time copies the text each time
    on Delphi 6 }
  Result := '';
  SetLength(Result, Length(S));
  N := 0;
  Pending := False;
  for I := 1 to Length(S) do
    if IsSpace(S[I]) then
      Pending := True
    else
    begin
      if Pending and (N > 0) then
      begin
        Inc(N);
        Result[N] := ' ';
      end;
      Inc(N);
      Result[N] := S[I];
      Pending := False;
    end;
  SetLength(Result, N);
end;

function GroupAmount(ALine: TLandrixInvoiceLine; ANoAmountLines: TObjectList): Currency;
var
  I: TLandrixEInvoiceListIndex;
  A, B: Int64;
  Part: Currency;
begin
  { the status as derived: a line with sub lines and no BT-X-8 is a group }
  if (ANoAmountLines.IndexOf(ALine) < 0) or (LandrixEInvoiceLineStatusOf(ALine, False) <> ilsrc_Group) then
  begin
    Result := ALine.LineAmount;
    Exit;
  end;
  Result := 0;
  for I := 0 to ALine.SubInvoiceLines.Count - 1 do
    if LandrixEInvoiceLineStatusOf(ALine.SubInvoiceLines[I], True) in [ilsrc_Detail, ilsrc_Group] then
    begin
      Part := GroupAmount(ALine.SubInvoiceLines[I], ANoAmountLines);
      A := PInt64(@Result)^;
      B := PInt64(@Part)^;
      { a sum beyond Currency stays 0: the calculation reports it }
      if ((B > 0) and (A > High(Int64) - B)) or ((B < 0) and (A < Low(Int64) - B)) then
      begin
        Result := 0;
        Exit;
      end;
      PInt64(@Result)^ := A + B;
    end;
end;

{ Byte order of two texts (no locale). }
function CompareIDs(const A, B: TLandrixEInvoiceString): Integer;
var
  I, N: Integer;
begin
  N := Length(A);
  if Length(B) < N then
    N := Length(B);
  for I := 1 to N do
    if A[I] <> B[I] then
    begin
      Result := Ord(A[I]) - Ord(B[I]);
      Exit;
    end;
  Result := Length(A) - Length(B);
end;

procedure LandrixEInvoiceBuildSubLines(AInvoice: TLandrixInvoice; ALines: TObjectList;
  AParentIDs: TLandrixEInvoiceStringList; ANoAmountLines: TObjectList;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
const
  { sub-line levels below a top line; deeper ones stay where they are (the
    writers and the rendering recurse per level) }
  MaxSubLineDepth = 64;
var
  I, J, K, N, Lo, Hi, Mid, L, R, Width, P, Depth, H: Integer;
  Line, Parent: TLandrixInvoiceLine;
  ParentID: TLandrixEInvoiceString;
  ChildHasCode, Cycle, AnyParent: Boolean;
  X, Y: TLandrixEInvoiceListIndex;
  IDs: array of TLandrixEInvoiceString;
  Order, Temp, ParentOf, Height: array of Integer;
  Problem: TLandrixEInvoiceString;
begin
  N := Integer(ALines.Count);
  { without any parent identifier there is nothing to build }
  AnyParent := False;
  for I := 0 to N - 1 do
    if NormalizeSpace(AParentIDs[I]) <> '' then
      AnyParent := True;
  if not AnyParent then
    N := 0;
  { the identifiers sorted (stable: document order among equal ones), to
    find a parent by binary search instead of a scan per line }
  IDs := nil;
  Order := nil;
  Temp := nil;
  ParentOf := nil;
  Height := nil;
  SetLength(IDs, N);
  SetLength(Order, N);
  SetLength(Temp, N);
  SetLength(ParentOf, N);
  SetLength(Height, N);
  for I := 0 to N - 1 do
  begin
    IDs[I] := NormalizeSpace(TLandrixInvoiceLine(ALines[I]).ID);
    Order[I] := I;
    ParentOf[I] := -1;
    Height[I] := 0;
  end;
  Width := 1;
  while Width < N do
  begin
    Lo := 0;
    while Lo < N do
    begin
      Mid := Lo + Width;
      if Mid > N then
        Mid := N;
      Hi := Mid + Width;
      if Hi > N then
        Hi := N;
      L := Lo;
      R := Mid;
      for K := Lo to Hi - 1 do
        if (L < Mid) and ((R >= Hi) or (CompareIDs(IDs[Order[L]], IDs[Order[R]]) <= 0)) then
        begin
          Temp[K] := Order[L];
          Inc(L);
        end
        else
        begin
          Temp[K] := Order[R];
          Inc(R);
        end;
      Lo := Hi;
    end;
    for K := 0 to N - 1 do
      Order[K] := Temp[K];
    Width := Width * 2;
  end;
  for I := 0 to N - 1 do
  begin
    ParentID := NormalizeSpace(AParentIDs[I]);
    if ParentID = '' then
      Continue;
    Line := TLandrixInvoiceLine(ALines[I]);
    { the first other line in document order with that identifier }
    Lo := 0;
    Hi := N;
    while Lo < Hi do
    begin
      Mid := (Lo + Hi) div 2;
      if CompareIDs(IDs[Order[Mid]], ParentID) < 0 then
        Lo := Mid + 1
      else
        Hi := Mid;
    end;
    P := -1;
    if (Lo < N) and (IDs[Order[Lo]] = ParentID) then
    begin
      if Order[Lo] <> I then
        P := Order[Lo]
      else if (Lo + 1 < N) and (IDs[Order[Lo + 1]] = ParentID) then
        P := Order[Lo + 1];
    end;
    Problem := '';
    if P < 0 then
      Problem := 'not found'
    else
    begin
      { a cycle: the line is an ancestor of the parent; the depth: the
        parent's ancestors, the parent and the levels below the line }
      Cycle := False;
      Depth := 1;
      J := P;
      while ParentOf[J] >= 0 do
      begin
        if ParentOf[J] = I then
          Cycle := True;
        J := ParentOf[J];
        Inc(Depth);
      end;
      if Cycle or (P = I) then
        Problem := 'a cycle'
      else if Depth + Height[I] > MaxSubLineDepth then
        Problem := 'more than 64 levels deep (MaxSubLineDepth)';
    end;
    if Problem <> '' then
    begin
      if ADiagnostics <> nil then
        ADiagnostics.AddDiagnostic(edk_ConversionFailed,
          '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:IncludedSupplyChainTradeLineItem/' +
          'ram:AssociatedDocumentLineDocument/ram:ParentLineID', 0, 0, 0,
          'parent line ' + ParentID + ' of line ' + Line.ID + ': ' + Problem +
          '; the line stays on its level').Severity := eds_Warning;
      Continue;
    end;
    Parent := TLandrixInvoiceLine(ALines[P]);
    AInvoice.InvoiceLines.Extract(Line);
    Parent.SubInvoiceLines.Add(Line);
    ParentOf[I] := P;
    { the levels below each ancestor }
    H := Height[I] + 1;
    J := P;
    while (J >= 0) and (Height[J] < H) do
    begin
      Height[J] := H;
      Inc(H);
      J := ParentOf[J];
    end;
  end;
  for X := 0 to ALines.Count - 1 do
  begin
    Line := TLandrixInvoiceLine(ALines[X]);
    if (Line.SubInvoiceLines.Count = 0) or (Line.LineStatusReasonCode <> ilsrc_None) then
      Continue;
    ChildHasCode := False;
    for Y := 0 to Line.SubInvoiceLines.Count - 1 do
      if Line.SubInvoiceLines[Y].LineStatusReasonCode <> ilsrc_None then
        ChildHasCode := True;
    if ChildHasCode then
      Line.LineStatusReasonCode := ilsrc_Detail;
  end;
  for X := 0 to ANoAmountLines.Count - 1 do
    TLandrixInvoiceLine(ANoAmountLines[X]).LineAmount :=
      GroupAmount(TLandrixInvoiceLine(ANoAmountLines[X]), ANoAmountLines);
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

  { One VAT group of the breakdown: category, rate as written and what goes
    into it.
    DE: Eine Gruppe der Steueraufschluesselung: Kategorie, Satz wie
    geschrieben und was hineinfliesst. }
  TVatGroup = record
    Category: TLandrixInvoiceDutyTaxFeeCategoryCode;
    CategoryOther: TLandrixEInvoiceString;
    RateText: TLandrixEInvoiceString;
    Rate: Double;
    Taxable: Currency;
    Reason: TLandrixEInvoiceString;
    Matched: Boolean;
  end;
  TVatGroups = array of TVatGroup;

  { which lexical form a number is written in }
  TWrittenKind = (wk_Quantity, wk_Price, wk_BaseQuantity, wk_Percent);

const
  { the largest amount taken as input: 9e14 (raw Currency 9e18) }
  MaxRawAmount = 9000000000000000000;

procedure CalcReport(var AState: TCalcState; ASeverity: TLandrixEInvoiceDiagnosticSeverity;
  const ATerms, AMessage: TLandrixEInvoiceString);
var
  D: TLandrixEInvoiceDiagnostic;
begin
  if AState.Diagnostics = nil then
    Exit;
  D := AState.Diagnostics.AddDiagnostic(edk_InvalidValue, '', 0, 0, 0, AMessage);
  D.Severity := ASeverity;
  D.Terms := ATerms;
end;

procedure CalcError(var AState: TCalcState; const ATerms, AMessage: TLandrixEInvoiceString);
begin
  Inc(AState.Errors);
  CalcReport(AState, eds_Error, ATerms, AMessage);
end;

procedure CalcWarning(var AState: TCalcState; const ATerms, AMessage: TLandrixEInvoiceString);
begin
  CalcReport(AState, eds_Warning, ATerms, AMessage);
end;

{ AValue as the writers write it, exact; False for a value they cannot
  format (NaN, infinite, 1e23 and above).
  DE: AValue, wie die Writer es schreiben, genau; False fuer einen Wert,
  den sie nicht formatieren koennen (NaN, unendlich, ab 1e23). }
function WrittenExact(AValue: Double; AKind: TWrittenKind; out AExact: TExact): Boolean;
var
  Text: TLandrixEInvoiceString;
begin
  Result := False;
  AExact := ExactInt(0);
  try
    case AKind of
      wk_Quantity:
        Text := LandrixEInvoiceQuantityToLexical(AValue);
      wk_Price:
        Text := LandrixEInvoicePriceToLexical(AValue);
      wk_BaseQuantity:
        Text := LandrixEInvoiceBaseQuantityToLexical(AValue);
    else
      Text := LandrixEInvoicePercentToLexical(AValue);
    end;
  except
    on ELandrixXmlError do
      Exit;
  end;
  if Text = '' then
    Exit;
  AExact := ExactOf(Text);
  Result := True;
end;

{ The rate of a category as written (2 to 4 decimals): category O has no rate
  (BR-O-05, the writers omit it) and counts with 0 (BR-O-09). '' if the
  rate cannot be written.
  DE: Der Satz einer Kategorie, wie geschrieben (2 bis 4 Nachkommastellen):
  Kategorie O hat keinen Satz (BR-O-05, die Writer lassen ihn weg) und
  zaehlt mit 0 (BR-O-09). '', wenn der Satz nicht geschrieben werden kann. }
function RateTextOf(ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode; ARate: Double): TLandrixEInvoiceString;
begin
  if ACategory = idtfcc_O_ServicesOutsideScopeOfTax then
    ARate := 0;
  try
    Result := LandrixEInvoicePercentToLexical(ARate);
  except
    on ELandrixXmlError do
      Result := '';
  end;
end;

{ AValue rounded to cents half away from zero (as the writers round), on
  the raw Int64 of the Currency (ten thousandths): exact, no Double.
  DE: AValue auf Cent gerundet, halb weg von null (wie die Writer runden),
  auf dem rohen Int64 des Currency (Zehntausendstel): genau, ohne Double. }
function CentsOf(AValue: Currency): Currency;
var
  Raw, R: Int64;
begin
  Raw := PInt64(@AValue)^;
  if (Raw > MaxRawAmount) or (Raw < -MaxRawAmount) then
  begin
    Result := AValue;
    Exit;
  end;
  R := Raw mod 100;
  Raw := Raw - R;
  if R >= 50 then
    Inc(Raw, 100)
  else if R <= -50 then
    Dec(Raw, 100);
  PInt64(@Result)^ := Raw;
end;

{ CentsOf, with an error for a value of 9e14 or more. }
function CheckedCents(var AState: TCalcState; AValue: Currency; const ATerms,
  AWhat: TLandrixEInvoiceString): Currency;
var
  Raw: Int64;
begin
  Raw := PInt64(@AValue)^;
  if (Raw > MaxRawAmount) or (Raw < -MaxRawAmount) then
  begin
    CalcError(AState, ATerms, AWhat + ' is out of range');
    Result := 0;
    Exit;
  end;
  Result := CentsOf(AValue);
end;

{ ASum + AValue, with an error instead of leaving the Currency range
  (only the result counts, so the order of the summands does not matter
  below it).
  DE: ASum + AValue, mit einem Fehler statt den Currency-Bereich zu
  verlassen. }
procedure AddAmount(var AState: TCalcState; var ASum: Currency; AValue: Currency; const ATerms,
  AWhat: TLandrixEInvoiceString);
var
  A, B: Int64;
begin
  A := PInt64(@ASum)^;
  B := PInt64(@AValue)^;
  if ((B > 0) and (A > High(Int64) - B)) or ((B < 0) and (A < Low(Int64) - B)) then
  begin
    CalcError(AState, ATerms, AWhat + ' is out of range');
    Exit;
  end;
  PInt64(@ASum)^ := A + B;
end;

{ Exact cents as Currency. }
function CentsToCurrency(ACents: Int64): Currency;
begin
  PInt64(@Result)^ := ACents * 100;
end;

function CurrencyExact(AValue: Currency): TExact;
begin
  Result := ExactInt(PInt64(@AValue)^);
  { ten thousandths }
  Inc(Result.Scale, 4);
end;

function LineLabel(ALine: TLandrixInvoiceLine): TLandrixEInvoiceString;
begin
  Result := 'line ' + ALine.ID;
end;

{ BT-131 of a line without sub lines: quantity x (net price / base quantity)
  (0 counts as 1; divided first, as PEPPOL-EN16931-R120 does), each as written (quantity with 4 to 10 decimals, the price with
  2 or 4, the base quantity with up to 10), computed exactly and rounded to
  cents, minus the line allowances, plus the line charges (each as written,
  in cents).
  DE: BT-131 einer Position ohne Unterpositionen: Menge x (Nettopreis /
  Basismenge) (0 gilt als 1; zuerst geteilt, wie PEPPOL-EN16931-R120),
  jeweils wie geschrieben (Menge mit 4 bis 10
  Nachkommastellen, Preis mit 2 oder 4, Basismenge mit bis zu 10), genau
  gerechnet und auf Cent gerundet, minus Positionsnachlaesse, plus
  Positionszuschlaege (jeweils wie geschrieben, in Cent). }
function PricedAmount(ALine: TLandrixInvoiceLine; var AState: TCalcState; out AAmount: Currency): Boolean;
var
  Quantity, Price, Base: TExact;
  Cents: Int64;
  I: TLandrixEInvoiceListIndex;
  Item: TLandrixInvoiceAllowanceCharge;
  Errors: Integer;
begin
  Result := False;
  AAmount := 0;
  if ALine.BaseQuantity < 0 then
  begin
    CalcError(AState, 'BT-149', LineLabel(ALine) + ': negative price base quantity');
    Exit;
  end;
  Base := ExactInt(1);
  if (ALine.BaseQuantity <> 0) and not WrittenExact(ALine.BaseQuantity, wk_BaseQuantity, Base) then
  begin
    CalcError(AState, 'BT-149', LineLabel(ALine) + ': the price base quantity cannot be written');
    Exit;
  end;
  { a base quantity that is written as 0 would be rejected (R121) }
  if ExactSign(Base) = 0 then
  begin
    CalcError(AState, 'BT-149', LineLabel(ALine) + ': the price base quantity is written as 0');
    Exit;
  end;
  if not WrittenExact(ALine.Quantity, wk_Quantity, Quantity) or
     not WrittenExact(ALine.NetPriceAmount, wk_Price, Price) or
     not ExactRoundCents(ExactMul(Quantity, ExactDiv(Price, Base)), Cents) then
  begin
    CalcError(AState, 'BT-131', LineLabel(ALine) + ': quantity x price is out of range');
    Exit;
  end;
  AAmount := CentsToCurrency(Cents);
  Errors := AState.Errors;
  for I := 0 to ALine.AllowanceCharges.Count - 1 do
  begin
    Item := ALine.AllowanceCharges[I];
    if Item.ChargeIndicator then
      AddAmount(AState, AAmount, CheckedCents(AState, Item.Amount, 'BT-141', LineLabel(ALine) + ': a charge'),
        'BT-131', LineLabel(ALine) + ': the line amount')
    else
      AddAmount(AState, AAmount, -CheckedCents(AState, Item.Amount, 'BT-136', LineLabel(ALine) + ': an allowance'),
        'BT-131', LineLabel(ALine) + ': the line amount');
  end;
  Result := AState.Errors = Errors;
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
  First, J, Errors: Integer;
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
      begin
        Errors := AState.Errors;
        for K := 0 to Line.SubInvoiceLines.Count - 1 do
        begin
          Sub := Line.SubInvoiceLines[K];
          if LandrixEInvoiceLineStatusOf(Sub, True) in [ilsrc_Detail, ilsrc_Group] then
            for J := First to AState.LineCount - 1 do
              if AState.Lines[J].Line = Sub then
                AddAmount(AState, Amount, AState.Lines[J].Amount, 'BT-131', LineLabel(Line) + ': the group amount');
        end;
        Ok := AState.Errors = Errors;
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

function CategoryLabel(ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode;
  const AOther, ARateText: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  if ACategory = idtfcc_None then
    Result := AOther
  else
    Result := LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(ACategory);
  Result := Result + ' ' + ARateText;
end;

function FindGroup(const AGroups: TVatGroups; ACount: Integer;
  ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode; const AOther, ARateText: TLandrixEInvoiceString): Integer;
var
  I: Integer;
begin
  for I := 0 to ACount - 1 do
    if (AGroups[I].Category = ACategory) and (AGroups[I].RateText = ARateText) and
       ((ACategory <> idtfcc_None) or (AGroups[I].CategoryOther = AOther)) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

{ The line has VAT data of its own (a GROUP line may have none).
  DE: Die Position hat eigene Steuerangaben (eine GROUP-Position darf keine
  haben). }
function HasOwnTax(ALine: TLandrixInvoiceLine): Boolean;
begin
  Result := (ALine.TaxCategory <> idtfcc_None) or not LandrixEInvoiceIsBlank(ALine.TaxCategoryOther);
end;

{ The leaf lines below a group must share its category and rate as
  written: the breakdown takes the top-level line, Factur-X EXTENDED the
  DETAIL lines. A group line without VAT data of its own is only looked
  through.
  DE: Die Blattpositionen unter einer Gruppe muessen deren Kategorie und
  Satz (wie geschrieben) teilen: die Aufschluesselung nimmt die oberste
  Position, Factur-X EXTENDED die DETAIL-Positionen. Durch eine
  Gruppenposition ohne eigene Steuerangaben wird nur hindurchgesehen. }
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
    if (LandrixEInvoiceLineStatusOf(Sub, True) = ilsrc_Group) and not HasOwnTax(Sub) then
    begin
      if not SubLinesMatch(Sub, ATop) then
      begin
        Result := False;
        Exit;
      end;
      Continue;
    end;
    if (Sub.TaxCategory <> ATop.TaxCategory) or
       (RateTextOf(Sub.TaxCategory, Sub.TaxPercent) <> RateTextOf(ATop.TaxCategory, ATop.TaxPercent)) or
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
  if (ALine.SubInvoiceLines.Count = 0) or HasOwnTax(ALine) then
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

procedure AddToGroup(var AState: TCalcState; var AGroups: TVatGroups; var ACount: Integer;
  ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode; const AOther, ARateText: TLandrixEInvoiceString;
  ARate: Double; AAmount: Currency; const AReason: TLandrixEInvoiceString);
var
  G: Integer;
begin
  G := FindGroup(AGroups, ACount, ACategory, AOther, ARateText);
  if G < 0 then
  begin
    G := ACount;
    Inc(ACount);
    AGroups[G].Category := ACategory;
    AGroups[G].CategoryOther := AOther;
    AGroups[G].RateText := ARateText;
    if ACategory = idtfcc_O_ServicesOutsideScopeOfTax then
      AGroups[G].Rate := 0
    else
      AGroups[G].Rate := ARate;
    AGroups[G].Taxable := 0;
    AGroups[G].Reason := '';
    AGroups[G].Matched := False;
  end;
  AddAmount(AState, AGroups[G].Taxable, AAmount, 'BT-116', 'the taxable amount of ' +
    CategoryLabel(ACategory, AOther, ARateText));
  { only categories that need an exemption reason get one (BR-S-10 and
    BR-Z-10 forbid it); a blank one does not hide a later reason }
  if NeedsExemptionReason(ACategory) and LandrixEInvoiceIsBlank(AGroups[G].Reason) and
     not LandrixEInvoiceIsBlank(AReason) then
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
  Lines, Allowances, Charges, TaxTotal, Amount, Payable, Total: Currency;
  RateText: TLandrixEInvoiceString;
  SubRates: array of TLandrixEInvoiceString;
  TaxCents: Int64;
begin
  State.LineCount := 0;
  State.Errors := 0;
  State.Diagnostics := ADiagnostics;
  Groups := nil;
  Existing := nil;
  Taxes := nil;
  SubRates := nil;
  SetLength(Groups, AInvoice.InvoiceLines.Count + AInvoice.AllowanceCharges.Count);
  GroupCount := 0;
  Lines := 0;
  Allowances := 0;
  Charges := 0;

  { MINIMUM and BASIC WL carry totals without lines: they cannot be
    calculated, and an empty breakdown would replace the given one }
  if AInvoice.InvoiceLines.Count = 0 then
  begin
    CalcError(State, 'BG-25', 'the invoice has no lines (MINIMUM, BASIC WL): the totals cannot be calculated');
    Result := State.Errors;
    Exit;
  end;

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
    if not HasOwnTax(Source) then
    begin
      CalcError(State, 'BT-151', LineLabel(Line) + ': no VAT category');
      Continue;
    end;
    RateText := RateTextOf(Source.TaxCategory, Source.TaxPercent);
    if RateText = '' then
    begin
      CalcError(State, 'BT-152', LineLabel(Line) + ': the VAT rate cannot be written');
      Continue;
    end;
    if not SubLinesMatch(Line, Source) then
    begin
      CalcError(State, 'BT-151', LineLabel(Line) + ': the sub lines have another VAT category or rate');
      Continue;
    end;
    Amount := CheckedCents(State, Line.LineAmount, 'BT-131', LineLabel(Line) + ': the line amount');
    AddAmount(State, Lines, Amount, 'BT-106', 'the sum of the line amounts');
    AddToGroup(State, Groups, GroupCount, Source.TaxCategory, Source.TaxCategoryOther, RateText, Source.TaxPercent,
      Amount, Source.TaxExemptionReason);
  end;

  { BG-20 and BG-21 }
  for I := 0 to Integer(AInvoice.AllowanceCharges.Count) - 1 do
  begin
    Item := AInvoice.AllowanceCharges[I];
    Amount := CheckedCents(State, Item.Amount, 'BT-92', 'allowance or charge');
    if (Item.TaxCategory = idtfcc_None) and LandrixEInvoiceIsBlank(Item.TaxCategoryOther) then
    begin
      CalcError(State, 'BT-95', 'allowance or charge ' + LandrixEInvoiceAmountToLexical(Amount) +
        ': no VAT category');
      Continue;
    end;
    RateText := RateTextOf(Item.TaxCategory, Item.TaxPercent);
    if RateText = '' then
    begin
      CalcError(State, 'BT-96', 'allowance or charge ' + LandrixEInvoiceAmountToLexical(Amount) +
        ': the VAT rate cannot be written');
      Continue;
    end;
    if Item.ChargeIndicator then
      AddAmount(State, Charges, Amount, 'BT-108', 'the sum of the charges')
    else
    begin
      AddAmount(State, Allowances, Amount, 'BT-107', 'the sum of the allowances');
      Amount := -Amount;
    end;
    AddToGroup(State, Groups, GroupCount, Item.TaxCategory, Item.TaxCategoryOther, RateText, Item.TaxPercent,
      Amount, '');
  end;

  { the existing breakdowns: one per category and rate as written }
  SetLength(Existing, AInvoice.TaxAmountSubtotals.Count);
  SetLength(SubRates, AInvoice.TaxAmountSubtotals.Count);
  for I := 0 to Integer(AInvoice.TaxAmountSubtotals.Count) - 1 do
  begin
    Sub := AInvoice.TaxAmountSubtotals[I];
    SubRates[I] := RateTextOf(Sub.TaxCategory, Sub.TaxPercent);
    if SubRates[I] = '' then
    begin
      CalcError(State, 'BT-119', 'VAT breakdown ' + CategoryLabel(Sub.TaxCategory, Sub.TaxCategoryOther, '') +
        ': the VAT rate cannot be written');
      Existing[I] := -1;
      Continue;
    end;
    Existing[I] := FindGroup(Groups, GroupCount, Sub.TaxCategory, Sub.TaxCategoryOther, SubRates[I]);
    for J := 0 to I - 1 do
      if (AInvoice.TaxAmountSubtotals[J].TaxCategory = Sub.TaxCategory) and (SubRates[J] = SubRates[I]) and
         ((Sub.TaxCategory <> idtfcc_None) or (AInvoice.TaxAmountSubtotals[J].TaxCategoryOther = Sub.TaxCategoryOther)) then
        CalcError(State, 'BG-23', 'VAT breakdown ' + CategoryLabel(Sub.TaxCategory, Sub.TaxCategoryOther,
          SubRates[I]) + ' occurs twice');
  end;

  { BT-117 per group: the taxable amount x the rate as written, exact,
    rounded once }
  SetLength(Taxes, GroupCount);
  TaxTotal := 0;
  for G := 0 to GroupCount - 1 do
  begin
    Taxes[G] := 0;
    if ExactRoundCents(ExactDiv(ExactMul(CurrencyExact(Groups[G].Taxable), ExactOf(Groups[G].RateText)),
      ExactInt(100)), TaxCents) and (TaxCents < MaxRawAmount div 100) and (TaxCents > -(MaxRawAmount div 100)) then
      Taxes[G] := CentsToCurrency(TaxCents)
    else
      CalcError(State, 'BT-117', 'VAT of ' + CategoryLabel(Groups[G].Category, Groups[G].CategoryOther,
        Groups[G].RateText) + ' is out of range');
    AddAmount(State, TaxTotal, Taxes[G], 'BT-110', 'the VAT total');
  end;

  { BG-22 }
  Total := 0;
  AddAmount(State, Total, Lines, 'BT-109', 'the total without VAT');
  AddAmount(State, Total, -Allowances, 'BT-109', 'the total without VAT');
  AddAmount(State, Total, Charges, 'BT-109', 'the total without VAT');
  Payable := Total;
  AddAmount(State, Payable, TaxTotal, 'BT-112', 'the total with VAT');
  { BT-112 }
  Amount := Payable;
  AddAmount(State, Payable, -CheckedCents(State, AInvoice.PrepaidAmount, 'BT-113', 'the paid amount'),
    'BT-115', 'the amount due');
  AddAmount(State, Payable, CheckedCents(State, AInvoice.PayableRoundingAmount, 'BT-114', 'the rounding amount'),
    'BT-115', 'the amount due');
  for I := 0 to Integer(AInvoice.PrepaidPayments.Count) - 1 do
    AddAmount(State, Payable, CheckedCents(State, AInvoice.PrepaidPayments[I].PaidAmount, 'BT-113',
      'a prepaid amount'), 'BT-115', 'the amount due');

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
        SubRates[I]) + ' removed: no line, allowance or charge has this category and rate');
      AInvoice.TaxAmountSubtotals.Delete(I);
      Continue;
    end;
    Groups[G].Matched := True;
    Sub.TaxableAmount := Groups[G].Taxable;
    Sub.TaxAmount := Taxes[G];
    { category O has no rate (BR-O-05); one left in the model would be
      written }
    if Sub.TaxCategory = idtfcc_O_ServicesOutsideScopeOfTax then
      Sub.TaxPercent := 0;
    { a missing reason is taken from the lines, as for a new breakdown }
    if LandrixEInvoiceIsBlank(Sub.TaxExemptionReason) and LandrixEInvoiceIsBlank(Sub.TaxExemptionReasonCode) then
      Sub.TaxExemptionReason := Groups[G].Reason;
    if NeedsExemptionReason(Sub.TaxCategory) and LandrixEInvoiceIsBlank(Sub.TaxExemptionReason) and
       LandrixEInvoiceIsBlank(Sub.TaxExemptionReasonCode) then
      CalcWarning(State, 'BT-120', 'VAT breakdown ' + CategoryLabel(Sub.TaxCategory, Sub.TaxCategoryOther,
        SubRates[I]) + ' needs an exemption reason (BT-120 or BT-121)');
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
          Groups[G].RateText) + ' needs an exemption reason (BT-120 or BT-121)');
    end;

  { BG-22; BT-113, BT-114 and BT-111 stay as given }
  AInvoice.LineAmount := Lines;
  AInvoice.AllowanceTotalAmount := Allowances;
  AInvoice.ChargeTotalAmount := Charges;
  AInvoice.TaxExclusiveAmount := Total;
  AInvoice.TaxAmountTotal := TaxTotal;
  AInvoice.TaxInclusiveAmount := Amount;
  AInvoice.PayableAmount := Payable;
end;

end.
