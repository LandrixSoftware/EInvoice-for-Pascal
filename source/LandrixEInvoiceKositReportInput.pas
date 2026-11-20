{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The input of the KoSIT report stylesheet (in:createReportInput, framework
  version 1.0.2) for a result of LandrixEInvoiceValidator, as the KoSIT
  validator builds it: engine, time, document hash and reference, the
  chosen scenario as the configuration writes it, the results of the
  well-formedness, XML schema and Schematron steps (each Schematron step
  with its SVRL) and the processing errors (a well-formedness error is one
  too, as in KoSIT). The report stylesheet of the
  configuration (Result.ReportFile) turns it into the KoSIT report
  (LandrixEInvoiceKositReport). No XSLT is needed here.
  The Schematron steps need their SVRL: validate with KeepSvrl set.
  A message of the XML schema step is written as Xerces writes it (the
  code, a colon and the text) with the severity SEVERITY_ERROR; a
  well-formedness error with SEVERITY_FATAL_ERROR.
  DE: Der Eingang des KoSIT-Bericht-Stylesheets (in:createReportInput,
  Framework-Version 1.0.2) fuer ein Ergebnis von LandrixEInvoiceValidator,
  wie der KoSIT-Validator ihn aufbaut: Engine, Zeit, Hash und Verweis des
  Dokuments, das gewaehlte Szenario, wie die Konfiguration es schreibt, die
  Ergebnisse der Schritte Wohlgeformtheit, XML-Schema und Schematron (jeder
  Schematron-Schritt mit seinem SVRL) und die Verarbeitungsfehler (ein
  Wohlgeformtheitsfehler ist auch einer, wie bei KoSIT). Das
  Bericht-Stylesheet der Konfiguration (Result.ReportFile) macht daraus den
  KoSIT-Bericht (LandrixEInvoiceKositReport). Hier ist kein XSLT noetig.
  Die Schematron-Schritte brauchen ihr SVRL: mit gesetztem KeepSvrl
  pruefen. Eine Meldung des XML-Schema-Schritts wird geschrieben, wie
  Xerces sie schreibt (Code, Doppelpunkt, Text), mit der Schwere
  SEVERITY_ERROR; ein Wohlgeformtheitsfehler mit SEVERITY_FATAL_ERROR. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceKositReportInput;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoiceValidator;

type
  { Writes the KoSIT report input of a validation result.
    DE: Schreibt den Eingang des KoSIT-Berichts zu einem Pruefergebnis. }
  TLandrixEInvoiceKositReportInputWriter = class(TObject)
  private
    FEngineName: TLandrixEInvoiceString;
  public
    constructor Create;
    { Writes the report input of AResult as UTF-8 XML. Raises
      ELandrixEInvoiceError when a Schematron step that ran has no SVRL
      (the result was made without KeepSvrl) or the result has no steps (it
      was not filled by a validation).
      DE: Schreibt den Berichtseingang zu AResult als UTF-8-XML. Loest
      ELandrixEInvoiceError aus, wenn ein Schematron-Schritt, der lief,
      kein SVRL hat (das Ergebnis entstand ohne KeepSvrl) oder das Ergebnis
      keine Schritte hat (es wurde nicht von einer Pruefung gefuellt). }
    procedure WriteToStream(AResult: TLandrixEInvoiceValidationResult; AStream: TStream);
    { The same into a file. DE: Dasselbe in eine Datei. }
    procedure SaveToFile(AResult: TLandrixEInvoiceValidationResult; const AFileName: string);
    { in:engine/in:name; default "EInvoice-for-Pascal" and the version.
      DE: in:engine/in:name; Vorgabe "EInvoice-for-Pascal" und die
      Version. }
    property EngineName: TLandrixEInvoiceString read FEngineName write FEngineName;
  end;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixXmlWriter,
  LandrixEInvoiceReportHtml;

const
  InputNs = 'http://www.xoev.de/de/validator/framework/1/createreportinput';
  FrameworkVersion = '1.0.2';

constructor TLandrixEInvoiceKositReportInputWriter.Create;
begin
  inherited Create;
  FEngineName := 'EInvoice-for-Pascal ' + LandrixEInvoiceVersion;
end;

{ Characters outside XML 1.0 (a control character in a file name or a
  message) become U+FFFD, as in the validation report; the writer would
  refuse them. }
function Utf8(const S: TLandrixEInvoiceString): TLandrixXmlUtf8;
var
  Sanitized: Boolean;
begin
  Sanitized := False;
  Result := LandrixEInvoiceStringToUtf8(LandrixEInvoiceReportSanitize(S, Sanitized));
end;

{ An in:xmlSyntaxError for a message of the well-formedness or XML schema
  step. }
procedure WriteSyntaxError(W: TLandrixXmlWriter; M: TLandrixEInvoiceValidationMessage);
var
  Text: TLandrixEInvoiceString;
begin
  if Copy(M.Code, 1, 4) = 'cvc-' then
    Text := M.Code + ': ' + M.Text
  else
    Text := M.Text;
  W.StartElementNs(InputNs, 'in', 'xmlSyntaxError');
  W.ElementNsUtf8(InputNs, 'in', 'message', Utf8(Text));
  if M.Step = evs_Wellformedness then
    W.ElementNsUtf8(InputNs, 'in', 'severityCode', 'SEVERITY_FATAL_ERROR')
  else
    W.ElementNsUtf8(InputNs, 'in', 'severityCode', 'SEVERITY_ERROR');
  if M.Line > 0 then
    W.ElementNsUtf8(InputNs, 'in', 'rowNumber', LandrixXmlStringToUtf8(IntToStr(M.Line)));
  if M.Column > 0 then
    W.ElementNsUtf8(InputNs, 'in', 'columnNumber', LandrixXmlStringToUtf8(IntToStr(M.Column)));
  W.EndElement;
end;

procedure TLandrixEInvoiceKositReportInputWriter.WriteToStream(AResult: TLandrixEInvoiceValidationResult;
  AStream: TStream);
var
  W: TLandrixXmlWriter;
  Step: TLandrixEInvoiceValidationStepResult;
  I, K: Integer;
  HasErrors: Boolean;
begin
  if AResult = nil then
    raise ELandrixEInvoiceError.Create('KoSIT report input: no result');
  if AResult.StepCount = 0 then
    raise ELandrixEInvoiceError.Create('KoSIT report input: the result has no steps');
  for I := 0 to AResult.StepCount - 1 do
  begin
    Step := AResult.Steps[I];
    if (Step.Step = evs_Schematron) and (Step.ProcessingError = '') and (Step.Svrl = '') then
      raise ELandrixEInvoiceError.Create('KoSIT report input: a Schematron step has no SVRL (validate with KeepSvrl)');
  end;
  W := TLandrixXmlWriter.Create(AStream);
  try
    W.StartDocument;
    W.StartElementNs(InputNs, 'in', 'createReportInput');
    W.AttributeUtf8('frameworkVersion', FrameworkVersion);
    W.StartElementNs(InputNs, 'in', 'engine');
    W.ElementNsUtf8(InputNs, 'in', 'name', Utf8(FEngineName));
    W.EndElement;
    W.ElementNsUtf8(InputNs, 'in', 'timestamp', Utf8(AResult.Timestamp));
    W.StartElementNs(InputNs, 'in', 'documentIdentification');
    W.StartElementNs(InputNs, 'in', 'documentHash');
    W.ElementNsUtf8(InputNs, 'in', 'hashAlgorithm', 'SHA-256');
    W.ElementNsUtf8(InputNs, 'in', 'hashValue', Utf8(AResult.DocumentHash));
    W.EndElement;
    W.ElementNsUtf8(InputNs, 'in', 'documentReference', Utf8(AResult.DocumentReference));
    W.EndElement;
    if AResult.ScenarioXml <> '' then
      LandrixEInvoiceWriteXmlFragment(AResult.ScenarioXml, W);
    for I := 0 to AResult.StepCount - 1 do
    begin
      Step := AResult.Steps[I];
      case Step.Step of
        evs_Wellformedness:
          begin
            W.StartElementNs(InputNs, 'in', 'validationResultsWellformedness');
            for K := 0 to AResult.MessageCount - 1 do
              if AResult.Messages[K].Step = evs_Wellformedness then
                WriteSyntaxError(W, AResult.Messages[K]);
            W.EndElement;
          end;
        evs_XmlSchema:
          begin
            W.StartElementNs(InputNs, 'in', 'validationResultsXmlSchema');
            LandrixEInvoiceWriteXmlFragment(Step.ResourceXml, W);
            for K := 0 to AResult.MessageCount - 1 do
              if AResult.Messages[K].Step = evs_XmlSchema then
                WriteSyntaxError(W, AResult.Messages[K]);
            W.EndElement;
          end;
        evs_Schematron:
          { a step with a processing error has no results (KoSIT's XSLT
            failed); the error follows below }
          if Step.ProcessingError = '' then
          begin
            W.StartElementNs(InputNs, 'in', 'validationResultsSchematron');
            LandrixEInvoiceWriteXmlFragment(Step.ResourceXml, W);
            W.StartElementNs(InputNs, 'in', 'results');
            { without svrl:suppressed-rule, which the SVRL schema of KoSIT
              does not allow there
              DE: ohne svrl:suppressed-rule, das das SVRL-Schema von KoSIT
              dort nicht erlaubt }
            LandrixEInvoiceWriteXmlFragment(Step.Svrl, W, True);
            W.EndElement;
            W.EndElement;
          end;
      end;
    end;
    { as KoSIT: a well-formedness error is a processing error too, then
      the errors of the Schematron steps }
    HasErrors := False;
    for I := 0 to AResult.MessageCount - 1 do
      if AResult.Messages[I].Step = evs_Wellformedness then
      begin
        if not HasErrors then
          W.StartElementNs(InputNs, 'in', 'processingError');
        HasErrors := True;
        W.ElementNsUtf8(InputNs, 'in', 'error', Utf8(AResult.Messages[I].Text));
      end;
    for I := 0 to AResult.StepCount - 1 do
      if AResult.Steps[I].ProcessingError <> '' then
      begin
        if not HasErrors then
          W.StartElementNs(InputNs, 'in', 'processingError');
        HasErrors := True;
        W.ElementNsUtf8(InputNs, 'in', 'error', Utf8(AResult.Steps[I].ProcessingError));
      end;
    if HasErrors then
      W.EndElement;
    W.EndElement;
    W.EndDocument;
  finally
    W.Free;
  end;
end;

procedure TLandrixEInvoiceKositReportInputWriter.SaveToFile(AResult: TLandrixEInvoiceValidationResult;
  const AFileName: string);
var
  M: TMemoryStream;
begin
  { in memory first: an error while building the input leaves an
    existing file as it was }
  M := TMemoryStream.Create;
  try
    WriteToStream(AResult, M);
    M.SaveToFile(AFileName);
  finally
    M.Free;
  end;
end;

end.
