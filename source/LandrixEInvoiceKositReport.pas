{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The KoSIT report (rep:report) of a validation, made as the KoSIT
  validator makes it: the report input (LandrixEInvoiceKositReportInput)
  is transformed with the report stylesheet of the configuration
  (Result.ReportFile: the scenario's createReport, without a scenario the
  noScenarioReport), the validated document passed as the parameter
  input-document (when it is not well-formed, as in KoSIT, a document
  in:error-message with the well-formedness error). The
  stylesheet embeds an HTML page in the report; it is extracted as the KoSIT
  validator does with --extract-html (the first html:html element). The
  XSLT engine is the one of LandrixXML; only this unit and
  LandrixEInvoiceKositVisualization link it.
  The report's assessment (Accepted) comes from the stylesheet. It is the
  validator's verdict for the configurations with acceptMatch (XRechnung,
  ZUGFeRD); a Peppol BIS scenario has none, and the validator then rejects
  any failed assert, also a warning, while the report may recommend to
  accept.
  The validation must keep the SVRL (TLandrixEInvoiceValidator.KeepSvrl).
  DE: Der KoSIT-Bericht (rep:report) einer Pruefung, erzeugt wie im
  KoSIT-Validator: der Berichtseingang (LandrixEInvoiceKositReportInput)
  wird mit dem Bericht-Stylesheet der Konfiguration transformiert
  (Result.ReportFile: das createReport des Szenarios, ohne Szenario das
  noScenarioReport), das gepruefte Dokument als Parameter input-document
  (wenn es nicht wohlgeformt ist, wie bei KoSIT ein Dokument
  in:error-message mit dem Wohlgeformtheitsfehler). Das Stylesheet bettet
  eine HTML-Seite in den Bericht ein; sie wird herausgeloest wie im
  KoSIT-Validator mit --extract-html (das erste Element html:html). Die
  XSLT-Maschine ist die von LandrixXML; nur diese Unit und
  LandrixEInvoiceKositVisualization binden sie ein.
  Die Bewertung des Berichts (Accepted) kommt aus dem Stylesheet. Sie ist
  das Urteil des Validators bei den Konfigurationen mit acceptMatch
  (XRechnung, ZUGFeRD); ein Szenario von Peppol BIS hat keines, der
  Validator lehnt dann jedes fehlgeschlagene assert ab, auch eine Warnung,
  waehrend der Bericht die Annahme empfehlen kann.
  Die Pruefung muss das SVRL behalten (TLandrixEInvoiceValidator.KeepSvrl). }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceKositReport;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixXmlBase,
  LandrixEInvoiceTypes,
  LandrixEInvoiceValidator,
  LandrixEInvoiceValidation;

type
  { A KoSIT report: the XML as the stylesheet writes it and the HTML page
    in it.
    DE: Ein KoSIT-Bericht: das XML, wie das Stylesheet es schreibt, und die
    HTML-Seite darin. }
  TLandrixEInvoiceKositReport = class(TObject)
  private
    FXml: TLandrixXmlUtf8;
    FHtml: TLandrixXmlUtf8;
    FAccepted: Boolean;
    function GetHasHtml: Boolean;
    procedure SaveUtf8(const S: TLandrixXmlUtf8; AStream: TStream);
    procedure SaveUtf8File(const S: TLandrixXmlUtf8; const AFileName: string);
  public
    { The report as XML, serialized as the KoSIT validator writes it (not
      indented).
      DE: Der Bericht als XML, serialisiert wie der KoSIT-Validator ihn
      schreibt (nicht eingerueckt). }
    procedure SaveXmlToStream(AStream: TStream);
    procedure SaveXmlToFile(const AFileName: string);
    { The HTML page of the report (as the KoSIT validator extracts it);
      raises ELandrixEInvoiceError when the report has none (HasHtml).
      DE: Die HTML-Seite des Berichts (wie der KoSIT-Validator sie
      herausloest); loest ELandrixEInvoiceError aus, wenn der Bericht keine
      hat (HasHtml). }
    procedure SaveHtmlToStream(AStream: TStream);
    procedure SaveHtmlToFile(const AFileName: string);
    { True if the report recommends to accept
      (/rep:report/rep:assessment[1]/rep:accept[1] exists).
      DE: True, wenn der Bericht die Annahme empfiehlt
      (/rep:report/rep:assessment[1]/rep:accept[1] existiert). }
    property Accepted: Boolean read FAccepted;
    { True if the report contains an HTML page.
      DE: True, wenn der Bericht eine HTML-Seite enthaelt. }
    property HasHtml: Boolean read GetHasHtml;
  end;

  { Makes KoSIT reports; the report stylesheets are compiled once and kept.
    One object per thread.
    DE: Erzeugt KoSIT-Berichte; die Bericht-Stylesheets werden einmal
    uebersetzt und behalten. Ein Objekt je Thread. }
  TLandrixEInvoiceKositReporter = class(TObject)
  private
    FStylesheets: TStringList;
    FInputWriter: TObject;
    function GetEngineName: TLandrixEInvoiceString;
    procedure SetEngineName(const AValue: TLandrixEInvoiceString);
    function StylesheetOf(const AFileName: string): TObject;
    function DoCreateReport(AResult: TLandrixEInvoiceValidationResult;
      ADocument: TStream): TLandrixEInvoiceKositReport;
  public
    constructor Create;
    destructor Destroy; override;
    { The report of AResult; ADocument is the validated document (read
      from its position to the end; nil: none). The caller frees the
      report. Raises ELandrixEInvoiceError when the result names no report
      stylesheet, a Schematron step has no SVRL, or the stylesheet does not
      load or fails.
      DE: Der Bericht zu AResult; ADocument ist das gepruefte Dokument
      (gelesen ab seiner Position bis zum Ende; nil: keines). Der Aufrufer
      gibt den Bericht frei. Loest ELandrixEInvoiceError aus, wenn das
      Ergebnis kein Bericht-Stylesheet nennt, ein Schematron-Schritt kein
      SVRL hat oder das Stylesheet nicht laedt oder scheitert. }
    function CreateReport(AResult: TLandrixEInvoiceValidationResult;
      ADocument: TStream): TLandrixEInvoiceKositReport; overload;
    { The same for the KoSIT run of a document validation (its Kosit and
      InvoiceXml); raises ELandrixEInvoiceError without a KoSIT run.
      DE: Dasselbe fuer den KoSIT-Lauf einer Dokumentpruefung (ihr Kosit
      und InvoiceXml); loest ohne KoSIT-Lauf ELandrixEInvoiceError aus. }
    function CreateReport(AValidation: TLandrixEInvoiceDocumentValidation): TLandrixEInvoiceKositReport; overload;
    { in:engine/in:name of the report input; default "EInvoice-for-Pascal"
      and the version.
      DE: in:engine/in:name des Berichtseingangs; Vorgabe
      "EInvoice-for-Pascal" und die Version. }
    property EngineName: TLandrixEInvoiceString read GetEngineName write SetEngineName;
  end;

implementation

uses
  SysUtils,
  LandrixXmlReader,
  LandrixXmlWriter,
  LandrixXmlXPathTree,
  LandrixXmlXPath,
  LandrixXmlXPathEval,
  LandrixXmlXslt,
  LandrixEInvoiceKositReportInput;

const
  RepNs = 'http://www.xoev.de/de/validator/varl/1';
  InputNs = 'http://www.xoev.de/de/validator/framework/1/createreportinput';
  HtmlNs = 'http://www.w3.org/1999/xhtml';
  { the first html:html of the report, serialized as the KoSIT validator
    writes it with --extract-html: indented, the output method from the
    html root (xhtml).
    DE: das erste html:html des Berichts, serialisiert wie der
    KoSIT-Validator es mit --extract-html schreibt: eingerueckt, die
    Ausgabemethode aus der Wurzel html (xhtml). }
  ExtractHtml =
    '<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" ' +
    'xmlns:html="http://www.w3.org/1999/xhtml">' +
    '<xsl:output indent="yes" encoding="UTF-8"/>' +
    '<xsl:template match="/"><xsl:copy-of select="(//html:html)[1]"/></xsl:template>' +
    '</xsl:stylesheet>';
  ExtractHtmlKey = '*extract-html*';

procedure Fail(const AMsg: string);
begin
  raise ELandrixEInvoiceError.Create('KoSIT report: ' + AMsg);
end;

{ --- TLandrixEInvoiceKositReport ----------------------------------------- }

function TLandrixEInvoiceKositReport.GetHasHtml: Boolean;
begin
  Result := FHtml <> '';
end;

procedure TLandrixEInvoiceKositReport.SaveUtf8(const S: TLandrixXmlUtf8; AStream: TStream);
begin
  if S <> '' then
    AStream.WriteBuffer(PAnsiChar(S)^, Length(S));
end;

procedure TLandrixEInvoiceKositReport.SaveUtf8File(const S: TLandrixXmlUtf8; const AFileName: string);
var
  F: TFileStream;
begin
  F := TFileStream.Create(AFileName, fmCreate);
  try
    SaveUtf8(S, F);
  finally
    F.Free;
  end;
end;

procedure TLandrixEInvoiceKositReport.SaveXmlToStream(AStream: TStream);
begin
  SaveUtf8(FXml, AStream);
end;

procedure TLandrixEInvoiceKositReport.SaveXmlToFile(const AFileName: string);
begin
  SaveUtf8File(FXml, AFileName);
end;

procedure TLandrixEInvoiceKositReport.SaveHtmlToStream(AStream: TStream);
begin
  if FHtml = '' then
    Fail('the report has no HTML page');
  SaveUtf8(FHtml, AStream);
end;

procedure TLandrixEInvoiceKositReport.SaveHtmlToFile(const AFileName: string);
begin
  if FHtml = '' then
    Fail('the report has no HTML page');
  SaveUtf8File(FHtml, AFileName);
end;

{ --- TLandrixEInvoiceKositReporter --------------------------------------- }

constructor TLandrixEInvoiceKositReporter.Create;
begin
  inherited Create;
  FStylesheets := TStringList.Create;
  FInputWriter := TLandrixEInvoiceKositReportInputWriter.Create;
end;

destructor TLandrixEInvoiceKositReporter.Destroy;
var
  I: Integer;
begin
  for I := 0 to FStylesheets.Count - 1 do
    FStylesheets.Objects[I].Free;
  FStylesheets.Free;
  FInputWriter.Free;
  inherited Destroy;
end;

function TLandrixEInvoiceKositReporter.GetEngineName: TLandrixEInvoiceString;
begin
  Result := TLandrixEInvoiceKositReportInputWriter(FInputWriter).EngineName;
end;

procedure TLandrixEInvoiceKositReporter.SetEngineName(const AValue: TLandrixEInvoiceString);
begin
  TLandrixEInvoiceKositReportInputWriter(FInputWriter).EngineName := AValue;
end;

function TLandrixEInvoiceKositReporter.StylesheetOf(const AFileName: string): TObject;
var
  I: Integer;
  Sheet: TLandrixXmlXsltStylesheet;
begin
  I := FStylesheets.IndexOf(AFileName);
  if I < 0 then
  begin
    Sheet := TLandrixXmlXsltStylesheet.Create;
    try
      if AFileName = ExtractHtmlKey then
        Sheet.LoadFromUtf8(ExtractHtml, '')
      else
        Sheet.LoadFromFile(AFileName);
    except
      on E: Exception do
      begin
        Sheet.Free;
        Fail('stylesheet ' + AFileName + ': ' + E.Message);
      end;
    end;
    I := FStylesheets.AddObject(AFileName, Sheet);
  end;
  Result := FStylesheets.Objects[I];
end;

{ The bytes from the stream's position to the end as a tree; nil when they
  are not well-formed (or there is no stream). }
function DocumentTree(ADocument: TStream): TLandrixXmlXPathTree;
var
  Data: TMemoryStream;
  Count: Int64;
  Reader: TLandrixXmlReader;
begin
  Result := nil;
  if ADocument = nil then
    Exit;
  Count := ADocument.Size - ADocument.Position;
  if (Count <= 0) or (Count > MaxInt) then
    Exit;
  Data := TMemoryStream.Create;
  try
    Data.CopyFrom(ADocument, Count);
    Result := TLandrixXmlXPathTree.Create;
    try
      Reader := TLandrixXmlReader.Create;
      try
        Reader.LoadFromBuffer(Data.Memory^, Integer(Data.Size));
        Result.LoadFromReader(Reader);
      finally
        Reader.Free;
      end;
    except
      on ELandrixXmlError do
      begin
        Result.Free;
        Result := nil;
      end;
      else
      begin
        Result.Free;
        raise;
      end;
    end;
  finally
    Data.Free;
  end;
end;

function TreeOfUtf8(const S: TLandrixXmlUtf8): TLandrixXmlXPathTree;
var
  Reader: TLandrixXmlReader;
begin
  Result := TLandrixXmlXPathTree.Create;
  try
    Reader := TLandrixXmlReader.Create;
    try
      Reader.LoadFromUtf8(S);
      Result.LoadFromReader(Reader);
    finally
      Reader.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

{ What the KoSIT validator passes as input-document for a document that is
  not well-formed: in:error-message with the error; nil without one. }
function ErrorMessageTree(AResult: TLandrixEInvoiceValidationResult): TLandrixXmlXPathTree;
var
  I: Integer;
  W: TLandrixXmlWriter;
  Xml: TLandrixXmlUtf8;
begin
  Result := nil;
  for I := 0 to AResult.MessageCount - 1 do
    if AResult.Messages[I].Step = evs_Wellformedness then
    begin
      W := TLandrixXmlWriter.Create;
      try
        W.ElementNsUtf8(InputNs, 'in', 'error-message', LandrixEInvoiceStringToUtf8(AResult.Messages[I].Text));
        W.EndDocument;
        Xml := W.AsUtf8;
      finally
        W.Free;
      end;
      Result := TreeOfUtf8(Xml);
      Exit;
    end;
end;

{ The boolean value of AExpression (prefixes rep and html) on the report. }
function ReportTest(AReport: TLandrixXmlXPathTree; const AExpression: TLandrixXmlUtf8): Boolean;
var
  Context: TLandrixXmlXPathStaticContext;
  Expression: TLandrixXmlXPathExpression;
  Evaluator: TLandrixXmlXPathEvaluator;
begin
  Context := TLandrixXmlXPathStaticContext.Create;
  try
    Context.Profile := xppSaxon;
    Context.AddNamespace('rep', RepNs);
    Context.AddNamespace('html', HtmlNs);
    Expression := TLandrixXmlXPathExpression.Create(AExpression, Context);
  finally
    Context.Free;
  end;
  try
    Evaluator := TLandrixXmlXPathEvaluator.Create(AReport);
    try
      Result := Evaluator.EvaluateBoolean(Expression, 0);
    finally
      Evaluator.Free;
    end;
  finally
    Expression.Free;
  end;
end;

function TLandrixEInvoiceKositReporter.DoCreateReport(AResult: TLandrixEInvoiceValidationResult;
  ADocument: TStream): TLandrixEInvoiceKositReport;
var
  Input: TMemoryStream;
  InputTree, DocTree, ReportTree: TLandrixXmlXPathTree;
  Transformer: TLandrixXmlXsltTransformer;
  Output: TMemoryStream;
  Xml: TLandrixXmlUtf8;
begin
  if AResult = nil then
    Fail('no result');
  if AResult.ReportFile = '' then
    Fail('the configuration names no report stylesheet');
  Result := TLandrixEInvoiceKositReport.Create;
  InputTree := nil;
  DocTree := nil;
  ReportTree := nil;
  Xml := '';
  Input := TMemoryStream.Create;
  Output := TMemoryStream.Create;
  try
    try
      TLandrixEInvoiceKositReportInputWriter(FInputWriter).WriteToStream(AResult, Input);
      SetLength(Xml, Integer(Input.Size));
      if Input.Size > 0 then
        Move(Input.Memory^, PAnsiChar(Xml)^, Integer(Input.Size));
      InputTree := TreeOfUtf8(Xml);
      DocTree := DocumentTree(ADocument);
      if DocTree = nil then
        DocTree := ErrorMessageTree(AResult);
      { the report }
      Transformer := TLandrixXmlXsltTransformer.Create(TLandrixXmlXsltStylesheet(StylesheetOf(AResult.ReportFile)));
      try
        if DocTree <> nil then
          Transformer.SetParameterTree('input-document', DocTree)
        else
          Transformer.SetParameterXPath('input-document', '()');
        { as the KoSIT validator serializes the report: not indented }
        Transformer.SetOutputProperty('indent', 'no');
        Transformer.Transform(InputTree, Output);
      finally
        Transformer.Free;
      end;
      SetLength(Xml, Integer(Output.Size));
      if Output.Size > 0 then
        Move(Output.Memory^, PAnsiChar(Xml)^, Integer(Output.Size));
      Result.FXml := Xml;
      ReportTree := TreeOfUtf8(Xml);
      Result.FAccepted := ReportTest(ReportTree, 'exists(/rep:report/rep:assessment[1]/rep:accept[1])');
      { the HTML page in it }
      if ReportTest(ReportTree, 'exists(//html:html)') then
      begin
        Transformer := TLandrixXmlXsltTransformer.Create(TLandrixXmlXsltStylesheet(StylesheetOf(ExtractHtmlKey)));
        try
          Result.FHtml := Transformer.TransformToUtf8(ReportTree);
        finally
          Transformer.Free;
        end;
      end;
    except
      on ELandrixEInvoiceError do
      begin
        Result.Free;
        raise;
      end;
      on E: Exception do
      begin
        Result.Free;
        Fail(E.Message);
      end;
    end;
  finally
    Output.Free;
    Input.Free;
    ReportTree.Free;
    DocTree.Free;
    InputTree.Free;
  end;
end;

function TLandrixEInvoiceKositReporter.CreateReport(AResult: TLandrixEInvoiceValidationResult;
  ADocument: TStream): TLandrixEInvoiceKositReport;
begin
  Result := DoCreateReport(AResult, ADocument);
end;

function TLandrixEInvoiceKositReporter.CreateReport(
  AValidation: TLandrixEInvoiceDocumentValidation): TLandrixEInvoiceKositReport;
var
  Xml: TMemoryStream;
begin
  if (AValidation = nil) or (AValidation.Kosit = nil) then
    Fail('the validation has no KoSIT run');
  Xml := AValidation.InvoiceXml;
  if Xml <> nil then
    Xml.Position := 0;
  Result := DoCreateReport(AValidation.Kosit, Xml);
end;

end.
