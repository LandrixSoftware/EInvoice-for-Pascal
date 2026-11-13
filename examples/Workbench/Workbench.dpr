{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Example: a window to try the library, in the spirit of the sample project
  of XRechnung-for-Delphi, but native only (no Java, no web service, no
  browser control). Create the overall example with options or one of the
  business cases for a target (XRechnung UBL/CII, ZUGFeRD EN 16931 and
  EXTENDED, Peppol BIS), or open an XML invoice or a ZUGFeRD / Factur-X PDF;
  the workbench then shows the XML, checks it (the library's own rules, and
  KoSIT when a configuration is set up in the tab KoSIT), reads it back and
  writes it again, and shows the invoice as text; HTML pages of the invoice
  and of the check open in the default browser.

  Delphi 6 to 13 (VCL, WorkbenchMain.dfm) and Lazarus (LCL,
  WorkbenchMain.lfm, project Workbench.lpi, built with lazbuild or the
  Lazarus IDE). Search path (Delphi): ..\..\source,
  ..\..\external\landrix-xml\source and ..\BusinessCases (the business
  cases). Writing every business case for every target is the console
  example BusinessCases. }

program Workbench;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
  {$IFDEF FPC}
  Interfaces,
  {$ENDIF}
  Forms,
  WorkbenchMain in 'WorkbenchMain.pas' {WorkbenchForm};

begin
  Application.Initialize;
  Application.CreateForm(TWorkbenchForm, WorkbenchForm);
  Application.Run;
end.
