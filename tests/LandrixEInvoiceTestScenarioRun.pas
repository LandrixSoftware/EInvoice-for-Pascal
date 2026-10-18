{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Runs the golden file sequence of LandrixEInvoiceTestScenarios with a sink
  that counts the outputs and checks that every target is known. Needs the
  local attachments (tests/data/local/attachments/); skipped when the folder
  does not exist. }

unit LandrixEInvoiceTestScenarioRun;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  LandrixEInvoiceTypes,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestScenarios;

type
  PRunState = ^TRunState;
  TRunState = record
    Count: Integer;
    WithoutInvoice: Integer;
    UnknownTargets: string;
  end;

procedure CountingSink(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  const AFileName: string; AData: Pointer);
var
  State: PRunState;
  Spec: TLandrixEInvoiceSpec;
begin
  State := PRunState(AData);
  Inc(State^.Count);
  if AInvoice = nil then
    Inc(State^.WithoutInvoice);
  if not LandrixEInvoiceFindSpec(ATarget, Spec) then
    State^.UnknownTargets := State^.UnknownTargets + ' ' + AFileName;
end;

procedure TestRun;
var
  Dir: string;
  State: TRunState;
begin
  Dir := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim +
    'attachments' + PathDelim;
  if not DirectoryExists(Dir) then
  begin
    Skip('no local attachments in ' + Dir);
    Exit;
  end;
  State.Count := 0;
  State.WithoutInvoice := 0;
  State.UnknownTargets := '';
  RunAllScenarios(CountingSink, @State, Dir);
  CheckEquals(111, State.Count, 'number of outputs');
  CheckEquals(0, State.WithoutInvoice, 'outputs without invoice');
  CheckEqualsStr('', State.UnknownTargets, 'outputs with unknown target');
end;

procedure Register;
begin
  RegisterTest('Scenarios.Run', TestRun);
end;

end.
