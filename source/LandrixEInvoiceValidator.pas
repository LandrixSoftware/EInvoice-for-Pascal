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
  This is the first building block of the validator of plan phase 6.
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
  match-Ausdruck wird abgewiesen, nicht geraten. Erster Baustein des
  Validators aus Phase 6 des Fahrplans. }

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
    function GetMessageCount: Integer;
    function GetMessage(AIndex: Integer): TLandrixEInvoiceValidationMessage;
    function Add(AStep: TLandrixEInvoiceValidationStep; AStepIndex: Integer;
      const ACode: TLandrixEInvoiceString; ALevel: TLandrixEInvoiceValidationLevel): TLandrixEInvoiceValidationMessage;
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
    function GetScenarioCount: Integer;
    function GetScenario(AIndex: Integer): TLandrixEInvoiceValidationScenario;
    function SchemaOf(const AFileName: string): TObject;
    function RulesOf(const AXsltFile: string): TObject;
    procedure ClearCaches;
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
  end;

{ The level as the KoSIT report writes it (information, warning, error).
  DE: Die Stufe, wie der KoSIT-Bericht sie schreibt (information, warning,
  error). }
function LandrixEInvoiceValidationLevelText(ALevel: TLandrixEInvoiceValidationLevel): TLandrixEInvoiceString;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixXmlDom,
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
end;

destructor TLandrixEInvoiceValidationResult.Destroy;
begin
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
      Scenario.FSchemaFile := ResourceLocation(Child, Dir);
      Child := FirstChild(Node, 'validateWithSchematron');
      while Child <> nil do
      begin
        Scenario.FSchematronFiles.Add(ResourceLocation(Child, Dir));
        Child := NextSibling(Child, 'validateWithSchematron');
      end;
      Child := FirstChild(Node, 'createReport');
      if Child <> nil then
        Child := FirstChild(Child, 'customLevel');
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
  except
    { a configuration that does not load leaves no scenario behind }
    FScenarios.Clear;
    FName := '';
    raise;
  end;
  finally
    Doc.Free;
  end;
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
  Tree: TLandrixXmlXPathTree;
  Evaluator: TLandrixXmlXPathEvaluator;
  Scenario, Candidate: TLandrixEInvoiceValidationScenario;
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
begin
  AResult.Clear;
  Result := False;
  Scenario := nil;
  Tree := TLandrixXmlXPathTree.Create;
  try
    { well-formedness: a document that does not load matches no scenario }
    try
      Tree.LoadFromFile(AFileName);
    except
      on E: ELandrixXmlError do
      begin
        Msg := AResult.Add(evs_Wellformedness, 0, 'generic-error', evl_Error);
        Msg.FLine := E.Line;
        Msg.FColumn := E.Column;
        Msg.FText := TLandrixEInvoiceString(E.Message);
        Exit;
      end;
    end;
    Evaluator := TLandrixXmlXPathEvaluator.Create(Tree);
    try
      for I := 0 to Integer(FScenarios.Count) - 1 do
      begin
        Candidate := Scenarios[I];
        try
          if Evaluator.EvaluateBoolean(Candidate.FMatch, 0) then
          begin
            Inc(AResult.FMatchCount);
            Scenario := Candidate;
          end;
        except
          { as KoSIT: an expression that raises does not match }
          on ELandrixXmlError do ;
        end;
      end;
    finally
      Evaluator.Free;
    end;
    { as KoSIT: none or several matching scenarios mean no scenario }
    if AResult.FMatchCount <> 1 then
      Scenario := nil;
    if Scenario = nil then
      Exit;
    AResult.FScenarioName := Scenario.FName;

    XsdValidator := TLandrixXmlXsdValidator.Create(TLandrixXmlXsdSchemaSet(SchemaOf(Scenario.FSchemaFile)));
    try
      XsdValidator.MaxErrors := 0;
      XsdValidator.ValidateFile(AFileName);
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
            if AResult.FProcessingError = '' then
              AResult.FProcessingError := TLandrixEInvoiceString(ExtractFileName(Scenario.SchematronFiles[I])) + ': ' +
                ErrorText;
          end
          else
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
  Result := AResult.FAccepted;
end;

end.
