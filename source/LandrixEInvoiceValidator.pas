{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Validation of an XML invoice as the KoSIT validator does it with a
  validator configuration (scenarios.xml): the scenario whose match
  expression holds is chosen (none or several: no scenario, as KoSIT does;
  an expression that raises does not match), the document is checked against the
  scenario's XML schema and, if it is schema-valid, with its Schematron
  rule sets; the level of every message follows the configuration's
  report stylesheet (flag and role, then customLevel). With the acceptMatch
  of the XRechnung configuration the document is accepted unless there is
  no scenario, a fallback scenario, a processing error or a message whose
  level is error (the assessment of the report stylesheet); a scenario
  without acceptMatch (Peppol BIS) accepts, as KoSIT does then, only a
  schema-valid document without processing error and without any failed
  assert, whatever its level. The XML schema, XPath and
  Schematron engines are those of LandrixXML. The configuration ships the
  Schematron rule sets as XSLT, which LandrixXML does not run: every XSLT
  file name is mapped to a LandrixXML rule file (RuleFiles), compiled from
  the same Schematron source.
  Only what the KoSIT configurations use is supported; a configuration with
  another acceptMatch or without match expression is refused, not guessed.
  The result keeps what the KoSIT report input needs (time, document hash,
  the scenario and the resource of every step as written in the
  configuration, with KeepSvrl the SVRL of every Schematron step), so
  LandrixEInvoiceKositReportInput can write it without the configuration.
  DE: Pruefung einer XML-Rechnung, wie der KoSIT-Validator sie mit einer
  Validator-Konfiguration (scenarios.xml) ausfuehrt: das Szenario, dessen
  match-Ausdruck zutrifft, wird gewaehlt (keines oder mehrere: kein
  Szenario wie bei KoSIT; ein Ausdruck, der einen Fehler ausloest, passt
  nicht), das Dokument gegen dessen
  XML-Schema und, wenn es schemagueltig ist, mit dessen
  Schematron-Regelwerken geprueft; die Stufe jeder Meldung folgt dem
  Bericht-Stylesheet der Konfiguration (flag und role, dann customLevel).
  Mit dem acceptMatch der XRechnung-Konfiguration wird das Dokument
  angenommen, ausser es gibt kein Szenario, ein Fallback-Szenario, einen
  Verarbeitungsfehler oder eine Meldung der Stufe error (die Bewertung des
  Bericht-Stylesheets); ein Szenario ohne acceptMatch (Peppol BIS) nimmt,
  wie KoSIT dann, nur ein schemagueltiges Dokument ohne
  Verarbeitungsfehler und ohne jedes fehlgeschlagene assert an, gleich
  welcher Stufe. XML-Schema, XPath und Schematron kommen aus LandrixXML. Die
  Konfiguration liefert die Schematron-Regelwerke als XSLT, das LandrixXML
  nicht ausfuehrt: jeder XSLT-Dateiname wird auf eine Regeldatei von
  LandrixXML abgebildet (RuleFiles), aus derselben Schematron-Quelle
  uebersetzt. Unterstuetzt wird nur, was die KoSIT-Konfigurationen
  verwenden; eine Konfiguration mit anderem acceptMatch oder ohne
  match-Ausdruck wird abgewiesen, nicht geraten. Das Ergebnis behaelt, was
  der Eingang des KoSIT-Berichts braucht (Zeit, Hash des Dokuments, das
  Szenario und die Ressource jedes Schritts wie in der Konfiguration, mit
  KeepSvrl das SVRL jedes Schematron-Schritts), damit
  LandrixEInvoiceKositReportInput ihn ohne die Konfiguration schreiben
  kann. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceValidator;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  Contnrs,
  LandrixXmlBase,
  LandrixXmlWriter,
  LandrixXmlXPath,
  LandrixEInvoiceTypes;

type
  { The level of a message (rep:message/@level of the KoSIT report).
    DE: Die Stufe einer Meldung (rep:message/@level des KoSIT-Berichts). }
  TLandrixEInvoiceValidationLevel = (evl_Information, evl_Warning, evl_Error);

  { The validation step a message belongs to.
    DE: Der Pruefschritt, zu dem eine Meldung gehoert. }
  TLandrixEInvoiceValidationStep = (evs_Wellformedness, evs_XmlSchema, evs_Schematron);

  { One message: a well-formedness or XML schema error (code cvc-... as
    Xerces, otherwise generic-error) or a failed assert or successful report
    of a Schematron step (code = its id, UNSPECIFIC without id). A step
    that could not be completed has no messages; see ProcessingError.
    DE: Eine Meldung: ein Fehler der Wohlgeformtheit oder des XML-Schemas
    (Code cvc-... wie Xerces, sonst generic-error) oder ein fehlgeschlagenes
    assert bzw. erfolgreiches report eines Schematron-Schritts (Code = seine
    id, UNSPECIFIC ohne id). Ein Schritt, der nicht abgeschlossen werden
    konnte, hat keine Meldungen; siehe ProcessingError. }
  TLandrixEInvoiceValidationMessage = class(TObject)
  private
    FStep: TLandrixEInvoiceValidationStep;
    FStepIndex: Integer;
    FCode: TLandrixEInvoiceString;
    FFlag: TLandrixEInvoiceString;
    FRole: TLandrixEInvoiceString;
    FLevel: TLandrixEInvoiceValidationLevel;
    FEffectiveLevel: TLandrixEInvoiceValidationLevel;
    FLocation: TLandrixEInvoiceString;
    FLine: Integer;
    FColumn: Integer;
    FText: TLandrixEInvoiceString;
    FFailedAssert: Boolean;
  public
    property Step: TLandrixEInvoiceValidationStep read FStep;
    { 1-based number of the Schematron step, 0 for the other steps.
      DE: Nummer des Schematron-Schritts ab 1, 0 bei den anderen Schritten. }
    property StepIndex: Integer read FStepIndex;
    property Code: TLandrixEInvoiceString read FCode;
    { flag and role of the assert or report as written in the rule set.
      DE: flag und role des assert bzw. report, wie im Regelwerk. }
    property Flag: TLandrixEInvoiceString read FFlag;
    property Role: TLandrixEInvoiceString read FRole;
    { the level of the step and the level after customLevel.
      DE: die Stufe des Schritts und die Stufe nach customLevel. }
    property Level: TLandrixEInvoiceValidationLevel read FLevel;
    property EffectiveLevel: TLandrixEInvoiceValidationLevel read FEffectiveLevel;
    { the XPath location of a Schematron message (as SchXslt writes it).
      DE: der XPath-Ort einer Schematron-Meldung (wie SchXslt ihn schreibt). }
    property Location: TLandrixEInvoiceString read FLocation;
    { line and column of a well-formedness or schema error, 0 if unknown.
      DE: Zeile und Spalte eines Wohlgeformtheits- oder Schemafehlers, 0
      wenn unbekannt. }
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
    property Text: TLandrixEInvoiceString read FText;
  end;

  { One step of a run as the KoSIT report input lists it: well-formedness
    (always), the XML schema (with a scenario) and every Schematron step
    that ran (only on a schema-valid document). The messages of all steps
    are in the result's Messages.
    DE: Ein Schritt eines Laufs, wie der Eingang des KoSIT-Berichts ihn
    auffuehrt: Wohlgeformtheit (immer), XML-Schema (mit Szenario) und jeder
    Schematron-Schritt, der lief (nur bei einem schemagueltigen Dokument).
    Die Meldungen aller Schritte stehen in Messages des Ergebnisses. }
  TLandrixEInvoiceValidationStepResult = class(TObject)
  private
    FStep: TLandrixEInvoiceValidationStep;
    FResourceXml: TLandrixXmlUtf8;
    FSvrl: TLandrixXmlUtf8;
    FProcessingError: TLandrixEInvoiceString;
  public
    { the kind of the step.
      DE: die Art des Schritts. }
    property Step: TLandrixEInvoiceValidationStep read FStep;
    { the s:resource element of the step as the configuration writes it
      (name and location), UTF-8; '' for well-formedness.
      DE: das Element s:resource des Schritts, wie die Konfiguration es
      schreibt (Name und Ort), UTF-8; '' bei der Wohlgeformtheit. }
    property ResourceXml: TLandrixXmlUtf8 read FResourceXml;
    { the SVRL of a Schematron step (svrl:schematron-output, UTF-8, the
      message texts as written in the rule set); '' unless the validator's
      KeepSvrl is set, and '' for a step with a processing error.
      DE: das SVRL eines Schematron-Schritts (svrl:schematron-output,
      UTF-8, die Meldungstexte wie im Regelwerk); '', ausser KeepSvrl des
      Validators ist gesetzt, und '' bei einem Schritt mit
      Verarbeitungsfehler. }
    property Svrl: TLandrixXmlUtf8 read FSvrl;
    { '' or the reason the step could not be completed.
      DE: '' oder der Grund, warum der Schritt nicht abgeschlossen werden
      konnte. }
    property ProcessingError: TLandrixEInvoiceString read FProcessingError;
  end;

  { The result of one validation.
    DE: Das Ergebnis einer Pruefung. }
  TLandrixEInvoiceValidationResult = class(TObject)
  private
    FMessages: TObjectList;
    FScenarioName: TLandrixEInvoiceString;
    FMatchCount: Integer;
    FXmlSchemaValid: Boolean;
    FProcessingError: TLandrixEInvoiceString;
    FAccepted: Boolean;
    FSteps: TObjectList;
    FTimestamp: TLandrixEInvoiceString;
    FDocumentHash: TLandrixEInvoiceString;
    FDocumentReference: TLandrixEInvoiceString;
    FScenarioXml: TLandrixXmlUtf8;
    FReportFile: string;
    function GetMessageCount: Integer;
    function GetMessage(AIndex: Integer): TLandrixEInvoiceValidationMessage;
    function GetStepCount: Integer;
    function GetStep(AIndex: Integer): TLandrixEInvoiceValidationStepResult;
    function Add(AStep: TLandrixEInvoiceValidationStep; AStepIndex: Integer;
      const ACode: TLandrixEInvoiceString; ALevel: TLandrixEInvoiceValidationLevel): TLandrixEInvoiceValidationMessage;
    function AddStep(AStep: TLandrixEInvoiceValidationStep;
      const AResourceXml: TLandrixXmlUtf8): TLandrixEInvoiceValidationStepResult;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    { the name of the chosen scenario, '' if none or several matched.
      DE: der Name des gewaehlten Szenarios, '' wenn keines oder mehrere
      passten. }
    property ScenarioName: TLandrixEInvoiceString read FScenarioName;
    { the number of scenarios whose match expression holds; only with
      exactly one is a scenario chosen.
      DE: die Zahl der Szenarien, deren match-Ausdruck zutrifft; nur bei
      genau einem wird ein Szenario gewaehlt. }
    property MatchCount: Integer read FMatchCount;
    { True if the XML schema step ran without error or warning.
      DE: True, wenn der XML-Schema-Schritt ohne Fehler und Warnung lief. }
    property XmlSchemaValid: Boolean read FXmlSchemaValid;
    { '' or the reason a Schematron step could not be completed (a dynamic
      XPath error, which makes KoSIT's XSLT fail); the document is
      rejected.
      DE: '' oder der Grund, warum ein Schematron-Schritt nicht
      abgeschlossen werden konnte (ein dynamischer XPath-Fehler, an dem das
      XSLT von KoSIT scheitert); das Dokument wird abgewiesen. }
    property ProcessingError: TLandrixEInvoiceString read FProcessingError;
    { the assessment: accept (True) or reject (False).
      DE: die Bewertung: annehmen (True) oder abweisen (False). }
    property Accepted: Boolean read FAccepted;
    property MessageCount: Integer read GetMessageCount;
    property Messages[AIndex: Integer]: TLandrixEInvoiceValidationMessage read GetMessage; default;
    { the start of the run as xs:dateTime in local time, without time zone.
      DE: der Beginn des Laufs als xs:dateTime in Ortszeit, ohne Zeitzone. }
    property Timestamp: TLandrixEInvoiceString read FTimestamp;
    { the SHA-256 of the document bytes, Base64 (as KoSIT); '' if the file
      could not be read.
      DE: der SHA-256 der Dokumentbytes, Base64 (wie KoSIT); '', wenn die
      Datei nicht gelesen werden konnte. }
    property DocumentHash: TLandrixEInvoiceString read FDocumentHash;
    { the full path of the file passed to Validate; '' for ValidateStream.
      DE: der volle Pfad der an Validate uebergebenen Datei; '' bei
      ValidateStream. }
    property DocumentReference: TLandrixEInvoiceString read FDocumentReference;
    { the s:scenario element of the chosen scenario as the configuration
      writes it, UTF-8, as the KoSIT validator copies it (text that is only
      white space left out, line breaks and tabs as spaces); '' without a
      scenario.
      DE: das Element s:scenario des gewaehlten Szenarios, wie die
      Konfiguration es schreibt, UTF-8, so kopiert wie im KoSIT-Validator
      (Text nur aus Leerraum entfaellt, Zeilenumbrueche und Tabulatoren als
      Leerzeichen); '' ohne Szenario. }
    property ScenarioXml: TLandrixXmlUtf8 read FScenarioXml;
    { the report stylesheet KoSIT applies (full path): the createReport of
      the scenario, without a scenario the noScenarioReport of the
      configuration; '' if the configuration names none.
      DE: das Bericht-Stylesheet, das KoSIT anwendet (voller Pfad): das
      createReport des Szenarios, ohne Szenario das noScenarioReport der
      Konfiguration; '', wenn die Konfiguration keines nennt. }
    property ReportFile: string read FReportFile;
    { the steps of the run in their order (well-formedness, XML schema,
      Schematron), for the KoSIT report input.
      DE: die Schritte des Laufs in ihrer Reihenfolge (Wohlgeformtheit,
      XML-Schema, Schematron), fuer den Eingang des KoSIT-Berichts. }
    property StepCount: Integer read GetStepCount;
    property Steps[AIndex: Integer]: TLandrixEInvoiceValidationStepResult read GetStep;
  end;

  { A scenario of the configuration.
    DE: Ein Szenario der Konfiguration. }
  TLandrixEInvoiceValidationScenario = class(TObject)
  private
    FName: TLandrixEInvoiceString;
    FMatch: TLandrixXmlXPathExpression;
    FHasAcceptMatch: Boolean;
    FSchemaFile: string;
    FSchematronFiles: TStringList;
    FCustomCodes: TStringList;
    FCustomLevels: array of TLandrixEInvoiceValidationLevel;
    FScenarioXml: TLandrixXmlUtf8;
    FReportFile: string;
    FSchemaResourceXml: TLandrixXmlUtf8;
    FSchematronResourceXml: array of TLandrixXmlUtf8;
    function GetSchematronCount: Integer;
    function GetSchematronFile(AIndex: Integer): string;
  public
    constructor Create;
    destructor Destroy; override;
    { the level customLevel gives for ACode; False if it names none.
      DE: die Stufe, die customLevel fuer ACode festlegt; False, wenn
      keine. }
    function CustomLevel(const ACode: TLandrixEInvoiceString; out ALevel: TLandrixEInvoiceValidationLevel): Boolean;
    property Name: TLandrixEInvoiceString read FName;
    { the XML schema, the full path.
      DE: das XML-Schema, voller Pfad. }
    property SchemaFile: string read FSchemaFile;
    { the Schematron steps as the configuration names them (XSLT files,
      full path).
      DE: die Schematron-Schritte, wie die Konfiguration sie nennt
      (XSLT-Dateien, voller Pfad). }
    property SchematronCount: Integer read GetSchematronCount;
    property SchematronFiles[AIndex: Integer]: string read GetSchematronFile;
    { the s:scenario element as the configuration writes it, UTF-8.
      DE: das Element s:scenario, wie die Konfiguration es schreibt,
      UTF-8. }
    property ScenarioXml: TLandrixXmlUtf8 read FScenarioXml;
    { the report stylesheet of createReport, the full path; '' if none.
      DE: das Bericht-Stylesheet aus createReport, voller Pfad; '', wenn
      keines. }
    property ReportFile: string read FReportFile;
  end;

  { A KoSIT validator configuration and the engines to run it. Load the
    configuration, fill RuleFiles, then validate any number of documents;
    schemas and rule files are loaded once, at their first use.
    DE: Eine KoSIT-Validator-Konfiguration und die Maschinen, sie
    auszufuehren. Konfiguration laden, RuleFiles fuellen, dann beliebig
    viele Dokumente pruefen; Schemata und Regeldateien werden einmal
    geladen, beim ersten Gebrauch. }
  TLandrixEInvoiceValidator = class(TObject)
  private
    FName: TLandrixEInvoiceString;
    FScenarios: TObjectList;
    FRuleFiles: TStringList;
    FSchemas: TStringList;
    FRules: TStringList;
    FKeepSvrl: Boolean;
    FNoScenarioReportFile: string;
    procedure ReadScenarioXml(const AFileName: string);
    function GetScenarioCount: Integer;
    function GetScenario(AIndex: Integer): TLandrixEInvoiceValidationScenario;
    function SchemaOf(const AFileName: string): TObject;
    function RulesOf(const AXsltFile: string): TObject;
    procedure ClearCaches;
    function DoValidate(const AFileName: string; AData: TMemoryStream;
      AResult: TLandrixEInvoiceValidationResult): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    { Reads scenarios.xml; resources are resolved against its folder.
      Raises ELandrixEInvoiceError for a configuration this unit does not
      support.
      DE: Liest scenarios.xml; Ressourcen werden gegen dessen Ordner
      aufgeloest. Loest ELandrixEInvoiceError fuer eine Konfiguration aus,
      die diese Unit nicht unterstuetzt. }
    procedure LoadConfiguration(const AFileName: string);
    { Validates the file and fills AResult; returns AResult.Accepted. A
      missing rule file or an XML schema that does not load raises
      ELandrixEInvoiceError (a problem of the setup, not of the document).
      DE: Prueft die Datei und fuellt AResult; liefert AResult.Accepted.
      Eine fehlende Regeldatei oder ein XML-Schema, das nicht laedt, loest
      ELandrixEInvoiceError aus (ein Problem der Einrichtung, nicht des
      Dokuments). }
    function Validate(const AFileName: string; AResult: TLandrixEInvoiceValidationResult): Boolean;
    { The same for the document in AStream, read from its position to the
      end (e.g. an invoice extracted from a PDF); the data is read once
      into memory. The document has no URI (document-uri() and base-uri()
      are empty; the KoSIT configurations do not use them). Nothing left,
      no stream or more than 2 GB: a well-formedness error.
      DE: Dasselbe fuer das Dokument in AStream, gelesen ab seiner Position
      bis zum Ende (z. B. eine aus einem PDF gezogene Rechnung); die Daten
      werden einmal in den Speicher gelesen. Das Dokument hat keine URI
      (document-uri() und base-uri() sind leer; die KoSIT-Konfigurationen
      nutzen sie nicht). Nichts mehr da, kein Stream oder mehr als 2 GB:
      ein Wohlgeformtheitsfehler. }
    function ValidateStream(AStream: TStream; AResult: TLandrixEInvoiceValidationResult): Boolean;
    { The number of scenarios whose match expression holds for the document
      in AStream, read from its position to the end (an expression that
      raises does not match); -1 if the document is not well-formed (also
      no stream or more than 2 GB). Only the match expressions run, no XML
      schema and no Schematron: for choosing among several configurations.
      DE: Die Zahl der Szenarien, deren match-Ausdruck fuer das Dokument in
      AStream gilt, gelesen ab seiner Position bis zum Ende (ein Ausdruck,
      der eine Ausnahme ausloest, passt nicht); -1, wenn das Dokument nicht
      wohlgeformt ist (auch kein Stream oder mehr als 2 GB). Es laufen nur
      die match-Ausdruecke, kein XML-Schema und kein Schematron: fuer die
      Wahl unter mehreren Konfigurationen. }
    function CountMatches(AStream: TStream): Integer;
    { the name of the configuration (scenarios/name).
      DE: der Name der Konfiguration (scenarios/name). }
    property Name: TLandrixEInvoiceString read FName;
    property ScenarioCount: Integer read GetScenarioCount;
    property Scenarios[AIndex: Integer]: TLandrixEInvoiceValidationScenario read GetScenario;
    { XSLT file name of a Schematron step (without folder) = LandrixXML
      rule file, e.g. EN16931-UBL-validation.xsl=...\en16931-ubl.xml; a
      file ending in .sch is compiled from ISO Schematron when loaded.
      Fill it before the first Validate: a rule file is loaded once.
      DE: XSLT-Dateiname eines Schematron-Schritts (ohne Ordner) =
      Regeldatei von LandrixXML, z. B.
      EN16931-UBL-validation.xsl=...\en16931-ubl.xml; eine Datei mit
      Endung .sch wird beim Laden aus ISO-Schematron uebersetzt. Vor dem
      ersten Validate fuellen: eine Regeldatei wird einmal geladen. }
    property RuleFiles: TStringList read FRuleFiles;
    { True: every Schematron step keeps its SVRL in the result (Steps[].Svrl,
      the message texts as written, as SchXslt writes them), for the KoSIT
      report input; default False (the SVRL lists every fired rule and can
      be large).
      DE: True: jeder Schematron-Schritt behaelt sein SVRL im Ergebnis
      (Steps[].Svrl, die Meldungstexte wie geschrieben, wie SchXslt sie
      schreibt), fuer den Eingang des KoSIT-Berichts; Vorgabe False (das
      SVRL fuehrt jede gefeuerte Regel auf und kann gross werden). }
    property KeepSvrl: Boolean read FKeepSvrl write FKeepSvrl;
    { the report stylesheet of noScenarioReport (full path), which KoSIT
      applies when no scenario is chosen; '' if the configuration names
      none.
      DE: das Bericht-Stylesheet aus noScenarioReport (voller Pfad), das
      KoSIT anwendet, wenn kein Szenario gewaehlt ist; '', wenn die
      Konfiguration keines nennt. }
    property NoScenarioReportFile: string read FNoScenarioReportFile;
  end;

{ The level as the KoSIT report writes it (information, warning, error).
  DE: Die Stufe, wie der KoSIT-Bericht sie schreibt (information, warning,
  error). }
function LandrixEInvoiceValidationLevelText(ALevel: TLandrixEInvoiceValidationLevel): TLandrixEInvoiceString;

{ Writes the elements of AXml (UTF-8, as ScenarioXml, ResourceXml or Svrl
  hold them) into AWriter, at its current position; namespaces are
  declared where needed. Comments and processing instructions are left
  out. Raises ELandrixXmlError if AXml is not well-formed.
  DE: Schreibt die Elemente von AXml (UTF-8, wie ScenarioXml, ResourceXml
  oder Svrl sie halten) in AWriter, an seiner aktuellen Stelle; Namensraeume
  werden deklariert, wo noetig. Kommentare und Verarbeitungsanweisungen
  entfallen. Loest ELandrixXmlError aus, wenn AXml nicht wohlgeformt ist.
  ASkipSuppressedRules: svrl:suppressed-rule wird ausgelassen (der
  KoSIT-Berichtseingang erlaubt es nicht). }
procedure LandrixEInvoiceWriteXmlFragment(const AXml: TLandrixXmlUtf8; AWriter: TLandrixXmlWriter;
  ASkipSuppressedRules: Boolean = False);

implementation

uses
  SysUtils,
  LandrixXmlConvert,
  LandrixXmlSha256,
  LandrixXmlDom,
  LandrixXmlReader,
  LandrixXmlXPathTree,
  LandrixXmlXPathEval,
  LandrixXmlXsdSchema,
  LandrixXmlXsdSchemaLoader,
  LandrixXmlXsdValidator,
  LandrixXmlSchematron;

const
  ScenariosNs = 'http://www.xoev.de/de/validator/framework/1/scenarios';
  { the only acceptMatch the KoSIT configurations use }
  AcceptMatch = '/rep:report/rep:assessment[1]/rep:accept[1]';
  LevelTexts: array[TLandrixEInvoiceValidationLevel] of string = ('information', 'warning', 'error');

function LandrixEInvoiceValidationLevelText(ALevel: TLandrixEInvoiceValidationLevel): TLandrixEInvoiceString;
begin
  Result := TLandrixEInvoiceString(LevelTexts[ALevel]);
end;

function U(const S: TLandrixXmlUtf8): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceUtf8ToString(S);
end;

procedure ConfigError(const AMsg: string);
begin
  raise ELandrixEInvoiceError.Create('validator configuration: ' + AMsg);
end;

function TrimUtf8(const S: TLandrixXmlUtf8): TLandrixXmlUtf8;
var
  First, Last: Integer;
begin
  First := 1;
  Last := Length(S);
  while (First <= Last) and (S[First] <= ' ') do
    Inc(First);
  while (Last >= First) and (S[Last] <= ' ') do
    Dec(Last);
  Result := Copy(S, First, Last - First + 1);
end;

{ Copies the element at the reader's position (a start tag) with its
  subtree into AWriter; the reader stops on its end. ANormalize: text is
  normalized as the KoSIT validator copies the scenario (JAXB, by the
  types of its scenarios.xsd): text that is only white space is left out,
  in p and li (xs:normalizedString) tab, carriage return and line feed
  become spaces, in match and acceptMatch (xs:string) the text is trimmed,
  any other text (xs:token, xs:anyURI) is trimmed and its runs of white
  space become one space.
  DE: Kopiert das Element an der Position des Readers (ein Start-Tag) samt
  Unterbaum nach AWriter; der Reader steht danach auf dessen Ende.
  ANormalize: Text wird normalisiert, wie der KoSIT-Validator das Szenario
  kopiert (JAXB, nach den Typen seiner scenarios.xsd): Text nur aus
  Leerraum entfaellt, in p und li (xs:normalizedString) werden Tabulator,
  Wagenruecklauf und Zeilenvorschub zu Leerzeichen, in match und
  acceptMatch (xs:string) wird der Text getrimmt, jeder andere Text
  (xs:token, xs:anyURI) getrimmt und Folgen von Leerraum zu einem
  Leerzeichen. }
procedure CopyElement(AReader: TLandrixXmlReader; AWriter: TLandrixXmlWriter; ANormalize: Boolean = False;
  ASkipSuppressedRules: Boolean = False);
var
  Level, I, Colon: Integer;
  Name, Prefix, Pending, Current: TLandrixXmlUtf8;
  { the names of the open elements, for the text after a child }
  Names: array of TLandrixXmlUtf8;

  function PrefixOf(AIndex: Integer; out AColon: Integer): TLandrixXmlUtf8;
  var
    J: Integer;
  begin
    Name := AReader.AttributeNameUtf8(AIndex);
    AColon := 0;
    for J := 1 to Length(Name) do
      if (AColon = 0) and (Name[J] = ':') then
        AColon := J;
    if AColon > 0 then
      Result := Copy(Name, 1, AColon - 1)
    else
      Result := '';
  end;

  { writes the text gathered since the last tag (the reader may deliver a
    text in several parts) }
  procedure Flush;
  var
    J: Integer;
    Text: TLandrixXmlUtf8;
    Space: Boolean;
  begin
    if Pending = '' then
      Exit;
    if not ANormalize then
      AWriter.TextUtf8(Pending)
    else if TrimUtf8(Pending) <> '' then
    begin
      if (Current = 'p') or (Current = 'li') then
      begin
        Text := Pending;
        for J := 1 to Length(Text) do
          if Text[J] in [#9, #10, #13] then
            Text[J] := ' ';
      end
      else if (Current = 'match') or (Current = 'acceptMatch') then
        Text := TrimUtf8(Pending)
      else
      begin
        Text := '';
        Space := False;
        for J := 1 to Length(Pending) do
          if Pending[J] in [#9, #10, #13, ' '] then
            Space := Text <> ''
          else
          begin
            if Space then
              Text := Text + ' ';
            Space := False;
            Text := Text + Copy(Pending, J, 1);
          end;
      end;
      AWriter.TextUtf8(Text);
    end;
    Pending := '';
  end;

begin
  Current := '';
  Pending := '';
  Names := nil;
  Level := 0;
  repeat
    case AReader.TokenType of
      xttStartElement:
        if ASkipSuppressedRules and (Level > 0) and (AReader.LocalNameUtf8 = 'suppressed-rule') and
           (AReader.NamespaceUriUtf8 = 'http://purl.oclc.org/dsdl/svrl') then
        begin
          Flush;
          AReader.Skip;
        end
        else
        begin
          Flush;
          AWriter.StartElementNs(AReader.NamespaceUriUtf8, AReader.PrefixUtf8, AReader.LocalNameUtf8, True);
          Current := AReader.LocalNameUtf8;
          { the declarations first: an attribute with a prefix declares it
            itself unless it is declared; StartElementNs declares the
            element's own prefix }
          for I := 0 to AReader.AttributeCount - 1 do
            if AReader.IsNamespaceDeclaration(I) then
            begin
              Prefix := PrefixOf(I, Colon);
              if Colon > 0 then
                Prefix := AReader.AttributeLocalNameUtf8(I);
              if Prefix <> AReader.PrefixUtf8 then
                AWriter.DeclareNamespace(Prefix, AReader.AttributeValueUtf8(I));
            end;
          for I := 0 to AReader.AttributeCount - 1 do
            if not AReader.IsNamespaceDeclaration(I) then
            begin
              Prefix := PrefixOf(I, Colon);
              if Colon > 0 then
                AWriter.AttributeNsUtf8(AReader.AttributeNamespaceUriUtf8(I), Prefix,
                  AReader.AttributeLocalNameUtf8(I), AReader.AttributeValueUtf8(I))
              else
                AWriter.AttributeUtf8(Name, AReader.AttributeValueUtf8(I));
            end;
          { an empty element <x/> has an end token too }
          Inc(Level);
          SetLength(Names, Level);
          Names[Level - 1] := Current;
        end;
      xttEndElement:
        begin
          Flush;
          AWriter.EndElement;
          Dec(Level);
          if Level > 0 then
            Current := Names[Level - 1];
        end;
      xttText, xttCData:
        Pending := Pending + AReader.ValueUtf8;
    else
      { comments, processing instructions and the document type are left
        out (FPC 3.3.1 warns about a case without else) }
    end;
    if Level = 0 then
      Exit;
  until not AReader.Read;
end;

procedure LandrixEInvoiceWriteXmlFragment(const AXml: TLandrixXmlUtf8; AWriter: TLandrixXmlWriter;
  ASkipSuppressedRules: Boolean);
var
  Reader: TLandrixXmlReader;
begin
  Reader := TLandrixXmlReader.Create;
  try
    Reader.LoadFromUtf8(AXml);
    while Reader.Read do
      if Reader.TokenType = xttStartElement then
        CopyElement(Reader, AWriter, False, ASkipSuppressedRules);
  finally
    Reader.Free;
  end;
end;

{ The element at the reader's position as UTF-8 text without declaration,
  normalized as CopyElement does with ANormalize.
  DE: Das Element an der Position des Readers als UTF-8-Text ohne
  Deklaration, normalisiert wie CopyElement mit ANormalize. }
function ElementXml(AReader: TLandrixXmlReader): TLandrixXmlUtf8;
var
  Writer: TLandrixXmlWriter;
begin
  Writer := TLandrixXmlWriter.Create;
  try
    Writer.WriteDeclaration := False;
    Writer.Indent := False;
    CopyElement(AReader, Writer, True);
    Writer.EndDocument;
    Result := Writer.AsUtf8;
  finally
    Writer.Free;
  end;
end;

{ SHA-256 of the bytes, Base64 as the KoSIT report input writes it. }
function Sha256Base64(AData: Pointer; ASize: Integer): TLandrixEInvoiceString;
const
  Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  Hex: string;
  Bytes: array[0..31] of Byte;
  I, N: Integer;
  S: string;
begin
  Hex := LandrixXmlSha256Hex(AData^, ASize);
  for I := 0 to 31 do
    Bytes[I] := Byte(StrToInt('$' + Copy(Hex, I * 2 + 1, 2)));
  S := '';
  I := 0;
  while I < 32 do
  begin
    N := Bytes[I] shl 16;
    if I + 1 < 32 then
      N := N or (Bytes[I + 1] shl 8);
    if I + 2 < 32 then
      N := N or Bytes[I + 2];
    S := S + Alphabet[(N shr 18) and 63 + 1] + Alphabet[(N shr 12) and 63 + 1];
    if I + 1 < 32 then
      S := S + Alphabet[(N shr 6) and 63 + 1]
    else
      S := S + '=';
    if I + 2 < 32 then
      S := S + Alphabet[N and 63 + 1]
    else
      S := S + '=';
    Inc(I, 3);
  end;
  Result := TLandrixEInvoiceString(S);
end;

{ the child elements in the scenarios namespace with that local name }
function FirstChild(ANode: TLandrixXmlNode; const ALocalName: TLandrixXmlUtf8): TLandrixXmlNode;
begin
  Result := ANode.FirstChildElement;
  while (Result <> nil) and not ((Result.NamespaceUriUtf8 = ScenariosNs) and (Result.LocalNameUtf8 = ALocalName)) do
    Result := Result.NextSiblingElement;
end;

function NextSibling(ANode: TLandrixXmlNode; const ALocalName: TLandrixXmlUtf8): TLandrixXmlNode;
begin
  Result := ANode.NextSiblingElement;
  while (Result <> nil) and not ((Result.NamespaceUriUtf8 = ScenariosNs) and (Result.LocalNameUtf8 = ALocalName)) do
    Result := Result.NextSiblingElement;
end;

function ChildText(ANode: TLandrixXmlNode; const ALocalName: TLandrixXmlUtf8): TLandrixXmlUtf8;
var
  Child: TLandrixXmlNode;
begin
  Child := FirstChild(ANode, ALocalName);
  if Child = nil then
    Result := ''
  else
    Result := TrimUtf8(Child.TextUtf8);
end;

function ResourceLocation(ANode: TLandrixXmlNode; const ADir: string): string;
var
  Resource: TLandrixXmlNode;
  Location: TLandrixXmlUtf8;
begin
  Resource := FirstChild(ANode, 'resource');
  Location := '';
  if Resource <> nil then
    Location := ChildText(Resource, 'location');
  if Location = '' then
    ConfigError('resource without location');
  Result := ExpandFileName(ADir + StringReplace(LandrixXmlUtf8ToString(Location), '/', PathDelim, [rfReplaceAll]));
end;

function LevelByName(const AName: TLandrixXmlUtf8; out ALevel: TLandrixEInvoiceValidationLevel): Boolean;
var
  L: TLandrixEInvoiceValidationLevel;
begin
  Result := False;
  for L := Low(L) to High(L) do
    if AName = LandrixXmlStringToUtf8(LevelTexts[L]) then
    begin
      ALevel := L;
      Result := True;
      Exit;
    end;
end;

{ the level of a failed assert or successful report as default-report.xsl
  derives it: (flag, role) = (fatal, error) gives error, = (warning, warn)
  warning, = (information, info) information, otherwise error.
  DE: die Stufe eines fehlgeschlagenen assert bzw. erfolgreichen report
  wie in default-report.xsl: (flag, role) = (fatal, error) ergibt error,
  = (warning, warn) warning, = (information, info) information, sonst
  error. }
function SchematronLevel(const AFlag, ARole: TLandrixXmlUtf8): TLandrixEInvoiceValidationLevel;

  function Either(const A, B: TLandrixXmlUtf8): Boolean;
  begin
    Result := (AFlag = A) or (AFlag = B) or (ARole = A) or (ARole = B);
  end;

begin
  if Either('fatal', 'error') then
    Result := evl_Error
  else if Either('warning', 'warn') then
    Result := evl_Warning
  else if Either('information', 'info') then
    Result := evl_Information
  else
    Result := evl_Error;
end;

{ --- TLandrixEInvoiceValidationResult ------------------------------------ }

constructor TLandrixEInvoiceValidationResult.Create;
begin
  inherited Create;
  FMessages := TObjectList.Create(True);
  FSteps := TObjectList.Create(True);
end;

destructor TLandrixEInvoiceValidationResult.Destroy;
begin
  FSteps.Free;
  FMessages.Free;
  inherited Destroy;
end;

procedure TLandrixEInvoiceValidationResult.Clear;
begin
  FMessages.Clear;
  FScenarioName := '';
  FMatchCount := 0;
  FXmlSchemaValid := False;
  FProcessingError := '';
  FAccepted := False;
  FSteps.Clear;
  FTimestamp := '';
  FDocumentHash := '';
  FDocumentReference := '';
  FScenarioXml := '';
  FReportFile := '';
end;

function TLandrixEInvoiceValidationResult.GetStepCount: Integer;
begin
  Result := Integer(FSteps.Count);
end;

function TLandrixEInvoiceValidationResult.GetStep(AIndex: Integer): TLandrixEInvoiceValidationStepResult;
begin
  Result := TLandrixEInvoiceValidationStepResult(FSteps[AIndex]);
end;

function TLandrixEInvoiceValidationResult.AddStep(AStep: TLandrixEInvoiceValidationStep;
  const AResourceXml: TLandrixXmlUtf8): TLandrixEInvoiceValidationStepResult;
begin
  Result := TLandrixEInvoiceValidationStepResult.Create;
  FSteps.Add(Result);
  Result.FStep := AStep;
  Result.FResourceXml := AResourceXml;
end;

function TLandrixEInvoiceValidationResult.GetMessageCount: Integer;
begin
  Result := Integer(FMessages.Count);
end;

function TLandrixEInvoiceValidationResult.GetMessage(AIndex: Integer): TLandrixEInvoiceValidationMessage;
begin
  Result := TLandrixEInvoiceValidationMessage(FMessages[AIndex]);
end;

function TLandrixEInvoiceValidationResult.Add(AStep: TLandrixEInvoiceValidationStep; AStepIndex: Integer;
  const ACode: TLandrixEInvoiceString; ALevel: TLandrixEInvoiceValidationLevel): TLandrixEInvoiceValidationMessage;
begin
  Result := TLandrixEInvoiceValidationMessage.Create;
  FMessages.Add(Result);
  Result.FStep := AStep;
  Result.FStepIndex := AStepIndex;
  Result.FCode := ACode;
  Result.FLevel := ALevel;
  Result.FEffectiveLevel := ALevel;
end;

{ --- TLandrixEInvoiceValidationScenario ---------------------------------- }

constructor TLandrixEInvoiceValidationScenario.Create;
begin
  inherited Create;
  FSchematronFiles := TStringList.Create;
  FCustomCodes := TStringList.Create;
end;

destructor TLandrixEInvoiceValidationScenario.Destroy;
begin
  FMatch.Free;
  FSchematronFiles.Free;
  FCustomCodes.Free;
  inherited Destroy;
end;

function TLandrixEInvoiceValidationScenario.GetSchematronCount: Integer;
begin
  Result := FSchematronFiles.Count;
end;

function TLandrixEInvoiceValidationScenario.GetSchematronFile(AIndex: Integer): string;
begin
  Result := FSchematronFiles[AIndex];
end;

{ customLevel lists codes separated by white space (tokenize(., '\s+') in
  default-report.xsl); the first customLevel naming the code wins.
  DE: customLevel nennt Codes durch Leerraum getrennt; das erste
  customLevel mit dem Code gilt. }
function TLandrixEInvoiceValidationScenario.CustomLevel(const ACode: TLandrixEInvoiceString;
  out ALevel: TLandrixEInvoiceValidationLevel): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FCustomCodes.Count - 1 do
    if LandrixXmlStringToUtf8(FCustomCodes[I]) = LandrixEInvoiceStringToUtf8(ACode) then
    begin
      ALevel := FCustomLevels[I];
      Result := True;
      Exit;
    end;
end;

{ --- TLandrixEInvoiceValidator ------------------------------------------- }

constructor TLandrixEInvoiceValidator.Create;
begin
  inherited Create;
  FScenarios := TObjectList.Create(True);
  FRuleFiles := TStringList.Create;
  FSchemas := TStringList.Create;
  FRules := TStringList.Create;
  { file names may differ only in case (Linux, macOS with a case-sensitive
    volume); on Windows another spelling only loads twice
    DE: Dateinamen koennen sich nur in der Schreibweise unterscheiden
    (Linux, macOS mit Gross-/Kleinschreibung); unter Windows laedt eine
    andere Schreibweise nur doppelt }
  FRuleFiles.CaseSensitive := True;
  FSchemas.CaseSensitive := True;
  FRules.CaseSensitive := True;
end;

destructor TLandrixEInvoiceValidator.Destroy;
begin
  ClearCaches;
  FSchemas.Free;
  FRules.Free;
  FRuleFiles.Free;
  FScenarios.Free;
  inherited Destroy;
end;

procedure TLandrixEInvoiceValidator.ClearCaches;
var
  I: Integer;
begin
  for I := 0 to FSchemas.Count - 1 do
    FSchemas.Objects[I].Free;
  FSchemas.Clear;
  for I := 0 to FRules.Count - 1 do
    FRules.Objects[I].Free;
  FRules.Clear;
end;

function TLandrixEInvoiceValidator.GetScenarioCount: Integer;
begin
  Result := Integer(FScenarios.Count);
end;

function TLandrixEInvoiceValidator.GetScenario(AIndex: Integer): TLandrixEInvoiceValidationScenario;
begin
  Result := TLandrixEInvoiceValidationScenario(FScenarios[AIndex]);
end;

procedure TLandrixEInvoiceValidator.LoadConfiguration(const AFileName: string);
var
  Doc: TLandrixXmlDocument;
  Node, Child: TLandrixXmlNode;
  Scenario: TLandrixEInvoiceValidationScenario;
  Context: TLandrixXmlXPathStaticContext;
  Dir: string;
  Codes, Code: TLandrixXmlUtf8;
  Level: TLandrixEInvoiceValidationLevel;
  I, Start: Integer;
begin
  FScenarios.Clear;
  ClearCaches;
  FName := '';
  FNoScenarioReportFile := '';
  Dir := IncludeTrailingPathDelimiter(ExtractFilePath(ExpandFileName(AFileName)));
  Doc := TLandrixXmlDocument.Create;
  try
  try
    Doc.LoadFromFile(AFileName);
    if (Doc.Root = nil) or (Doc.Root.NamespaceUriUtf8 <> ScenariosNs) or (Doc.Root.LocalNameUtf8 <> 'scenarios') then
      ConfigError('no scenarios element in ' + AFileName);
    FName := U(ChildText(Doc.Root, 'name'));
    Node := FirstChild(Doc.Root, 'scenario');
    while Node <> nil do
    begin
      Scenario := TLandrixEInvoiceValidationScenario.Create;
      FScenarios.Add(Scenario);
      Scenario.FName := U(ChildText(Node, 'name'));
      Scenario.FHasAcceptMatch := FirstChild(Node, 'acceptMatch') <> nil;
      if Scenario.FHasAcceptMatch and (ChildText(Node, 'acceptMatch') <> TLandrixXmlUtf8(AcceptMatch)) then
        ConfigError('scenario ' + string(Scenario.FName) + ': acceptMatch other than ' + AcceptMatch);
      if ChildText(Node, 'match') = '' then
        ConfigError('scenario ' + string(Scenario.FName) + ' without match');
      Context := TLandrixXmlXPathStaticContext.Create;
      try
        Context.Profile := xppSaxon;
        Child := FirstChild(Node, 'namespace');
        while Child <> nil do
        begin
          Context.AddNamespace(Child.AttributeValueUtf8('', 'prefix'), TrimUtf8(Child.TextUtf8));
          Child := NextSibling(Child, 'namespace');
        end;
        Scenario.FMatch := TLandrixXmlXPathExpression.Create(ChildText(Node, 'match'), Context);
      finally
        Context.Free;
      end;
      Child := FirstChild(Node, 'validateWithXmlSchema');
      if Child = nil then
        ConfigError('scenario ' + string(Scenario.FName) + ' without XML schema');
      { the validator loads one schema per scenario
        DE: der Validator laedt ein Schema je Szenario }
      if (FirstChild(Child, 'resource') <> nil) and (NextSibling(FirstChild(Child, 'resource'), 'resource') <> nil) then
        ConfigError('scenario ' + string(Scenario.FName) + ' with several XML schema resources');
      Scenario.FSchemaFile := ResourceLocation(Child, Dir);
      Child := FirstChild(Node, 'validateWithSchematron');
      while Child <> nil do
      begin
        Scenario.FSchematronFiles.Add(ResourceLocation(Child, Dir));
        Child := NextSibling(Child, 'validateWithSchematron');
      end;
      Child := FirstChild(Node, 'createReport');
      if Child <> nil then
      begin
        Scenario.FReportFile := ResourceLocation(Child, Dir);
        Child := FirstChild(Child, 'customLevel');
      end;
      while Child <> nil do
      begin
        if not LevelByName(Child.AttributeValueUtf8('', 'level'), Level) then
          ConfigError('scenario ' + string(Scenario.FName) + ': unknown customLevel ' +
            LandrixXmlUtf8ToString(Child.AttributeValueUtf8('', 'level')));
        Codes := Child.TextUtf8;
        Start := 1;
        for I := 1 to Length(Codes) + 1 do
          if (I > Length(Codes)) or (Codes[I] <= ' ') then
          begin
            Code := Copy(Codes, Start, I - Start);
            if Code <> '' then
            begin
              Scenario.FCustomCodes.Add(LandrixXmlUtf8ToString(Code));
              SetLength(Scenario.FCustomLevels, Scenario.FCustomCodes.Count);
              Scenario.FCustomLevels[Scenario.FCustomCodes.Count - 1] := Level;
            end;
            Start := I + 1;
          end;
        Child := NextSibling(Child, 'customLevel');
      end;
      Node := NextSibling(Node, 'scenario');
    end;
    if FScenarios.Count = 0 then
      ConfigError('no scenario in ' + AFileName);
    Child := FirstChild(Doc.Root, 'noScenarioReport');
    if Child <> nil then
      FNoScenarioReportFile := ResourceLocation(Child, Dir);
    ReadScenarioXml(AFileName);
  except
    { a configuration that does not load leaves no scenario behind }
    FScenarios.Clear;
    FName := '';
    FNoScenarioReportFile := '';
    raise;
  end;
  finally
    Doc.Free;
  end;
end;

{ The s:scenario elements as written (for the KoSIT report input), and
  the s:resource of the XML schema and of each Schematron step. }
procedure TLandrixEInvoiceValidator.ReadScenarioXml(const AFileName: string);
var
  Reader, Inner: TLandrixXmlReader;
  Scenario: TLandrixEInvoiceValidationScenario;
  Index, Count: Integer;
  Container: TLandrixXmlUtf8;
begin
  Index := 0;
  Reader := TLandrixXmlReader.Create;
  try
    Reader.LoadFromFile(AFileName);
    while Reader.Read do
      if (Reader.TokenType = xttStartElement) and (Reader.Depth = 1) and
        (Reader.NamespaceUriUtf8 = ScenariosNs) and (Reader.LocalNameUtf8 = 'scenario') then
      begin
        if Index >= ScenarioCount then
          ConfigError('scenarios not read again from ' + AFileName);
        Scenario := Scenarios[Index];
        Inc(Index);
        Scenario.FScenarioXml := ElementXml(Reader);
        Count := 0;
        Container := '';
        Inner := TLandrixXmlReader.Create;
        try
          Inner.LoadFromUtf8(Scenario.FScenarioXml);
          while Inner.Read do
            if (Inner.TokenType = xttStartElement) and (Inner.NamespaceUriUtf8 = ScenariosNs) then
              if Inner.Depth = 1 then
                Container := Inner.LocalNameUtf8
              else if (Inner.Depth = 2) and (Inner.LocalNameUtf8 = 'resource') then
                if Container = 'validateWithXmlSchema' then
                  Scenario.FSchemaResourceXml := ElementXml(Inner)
                else if Container = 'validateWithSchematron' then
                begin
                  SetLength(Scenario.FSchematronResourceXml, Count + 1);
                  Scenario.FSchematronResourceXml[Count] := ElementXml(Inner);
                  Inc(Count);
                end;
        finally
          Inner.Free;
        end;
        if Count <> Scenario.SchematronCount then
          ConfigError('scenario ' + string(Scenario.FName) + ': Schematron resources not read');
      end;
  finally
    Reader.Free;
  end;
  if Index <> ScenarioCount then
    ConfigError('scenarios not read again from ' + AFileName);
end;

function TLandrixEInvoiceValidator.SchemaOf(const AFileName: string): TObject;
var
  I: Integer;
begin
  I := FSchemas.IndexOf(AFileName);
  if I < 0 then
  begin
    try
      I := FSchemas.AddObject(AFileName, LandrixXmlXsdLoadSchema(AFileName));
    except
      on E: ELandrixXmlError do
        ConfigError('XML schema ' + AFileName + ': ' + E.Message);
    end;
  end;
  Result := FSchemas.Objects[I];
end;

function TLandrixEInvoiceValidator.RulesOf(const AXsltFile: string): TObject;
var
  I: Integer;
  RuleFile: string;
  Rules: TLandrixXmlSchematronRules;
begin
  I := FRules.IndexOf(AXsltFile);
  if I < 0 then
  begin
    RuleFile := FRuleFiles.Values[ExtractFileName(AXsltFile)];
    if RuleFile = '' then
      ConfigError('no rule file for ' + ExtractFileName(AXsltFile));
    Rules := TLandrixXmlSchematronRules.Create;
    try
      if SameText(ExtractFileExt(RuleFile), '.sch') then
        Rules.LoadFromSchematronFile(RuleFile)
      else
        Rules.LoadFromFile(RuleFile);
    except
      on E: Exception do
      begin
        Rules.Free;
        ConfigError('rule file ' + RuleFile + ': ' + E.Message);
      end;
    end;
    I := FRules.AddObject(AXsltFile, Rules);
  end;
  Result := FRules.Objects[I];
end;

function TLandrixEInvoiceValidator.Validate(const AFileName: string;
  AResult: TLandrixEInvoiceValidationResult): Boolean;
var
  F: TFileStream;
  Data: TMemoryStream;
begin
  { the file is read once, so hash, scenario, schema and Schematron judge
    the same bytes even if the file is replaced meanwhile; a file that
    cannot be opened or is larger than 2 GB takes the path by name, whose
    well-formedness step reports it }
  Data := nil;
  try
    try
      F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
      try
        if F.Size <= MaxInt then
        begin
          Data := TMemoryStream.Create;
          if F.Size > 0 then
            Data.CopyFrom(F, F.Size);
          Data.Position := 0;
        end;
      finally
        F.Free;
      end;
    except
      on EStreamError do
        FreeAndNil(Data);
      on EInOutError do
        FreeAndNil(Data);
    end;
    Result := DoValidate(AFileName, Data, AResult);
  finally
    Data.Free;
  end;
end;

function TLandrixEInvoiceValidator.ValidateStream(AStream: TStream;
  AResult: TLandrixEInvoiceValidationResult): Boolean;
var
  Data: TMemoryStream;
  Count: Int64;
  Msg: TLandrixEInvoiceValidationMessage;
begin
  Count := 0;
  if AStream <> nil then
    Count := AStream.Size - AStream.Position;
  if Count > MaxInt then
  begin
    { a run without document: time, the well-formedness step and the
      report without scenario, as for a document that does not load }
    AResult.Clear;
    AResult.FTimestamp := U(LandrixXmlFormatDateTime(Now));
    AResult.FReportFile := FNoScenarioReportFile;
    AResult.AddStep(evs_Wellformedness, '');
    Msg := AResult.Add(evs_Wellformedness, 0, 'generic-error', evl_Error);
    Msg.FText := 'The document is larger than 2 GB';
    Result := False;
    Exit;
  end;
  Data := TMemoryStream.Create;
  try
    { CopyFrom with 0 copies the whole stream: only when bytes are left }
    if Count > 0 then
      Data.CopyFrom(AStream, Count);
    Result := DoValidate('', Data, AResult);
  finally
    Data.Free;
  end;
end;

{ The scenarios of AValidator whose match holds on ATree, as KoSIT
  evaluates them (an expression that raises does not match); AScenario is
  the last of them.
  DE: Die Szenarien von AValidator, deren match auf ATree gilt, wie KoSIT
  sie auswertet (ein Ausdruck, der eine Ausnahme ausloest, passt nicht);
  AScenario ist das letzte davon. }
function MatchScenarios(AValidator: TLandrixEInvoiceValidator; ATree: TLandrixXmlXPathTree;
  out AScenario: TLandrixEInvoiceValidationScenario): Integer;
var
  Evaluator: TLandrixXmlXPathEvaluator;
  Candidate: TLandrixEInvoiceValidationScenario;
  I: Integer;
begin
  Result := 0;
  AScenario := nil;
  Evaluator := TLandrixXmlXPathEvaluator.Create(ATree);
  try
    for I := 0 to AValidator.ScenarioCount - 1 do
    begin
      Candidate := AValidator.Scenarios[I];
      try
        if Evaluator.EvaluateBoolean(Candidate.FMatch, 0) then
        begin
          Inc(Result);
          AScenario := Candidate;
        end;
      except
        { as KoSIT: an expression that raises does not match }
        on ELandrixXmlError do ;
      end;
    end;
  finally
    Evaluator.Free;
  end;
end;

function TLandrixEInvoiceValidator.CountMatches(AStream: TStream): Integer;
var
  Data: TMemoryStream;
  Count: Int64;
  Reader: TLandrixXmlReader;
  Tree: TLandrixXmlXPathTree;
  Scenario: TLandrixEInvoiceValidationScenario;
begin
  Result := -1;
  if AStream = nil then
    Exit;
  Count := AStream.Size - AStream.Position;
  if Count > MaxInt then
    Exit;
  Data := TMemoryStream.Create;
  Tree := TLandrixXmlXPathTree.Create;
  try
    { CopyFrom with 0 copies the whole stream: only when bytes are left }
    if Count > 0 then
      Data.CopyFrom(AStream, Count);
    try
      Reader := TLandrixXmlReader.Create;
      try
        Reader.LoadFromBuffer(Data.Memory^, Integer(Data.Size));
        Tree.LoadFromReader(Reader);
      finally
        Reader.Free;
      end;
    except
      on ELandrixXmlError do
        Exit;
    end;
    Result := MatchScenarios(Self, Tree, Scenario);
  finally
    Tree.Free;
    Data.Free;
  end;
end;

{ The run on the file AFileName, or on AData when it is not nil (both
  passes, scenario and Schematron on the tree and the XML schema, read the
  same bytes). }
function TLandrixEInvoiceValidator.DoValidate(const AFileName: string; AData: TMemoryStream;
  AResult: TLandrixEInvoiceValidationResult): Boolean;
var
  Reader: TLandrixXmlReader;
  Tree: TLandrixXmlXPathTree;
  Scenario: TLandrixEInvoiceValidationScenario;
  XsdValidator: TLandrixXmlXsdValidator;
  XsdError: TLandrixXmlXsdValidationError;
  SchValidator: TLandrixXmlSchematronValidator;
  SchResult: TLandrixXmlSchematronResult;
  Msg: TLandrixEInvoiceValidationMessage;
  Level: TLandrixEInvoiceValidationLevel;
  Code: TLandrixEInvoiceString;
  I, K: Integer;
  HasDynamicError: Boolean;
  ErrorText: TLandrixEInvoiceString;
  Step: TLandrixEInvoiceValidationStepResult;
  FileData: TMemoryStream;
  SvrlWriter: TLandrixXmlWriter;
  TruncMsg: TLandrixEInvoiceValidationMessage;
begin
  AResult.Clear;
  Result := False;
  TruncMsg := nil;
  Scenario := nil;
  AResult.FTimestamp := U(LandrixXmlFormatDateTime(Now));
  if AFileName <> '' then
    AResult.FDocumentReference := TLandrixEInvoiceString(ExpandFileName(AFileName));
  AResult.FReportFile := FNoScenarioReportFile;
  if AData <> nil then
    AResult.FDocumentHash := Sha256Base64(AData.Memory, Integer(AData.Size))
  else
  begin
    FileData := TMemoryStream.Create;
    try
      try
        FileData.LoadFromFile(AFileName);
        if FileData.Size <= MaxInt then
          AResult.FDocumentHash := Sha256Base64(FileData.Memory, Integer(FileData.Size));
      except
        { the well-formedness step reports a file that cannot be read }
        on EStreamError do ;
        on EInOutError do ;
      end;
    finally
      FileData.Free;
    end;
  end;
  AResult.AddStep(evs_Wellformedness, '');
  { an exception (a setup error) leaves no acceptance behind: the verdict
    of the finally block below is taken back }
  try
    Tree := TLandrixXmlXPathTree.Create;
    try
      { well-formedness: a document that does not load matches no scenario }
      try
        if AData = nil then
          Tree.LoadFromFile(AFileName)
        else
        begin
          Reader := TLandrixXmlReader.Create;
          try
            Reader.LoadFromBuffer(AData.Memory^, Integer(AData.Size));
            Tree.LoadFromReader(Reader);
          finally
            Reader.Free;
          end;
          { the bytes of a file read once keep its URI (document-uri()) }
          if AFileName <> '' then
            Tree.BaseUri := LandrixXmlFileUri(AFileName);
        end;
      except
        on E: ELandrixXmlError do
        begin
          Msg := AResult.Add(evs_Wellformedness, 0, 'generic-error', evl_Error);
          Msg.FLine := E.Line;
          Msg.FColumn := E.Column;
          Msg.FText := TLandrixEInvoiceString(E.Message);
          Exit;
        end;
        { a file that cannot be opened or read }
        on E: EStreamError do
        begin
          Msg := AResult.Add(evs_Wellformedness, 0, 'generic-error', evl_Error);
          Msg.FText := TLandrixEInvoiceString(E.Message);
          Exit;
        end;
        on E: EInOutError do
        begin
          Msg := AResult.Add(evs_Wellformedness, 0, 'generic-error', evl_Error);
          Msg.FText := TLandrixEInvoiceString(E.Message);
          Exit;
        end;
      end;
      AResult.FMatchCount := MatchScenarios(Self, Tree, Scenario);
      { as KoSIT: none or several matching scenarios mean no scenario }
      if AResult.FMatchCount <> 1 then
        Scenario := nil;
      if Scenario = nil then
        Exit;
      AResult.FScenarioName := Scenario.FName;
      AResult.FScenarioXml := Scenario.FScenarioXml;
      AResult.FReportFile := Scenario.FReportFile;
      AResult.AddStep(evs_XmlSchema, Scenario.FSchemaResourceXml);

      XsdValidator := TLandrixXmlXsdValidator.Create(TLandrixXmlXsdSchemaSet(SchemaOf(Scenario.FSchemaFile)));
      try
        { a crafted document can produce an error per element: keep at most
          10000 and say that the list was cut }
        XsdValidator.MaxErrors := 10000;
        if AData = nil then
          XsdValidator.ValidateFile(AFileName)
        else
        begin
          Reader := TLandrixXmlReader.Create;
          try
            Reader.LoadFromBuffer(AData.Memory^, Integer(AData.Size));
            XsdValidator.ValidateReader(Reader);
          finally
            Reader.Free;
          end;
        end;
        for I := 0 to XsdValidator.ErrorCount - 1 do
        begin
          XsdError := XsdValidator.Errors[I];
          if Copy(XsdError.Code, 1, 4) = 'cvc-' then
            Code := TLandrixEInvoiceString(XsdError.Code)
          else
            Code := 'generic-error';
          Msg := AResult.Add(evs_XmlSchema, 0, Code, evl_Error);
          Msg.FLine := XsdError.Line;
          Msg.FColumn := XsdError.Column;
          Msg.FText := TLandrixEInvoiceString(XsdError.Message);
        end;
        if XsdValidator.Truncated then
        begin
          Msg := AResult.Add(evs_XmlSchema, 0, 'generic-error', evl_Error);
          TruncMsg := Msg;
          Msg.FText := 'more than ' + TLandrixEInvoiceString(IntToStr(XsdValidator.MaxErrors)) +
            ' schema errors; the rest is not listed';
        end;
        AResult.FXmlSchemaValid := XsdValidator.ErrorCount = 0;
      finally
        XsdValidator.Free;
      end;

      { the Schematron steps run only on a schema-valid document }
      if AResult.FXmlSchemaValid then
        for I := 0 to Scenario.SchematronCount - 1 do
        begin
          SchValidator := TLandrixXmlSchematronValidator.Create(TLandrixXmlSchematronRules(
            RulesOf(Scenario.SchematronFiles[I])));
          Step := AResult.AddStep(evs_Schematron, Scenario.FSchematronResourceXml[I]);
          try
            SchValidator.AbortOnDynamicError := True;
            SchValidator.ValidateTree(Tree);
            HasDynamicError := SchValidator.Incomplete;
            ErrorText := '';
            for K := 0 to SchValidator.ResultCount - 1 do
              if SchValidator.Results[K].Kind = xsrDynamicError then
              begin
                HasDynamicError := True;
                if ErrorText = '' then
                  ErrorText := U(SchValidator.Results[K].Message);
              end;
            if HasDynamicError then
            begin
              { as KoSIT: the step's XSLT fails, a processing error without
                messages of the step }
              Step.FProcessingError := TLandrixEInvoiceString(ExtractFileName(Scenario.SchematronFiles[I])) + ': ' +
                ErrorText;
              if AResult.FProcessingError = '' then
                AResult.FProcessingError := Step.FProcessingError;
            end
            else
            begin
              if FKeepSvrl then
              begin
                SchValidator.SvrlPreserveWhitespace := True;
                if AFileName <> '' then
                  SchValidator.DocumentUri := LandrixXmlFileUri(AFileName);
                SvrlWriter := TLandrixXmlWriter.Create;
                try
                  SvrlWriter.WriteDeclaration := False;
                  SchValidator.SaveSvrlToWriter(SvrlWriter);
                  SvrlWriter.EndDocument;
                  Step.FSvrl := SvrlWriter.AsUtf8;
                finally
                  SvrlWriter.Free;
                end;
              end;
              for K := 0 to SchValidator.ResultCount - 1 do
              begin
                SchResult := SchValidator.Results[K];
                if SchResult.Id = '' then
                  Code := 'UNSPECIFIC'
                else
                  Code := U(SchResult.Id);
                Msg := AResult.Add(evs_Schematron, I + 1, Code, SchematronLevel(SchResult.Flag, SchResult.Role));
                Msg.FFlag := U(SchResult.Flag);
                Msg.FRole := U(SchResult.Role);
                Msg.FLocation := U(SchResult.Location);
                Msg.FText := U(SchResult.Message);
                Msg.FFailedAssert := SchResult.Kind = xsrFailedAssert;
              end;
            end;
          finally
            SchValidator.Free;
          end;
        end;
    finally
      Tree.Free;
      { customLevel, then the assessment of default-report.xsl }
      if Scenario <> nil then
        for I := 0 to AResult.MessageCount - 1 do
        begin
          Msg := AResult.Messages[I];
          if Scenario.CustomLevel(Msg.FCode, Level) then
            Msg.FEffectiveLevel := Level;
        end;
      { errors beyond the cut were not seen: a customLevel must not turn the
        cut list into an acceptance }
      if TruncMsg <> nil then
        TruncMsg.FEffectiveLevel := evl_Error;
      AResult.FAccepted := (Scenario <> nil) and (AResult.FProcessingError = '');
      if AResult.FAccepted and Scenario.FHasAcceptMatch then
      begin
        if Pos('fallback', LowerCase(string(Scenario.FName))) > 0 then
          AResult.FAccepted := False;
        for I := 0 to AResult.MessageCount - 1 do
          if AResult.Messages[I].FEffectiveLevel = evl_Error then
            AResult.FAccepted := False;
      end
      else if AResult.FAccepted then
      begin
        { as KoSIT without acceptMatch: schema-valid and no failed assert.
          DE: wie KoSIT ohne acceptMatch: schemagueltig und kein
          fehlgeschlagenes assert. }
        if not AResult.FXmlSchemaValid then
          AResult.FAccepted := False;
        for I := 0 to AResult.MessageCount - 1 do
          if AResult.Messages[I].FFailedAssert then
            AResult.FAccepted := False;
      end;
    end;
  except
    AResult.FAccepted := False;
    raise;
  end;
  Result := AResult.FAccepted;
end;

end.
