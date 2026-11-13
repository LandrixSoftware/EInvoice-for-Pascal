{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Main form of the workbench: creates the business cases of
  LandrixEInvoiceExampleScenarios for a chosen target, opens XML and PDF
  invoices, checks them natively (the library's own rules, and KoSIT when a
  configuration is set up) and shows the invoice as text and HTML. No Java,
  no web service, no browser control: HTML pages open in the default
  browser. The interface is German (default) or English; the language also
  applies to the invoice and the check report.

  The same unit serves Delphi (VCL, WorkbenchMain.dfm) and Lazarus (LCL,
  WorkbenchMain.lfm). Validation and rendering use units marked
  "API: internal" (LandrixEInvoiceValidation, LandrixEInvoiceRender*): they
  may still change before they become stable. }

unit WorkbenchMain;

{$I LandrixEInvoice.inc}
{$IFDEF FPC}
  { event handlers that do not use Sender }
  {$WARN 5024 OFF}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  LCLIntf,
  {$ELSE}
  Windows,
  ShellAPI,
  {$ENDIF}
  SysUtils,
  Classes,
  Contnrs,
  Controls,
  Forms,
  Dialogs,
  StdCtrls,
  ExtCtrls,
  ComCtrls,
  LandrixXmlBase,
  LandrixXmlEncoding,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoice,
  LandrixEInvoiceReportHtml,
  LandrixEInvoiceValidation;

type
  TWorkbenchForm = class(TForm)
    pnLeft: TPanel;
    rgTarget: TRadioGroup;
    gbOverall: TGroupBox;
    rgPaymentTerms: TRadioGroup;
    cbAllowancesCharges: TCheckBox;
    cbPrepayments: TCheckBox;
    cbAttachments: TCheckBox;
    cbDeliveryAddress: TCheckBox;
    btCreateOverall: TButton;
    lbCasesCaption: TLabel;
    lbCases: TListBox;
    btCreateCase: TButton;
    btOpen: TButton;
    pnBottom: TPanel;
    pnButtons: TPanel;
    btInvoiceHtml: TButton;
    btReportHtml: TButton;
    btSaveXml: TButton;
    lbLanguage: TLabel;
    cxLanguage: TComboBox;
    cbTerms: TCheckBox;
    mmLog: TMemo;
    pcMain: TPageControl;
    tsXml: TTabSheet;
    mmXml: TMemo;
    tsCheck: TTabSheet;
    mmCheck: TMemo;
    tsInvoice: TTabSheet;
    mmInvoice: TMemo;
    tsKosit: TTabSheet;
    pnKosit: TPanel;
    lbKositConfig: TLabel;
    edKositConfig: TEdit;
    lbKositRules: TLabel;
    edKositRules: TEdit;
    btKositLoad: TButton;
    mmKosit: TMemo;
    odOpen: TOpenDialog;
    sdSave: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btCreateOverallClick(Sender: TObject);
    procedure btCreateCaseClick(Sender: TObject);
    procedure btOpenClick(Sender: TObject);
    procedure btKositLoadClick(Sender: TObject);
    procedure btInvoiceHtmlClick(Sender: TObject);
    procedure btReportHtmlClick(Sender: TObject);
    procedure btSaveXmlClick(Sender: TObject);
    procedure cxLanguageChange(Sender: TObject);
    procedure cbTermsClick(Sender: TObject);
  private
    { the invoice shown: FInvoice for a created case, FDocument for an
      opened file; at most one is set }
    FInvoice: TLandrixInvoice;
    FDocument: TLandrixEInvoiceDocument;
    { the XML as written or read (any encoding the reader takes), the same
      as UTF-8, and the bytes checked (the XML, or the opened PDF) }
    FXml: TLandrixXmlUtf8;
    FXmlUtf8: TLandrixXmlUtf8;
    FData: TMemoryStream;
    FName: TLandrixEInvoiceString;
    FChecked: Boolean;
    FValidator: TLandrixEInvoiceDocumentValidator;
    FValidation: TLandrixEInvoiceDocumentValidation;
    { loaded KoSIT configurations (TLandrixEInvoiceValidator, owned) }
    FKosit: TObjectList;
    function German: Boolean;
    function T(const AEnglish, AGerman: string): string;
    function Language: TLandrixEInvoiceReportLanguage;
    procedure ApplyLanguage;
    procedure SetItems(AItems: TStrings; const AEnglish, AGerman: array of string);
    procedure ClearCurrent;
    procedure Log(const AText: string);
    procedure LogDiagnostics(ADiagnostics: TLandrixEInvoiceDiagnostics);
    function SelectedTarget: TLandrixEInvoiceTarget;
    function OutputFolder: string;
    procedure OpenInBrowser(const AFileName: string);
    procedure ShowCreated(AInvoice: TLandrixInvoice; const AName: string; AOwnAddresses: Boolean);
    procedure OpenFile(const AFileName: string);
    procedure CheckData;
    procedure ShowCheck;
    procedure SetXml(const AXml: TLandrixXmlUtf8);
    procedure RoundTrip(const ATarget: TLandrixEInvoiceTarget);
    procedure RenderInvoice;
    procedure LoadKosit;
    function LoadConfiguration(const AFolder: string; AKind: TLandrixEInvoiceConfigurationKind): Boolean;
  end;

var
  WorkbenchForm: TWorkbenchForm;

implementation

uses
  LandrixEInvoicePdf,
  LandrixEInvoiceValidator,
  LandrixEInvoiceValidationHtml,
  LandrixEInvoiceRenderHtml,
  LandrixEInvoiceRenderMarkdown,
  LandrixEInvoiceExampleScenarios;

{$IFDEF FPC}
  {$R *.lfm}
{$ELSE}
  {$R *.dfm}
{$ENDIF}

{ German texts are written in ASCII with markers for the characters outside
  it (the sources stay ASCII): #a #o #u #A #O #U for the umlauts, #s for
  sharp s, #p for the section sign. De turns them into text for the
  controls. }

const
  TargetNames: array[0..4] of string = (
    'XRechnung 3.0 UBL',
    'XRechnung 3.0 CII',
    'ZUGFeRD 2.5 EN 16931',
    'ZUGFeRD 2.5 EXTENDED',
    'Peppol BIS Billing 3.0');

  PaymentTermsEN: array[0..4] of string = (
    'None', 'Net', 'One cash discount', 'Two cash discounts', 'Three cash discounts');
  PaymentTermsDE: array[0..4] of string = (
    'Keine', 'Netto', '1 Skonto', '2 Skonti', '3 Skonti');

  { the cases of btCreateCaseClick, in this order }
  CasesEN: array[0..24] of string = (
    'Small business regulation',
    'Reverse charge (13b UStG)',
    'Exchange part tax',
    'Margin scheme',
    'Title line groups',
    'Credit note',
    'Corrected invoice',
    'Minimal B2B without Leitweg-ID',
    'Price base quantity above 1',
    'Direct debit',
    'Intra-community supply without VAT',
    'Online payment service',
    'Payment card',
    'Period per line',
    'Third party payment BG-DEX-09',
    'Four decimal places',
    'Endpoint schemes 0088/0002',
    'Endpoint schemes EM',
    'Endpoint schemes empty',
    'BT-29/46 identifier only',
    'BT-29/46 GLN and BT-90',
    'BT-29/46 identifier and GLN',
    'Base quantity 0.001',
    'Collective invoice (EXTENDED only)',
    'Title line groups (EXTENDED only)');
  CasesDE: array[0..24] of string = (
    'Kleinunternehmerregelung',
    '#p13b UStG',
    'Austauschteilesteuer',
    'Differenzbesteuerung',
    'Titel/Positionsgruppen',
    'Gutschrift',
    'Rechnungskorrektur/Storno',
    'Minimalrechnung B2B ohne Leitweg-ID',
    'Preiseinheit gr#o#ser 1',
    'Lastschrift',
    'Innergem. Lieferung ohne MwSt.',
    'Online-Zahlungsdienst (PayPal)',
    'Kreditkarte',
    'Leistungszeitraum je Position',
    'Third Party Payment BG-DEX-09',
    '4 Nachkommastellen',
    'Endpoint-Schema 0088/0002',
    'Endpoint-Schema EM',
    'Endpoint-Schema leer',
    'BT-29/46 nur Kennung',
    'BT-29/46 GLN und BT-90',
    'BT-29/46 Kennung und GLN',
    'Basismenge 0,001',
    'Sammelrechnung (nur EXTENDED)',
    'Titel/Positionsgruppen (nur EXTENDED)');

  SeverityEN: array[TLandrixEInvoiceDiagnosticSeverity] of string = ('info', 'warning', 'error');
  SeverityDE: array[TLandrixEInvoiceDiagnosticSeverity] of string = ('Hinweis', 'Warnung', 'Fehler');
  VerdictEN: array[TLandrixEInvoiceVerdict] of string = ('ACCEPTED', 'REJECTED', 'INCOMPLETE');
  VerdictDE: array[TLandrixEInvoiceVerdict] of string = ('ANGENOMMEN', 'ABGELEHNT', 'UNVOLLST#ANDIG');
  PartEN: array[TLandrixEInvoiceValidationPart] of string = (
    'read', 'KoSIT', 'model check', 'PDF embedding', 'PDF metadata', 'PDF/A');
  PartDE: array[TLandrixEInvoiceValidationPart] of string = (
    'Lesen', 'KoSIT', 'Modellpr#ufung', 'PDF-Einbettung', 'PDF-Metadaten', 'PDF/A');
  StatusEN: array[TLandrixEInvoicePartStatus] of string = ('not run', 'passed', 'failed', 'incomplete');
  StatusDE: array[TLandrixEInvoicePartStatus] of string = (
    'nicht gelaufen', 'bestanden', 'nicht bestanden', 'unvollst#andig');

  { XSLT of a KoSIT configuration -> LandrixXML rule file below the rule
    folder (the layout tools/testdata/sync-local.py writes to
    tests/data/local/kosit, as in tools/kosit/ValidatorProbe.dpr) }
  RuleMap: array[0..5, 0..1] of string = (
    ('EN16931-UBL-validation.xsl', 'rules/rules/en16931-ubl.xml'),
    ('EN16931-CII-validation.xsl', 'rules/rules/en16931-cii.xml'),
    ('XRechnung-UBL-validation.xsl', 'rules/rules/xrechnung-ubl.xml'),
    ('XRechnung-CII-validation.xsl', 'rules/rules/xrechnung-cii.xml'),
    ('CEN-EN16931-UBL.xslt', 'rules/rules/en16931-ubl.xml'),
    ('PEPPOL-EN16931-UBL.xslt', 'peppol/PEPPOL-EN16931-UBL.sch'));

{ Text conversions: TLandrixEInvoiceString is UTF-16 everywhere, the
  controls take string (UTF-8 under the LCL, ANSI under Delphi 6-2007). }

function UI(const S: TLandrixEInvoiceString): string;
begin
  Result := LandrixXmlUtf8ToString(LandrixXmlWideToUtf8(S));
end;

function FromUI(const S: string): TLandrixEInvoiceString;
begin
  Result := LandrixXmlUtf8ToWide(LandrixXmlStringToUtf8(S));
end;

{ German text with markers (see above) as text for the controls. }
function De(const S: string): string;
var
  W: TLandrixEInvoiceString;
  I: Integer;
  C: Word;
begin
  W := '';
  I := 1;
  while I <= Length(S) do
  begin
    C := Ord(S[I]);
    if (S[I] = '#') and (I < Length(S)) then
    begin
      case S[I + 1] of
        'a': C := $E4;
        'o': C := $F6;
        'u': C := $FC;
        'A': C := $C4;
        'O': C := $D6;
        'U': C := $DC;
        's': C := $DF;
        'p': C := $A7;
      end;
      if C <> Ord('#') then
        Inc(I);
    end;
    W := W + WideChar(C);
    Inc(I);
  end;
  Result := UI(W);
end;

function StreamText(AStream: TStream): TLandrixXmlUtf8;
begin
  Result := '';
  { an XML invoice in memory is below 2 GB }
  SetLength(Result, Integer(AStream.Size));
  AStream.Position := 0;
  if Length(Result) > 0 then
    AStream.ReadBuffer(PAnsiChar(Result)^, Length(Result));
  AStream.Position := 0;
end;

procedure SetStreamText(AStream: TMemoryStream; const S: TLandrixXmlUtf8);
begin
  AStream.Clear;
  if Length(S) > 0 then
    AStream.WriteBuffer(PAnsiChar(S)^, Length(S));
  AStream.Position := 0;
end;

procedure SaveText(const AFileName: string; const S: TLandrixXmlUtf8);
var
  M: TMemoryStream;
begin
  M := TMemoryStream.Create;
  try
    SetStreamText(M, S);
    M.SaveToFile(AFileName);
  finally
    M.Free;
  end;
end;

{ The first line (1-based) where A and B differ. }
function FirstDifferentLine(const A, B: TLandrixXmlUtf8): Integer;
var
  I, N: Integer;
begin
  Result := 1;
  N := Length(A);
  if Length(B) < N then
    N := Length(B);
  for I := 1 to N do
  begin
    if A[I] <> B[I] then
      Exit;
    if A[I] = #10 then
      Inc(Result);
  end;
end;

{ ARelative below the program's folder or one of its parents (the program
  may run from build/<toolchain>/examples or from the project folder);
  empty if not found. }
function FindUp(const ARelative: string): string;
var
  Dir, Parent: string;
  I: Integer;
begin
  Result := '';
  Dir := ExtractFilePath(ParamStr(0));
  for I := 0 to 6 do
  begin
    if DirectoryExists(Dir + ARelative) then
    begin
      Result := IncludeTrailingPathDelimiter(Dir + ARelative);
      Exit;
    end;
    Parent := ExtractFilePath(ExcludeTrailingPathDelimiter(Dir));
    { at the root ExtractFilePath('D:') gives 'D:' (drive-relative) }
    if (Parent = '') or (Parent = Dir) or not IsPathDelimiter(Parent, Length(Parent)) then
      Exit;
    Dir := Parent;
  end;
end;

{ AName usable as a file name: characters that file systems refuse become '-'. }
function FileNameOf(const AName: string): string;
var
  I: Integer;
begin
  Result := AName;
  for I := 1 to Length(Result) do
    if Pos(Result[I], '/\:*?"<>|') > 0 then
      Result[I] := '-';
  if Result = '' then
    Result := 'invoice';
end;

function Slashes(const S: string): string;
begin
  Result := StringReplace(S, '/', PathDelim, [rfReplaceAll]);
end;

{ Peppol requires electronic addresses with a Peppol scheme (not EM); as
  RunAllScenarios does before every Peppol output. }
procedure PeppolAddresses(AInvoice: TLandrixInvoice);
begin
  AInvoice.AccountingSupplierParty.ElectronicAddressSellerBuyer := '9482348239847239874';
  AInvoice.AccountingSupplierParty.ElectronicAddressSellerBuyerSchemeID := '0088';
  AInvoice.AccountingCustomerParty.ElectronicAddressSellerBuyer := 'FR23342';
  AInvoice.AccountingCustomerParty.ElectronicAddressSellerBuyerSchemeID := '0002';
end;

{ TWorkbenchForm }

procedure TWorkbenchForm.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  FData := TMemoryStream.Create;
  FValidator := TLandrixEInvoiceDocumentValidator.Create;
  FValidation := TLandrixEInvoiceDocumentValidation.Create;
  FKosit := TObjectList.Create(True);
  for I := Low(TargetNames) to High(TargetNames) do
    rgTarget.Items.Add(TargetNames[I]);
  rgTarget.ItemIndex := 0;
  cxLanguage.Items.Add('Deutsch');
  cxLanguage.Items.Add('English');
  cxLanguage.ItemIndex := 0;
  ApplyLanguage;
  rgPaymentTerms.ItemIndex := 1;
  lbCases.ItemIndex := 0;
  pcMain.ActivePage := tsXml;
  sdSave.Options := sdSave.Options + [ofOverwritePrompt];

  { the repository layout: configurations from
    addons/java-tools/install-tools.ps1, rule files from
    tools/testdata/sync-local.py }
  edKositConfig.Text := FindUp('addons' + PathDelim + 'java-tools');
  edKositRules.Text := FindUp('tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim + 'kosit');
  if (edKositConfig.Text <> '') and (edKositRules.Text <> '') then
    LoadKosit
  else
    mmKosit.Lines.Text := T('No KoSIT configuration set up: only the library''s own rules run, ' +
      'the verdict stays INCOMPLETE. Enter both folders and click Load.',
      'Keine KoSIT-Konfiguration eingerichtet: es laufen nur die eigenen Regeln der Bibliothek, ' +
      'das Urteil bleibt UNVOLLST#ANDIG. Beide Ordner eintragen und Laden klicken.');
end;

procedure TWorkbenchForm.FormDestroy(Sender: TObject);
begin
  ClearCurrent;
  FValidator.Free;
  FValidation.Free;
  FKosit.Free;
  FData.Free;
end;

function TWorkbenchForm.German: Boolean;
begin
  Result := cxLanguage.ItemIndex <> 1;
end;

function TWorkbenchForm.T(const AEnglish, AGerman: string): string;
begin
  if German then
    Result := De(AGerman)
  else
    Result := AEnglish;
end;

function TWorkbenchForm.Language: TLandrixEInvoiceReportLanguage;
begin
  if German then
    Result := eln_German
  else
    Result := eln_English;
end;

procedure TWorkbenchForm.SetItems(AItems: TStrings; const AEnglish, AGerman: array of string);
var
  I: Integer;
begin
  AItems.BeginUpdate;
  try
    AItems.Clear;
    { High of an open array is 64-bit on Win64 }
    for I := 0 to Integer(High(AEnglish)) do
      AItems.Add(T(AEnglish[I], AGerman[I]));
  finally
    AItems.EndUpdate;
  end;
end;

{ Sets every caption in the chosen language; lists keep their choice. }
procedure TWorkbenchForm.ApplyLanguage;
var
  Terms, CaseIndex: Integer;
begin
  Terms := rgPaymentTerms.ItemIndex;
  CaseIndex := lbCases.ItemIndex;
  rgTarget.Caption := T('Target', 'Ziel');
  gbOverall.Caption := T('Overall example', 'Gesamtbeispiel');
  rgPaymentTerms.Caption := T('Payment terms', 'Zahlungsbedingungen');
  SetItems(rgPaymentTerms.Items, PaymentTermsEN, PaymentTermsDE);
  rgPaymentTerms.ItemIndex := Terms;
  cbAllowancesCharges.Caption := T('Allowances and charges', 'Nachl#asse und Zuschl#age');
  cbPrepayments.Caption := T('Prepayments', 'Abschlagszahlungen');
  cbAttachments.Caption := T('Attachments', 'Mit Anh#angen');
  cbDeliveryAddress.Caption := T('Delivery address', 'Lieferanschrift');
  btCreateOverall.Caption := T('Create overall example', 'Gesamtbeispiel erzeugen');
  lbCasesCaption.Caption := T('Business cases', 'Gesch#aftsf#alle');
  SetItems(lbCases.Items, CasesEN, CasesDE);
  lbCases.ItemIndex := CaseIndex;
  btCreateCase.Caption := T('Create selected case', 'Gew#ahlten Fall erzeugen');
  btOpen.Caption := T('Open XML or PDF...', 'XML oder PDF #offnen...');
  btInvoiceHtml.Caption := T('Invoice in browser', 'Rechnung im Browser');
  btReportHtml.Caption := T('Report in browser', 'Pr#ufbericht im Browser');
  btSaveXml.Caption := T('Save XML...', 'XML speichern...');
  lbLanguage.Caption := T('Language', 'Sprache');
  cbTerms.Caption := T('Business terms', 'Business Terms (BT)');
  tsCheck.Caption := T('Check', 'Pr#ufung');
  tsInvoice.Caption := T('Invoice', 'Rechnung');
  lbKositConfig.Caption := T('Folder with the KoSIT configurations (validator-configuration-xrechnung, -bis, ' +
    '-zugferd; addons/java-tools/install-tools.ps1)',
    'Ordner mit den KoSIT-Konfigurationen (validator-configuration-xrechnung, -bis, -zugferd; ' +
    'addons/java-tools/install-tools.ps1)');
  lbKositRules.Caption := T('Folder with the LandrixXML rule files (rules/rules, peppol; ' +
    'tools/testdata/sync-local.py)',
    'Ordner mit den Regeldateien von LandrixXML (rules/rules, peppol; tools/testdata/sync-local.py)');
  btKositLoad.Caption := T('Load', 'Laden');
  odOpen.Filter := T('Invoices (*.xml;*.pdf)|*.xml;*.pdf|All files (*.*)|*.*',
    'Rechnungen (*.xml;*.pdf)|*.xml;*.pdf|Alle Dateien (*.*)|*.*');
end;

procedure TWorkbenchForm.cxLanguageChange(Sender: TObject);
begin
  ApplyLanguage;
  ShowCheck;
  RenderInvoice;
end;

procedure TWorkbenchForm.cbTermsClick(Sender: TObject);
begin
  RenderInvoice;
end;

procedure TWorkbenchForm.ClearCurrent;
begin
  FInvoice.Free;
  FInvoice := nil;
  FDocument.Free;
  FDocument := nil;
  FXml := '';
  FXmlUtf8 := '';
  FData.Clear;
  FName := '';
  FChecked := False;
  FValidation.Clear;
  mmXml.Clear;
  mmCheck.Clear;
  mmInvoice.Clear;
  mmLog.Clear;
end;

procedure TWorkbenchForm.Log(const AText: string);
begin
  mmLog.Lines.Add(AText);
end;

procedure TWorkbenchForm.LogDiagnostics(ADiagnostics: TLandrixEInvoiceDiagnostics);
var
  I: Integer;
  D: TLandrixEInvoiceDiagnostic;
  S: string;
begin
  for I := 0 to Integer(ADiagnostics.Count) - 1 do
  begin
    D := ADiagnostics[I];
    S := '  ' + T(SeverityEN[D.Severity], SeverityDE[D.Severity]);
    if D.RuleID <> '' then
      S := S + ' ' + UI(D.RuleID);
    S := S + ': ' + UI(D.Message);
    if D.Path <> '' then
      S := S + ' (' + UI(D.Path) + ')';
    Log(S);
  end;
end;

function TWorkbenchForm.SelectedTarget: TLandrixEInvoiceTarget;
begin
  case rgTarget.ItemIndex of
    1: Result := TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII);
    2: Result := TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_EN16931);
    3: Result := TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Extended);
    4: Result := TLandrixEInvoiceTargets.PeppolBIS('3.0');
  else
    Result := TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL);
  end;
end;

function TWorkbenchForm.OutputFolder: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'workbench-output' + PathDelim;
  ForceDirectories(Result);
end;

procedure TWorkbenchForm.OpenInBrowser(const AFileName: string);
begin
  Log(T('Written ', 'Geschrieben: ') + AFileName);
  {$IFDEF FPC}
  OpenDocument(AFileName);
  {$ELSE}
  ShellExecute(Handle, 'open', PChar(AFileName), nil, nil, SW_SHOWNORMAL);
  {$ENDIF}
end;

{ Shows a created invoice (takes ownership): checks it against the target,
  writes it (despite errors, so that the check result can be seen), checks
  the output, reads it back and writes it again. }
procedure TWorkbenchForm.ShowCreated(AInvoice: TLandrixInvoice; const AName: string; AOwnAddresses: Boolean);
var
  Target: TLandrixEInvoiceTarget;
  D: TLandrixEInvoiceDiagnostics;
  Errors: Integer;
begin
  ClearCurrent;
  FInvoice := AInvoice;
  Target := SelectedTarget;
  FName := FromUI(AName);
  { the endpoint cases bring their own electronic addresses }
  if (Target.Standard = est_PeppolBIS) and not AOwnAddresses then
    PeppolAddresses(FInvoice);
  Screen.Cursor := crHourGlass;
  try
    D := TLandrixEInvoiceDiagnostics.Create;
    try
      Errors := TLandrixEInvoice.Check(FInvoice, Target, [], D);
      Log(AName + T(' as ', ' als ') + UI(LandrixEInvoiceTargetToStr(Target)) + ': ' + IntToStr(Errors) +
        T(' error(s)', ' Fehler'));
      LogDiagnostics(D);
    finally
      D.Free;
    end;
    try
      FXml := TLandrixEInvoice.SaveToUtf8(FInvoice, Target, [eio_WriteDespiteErrors]);
    except
      on E: Exception do
      begin
        Log(T('Not written: ', 'Nicht geschrieben: ') + E.Message);
        Exit;
      end;
    end;
    if Errors > 0 then
      Log(T('Written despite the errors (eio_WriteDespiteErrors); SaveToFile would refuse it',
        'Trotz der Fehler geschrieben (eio_WriteDespiteErrors); SaveToFile w#urde ablehnen'));
    SetXml(FXml);
    SetStreamText(FData, FXml);
    CheckData;
    RoundTrip(Target);
    RenderInvoice;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TWorkbenchForm.btCreateOverallClick(Sender: TObject);
var
  Inv: TLandrixInvoice;
  Attachments: string;
begin
  Attachments := '';
  if cbAttachments.Checked then
  begin
    { next to the program, or in the repository }
    Attachments := FindUp('attachments');
    if (Attachments <> '') and not FileExists(Attachments + 'attachment.pdf') then
      Attachments := '';
    if Attachments = '' then
      Attachments := FindUp('examples' + PathDelim + 'BusinessCases' + PathDelim + 'attachments');
    if Attachments = '' then
    begin
      { ShowMessage, not MessageDlg: Delphi 2009+ inlines MessageDlg only
        with System.UITypes, which Delphi 6 lacks }
      ShowMessage(T('Folder examples/BusinessCases/attachments not found.',
        'Ordner examples/BusinessCases/attachments nicht gefunden.'));
      Exit;
    end;
  end;
  Inv := TLandrixInvoice.Create;
  try
    { the CII binding allows less than UBL (see ScenarioOverallExample) }
    ScenarioOverallExample(Inv, rgPaymentTerms.ItemIndex, cbAllowancesCharges.Checked,
      cbPrepayments.Checked, cbAttachments.Checked, cbDeliveryAddress.Checked,
      SelectedTarget.Syntax = esy_CII, Attachments);
  except
    Inv.Free;
    raise;
  end;
  ShowCreated(Inv, T('Overall example', 'Gesamtbeispiel'), False);
end;

procedure TWorkbenchForm.btCreateCaseClick(Sender: TObject);
var
  Inv: TLandrixInvoice;
  OwnAddresses: Boolean;
begin
  if lbCases.ItemIndex < 0 then
    Exit;
  OwnAddresses := False;
  Inv := TLandrixInvoice.Create;
  try
    case lbCases.ItemIndex of
      0: ScenarioSmallBusinessRegulation(Inv);
      1: ScenarioReverseCharge13b(Inv);
      2: ScenarioExchangePartTax(Inv);
      3: ScenarioMarginScheme(Inv);
      4: ScenarioTitleLineGroups(Inv);
      5: ScenarioCreditNote(Inv);
      6: ScenarioCorrectedInvoice(Inv);
      7: ScenarioMinimalB2BWithoutLeitwegID(Inv);
      8: ScenarioPriceBaseQuantityAbove1(Inv);
      9: ScenarioDirectDebit(Inv);
      10: ScenarioIntraCommunitySupplyWithoutVAT(Inv);
      11: ScenarioOnlinePaymentService(Inv);
      12: ScenarioCreditCard(Inv);
      13: ScenarioLinePeriods(Inv);
      14: ScenarioThirdPartyPaymentBGDEX09(Inv, cbAllowancesCharges.Checked);
      15: ScenarioFourDecimalPlaces(Inv);
      16, 17, 18:
        begin
          case lbCases.ItemIndex of
            16: ScenarioPeppolEndpointSchemeID(Inv, '0088', '0002');
            17: ScenarioPeppolEndpointSchemeID(Inv, 'EM', 'EM');
          else
            ScenarioPeppolEndpointSchemeID(Inv, '', '');
          end;
          OwnAddresses := True;
        end;
      19: ScenarioPartyIdentifierGLN(Inv, True, False, False);
      20: ScenarioPartyIdentifierGLN(Inv, False, True, True);
      21: ScenarioPartyIdentifierGLN(Inv, True, True, False);
      22: ScenarioBaseQuantityDecimals(Inv);
      23: ScenarioCollectiveInvoiceDeliveryNotes(Inv);
    else
      ScenarioTitleLineGroupsExtended(Inv);
    end;
  except
    Inv.Free;
    raise;
  end;
  ShowCreated(Inv, lbCases.Items[lbCases.ItemIndex], OwnAddresses);
end;

procedure TWorkbenchForm.btOpenClick(Sender: TObject);
begin
  if odOpen.Execute then
    OpenFile(odOpen.FileName);
end;

{ Opens an XML invoice or a ZUGFeRD / Factur-X PDF: reads it, checks it and,
  for XML of a known specification, writes it again for comparison. }
procedure TWorkbenchForm.OpenFile(const AFileName: string);
var
  Xml: TMemoryStream;
  AttachmentName: TLandrixEInvoiceString;
  PdfInfo: TLandrixEInvoicePdfExtractInfo;
  IsPdf: Boolean;
begin
  ClearCurrent;
  FName := FromUI(ExtractFileName(AFileName));
  Screen.Cursor := crHourGlass;
  try
    try
      FData.LoadFromFile(AFileName);
    except
      on E: Exception do
      begin
        Log(T('Cannot read ', 'Nicht lesbar: ') + AFileName + ': ' + E.Message);
        Exit;
      end;
    end;
    Log(T('Opened ', 'Ge#offnet: ') + AFileName);
    IsPdf := TLandrixEInvoicePdfExtractor.IsPdfStream(FData);
    FData.Position := 0;
    if IsPdf then
    begin
      Xml := TMemoryStream.Create;
      try
        if TLandrixEInvoicePdfExtractor.ExtractInvoiceFromStream(FData, Xml, AttachmentName, PdfInfo) then
        begin
          FXml := StreamText(Xml);
          Log(T('PDF with the embedded invoice ', 'PDF mit der eingebetteten Rechnung ') + UI(AttachmentName));
        end
        else
          Log(T('No invoice found in the PDF', 'Keine Rechnung im PDF gefunden'));
      finally
        Xml.Free;
      end;
      FData.Position := 0;
    end
    else
      FXml := StreamText(FData);
    SetXml(FXml);

    try
      FDocument := TLandrixEInvoice.LoadFromStream(FData);
    except
      on E: Exception do
        Log(T('Not read: ', 'Nicht gelesen: ') + E.Message);
    end;
    FData.Position := 0;
    if FDocument <> nil then
    begin
      if FDocument.Info.SpecFound then
        Log(T('Specification: ', 'Spezifikation: ') + UI(LandrixEInvoiceTargetToStr(FDocument.Info.Spec.Target)))
      else
        Log(T('Unknown specification: ', 'Unbekannte Spezifikation: ') + UI(FDocument.Info.CustomizationID));
      if FDocument.Diagnostics.Count > 0 then
      begin
        Log(T('While reading:', 'Beim Lesen:'));
        LogDiagnostics(FDocument.Diagnostics);
      end;
    end;
    CheckData;
    if (FDocument <> nil) and FDocument.Info.SpecFound and (FDocument.Info.Source = eso_Xml) then
      RoundTrip(FDocument.Info.Spec.Target);
    RenderInvoice;
  finally
    Screen.Cursor := crDefault;
  end;
end;

{ Checks the bytes in FData (XML or PDF) with the document validator: the
  library's own rules always, KoSIT with the loaded configurations. }
procedure TWorkbenchForm.CheckData;
begin
  FValidation.Clear;
  FData.Position := 0;
  try
    FValidator.ValidateStream(FData, FValidation);
  except
    on E: Exception do
    begin
      Log(T('Check failed: ', 'Pr#ufung gescheitert: ') + E.Message);
      Exit;
    end;
  end;
  FData.Position := 0;
  FChecked := True;
  ShowCheck;
  Log(T('Check: ', 'Pr#ufung: ') + T(VerdictEN[FValidation.Verdict], VerdictDE[FValidation.Verdict]) + ', ' +
    IntToStr(FValidation.FindingCount) + T(' finding(s) (tab Check)', ' Befund(e) (Reiter Pr#ufung)'));
end;

procedure TWorkbenchForm.ShowCheck;
var
  I: Integer;
  P: TLandrixEInvoiceValidationPart;
  F: TLandrixEInvoiceFinding;
  S: string;
  Lines: TStringList;
begin
  mmCheck.Clear;
  if not FChecked then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.Add(T('Verdict: ', 'Urteil: ') + T(VerdictEN[FValidation.Verdict], VerdictDE[FValidation.Verdict]));
    if FValidation.ConfigurationName <> '' then
      Lines.Add(T('KoSIT configuration: ', 'KoSIT-Konfiguration: ') + UI(FValidation.ConfigurationName) +
        T(', scenario: ', ', Szenario: ') + UI(FValidation.ScenarioName));
    for P := Low(TLandrixEInvoiceValidationPart) to High(TLandrixEInvoiceValidationPart) do
      if FValidation.Status[P] <> evr_NotRun then
        Lines.Add('  ' + T(PartEN[P], PartDE[P]) + ': ' +
          T(StatusEN[FValidation.Status[P]], StatusDE[FValidation.Status[P]]));
    Lines.Add('');
    Lines.Add(IntToStr(FValidation.FindingCount) + T(' finding(s)', ' Befund(e)'));
    for I := 0 to FValidation.FindingCount - 1 do
    begin
      F := FValidation.Findings[I];
      S := '[' + T(PartEN[F.Part], PartDE[F.Part]) + '] ' + T(SeverityEN[F.Severity], SeverityDE[F.Severity]);
      if F.RuleID <> '' then
        S := S + ' ' + UI(F.RuleID);
      if F.Predicted then
        S := S + T(' (predicted)', ' (vorhergesagt)');
      if F.Line > 0 then
        S := S + T(' line ', ' Zeile ') + IntToStr(F.Line) + ':' + IntToStr(F.Column);
      S := S + ': ' + UI(F.Text);
      if F.Location <> '' then
        S := S + ' (' + UI(F.Location) + ')';
      Lines.Add(S);
    end;
    mmCheck.Lines.Assign(Lines);
  finally
    Lines.Free;
  end;
end;

{ FXml as text for the XML tab: decoded as the reader does (byte order
  mark, encoding declaration, single-byte encodings) into FXmlUtf8. }
procedure TWorkbenchForm.SetXml(const AXml: TLandrixXmlUtf8);
var
  Input: TLandrixXmlInput;
begin
  FXmlUtf8 := '';
  Input := TLandrixXmlInput.Create;
  try
    try
      Input.LoadFromBuffer(PAnsiChar(AXml)^, Length(AXml));
      SetString(FXmlUtf8, Input.Data, Input.Size);
      mmXml.Lines.Text := LandrixXmlUtf8ToString(FXmlUtf8);
    except
      on E: Exception do
      begin
        FXmlUtf8 := '';
        mmXml.Lines.Text := T('Not shown: ', 'Nicht angezeigt: ') + E.Message;
      end;
    end;
  finally
    Input.Free;
  end;
end;

{ Reads the XML again and writes it for ATarget; a library output must come
  back byte-identical. Files from elsewhere usually differ in layout (and in
  the encoding, compared as UTF-8). }
procedure TWorkbenchForm.RoundTrip(const ATarget: TLandrixEInvoiceTarget);
var
  Doc: TLandrixEInvoiceDocument;
  Again: TLandrixXmlUtf8;
  Folder: string;
begin
  if FXmlUtf8 = '' then
    Exit;
  try
    Doc := TLandrixEInvoice.LoadFromUtf8(FXmlUtf8);
    try
      Again := TLandrixEInvoice.SaveToUtf8(Doc.Invoice, ATarget, [eio_NoRuleCheck, eio_WriteDespiteErrors]);
    finally
      Doc.Free;
    end;
  except
    on E: Exception do
    begin
      Log(T('Round trip failed: ', 'Roundtrip gescheitert: ') + E.Message);
      Exit;
    end;
  end;
  if Again = FXmlUtf8 then
    Log(T('Round trip: read and written again, byte-identical',
      'Roundtrip: gelesen und wieder geschrieben, byte-gleich'))
  else
  begin
    Log(T('Round trip: differs from line ', 'Roundtrip: weicht ab ab Zeile ') +
      IntToStr(FirstDifferentLine(FXmlUtf8, Again)));
    try
      Folder := OutputFolder;
      { the original bytes: FXmlUtf8 keeps the declared encoding }
      SaveText(Folder + 'roundtrip-original.xml', FXml);
      SaveText(Folder + 'roundtrip-again.xml', Again);
      Log(T('  both files in ', '  beide Dateien in ') + Folder);
    except
      on E: Exception do
        Log(T('  not saved: ', '  nicht gespeichert: ') + E.Message);
    end;
  end;
end;

procedure TWorkbenchForm.RenderInvoice;
var
  W: TLandrixEInvoiceRenderMarkdownWriter;
begin
  mmInvoice.Clear;
  if (FInvoice = nil) and (FDocument = nil) then
    Exit;
  W := TLandrixEInvoiceRenderMarkdownWriter.Create;
  try
    W.Language := Language;
    W.ShowBusinessTerms := cbTerms.Checked;
    W.DocumentName := FName;
    try
      if FDocument <> nil then
        mmInvoice.Lines.Text := UI(W.WriteToString(FDocument))
      else
        mmInvoice.Lines.Text := UI(W.WriteToString(FInvoice));
    except
      on E: Exception do
        Log(T('Not rendered: ', 'Nicht dargestellt: ') + E.Message);
    end;
  finally
    W.Free;
  end;
end;

procedure TWorkbenchForm.btInvoiceHtmlClick(Sender: TObject);
var
  W: TLandrixEInvoiceRenderHtmlWriter;
  FileName: string;
begin
  if (FInvoice = nil) and (FDocument = nil) then
    Exit;
  FileName := '';
  W := TLandrixEInvoiceRenderHtmlWriter.Create;
  try
    W.Language := Language;
    W.ShowBusinessTerms := cbTerms.Checked;
    W.DocumentName := FName;
    try
      FileName := OutputFolder + 'invoice.html';
      if FDocument <> nil then
        W.SaveToFile(FDocument, FileName)
      else
        W.SaveToFile(FInvoice, FileName);
    except
      on E: Exception do
      begin
        Log(T('Not written: ', 'Nicht geschrieben: ') + E.Message);
        Exit;
      end;
    end;
  finally
    W.Free;
  end;
  OpenInBrowser(FileName);
end;

procedure TWorkbenchForm.btReportHtmlClick(Sender: TObject);
var
  W: TLandrixEInvoiceValidationHtmlWriter;
  FileName: string;
begin
  if not FChecked then
    Exit;
  FileName := '';
  W := TLandrixEInvoiceValidationHtmlWriter.Create;
  try
    W.Language := Language;
    W.DocumentName := FName;
    try
      FileName := OutputFolder + 'report.html';
      W.SaveToFile(FValidation, FileName);
    except
      on E: Exception do
      begin
        Log(T('Not written: ', 'Nicht geschrieben: ') + E.Message);
        Exit;
      end;
    end;
  finally
    W.Free;
  end;
  OpenInBrowser(FileName);
end;

procedure TWorkbenchForm.btSaveXmlClick(Sender: TObject);
begin
  if FXml = '' then
    Exit;
  if FInvoice <> nil then
    sdSave.FileName := FileNameOf(UI(FName)) + '.xml'
  else
    sdSave.FileName := ChangeFileExt(FileNameOf(UI(FName)), '.xml');
  if sdSave.Execute then
    try
      SaveText(sdSave.FileName, FXml);
      Log(T('Written ', 'Geschrieben: ') + sdSave.FileName);
    except
      on E: Exception do
        Log(T('Not written: ', 'Nicht geschrieben: ') + E.Message);
    end;
end;

procedure TWorkbenchForm.btKositLoadClick(Sender: TObject);
begin
  Screen.Cursor := crHourGlass;
  try
    LoadKosit;
  finally
    Screen.Cursor := crDefault;
  end;
end;

{ Loads the KoSIT configurations found below the configuration folder and
  registers them for the choice per document (precedence ZUGFeRD, Peppol
  BIS, XRechnung). }
procedure TWorkbenchForm.LoadKosit;
var
  Root: string;
  Count: Integer;
begin
  FValidator.Options.ClearConfigurations;
  FKosit.Clear;
  mmKosit.Clear;
  Root := Trim(edKositConfig.Text);
  if Root = '' then
    Exit;
  Root := IncludeTrailingPathDelimiter(Root);
  Count := 0;
  if LoadConfiguration(Root + 'validator-configuration-xrechnung', eck_XRechnung) then
    Inc(Count);
  if LoadConfiguration(Root + 'validator-configuration-bis', eck_PeppolBIS) then
    Inc(Count);
  if LoadConfiguration(Root + 'validator-configuration-zugferd', eck_ZUGFeRD) then
    Inc(Count);
  mmKosit.Lines.Add(IntToStr(Count) + T(' configuration(s) loaded. The first check with a configuration ' +
    'loads its XML schemas and rules and takes a few seconds.',
    ' Konfiguration(en) geladen. Die erste Pr#ufung mit einer Konfiguration l#adt deren XML-Schemas und ' +
    'Regeln und dauert einige Sekunden.'));
  Log('KoSIT: ' + IntToStr(Count) + T(' configuration(s) loaded (tab KoSIT)',
    ' Konfiguration(en) geladen (Reiter KoSIT)'));
end;

function TWorkbenchForm.LoadConfiguration(const AFolder: string;
  AKind: TLandrixEInvoiceConfigurationKind): Boolean;
var
  V: TLandrixEInvoiceValidator;
  Folder, Rules, XsltName, Href, Xslt: string;
  Wrapper: TStringList;
  SR: TSearchRec;
  I, J, P: Integer;
begin
  Result := False;
  Folder := IncludeTrailingPathDelimiter(AFolder);
  if not FileExists(Folder + 'scenarios.xml') then
  begin
    mmKosit.Lines.Add(T('Not found: ', 'Nicht gefunden: ') + Folder + 'scenarios.xml');
    Exit;
  end;
  Rules := IncludeTrailingPathDelimiter(Trim(edKositRules.Text));
  V := TLandrixEInvoiceValidator.Create;
  try
    V.LoadConfiguration(Folder + 'scenarios.xml');
    for I := Low(RuleMap) to High(RuleMap) do
      V.RuleFiles.Values[RuleMap[I, 0]] := Rules + Slashes(RuleMap[I, 1]);
    { the ZUGFeRD configuration ships its Schematron sources: each
      Schema/Factur-X-*.xslt imports <profile>/_XSLT_*/<name>.xslt, whose
      source is <profile>/<name>.sch (compiled when loaded) }
    if FindFirst(Folder + 'Schema' + PathDelim + 'Factur-X-*.xslt', faAnyFile, SR) = 0 then
    begin
      Wrapper := TStringList.Create;
      try
        repeat
          Wrapper.LoadFromFile(Folder + 'Schema' + PathDelim + SR.Name);
          { the href of the xsl:import element }
          Href := Wrapper.Text;
          P := Pos('<xsl:import', Href);
          if P > 0 then
          begin
            Href := Copy(Href, P, MaxInt);
            P := Pos('href="', Href);
          end;
          if P > 0 then
          begin
            Href := Copy(Href, P + 6, MaxInt);
            Href := Copy(Href, 1, Pos('"', Href) - 1);
            Xslt := Folder + 'Schema' + PathDelim + Slashes(Href);
            V.RuleFiles.Values[SR.Name] := ExtractFilePath(ExcludeTrailingPathDelimiter(ExtractFilePath(Xslt))) +
              ChangeFileExt(ExtractFileName(Xslt), '.sch');
          end;
        until FindNext(SR) <> 0;
      finally
        Wrapper.Free;
        FindClose(SR);
      end;
    end;
    { every rule file a scenario needs must exist, else its check raises }
    for I := 0 to V.ScenarioCount - 1 do
      for J := 0 to V.Scenarios[I].SchematronCount - 1 do
      begin
        XsltName := ExtractFileName(V.Scenarios[I].SchematronFiles[J]);
        if not FileExists(V.RuleFiles.Values[XsltName]) then
        begin
          mmKosit.Lines.Add(UI(V.Name) + T(': rule file for ', ': Regeldatei f#ur ') + XsltName +
            T(' missing (', ' fehlt (') + V.RuleFiles.Values[XsltName] +
            T('); configuration not used', '); Konfiguration nicht benutzt'));
          V.Free;
          Exit;
        end;
      end;
  except
    on E: Exception do
    begin
      mmKosit.Lines.Add(Folder + ': ' + E.Message);
      V.Free;
      Exit;
    end;
  end;
  FKosit.Add(V);
  FValidator.Options.AddConfiguration(V, AKind);
  mmKosit.Lines.Add(T('Loaded: ', 'Geladen: ') + UI(V.Name) + ' (' + IntToStr(V.ScenarioCount) +
    T(' scenarios)', ' Szenarien)'));
  Result := True;
end;

end.
