{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Validates an e-invoice document as a whole, XML or a hybrid PDF
  (ZUGFeRD, Factur-X; told by the content): the KoSIT run of a
  configuration the caller chooses (well-formedness, XML schema,
  Schematron; LandrixEInvoiceValidator), reading through the facade and
  the library's own rule check; for a PDF first the embedding of the XML
  and the XMP metadata (levels 2 and 3, LandrixEInvoicePdfCheck), then the
  same for the embedded invoice. For XML only the KoSIT run decides the
  verdict; for a PDF levels 2 and 3 decide with it. The own rule check
  predicts what KoSIT would report and never changes it (its findings are
  marked Predicted). Without a configuration an XML document gets no
  verdict (Incomplete), a PDF only a rejection by levels 2 and 3; reading
  and the rule check still run. PDF/A (level 1, so far the rules of clauses
  6.1, 6.3 to 6.6 and 6.8 to 6.11) is
  reported with its findings and status but does not count for the
  verdict. The advisory checks (LandrixEInvoiceAdvisory, Options.Advisory)
  run on the invoice as read and never count for the verdict either. One
  flat list of findings, a status per part.

  DE: Prueft ein E-Rechnungs-Dokument als Ganzes, XML oder ein hybrides
  PDF (ZUGFeRD, Factur-X; am Inhalt erkannt): den KoSIT-Lauf einer
  Konfiguration, die der Aufrufer waehlt (Wohlgeformtheit, XML-Schema,
  Schematron; LandrixEInvoiceValidator), das Lesen ueber die Fassade und
  die eigene Regelpruefung der Bibliothek; bei einem PDF zuerst die
  Einbettung der XML und die XMP-Metadaten (Ebenen 2 und 3,
  LandrixEInvoicePdfCheck), dann dasselbe fuer die eingebettete Rechnung.
  Bei XML entscheidet nur der KoSIT-Lauf das Urteil, bei einem PDF
  entscheiden die Ebenen 2 und 3 mit. Die eigene Regelpruefung sagt
  voraus, was KoSIT melden wuerde, und aendert es nie (ihre Befunde sind
  als Predicted markiert). Ohne Konfiguration bekommt ein XML-Dokument
  kein Urteil (Incomplete), ein PDF nur eine Ablehnung durch die Ebenen 2
  und 3; Lesen und Regelpruefung laufen trotzdem. PDF/A (Ebene 1, bisher
  die Regeln der Abschnitte 6.1, 6.3 bis 6.6 und 6.8 bis
  6.11) wird mit Befunden und Status gemeldet,
  zaehlt aber nicht fuer das Urteil. Die Hinweispruefungen
  (LandrixEInvoiceAdvisory, Options.Advisory) laufen auf der gelesenen
  Rechnung und zaehlen ebenfalls nie fuer das Urteil. Eine flache
  Befundliste, ein Status je Teil. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceValidation;

{$I LandrixEInvoice.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceInvoice,
  LandrixEInvoice,
  LandrixEInvoicePdfCheck,
  LandrixEInvoiceValidator,
  LandrixEInvoiceAdvisory;

type
  { The verdict on a document. Incomplete: no verdict could be reached
    because a part that decides it did not run or is incomplete (no KoSIT
    configuration; for a PDF also level 2 or 3).
    DE: Das Urteil ueber ein Dokument. Incomplete: es kam kein Urteil
    zustande, weil ein Teil, der es entscheidet, nicht gelaufen oder
    unvollstaendig ist (keine KoSIT-Konfiguration; bei einem PDF auch
    Ebene 2 oder 3). }
  TLandrixEInvoiceVerdict = (ev_Accepted, ev_Rejected, ev_Incomplete);

  { The parts of a validation: reading through the facade, the KoSIT run,
    the own rule check (a prediction); for a PDF the embedding of the XML
    (level 2), the XMP metadata (level 3) and PDF/A (level 1: evr_Failed on a
    violation, else evr_Incomplete, as not every PDF/A rule is implemented;
    it does not count for the verdict); the advisory checks (hints, at most
    warnings; evr_Passed when they ran, evr_Incomplete when they stopped,
    never evr_Failed; they never count for the verdict).
    DE: Die Teile einer Pruefung: Lesen ueber die Fassade, der KoSIT-Lauf,
    die eigene Regelpruefung (eine Vorhersage); bei einem PDF die
    Einbettung der XML (Ebene 2), die XMP-Metadaten (Ebene 3) und PDF/A
    (Ebene 1: evr_Failed bei einem Verstoss, sonst evr_Incomplete, weil
    nicht jede PDF/A-Regel umgesetzt ist; zaehlt nicht fuer das Urteil);
    die Hinweispruefungen (Hinweise, hoechstens Warnungen; evr_Passed, wenn
    sie liefen, evr_Incomplete, wenn sie abbrachen, nie evr_Failed; sie
    zaehlen nie fuer das Urteil). }
  TLandrixEInvoiceValidationPart = (evp_Read, evp_KoSIT, evp_ModelCheck, evp_PdfEmbedding, evp_PdfMetadata,
    evp_PdfA, evp_Advisory);

  { The status of a part. Failed: it found errors (reading: an error, or
    the document could not be read at all). Incomplete: it started but
    could not finish (a Schematron step that failed, a part that raised).
    DE: Der Status eines Teils. Failed: er hat Fehler gefunden (Lesen: ein
    Fehler, oder das Dokument liess sich gar nicht lesen). Incomplete: er
    hat begonnen, konnte aber nicht zu Ende laufen (ein Schematron-Schritt,
    der scheiterte, ein Teil, der eine Ausnahme ausloeste). }
  TLandrixEInvoicePartStatus = (evr_NotRun, evr_Passed, evr_Failed, evr_Incomplete);

  { The KoSIT step that reported a finding (well-formedness, XML schema,
    Schematron); efs_None for every other finding, also for the KoSIT
    findings of the validation itself (no scenario, a processing error).
    DE: Der KoSIT-Schritt, der einen Befund gemeldet hat (Wohlgeformtheit,
    XML-Schema, Schematron); efs_None fuer jeden anderen Befund, auch fuer
    die KoSIT-Befunde der Pruefung selbst (kein Szenario, ein
    Verarbeitungsfehler). }
  TLandrixEInvoiceFindingStep = (efs_None, efs_Wellformedness, efs_XmlSchema, efs_Schematron);

  { The kind of a registered KoSIT configuration, declared by the caller
    (never guessed from its name); it decides the precedence when several
    configurations match a document.
    DE: Die Art einer registrierten KoSIT-Konfiguration, vom Aufrufer
    angegeben (nie aus ihrem Namen geraten); sie entscheidet den Vorrang,
    wenn mehrere Konfigurationen zu einem Dokument passen. }
  TLandrixEInvoiceConfigurationKind = (eck_Other, eck_XRechnung, eck_ZUGFeRD, eck_PeppolBIS);

  { How the KoSIT configuration of a validation was chosen. ecc_None: no
    KoSIT run (no configuration, or a document that is not well-formed:
    the first registered configuration reports that). ecc_Fixed:
    Options.Configuration. ecc_OnlyMatch: the one registered configuration
    with exactly one matching scenario. ecc_Precedence: several had one,
    the precedence decided (eck_ZUGFeRD, eck_PeppolBIS, eck_XRechnung,
    eck_Other; then the order of registration). ecc_NoMatch: none had
    exactly one, rejected as KoSIT does without a scenario.
    DE: Wie die KoSIT-Konfiguration einer Pruefung gewaehlt wurde.
    ecc_None: kein KoSIT-Lauf (keine Konfiguration, oder ein nicht
    wohlgeformtes Dokument: das meldet die erste registrierte
    Konfiguration). ecc_Fixed: Options.Configuration. ecc_OnlyMatch: die
    eine registrierte Konfiguration mit genau einem passenden Szenario.
    ecc_Precedence: mehrere hatten eines, der Vorrang entschied
    (eck_ZUGFeRD, eck_PeppolBIS, eck_XRechnung, eck_Other; dann die
    Reihenfolge der Registrierung). ecc_NoMatch: keine hatte genau eines,
    abgelehnt wie bei KoSIT ohne Szenario. }
  TLandrixEInvoiceConfigurationChoice = (ecc_None, ecc_Fixed, ecc_OnlyMatch, ecc_Precedence, ecc_NoMatch);

  { One finding. RuleID: the KoSIT code (cvc-..., generic-error or the id
    of the assert or report), the rule identifier of the own rule check
    (e.g. BR-DE-15), for reading the kind of the diagnostic (e.g.
    UnknownElement); '' for a finding of the validation itself (no
    scenario, a processing error, a part that raised, a document that
    could not be read), the rule of the PDF checker (BR-HYBRID-..,
    LX-PDF-..). Location: the XPath location (KoSIT), the element path
    (reading, the Factur-X code asserts), the model path of the rule check
    (see TLandrixEInvoiceDiagnostic.Path; often '') or the place in the PDF
    as the PDF checker writes it (e.g. /Root/Names/EmbeddedFiles/Names[1]/UF,
    XMP fx:Version); Line and Column 0 when unknown (KoSIT, reading, the
    rule check and BR-HYBRID-12: in the invoice XML; LX-PDF-11: in the XMP
    packet). Terms, Expected, Found and Calculation: as in
    TLandrixEInvoiceDiagnostic (rule check), '' otherwise.
    DE: Ein Befund. RuleID: der KoSIT-Code (cvc-..., generic-error oder
    die id des asserts bzw. reports), die Regelkennung der eigenen
    Regelpruefung (z. B. BR-DE-15), beim Lesen die Art der Meldung (z. B.
    UnknownElement); '' fuer einen Befund der Pruefung selbst (kein
    Szenario, ein Verarbeitungsfehler, ein Teil mit Ausnahme, ein Dokument,
    das sich nicht lesen liess), die Regel des PDF-Pruefers (BR-HYBRID-..,
    LX-PDF-..). Location: der XPath-Ort (KoSIT), der Elementpfad (Lesen,
    die Factur-X-Code-Asserts), der Modellpfad der Regelpruefung (siehe
    TLandrixEInvoiceDiagnostic.Path; oft '') oder der Ort im PDF, wie der
    PDF-Pruefer ihn schreibt (z. B. /Root/Names/EmbeddedFiles/Names[1]/UF,
    XMP fx:Version); Line und Column 0, wenn unbekannt (KoSIT, Lesen,
    Regelpruefung und BR-HYBRID-12: in der Rechnungs-XML; LX-PDF-11: im
    XMP-Paket). Terms, Expected, Found und Calculation: wie in
    TLandrixEInvoiceDiagnostic (Regelpruefung), sonst ''. }
  TLandrixEInvoiceFinding = class(TObject)
  private
    FPart: TLandrixEInvoiceValidationPart;
    FRuleID: TLandrixEInvoiceString;
    FSeverity: TLandrixEInvoiceDiagnosticSeverity;
    FLocation: TLandrixEInvoiceString;
    FLine: Integer;
    FColumn: Integer;
    FText: TLandrixEInvoiceString;
    FPredicted: Boolean;
    FStep: TLandrixEInvoiceFindingStep;
    FTerms: TLandrixEInvoiceString;
    FExpected: TLandrixEInvoiceString;
    FFound: TLandrixEInvoiceString;
    FCalculation: TLandrixEInvoiceString;
  public
    { The part that reported it. DE: Der Teil, der ihn gemeldet hat. }
    property Part: TLandrixEInvoiceValidationPart read FPart;
    property RuleID: TLandrixEInvoiceString read FRuleID;
    { KoSIT: the effective level (after customLevel).
      DE: KoSIT: die wirksame Stufe (nach customLevel). }
    property Severity: TLandrixEInvoiceDiagnosticSeverity read FSeverity;
    property Location: TLandrixEInvoiceString read FLocation;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
    { The message (English, or as the rule set writes it).
      DE: Der Meldungstext (englisch, oder wie das Regelwerk ihn schreibt). }
    property Text: TLandrixEInvoiceString read FText;
    { True for the rule findings of the own rule check: they predict what KoSIT
      would report, they do not replace it.
      DE: True fuer die Befunde der eigenen Regelpruefung: sie sagen
      voraus, was KoSIT melden wuerde, sie ersetzen es nicht. }
    property Predicted: Boolean read FPredicted;
    { KoSIT: the step that reported it; efs_None otherwise.
      DE: KoSIT: der Schritt, der ihn gemeldet hat; sonst efs_None. }
    property Step: TLandrixEInvoiceFindingStep read FStep;
    { Rule check: the fields of the same name of TLandrixEInvoiceDiagnostic
      (business terms, expected and found value, how the expected value
      came about); '' otherwise.
      DE: Regelpruefung: die gleichnamigen Felder von
      TLandrixEInvoiceDiagnostic (Geschaeftsbegriffe, erwarteter und
      gefundener Wert, wie der erwartete Wert zustande kam); sonst ''. }
    property Terms: TLandrixEInvoiceString read FTerms;
    property Expected: TLandrixEInvoiceString read FExpected;
    property Found: TLandrixEInvoiceString read FFound;
    property Calculation: TLandrixEInvoiceString read FCalculation;
  end;

  { The result of a validation.
    DE: Das Ergebnis einer Pruefung. }
  TLandrixEInvoiceDocumentValidation = class(TObject)
  private
    FVerdict: TLandrixEInvoiceVerdict;
    FStatus: array[TLandrixEInvoiceValidationPart] of TLandrixEInvoicePartStatus;
    FFindings: TObjectList;
    FScenarioName: TLandrixEInvoiceString;
    FConfigurationName: TLandrixEInvoiceString;
    FConfigurationKind: TLandrixEInvoiceConfigurationKind;
    FConfigurationChoice: TLandrixEInvoiceConfigurationChoice;
    FCandidateCount: Integer;
    FCandidateKinds: set of TLandrixEInvoiceConfigurationKind;
    FInfo: TLandrixEInvoiceDocumentInfo;
    FPdf: TLandrixEInvoicePdfCheckResult;
    FKosit: TLandrixEInvoiceValidationResult;
    FXml: TMemoryStream;
    function GetStatus(APart: TLandrixEInvoiceValidationPart): TLandrixEInvoicePartStatus;
    function GetInvoiceXml: TMemoryStream;
    function GetFindingCount: Integer;
    function GetFinding(AIndex: Integer): TLandrixEInvoiceFinding;
    procedure AddFailure(APart: TLandrixEInvoiceValidationPart; E: Exception);
    function AddFinding(APart: TLandrixEInvoiceValidationPart; const ARuleID: TLandrixEInvoiceString;
      ASeverity: TLandrixEInvoiceDiagnosticSeverity; const ALocation: TLandrixEInvoiceString;
      ALine, AColumn: Integer; const AText: TLandrixEInvoiceString): TLandrixEInvoiceFinding;
    procedure AddDiagnosticFinding(APart: TLandrixEInvoiceValidationPart; ADiagnostic: TLandrixEInvoiceDiagnostic);
  public
    constructor Create;
    destructor Destroy; override;
    { Empties the result: ev_Incomplete, every part evr_NotRun, no findings,
      Pdf nil.
      DE: Leert das Ergebnis: ev_Incomplete, jeder Teil evr_NotRun, keine
      Befunde, Pdf nil. }
    procedure Clear;
    { The verdict: for XML the assessment of the KoSIT run (ev_Incomplete
      without one); for a PDF ev_Rejected if KoSIT rejects or level 2 or 3
      failed, ev_Incomplete if one of them did not run or is incomplete,
      ev_Accepted otherwise (PDF/A does not count). KoSIT rejects also when
      it could not finish (a processing error, KoSIT evr_Incomplete).
      DE: Das Urteil: bei XML die Bewertung des KoSIT-Laufs (ev_Incomplete
      ohne ihn); bei einem PDF ev_Rejected, wenn KoSIT ablehnt oder Ebene 2
      oder 3 fehlschlug, ev_Incomplete, wenn eine davon nicht lief oder
      unvollstaendig ist, sonst ev_Accepted (PDF/A zaehlt nicht mit). KoSIT
      lehnt auch ab, wenn es nicht zu Ende kam (ein Verarbeitungsfehler,
      KoSIT evr_Incomplete). }
    property Verdict: TLandrixEInvoiceVerdict read FVerdict;
    { The status of each part. DE: Der Status jedes Teils. }
    property Status[APart: TLandrixEInvoiceValidationPart]: TLandrixEInvoicePartStatus read GetStatus;
    { The findings in the order: PDF embedding, PDF metadata, PDF/A,
      KoSIT, reading, rule check, advisory checks.
      DE: Die Befunde in der Reihenfolge: PDF-Einbettung, PDF-Metadaten,
      PDF/A, KoSIT, Lesen, Regelpruefung, Hinweispruefungen. }
    property FindingCount: Integer read GetFindingCount;
    property Findings[AIndex: Integer]: TLandrixEInvoiceFinding read GetFinding; default;
    { The KoSIT scenario chosen, '' if none.
      DE: Das gewaehlte KoSIT-Szenario, '' wenn keines. }
    property ScenarioName: TLandrixEInvoiceString read FScenarioName;
    { The name of the KoSIT configuration that ran (its scenarios/name, as
      it was at the time of the run), '' without a KoSIT run.
      DE: Der Name der KoSIT-Konfiguration, die lief (ihr scenarios/name,
      wie er zur Zeit des Laufs war), '' ohne KoSIT-Lauf. }
    property ConfigurationName: TLandrixEInvoiceString read FConfigurationName;
    { The kind of the chosen registered configuration; eck_Other for
      Options.Configuration and without a choice.
      DE: Die Art der gewaehlten registrierten Konfiguration; eck_Other
      fuer Options.Configuration und ohne Wahl. }
    property ConfigurationKind: TLandrixEInvoiceConfigurationKind read FConfigurationKind;
    { How the configuration was chosen. DE: Wie die Konfiguration gewaehlt
      wurde. }
    property ConfigurationChoice: TLandrixEInvoiceConfigurationChoice read FConfigurationChoice;
    { The registered configurations with exactly one matching scenario (0
      without a choice among them).
      DE: Die registrierten Konfigurationen mit genau einem passenden
      Szenario (0 ohne Wahl unter ihnen). }
    property CandidateCount: Integer read FCandidateCount;
    { What reading found out (syntax, BT-24, specification); empty when the
      document could not be read, except for a PDF: Source eso_Pdf and
      PdfAttachmentName are always set (Pdf has the details).
      DE: Was das Lesen herausgefunden hat (Syntax, BT-24, Spezifikation);
      leer, wenn das Dokument nicht gelesen werden konnte, ausser bei einem
      PDF: Source eso_Pdf und PdfAttachmentName sind immer gesetzt (Pdf hat
      die Einzelheiten). }
    property Info: TLandrixEInvoiceDocumentInfo read FInfo;
    { For a PDF the result of the PDF checker (hybrid kind, file names, XMP
      values, versions, the embedded invoice bytes); nil for XML. Owned by
      the result; read only. Status and Findings of the validation are
      authoritative, Pdf.Diagnostics is their raw source.
      DE: Bei einem PDF das Ergebnis des PDF-Pruefers (hybride Art,
      Dateinamen, XMP-Werte, Versionen, die eingebetteten Rechnungsbytes);
      nil bei XML. Gehoert dem Ergebnis; nur lesen. Status und Findings der
      Pruefung sind massgeblich, Pdf.Diagnostics ist ihre Rohquelle. }
    property Pdf: TLandrixEInvoicePdfCheckResult read FPdf;
    { The result of the KoSIT run (scenario, steps, messages, assessment),
      for the KoSIT report; nil without a run. Owned by the result; read
      only.
      DE: Das Ergebnis des KoSIT-Laufs (Szenario, Schritte, Meldungen,
      Bewertung), fuer den KoSIT-Bericht; nil ohne Lauf. Gehoert dem
      Ergebnis; nur lesen. }
    property Kosit: TLandrixEInvoiceValidationResult read FKosit;
    { The XML that was checked: the document itself, for a PDF the
      embedded invoice (Pdf.Invoice); nil when there is none (no stream,
      more than 2 GB, a PDF without invoice). Owned by the result; read
      only.
      DE: Das gepruefte XML: das Dokument selbst, bei einem PDF die
      eingebettete Rechnung (Pdf.Invoice); nil, wenn es keines gibt (kein
      Stream, mehr als 2 GB, ein PDF ohne Rechnung). Gehoert dem Ergebnis;
      nur lesen. }
    property InvoiceXml: TMemoryStream read GetInvoiceXml;
  end;

  { The options of a validation.
    DE: Die Optionen einer Pruefung. }
  TLandrixEInvoiceValidationOptions = class(TObject)
  private
    FConfiguration: TLandrixEInvoiceValidator;
    FModelCheck: Boolean;
    FAdvisory: TLandrixEInvoiceAdvisoryFamilies;
    FConfigurations: TObjectList;
    FKinds: array of TLandrixEInvoiceConfigurationKind;
    function GetConfigurationCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    { Registers a loaded KoSIT configuration (owned by the caller) with its
      kind, for the choice per document when Configuration is nil: the
      configuration with exactly one matching scenario runs; with several,
      the precedence of the kind decides (see ecc_Precedence). A
      configuration registered twice counts twice.
      DE: Registriert eine geladene KoSIT-Konfiguration (vom Aufrufer
      besessen) mit ihrer Art, fuer die Wahl je Dokument, wenn
      Configuration nil ist: die Konfiguration mit genau einem passenden
      Szenario laeuft; bei mehreren entscheidet der Vorrang der Art (siehe
      ecc_Precedence). Eine zweimal registrierte Konfiguration zaehlt
      zweimal. }
    procedure AddConfiguration(AConfiguration: TLandrixEInvoiceValidator; AKind: TLandrixEInvoiceConfigurationKind);
    { Removes every registered configuration (they are not freed).
      DE: Entfernt jede registrierte Konfiguration (sie werden nicht
      freigegeben). }
    procedure ClearConfigurations;
    { The number of registered configurations. DE: Die Zahl der
      registrierten Konfigurationen. }
    property ConfigurationCount: Integer read GetConfigurationCount;
    { The KoSIT configuration to run, loaded and owned by the caller; it
      wins over the registered ones. nil (the default) and none registered:
      no KoSIT run, the verdict is ev_Incomplete (for a PDF ev_Rejected if
      level 2 or 3 failed).
      DE: Die KoSIT-Konfiguration, die laufen soll, vom Aufrufer geladen
      und besessen; sie hat Vorrang vor den registrierten. nil (Vorgabe)
      und keine registriert: kein KoSIT-Lauf, das Urteil ist ev_Incomplete
      (bei einem PDF ev_Rejected, wenn Ebene 2 oder 3 fehlschlug). }
    property Configuration: TLandrixEInvoiceValidator read FConfiguration write FConfiguration;
    { Run the own rule check (default True).
      DE: Die eigene Regelpruefung ausfuehren (Vorgabe True). }
    property ModelCheck: Boolean read FModelCheck write FModelCheck;
    { The families of advisory checks to run (default
      LandrixEInvoiceAdvisoryTechnical; [] for none: evp_Advisory stays
      evr_NotRun).
      DE: Die Familien der Hinweispruefungen, die laufen sollen (Vorgabe
      LandrixEInvoiceAdvisoryTechnical; [] fuer keine: evp_Advisory bleibt
      evr_NotRun). }
    property Advisory: TLandrixEInvoiceAdvisoryFamilies read FAdvisory write FAdvisory;
  end;

  { Validates documents with its Options.
    DE: Prueft Dokumente mit seinen Options. }
  TLandrixEInvoiceDocumentValidator = class(TObject)
  private
    FOptions: TLandrixEInvoiceValidationOptions;
    procedure RunKosit(AConfiguration: TLandrixEInvoiceValidator; AData: TStream;
      AResult: TLandrixEInvoiceDocumentValidation; out AWellFormed: Boolean);
    function ChooseConfiguration(AData: TStream; AResult: TLandrixEInvoiceDocumentValidation;
      out AWellFormed: Boolean): TLandrixEInvoiceValidator;
    function RunChosen(AData: TStream; AResult: TLandrixEInvoiceDocumentValidation;
      out AWellFormed: Boolean): Boolean;
    procedure CheckKind(AResult: TLandrixEInvoiceDocumentValidation; AKositEnd: Integer);
    procedure ValidatePdf(AData: TMemoryStream; AResult: TLandrixEInvoiceDocumentValidation);
    procedure ReadAndCheck(AData: TMemoryStream; AResult: TLandrixEInvoiceDocumentValidation;
      APdfChecker: TLandrixEInvoicePdfChecker);
    procedure RunModelCheck(ADoc: TLandrixEInvoiceDocument; AResult: TLandrixEInvoiceDocumentValidation);
    procedure RunAdvisory(ADoc: TLandrixEInvoiceDocument; AResult: TLandrixEInvoiceDocumentValidation);
  protected
    { Runs the advisory checks of Options.Advisory on AInvoice (read as
      ATarget, Standard est_None when unknown; AReported: the rule identifiers
      the rule check reported) into ADiagnostics. An
      exception leaves evp_Advisory evr_Incomplete with a warning; the
      verdict stays. Tests override it.
      DE: Fuehrt die Hinweispruefungen von Options.Advisory auf AInvoice
      (gelesen als ATarget, Standard est_None, wenn unbekannt;
      AReported: die Regelkennungen, die die Regelpruefung meldete) in
      ADiagnostics aus. Eine Ausnahme laesst evp_Advisory evr_Incomplete
      mit einer Warnung; das Urteil bleibt. Tests ueberschreiben sie. }
    procedure Advise(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget; AReported: TStrings;
      ADiagnostics: TLandrixEInvoiceDiagnostics); virtual;
  public
    constructor Create;
    destructor Destroy; override;
    { Validates the document in AStream, read from its position to the end
      (a hybrid PDF if it starts with %PDF-, XML otherwise), fills AResult
      and returns AResult.Verdict (see Verdict). For XML: with
      Options.Configuration the verdict is the KoSIT assessment; without it
      KoSIT stays evr_NotRun and the verdict is ev_Incomplete. Reading and
      the own rule check run on the same bytes unless KoSIT finds the
      document not well-formed; without KoSIT, reading reports a document
      that is not well-formed. For a PDF: levels 2 and 3 first, then the
      same for the embedded invoice, if level 2 found one; reading also
      runs the second pass of the PDF checker (profile and country rules),
      without it level 2 is at most evr_Incomplete. An exception of reading
      or of the rule check (other than EOutOfMemory) becomes a finding and
      leaves that part evr_Incomplete, or evr_Failed for a document the
      facade cannot read; the verdict stays. A problem of the setup (see
      TLandrixEInvoiceValidator.Validate) raises ELandrixEInvoiceError; an
      exception of AStream itself (e.g. EReadError) is passed on.
      DE: Prueft das Dokument in AStream, gelesen ab seiner Position bis
      zum Ende (ein hybrides PDF, wenn es mit %PDF- beginnt, sonst XML),
      fuellt AResult und liefert AResult.Verdict (siehe Verdict). Bei XML:
      mit Options.Configuration ist das Urteil die Bewertung von KoSIT;
      ohne bleibt KoSIT evr_NotRun und das Urteil ist ev_Incomplete. Lesen
      und eigene Regelpruefung laufen auf denselben Bytes, ausser KoSIT
      findet das Dokument nicht wohlgeformt; ohne KoSIT meldet das Lesen
      ein nicht wohlgeformtes Dokument. Bei einem PDF: zuerst die Ebenen 2
      und 3, dann dasselbe fuer die eingebettete Rechnung, wenn Ebene 2
      eine gefunden hat; das Lesen fuehrt auch den zweiten Durchgang des
      PDF-Pruefers aus (Profil- und Laenderregeln), ohne ihn ist Ebene 2
      hoechstens evr_Incomplete. Eine Ausnahme beim Lesen oder in der
      Regelpruefung (ausser EOutOfMemory) wird zum Befund und laesst den
      Teil evr_Incomplete, oder evr_Failed fuer ein Dokument, das die
      Fassade nicht lesen kann; das Urteil bleibt. Ein Problem der
      Einrichtung (siehe TLandrixEInvoiceValidator.Validate) loest
      ELandrixEInvoiceError aus; eine Ausnahme von AStream selbst (z. B.
      EReadError) wird weitergereicht. }
    function ValidateStream(AStream: TStream; AResult: TLandrixEInvoiceDocumentValidation): TLandrixEInvoiceVerdict;
    { The same for a file; a file that cannot be opened raises the
      exception of TFileStream (EFOpenError).
      DE: Dasselbe fuer eine Datei; eine Datei, die sich nicht oeffnen
      laesst, loest die Ausnahme von TFileStream aus (EFOpenError). }
    function ValidateFile(const AFileName: string; AResult: TLandrixEInvoiceDocumentValidation): TLandrixEInvoiceVerdict;
    { The options, owned by the validator.
      DE: Die Optionen, im Besitz des Pruefers. }
    property Options: TLandrixEInvoiceValidationOptions read FOptions;
  end;

implementation

uses
  LandrixEInvoiceSpecs,
  LandrixEInvoiceCheck,
  LandrixEInvoicePdf;

function SeverityOf(ALevel: TLandrixEInvoiceValidationLevel): TLandrixEInvoiceDiagnosticSeverity;
begin
  case ALevel of
    evl_Information:
      Result := eds_Info;
    evl_Warning:
      Result := eds_Warning;
  else
    Result := eds_Error;
  end;
end;

function StepOf(AStep: TLandrixEInvoiceValidationStep): TLandrixEInvoiceFindingStep;
begin
  case AStep of
    evs_Wellformedness:
      Result := efs_Wellformedness;
    evs_XmlSchema:
      Result := efs_XmlSchema;
  else
    Result := efs_Schematron;
  end;
end;

{ --- TLandrixEInvoiceDocumentValidation ---------------------------------- }

constructor TLandrixEInvoiceDocumentValidation.Create;
begin
  inherited Create;
  FFindings := TObjectList.Create(True);
  Clear;
end;

destructor TLandrixEInvoiceDocumentValidation.Destroy;
begin
  FKosit.Free;
  FXml.Free;
  FPdf.Free;
  FFindings.Free;
  inherited Destroy;
end;

procedure TLandrixEInvoiceDocumentValidation.Clear;
var
  P: TLandrixEInvoiceValidationPart;
begin
  FVerdict := ev_Incomplete;
  for P := Low(TLandrixEInvoiceValidationPart) to High(TLandrixEInvoiceValidationPart) do
    FStatus[P] := evr_NotRun;
  FFindings.Clear;
  FScenarioName := '';
  FConfigurationName := '';
  FConfigurationKind := eck_Other;
  FConfigurationChoice := ecc_None;
  FCandidateCount := 0;
  FCandidateKinds := [];
  FPdf.Free;
  FPdf := nil;
  FKosit.Free;
  FKosit := nil;
  FXml.Free;
  FXml := nil;
  Finalize(FInfo);
  FillChar(FInfo, SizeOf(FInfo), 0);
end;

function TLandrixEInvoiceDocumentValidation.GetStatus(APart: TLandrixEInvoiceValidationPart): TLandrixEInvoicePartStatus;
begin
  Result := FStatus[APart];
end;

function TLandrixEInvoiceDocumentValidation.GetInvoiceXml: TMemoryStream;
begin
  if FPdf <> nil then
  begin
    Result := FPdf.Invoice;
    if (Result <> nil) and (Result.Size = 0) then
      Result := nil;
  end
  else
    Result := FXml;
end;

function TLandrixEInvoiceDocumentValidation.GetFindingCount: Integer;
begin
  Result := Integer(FFindings.Count);
end;

function TLandrixEInvoiceDocumentValidation.GetFinding(AIndex: Integer): TLandrixEInvoiceFinding;
begin
  Result := TLandrixEInvoiceFinding(FFindings[AIndex]);
end;

function TLandrixEInvoiceDocumentValidation.AddFinding(APart: TLandrixEInvoiceValidationPart;
  const ARuleID: TLandrixEInvoiceString; ASeverity: TLandrixEInvoiceDiagnosticSeverity;
  const ALocation: TLandrixEInvoiceString; ALine, AColumn: Integer;
  const AText: TLandrixEInvoiceString): TLandrixEInvoiceFinding;
begin
  Result := TLandrixEInvoiceFinding.Create;
  FFindings.Add(Result);
  Result.FPart := APart;
  Result.FRuleID := ARuleID;
  Result.FSeverity := ASeverity;
  Result.FLocation := ALocation;
  Result.FLine := ALine;
  Result.FColumn := AColumn;
  Result.FText := AText;
  Result.FPredicted := (APart = evp_ModelCheck) and (ARuleID <> '');
  Result.FStep := efs_None;
end;

{ A finding from a diagnostic of the rule check or the PDF checker, with
  its rule details. }
procedure TLandrixEInvoiceDocumentValidation.AddDiagnosticFinding(APart: TLandrixEInvoiceValidationPart;
  ADiagnostic: TLandrixEInvoiceDiagnostic);
var
  F: TLandrixEInvoiceFinding;
begin
  F := AddFinding(APart, ADiagnostic.RuleID, ADiagnostic.Severity, ADiagnostic.Path, ADiagnostic.Line,
    ADiagnostic.Column, ADiagnostic.Message);
  { a hint is never an error
    DE: ein Hinweis ist nie ein Fehler }
  if (APart = evp_Advisory) and (F.FSeverity = eds_Error) then
    F.FSeverity := eds_Warning;
  F.FTerms := ADiagnostic.Terms;
  F.FExpected := ADiagnostic.Expected;
  F.FFound := ADiagnostic.Found;
  F.FCalculation := ADiagnostic.Calculation;
end;

{ A part that raised: a document the facade cannot read fails reading;
  anything else leaves the part incomplete (the advisory checks with a
  warning, never an error). }
procedure TLandrixEInvoiceDocumentValidation.AddFailure(APart: TLandrixEInvoiceValidationPart; E: Exception);
var
  Line, Column: Integer;
begin
  if (APart = evp_Read) and (E is ELandrixEInvoiceError) then
  begin
    Line := 0;
    Column := 0;
    if E is ELandrixEInvoiceFormatError then
    begin
      Line := ELandrixEInvoiceFormatError(E).Line;
      Column := ELandrixEInvoiceFormatError(E).Column;
    end;
    AddFinding(APart, '', eds_Error, '', Line, Column, TLandrixEInvoiceString(E.Message));
    FStatus[APart] := evr_Failed;
  end
  else if APart = evp_Advisory then
  begin
    AddFinding(APart, '', eds_Warning, '', 0, 0, TLandrixEInvoiceString(E.ClassName + ': ' + E.Message));
    FStatus[APart] := evr_Incomplete;
  end
  else
  begin
    AddFinding(APart, '', eds_Error, '', 0, 0, TLandrixEInvoiceString(E.ClassName + ': ' + E.Message));
    FStatus[APart] := evr_Incomplete;
  end;
end;

{ --- TLandrixEInvoiceValidationOptions ----------------------------------- }

constructor TLandrixEInvoiceValidationOptions.Create;
begin
  inherited Create;
  FModelCheck := True;
  FAdvisory := LandrixEInvoiceAdvisoryTechnical;
  { not owned: the caller frees the configurations }
  FConfigurations := TObjectList.Create(False);
end;

destructor TLandrixEInvoiceValidationOptions.Destroy;
begin
  FConfigurations.Free;
  inherited Destroy;
end;

procedure TLandrixEInvoiceValidationOptions.AddConfiguration(AConfiguration: TLandrixEInvoiceValidator;
  AKind: TLandrixEInvoiceConfigurationKind);
begin
  if AConfiguration = nil then
    raise ELandrixEInvoiceError.Create('AddConfiguration: no configuration');
  SetLength(FKinds, Integer(FConfigurations.Count) + 1);
  FKinds[Integer(FConfigurations.Count)] := AKind;
  FConfigurations.Add(AConfiguration);
end;

procedure TLandrixEInvoiceValidationOptions.ClearConfigurations;
begin
  FConfigurations.Clear;
  FKinds := nil;
end;

function TLandrixEInvoiceValidationOptions.GetConfigurationCount: Integer;
begin
  Result := Integer(FConfigurations.Count);
end;

{ --- TLandrixEInvoiceDocumentValidator ----------------------------------- }

constructor TLandrixEInvoiceDocumentValidator.Create;
begin
  inherited Create;
  FOptions := TLandrixEInvoiceValidationOptions.Create;
end;

destructor TLandrixEInvoiceDocumentValidator.Destroy;
begin
  FOptions.Free;
  inherited Destroy;
end;

function TLandrixEInvoiceDocumentValidator.ValidateFile(const AFileName: string;
  AResult: TLandrixEInvoiceDocumentValidation): TLandrixEInvoiceVerdict;
var
  F: TFileStream;
begin
  F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := ValidateStream(F, AResult);
  finally
    F.Free;
  end;
end;

function TLandrixEInvoiceDocumentValidator.ValidateStream(AStream: TStream;
  AResult: TLandrixEInvoiceDocumentValidation): TLandrixEInvoiceVerdict;
var
  Data: TMemoryStream;
  Count: Int64;
  WellFormed: Boolean;
  KositEnd: Integer;
begin
  AResult.Clear;
  Count := 0;
  if AStream <> nil then
    Count := AStream.Size - AStream.Position;
  if (AStream = nil) or (Count > MaxInt) then
  begin
    { no stream or more than 2 GB: the engine reports it without reading
      (a registered configuration too, without a choice) }
    if FOptions.Configuration <> nil then
    begin
      AResult.FConfigurationChoice := ecc_Fixed;
      RunKosit(FOptions.Configuration, AStream, AResult, WellFormed);
    end
    else if FOptions.ConfigurationCount > 0 then
    begin
      RunKosit(TLandrixEInvoiceValidator(FOptions.FConfigurations[0]), AStream, AResult, WellFormed);
      AResult.FConfigurationName := '';
    end
    else
    begin
      if AStream = nil then
        AResult.AddFinding(evp_Read, '', eds_Error, '', 0, 0, 'No document (no stream)')
      else
        AResult.AddFinding(evp_Read, '', eds_Error, '', 0, 0, 'The document is larger than 2 GB');
      AResult.FStatus[evp_Read] := evr_Failed;
    end;
    Result := AResult.FVerdict;
    Exit;
  end;
  Data := TMemoryStream.Create;
  try
    { CopyFrom with 0 copies the whole stream: only when bytes are left }
    if Count > 0 then
      Data.CopyFrom(AStream, Count);
    Data.Position := 0;
    if TLandrixEInvoicePdfExtractor.IsPdfStream(Data) then
      ValidatePdf(Data, AResult)
    else
    begin
      { XML: the KoSIT run decides; without it there is no verdict }
      RunChosen(Data, AResult, WellFormed);
      KositEnd := AResult.FindingCount;
      if WellFormed then
      begin
        ReadAndCheck(Data, AResult, nil);
        CheckKind(AResult, KositEnd);
      end;
      { the result keeps the checked XML }
      AResult.FXml := Data;
      Data := nil;
    end;
  finally
    Data.Free;
  end;
  Result := AResult.FVerdict;
end;

{ Runs the configuration on AData (nil or more than 2 GB: the engine
  reports it), adds its findings, sets the KoSIT status and the verdict to
  its assessment. AWellFormed: False if KoSIT found the document not
  well-formed. }
procedure TLandrixEInvoiceDocumentValidator.RunKosit(AConfiguration: TLandrixEInvoiceValidator; AData: TStream;
  AResult: TLandrixEInvoiceDocumentValidation; out AWellFormed: Boolean);
var
  K: TLandrixEInvoiceValidationResult;
  M: TLandrixEInvoiceValidationMessage;
  I: Integer;
begin
  K := TLandrixEInvoiceValidationResult.Create;
  try
    AConfiguration.ValidateStream(AData, K);
    AResult.FScenarioName := K.ScenarioName;
    AResult.FConfigurationName := AConfiguration.Name;
    AWellFormed := True;
    for I := 0 to K.MessageCount - 1 do
    begin
      M := K[I];
      if M.Step = evs_Wellformedness then
        AWellFormed := False;
      AResult.AddFinding(evp_KoSIT, M.Code, SeverityOf(M.EffectiveLevel), M.Location, M.Line, M.Column,
        M.Text).FStep := StepOf(M.Step);
    end;
    { KoSIT rejects without a message when no scenario is chosen (it
      chooses one when exactly one matches, whatever its name) }
    if AWellFormed and (K.MatchCount <> 1) then
      if K.MatchCount = 0 then
        AResult.AddFinding(evp_KoSIT, '', eds_Error, '', 0, 0, 'No scenario of the configuration matches the document')
      else
        AResult.AddFinding(evp_KoSIT, '', eds_Error, '', 0, 0,
          TLandrixEInvoiceString(IntToStr(K.MatchCount) + ' scenarios match the document; none is chosen'));
    if K.ProcessingError <> '' then
    begin
      AResult.AddFinding(evp_KoSIT, '', eds_Error, '', 0, 0, K.ProcessingError);
      AResult.FStatus[evp_KoSIT] := evr_Incomplete;
    end
    else if K.Accepted then
      AResult.FStatus[evp_KoSIT] := evr_Passed
    else
      AResult.FStatus[evp_KoSIT] := evr_Failed;
    if K.Accepted then
      AResult.FVerdict := ev_Accepted
    else
      AResult.FVerdict := ev_Rejected;
    { the result keeps the KoSIT result }
    AResult.FKosit.Free;
    AResult.FKosit := K;
  except
    K.Free;
    raise;
  end;
end;

const
  { The precedence among several candidates: the specific schema first.
    DE: Der Vorrang unter mehreren Kandidaten: das spezifische Schema
    zuerst. }
  KindRank: array[TLandrixEInvoiceConfigurationKind] of Integer = (3, 2, 0, 1);
  KindTexts: array[TLandrixEInvoiceConfigurationKind] of string = ('other', 'XRechnung', 'ZUGFeRD',
    'Peppol BIS');

{ The configuration for AData (read from its position; the position is
  restored): Options.Configuration (ecc_Fixed), else the registered
  configuration with exactly one matching scenario, by precedence among
  several (ecc_OnlyMatch, ecc_Precedence); nil without one (ecc_None, or
  ecc_NoMatch when none matches). AWellFormed False: the document is not
  well-formed (no choice, ecc_None).
  DE: Die Konfiguration fuer AData (gelesen ab seiner Position; die
  Position wird wiederhergestellt): Options.Configuration (ecc_Fixed),
  sonst die registrierte Konfiguration mit genau einem passenden Szenario,
  unter mehreren nach Vorrang (ecc_OnlyMatch, ecc_Precedence); nil ohne
  eine (ecc_None, oder ecc_NoMatch, wenn keine passt). AWellFormed False:
  das Dokument ist nicht wohlgeformt (keine Wahl, ecc_None). }
function TLandrixEInvoiceDocumentValidator.ChooseConfiguration(AData: TStream;
  AResult: TLandrixEInvoiceDocumentValidation; out AWellFormed: Boolean): TLandrixEInvoiceValidator;
var
  I, N, Best: Integer;
  Start: Int64;
begin
  AWellFormed := True;
  Result := FOptions.Configuration;
  if Result <> nil then
  begin
    AResult.FConfigurationChoice := ecc_Fixed;
    Exit;
  end;
  if FOptions.ConfigurationCount = 0 then
    Exit;
  Start := AData.Position;
  Best := -1;
  for I := 0 to FOptions.ConfigurationCount - 1 do
  begin
    AData.Position := Start;
    N := TLandrixEInvoiceValidator(FOptions.FConfigurations[I]).CountMatches(AData);
    if N < 0 then
    begin
      AWellFormed := False;
      Break;
    end;
    if N = 1 then
    begin
      Inc(AResult.FCandidateCount);
      Include(AResult.FCandidateKinds, FOptions.FKinds[I]);
      if (Best < 0) or (KindRank[FOptions.FKinds[I]] < KindRank[FOptions.FKinds[Best]]) then
        Best := I;
    end;
  end;
  AData.Position := Start;
  if not AWellFormed then
  begin
    AResult.FCandidateCount := 0;
    AResult.FCandidateKinds := [];
    Exit;
  end;
  if Best < 0 then
  begin
    AResult.FConfigurationChoice := ecc_NoMatch;
    Exit;
  end;
  Result := TLandrixEInvoiceValidator(FOptions.FConfigurations[Best]);
  AResult.FConfigurationKind := FOptions.FKinds[Best];
  if AResult.FCandidateCount = 1 then
    AResult.FConfigurationChoice := ecc_OnlyMatch
  else
    AResult.FConfigurationChoice := ecc_Precedence;
end;

{ Chooses the configuration and runs it on AData; True if KoSIT decided
  the verdict (a run, or no registered configuration matches). A document
  that is not well-formed runs the first registered configuration, which
  reports it, without a configuration name. No candidate is rejected as
  KoSIT rejects a document without a scenario.
  DE: Waehlt die Konfiguration und laesst sie auf AData laufen; True, wenn
  KoSIT das Urteil bestimmt hat (ein Lauf, oder keine registrierte
  Konfiguration passt). Ein nicht wohlgeformtes Dokument laeuft durch die
  erste registrierte Konfiguration, die es meldet, ohne
  Konfigurationsnamen. Kein Kandidat wird abgelehnt, wie KoSIT ein
  Dokument ohne Szenario ablehnt. }
function TLandrixEInvoiceDocumentValidator.RunChosen(AData: TStream; AResult: TLandrixEInvoiceDocumentValidation;
  out AWellFormed: Boolean): Boolean;
var
  Configuration: TLandrixEInvoiceValidator;
begin
  Result := True;
  Configuration := ChooseConfiguration(AData, AResult, AWellFormed);
  if not AWellFormed then
  begin
    RunKosit(TLandrixEInvoiceValidator(FOptions.FConfigurations[0]), AData, AResult, AWellFormed);
    AResult.FConfigurationName := '';
  end
  else if Configuration <> nil then
    RunKosit(Configuration, AData, AResult, AWellFormed)
  else if AResult.FConfigurationChoice = ecc_NoMatch then
  begin
    { as KoSIT without a scenario: rejected }
    AResult.AddFinding(evp_KoSIT, '', eds_Error, '', 0, 0,
      'No registered configuration has exactly one scenario that matches the document');
    AResult.FStatus[evp_KoSIT] := evr_Failed;
    AResult.FVerdict := ev_Rejected;
  end
  else
    Result := False;
end;

{ A warning after the KoSIT findings (at AKositEnd) when the chosen
  registered configuration is of another kind than the specification read
  from the document (BT-24), e.g. XRechnung for a Factur-X document because
  no ZUGFeRD configuration is registered; the verdict stays.
  DE: Eine Warnung nach den KoSIT-Befunden (an AKositEnd), wenn die
  gewaehlte registrierte Konfiguration von anderer Art ist als die aus dem
  Dokument gelesene Spezifikation (BT-24), z. B. XRechnung fuer ein
  Factur-X-Dokument, weil keine ZUGFeRD-Konfiguration registriert ist; das
  Urteil bleibt. A configuration of kind eck_Other gets no warning: its
  kind is unknown, and it never wins over a declared kind.
  DE: Eine Konfiguration der Art eck_Other bekommt keine Warnung: ihre Art
  ist unbekannt, und sie gewinnt nie gegen eine angegebene Art. }
procedure TLandrixEInvoiceDocumentValidator.CheckKind(AResult: TLandrixEInvoiceDocumentValidation;
  AKositEnd: Integer);
var
  Expected: TLandrixEInvoiceConfigurationKind;
  Registered: Boolean;
  I: Integer;
  Text: string;
begin
  if not (AResult.FConfigurationChoice in [ecc_OnlyMatch, ecc_Precedence]) or not AResult.FInfo.SpecFound or
     (AResult.FConfigurationKind = eck_Other) then
    Exit;
  case AResult.FInfo.Spec.Target.Standard of
    est_XRechnung:
      Expected := eck_XRechnung;
    est_FacturX:
      Expected := eck_ZUGFeRD;
    est_PeppolBIS:
      Expected := eck_PeppolBIS;
  else
    Exit;
  end;
  if Expected = AResult.FConfigurationKind then
    Exit;
  Registered := False;
  for I := 0 to FOptions.ConfigurationCount - 1 do
    if FOptions.FKinds[I] = Expected then
      Registered := True;
  Text := 'The document is ' + string(LandrixEInvoiceTargetToStr(AResult.FInfo.Spec.Target)) + ', a ' +
    KindTexts[Expected] + ' document, but the ' + KindTexts[AResult.FConfigurationKind] + ' configuration ran: ';
  if Expected in AResult.FCandidateKinds then
    Text := Text + 'the ' + KindTexts[Expected] + ' configuration matched too, the precedence chose ' +
      KindTexts[AResult.FConfigurationKind]
  else if Registered then
    Text := Text + 'the ' + KindTexts[Expected] + ' configuration has not exactly one matching scenario'
  else
    Text := Text + 'no ' + KindTexts[Expected] + ' configuration is registered';
  AResult.AddFinding(evp_KoSIT, '', eds_Warning, '', 0, 0, TLandrixEInvoiceString(Text));
  AResult.FFindings.Move(AResult.FindingCount - 1, AKositEnd);
end;

function PartStatusOf(AStatus: TLandrixEInvoicePdfLevelStatus): TLandrixEInvoicePartStatus;
begin
  case AStatus of
    eps_Passed:
      Result := evr_Passed;
    eps_Failed:
      Result := evr_Failed;
    eps_Incomplete:
      Result := evr_Incomplete;
  else
    Result := evr_NotRun;
  end;
end;

{ The level of a finding of the PDF checker: level 3 paths start with
  "XMP " or are /Root/Metadata (LandrixEInvoicePdfCheck), everything else is
  level 2. }
function IsMetadataFinding(const APath: TLandrixEInvoiceString): Boolean;
begin
  Result := (Copy(APath, 1, 4) = 'XMP ') or (APath = '/Root/Metadata');
end;

{ The part of a finding of the PDF checker: PDF/A (rule PDFA-... or a path
  starting with "PDF/A "), the XMP metadata or the embedding. }
function PdfFindingPart(D: TLandrixEInvoiceDiagnostic): TLandrixEInvoiceValidationPart;
begin
  if (Copy(D.RuleID, 1, 5) = 'PDFA-') or (Copy(D.Path, 1, 6) = 'PDF/A ') then
    Result := evp_PdfA
  else if IsMetadataFinding(D.Path) then
    Result := evp_PdfMetadata
  else
    Result := evp_PdfEmbedding;
end;

{ A hybrid PDF: levels 2 and 3, then the embedded invoice through KoSIT,
  reading (with the second pass of the PDF checker) and the rule check.
  The verdict: rejected if KoSIT rejects or level 2 or 3 failed;
  incomplete if one of them did not run or is incomplete; accepted
  otherwise. PDF/A (level 1) is reported and does not count.
  DE: Ein hybrides PDF: Ebenen 2 und 3, dann die eingebettete Rechnung
  durch KoSIT, Lesen (mit dem zweiten Durchgang des PDF-Pruefers) und
  Regelpruefung. Das Urteil: abgelehnt, wenn KoSIT ablehnt oder Ebene 2
  oder 3 fehlschlug; unvollstaendig, wenn eine davon nicht lief oder
  unvollstaendig ist; sonst angenommen. PDF/A (Ebene 1) wird gemeldet und
  zaehlt nicht mit. }
procedure TLandrixEInvoiceDocumentValidator.ValidatePdf(AData: TMemoryStream;
  AResult: TLandrixEInvoiceDocumentValidation);
var
  Checker: TLandrixEInvoicePdfChecker;
  Pdf: TLandrixEInvoicePdfCheckResult;
  D: TLandrixEInvoiceDiagnostics;
  First, J: Integer;
  I: TLandrixEInvoiceListIndex;
  WellFormed, KositRan: Boolean;
  Part: TLandrixEInvoiceValidationPart;
  KositEnd: Integer;
  Embedding, Meta, Kosit: TLandrixEInvoicePartStatus;
begin
  KositRan := False;
  Pdf := TLandrixEInvoicePdfCheckResult.Create;
  AResult.FPdf := Pdf;
  Checker := TLandrixEInvoicePdfChecker.Create;
  try
    Checker.CheckStream(AData, Pdf);
    { the embedded invoice, if level 2 found one with bytes }
    if (Pdf.HybridKind <> ehk_None) and (Pdf.Invoice.Size > 0) then
    begin
      KositRan := RunChosen(Pdf.Invoice, AResult, WellFormed);
      KositEnd := AResult.FindingCount;
      if WellFormed then
      begin
        ReadAndCheck(Pdf.Invoice, AResult, Checker);
        CheckKind(AResult, KositEnd);
      end;
    end;
  finally
    Checker.Free;
  end;
  AResult.FInfo.Source := eso_Pdf;
  AResult.FInfo.PdfAttachmentName := Pdf.InvoiceFileName;
  { the findings of levels 2, 3 and 1 go first, in this order }
  First := AResult.FindingCount;
  D := Pdf.Diagnostics;
  for Part := evp_PdfEmbedding to evp_PdfA do
    for I := 0 to D.Count - 1 do
      if PdfFindingPart(D[I]) = Part then
        AResult.AddDiagnosticFinding(Part, D[I]);
  for J := 0 to AResult.FindingCount - First - 1 do
    AResult.FFindings.Move(First + J, J);
  Embedding := PartStatusOf(Pdf.Status[epl_Embedding]);
  { the profile and country rules need the facts of the invoice: without
    them level 2 is not complete }
  if (Embedding = evr_Passed) and (Pdf.HybridKind in [ehk_FacturX, ehk_XRechnung]) and not Pdf.FactsChecked then
    Embedding := evr_Incomplete;
  Meta := PartStatusOf(Pdf.Status[epl_Metadata]);
  AResult.FStatus[evp_PdfEmbedding] := Embedding;
  AResult.FStatus[evp_PdfMetadata] := Meta;
  AResult.FStatus[evp_PdfA] := PartStatusOf(Pdf.Status[epl_PdfA]);
  Kosit := AResult.FStatus[evp_KoSIT];
  if (Embedding = evr_Failed) or (Meta = evr_Failed) or
     (KositRan and (AResult.FVerdict = ev_Rejected)) then
    AResult.FVerdict := ev_Rejected
  else if (Embedding <> evr_Passed) or (Meta <> evr_Passed) or (Kosit <> evr_Passed) then
    AResult.FVerdict := ev_Incomplete
  else
    AResult.FVerdict := ev_Accepted;
end;

procedure TLandrixEInvoiceDocumentValidator.ReadAndCheck(AData: TMemoryStream;
  AResult: TLandrixEInvoiceDocumentValidation; APdfChecker: TLandrixEInvoicePdfChecker);
var
  Doc: TLandrixEInvoiceDocument;
  I: TLandrixEInvoiceListIndex;
  Facts: TLandrixEInvoicePdfInvoiceFacts;
begin
  Doc := nil;
  try
    AData.Position := 0;
    try
      Doc := TLandrixEInvoice.LoadFromStream(AData, [eio_NoPdf, eio_InvoiceOnly]);
    except
      on E: Exception do
      begin
        if E is EOutOfMemory then
          raise;
        AResult.AddFailure(evp_Read, E);
        Exit;
      end;
    end;
    AResult.FInfo := Doc.Info;
    for I := 0 to Doc.Diagnostics.Count - 1 do
      AResult.AddFinding(evp_Read, LandrixEInvoiceDiagnosticKindToStr(Doc.Diagnostics[I].Kind),
        Doc.Diagnostics[I].Severity, Doc.Diagnostics[I].Path, Doc.Diagnostics[I].Line,
        Doc.Diagnostics[I].Column, Doc.Diagnostics[I].Message);
    if Doc.Diagnostics.HasErrors then
      AResult.FStatus[evp_Read] := evr_Failed
    else
      AResult.FStatus[evp_Read] := evr_Passed;
    { second pass of the PDF checker with what reading found; without a
      known specification Target.Syntax still tells UBL (LX-PDF-10) }
    if APdfChecker <> nil then
    begin
      Facts.Target := Doc.Info.Spec.Target;
      if not Doc.Info.SpecFound then
        Facts.Target.Syntax := Doc.Info.Syntax;
      Facts.SellerCountryCode := Doc.Invoice.AccountingSupplierParty.Address.CountryCode;
      Facts.BuyerCountryCode := Doc.Invoice.AccountingCustomerParty.Address.CountryCode;
      APdfChecker.CheckInvoiceFacts(AResult.FPdf, Facts);
    end;
    { without a known specification (BT-24) there are no rules to check;
      reading reported it }
    if FOptions.ModelCheck and Doc.Info.SpecFound then
      RunModelCheck(Doc, AResult);
    { the advisory checks need no specification
      DE: die Hinweispruefungen brauchen keine Spezifikation }
    if FOptions.Advisory <> [] then
      RunAdvisory(Doc, AResult);
  finally
    Doc.Free;
  end;
end;

procedure TLandrixEInvoiceDocumentValidator.RunModelCheck(ADoc: TLandrixEInvoiceDocument;
  AResult: TLandrixEInvoiceDocumentValidation);
var
  D: TLandrixEInvoiceDiagnostics;
  I: TLandrixEInvoiceListIndex;
  Errors: Integer;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    try
      Errors := LandrixEInvoiceCheckInvoice(ADoc.Invoice, ADoc.Info.Spec, D);
    except
      on E: Exception do
      begin
        if E is EOutOfMemory then
          raise;
        AResult.AddFailure(evp_ModelCheck, E);
        Exit;
      end;
    end;
    for I := 0 to D.Count - 1 do
      AResult.AddDiagnosticFinding(evp_ModelCheck, D[I]);
    if Errors > 0 then
      AResult.FStatus[evp_ModelCheck] := evr_Failed
    else
      AResult.FStatus[evp_ModelCheck] := evr_Passed;
  finally
    D.Free;
  end;
end;

{ The advisory checks: evr_Passed when they ran (whatever they found),
  evr_Incomplete when they raised; the hints found before are kept.
  DE: Die Hinweispruefungen: evr_Passed, wenn sie liefen (was immer sie
  fanden), evr_Incomplete, wenn sie eine Ausnahme ausloesten; die bis
  dahin gefundenen Hinweise bleiben. }
procedure TLandrixEInvoiceDocumentValidator.RunAdvisory(ADoc: TLandrixEInvoiceDocument;
  AResult: TLandrixEInvoiceDocumentValidation);
var
  D: TLandrixEInvoiceDiagnostics;
  I: TLandrixEInvoiceListIndex;
  Failure: Boolean;
  Target: TLandrixEInvoiceTarget;
  J: Integer;
  Reported: TStringList;
begin
  Reported := TStringList.Create;
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    Failure := False;
    Target := ADoc.Info.Spec.Target;
    if not ADoc.Info.SpecFound then
    begin
      Target.Standard := est_None;
      Target.Syntax := ADoc.Info.Syntax;
    end;
    { what the rule check reported is not repeated
      DE: was die Regelpruefung gemeldet hat, wird nicht wiederholt }
    for J := 0 to AResult.FindingCount - 1 do
      if (AResult[J].Part = evp_ModelCheck) and (AResult[J].RuleID <> '') then
        Reported.Add(string(AResult[J].RuleID));
    try
      Advise(ADoc.Invoice, Target, Reported, D);
    except
      on E: Exception do
      begin
        if E is EOutOfMemory then
          raise;
        for I := 0 to D.Count - 1 do
          AResult.AddDiagnosticFinding(evp_Advisory, D[I]);
        AResult.AddFailure(evp_Advisory, E);
        Failure := True;
      end;
    end;
    if not Failure then
    begin
      for I := 0 to D.Count - 1 do
        AResult.AddDiagnosticFinding(evp_Advisory, D[I]);
      AResult.FStatus[evp_Advisory] := evr_Passed;
    end;
  finally
    D.Free;
    Reported.Free;
  end;
end;

procedure TLandrixEInvoiceDocumentValidator.Advise(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  AReported: TStrings; ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  LandrixEInvoiceAdvise(AInvoice, ATarget, FOptions.Advisory, ADiagnostics, AReported);
end;

end.
