{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Runs the golden file sequence of LandrixEInvoiceExampleScenarios with a sink
  that counts the outputs and checks that every target is known. }

unit LandrixEInvoiceTestScenarioRun;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceCheck,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceExampleScenarios,
  LandrixEInvoiceTestGolden;

type
  PRunState = ^TRunState;
  TRunState = record
    Count: Integer;
    WithoutInvoice: Integer;
    UnknownTargets: string;
    RuleErrors: string;
  end;

procedure CountingSink(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  const AFileName: string; AData: Pointer);
var
  State: PRunState;
  Spec: TLandrixEInvoiceSpec;
  D: TLandrixEInvoiceDiagnostics;
  I: TLandrixEInvoiceListIndex;
begin
  State := PRunState(AData);
  Inc(State^.Count);
  if AInvoice = nil then
    Inc(State^.WithoutInvoice);
  if not LandrixEInvoiceFindSpec(ATarget, Spec) then
    State^.UnknownTargets := State^.UnknownTargets + ' ' + AFileName
  else if AInvoice <> nil then
  begin
    { the scenario outputs are valid (KoSIT): no rule may report an error }
    D := TLandrixEInvoiceDiagnostics.Create;
    try
      LandrixEInvoiceCheckInvoice(AInvoice, Spec, D);
      for I := 0 to D.Count - 1 do
        if D[I].Severity = eds_Error then
          State^.RuleErrors := State^.RuleErrors + ' ' + AFileName + ':' + string(D[I].RuleID);
    finally
      D.Free;
    end;
  end;
end;

procedure TestRun;
var
  Dir: string;
  State: TRunState;
begin
  Dir := ScenarioAttachmentDir;
  State.Count := 0;
  State.WithoutInvoice := 0;
  State.UnknownTargets := '';
  State.RuleErrors := '';
  RunAllScenarios(CountingSink, @State, Dir);
  CheckEquals(111, State.Count, 'number of outputs');
  CheckEquals(0, State.WithoutInvoice, 'outputs without invoice');
  CheckEqualsStr('', State.UnknownTargets, 'outputs with unknown target');
  CheckEqualsStr('', State.RuleErrors, 'outputs with rule errors');
end;

procedure Register;
begin
  RegisterTest('Scenarios.Run', TestRun);
end;

end.
