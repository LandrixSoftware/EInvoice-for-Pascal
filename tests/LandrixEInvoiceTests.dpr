{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Console test runner. Exit code 0 = all tests passed.

  Usage: LandrixEInvoiceTests [repository-root] [-filter=Prefix] }

program LandrixEInvoiceTests;

{$I LandrixEInvoice.inc}

{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  SysUtils,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestSelf,
  LandrixEInvoiceTestTypes,
  LandrixEInvoiceTestNullable,
  LandrixEInvoiceTestModel,
  LandrixEInvoiceTestCompat,
  LandrixEInvoiceTestSpecs,
  LandrixEInvoiceTestCII;

function FilterParam: string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ParamCount do
    if Copy(ParamStr(I), 1, 8) = '-filter=' then
      Result := Copy(ParamStr(I), 9, MaxInt);
end;

begin
  LandrixEInvoiceTestSelf.Register;
  LandrixEInvoiceTestTypes.Register;
  LandrixEInvoiceTestNullable.Register;
  LandrixEInvoiceTestModel.Register;
  LandrixEInvoiceTestCompat.Register;
  LandrixEInvoiceTestSpecs.Register;
  LandrixEInvoiceTestCII.Register;
  ExitCode := RunAllTests(FilterParam);
end.
