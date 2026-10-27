{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Sub invoice lines (BG-DEX-01, line groups) for a target that does not
  write them nested. Only Factur-X EXTENDED (CII) and UBL invoices outside
  Peppol keep the structure; everywhere else the invoice is written flat:
  a group line is replaced by its lines, depth-first, so the sum of the
  written lines (BT-106) stays the same (a group carries the sum of its
  DETAIL and GROUP sub lines). The group lines themselves (title text,
  subtotal) and INFORMATION sub lines are left out; each top-level group
  and each left-out INFORMATION line is reported as a warning. The checks and the mappings work on the same flat copy, so the
  invoice is checked as it is written.

  DE: Unterpositionen (BG-DEX-01, Positionsgruppen) fuer ein Ziel, das sie
  nicht verschachtelt schreibt. Nur Factur-X EXTENDED (CII) und
  UBL-Rechnungen ausserhalb von Peppol behalten die Struktur; ueberall
  sonst wird die Rechnung flach geschrieben: eine Gruppenposition wird
  durch ihre Positionen ersetzt, der Tiefe nach, so dass die Summe der
  geschriebenen Positionen (BT-106) gleich bleibt (eine Gruppe traegt die
  Summe ihrer DETAIL- und GROUP-Unterpositionen). Die Gruppenposition
  selbst (Titel, Zwischensumme) und INFORMATION-Unterpositionen entfallen;
  jede Gruppe der obersten Ebene und jede entfallene INFORMATION-Position
  wird als Warnung gemeldet. Pruefungen und Abbildungen arbeiten auf
  derselben flachen Kopie, die Rechnung wird also so geprueft, wie sie
  geschrieben wird. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceSubLines;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceSpecs;

{ True if ASpec writes the sub lines of AInvoice nested: the rule table
  allows them (LandrixEInvoiceRuleLineSubLines, erl_Allowed) and, in UBL,
  the invoice is no credit note (ubl:CreditNote has no sub lines).
  DE: True, wenn ASpec die Unterpositionen von AInvoice verschachtelt
  schreibt: die Regel-Tabelle erlaubt sie (LandrixEInvoiceRuleLineSubLines,
  erl_Allowed) und in UBL ist die Rechnung keine Gutschrift
  (ubl:CreditNote hat keine Unterpositionen). }
function LandrixEInvoiceSubLinesNested(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;

{ A flat copy of AInvoice for ASpec, nil if AInvoice has no sub lines or
  ASpec writes them nested. A line with sub lines and status GROUP (also
  derived) is replaced by its sub lines, depth-first: DETAIL lines and GROUP
  lines without sub lines become ordinary lines (their status is cleared),
  INFORMATION lines are left out. A DETAIL or INFORMATION line with sub
  lines (only Factur-X EXTENDED knows sub lines at all, and not there) keeps
  its place without them. Every flattened top-level group (naming the
  lines written in its place), every left-out INFORMATION line and every
  left-out set of sub lines is reported (edk_NotAllowed, warning) in
  ADiagnostics (nil: discarded). The
  amounts are not changed; a group whose amount differs from its sub lines
  is flattened all the same, the checks then report the totals as written.
  The caller frees the result.
  DE: Eine flache Kopie von AInvoice fuer ASpec, nil, wenn AInvoice keine
  Unterpositionen hat oder ASpec sie verschachtelt schreibt. Eine Position
  mit Unterpositionen und Status GROUP (auch abgeleitet) wird durch ihre
  Unterpositionen ersetzt, der Tiefe nach: DETAIL-Positionen und
  GROUP-Positionen ohne Unterpositionen werden gewoehnliche Positionen (ihr
  Status wird geleert), INFORMATION-Positionen entfallen. Eine DETAIL- oder
  INFORMATION-Position mit Unterpositionen (Unterpositionen kennt nur
  Factur-X EXTENDED, und dort nicht so) behaelt ihren Platz ohne sie. Jede
  aufgeloeste Gruppe der obersten Ebene (mit den Positionen an ihrer
  Stelle), jede entfallene INFORMATION-Position und jede entfallene
  Gruppe von Unterpositionen wird gemeldet (edk_NotAllowed, Warnung) in
  ADiagnostics (nil: verworfen). Die Betraege
  bleiben unveraendert; eine Gruppe, deren Betrag nicht zu ihren
  Unterpositionen passt, wird trotzdem aufgeloest, die Pruefungen melden
  dann die Summen wie geschrieben. Der Aufrufer gibt das Ergebnis frei. }
function LandrixEInvoiceFlattenSubLines(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixInvoice;

implementation

uses
  Classes,
  Contnrs,
  LandrixEInvoiceCodes,
  LandrixEInvoiceRules,
  LandrixEInvoiceCalc;

function LandrixEInvoiceSubLinesNested(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := (LandrixEInvoiceRuleLevel(ASpec, LandrixEInvoiceRuleLineSubLines) = erl_Allowed) and
    ((ASpec.Target.Syntax <> esy_UBL) or (AInvoice.InvoiceTypeCode <> itc_CreditNote));
end;

function HasSubLines(AInvoice: TLandrixInvoice): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to AInvoice.InvoiceLines.Count - 1 do
    if AInvoice.InvoiceLines[I].SubInvoiceLines.Count > 0 then
      Exit;
  Result := False;
end;

type
  TFlattener = class(TObject)
  private
    FDiagnostics: TLandrixEInvoiceDiagnostics;
    FPath: TLandrixEInvoiceString;
    FReason: TLandrixEInvoiceString;
    { the written lines, in order; extracted from their lists and owned
      until they are handed over }
    FLines: TObjectList;
    FWritten: TLandrixEInvoiceString;
    procedure Warn(const AMessage: TLandrixEInvoiceString);
    procedure Take(AList: TLandrixInvoiceLines; ALine: TLandrixInvoiceLine);
    procedure DropSubLines(ALine: TLandrixInvoiceLine);
    procedure Collect(AGroup: TLandrixInvoiceLine);
  public
    constructor Create(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
      ADiagnostics: TLandrixEInvoiceDiagnostics);
    destructor Destroy; override;
    procedure Execute(AInvoice: TLandrixInvoice);
  end;

constructor TFlattener.Create(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
var
  Rule: TLandrixEInvoiceRule;
begin
  inherited Create;
  FDiagnostics := ADiagnostics;
  FLines := TObjectList.Create(True);
  if ASpec.Target.Syntax = esy_CII then
    FPath := '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:IncludedSupplyChainTradeLineItem'
  else if AInvoice.InvoiceTypeCode = itc_CreditNote then
    FPath := '/CreditNote/cac:CreditNoteLine'
  else
    FPath := '/Invoice/cac:InvoiceLine';
  if LandrixEInvoiceFindRule(ASpec, LandrixEInvoiceRuleLineSubLines, Rule) and (Rule.Level <> erl_Allowed) then
    FReason := TLandrixEInvoiceString(Rule.Terms) + ', ' + TLandrixEInvoiceString(Rule.Source)
  else
    FReason := 'BG-DEX-01, ubl:CreditNote has no sub lines';
end;

destructor TFlattener.Destroy;
begin
  FLines.Free;
  inherited Destroy;
end;

procedure TFlattener.Warn(const AMessage: TLandrixEInvoiceString);
begin
  if FDiagnostics <> nil then
    FDiagnostics.AddDiagnostic(edk_NotAllowed, FPath, 0, 0, 0, AMessage).Severity := eds_Warning;
end;

procedure TFlattener.Take(AList: TLandrixInvoiceLines; ALine: TLandrixInvoiceLine);
begin
  AList.Extract(ALine);
  FLines.Add(ALine);
end;

{ A DETAIL or INFORMATION line cannot carry sub lines (BT-X-8); they are
  left out. DE: Eine DETAIL- oder INFORMATION-Position kann keine
  Unterpositionen tragen (BT-X-8); sie entfallen. }
procedure TFlattener.DropSubLines(ALine: TLandrixInvoiceLine);
begin
  Warn('sub lines of line ' + ALine.ID + ' left out: a line with status DETAIL or INFORMATION has no sub ' +
    'lines (' + FReason + ')');
  ALine.SubInvoiceLines.Clear;
end;

procedure TFlattener.Collect(AGroup: TLandrixInvoiceLine);
var
  Subs: array of TLandrixInvoiceLine;
  Sub: TLandrixInvoiceLine;
  I: TLandrixEInvoiceListIndex;
begin
  { the list changes while lines are taken out }
  Subs := nil;
  SetLength(Subs, AGroup.SubInvoiceLines.Count);
  for I := 0 to AGroup.SubInvoiceLines.Count - 1 do
    Subs[I] := AGroup.SubInvoiceLines[I];
  for I := 0 to Length(Subs) - 1 do
  begin
    Sub := Subs[I];
    case LandrixEInvoiceLineStatusOf(Sub, True) of
      ilsrc_Group:
        if Sub.SubInvoiceLines.Count > 0 then
          Collect(Sub)
        else
        begin
          { an empty group counts in its parent's sum (BR-FXEXT-08): an
            ordinary line. DE: eine leere Gruppe zaehlt in der Summe der
            Oberposition (BR-FXEXT-08): eine gewoehnliche Position. }
          Sub.LineStatusReasonCode := ilsrc_None;
          Sub.LineStatusReasonCodeOther := '';
          Take(AGroup.SubInvoiceLines, Sub);
          FWritten := FWritten + ' ' + Sub.ID;
        end;
      ilsrc_Information:
        Warn('line ' + Sub.ID + ' (status INFORMATION) of group ' + AGroup.ID + ' left out: the invoice is ' +
          'written flat (' + FReason + ')');
    else
      begin
        if Sub.SubInvoiceLines.Count > 0 then
          DropSubLines(Sub);
        Sub.LineStatusReasonCode := ilsrc_None;
        Sub.LineStatusReasonCodeOther := '';
        Take(AGroup.SubInvoiceLines, Sub);
        FWritten := FWritten + ' ' + Sub.ID;
      end;
    end;
  end;
end;

procedure TFlattener.Execute(AInvoice: TLandrixInvoice);
var
  Tops: array of TLandrixInvoiceLine;
  Line: TLandrixInvoiceLine;
  I: TLandrixEInvoiceListIndex;
begin
  Tops := nil;
  SetLength(Tops, AInvoice.InvoiceLines.Count);
  for I := 0 to AInvoice.InvoiceLines.Count - 1 do
    Tops[I] := AInvoice.InvoiceLines[I];
  for I := 0 to Length(Tops) - 1 do
  begin
    Line := Tops[I];
    if Line.SubInvoiceLines.Count = 0 then
      Take(AInvoice.InvoiceLines, Line)
    else if LandrixEInvoiceLineStatusOf(Line, False) = ilsrc_Group then
    begin
      FWritten := '';
      Collect(Line);
      Warn('sub lines of line ' + Line.ID + ' written as lines' + FWritten + '; the group line (title, ' +
        'subtotal) is left out (' + FReason + ')');
    end
    else
    begin
      DropSubLines(Line);
      Take(AInvoice.InvoiceLines, Line);
    end;
  end;
  { what is left are the group lines with their INFORMATION lines }
  AInvoice.InvoiceLines.Clear;
  FLines.OwnsObjects := False;
  for I := 0 to FLines.Count - 1 do
    AInvoice.InvoiceLines.Add(FLines[I]);
  FLines.Clear;
end;

function LandrixEInvoiceFlattenSubLines(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixInvoice;
var
  Flattener: TFlattener;
begin
  Result := nil;
  if not HasSubLines(AInvoice) or LandrixEInvoiceSubLinesNested(AInvoice, ASpec) then
    Exit;
  Result := TLandrixInvoice.Create;
  try
    Result.Assign(AInvoice);
    Flattener := TFlattener.Create(AInvoice, ASpec, ADiagnostics);
    try
      Flattener.Execute(Result);
    finally
      Flattener.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
