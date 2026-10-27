{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Helpers for running the example scenarios (LandrixEInvoiceExampleScenarios)
  in tests and comparing them with the golden files of XRechnung-for-Delphi. }

unit LandrixEInvoiceTestGolden;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixXmlBase;

{ The attachments of the overall example: examples/BusinessCases/attachments/,
  with a trailing path delimiter. }
function ScenarioAttachmentDir: string;

{ AXml as the golden file AFileName shows it. The golden files of
  XRechnung-for-Delphi carry one invoiced object identifier (BT-18);
  Factur-X EXTENDED takes the second of the scenario as well (owner
  decision 2026-10-21), so it is removed from an EXTENDED output before
  the comparison. }
function GoldenView(const AFileName: string; const AXml: TLandrixXmlUtf8): TLandrixXmlUtf8;

{ The reason this library deliberately writes the golden file AFileName
  differently, '' for any other file; such a file is not compared.
  TitelPositionsgruppen-ubl-peppol.xml: the sub lines are written flat in
  Peppol (UBL-CR-646, KoSIT rejects the nested form; owner decision
  2026-10-27). }
function GoldenDeviation(const AFileName: string): string;

implementation

uses
  SysUtils,
  LandrixEInvoiceTestFramework;

function ScenarioAttachmentDir: string;
begin
  Result := RepositoryRoot + 'examples' + PathDelim + 'BusinessCases' + PathDelim + 'attachments' + PathDelim;
end;

function MatchesAt(const S, ASub: TLandrixXmlUtf8; AAt: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (AAt < 1) or (AAt + Length(ASub) - 1 > Length(S)) then
    Exit;
  for I := 1 to Length(ASub) do
    if S[AAt + I - 1] <> ASub[I] then
      Exit;
  Result := True;
end;

function GoldenDeviation(const AFileName: string): string;
begin
  Result := '';
  if AFileName = 'TitelPositionsgruppen-ubl-peppol.xml' then
    Result := 'sub lines written flat in Peppol';
end;

function GoldenView(const AFileName: string; const AXml: TLandrixXmlUtf8): TLandrixXmlUtf8;
const
  Second: TLandrixXmlUtf8 = '<ram:IssuerAssignedID>BT-18 67890</ram:IssuerAssignedID>';
  StartTag: TLandrixXmlUtf8 = '<ram:AdditionalReferencedDocument>';
  EndTag: TLandrixXmlUtf8 = '</ram:AdditionalReferencedDocument>';
var
  P, First, Last: Integer;
begin
  Result := AXml;
  if Pos('-ciiextended-', AFileName) = 0 then
    Exit;
  P := 1;
  while (P <= Length(Result)) and not MatchesAt(Result, Second, P) do
    Inc(P);
  if P > Length(Result) then
    Exit;
  First := P;
  while (First > 0) and not MatchesAt(Result, StartTag, First) do
    Dec(First);
  Last := P;
  while (Last <= Length(Result)) and not MatchesAt(Result, EndTag, Last) do
    Inc(Last);
  if (First = 0) or (Last > Length(Result)) then
    Exit;
  Delete(Result, First, Last + Length(EndTag) - First);
end;

end.
