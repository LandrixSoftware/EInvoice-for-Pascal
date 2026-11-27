{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The content streams of a PDF read as the PDF/A-3b checks (ISO 19005-3,
  6.1.6, 6.1.10, 6.1.13 and 6.8) need them, the way veraPDF reads them:
  - the streams that are reached: the /Contents of every page (an array is
    one stream, a CR between its parts), form XObjects called with Do,
    tiling patterns selected with scn or SCN, all glyph procedures of a
    Type 3 font that shows text, and the normal, down and rollover
    appearances of every annotation of a page; resources are looked up in
    the stream's own resources and then in those of the page; a stream
    object is validated once, wherever veraPDF meets it first;
  - the operands an operator passes on to the checks (veraPDF checks only
    these, e.g. w checks its last operand only), the q nesting depth, the
    filters of inline images, file specifications inside inline
    dictionaries and the files that /AF /Name BDC associates;
  - what makes veraPDF see nothing: an unknown filter or DCTDecode gives no
    data, a syntax error inside an array or dictionary drops the whole
    stream, a stray ] ends it.
  A stream veraPDF might read differently (damaged or tolerated Flate data,
  other filters, encryption, a value too close to a limit, a stream reached
  in several ways with different results) makes the affected checks
  uncertain instead of failing them.

  DE: Die Content-Streams eines PDF, gelesen wie es die PDF/A-3b-Pruefungen
  (ISO 19005-3, 6.1.6, 6.1.10, 6.1.13 und 6.8) brauchen, so wie veraPDF sie
  liest:
  - die Streams, die erreicht werden: die /Contents jeder Seite (ein Array
    ist ein Stream, ein CR zwischen seinen Teilen), Form-XObjects, die Do
    aufruft, Kachelmuster, die scn oder SCN waehlt, alle Glyphenprozeduren
    einer Type-3-Schrift, die Text zeigt, und die normale, gedrueckte und
    Rollover-Erscheinung jeder Annotation einer Seite; Ressourcen werden in
    den eigenen Ressourcen des Streams und dann in denen der Seite gesucht;
    ein Stream-Objekt wird einmal geprueft, wo veraPDF es zuerst trifft;
  - die Operanden, die ein Operator an die Pruefungen weitergibt (veraPDF
    prueft nur diese, z. B. prueft w nur seinen letzten Operanden), die
    Schachtelungstiefe von q, die Filter von Inline-Bildern,
    Dateispezifikationen in Inline-Dictionaries und die Dateien, die /AF
    /Name BDC zuordnet;
  - was veraPDF nichts sehen laesst: ein unbekannter Filter oder DCTDecode
    liefert keine Daten, ein Syntaxfehler in einem Array oder Dictionary
    verwirft den ganzen Stream, ein einzelnes ] beendet ihn.
  Ein Stream, den veraPDF anders lesen koennte (beschaedigte oder nur
  nachsichtig lesbare Flate-Daten, andere Filter, Verschluesselung, ein Wert
  zu nah an einer Grenze, ein Stream, der auf mehreren Wegen mit
  verschiedenem Ergebnis erreicht wird), macht die betroffenen Pruefungen
  unsicher, statt sie scheitern zu lassen. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoicePdfContent;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  Contnrs,
  LandrixEInvoicePdfObjects;

type
  { What a finding in a content stream is about: an integer, a real number
    out of range or too close to zero, a string too long, a hexadecimal
    string with an odd number of characters or with other characters than
    hex digits, a name too long, an inline image filter that is not
    allowed, q nested too deep, a file specification with /EF but without
    /F and /UF strings, without /AFRelationship, or direct (never
    associated); an operator ISO 32000-1 does not define; an ExtGState with
    /TR, with /TR2 other than /Default, with /HTP; a halftone of another
    type than 1 or 5, with /HalftoneName, with a /TransferFunction where
    none may be or without one where one must be; a rendering intent
    outside the four of ISO 32000-1; an image with /Alternates, with /OPI,
    with /Interpolate true, with BitsPerComponent other than 1, 2, 4, 8 or
    16; an image mask with BitsPerComponent other than 1; a form XObject
    with /OPI, /PS or /Subtype2 /PS; a reference XObject; a PostScript
    XObject; a blend mode outside ISO 32000-1; a DeviceGray, DeviceRGB or
    DeviceCMYK colour space veraPDF links (whether that breaks a rule
    depends on the output intent); an ICC input profile of a class, colour
    space or version not allowed; a DeviceN colour space with more than 32
    colourants, or with a colourant that is neither in /Colorants nor a
    process component; an ICCBased CMYK space painted with overprint on and
    an overprint mode other than 0; two Separation spaces of one colourant
    name with different alternate spaces or tint transforms; a content
    stream that takes a named resource from the page's resources instead of
    its own (or the content of a page that inherits its resources); a page
    that contains transparency and has no /Group with /CS (whether that
    breaks 6.2.10-2 depends on the output intent); JPEG 2000 data of an
    image with other than 1, 3 or 4 colour channels, without a single colour
    specification (or one with APPROX 1), with a METH other than 1 to 3, with
    the enumerated colour space 19 (the last three only without /ColorSpace),
    with a bpcc box or a bit depth outside 1 to 38; a font a text operator
    shows (or the descendant CIDFont of a Type 0 font) without /Type /Font,
    with a descendant /Subtype other than CIDFontType0 and CIDFontType2,
    without a /BaseFont name (except Type 3), with a font program /Subtype
    other than Type1C, CIDFontType0C and OpenType; a simple font (unless a
    standard one without a program) without /FirstChar, /LastChar or a
    /Widths array of LastChar - FirstChar + 1 entries; a Type 0 font whose
    CMap is no Identity CMap and does not match the CIDSystemInfo of its
    CIDFont, a CIDFontType2 with a font program but without /CIDToGIDMap, a
    CMap (or one named by /UseCMap) neither predefined nor embedded; a font
    that is not embedded (except Type 3 and Type 0, and text rendering mode
    3); a non-symbolic TrueType font without MacRomanEncoding or
    WinAnsiEncoding (or with /Differences veraPDF does not accept), a
    symbolic one with an encoding; the TrueType program of a non-symbolic
    font without a cmap subtable other than (3,0), of a symbolic one with
    several subtables but no (3,0); a glyph shown that the font program
    lacks, whose widths in the dictionary and the program differ by more
    than 1 (both certain only for a font shown in one parse under one
    resource name), or that is .notdef.
    DE: Worum es bei einem Befund in einem Content-Stream geht: eine ganze
    Zahl, eine reelle Zahl ausserhalb des Bereichs oder zu nah an null, ein
    zu langer String, ein hexadezimaler String mit ungerader Zeichenzahl
    oder mit anderen Zeichen als Hex-Ziffern, ein zu langer Name, ein nicht
    erlaubter Filter eines Inline-Bilds, q zu tief verschachtelt, eine
    Dateispezifikation mit /EF ohne /F- und /UF-Strings, ohne
    /AFRelationship oder direkt (nie zugeordnet); ein Operator, den ISO
    32000-1 nicht definiert; ein ExtGState mit /TR, mit /TR2 ungleich
    /Default, mit /HTP; ein Halftone eines anderen Typs als 1 oder 5, mit
    /HalftoneName, mit /TransferFunction, wo keine sein darf, oder ohne,
    wo eine sein muss; ein Rendering-Intent ausserhalb der vier aus ISO
    32000-1; ein Bild mit /Alternates, mit /OPI, mit /Interpolate true, mit
    BitsPerComponent ungleich 1, 2, 4, 8 oder 16; eine Bildmaske mit
    BitsPerComponent ungleich 1; ein Form-XObject mit /OPI, /PS oder
    /Subtype2 /PS; ein Referenz-XObject; ein PostScript-XObject; ein
    Blend-Mode ausserhalb von ISO 32000-1; ein Farbraum DeviceGray,
    DeviceRGB oder DeviceCMYK, den veraPDF verknuepft (ob das eine Regel
    verletzt, haengt vom Output-Intent ab); ein ICC-Eingangsprofil mit nicht
    erlaubter Klasse, Farbraum oder Version; ein DeviceN-Farbraum mit mehr
    als 32 Farbmitteln oder mit einem Farbmittel, das weder in /Colorants
    noch eine Prozesskomponente ist; ein ICCBased-CMYK-Raum, mit dem bei
    eingeschaltetem Ueberdrucken und einem Ueberdruckmodus ungleich 0 gemalt
    wird; zwei Separation-Raeume eines Farbmittelnamens mit verschiedenen
    Alternativraeumen oder Tint-Funktionen; ein Content-Stream, der eine
    benannte Ressource aus den Ressourcen der Seite statt aus seinen eigenen
    nimmt (oder der Inhalt einer Seite, die ihre Ressourcen erbt); eine
    Seite, die Transparenz enthaelt und keine /Group mit /CS hat (ob das
    6.2.10-2 verletzt, haengt vom Output-Intent ab); JPEG-2000-Daten eines
    Bilds mit anderen als 1, 3 oder 4 Farbkanaelen, ohne eine einzige
    Farbspezifikation (oder eine mit APPROX 1), mit einer METH ausser 1 bis
    3, mit dem aufgezaehlten Farbraum 19 (die letzten drei nur ohne
    /ColorSpace), mit einer bpcc-Box oder einer Bittiefe ausserhalb 1 bis
    38; eine Schrift, die ein Textoperator zeigt (oder die CIDFont unter
    einer Type-0-Schrift), ohne /Type /Font, mit einem /Subtype der CIDFont
    ausser CIDFontType0 und CIDFontType2, ohne /BaseFont-Namen (ausser Type
    3), mit einem /Subtype des Fontprogramms ausser Type1C, CIDFontType0C
    und OpenType; eine einfache Schrift (ausser einer Standardschrift ohne
    Programm) ohne /FirstChar, /LastChar oder ein /Widths-Array mit
    LastChar - FirstChar + 1 Eintraegen; eine Type-0-Schrift, deren CMap
    keine Identity-CMap ist und nicht zum CIDSystemInfo ihrer CIDFont
    passt, eine CIDFontType2 mit Fontprogramm, aber ohne /CIDToGIDMap, eine
    CMap (oder eine ueber /UseCMap genannte), die weder vordefiniert noch
    eingebettet ist; eine nicht eingebettete Schrift (ausser Type 3 und Type
    0 und Darstellungsmodus 3); eine nicht symbolische TrueType-Schrift ohne
    MacRomanEncoding oder WinAnsiEncoding (oder mit /Differences, die
    veraPDF nicht annimmt), eine symbolische mit einer Kodierung; das
    TrueType-Programm einer nicht symbolischen Schrift ohne eine
    cmap-Subtabelle ausser (3,0), einer symbolischen mit mehreren
    Subtabellen, aber ohne (3,0); eine gezeigte Glyphe, die dem
    Fontprogramm fehlt, deren Breiten im Dictionary und im Programm um mehr
    als 1 abweichen (beides sicher nur fuer eine Schrift, die in einer Parse
    unter einem Ressourcennamen gezeigt wird), oder die .notdef ist. }
  TLandrixEInvoicePdfContentCheck = (pcc_Integer, pcc_Real, pcc_SmallReal, pcc_StringLength, pcc_HexOdd,
    pcc_HexDigits, pcc_NameLength, pcc_InlineFilter, pcc_Nesting, pcc_SpecNames, pcc_SpecRelationship,
    pcc_SpecDirect, pcc_Undefined, pcc_TR, pcc_TR2, pcc_HTP, pcc_HalftoneType, pcc_HalftoneName,
    pcc_HalftoneTransfer, pcc_Intent, pcc_ImageAlternates, pcc_ImageOPI, pcc_Interpolate, pcc_ImageBits,
    pcc_MaskBits, pcc_FormPS, pcc_FormRef, pcc_PSXObject, pcc_BlendMode, pcc_DeviceGray, pcc_DeviceRGB,
    pcc_DeviceCMYK, pcc_IccInput, pcc_DeviceNComponents, pcc_DeviceNColorants, pcc_Overprint,
    pcc_SeparationConsistency, pcc_Inherited, pcc_PageTransparency, pcc_JpxChannels, pcc_JpxSpecs, pcc_JpxMethod,
    pcc_JpxEnum, pcc_JpxDepth, pcc_FontType, pcc_FontSubtype, pcc_FontName, pcc_FirstChar, pcc_LastChar,
    pcc_Widths, pcc_FontFileSubtype, pcc_CidSystemInfo, pcc_CidToGid, pcc_CMapName, pcc_UseCMapName, pcc_FontEmbedded,
    pcc_TrueTypeEncoding, pcc_TrueTypeSymbolic, pcc_TrueTypeCmaps, pcc_SymbolicCmaps, pcc_GlyphPresent,
    pcc_GlyphWidth, pcc_GlyphNotdef);

  { A finding that veraPDF certainly reports: the content stream object
    (for the /Contents array of a page its first stream) and a short text.
    DE: Ein Befund, den veraPDF sicher meldet: das Content-Stream-Objekt
    (beim /Contents-Array einer Seite sein erster Stream) und ein kurzer
    Text. }
  TLandrixEInvoicePdfContentFinding = record
    Check: TLandrixEInvoicePdfContentCheck;
    ObjNum: Integer;
    ObjGen: Integer;
    Detail: string;
  end;

  { Walks the content streams of a document once (Run) and keeps what the
    checks need.
    DE: Durchlaeuft die Content-Streams eines Dokuments einmal (Run) und
    behaelt, was die Pruefungen brauchen. }
  TLandrixEInvoicePdfContentWalk = class(TObject)
  private
    FDoc: TLandrixEInvoicePdfDocument;
    FParses: TObjectList;
    FMemo: TStringList;
    FActive: TStringList;
    FType3Seen: TStringList;
    FReachDepth: Integer;
    FTotalBytes: Int64;
    FPageNodes: Integer;
    FPageCount: Integer;
    { values alive in all lexers of the walk (nested parses included) }
    FLive: Integer;
    FIncomplete: Boolean;
    FMaxReal: Double;
    FMinReal: Double;
    FMaxDouble: Double;
    FTiny: Double;
    { 2^31 }
    FTwo31: Double;
    FNearHigh: Double;
    FNearHighTop: Double;
    FNearLow: Double;
    FNearLowTop: Double;
    { all findings of all parses: parse index, check, maybe, text }
    FFParse: array of Integer;
    FFCheck: array of TLandrixEInvoicePdfContentCheck;
    FFMaybe: array of Boolean;
    FFDetail: array of string;
    FFCount: Integer;
    { the result }
    FFindings: array of TLandrixEInvoicePdfContentFinding;
    FFindingCount: Integer;
    FUncertain: array[TLandrixEInvoicePdfContentCheck] of Boolean;
    FAssocSure: array of Boolean;
    FAssocMaybe: array of Boolean;
    { some stream could not be read with certainty: what it reaches and
      associates is unknown }
    FAnyUncertain: Boolean;
    FAssocAll: Boolean;
    { the pages veraPDF sees may differ: no finding is certain }
    FPagesUnsure: Boolean;
    FLimitHit: Boolean;
    { findings outside any parse (the form dictionaries of annotation
      appearances): check, object, text }
    FRCheck: array of TLandrixEInvoicePdfContentCheck;
    FRNum: array of Integer;
    FRDetail: array of string;
    FRCount: Integer;
    { per object, the colorant classes a halftone may be visited in
      anywhere in the file (bits HtPrimary, HtDefault, HtOther) }
    FHtCtx: array of Byte;
    FHtBuilt: Boolean;
    FHtBroken: Boolean;
    { veraPDF throws while validating: it reports nothing (FThrows also at a
      scan limit of this walk; FMayThrow only where veraPDF itself throws) }
    FThrows: Boolean;
    FMayThrow: Boolean;
    { ICC profile headers read so far, by object }
    FIccCache: TStringList;
    { a 3D annotation: veraPDF reaches colour spaces through its 3D stream
      first, which is not modelled }
    FColourUnsure: Boolean;
    { nested colour spaces looked into (a budget against hostile nesting) }
    FCsSteps: Integer;
    { a colour space was not followed somewhere: veraPDF may meet a shared
      one there first, so findings on shared objects are not certain }
    FSharedUnsure: Boolean;
    { the Separation spaces linked anywhere (TSepSig), by key; the work of
      comparing them; a comparison not decided for another reason }
    FSeps: TObjectList;
    FSepKeys: TStringList;
    FSepWork: Int64;
    FSepUnsure: Boolean;
    { a paint with an overprint mode not decided: it may share the identity
      of any CMYK ICC link, so no profile reached as one is certain }
    FOpmUnsure: Boolean;
    { a resource lookup of veraPDF that is not
      decided here (an image's named colour space, the initial gray of a
      page that inherits a /DeviceGray entry, an odd /Resources entry):
      6.2.2-2 is not certain }
    FInheritUnsure: Boolean;
    { 6.2.10-2 per page walk: the page object (ObjId), its number and the
      level (0 passes, 1 not decided, 2 transparency without a group colour
      space) }
    FPageTpKey: TStringList;
    { the JPEG 2000 facts of image streams, by object (TJpxEntry) }
    FJpxCache: TStringList;
    { font facts by font object (TFontFacts) }
    FFontCache: TStringList;
    { TrueType programs by stream object (nil: the data not decided) }
    FTrueTypeCache: TStringList;
    { certain font findings (index into FF*) and their font facts }
    FEmbIdx: array of Integer;
    FEmbFont: array of TObject;
    FEmbCount: Integer;
    { the active streams changed (a stamp for TContentParse.ReachGen); a
      parse failed with an exception somewhere (veraPDF then keeps streams on
      its stack of streams being read, which reads later uses as empty) }
    FActiveGen: Integer;
    FVisitGen: Integer;
    FAnyParseFailed: Boolean;
    FPageTpNum: array of Integer;
    FPageTpLevel: array of Integer;
    { the number of the page object being walked (-1 direct) }
    FCurPageNum: Integer;
    { the decoding budget (MaxTotalBytes) ran out: nothing more is decoded }
    FBudgetSpent: Boolean;
    { Type3 glyph sets already replayed into a parse (key and parse) }
    FType3Replayed: TStringList;
    { page objects walked with their inherited resources }
    FWalkedPages: TStringList;
    { the stream list and key of a contents array object, by object }
    FPartsCache: TStringList;
    { sorted key indexes of large dictionaries, by object }
    FDictIndex: TStringList;
    function ObjId(AObj: TLandrixEInvoicePdfObject): string;
    function DictGet(ADict: TLandrixEInvoicePdfObject; const AKey: AnsiString): TLandrixEInvoicePdfObject;
    function ResolveRef(ARaw: TLandrixEInvoicePdfObject): TLandrixEInvoicePdfObject;
    function DGetRef(AObj: TLandrixEInvoicePdfObject; const AKey: AnsiString): TLandrixEInvoicePdfObject;
    function LastRefNum(ARaw: TLandrixEInvoicePdfObject): Integer;
    function StreamBytes(AStream: TLandrixEInvoicePdfObject; out AData: TLandrixEInvoicePdfBytes): Boolean;
    function WalkPages(ANode, AInherited: TLandrixEInvoicePdfObject; ADepth: Integer): Integer;
    procedure WalkPage(APage, AInherited: TLandrixEInvoicePdfObject);
    procedure Finish;
    procedure SeparationThrows;
    function ParseTransp(AIndex: Integer): Integer;
    procedure FinishPageTransparency;
    function ReachesActive(AIndex: Integer): Boolean;
    procedure FinishSeparations(var AGroupStart, AMembers: array of Integer; var AReach: array of Boolean;
      ANG: Integer);
    procedure ScanTiling;
    procedure ScanAlternates;
    procedure FinishFonts;
    procedure AddFontMark(AIndex: Integer; AFacts: TObject);
    procedure AddRootFinding(ACheck: TLandrixEInvoicePdfContentCheck; ANum: Integer; const ADetail: string);
    procedure CheckAppearanceForm(V, ARaw: TLandrixEInvoicePdfObject);
    procedure BuildHalftoneContexts;
    function HalftonePassesElsewhere(ANum: Integer; ATransferNull: Boolean): Boolean;
  public
    constructor Create(ADoc: TLandrixEInvoicePdfDocument);
    destructor Destroy; override;
    { Walks every page of the document. DE: Durchlaeuft jede Seite des
      Dokuments. }
    procedure Run;
    { The findings veraPDF certainly reports. DE: Die Befunde, die veraPDF
      sicher meldet. }
    function FindingCount: Integer;
    function Finding(AIndex: Integer): TLandrixEInvoicePdfContentFinding;
    { A check may have findings that are not certain (or content that could
      not be read the way veraPDF reads it): the rule stays undecided where
      no certain finding exists.
      DE: Eine Pruefung kann Befunde haben, die nicht sicher sind (oder
      Inhalt, der sich nicht so lesen liess, wie veraPDF ihn liest): die
      Regel bleibt offen, wo kein sicherer Befund existiert. }
    function Uncertain(ACheck: TLandrixEInvoicePdfContentCheck): Boolean;
    { Object ANum is certainly associated by /AF /Name BDC in a content
      stream veraPDF reads; or it may be.
      DE: Objekt ANum wird sicher durch /AF /Name BDC in einem Content-Stream
      zugeordnet, den veraPDF liest; oder es kann sein. }
    function AssociatedSure(ANum: Integer): Boolean;
    function AssociatedMaybe(ANum: Integer): Boolean;
    { veraPDF may stop with an exception on this document (it then reports
      no rule at all).
      DE: veraPDF kann bei diesem Dokument mit einer Ausnahme abbrechen (es
      meldet dann gar keine Regel). }
    function Throws: Boolean;
  end;

  { The header fields of an ICC profile stream as veraPDF reads them for
    6.2.3 and 6.2.4.2: one read of at most 128 decoded bytes. Known is False
    when the bytes veraPDF reads are not certain (a filter other than
    FlateDecode, decode parameters, a /Length that is no integer, an
    external file, an encrypted document, zlib data that is not intact, an
    unfiltered profile of fewer than 20 bytes); the other fields are then
    empty. Count is the number of bytes read. DeviceClass (bytes 12 to 15)
    and ColorSpace (bytes 16 to 19) are empty when the bytes are missing or
    all zero; Major (byte 8) is -1 when fewer than 10 bytes were read.
    DE: Die Kopffelder eines ICC-Profil-Streams, wie veraPDF sie fuer 6.2.3
    und 6.2.4.2 liest: ein Lesevorgang von hoechstens 128 dekodierten Bytes.
    Known ist False, wenn die Bytes, die veraPDF liest, nicht sicher sind
    (ein anderer Filter als FlateDecode, Dekodierparameter, eine /Length,
    die keine ganze Zahl ist, eine externe Datei, ein verschluesseltes
    Dokument, zlib-Daten, die nicht intakt sind, ein ungefiltertes Profil
    unter 20 Bytes); die uebrigen Felder sind dann leer. Count ist die Zahl der
    gelesenen Bytes.
    DeviceClass (Bytes 12 bis 15) und ColorSpace (Bytes 16 bis 19) sind
    leer, wenn die Bytes fehlen oder alle null sind; Major (Byte 8) ist -1,
    wenn weniger als 10 Bytes gelesen wurden. }
  TLandrixEInvoicePdfIccHeader = record
    Known: Boolean;
    Count: Integer;
    DeviceClass: AnsiString;
    ColorSpace: AnsiString;
    Major: Integer;
  end;

{ Follows the reference ARaw as veraPDF does: to the object in use with that
  number and generation, nil (null) otherwise; a direct object as it is.
  After 32 references AUnsure becomes True and the result is nil (veraPDF
  may follow further).
  DE: Folgt der Referenz ARaw wie veraPDF: zum benutzten Objekt mit dieser
  Nummer und Generation, sonst nil (null); ein direktes Objekt unveraendert.
  Nach 32 Referenzen wird AUnsure True und das Ergebnis nil (veraPDF folgt
  womoeglich weiter). }
function LandrixEInvoicePdfResolveRef(ADoc: TLandrixEInvoicePdfDocument; ARaw: TLandrixEInvoicePdfObject;
  var AUnsure: Boolean): TLandrixEInvoicePdfObject;

{ Reads the header of the ICC profile stream AStream.
  DE: Liest den Kopf des ICC-Profil-Streams AStream. }
function LandrixEInvoicePdfIccHeader(ADoc: TLandrixEInvoicePdfDocument;
  AStream: TLandrixEInvoicePdfObject): TLandrixEInvoicePdfIccHeader;

implementation

uses
  SysUtils, LandrixEInvoicePdfFontProgram, LandrixEInvoicePdfTrueType, LandrixEInvoicePdfFontGlyphs;

const
  { q may nest 28 levels deep (ISO 19005-2, 6.1.13) }
  MaxNesting = 28;
  { limits of the walk; beyond them every check is uncertain }
  MaxReachDepth = 48;
  MaxParses = 20000;
  MaxTotalBytes = 256 * 1024 * 1024;
  MaxParts = 10000;
  { tokens of one stream (nested values included), values alive at once in
    all streams being parsed (the operands waiting for an operator and their
    items), operands waiting for an operator }
  MaxTokens = 50000000;
  MaxLive = 500000;
  MaxPending = 1000000;
  MaxCompoundDepth = 200;
  MaxPageDepth = 64;
  MaxPageNodes = 200000;
  { keys of one dictionary operand (BDC, DP, an inline image); beyond, the
    stream is not decided (the key search would grow quadratic) }
  MaxDictKeys = 100;
  { q levels kept; deeper ones are only counted (a Q back from there makes
    the parse uncertain) }
  MaxStack = 1000;
  { dictionaries with more keys than this get a sorted key index }
  DictIndexFrom = 16;
  { veraPDF looks one token ahead after EI and reads it back from a buffer
    of 2048 bytes that keeps at least 1024 bytes behind its position }
  MaxLookahead = 1000;
  { findings kept per parse and check (the level counts all of them) }
  MaxFindingsPerCheck = 20;

  { what an operator passes on (see TInterpreter.Operate) }
  oc_None = 0;
  oc_Number = 1;
  oc_Integer = 2;
  oc_Dash = 3;
  oc_Intent = 4;
  oc_Push = 5;
  oc_Pop = 6;
  oc_NumberList = 7;
  oc_Glyph = 8;
  oc_TwoNumbers = 9;
  oc_Font = 10;
  oc_Show = 11;
  oc_ShowSpaced = 12;
  oc_ShowArray = 13;
  oc_Color = 14;
  oc_SpaceStroke = 15;
  oc_SpaceFill = 16;
  oc_ColorNStroke = 17;
  oc_ColorNFill = 18;
  oc_DeviceStroke = 19;
  oc_DeviceFill = 20;
  oc_Shading = 21;
  oc_Do = 22;
  oc_Tag = 23;
  oc_TagProps = 24;
  oc_TagPropsBegin = 25;
  oc_Inline = 26;
  oc_Other = 27;
  oc_ExtGState = 28;
  oc_PaintFill = 29;
  oc_PaintStroke = 30;
  oc_PaintBoth = 31;
  oc_TextMode = 32;

  OpCount = 71;
  OpNames: array[0..OpCount - 1] of AnsiString = (
    'w', 'M', 'i', 'Tc', 'Tw', 'Tz', 'TL', 'Ts',
    'J', 'j',
    'd',
    'ri',
    'q', 'Q',
    'cm', 'm', 'l', 'c', 'v', 'y', 're', 'Tm',
    'd1',
    'Td', 'TD', 'd0',
    'Tf',
    'Tj', '''',
    '"',
    'TJ',
    'SC', 'sc',
    'CS', 'cs',
    'SCN', 'scn',
    'G', 'RG', 'K', 'g', 'rg', 'k',
    'sh',
    'Do',
    'MP', 'BMC',
    'DP', 'BDC',
    'BI',
    'gs', 'Tr', 'h', 'W', 'W*', 'n', 'S', 's', 'f', 'F', 'f*', 'B', 'B*', 'b', 'b*', 'BT', 'ET', 'T*', 'EMC',
    'BX', 'EX');
  OpCodes: array[0..OpCount - 1] of Integer = (
    oc_Number, oc_Number, oc_Number, oc_Number, oc_Number, oc_Number, oc_Number, oc_Number,
    oc_Integer, oc_Integer,
    oc_Dash,
    oc_Intent,
    oc_Push, oc_Pop,
    oc_NumberList, oc_NumberList, oc_NumberList, oc_NumberList, oc_NumberList, oc_NumberList, oc_NumberList,
    oc_NumberList,
    oc_Glyph,
    oc_TwoNumbers, oc_TwoNumbers, oc_TwoNumbers,
    oc_Font,
    oc_Show, oc_Show,
    oc_ShowSpaced,
    oc_ShowArray,
    oc_Color, oc_Color,
    oc_SpaceStroke, oc_SpaceFill,
    oc_ColorNStroke, oc_ColorNFill,
    oc_DeviceStroke, oc_DeviceStroke, oc_DeviceStroke, oc_DeviceFill, oc_DeviceFill, oc_DeviceFill,
    oc_Shading,
    oc_Do,
    oc_Tag, oc_Tag,
    oc_TagProps, oc_TagPropsBegin,
    oc_Inline,
    oc_ExtGState, oc_TextMode, oc_Other, oc_Other, oc_Other, oc_Other, oc_PaintStroke, oc_PaintStroke, oc_PaintFill,
    oc_PaintFill, oc_PaintFill, oc_PaintBoth, oc_PaintBoth, oc_PaintBoth, oc_PaintBoth, oc_Other, oc_Other, oc_Other,
    oc_Other, oc_Other, oc_Other);

  { the rendering intents of ISO 32000-1, Table 70 (6.2.6-1). DE: die
    Rendering-Intents aus ISO 32000-1, Tabelle 70 (6.2.6-1). }
  RenderingIntents: array[0..3] of AnsiString = ('RelativeColorimetric', 'AbsoluteColorimetric', 'Perceptual',
    'Saturation');
  { the blend modes of ISO 32000-1, 11.3.5 (6.2.10-1). DE: die Blend-Modes
    aus ISO 32000-1, 11.3.5 (6.2.10-1). }
  BlendModes: array[0..16] of AnsiString = ('Normal', 'Compatible', 'Multiply', 'Screen', 'Overlay', 'Darken',
    'Lighten', 'ColorDodge', 'ColorBurn', 'HardLight', 'SoftLight', 'Difference', 'Exclusion', 'Hue', 'Saturation',
    'Color', 'Luminosity');
  { the colorant classes of a halftone for 6.2.5-6: top level or a primary
    colorant (no transfer function), Default (any), another colorant (a
    transfer function). DE: die Farbmittelklassen eines Halftones fuer
    6.2.5-6: oberste Ebene oder ein Primaerfarbmittel (keine
    Transferfunktion), Default (beliebig), ein anderes Farbmittel (eine
    Transferfunktion). }
  HtPrimary = 1;
  HtDefault = 2;
  HtOther = 4;
  MaxHalftoneDepth = 32;
  MaxImageDepth = 32;
  { the kinds of image veraPDF builds: an image, the /Mask stream of one
    (an image mask), the /SMask stream of one }
  ik_Image = 0;
  ik_Mask = 1;
  ik_SMask = 2;

  { the filters 6.1.10-1 allows for inline images }
  InlineFilters: array[0..11] of AnsiString = ('ASCIIHexDecode', 'ASCII85Decode', 'FlateDecode', 'RunLengthDecode',
    'CCITTFaxDecode', 'DCTDecode', 'AHx', 'A85', 'Fl', 'RL', 'CCF', 'DCT');
  { stream filters veraPDF may decode; any other name (also the abbreviation
    Fl, which veraPDF does not register for streams) gives no data }
  KnownFilters: array[0..15] of AnsiString = ('ASCIIHexDecode', 'AHx', 'ASCII85Decode', 'A85', 'LZWDecode', 'LZW',
    'FlateDecode', 'RunLengthDecode', 'RL', 'CCITTFaxDecode', 'CCF', 'JBIG2Decode', 'DCTDecode', 'DCT',
    'JPXDecode', 'Crypt');

function OpCode(const AName: AnsiString): Integer;
var
  I: Integer;
begin
  for I := 0 to OpCount - 1 do
    if OpNames[I] = AName then
    begin
      Result := OpCodes[I];
      Exit;
    end;
  Result := oc_None;
end;

function InList(const AName: AnsiString; const AList: array of AnsiString): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to Integer(High(AList)) do
    if AList[I] = AName then
      Exit;
  Result := False;
end;

function IsWhite(B: Byte): Boolean;
begin
  Result := (B = 0) or (B = 9) or (B = 10) or (B = 12) or (B = 13) or (B = 32);
end;

function IsDelim(B: Byte): Boolean;
begin
  Result := (B = Ord('(')) or (B = Ord(')')) or (B = Ord('<')) or (B = Ord('>')) or (B = Ord('[')) or
    (B = Ord(']')) or (B = Ord('{')) or (B = Ord('}')) or (B = Ord('/')) or (B = Ord('%'));
end;

function IsRegular(B: Byte): Boolean;
begin
  Result := not IsWhite(B) and not IsDelim(B);
end;

function IsNumberStart(B: Byte): Boolean;
begin
  Result := ((B >= Ord('0')) and (B <= Ord('9'))) or (B = Ord('+')) or (B = Ord('-')) or (B = Ord('.'));
end;

function HexDigit(B: Byte): Integer;
begin
  if (B >= Ord('0')) and (B <= Ord('9')) then
    Result := B - Ord('0')
  else if (B >= Ord('a')) and (B <= Ord('f')) then
    Result := B - Ord('a') + 10
  else if (B >= Ord('A')) and (B <= Ord('F')) then
    Result := B - Ord('A') + 10
  else
    Result := -1;
end;

{ ASCII bytes as a string, byte by byte. }
function AsciiOf(const A: AnsiString): string;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(A));
  for I := 1 to Length(A) do
    Result[I] := Char(A[I]);
end;

function HasByte(const A: AnsiString; C: AnsiChar): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(A) do
    if A[I] = C then
    begin
      Result := True;
      Exit;
    end;
end;

function TextOf(const AName: AnsiString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AName) do
  begin
    { only the first 40 characters are shown }
    if Length(Result) > 40 then
      Break;
    if (Ord(AName[I]) >= 32) and (Ord(AName[I]) < 127) then
      Result := Result + Char(AName[I])
    else
      Result := Result + '#' + IntToHex(Ord(AName[I]), 2);
  end;
  if Length(Result) > 40 then
    Result := Copy(Result, 1, 40) + '...';
end;

function FloatOf(const AText: string): Double;
var
  Code: Integer;
begin
  Val(AText, Result, Code);
  if Code <> 0 then
    Result := 0;
end;

//==============================================================================
// Values of a content stream
//==============================================================================

type
  TCvKind = (cvk_Int, cvk_Real, cvk_Bool, cvk_Null, cvk_Str, cvk_Name, cvk_Arr, cvk_Dict, cvk_Op);

  { A token of a content stream: an operand (number, string, name, array,
    dictionary) or an operator. }
  TCv = class(TObject)
  public
    Kind: TCvKind;
    IntVal: Int64;
    RealVal: Double;
    { the real number is too close to a limit to decide }
    RealNear: Boolean;
    { a name, a keyword }
    Text: AnsiString;
    { strings: the length range as veraPDF measures it, hex facts }
    LenLo: Integer;
    LenHi: Integer;
    Hex: Boolean;
    HexChars: Integer;
    HexInvalid: Boolean;
    { strings: the number of decoded bytes; the bytes that occur (CodesUnsure:
      an unescaped CR, which veraPDF may read as LF) }
    ByteLen: Integer;
    Data: TLandrixEInvoicePdfBytes;
    Codes: set of Byte;
    CodesUnsure: Boolean;
    { array items or dictionary values (owned by the pool) }
    Items: TObjectList;
    Keys: array of AnsiString;
    { BI: the image dictionary }
    ImageDict: TCv;
    constructor Create(AKind: TCvKind);
    destructor Destroy; override;
    function Get(const AKey: AnsiString): TCv;
    procedure Put(const AKey: AnsiString; AValue: TCv);
  end;

constructor TCv.Create(AKind: TCvKind);
begin
  inherited Create;
  Kind := AKind;
  if (AKind = cvk_Arr) or (AKind = cvk_Dict) then
    Items := TObjectList.Create(False);
end;

destructor TCv.Destroy;
begin
  Items.Free;
  inherited Destroy;
end;

function TCv.Get(const AKey: AnsiString): TCv;
var
  I: Integer;
begin
  Result := nil;
  if Kind <> cvk_Dict then
    Exit;
  for I := 0 to Integer(Length(Keys)) - 1 do
    if Keys[I] = AKey then
    begin
      Result := TCv(Items[I]);
      Exit;
    end;
end;

{ a later key replaces an earlier one, as in a map }
procedure TCv.Put(const AKey: AnsiString; AValue: TCv);
var
  I, K: Integer;
begin
  for I := 0 to Integer(Length(Keys)) - 1 do
    if Keys[I] = AKey then
    begin
      if AValue.Kind = cvk_Null then
      begin
        { a null value removes the key, as in veraPDF's dictionaries }
        for K := I to Integer(Length(Keys)) - 2 do
          Keys[K] := Keys[K + 1];
        SetLength(Keys, Length(Keys) - 1);
        Items.Delete(I);
      end
      else
        Items[I] := AValue;
      Exit;
    end;
  if AValue.Kind = cvk_Null then
    Exit;
  SetLength(Keys, Length(Keys) + 1);
  Keys[High(Keys)] := AKey;
  Items.Add(AValue);
end;

//==============================================================================
// Lexer
//==============================================================================

type
  { ok; failed: veraPDF throws and sees no operator of the stream; unknown:
    veraPDF might read it differently }
  TLexStatus = (lxs_Ok, lxs_Failed, lxs_Unknown);

  TLookahead = (lka_Accept, lka_Reject, lka_Unknown);

  { Splits a content stream into tokens as veraPDF's stream parser does, one
    token at a time (Next); Release frees the tokens read so far. }
  TContentLexer = class(TObject)
  private
    FBuf: TLandrixEInvoicePdfBytes;
    FLen: Integer;
    FPos: Integer;
    FPool: TObjectList;
    FStatus: TLexStatus;
    FWalk: TLandrixEInvoicePdfContentWalk;
    FPending: Integer;
    FCount: Integer;
    FDone: Boolean;
    function NewCv(AKind: TCvKind): TCv;
    function AtEnd: Boolean;
    procedure SkipWhite;
    function ReadKeyword: AnsiString;
    function ReadOperator: AnsiString;
    function ParseNumber: TCv;
    function ParseLiteral: TCv;
    function ParseHex: TCv;
    function ParseName: TCv;
    function ParseValue(ADepth: Integer): TCv;
    function ParseArray(ADepth: Integer): TCv;
    function ParseDict(ADepth: Integer): TCv;
    function ParseInline: TCv;
    function Lookahead(APos: Integer): TLookahead;
  public
    constructor Create(AWalk: TLandrixEInvoicePdfContentWalk; const ABuf: TLandrixEInvoicePdfBytes);
    destructor Destroy; override;
    { The next token, nil at the end (also after a stray ]) or when the
      status is no longer lxs_Ok. }
    function Next: TCv;
    procedure Release;
    property Status: TLexStatus read FStatus;
  end;

constructor TContentLexer.Create(AWalk: TLandrixEInvoicePdfContentWalk; const ABuf: TLandrixEInvoicePdfBytes);
begin
  inherited Create;
  FWalk := AWalk;
  FBuf := ABuf;
  FLen := Integer(Length(ABuf));
  FPool := TObjectList.Create(True);
  FStatus := lxs_Ok;
end;

destructor TContentLexer.Destroy;
begin
  Dec(FWalk.FLive, FPool.Count);
  FPool.Free;
  inherited Destroy;
end;

procedure TContentLexer.Release;
begin
  Dec(FWalk.FLive, FPool.Count);
  FPool.Clear;
end;

function TContentLexer.NewCv(AKind: TCvKind): TCv;
begin
  Result := TCv.Create(AKind);
  FPool.Add(Result);
  Inc(FCount);
  Inc(FWalk.FLive);
  if (FCount > MaxTokens) or (FWalk.FLive > MaxLive) then
    FStatus := lxs_Unknown;
end;

function TContentLexer.AtEnd: Boolean;
begin
  Result := FPos >= FLen;
end;

procedure TContentLexer.SkipWhite;
begin
  while FPos < FLen do
  begin
    if IsWhite(FBuf[FPos]) then
      Inc(FPos)
    else if FBuf[FPos] = Ord('%') then
    begin
      while (FPos < FLen) and (FBuf[FPos] <> 10) and (FBuf[FPos] <> 13) do
        Inc(FPos);
    end
    else
      Break;
  end;
end;

function TContentLexer.ReadKeyword: AnsiString;
var
  Start: Integer;
begin
  Start := FPos;
  while (FPos < FLen) and IsRegular(FBuf[FPos]) do
    Inc(FPos);
  Result := LandrixEInvoicePdfBytesToAnsi(FBuf, Start, FPos - Start);
end;

{ The end of an operator as veraPDF's stream parser reads it from APos: up
  to white space, [, ], <, (, / or a digit, where a 0 or 1 right after a d
  belongs to it (d0, d1, also d1q); other delimiters such as % or > belong
  to it. }
function OperatorEnd(const ABuf: TLandrixEInvoicePdfBytes; ALen, APos: Integer): Integer;
var
  B: Byte;
begin
  Result := APos + 1;
  while Result < ALen do
  begin
    B := ABuf[Result];
    if IsWhite(B) or (B = Ord('[')) or (B = Ord(']')) or (B = Ord('<')) or (B = Ord('(')) or (B = Ord('/')) then
      Break;
    if (B >= Ord('0')) and (B <= Ord('9')) then
    begin
      if ((B = Ord('0')) or (B = Ord('1'))) and (ABuf[Result - 1] = Ord('d')) then
      begin
        Inc(Result);
        Continue;
      end;
      Break;
    end;
    Inc(Result);
  end;
end;

{ A token starting with f, t, n or B goes another path in veraPDF: up to
  the next white space or delimiter (digits included); true, false and null
  are operands, BI starts an inline image, anything else is an operator. }
function KeywordEnd(const ABuf: TLandrixEInvoicePdfBytes; ALen, APos: Integer): Integer;
begin
  Result := APos + 1;
  while (Result < ALen) and IsRegular(ABuf[Result]) do
    Inc(Result);
end;

function IsKeywordStart(B: Byte): Boolean;
begin
  Result := (B = Ord('f')) or (B = Ord('t')) or (B = Ord('n')) or (B = Ord('B'));
end;

function TContentLexer.ReadOperator: AnsiString;
var
  Start: Integer;
begin
  Start := FPos;
  if IsKeywordStart(FBuf[FPos]) then
    FPos := KeywordEnd(FBuf, FLen, FPos)
  else
    FPos := OperatorEnd(FBuf, FLen, FPos);
  Result := LandrixEInvoicePdfBytesToAnsi(FBuf, Start, FPos - Start);
end;

function TContentLexer.ParseNumber: TCv;
var
  Neg, Valid: Boolean;
  Start, Dots, I, Dot, IntDigits, LeadZeros, Digit: Integer;
  Digits, IntPart, FracPart: AnsiString;
  V: Int64;
  D: Double;
  S: string;
  W: TLandrixEInvoicePdfContentWalk;
begin
  Neg := False;
  if FBuf[FPos] = Ord('-') then
  begin
    Neg := True;
    Inc(FPos);
  end
  else if FBuf[FPos] = Ord('+') then
    Inc(FPos);
  Start := FPos;
  Dots := 0;
  while (FPos < FLen) and (((FBuf[FPos] >= Ord('0')) and (FBuf[FPos] <= Ord('9'))) or (FBuf[FPos] = Ord('.'))) do
  begin
    if FBuf[FPos] = Ord('.') then
      Inc(Dots);
    Inc(FPos);
  end;
  Digits := LandrixEInvoicePdfBytesToAnsi(FBuf, Start, FPos - Start);
  if Dots = 0 then
  begin
    Result := NewCv(cvk_Int);
    Valid := Digits <> '';
    V := 0;
    I := 1;
    while Valid and (I <= Length(Digits)) do
    begin
      Digit := Ord(Digits[I]) - Ord('0');
      if V > (High(Int64) - Digit) div 10 then
        Valid := False
      else
        V := V * 10 + Digit;
      Inc(I);
    end;
    if not Valid then
      V := High(Int64);
    if Neg then
      V := -V;
    Result.IntVal := V;
    Exit;
  end;
  Result := NewCv(cvk_Real);
  W := FWalk;
  { one dot and at least one digit, else Double.MAX_VALUE }
  if (Dots <> 1) or (Length(Digits) < 2) then
  begin
    D := W.FMaxDouble;
    if Neg then
      D := -D;
    Result.RealVal := D;
    Exit;
  end;
  Dot := Pos('.', AsciiOf(Digits));
  IntPart := Copy(Digits, 1, Dot - 1);
  FracPart := Copy(Digits, Dot + 1, MaxInt);
  I := 1;
  while (I <= Length(IntPart)) and (IntPart[I] = '0') do
    Inc(I);
  IntPart := Copy(IntPart, I, MaxInt);
  IntDigits := Length(IntPart);
  LeadZeros := 0;
  while (LeadZeros < Length(FracPart)) and (FracPart[LeadZeros + 1] = '0') do
    Inc(LeadZeros);
  if IntDigits > 39 then
    D := W.FMaxDouble
  else if (IntDigits = 0) and (LeadZeros = Length(FracPart)) then
    D := 0
  else if (IntDigits = 0) and (LeadZeros > 320) then
  begin
    { may underflow to zero in binary64 }
    D := 0;
    Result.RealNear := True;
  end
  else if (IntDigits = 0) and (LeadZeros >= 39) then
    D := W.FTiny
  else
  begin
    { the significant digits, enough of them for binary64 }
    if IntDigits = 0 then
      S := '0.' + AsciiOf(Copy(FracPart, 1, LeadZeros + 60))
    else if FracPart = '' then
      S := AsciiOf(IntPart) + '.0'
    else
      S := AsciiOf(IntPart) + '.' + AsciiOf(Copy(FracPart, 1, 60));
    D := FloatOf(S);
  end;
  if (Abs(D) >= W.FNearHigh) and (Abs(D) <= W.FNearHighTop) then
    Result.RealNear := True;
  if (Abs(D) >= W.FNearLow) and (Abs(D) <= W.FNearLowTop) then
    Result.RealNear := True;
  if Neg then
    D := -D;
  Result.RealVal := D;
end;

function TContentLexer.ParseLiteral: TCv;
var
  Depth, Oct, K, CrLf, N, I: Integer;
  B: Byte;
  Bytes: TLandrixEInvoicePdfBytes;

  procedure Add(AByte: Byte);
  begin
    if N >= Length(Bytes) then
      SetLength(Bytes, 64 + 2 * N);
    Bytes[N] := AByte;
    Inc(N);
  end;

begin
  Result := NewCv(cvk_Str);
  Bytes := nil;
  N := 0;
  Inc(FPos);
  Depth := 1;
  CrLf := 0;
  while FPos < FLen do
  begin
    B := FBuf[FPos];
    Inc(FPos);
    if B = Ord('\') then
    begin
      if FPos >= FLen then
        Break;
      B := FBuf[FPos];
      Inc(FPos);
      case B of
        Ord('n'): B := 10;
        Ord('r'): B := 13;
        Ord('t'): B := 9;
        Ord('b'): B := 8;
        Ord('f'): B := 12;
        10: Continue;
        13:
          begin
            if (FPos < FLen) and (FBuf[FPos] = 10) then
              Inc(FPos);
            Continue;
          end;
        48..55:
          begin
            Oct := B - 48;
            K := 1;
            while (K < 3) and (FPos < FLen) and (FBuf[FPos] >= 48) and (FBuf[FPos] <= 55) do
            begin
              Oct := Oct * 8 + (FBuf[FPos] - 48);
              Inc(FPos);
              Inc(K);
            end;
            B := Byte(Oct and $FF);
          end;
      else
        { the character itself }
      end;
      Add(B);
      Continue;
    end;
    if (B = 13) and (FPos < FLen) and (FBuf[FPos] = 10) then
      Inc(CrLf);
    if B = 13 then
      Result.CodesUnsure := True;
    if B = Ord('(') then
      Inc(Depth)
    else if B = Ord(')') then
    begin
      Dec(Depth);
      if Depth = 0 then
        Break;
    end;
    Add(B);
  end;
  SetLength(Bytes, N);
  Result.ByteLen := N;
  Result.Data := Bytes;
  for I := 0 to N - 1 do
    Include(Result.Codes, Bytes[I]);
  LandrixEInvoicePdfStringLength(Bytes, CrLf, Result.LenLo, Result.LenHi);
end;

{ A hexadecimal string: every character other than white space counts
  (hex digit or not); one that is no hex digit adds nothing; a last single
  digit is padded with 0 when > closes the string. }
function TContentLexer.ParseHex: TCv;
var
  Hi, V, N, I: Integer;
  B: Byte;
  Bytes: TLandrixEInvoicePdfBytes;
  Closed: Boolean;
begin
  Result := NewCv(cvk_Str);
  Result.Hex := True;
  Bytes := nil;
  N := 0;
  Hi := -1;
  Closed := False;
  Inc(FPos);
  { <~ starts an ASCII85 string for veraPDF: not followed }
  if (FPos < FLen) and (FBuf[FPos] = Ord('~')) then
  begin
    FStatus := lxs_Unknown;
    Exit;
  end;
  while FPos < FLen do
  begin
    B := FBuf[FPos];
    Inc(FPos);
    if B = Ord('>') then
    begin
      Closed := True;
      Break;
    end;
    if IsWhite(B) then
      Continue;
    Inc(Result.HexChars);
    V := HexDigit(B);
    if V < 0 then
    begin
      Result.HexInvalid := True;
      Continue;
    end;
    if Hi < 0 then
      Hi := V
    else
    begin
      if N >= Length(Bytes) then
        SetLength(Bytes, 64 + 2 * N);
      Bytes[N] := Byte((Hi shl 4) or V);
      Inc(N);
      Hi := -1;
    end;
  end;
  if Closed and (Hi >= 0) then
  begin
    if N >= Length(Bytes) then
      SetLength(Bytes, N + 1);
    Bytes[N] := Byte(Hi shl 4);
    Inc(N);
  end;
  SetLength(Bytes, N);
  Result.ByteLen := N;
  Result.Data := Bytes;
  for I := 0 to N - 1 do
    Include(Result.Codes, Bytes[I]);
  LandrixEInvoicePdfStringLength(Bytes, 0, Result.LenLo, Result.LenHi);
end;

{ A name: #xx with two hex digits stands for one byte, any other # stays. }
function TContentLexer.ParseName: TCv;
var
  Start, Stop, I, V1, V2, N: Integer;
  S: AnsiString;
begin
  Result := NewCv(cvk_Name);
  Inc(FPos);
  Start := FPos;
  while (FPos < FLen) and IsRegular(FBuf[FPos]) do
    Inc(FPos);
  Stop := FPos;
  { one buffer of the longest result: appending a character at a time
    would copy a long name again and again }
  S := '';
  SetLength(S, Stop - Start);
  N := 0;
  I := Start;
  while I < Stop do
  begin
    { a # with fewer than two characters left: veraPDF reads on past the
      name, so the following tokens are not known }
    if (FBuf[I] = Ord('#')) and (I + 2 >= Stop) then
    begin
      FStatus := lxs_Unknown;
      Exit;
    end;
    if (FBuf[I] = Ord('#')) and (I + 2 < Stop) then
    begin
      V1 := HexDigit(FBuf[I + 1]);
      V2 := HexDigit(FBuf[I + 2]);
      if (V1 >= 0) and (V2 >= 0) then
      begin
        Inc(N);
        S[N] := AnsiChar((V1 shl 4) or V2);
        Inc(I, 3);
        Continue;
      end;
    end;
    Inc(N);
    S[N] := AnsiChar(FBuf[I]);
    Inc(I);
  end;
  SetLength(S, N);
  Result.Text := S;
end;

{ A value inside an array or dictionary. A keyword other than true, false
  and null (a reference R, an operator) or a stray delimiter is read by
  another parser path in veraPDF: not decided. }
function TContentLexer.ParseValue(ADepth: Integer): TCv;
var
  B: Byte;
  K: AnsiString;
begin
  Result := nil;
  if ADepth > MaxCompoundDepth then
  begin
    FStatus := lxs_Unknown;
    Exit;
  end;
  SkipWhite;
  if AtEnd then
  begin
    FStatus := lxs_Failed;
    Exit;
  end;
  B := FBuf[FPos];
  if B = Ord('[') then
    Result := ParseArray(ADepth + 1)
  else if B = Ord('<') then
  begin
    if (FPos + 1 < FLen) and (FBuf[FPos + 1] = Ord('<')) then
      Result := ParseDict(ADepth + 1)
    else
      Result := ParseHex;
  end
  else if B = Ord('(') then
    Result := ParseLiteral
  else if B = Ord('/') then
    Result := ParseName
  else if IsNumberStart(B) then
    Result := ParseNumber
  else if IsRegular(B) then
  begin
    K := ReadKeyword;
    if (K = 'true') or (K = 'false') then
    begin
      Result := NewCv(cvk_Bool);
      Result.IntVal := Ord(K = 'true');
    end
    else if K = 'null' then
      Result := NewCv(cvk_Null)
    else
      FStatus := lxs_Unknown;
  end
  else
    FStatus := lxs_Unknown;
end;

function TContentLexer.ParseArray(ADepth: Integer): TCv;
var
  V: TCv;
begin
  Result := NewCv(cvk_Arr);
  Inc(FPos);
  while FStatus = lxs_Ok do
  begin
    SkipWhite;
    if AtEnd then
    begin
      { the array is not closed: veraPDF throws }
      FStatus := lxs_Failed;
      Exit;
    end;
    if FBuf[FPos] = Ord(']') then
    begin
      Inc(FPos);
      Exit;
    end;
    V := ParseValue(ADepth);
    if FStatus <> lxs_Ok then
      Exit;
    Result.Items.Add(V);
  end;
end;

function TContentLexer.ParseDict(ADepth: Integer): TCv;
var
  K: AnsiString;
  V: TCv;
begin
  Result := NewCv(cvk_Dict);
  Inc(FPos, 2);
  while FStatus = lxs_Ok do
  begin
    SkipWhite;
    if AtEnd then
    begin
      FStatus := lxs_Failed;
      Exit;
    end;
    if (FBuf[FPos] = Ord('>')) and (FPos + 1 < FLen) and (FBuf[FPos + 1] = Ord('>')) then
    begin
      Inc(FPos, 2);
      Exit;
    end;
    if FBuf[FPos] <> Ord('/') then
    begin
      { a key that is no name }
      FStatus := lxs_Unknown;
      Exit;
    end;
    K := ParseName.Text;
    SkipWhite;
    if AtEnd then
    begin
      FStatus := lxs_Failed;
      Exit;
    end;
    if FBuf[FPos] = Ord('>') then
    begin
      { a key without value }
      FStatus := lxs_Unknown;
      Exit;
    end;
    V := ParseValue(ADepth);
    if FStatus <> lxs_Ok then
      Exit;
    Result.Put(K, V);
    if Length(Result.Keys) > MaxDictKeys then
    begin
      FStatus := lxs_Unknown;
      Exit;
    end;
  end;
end;

{ After EI and white space veraPDF reads one token: an operator it knows (or
  an operand) accepts this EI as the end of the image, an unknown keyword
  rejects it. }
function TContentLexer.Lookahead(APos: Integer): TLookahead;
var
  Q, Start, Code: Integer;
  B: Byte;
  K: AnsiString;
begin
  Result := lka_Unknown;
  Q := APos;
  while (Q < FLen) and IsWhite(FBuf[Q]) do
    Inc(Q);
  if Q - APos > MaxLookahead then
    Exit;
  if Q >= FLen then
  begin
    Result := lka_Accept;
    Exit;
  end;
  B := FBuf[Q];
  Start := Q;
  if IsNumberStart(B) or (B = Ord('/')) then
  begin
    { an operand: it must fit into veraPDF's buffer to be read back }
    Inc(Q);
    while (Q < FLen) and IsRegular(FBuf[Q]) do
      Inc(Q);
    if Q - APos <= MaxLookahead then
      Result := lka_Accept;
    Exit;
  end;
  if not IsRegular(B) or (B = Ord('I')) then
    Exit;
  if IsKeywordStart(B) then
    Q := KeywordEnd(FBuf, FLen, Q)
  else
    Q := OperatorEnd(FBuf, FLen, Q);
  if Q - APos > MaxLookahead then
    Exit;
  K := LandrixEInvoicePdfBytesToAnsi(FBuf, Start, Q - Start);
  { BI: veraPDF reads the whole next image and its own lookahead, and
    loses its read-back position on the way: not decided }
  if K = 'BI' then
    Exit;
  Code := OpCode(K);
  if (Code <> oc_None) or (K = 'EI') or (K = 'true') or (K = 'false') or (K = 'null') then
    Result := lka_Accept
  else
    Result := lka_Reject;
end;

function TContentLexer.ParseInline: TCv;
var
  D, V: TCv;
  K: AnsiString;
  DataStart, I: Integer;
  L: Int64;
  Found: Boolean;
begin
  Result := nil;
  if FPending > 0 then
  begin
    { operands before BI: veraPDF takes the image from another argument }
    FStatus := lxs_Unknown;
    Exit;
  end;
  D := NewCv(cvk_Dict);
  while True do
  begin
    SkipWhite;
    if AtEnd then
    begin
      FStatus := lxs_Failed;
      Exit;
    end;
    if (FBuf[FPos] = Ord('I')) and (FPos + 1 < FLen) and (FBuf[FPos + 1] = Ord('D')) and
      ((FPos + 2 >= FLen) or not IsRegular(FBuf[FPos + 2])) then
    begin
      Inc(FPos, 2);
      Break;
    end;
    if FBuf[FPos] <> Ord('/') then
    begin
      FStatus := lxs_Unknown;
      Exit;
    end;
    K := ParseName.Text;
    SkipWhite;
    if AtEnd then
    begin
      FStatus := lxs_Failed;
      Exit;
    end;
    V := ParseValue(1);
    if FStatus <> lxs_Ok then
      Exit;
    D.Put(K, V);
    if Length(D.Keys) > MaxDictKeys then
    begin
      FStatus := lxs_Unknown;
      Exit;
    end;
  end;
  if (FPos < FLen) and IsWhite(FBuf[FPos]) then
    Inc(FPos);
  DataStart := FPos;
  L := -1;
  V := D.Get('L');
  if V = nil then
    V := D.Get('Length');
  if (V <> nil) and (V.Kind = cvk_Int) and (V.IntVal >= 0) then
    L := V.IntVal
  else if (V <> nil) and (V.Kind = cvk_Real) and (V.RealVal >= 0) then
  begin
    { veraPDF takes the integer part }
    if V.RealVal >= 2147483647.0 then
    begin
      FStatus := lxs_Unknown;
      Exit;
    end;
    L := Trunc(V.RealVal);
  end
  else if (V <> nil) and (V.Kind = cvk_Str) then
  begin
    FStatus := lxs_Unknown;
    Exit;
  end;
  Found := False;
  I := DataStart;
  while I + 1 < FLen do
  begin
    { veraPDF's counter has read EI too when it compares with /L }
    if (FBuf[I] = Ord('E')) and (FBuf[I + 1] = Ord('I')) and ((L < 0) or (Int64(I) + 2 - DataStart >= L)) then
    begin
      if I + 2 >= FLen then
      begin
        Found := True;
        Break;
      end;
      if IsWhite(FBuf[I + 2]) then
        case Lookahead(I + 2) of
          lka_Accept:
            begin
              Found := True;
              Break;
            end;
          lka_Unknown:
            begin
              FStatus := lxs_Unknown;
              Exit;
            end;
        else
          { rejected: search on }
        end;
    end;
    Inc(I);
  end;
  if Found then
    FPos := I + 2
  else
    FPos := FLen;
  Result := NewCv(cvk_Op);
  Result.Text := 'BI';
  Result.ImageDict := D;
end;

function TContentLexer.Next: TCv;
var
  B: Byte;
  K: AnsiString;
begin
  Result := nil;
  if (FStatus <> lxs_Ok) or FDone then
    Exit;
  SkipWhite;
  if AtEnd then
  begin
    FDone := True;
    Exit;
  end;
  B := FBuf[FPos];
  if B = Ord('[') then
    Result := ParseArray(1)
  else if B = Ord('<') then
  begin
    if (FPos + 1 < FLen) and (FBuf[FPos + 1] = Ord('<')) then
      Result := ParseDict(1)
    else
      Result := ParseHex;
  end
  else if B = Ord('(') then
    Result := ParseLiteral
  else if B = Ord('/') then
    Result := ParseName
  else if B = Ord(']') then
  begin
    { a stray ] ends the stream quietly }
    FDone := True;
    Exit;
  end
  else if IsNumberStart(B) then
    Result := ParseNumber
  else if B = Ord('I') then
    { veraPDF reads a token starting with I as ID and its image data or
      throws: not decided }
    FStatus := lxs_Unknown
  else
  begin
    K := ReadOperator;
    if not IsKeywordStart(B) and (HasByte(K, '+') or HasByte(K, '-') or HasByte(K, '.')) then
      FStatus := lxs_Unknown
    else if (K = 'true') or (K = 'false') then
    begin
      Result := NewCv(cvk_Bool);
      Result.IntVal := Ord(K = 'true');
    end
    else if K = 'null' then
      Result := NewCv(cvk_Null)
    else if K = 'BI' then
      Result := ParseInline
    else
    begin
      Result := NewCv(cvk_Op);
      Result.Text := K;
    end;
  end;
  if FStatus <> lxs_Ok then
  begin
    Result := nil;
    Exit;
  end;
  if Result.Kind = cvk_Op then
    FPending := 0
  else
    Inc(FPending);
end;

//==============================================================================
// The walk
//==============================================================================

type
  { The lookup of named resources: the stream's own (nil: none, which
    veraPDF reads as an empty dictionary), then the page's. InheritAll: the
    content of a page without /Resources (veraPDF counts every resource
    found there as inherited). }
  TRes = record
    Local: TLandrixEInvoicePdfObject;
    Page: TLandrixEInvoicePdfObject;
    InheritAll: Boolean;
  end;

  { A colour space as veraPDF builds it: none (null),
    a device space (defaults applied), a space array to look into (V; R the
    resources its nested names are looked up in; Num its object number, -1
    when direct; WasDefault: selected by a /Default* entry), a pattern space
    (with an underlying space or not), or not decided. }
  TCsKind = (csk_Null, csk_Gray, csk_RGB, csk_CMYK, csk_Value, csk_Pattern, csk_PatternUnder, csk_Unknown);
  TCsRef = record
    Kind: TCsKind;
    V: TLandrixEInvoicePdfObject;
    R: TLandrixEInvoicePdfObject;
    Num: Integer;
    WasDefault: Boolean;
  end;

  { The parts of the graphics state the checks need. }
  TGState = record
    ColorOn: Boolean;
    FillPattern: Boolean;
    StrokePattern: Boolean;
    Font: TLandrixEInvoicePdfObject;
    { the resource name Tf selected the font by ('' from a graphics state) }
    FontName: AnsiString;
    { the initial colour space was not decided }
    Unsure: Boolean;
    { a pattern space with an underlying space was selected: veraPDF then
      changes the start state of later tiling patterns }
    Under: Boolean;
    { the current fill and stroke colour spaces; the text rendering mode
      (-1 not decided) }
    FillCs: TCsRef;
    StrokeCs: TCsRef;
    TextMode: Integer;
    { overprint for stroking (/OP) and filling (/op) and the overprint mode
      (/OPM; OPMKnown False: a value not decided) }
    OPStroke: Boolean;
    OPFill: Boolean;
    OPM: Int64;
    OPMKnown: Boolean;
    { veraPDF's transparency state (fresh in every parse; 0 no, 1 not
      decided, 2 yes): a soft mask, a blend mode other than Normal, a fill
      (ca) and a stroke (CA) alpha below 1 }
    TSMask: Integer;
    TBM: Integer;
    TFillA: Integer;
    TStrokeA: Integer;
    { the tiling pattern of the fill and stroke space: its parse, -1 none
      (or a pattern without content), -2 not decided }
    FillPat: Integer;
    StrokePat: Integer;
  end;

  TGStack = array of TGState;

  TIntArray = array of Integer;

  { One parse of a content stream in one context. }
  TContentParse = class(TObject)
  public
    Key: string;
    Num: Integer;
    Root: Boolean;
    Uncertain: Boolean;
    Level: array[TLandrixEInvoicePdfContentCheck] of Integer;
    KeptSure: array[TLandrixEInvoicePdfContentCheck] of Integer;
    KeptMaybe: array[TLandrixEInvoicePdfContentCheck] of Integer;
    Children: TIntArray;
    { Children sorted, to find a value already there }
    ChildSorted: TIntArray;
    { the associated objects, AssocCount of them; duplicates are removed
      (and the list sorted) when it has doubled and by CompactAssoc }
    Assoc: TIntArray;
    AssocCount: Integer;
    AssocCompact: Integer;
    Group: Integer;
    Index: Integer;
    { no stream: something veraPDF validates once by its identity (an image,
      a shading, a colour space array, a group), in the context it meets it
      first }
    Virtual: Boolean;
    { the Separation spaces this parse links (indexes into the walk's list),
      and whether only maybe }
    SepIdx: array of Integer;
    SepMaybe: array of Boolean;
    { 6.2.10-2: whether the parse contains transparency as veraPDF
      finds it (0 no, 1 not decided, 2 yes); CycleCut: a
      stream it reaches was being parsed already (veraPDF then reads it as
      empty, which a reuse of this parse elsewhere may not) }
    Transp: Integer;
    CycleCut: Boolean;
    { a Type 3 entry (FType3Seen): the parse of each CharProcs stream, by
      glyph name }
    GlyphNames: array of AnsiString;
    GlyphIdx: array of Integer;
    { the entry's glyphs are being parsed (a glyph shows text in its own
      font); the glyph slot per code 0 to 127 (-1 none, -2 a name from a base
      table not modelled), CodesDone once filled }
    Building: Boolean;
    CodeGlyph: array of Integer;
    CodesDone: Boolean;
    { ReachesActive cached for the active streams of stamp ReachGen }
    ReachGen: Integer;
    ReachVal: Boolean;
    VisitGen: Integer;
    procedure AddSep(AIndex: Integer; AMaybe: Boolean);
    procedure AddChild(AIndex: Integer);
    procedure AddAssoc(ANum: Integer);
    procedure CompactAssoc;
    function HasAssoc(ANum: Integer): Boolean;
  end;

{ Inserts AValue into the sorted ASorted; False if it is there already
  (binary search: a glyph set replayed for every text operator would make
  a linear search quadratic). }
function InsertSorted(var ASorted: TIntArray; AValue: Integer): Boolean;
var
  Lo, Hi, Mid, N: Integer;
begin
  Result := False;
  Lo := 0;
  Hi := Integer(Length(ASorted)) - 1;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if ASorted[Mid] = AValue then
      Exit;
    if ASorted[Mid] < AValue then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
  N := Integer(Length(ASorted));
  SetLength(ASorted, N + 1);
  if Lo < N then
    Move(ASorted[Lo], ASorted[Lo + 1], (N - Lo) * SizeOf(Integer));
  ASorted[Lo] := AValue;
  Result := True;
end;

procedure TContentParse.AddChild(AIndex: Integer);
begin
  if AIndex < 0 then
    Exit;
  if not InsertSorted(ChildSorted, AIndex) then
    Exit;
  SetLength(Children, Length(Children) + 1);
  Children[High(Children)] := AIndex;
end;

{ Sorts the first ACount values of A (bottom-up merge sort: n log n for
  any order). }
procedure SortInts(var A: TIntArray; ACount: Integer);
var
  Temp: TIntArray;
  Width, Lo, Mid, Hi, L, R, K: Integer;
begin
  Temp := nil;
  SetLength(Temp, ACount);
  Width := 1;
  while Width < ACount do
  begin
    Lo := 0;
    while Lo < ACount do
    begin
      Mid := Lo + Width;
      if Mid > ACount then
        Mid := ACount;
      Hi := Mid + Width;
      if Hi > ACount then
        Hi := ACount;
      L := Lo;
      R := Mid;
      for K := Lo to Hi - 1 do
        if (L < Mid) and ((R >= Hi) or (A[L] <= A[R])) then
        begin
          Temp[K] := A[L];
          Inc(L);
        end
        else
        begin
          Temp[K] := A[R];
          Inc(R);
        end;
      Lo := Hi;
    end;
    for K := 0 to ACount - 1 do
      A[K] := Temp[K];
    Width := Width * 2;
  end;
end;

procedure TContentParse.AddSep(AIndex: Integer; AMaybe: Boolean);
var
  I: Integer;
begin
  for I := 0 to Integer(Length(SepIdx)) - 1 do
    if SepIdx[I] = AIndex then
    begin
      if not AMaybe then
        SepMaybe[I] := False;
      Exit;
    end;
  SetLength(SepIdx, Length(SepIdx) + 1);
  SetLength(SepMaybe, Length(SepMaybe) + 1);
  SepIdx[High(SepIdx)] := AIndex;
  SepMaybe[High(SepMaybe)] := AMaybe;
end;

{ Appended; duplicates go when the list has doubled since the last
  compaction (sorted insertion would be quadratic for numbers in falling
  order). }
procedure TContentParse.AddAssoc(ANum: Integer);
begin
  if AssocCount >= Length(Assoc) then
    SetLength(Assoc, 2 * AssocCount + 8);
  Assoc[AssocCount] := ANum;
  Inc(AssocCount);
  if AssocCount > 2 * AssocCompact + 64 then
    CompactAssoc;
end;

procedure TContentParse.CompactAssoc;
var
  I, N: Integer;
begin
  SortInts(Assoc, AssocCount);
  N := 0;
  for I := 0 to AssocCount - 1 do
    if (N = 0) or (Assoc[I] <> Assoc[N - 1]) then
    begin
      Assoc[N] := Assoc[I];
      Inc(N);
    end;
  AssocCount := N;
  AssocCompact := N;
end;

{ After CompactAssoc: binary search. }
function TContentParse.HasAssoc(ANum: Integer): Boolean;
var
  Lo, Hi, Mid: Integer;
begin
  Result := True;
  Lo := 0;
  Hi := AssocCount - 1;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if Assoc[Mid] = ANum then
      Exit;
    if Assoc[Mid] < ANum then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
  Result := False;
end;

function NullCs: TCsRef;
begin
  Result.Kind := csk_Null;
  Result.V := nil;
  Result.R := nil;
  Result.Num := -1;
  Result.WasDefault := False;
end;

{ A key of a colour space for the memo. }
function CsKey(AWalk: TLandrixEInvoicePdfContentWalk; const C: TCsRef): string;
begin
  Result := IntToStr(Ord(C.Kind)) + ':' + AWalk.ObjId(C.V) + ':' + AWalk.ObjId(C.R) + ':' +
    IntToStr(Ord(C.WasDefault));
end;

{ A key of the overprint state for the memo. }
function OpKey(const AState: TGState): string;
begin
  Result := IntToStr(Ord(AState.OPStroke)) + IntToStr(Ord(AState.OPFill)) + ':' + IntToStr(AState.OPM) +
    IntToStr(Ord(AState.OPMKnown));
end;

type
  { A Separation space veraPDF registers: its colourant name, the alternate
    space as built and the tint transform as stored (element 3). }
  TSepSig = class(TObject)
  public
    Name: AnsiString;
    NameOk: Boolean;
    Alt: TCsRef;
    Tint: TLandrixEInvoicePdfObject;
    Num: Integer;
    Index: Integer;
    { the same object built with another alternate elsewhere }
    Unsure: Boolean;
  end;

  { The parse an interpreter writes to, kept while it writes to a virtual
    one. }
  TVSave = record
    Parse: TContentParse;
    Index: Integer;
  end;

  { The interpretation of one parse (operators, state, reaching further
    streams). }
  TInterpreter = class(TObject)
  private
    FWalk: TLandrixEInvoicePdfContentWalk;
    FDoc: TLandrixEInvoicePdfDocument;
    FParse: TContentParse;
    FParseIndex: Integer;
    FRes: TRes;
    FState: TGState;
    { the state the stream started with: veraPDF starts a tiling pattern
      reached from this stream with it }
    FInit: TGState;
    FStack: TGStack;
    { q levels beyond MaxStack, only counted }
    FStackOver: Integer;
    FOp: string;
    { graphics states, halftones and images checked by this parse }
    FSeen: TStringList;
    { above 0: colour findings are not certain }
    FCsMaybe: Integer;
    { the resources the last Lookup found its entry in; the resources that
      supplied the image or shading being looked into }
    FLookupFrom: TLandrixEInvoicePdfObject;
    { 6.2.10-2: what the last Do painted (its XObject), the glyphs of the
      last text shown }
    FDoTransp: Integer;
    FLastType3: TContentParse;
    FSiteFrom: TLandrixEInvoicePdfObject;
    { shading patterns being followed }
    FPatternNest: Integer;
    { a paint or text link is being made: the overprint flag of its side
      and the mode go with the colour space it links directly }
    FPaintActive: Boolean;
    FPaintFlag: Boolean;
    FPaintOPM: Int64;
    FPaintOPMKnown: Boolean;
    function SeenBefore(const AKey: string): Boolean;
    procedure Mark(ACheck: TLandrixEInvoicePdfContentCheck; AMaybe: Boolean; const AWhat: string);
    procedure ExposeNumber(V: TCv);
    procedure ExposeString(V: TCv);
    procedure ExposeName(V: TCv);
    procedure ExposeCos(V: TCv; AOuter: Boolean);
    procedure CheckSpec(D: TCv);
    procedure NumberList(AOps: TObjectList);
    procedure TopNumbers(AOps: TObjectList);
    function Lookup(const ACategory, AName: AnsiString; out ARaw: TLandrixEInvoicePdfObject):
      TLandrixEInvoicePdfObject;
    function IsPatternSpace(const AName: AnsiString): Boolean;
    procedure SetExtGState(const AName: AnsiString);
    procedure TranspState(G: TLandrixEInvoicePdfObject);
    procedure SelectFont(AOps: TObjectList);
    procedure ShowText;
    procedure CheckFont;
    procedure CheckGlyphs(AFirst: TCv);
    procedure GlyphMark(AFacts: TObject; ACheck: TLandrixEInvoicePdfContentCheck; AMaybe: Boolean;
      const AText: string);
    procedure ReachForm(const AName: AnsiString);
    procedure ReachPattern(const AName: AnsiString; AFill: Boolean);
    procedure RegisterAF(const AName: AnsiString);
    procedure CsInherit(const AName: AnsiString);
    procedure TouchProperties(const AName: AnsiString);
    procedure NoteTransp(ALevel: Integer);
    function TranspBase: Integer;
    function PatTransp(AIndex: Integer): Integer;
    procedure TranspPaint(AFill, AStroke: Boolean);
    procedure TextTransp(AFirst: TCv);
    function Type3Transp(AFirst: TCv): Integer;
    procedure Type3Codes(AEntry: TContentParse; E: TLandrixEInvoicePdfObject);
    function ChildTransp(AIndex: Integer; const AKey: string): Integer;
    procedure InlineImage(D: TCv);
    procedure CheckIntent(const AName: AnsiString; const AWhere: string);
    procedure CheckExtGState(G, ARaw: TLandrixEInvoicePdfObject);
    procedure CheckHalftone(V, ARaw: TLandrixEInvoicePdfObject; AClass: Integer; ADepth: Integer);
    procedure CheckImage(V, ARaw: TLandrixEInvoicePdfObject; AKind, ADepth: Integer);
    procedure CheckJpx(V: TLandrixEInvoicePdfObject; const AWhat: string);
    procedure CheckForm(V, ARaw: TLandrixEInvoicePdfObject);
    procedure CheckInline(D: TCv);
    procedure MaybeColour(const AWhat: string);
    function EnterVirtual(const AKey, ACtx: string; ANum: Integer; out ASave: TVSave): Boolean;
    procedure LeaveVirtual(const ASave: TVSave);
    procedure ExposeCs(const C: TCsRef; ANullGray: Boolean; ADepth: Integer);
    procedure ExposeArray(const C: TCsRef; ADepth: Integer; APaint: Boolean);
    procedure ExposeIcc(const C: TCsRef; APaint: Boolean);
    procedure RecordSeparation(const C: TCsRef);
    function CvSelectsSpecial(V: TCv; ADepth: Integer): Boolean;
    procedure PaintLink(const C: TCsRef; AStroke: Boolean);
    procedure ExposeDeviceN(const C: TCsRef; ADepth: Integer);
    function SiteSpace(ARaw: TLandrixEInvoicePdfObject; AShading: Boolean): TCsRef;
    procedure SiteLink(ARaw: TLandrixEInvoicePdfObject; AShading: Boolean);
    procedure ImageColour(V, ARaw: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure ImageSpace(V: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure ShadingColour(S, ARaw: TLandrixEInvoicePdfObject);
    procedure InlineColour(D: TCv);
    procedure GroupColour(G, R: TLandrixEInvoicePdfObject);
    procedure OwnerGroup(AOwner, R: TLandrixEInvoicePdfObject; const AOwnerKey: string; AOwnerNum: Integer);
    procedure TextColour;
    procedure Operate(AOp: TCv; AOps: TObjectList);
  public
    destructor Destroy; override;
    procedure Run(ALex: TContentLexer);
  end;

destructor TInterpreter.Destroy;
begin
  FSeen.Free;
  inherited Destroy;
end;

{ AKey was checked by this parse before (context-free checks run once). }
function TInterpreter.SeenBefore(const AKey: string): Boolean;
begin
  if FSeen = nil then
  begin
    FSeen := TStringList.Create;
    FSeen.Sorted := True;
    FSeen.Duplicates := dupIgnore;
  end;
  Result := FSeen.IndexOf(AKey) >= 0;
  if not Result then
    FSeen.Add(AKey);
end;

{ The parse of AStreams (one stream, or the parts of a page's /Contents) in
  the context ARes/AState; the index of the parse, -1 if the stream is being
  parsed already (a cycle: veraPDF reads nothing) or a limit was reached. }
function ParseStreams(AWalk: TLandrixEInvoicePdfContentWalk; const AKey: string; ANum: Integer;
  const AStreams: array of TLandrixEInvoicePdfObject; const ARes: TRes; const AState: TGState;
  ARoot: Boolean): Integer;
var
  Ctx, MemoKey: string;
  I, Idx, N, At: Integer;
  P: TContentParse;
  Data: TLandrixEInvoicePdfBytes;
  Parts: array of TLandrixEInvoicePdfBytes;
  Total: Int64;
  Unc: Boolean;
  Lex: TContentLexer;
  Interp: TInterpreter;
begin
  Result := -1;
  if AWalk.FActive.IndexOf(AKey) >= 0 then
    Exit;
  Ctx := AWalk.ObjId(ARes.Local) + '/' + AWalk.ObjId(ARes.Page) + '/' +
    IntToStr(Ord(AState.ColorOn)) + IntToStr(Ord(AState.FillPattern)) + IntToStr(Ord(AState.StrokePattern)) +
    IntToStr(Ord(AState.Unsure)) + IntToStr(Ord(AState.Under)) + '/' +
    AWalk.ObjId(AState.Font) + '/' + CsKey(AWalk, AState.FillCs) + '/' + CsKey(AWalk, AState.StrokeCs) + '/' +
    IntToStr(AState.TextMode) + '/' + OpKey(AState) + '/' + IntToStr(Ord(ARes.InheritAll)) + '/' +
    IntToStr(AState.FillPat) + ',' + IntToStr(AState.StrokePat);
  MemoKey := AKey + '#' + Ctx;
  Idx := AWalk.FMemo.IndexOf(MemoKey);
  if Idx >= 0 then
  begin
    Result := TContentParse(AWalk.FMemo.Objects[Idx]).Index;
    if ARoot then
      TContentParse(AWalk.FParses[Result]).Root := True;
    Exit;
  end;
  if (Integer(AWalk.FParses.Count) >= MaxParses) or (AWalk.FReachDepth >= MaxReachDepth) then
  begin
    { veraPDF may validate the stream here first, in this context }
    AWalk.FIncomplete := True;
    AWalk.FLimitHit := True;
    Exit;
  end;
  P := TContentParse.Create;
  P.Key := AKey;
  P.Num := ANum;
  P.Root := ARoot;
  P.Uncertain := AState.Unsure;
  Result := Integer(AWalk.FParses.Add(P));
  P.Index := Result;
  AWalk.FMemo.AddObject(MemoKey, P);

  { the data: the parts one after the other, a CR between two; the budget
    is checked before anything is joined }
  Unc := False;
  Parts := nil;
  if AWalk.FBudgetSpent then
  begin
    { decoded again and again, a large stream would cost time without end }
    AWalk.FIncomplete := True;
    P.Uncertain := True;
    Exit;
  end;
  SetLength(Parts, Length(AStreams));
  Total := 0;
  for I := 0 to Integer(High(AStreams)) do
  begin
    if not AWalk.StreamBytes(AStreams[I], Parts[I]) then
    begin
      Unc := True;
      Break;
    end;
    Inc(Total, Int64(Length(Parts[I])) + 1);
    if AWalk.FTotalBytes + Total > MaxTotalBytes then
    begin
      AWalk.FIncomplete := True;
      AWalk.FBudgetSpent := True;
      Unc := True;
      Break;
    end;
  end;
  { what was decoded counts, also when a later part fails }
  Inc(AWalk.FTotalBytes, Total);
  if AWalk.FTotalBytes > MaxTotalBytes then
    AWalk.FBudgetSpent := True;
  if Unc then
  begin
    P.Uncertain := True;
    Exit;
  end;
  N := 0;
  for I := 0 to Integer(High(Parts)) do
    Inc(N, Length(Parts[I]));
  if Length(Parts) > 1 then
    Inc(N, Length(Parts) - 1);
  Data := nil;
  SetLength(Data, N);
  At := 0;
  for I := 0 to Integer(High(Parts)) do
  begin
    if I > 0 then
    begin
      Data[At] := 13;
      Inc(At);
    end;
    if Length(Parts[I]) > 0 then
    begin
      Move(Parts[I][0], Data[At], Length(Parts[I]));
      Inc(At, Length(Parts[I]));
    end;
    Parts[I] := nil;
  end;

  AWalk.FActive.Add(AKey);
  Inc(AWalk.FActiveGen);
  Inc(AWalk.FReachDepth);
  try
    { first the whole stream: an exception in veraPDF drops every operator
      of it; then the operators one by one }
    Lex := TContentLexer.Create(AWalk, Data);
    try
      while Lex.Next <> nil do
        Lex.Release;
      Lex.Release;
      case Lex.Status of
        lxs_Unknown:
          P.Uncertain := True;
        lxs_Failed:
          begin
            AWalk.FAnyParseFailed := True;
            Exit;
          end;
      end;
    finally
      Lex.Free;
    end;
    if P.Uncertain then
      Exit;
    Lex := TContentLexer.Create(AWalk, Data);
    try
      Interp := TInterpreter.Create;
      try
        Interp.FWalk := AWalk;
        Interp.FDoc := AWalk.FDoc;
        Interp.FParse := P;
        Interp.FParseIndex := Result;
        Interp.FRes := ARes;
        Interp.FState := AState;
        Interp.FState.Unsure := False;
        Interp.FState.TSMask := 0;
        Interp.FState.TBM := 0;
        Interp.FState.TFillA := 0;
        Interp.FState.TStrokeA := 0;
        { veraPDF builds a tiling pattern at the paint, on the start state of
          the stream that paints: one set by a caller is not decided here }
        if Interp.FState.FillPat >= 0 then
          Interp.FState.FillPat := -2;
        if Interp.FState.StrokePat >= 0 then
          Interp.FState.StrokePat := -2;
        Interp.FInit := AState;
        Interp.FStack := nil;
        Interp.Run(Lex);
      finally
        Interp.Free;
      end;
    finally
      Lex.Free;
    end;
  finally
    AWalk.FActive.Delete(AWalk.FActive.Count - 1);
    Inc(AWalk.FActiveGen);
    Dec(AWalk.FReachDepth);
  end;
end;

{ A parse without a stream (TContentParse.Virtual) for AKey in the context
  ACtx; ANew when it was made now (the caller fills it). -1 at the limit. }
function VirtualParse(AWalk: TLandrixEInvoicePdfContentWalk; const AKey, ACtx: string; ANum: Integer;
  ARoot: Boolean; out ANew: Boolean): Integer;
var
  MemoKey: string;
  Idx: Integer;
  P: TContentParse;
begin
  ANew := False;
  Result := -1;
  MemoKey := AKey + '#' + ACtx;
  Idx := AWalk.FMemo.IndexOf(MemoKey);
  if Idx >= 0 then
  begin
    Result := TContentParse(AWalk.FMemo.Objects[Idx]).Index;
    if ARoot then
      TContentParse(AWalk.FParses[Result]).Root := True;
    Exit;
  end;
  if Integer(AWalk.FParses.Count) >= MaxParses then
  begin
    AWalk.FIncomplete := True;
    AWalk.FLimitHit := True;
    Exit;
  end;
  P := TContentParse.Create;
  P.Key := AKey;
  P.Num := ANum;
  P.Root := ARoot;
  P.Virtual := True;
  Result := Integer(AWalk.FParses.Add(P));
  P.Index := Result;
  AWalk.FMemo.AddObject(MemoKey, P);
  ANew := True;
end;

type
  { an ICC header in a string list }
  TIccBox = class(TObject)
  public
    H: TLandrixEInvoicePdfIccHeader;
  end;

{ The header of the ICC profile stream S, read once per object. }
function CachedIccHeader(AWalk: TLandrixEInvoicePdfContentWalk; S: TLandrixEInvoicePdfObject):
  TLandrixEInvoicePdfIccHeader;
var
  K: Integer;
  Key: string;
  Box: TIccBox;
begin
  Key := IntToStr(S.Serial);
  if AWalk.FIccCache.Find(Key, K) then
  begin
    Result := TIccBox(AWalk.FIccCache.Objects[K]).H;
    Exit;
  end;
  Result := LandrixEInvoicePdfIccHeader(AWalk.FDoc, S);
  Box := TIccBox.Create;
  Box.H := Result;
  AWalk.FIccCache.AddObject(Key, Box);
end;

const
  { the checks of colour spaces }
  ColourChecks = [pcc_DeviceGray..pcc_SeparationConsistency];
  { DeviceN names and process components compared one by one at most }
  MaxColorantScan = 1000;
  { nested colour spaces looked into per document }
  MaxCsSteps = 2000000;

{ An integer as veraPDF reads it from a dictionary entry: a number
  truncated toward zero, a string its byte length; False for anything else. }
function IntegerOf(V: TLandrixEInvoicePdfObject; out AValue: Int64): Boolean;
begin
  Result := False;
  AValue := 0;
  if V = nil then
    Exit;
  if V.Kind = pok_Num then
  begin
    { an integer token as it is; a real truncated toward zero, saturated
      beyond about 9e18 }
    if V.NumExact then
      AValue := V.NumInt
    else if V.NumVal >= 9.0E18 then
      AValue := High(Int64)
    else if V.NumVal <= -9.0E18 then
      AValue := Low(Int64)
    else
      AValue := Trunc(V.NumVal);
    Result := True;
  end
  else if V.Kind = pok_Str then
  begin
    AValue := Length(V.StrVal);
    Result := True;
  end;
end;

{ The low 32 bits as a signed value, as veraPDF keeps them. }
function Narrow32(N: Int64): Int64;
begin
  Result := N and $FFFFFFFF;
  if Result > $7FFFFFFF then
    Result := Result - $100000000;
end;

{ A pattern type: 1 tiling, 2 shading, 0 none (read as an int). }
function PatternTypeOf(AWalk: TLandrixEInvoicePdfContentWalk; V: TLandrixEInvoicePdfObject): Integer;
var
  N: Int64;
begin
  Result := 0;
  if (V = nil) or not V.IsDictLike then
    Exit;
  if IntegerOf(AWalk.DGetRef(V, 'PatternType'), N) then
  begin
    N := Narrow32(N);
    if (N = 1) or (N = 2) then
      Result := Integer(N);
  end;
end;

{ A key veraPDF's knownKey sees: stored with any value but a direct null
  (a reference counts even when its object is null or missing).
  DE: Ein Schluessel, den veraPDFs knownKey sieht: gespeichert mit jedem
  Wert ausser einem direkten null (ein Verweis zaehlt, auch wenn sein
  Objekt null ist oder fehlt). }
function HasKey(V: TLandrixEInvoicePdfObject; const AKey: AnsiString): Boolean;
var
  R: TLandrixEInvoicePdfObject;
begin
  Result := False;
  if (V = nil) or not V.IsDictLike then
    Exit;
  R := V.RawGet(AKey);
  Result := (R <> nil) and (R.Kind <> pok_Null);
end;

{ The resolved value of AKey is a name (veraPDF reads names this way, a
  string with the same text is none).
  DE: Der aufgeloeste Wert von AKey ist ein Name (so liest veraPDF Namen,
  ein String mit demselben Text ist keiner). }
function NameKey(AWalk: TLandrixEInvoicePdfContentWalk; V: TLandrixEInvoicePdfObject; const AKey: AnsiString;
  out AName: AnsiString): Boolean;
var
  R: TLandrixEInvoicePdfObject;
begin
  AName := '';
  R := AWalk.DGetRef(V, AKey);
  Result := (R <> nil) and (R.Kind = pok_Name);
  if Result then
    AName := R.NameVal;
end;

{ "object 12" for a reference, "a direct object" otherwise. }
function ObjLabel(AWalk: TLandrixEInvoicePdfContentWalk; ARaw: TLandrixEInvoicePdfObject): string;
begin
  if (ARaw <> nil) and (ARaw.Kind = pok_Ref) then
    Result := 'object ' + IntToStr(AWalk.LastRefNum(ARaw))
  else
    Result := 'a direct object';
end;

{ The colorant class of a key of a Type 5 halftone (6.2.5-6): Default needs
  nothing, Cyan, Magenta, Yellow and Black no transfer function, any other
  colorant one.
  DE: Die Farbmittelklasse eines Schluessels eines Halftones vom Typ 5
  (6.2.5-6): Default braucht nichts, Cyan, Magenta, Yellow und Black keine
  Transferfunktion, jedes andere Farbmittel eine. }
function HalftoneClass(const AKey: AnsiString): Integer;
begin
  if AKey = 'Default' then
    Result := HtDefault
  else if (AKey = 'Cyan') or (AKey = 'Magenta') or (AKey = 'Yellow') or (AKey = 'Black') then
    Result := HtPrimary
  else
    Result := HtOther;
end;

{ 6.2.9: what a form XObject dictionary has that it must not: /OPI, /PS or
  /Subtype2 /PS (APs), /Ref (ARef), /Subtype /PS (ASub); '' for none.
  DE: 6.2.9: was ein Form-XObject-Dictionary hat, das es nicht haben darf:
  /OPI, /PS oder /Subtype2 /PS (APs), /Ref (ARef), /Subtype /PS (ASub);
  '' fuer nichts. }
procedure FormFaults(AWalk: TLandrixEInvoicePdfContentWalk; V: TLandrixEInvoicePdfObject; out APs, ARef,
  ASub: string);
var
  N: AnsiString;
begin
  APs := '';
  ARef := '';
  ASub := '';
  if (V = nil) or not V.IsDictLike then
    Exit;
  if HasKey(V, 'OPI') then
    APs := ' /OPI';
  if HasKey(V, 'PS') then
    APs := APs + ' /PS';
  if NameKey(AWalk, V, 'Subtype2', N) and (N = 'PS') then
    APs := APs + ' /Subtype2 /PS';
  if HasKey(V, 'Ref') then
    ARef := ' /Ref';
  if NameKey(AWalk, V, 'Subtype', N) and (N = 'PS') then
    ASub := ' /Subtype /PS';
end;

type
  { What veraPDF builds from a colour space value: nothing, another space, a
    pattern space, or not decided (too deep). }
  TCsClass = (csc_None, csc_Other, csc_Pattern, csc_PatternUnder, csc_Unknown);

const
  { nesting of aliases, arrays and defaults followed }
  MaxCsDepth = 32;

function ResolveCsName(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; const AName: AnsiString;
  AStart, ADepth: Integer): TCsClass; forward;

function CsEntry(AWalk: TLandrixEInvoicePdfContentWalk; R: TLandrixEInvoicePdfObject;
  const AName: AnsiString): TLandrixEInvoicePdfObject;
begin
  Result := AWalk.DGetRef(AWalk.DGetRef(R, 'ColorSpace'), AName);
end;

function ClassifyIn(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; R, V: TLandrixEInvoicePdfObject;
  AStart, ADepth: Integer; ANoDefault, ANoAlias: Boolean): TCsClass; forward;

{ A device space met as a value in the resources R (AStart: 0 the stream's,
  1 the page's): the /DefaultGray, /DefaultRGB or /DefaultCMYK of R
  replaces it; a default that gives no space gives none. }
function DeviceIn(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; R: TLandrixEInvoicePdfObject;
  const AFamily: AnsiString; AStart, ADepth: Integer): TCsClass;
var
  D: TLandrixEInvoicePdfObject;
begin
  D := CsEntry(AWalk, R, 'Default' + AFamily);
  if D = nil then
    Result := csc_Other
  else
    Result := ClassifyIn(AWalk, ARes, R, D, AStart, ADepth + 1, True, False);
end;

{ The space veraPDF builds from a value V met in the resources R
  (AStart where R is, -1 none): device names with the default of R (not
  inside a default: ANoDefault), /Pattern, another name as an alias looked
  up in R only (not without resources: ANoAlias), a one-element array as its
  element, arrays by their first name, pattern dictionaries and streams. }
function ClassifyIn(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; R, V: TLandrixEInvoicePdfObject;
  AStart, ADepth: Integer; ANoDefault, ANoAlias: Boolean): TCsClass;
var
  F: TLandrixEInvoicePdfObject;
  N: AnsiString;
begin
  Result := csc_None;
  if V = nil then
    Exit;
  if ADepth > MaxCsDepth then
  begin
    Result := csc_Unknown;
    Exit;
  end;
  case V.Kind of
    pok_Name:
      begin
        N := V.NameVal;
        if (N = 'DeviceGray') or (N = 'DeviceRGB') or (N = 'DeviceCMYK') then
        begin
          if ANoDefault then
            Result := csc_Other
          else
            Result := DeviceIn(AWalk, ARes, R, Copy(N, 7, MaxInt), AStart, ADepth);
        end
        else if N = 'Pattern' then
          Result := csc_Pattern
        else if not ANoAlias and (AStart >= 0) then
        begin
          { an alias is looked up only in the resources where it was found }
          F := CsEntry(AWalk, R, N);
          if F <> nil then
            Result := ClassifyIn(AWalk, ARes, R, F, AStart, ADepth + 1, False, False);
        end;
      end;
    pok_Arr:
      if V.ArrCount = 1 then
        { one element: the element itself }
        Result := ClassifyIn(AWalk, ARes, R, AWalk.ResolveRef(V.ArrItem(0)), AStart, ADepth + 1, ANoDefault, ANoAlias)
      else if V.ArrCount >= 2 then
      begin
        F := AWalk.ResolveRef(V.ArrItem(0));
        if (F <> nil) and (F.Kind = pok_Name) then
        begin
          N := F.NameVal;
          if N = 'Pattern' then
            Result := csc_PatternUnder
          else if N = 'CalCMYK' then
          begin
            if ANoDefault then
              Result := csc_Other
            else
              Result := DeviceIn(AWalk, ARes, R, 'CMYK', AStart, ADepth);
          end
          else if (N = 'CalGray') or (N = 'CalRGB') or (N = 'Lab') or (N = 'ICCBased') or (N = 'Separation') or
            (N = 'DeviceN') or (N = 'Indexed') then
            Result := csc_Other;
        end;
      end;
    pok_Dict, pok_Stream:
      if PatternTypeOf(AWalk, V) <> 0 then
        Result := csc_Pattern;
  else
    { numbers, strings, booleans: nothing }
  end;
end;

{ The colour space a name selects, as veraPDF finds it
  (from AStart on: 0 the stream's resources, 1 the page's). A device name
  first takes the /Default* of the stream's own resources. Then each
  resources in turn (a stream without resources counts as empty ones): an entry of the
  name gives what veraPDF builds from it (nothing: the next
  resources); no entry gives the built-in space of the name (device spaces
  and /Pattern; nothing for other names: the next resources). }
function ResolveCsName(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; const AName: AnsiString;
  AStart, ADepth: Integer): TCsClass;
var
  K: Integer;
  R, V, D: TLandrixEInvoicePdfObject;
  Device: Boolean;
begin
  Result := csc_Unknown;
  if ADepth > MaxCsDepth then
    Exit;
  Device := (AName = 'DeviceGray') or (AName = 'DeviceRGB') or (AName = 'DeviceCMYK');
  if Device and (AStart = 0) then
  begin
    { the stream's own resources (a form without resources has none) }
    R := ARes.Local;
    D := CsEntry(AWalk, R, 'Default' + Copy(AName, 7, MaxInt));
    if D <> nil then
    begin
      Result := ClassifyIn(AWalk, ARes, R, D, 0, ADepth + 1, True, False);
      { a default that gives no space leaves the device space }
      if Result = csc_None then
        Result := csc_Other;
      Exit;
    end;
  end;
  for K := AStart to 1 do
  begin
    if K = 0 then
      R := ARes.Local
    else
      R := ARes.Page;
    if (K = 1) and ((R = nil) or ((AStart = 0) and (R = ARes.Local))) then
      Continue;
    V := CsEntry(AWalk, R, AName);
    if V <> nil then
      Result := ClassifyIn(AWalk, ARes, R, V, K, ADepth + 1, False, False)
    else if Device then
      Result := csc_Other
    else if AName = 'Pattern' then
      Result := csc_Pattern
    else
      Result := csc_None;
    if Result <> csc_None then
      Exit;
  end;
  Result := csc_None;
end;

{ A value a pattern resource lookup accepts: veraPDF builds it without
  resources and keeps a pattern space. }
function IsPatternValue(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; V: TLandrixEInvoicePdfObject): Boolean;
begin
  Result := ClassifyIn(AWalk, ARes, nil, V, -1, 0, True, True) in [csc_Pattern, csc_PatternUnder];
end;

{ The device space a name stands for (csk_Null: none). }
function DeviceKind(const AName: AnsiString): TCsKind;
begin
  if AName = 'DeviceGray' then
    Result := csk_Gray
  else if AName = 'DeviceRGB' then
    Result := csk_RGB
  else if AName = 'DeviceCMYK' then
    Result := csk_CMYK
  else
    Result := csk_Null;
end;

function IsDefaultName(const AName: AnsiString): Boolean;
begin
  Result := (AName = 'DefaultGray') or (AName = 'DefaultRGB') or (AName = 'DefaultCMYK');
end;

{ The entry AName of the /ColorSpace dictionary of the resources R as it is
  stored; nil if there is none or it is a direct null (a reference to no
  object is an entry: veraPDF builds null from it). }
function CsRaw(AWalk: TLandrixEInvoicePdfContentWalk; R: TLandrixEInvoicePdfObject;
  const AName: AnsiString): TLandrixEInvoicePdfObject;
var
  C: TLandrixEInvoicePdfObject;
begin
  Result := nil;
  C := AWalk.DGetRef(R, 'ColorSpace');
  if (C = nil) or not C.IsDictLike then
    Exit;
  Result := C.RawGet(AName);
  if (Result <> nil) and (Result.Kind = pok_Null) then
    Result := nil;
end;

function CsValue(AWalk: TLandrixEInvoicePdfContentWalk; R, ARaw: TLandrixEInvoicePdfObject; AWasDefault: Boolean;
  ADepth: Integer): TCsRef; forward;

{ A name met in a colour space value of the resources R, as veraPDF
  resolves it: a device name takes the /Default* entry of R unless
  the value was itself selected by one (AWasDefault); /Pattern is the
  pattern space; any other name is an alias looked up in R only. veraPDF
  keeps resolved names by name, so a default reached again from a default,
  and an alias named like a default, depend on the order of the lookups:
  not decided.
  DE: Ein Name in einem Farbraumwert der Ressourcen R, wie veraPDFs Fabrik
  ihn aufloest: ein Geraetename nimmt den /Default*-Eintrag von R, ausser
  der Wert wurde selbst ueber einen ausgewaehlt (AWasDefault); /Pattern ist
  der Musterraum; jeder andere Name ist ein Alias, der nur in R gesucht
  wird. veraPDF merkt sich aufgeloeste Namen nach dem Namen; ein Default,
  der von einem Default aus wieder erreicht wird, und ein Alias, der wie
  ein Default heisst, haengen daher von der Reihenfolge der Abfragen ab:
  nicht entschieden. }
function CsName(AWalk: TLandrixEInvoicePdfContentWalk; R: TLandrixEInvoicePdfObject; const AName: AnsiString;
  AWasDefault: Boolean; ADepth: Integer): TCsRef;
var
  D: TCsKind;
  E: TLandrixEInvoicePdfObject;
begin
  Result := NullCs;
  D := DeviceKind(AName);
  if D <> csk_Null then
  begin
    E := CsRaw(AWalk, R, 'Default' + Copy(AName, 7, MaxInt));
    if E = nil then
      Result.Kind := D
    else if AWasDefault then
      Result.Kind := csk_Unknown
    else
      Result := CsValue(AWalk, R, E, True, ADepth + 1);
    Exit;
  end;
  if AName = 'Pattern' then
  begin
    Result.Kind := csk_Pattern;
    Exit;
  end;
  E := CsRaw(AWalk, R, AName);
  if E = nil then
    Exit;
  if IsDefaultName(AName) then
    Result.Kind := csk_Unknown
  else
    Result := CsValue(AWalk, R, E, False, ADepth + 1);
end;

{ The colour space veraPDF builds from the value ARaw met in the
  resources R: a name (CsName), a one-element array as its element, an
  array by its first name (/CalCMYK as DeviceCMYK; /Pattern a pattern space
  with an underlying space), a pattern dictionary or stream; null for
  anything else.
  DE: Der Farbraum, den veraPDFs Fabrik aus dem Wert ARaw in den Ressourcen
  R baut: ein Name (CsName), ein Array mit einem Element als dieses
  Element, ein Array nach seinem ersten Namen (/CalCMYK als DeviceCMYK;
  /Pattern ein Musterraum mit zugrunde liegendem Raum), ein
  Muster-Dictionary oder -Stream; null fuer alles andere. }
function CsValue(AWalk: TLandrixEInvoicePdfContentWalk; R, ARaw: TLandrixEInvoicePdfObject; AWasDefault: Boolean;
  ADepth: Integer): TCsRef;
var
  V, F: TLandrixEInvoicePdfObject;
  N: AnsiString;
begin
  Result := NullCs;
  if ADepth > MaxCsDepth then
  begin
    Result.Kind := csk_Unknown;
    Exit;
  end;
  V := AWalk.ResolveRef(ARaw);
  if V = nil then
    Exit;
  if V.Kind = pok_Name then
    Result := CsName(AWalk, R, V.NameVal, AWasDefault, ADepth)
  else if V.Kind = pok_Arr then
  begin
    if V.ArrCount = 1 then
    begin
      Result := CsValue(AWalk, R, V.ArrItem(0), AWasDefault, ADepth + 1);
      Exit;
    end;
    if V.ArrCount < 2 then
      Exit;
    F := AWalk.ResolveRef(V.ArrItem(0));
    if (F = nil) or (F.Kind <> pok_Name) then
      Exit;
    N := F.NameVal;
    if N = 'CalCMYK' then
    begin
      Result := CsName(AWalk, R, 'DeviceCMYK', AWasDefault, ADepth);
      Exit;
    end;
    if N = 'Pattern' then
      Result.Kind := csk_PatternUnder
    else if (N = 'CalGray') or (N = 'CalRGB') or (N = 'Lab') or (N = 'ICCBased') or (N = 'Indexed') or
      (N = 'Separation') or (N = 'DeviceN') then
      Result.Kind := csk_Value
    else
      Exit;
    Result.V := V;
    Result.R := R;
    Result.WasDefault := AWasDefault;
    if (ARaw <> nil) and (ARaw.Kind = pok_Ref) then
      Result.Num := AWalk.LastRefNum(ARaw);
  end
  else if (V.Kind = pok_Dict) or (V.Kind = pok_Stream) then
  begin
    if PatternTypeOf(AWalk, V) <> 0 then
    begin
      Result.Kind := csk_Pattern;
      Result.V := V;
      Result.R := R;
    end;
  end;
end;

{ The colour space a name selects in a content stream, as veraPDF finds
  it (see ResolveCsName): a device name first takes
  the /Default* entry of the stream's own resources; then the stream's
  resources and the page's in turn. Null where nothing is found (what that
  gives depends on the operator).
  DE: Der Farbraum, den ein Name in einem Content-Stream auswaehlt, wie
  veraPDF ihn findet (siehe ResolveCsName): ein
  Geraetename nimmt zuerst den /Default*-Eintrag der eigenen Ressourcen des
  Streams; dann die Ressourcen des Streams und die der Seite. Null, wo
  nichts gefunden wird (was das ergibt, haengt vom Operator ab). }
function ResolveName(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; const AName: AnsiString): TCsRef;
var
  K: Integer;
  R, E: TLandrixEInvoicePdfObject;
  D: TCsKind;
begin
  Result := NullCs;
  D := DeviceKind(AName);
  if D <> csk_Null then
  begin
    E := CsRaw(AWalk, ARes.Local, 'Default' + Copy(AName, 7, MaxInt));
    if E <> nil then
    begin
      Result := CsValue(AWalk, ARes.Local, E, True, 1);
      Exit;
    end;
  end;
  for K := 0 to 1 do
  begin
    if K = 0 then
      R := ARes.Local
    else
      R := ARes.Page;
    if (K = 1) and ((R = nil) or (R = ARes.Local)) then
      Continue;
    E := CsRaw(AWalk, R, AName);
    if E <> nil then
    begin
      if IsDefaultName(AName) then
        Result.Kind := csk_Unknown
      else
        Result := CsValue(AWalk, R, E, False, 1);
      { a device name veraPDF then looks up in the page's resources with
        their default: not modelled }
      if (Result.Kind = csk_Null) and (D <> csk_Null) then
        Result.Kind := csk_Unknown;
    end
    else if D <> csk_Null then
      Result.Kind := D
    else if AName = 'Pattern' then
      Result.Kind := csk_Pattern;
    if Result.Kind <> csk_Null then
      Exit;
  end;
end;

{ 6.2.2-2 for a colour space name as veraPDF looks it
  up: 0 not inherited, 1 not decided, 2 inherited. A device name with a
  /Default* entry in the stream's own resources is not looked up; a lookup
  in the page's resources (after the stream's own gave nothing, or for a
  page that inherits them) marks the name unless it gives null or a device
  space as such.
  DE: 6.2.2-2 fuer einen Farbraumnamen, wie veraPDF ihn
  sucht: 0 nicht geerbt, 1 nicht entschieden, 2 geerbt. Ein Geraetename mit
  /Default*-Eintrag in den eigenen Ressourcen des Streams wird nicht
  gesucht; eine Suche in den Ressourcen der Seite (nachdem die eigenen des
  Streams nichts ergaben, oder fuer eine Seite, die sie erbt) markiert den
  Namen, ausser sie ergibt null oder einen Geraeteraum als solchen. }
function CsInheritLevel(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; const AName: AnsiString): Integer;
var
  K: Integer;
  R, E: TLandrixEInvoicePdfObject;
  D: TCsKind;
  C: TCsRef;
begin
  Result := 0;
  { a page without resources: veraPDF looks into empty resources, not marked }
  if ARes.InheritAll and (ARes.Page = nil) then
    Exit;
  D := DeviceKind(AName);
  if (D <> csk_Null) and (CsRaw(AWalk, ARes.Local, 'Default' + Copy(AName, 7, MaxInt)) <> nil) then
    Exit;
  for K := 0 to 1 do
  begin
    if K = 0 then
      R := ARes.Local
    else
      R := ARes.Page;
    if (K = 1) and ((R = nil) or (R = ARes.Local)) then
      Continue;
    C := NullCs;
    E := CsRaw(AWalk, R, AName);
    if E <> nil then
    begin
      if IsDefaultName(AName) then
        C.Kind := csk_Unknown
      else
        C := CsValue(AWalk, R, E, False, 1);
      if (C.Kind = csk_Null) and (D <> csk_Null) then
        C.Kind := csk_Unknown;
    end
    else if D <> csk_Null then
      C.Kind := D
    else if AName = 'Pattern' then
      C.Kind := csk_Pattern;
    if C.Kind = csk_Null then
      Continue;
    if C.Kind = csk_Unknown then
    begin
      { whether this gives null (and the page is asked) is not decided }
      if (K = 1) or ARes.InheritAll or ((ARes.Page <> nil) and (ARes.Page <> ARes.Local)) then
        Result := 1;
      Exit;
    end;
    if (K = 0) and not ARes.InheritAll then
      Exit;
    if not (C.Kind in [csk_Gray, csk_RGB, csk_CMYK]) then
      Result := 2;
    Exit;
  end;
end;

{ The first name of a colour space array ('' if none). }
function FirstName(AWalk: TLandrixEInvoicePdfContentWalk; V: TLandrixEInvoicePdfObject): AnsiString;
var
  F: TLandrixEInvoicePdfObject;
begin
  Result := '';
  if (V = nil) or (V.Kind <> pok_Arr) or (V.ArrCount = 0) then
    Exit;
  F := AWalk.ResolveRef(V.ArrItem(0));
  if (F <> nil) and (F.Kind = pok_Name) then
    Result := F.NameVal;
end;

{ /N of the profile of an ICCBased array as veraPDF reads it (-1 if none,
  -2 not decided). }
function IccComponents(AWalk: TLandrixEInvoicePdfContentWalk; V: TLandrixEInvoicePdfObject): Int64;
var
  S, N: TLandrixEInvoicePdfObject;
begin
  Result := -1;
  if (FirstName(AWalk, V) <> 'ICCBased') or (V.ArrCount < 2) then
    Exit;
  S := AWalk.ResolveRef(V.ArrItem(1));
  if (S = nil) or (S.Kind <> pok_Stream) then
    Exit;
  N := AWalk.DGetRef(S, 'N');
  { a string counts its bytes, which this reader may not read as veraPDF
    does (an ASCII85 token): -2, not decided }
  if (N <> nil) and (N.Kind = pok_Str) then
    Result := -2
  else if IntegerOf(N, Result) then
    Result := Narrow32(Result)
  else
    Result := -1;
end;

{ veraPDF reads JPEG 2000 data of an image: /Filter is the name JPXDecode,
  or an array of names only with JPXDecode among them.
  DE: veraPDF liest JPEG-2000-Daten eines Bilds: /Filter ist der Name
  JPXDecode oder ein Array nur aus Namen, darunter JPXDecode. }
function IsJpxRead(AWalk: TLandrixEInvoicePdfContentWalk; V: TLandrixEInvoicePdfObject): Boolean;
var
  F, Item: TLandrixEInvoicePdfObject;
  I: Integer;
begin
  Result := False;
  F := AWalk.DGetRef(V, 'Filter');
  if F = nil then
    Exit;
  if F.Kind = pok_Name then
    Result := F.NameVal = 'JPXDecode'
  else if F.Kind = pok_Arr then
    for I := 0 to F.ArrCount - 1 do
    begin
      Item := AWalk.ResolveRef(F.ArrItem(I));
      if (Item = nil) or (Item.Kind <> pok_Name) then
      begin
        Result := False;
        Exit;
      end;
      if Item.NameVal = 'JPXDecode' then
        Result := True;
    end;
end;

{ The image has JPEG 2000 data (a JPXDecode filter). }
function IsJpx(AWalk: TLandrixEInvoicePdfContentWalk; V: TLandrixEInvoicePdfObject): Boolean;
var
  F, Item: TLandrixEInvoicePdfObject;
  I: Integer;
begin
  Result := False;
  F := AWalk.DGetRef(V, 'Filter');
  if F = nil then
    Exit;
  if F.Kind = pok_Name then
    Result := F.NameVal = 'JPXDecode'
  else if F.Kind = pok_Arr then
    for I := 0 to F.ArrCount - 1 do
    begin
      Item := AWalk.ResolveRef(F.ArrItem(I));
      if (Item <> nil) and (Item.Kind = pok_Name) and (Item.NameVal = 'JPXDecode') then
        Result := True;
    end;
end;

{ A new graphics state: colour on, no font, text rendering mode 0, both
  colour spaces DeviceGray (resolved when the state is made, against the
  resources of the stream); Unsure where the pattern state is not decided. }
function FreshState(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes): TGState;
var
  C: TCsClass;
begin
  Result.ColorOn := True;
  C := ResolveCsName(AWalk, ARes, 'DeviceGray', 0, 0);
  Result.FillPattern := C in [csc_Pattern, csc_PatternUnder];
  Result.StrokePattern := Result.FillPattern;
  Result.Under := C = csc_PatternUnder;
  Result.Font := nil;
  Result.Unsure := C = csc_Unknown;
  Result.FillCs := ResolveName(AWalk, ARes, 'DeviceGray');
  if Result.FillCs.Kind = csk_Null then
    Result.FillCs.Kind := csk_Unknown;
  Result.StrokeCs := Result.FillCs;
  Result.TextMode := 0;
  Result.OPStroke := False;
  Result.OPFill := False;
  Result.OPM := 0;
  Result.OPMKnown := True;
  Result.TSMask := 0;
  Result.TBM := 0;
  Result.TFillA := 0;
  Result.TStrokeA := 0;
  Result.FillPat := -1;
  Result.StrokePat := -1;
end;

procedure TInterpreter.Mark(ACheck: TLandrixEInvoicePdfContentCheck; AMaybe: Boolean; const AWhat: string);
var
  Lvl, N: Integer;
  W: TLandrixEInvoicePdfContentWalk;
begin
  if (FCsMaybe > 0) and (ACheck in ColourChecks) then
    AMaybe := True;
  if AMaybe then
    Lvl := 1
  else
    Lvl := 2;
  if Lvl > FParse.Level[ACheck] then
    FParse.Level[ACheck] := Lvl;
  { certain and uncertain findings are kept separately, so that uncertain
    ones never crowd out a certain one }
  if AMaybe then
  begin
    if FParse.KeptMaybe[ACheck] >= MaxFindingsPerCheck then
      Exit;
    Inc(FParse.KeptMaybe[ACheck]);
  end
  else
  begin
    if FParse.KeptSure[ACheck] >= MaxFindingsPerCheck then
      Exit;
    Inc(FParse.KeptSure[ACheck]);
  end;
  W := FWalk;
  N := W.FFCount;
  if N >= Length(W.FFParse) then
  begin
    SetLength(W.FFParse, 64 + 2 * N);
    SetLength(W.FFCheck, 64 + 2 * N);
    SetLength(W.FFMaybe, 64 + 2 * N);
    SetLength(W.FFDetail, 64 + 2 * N);
  end;
  W.FFParse[N] := FParseIndex;
  W.FFCheck[N] := ACheck;
  W.FFMaybe[N] := AMaybe;
  W.FFDetail[N] := AWhat + ' (operator ' + FOp + ')';
  Inc(W.FFCount);
end;

procedure TInterpreter.ExposeNumber(V: TCv);
var
  A: Double;
begin
  if V.Kind = cvk_Int then
  begin
    if (V.IntVal > 2147483647) or (V.IntVal < -2147483648) then
      Mark(pcc_Integer, False, 'integer ' + IntToStr(V.IntVal) + ' out of range');
    Exit;
  end;
  if V.Kind <> cvk_Real then
    Exit;
  A := Abs(V.RealVal);
  if V.RealNear then
  begin
    if A > 1 then
      Mark(pcc_Real, True, 'real number near the limit')
    else
      Mark(pcc_SmallReal, True, 'real number near the limit');
    Exit;
  end;
  if A > FWalk.FMaxReal then
    Mark(pcc_Real, False, 'real number out of range');
  if (A <> 0) and (A < FWalk.FMinReal) then
    Mark(pcc_SmallReal, False, 'real number too close to zero');
end;

procedure TInterpreter.ExposeString(V: TCv);
begin
  if V.LenLo > 32767 then
    Mark(pcc_StringLength, False, 'string of ' + IntToStr(V.LenLo) + ' characters')
  else if V.LenHi > 32767 then
    Mark(pcc_StringLength, True, 'string of up to ' + IntToStr(V.LenHi) + ' characters');
  if V.Hex then
  begin
    if Odd(V.HexChars) then
      Mark(pcc_HexOdd, False, 'odd number of hexadecimal characters');
    if V.HexInvalid then
      Mark(pcc_HexDigits, False, 'character that is no hexadecimal digit');
  end;
end;

procedure TInterpreter.ExposeName(V: TCv);
begin
  if Length(V.Text) > 127 then
    Mark(pcc_NameLength, False, 'name of ' + IntToStr(Length(V.Text)) + ' bytes');
end;

{ A value passed on as a whole: numbers, strings, names, the items of an
  array, the keys and values of a dictionary; a dictionary inside it with
  /Type /Filespec is a file specification (not the outer one itself). }
procedure TInterpreter.ExposeCos(V: TCv; AOuter: Boolean);
var
  I: Integer;
  T: TCv;
begin
  if V = nil then
    Exit;
  case V.Kind of
    cvk_Int, cvk_Real:
      ExposeNumber(V);
    cvk_Str:
      ExposeString(V);
    cvk_Name:
      ExposeName(V);
    cvk_Arr:
      for I := 0 to Integer(V.Items.Count) - 1 do
        ExposeCos(TCv(V.Items[I]), False);
    cvk_Dict:
      begin
        for I := 0 to Integer(Length(V.Keys)) - 1 do
          if Length(V.Keys[I]) > 127 then
            Mark(pcc_NameLength, False, 'name of ' + IntToStr(Length(V.Keys[I])) + ' bytes');
        for I := 0 to Integer(V.Items.Count) - 1 do
          ExposeCos(TCv(V.Items[I]), False);
        if not AOuter then
        begin
          T := V.Get('Type');
          if (T <> nil) and (T.Kind = cvk_Name) and (T.Text = 'Filespec') then
            CheckSpec(V);
        end;
      end;
  else
    { booleans and null }
  end;
end;

{ 6.8-2 to 6.8-4 on a file specification inside content: a direct object,
  so it is never associated. }
procedure TInterpreter.CheckSpec(D: TCv);
var
  EF, F, UF, R: TCv;
begin
  EF := D.Get('EF');
  if (EF <> nil) and (EF.Kind <> cvk_Null) then
  begin
    F := D.Get('F');
    UF := D.Get('UF');
    if not ((F <> nil) and (F.Kind = cvk_Str) and (UF <> nil) and (UF.Kind = cvk_Str)) then
      Mark(pcc_SpecNames, False, 'file specification with /EF without /F and /UF');
  end;
  R := D.Get('AFRelationship');
  if (R = nil) or (R.Kind <> cvk_Name) then
    Mark(pcc_SpecRelationship, False, 'file specification without /AFRelationship');
  Mark(pcc_SpecDirect, False, 'direct file specification, not associated');
end;

{ cm m l c v y re Tm d1: every number, and the items of an array (an item
  that is no number gives veraPDF a link it cannot validate). }
procedure TInterpreter.NumberList(AOps: TObjectList);
var
  I, K: Integer;
  V, Item: TCv;
begin
  for I := 0 to Integer(AOps.Count) - 1 do
  begin
    V := TCv(AOps[I]);
    if (V.Kind = cvk_Int) or (V.Kind = cvk_Real) then
      ExposeNumber(V)
    else if V.Kind = cvk_Arr then
      for K := 0 to Integer(V.Items.Count) - 1 do
      begin
        Item := TCv(V.Items[K]);
        if (Item.Kind = cvk_Int) or (Item.Kind = cvk_Real) then
          ExposeNumber(Item)
        else
          FParse.Uncertain := True;
      end;
  end;
end;

{ colour operators: every number at the top level }
procedure TInterpreter.TopNumbers(AOps: TObjectList);
var
  I: Integer;
  V: TCv;
begin
  for I := 0 to Integer(AOps.Count) - 1 do
  begin
    V := TCv(AOps[I]);
    if (V.Kind = cvk_Int) or (V.Kind = cvk_Real) then
      ExposeNumber(V);
  end;
end;

{ A named resource: in the stream's own resources, then in the page's; an
  entry that does not give an object of the kinds asked for (or a reference
  to no object in use) makes veraPDF look in the page's resources. }
{ An object veraPDF takes as a font: a dictionary with one of five
  subtypes. }
function IsFontObject(AWalk: TLandrixEInvoicePdfContentWalk; V: TLandrixEInvoicePdfObject): Boolean;
var
  Sub: TLandrixEInvoicePdfObject;
begin
  Result := False;
  if (V = nil) or (V.Kind <> pok_Dict) then
    Exit;
  Sub := AWalk.DGetRef(V, 'Subtype');
  Result := (Sub <> nil) and (Sub.Kind = pok_Name) and ((Sub.NameVal = 'Type1') or (Sub.NameVal = 'MMType1') or
    (Sub.NameVal = 'TrueType') or (Sub.NameVal = 'Type3') or (Sub.NameVal = 'Type0'));
end;

{ Whether veraPDF's lookup of a resource of ACategory gives an object for
  the entry ARaw (resolved V); if not, it looks in the page's resources.
  ExtGState, Shading and Properties: any entry. XObject: /Subtype Image,
  Form or PS. Font: see IsFontObject. Pattern: a pattern dictionary or
  stream or a pattern colour space. ColorSpace: a value veraPDF builds a
  space from. }
function ResourceAccepted(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; const ACategory: AnsiString;
  ARaw, V: TLandrixEInvoicePdfObject): Boolean;
var
  Sub: TLandrixEInvoicePdfObject;
begin
  Result := False;
  if (ARaw = nil) or (ARaw.Kind = pok_Null) then
    Exit;
  if (ACategory = 'ExtGState') or (ACategory = 'Shading') or (ACategory = 'Properties') then
    Result := True
  else if V = nil then
    Result := False
  else if ACategory = 'XObject' then
  begin
    Sub := AWalk.DGetRef(V, 'Subtype');
    Result := (Sub <> nil) and (Sub.Kind = pok_Name) and ((Sub.NameVal = 'Image') or (Sub.NameVal = 'Form') or
      (Sub.NameVal = 'PS'));
  end
  else if ACategory = 'Font' then
    Result := IsFontObject(AWalk, V)
  else if ACategory = 'Pattern' then
    Result := IsPatternValue(AWalk, ARes, V)
  else if ACategory = 'ColorSpace' then
    Result := ClassifyIn(AWalk, ARes, nil, V, -1, 0, False, False) <> csc_None;
end;

{ A named resource: in the stream's own resources, then in the page's when
  veraPDF's lookup there gives nothing (ResourceAccepted); the entry ARaw
  and its object (nil for a reference to no object in use). }
function TInterpreter.Lookup(const ACategory, AName: AnsiString; out ARaw: TLandrixEInvoicePdfObject):
  TLandrixEInvoicePdfObject;
var
  K: Integer;
  R, C: TLandrixEInvoicePdfObject;
begin
  Result := nil;
  ARaw := nil;
  FLookupFrom := nil;
  for K := 0 to 1 do
  begin
    if K = 0 then
      R := FRes.Local
    else
      R := FRes.Page;
    if (R = nil) or not R.IsDictLike then
      Continue;
    C := FWalk.DGetRef(R, ACategory);
    if (C = nil) or not C.IsDictLike then
      Continue;
    ARaw := FWalk.DictGet(C, AName);
    Result := FWalk.ResolveRef(ARaw);
    { a pattern value nested beyond the depth limit: not decided }
    if (ACategory = 'Pattern') and (Result <> nil) and
      (ClassifyIn(FWalk, FRes, nil, Result, -1, 0, True, True) = csc_Unknown) then
      FParse.Uncertain := True;
    if ResourceAccepted(FWalk, FRes, ACategory, ARaw, Result) then
    begin
      FLookupFrom := R;
      { 6.2.2-2: found in the page's resources after the stream's own gave
        nothing (none count as empty), or by a page that inherits them
        DE: 6.2.2-2: in den Ressourcen der Seite gefunden, nachdem die
        eigenen des Streams nichts ergaben (keine zaehlen als leer), oder von
        einer Seite, die sie erbt }
      if (K = 1) or FRes.InheritAll then
        Mark(pcc_Inherited, False, TextOf(ACategory) + ' /' + TextOf(AName) + ' taken from the page''s resources');
      Exit;
    end;
    Result := nil;
    ARaw := nil;
  end;
end;

{ The colour space a name selects is a pattern space: /Pattern itself, a
  device space replaced by its default space, or a named space of the
  resources. }
function TInterpreter.IsPatternSpace(const AName: AnsiString): Boolean;
begin
  case ResolveCsName(FWalk, FRes, AName, 0, 0) of
    csc_Pattern:
      Result := True;
    csc_PatternUnder:
      begin
        FState.Under := True;
        Result := True;
      end;
    csc_Unknown:
      begin
        FParse.Uncertain := True;
        Result := False;
      end;
  else
    Result := False;
  end;
end;

function MaxOf(A, B: Integer): Integer;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

{ An alpha (ca, CA) as veraPDF reads it: a number as a float below 1.0
  (near 1 not decided, the digits may round otherwise); another value
  leaves the state. }
procedure AlphaLevel(V: TLandrixEInvoicePdfObject; var ALevel: Integer);
begin
  if (V = nil) or (V.Kind <> pok_Num) then
    Exit;
  if V.NumExact then
  begin
    if V.NumInt < 1 then
      ALevel := 2
    else
      ALevel := 0;
  end
  else if V.NumVal >= 1 then
    ALevel := 0
  else if V.NumVal * 100000 < 99999 then
    ALevel := 2
  else
    ALevel := 1;
end;

{ 6.2.10-2: gs copies /SMask and /BM into veraPDF's transparency state
  whether they are there or not (missing: none), /ca and /CA where they are
  numbers. A soft mask counts as a dictionary or stream; a blend mode as a
  name other than Normal, an array not of one element or of one name other
  than Normal, or any other value but null.
  DE: 6.2.10-2: gs kopiert /SMask und /BM in veraPDFs Transparenzzustand,
  ob sie da sind oder nicht (fehlend: keine), /ca und /CA, wo sie Zahlen
  sind. Eine Soft-Mask zaehlt als Dictionary oder Stream; ein Blend-Mode
  als Name ausser Normal, als Array nicht aus einem Element oder aus einem
  Namen ausser Normal, oder als jeder andere Wert ausser null. }
procedure TInterpreter.TranspState(G: TLandrixEInvoicePdfObject);
var
  V, It: TLandrixEInvoicePdfObject;
begin
  V := FWalk.DGetRef(G, 'SMask');
  if (V <> nil) and V.IsDictLike then
    FState.TSMask := 2
  else
    FState.TSMask := 0;
  V := FWalk.DGetRef(G, 'BM');
  FState.TBM := 0;
  if V <> nil then
    case V.Kind of
      pok_Name:
        if V.NameVal <> 'Normal' then
          FState.TBM := 2;
      pok_Arr:
        if V.ArrCount <> 1 then
          FState.TBM := 2
        else
        begin
          It := FWalk.ResolveRef(V.ArrItem(0));
          if (It <> nil) and (It.Kind = pok_Name) and (It.NameVal <> 'Normal') then
            FState.TBM := 2;
        end;
      pok_Null:
        ;
    else
      FState.TBM := 2;
    end;
  AlphaLevel(FWalk.DGetRef(G, 'ca'), FState.TFillA);
  AlphaLevel(FWalk.DGetRef(G, 'CA'), FState.TStrokeA);
end;

{ gs: an ExtGState with /Font [font size] selects that font where veraPDF
  takes it as a font; otherwise the font stays. }
procedure TInterpreter.SetExtGState(const AName: AnsiString);
var
  G, F, Font, Raw: TLandrixEInvoicePdfObject;
  OpmValue: Int64;
begin
  G := Lookup('ExtGState', AName, Raw);
  if (G = nil) or not G.IsDictLike then
  begin
    { an entry veraPDF builds but no dictionary: whether its keys reset the
      soft mask and blend mode is not decided }
    if Raw <> nil then
    begin
      if FState.TSMask > 0 then
        FState.TSMask := 1;
      if FState.TBM > 0 then
        FState.TBM := 1;
    end;
    Exit;
  end;
  CheckExtGState(G, Raw);
  TranspState(G);
  { 6.2.4.2-2: /OP for stroking; /op for filling, else /OP of the same
    dictionary; /OPM as veraPDF reads an integer entry; a value of
    another type leaves the state as it was
    DE: 6.2.4.2-2: /OP fuers Zeichnen von Linien; /op fuers Fuellen, sonst
    /OP desselben Dictionarys; /OPM, wie veraPDF einen ganzzahligen Eintrag liest;
    ein Wert anderen Typs laesst den Zustand, wie er war }
  F := FWalk.DGetRef(G, 'OP');
  if (F <> nil) and (F.Kind = pok_Bool) then
    FState.OPStroke := F.BoolVal;
  F := FWalk.DGetRef(G, 'op');
  if (F = nil) or (F.Kind <> pok_Bool) then
    F := FWalk.DGetRef(G, 'OP');
  if (F <> nil) and (F.Kind = pok_Bool) then
    FState.OPFill := F.BoolVal;
  F := FWalk.DGetRef(G, 'OPM');
  if F <> nil then
  begin
    if F.Kind = pok_Num then
    begin
      { an integer as such, then the low 32 bits; a real truncated toward
        zero. From 2^31 on the low bits of a real depend on how
        exactly its digits are read, which this reader does not promise on
        every compiler: not decided }
      if F.NumExact then
      begin
        FState.OPM := Narrow32(F.NumInt);
        FState.OPMKnown := True;
      end
      else if Abs(F.NumVal) < FWalk.FTwo31 then
      begin
        OpmValue := Trunc(F.NumVal);
        FState.OPM := Narrow32(OpmValue);
        FState.OPMKnown := True;
      end
      else
        FState.OPMKnown := False;
    end
    else if F.Kind = pok_Str then
      { the byte length of a string; this reader may not keep the bytes
        veraPDF reads (an ASCII85 token): not decided }
      FState.OPMKnown := False;
  end;
  F := FWalk.DGetRef(G, 'Font');
  if (F = nil) or (F.Kind <> pok_Arr) or (F.ArrCount = 0) then
    Exit;
  Font := FWalk.ResolveRef(F.ArrItem(0));
  if IsFontObject(FWalk, Font) then
  begin
    FState.Font := Font;
    FState.FontName := '';
  end;
end;

{ Tf: the font of the name (none if there is no font to build). }
procedure TInterpreter.SelectFont(AOps: TObjectList);
var
  V: TCv;
  Raw: TLandrixEInvoicePdfObject;
begin
  FState.Font := nil;
  if AOps.Count = 0 then
    Exit;
  V := TCv(AOps[0]);
  if V.Kind <> cvk_Name then
    Exit;
  FState.Font := Lookup('Font', V.Text, Raw);
  FState.FontName := V.Text;
end;

type
  { What veraPDF checks on a font object that a text operator shows (and on
    the descendant CIDFont of a Type 0 font), except where it depends on the
    text rendering mode: the findings Checks/Maybes/Texts; for 6.2.11.4.1-1
    whether it applies (Need), and the font program: none (Prog 0), one
    veraPDF may or may not parse (1), one it parses (2), one it builds but
    does not parse (3); 0 and 3 fail; Throws: veraPDF throws while building
    or checking the font.
    Modes: the text rendering modes it is shown with (1 mode 3, 2 another, 4
    not decided); veraPDF checks a font once, with the mode of its first
    use. }
  TFontFacts = class(TObject)
  public
    Checks: array of TLandrixEInvoicePdfContentCheck;
    Maybes: array of Boolean;
    Texts: array of string;
    Need: Boolean;
    Prog: Integer;
    Lbl: string;
    Throws: Boolean;
    Modes: Integer;
    { a TrueType program veraPDF shares between fonts with this key (the
      stream, symbolic, the /Encoding object or "direct"); EncOut the outcome
      of its encoding step (Prog, 4 for a throw); '' none }
    EncKey: string;
    EncOut: Integer;
    { shares its program with a font of another encoding outcome }
    Mixed: Boolean;
    { the glyph rules: 0 nothing to find (no program veraPDF parses), 1 not
      decided, 2 decided by Glyphs (TLandrixEInvoicePdfCidGlyphs, owned), 3
      only the glyph name not decided }
    GlyphKind: Integer;
    Glyphs: TObject;
    { the first parse and resource name the font is shown with; MultiCtx:
      also with another (veraPDF then judges some glyphs with a font object
      it has not parsed) }
    CtxParse: Integer;
    CtxName: AnsiString;
    CtxSet: Boolean;
    MultiCtx: Boolean;
    { the codes checked so far, per paint and unsure (4 bits a code) }
    Seen: array of Byte;
    { /W makes veraPDF throw when it reads the width of a glyph }
    WThrows: Boolean;
    destructor Destroy; override;
    procedure Add(ACheck: TLandrixEInvoicePdfContentCheck; AMaybe: Boolean; const AText: string);
  end;

destructor TFontFacts.Destroy;
begin
  Glyphs.Free;
  inherited Destroy;
end;

procedure TFontFacts.Add(ACheck: TLandrixEInvoicePdfContentCheck; AMaybe: Boolean; const AText: string);
var
  N: Integer;
begin
  N := Integer(Length(Checks));
  SetLength(Checks, N + 1);
  SetLength(Maybes, N + 1);
  SetLength(Texts, N + 1);
  Checks[N] := ACheck;
  Maybes[N] := AMaybe;
  Texts[N] := Lbl + AText;
end;

const
  { The standard 14 fonts by their /BaseFont. }
  Standard14: array[0..13] of AnsiString = ('Courier-Bold', 'Courier-BoldOblique', 'Courier', 'Courier-Oblique',
    'Helvetica', 'Helvetica-Bold', 'Helvetica-BoldOblique', 'Helvetica-Oblique', 'Symbol', 'Times-Bold',
    'Times-BoldItalic', 'Times-Italic', 'Times-Roman', 'ZapfDingbats');

  { The predefined CMaps veraPDF knows for PDF/A-2 and -3, with the ordering
    (registry Adobe) and supplement it gives them; also the names 6.2.11.3.3
    allows. }
  PredefCMaps: array[0..60] of AnsiString = ('GB-EUC-H', 'GB-EUC-V', 'GBpc-EUC-H', 'GBpc-EUC-V', 'GBK-EUC-H',
    'GBK-EUC-V', 'GBKp-EUC-H', 'GBKp-EUC-V', 'GBK2K-H', 'GBK2K-V', 'UniGB-UCS2-H', 'UniGB-UCS2-V', 'UniGB-UTF16-H',
    'UniGB-UTF16-V', 'B5pc-H', 'B5pc-V', 'HKscs-B5-H', 'HKscs-B5-V', 'ETen-B5-H', 'ETen-B5-V', 'ETenms-B5-H',
    'ETenms-B5-V', 'CNS-EUC-H', 'CNS-EUC-V', 'UniCNS-UCS2-H', 'UniCNS-UCS2-V', 'UniCNS-UTF16-H', 'UniCNS-UTF16-V',
    '83pv-RKSJ-H', '90ms-RKSJ-H', '90ms-RKSJ-V', '90msp-RKSJ-H', '90msp-RKSJ-V', '90pv-RKSJ-H', 'Add-RKSJ-H',
    'Add-RKSJ-V', 'EUC-H', 'EUC-V', 'Ext-RKSJ-H', 'Ext-RKSJ-V', 'H', 'V', 'UniJIS-UCS2-H', 'UniJIS-UCS2-V',
    'UniJIS-UCS2-HW-H', 'UniJIS-UCS2-HW-V', 'UniJIS-UTF16-H', 'UniJIS-UTF16-V', 'KSC-EUC-H', 'KSC-EUC-V',
    'KSCms-UHC-H', 'KSCms-UHC-V', 'KSCms-UHC-HW-H', 'KSCms-UHC-HW-V', 'KSCpc-EUC-H', 'UniKS-UCS2-H', 'UniKS-UCS2-V',
    'UniKS-UTF16-H', 'UniKS-UTF16-V', 'Identity-H', 'Identity-V');
  PredefOrdering: array[0..60] of AnsiString = ('GB1', 'GB1', 'GB1', 'GB1', 'GB1', 'GB1', 'GB1', 'GB1', 'GB1',
    'GB1', 'GB1', 'GB1', 'GB1', 'GB1', 'CNS1', 'CNS1', 'CNS1', 'CNS1', 'CNS1', 'CNS1', 'CNS1', 'CNS1', 'CNS1', 'CNS1',
    'CNS1', 'CNS1', 'CNS1', 'CNS1', 'Japan1', 'Japan1', 'Japan1', 'Japan1', 'Japan1', 'Japan1', 'Japan1', 'Japan1',
    'Japan1', 'Japan1', 'Japan1', 'Japan1', 'Japan1', 'Japan1', 'Japan1', 'Japan1', 'Japan1', 'Japan1', 'Japan1',
    'Japan1', 'Korea1', 'Korea1', 'Korea1', 'Korea1', 'Korea1', 'Korea1', 'Korea1', 'Korea1', 'Korea1', 'Korea1',
    'Korea1', 'Identity', 'Identity');
  PredefSupplement: array[0..60] of Integer = (0, 0, 0, 0, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 0, 0, 3, 3, 0, 0, 0, 0,
    0, 0, 3, 3, 4, 4, 1, 2, 2, 2, 2, 1, 1, 1, 1, 1, 2, 2, 1, 1, 4, 4, 4, 4, 5, 5, 0, 0, 1, 1, 1, 1, 0, 1, 1, 2, 2,
    0, 0);

function PredefIndex(const AName: AnsiString): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to Integer(High(PredefCMaps)) do
    if PredefCMaps[I] = AName then
    begin
      Result := I;
      Exit;
    end;
end;

{ A value as veraPDF reads it as text: 0 none (no name and no string), 1 the
  text AText (a name, or a string of printable ASCII), 2 not decided (a
  string with other bytes, which veraPDF decodes). With ANoName a name gives
  none, as for a string entry. }
function FontText(V: TLandrixEInvoicePdfObject; ANoName: Boolean; out AText: AnsiString): Integer;
var
  I: Integer;
begin
  Result := 0;
  AText := '';
  if V = nil then
    Exit;
  if V.Kind = pok_Name then
  begin
    if not ANoName then
    begin
      AText := V.NameVal;
      Result := 1;
    end;
    Exit;
  end;
  if V.Kind <> pok_Str then
    Exit;
  for I := 0 to Integer(Length(V.StrVal)) - 1 do
    if (V.StrVal[I] < $20) or (V.StrVal[I] > $7E) then
    begin
      Result := 2;
      Exit;
    end;
  SetLength(AText, Length(V.StrVal));
  for I := 0 to Integer(Length(V.StrVal)) - 1 do
    AText[I + 1] := AnsiChar(V.StrVal[I]);
  Result := 1;
end;

{ The font descriptor veraPDF takes: /FontDescriptor if it is a dictionary,
  else none. }
function FontDescriptor(AWalk: TLandrixEInvoicePdfContentWalk; D: TLandrixEInvoicePdfObject): TLandrixEInvoicePdfObject;
begin
  Result := AWalk.DGetRef(D, 'FontDescriptor');
  if (Result <> nil) and (Result.Kind <> pok_Dict) then
    Result := nil;
end;

function DescStream(AWalk: TLandrixEInvoicePdfContentWalk; ADesc: TLandrixEInvoicePdfObject;
  const AKey: AnsiString): TLandrixEInvoicePdfObject;
begin
  Result := AWalk.DGetRef(ADesc, AKey);
  if (Result <> nil) and (Result.Kind <> pok_Stream) then
    Result := nil;
end;

function SubtypeName(AWalk: TLandrixEInvoicePdfContentWalk; V: TLandrixEInvoicePdfObject): AnsiString;
var
  S: TLandrixEInvoicePdfObject;
begin
  Result := '';
  S := AWalk.DGetRef(V, 'Subtype');
  if (S <> nil) and (S.Kind = pok_Name) then
    Result := S.NameVal;
end;

{ Whether veraPDF builds a font program for the font dictionary D of the
  subtype ASub (Type1/MMType1 or TrueType; ACid: the descendant of a Type 0
  font, whatever its subtype): 0 none, 1 one it may or may not parse. Type 1
  takes /FontFile, else /FontFile3 with /Subtype /Type1C or /OpenType;
  TrueType /FontFile2, else any /FontFile3; a descendant /FontFile2 for
  CIDFontType2, else /FontFile3 with /Subtype /CIDFontType0C or /OpenType.
  The /FontFile3 path needs a /BaseFont name. AThrows: a /FontFile3 of a
  descendant whose /Subtype is no name. }
function FontProgram(AWalk: TLandrixEInvoicePdfContentWalk; D: TLandrixEInvoicePdfObject; const ASub: AnsiString;
  ACid: Boolean; out AThrows: Boolean): Integer;
var
  Desc, FF, S, Name, Raw: TLandrixEInvoicePdfObject;
  Sub3: AnsiString;
begin
  Result := 0;
  AThrows := False;
  Desc := FontDescriptor(AWalk, D);
  if Desc = nil then
    Exit;
  Name := AWalk.DGetRef(D, 'BaseFont');
  if not ACid and ((ASub = 'Type1') or (ASub = 'MMType1')) then
  begin
    if DescStream(AWalk, Desc, 'FontFile') <> nil then
      Result := 1
    else
    begin
      FF := DescStream(AWalk, Desc, 'FontFile3');
      Sub3 := SubtypeName(AWalk, FF);
      if (FF <> nil) and ((Sub3 = 'Type1C') or (Sub3 = 'OpenType')) and (Name <> nil) and
        (Name.Kind = pok_Name) then
        Result := 1;
    end;
    Exit;
  end;
  if not ACid and (ASub = 'TrueType') then
  begin
    if DescStream(AWalk, Desc, 'FontFile2') <> nil then
      Result := 1
    else if (DescStream(AWalk, Desc, 'FontFile3') <> nil) and (Name <> nil) and (Name.Kind = pok_Name) then
      Result := 1;
    Exit;
  end;
  { a CIDFont }
  if (DescStream(AWalk, Desc, 'FontFile2') <> nil) and (ASub = 'CIDFontType2') then
  begin
    Result := 1;
    Exit;
  end;
  FF := DescStream(AWalk, Desc, 'FontFile3');
  if FF = nil then
    Exit;
  S := AWalk.DGetRef(FF, 'Subtype');
  Raw := AWalk.DictGet(FF, 'Subtype');
  if ((S <> nil) and (S.Kind <> pok_Name) and (S.Kind <> pok_Null)) or
    ((Raw <> nil) and (Raw.Kind = pok_Ref) and ((S = nil) or (S.Kind = pok_Null))) then
  begin
    AThrows := True;
    Exit;
  end;
  if (S <> nil) and (S.Kind = pok_Name) and ((S.NameVal = 'CIDFontType0C') or (S.NameVal = 'OpenType')) and
    (Name <> nil) and (Name.Kind = pok_Name) then
    Result := 1;
end;

{ 6.2.11.2-1, -3 and -7 on the font dictionary D (Type 3: no name needed). }
procedure FontCommon(AWalk: TLandrixEInvoicePdfContentWalk; F: TFontFacts; D: TLandrixEInvoicePdfObject;
  AType3: Boolean);
var
  V, Desc, FF: TLandrixEInvoicePdfObject;
begin
  V := AWalk.DGetRef(D, 'Type');
  if (V = nil) or (V.Kind <> pok_Name) or (V.NameVal <> 'Font') then
    F.Add(pcc_FontType, False, ' has no /Type /Font');
  V := AWalk.DGetRef(D, 'BaseFont');
  if not AType3 and ((V = nil) or (V.Kind <> pok_Name)) then
    F.Add(pcc_FontName, False, ' has no /BaseFont name');
  Desc := FontDescriptor(AWalk, D);
  if Desc = nil then
    Exit;
  FF := DescStream(AWalk, Desc, 'FontFile');
  if FF = nil then
    FF := DescStream(AWalk, Desc, 'FontFile2');
  if FF = nil then
    FF := DescStream(AWalk, Desc, 'FontFile3');
  if FF = nil then
    Exit;
  V := AWalk.DGetRef(FF, 'Subtype');
  if (V <> nil) and (V.Kind = pok_Name) and not InList(V.NameVal, ['Type1C', 'CIDFontType0C', 'OpenType']) then
    F.Add(pcc_FontFileSubtype, False, ' font program /Subtype /' + TextOf(V.NameVal));
end;

{ 6.2.11.2-4 to -6 on a simple font: /FirstChar, /LastChar (numbers, or
  strings by their length) and /Widths with LastChar - FirstChar + 1
  entries (a missing one counts as 0), unless veraPDF takes the font as a
  standard one (AStandard 2; 1 not decided). }
procedure FontWidths(AWalk: TLandrixEInvoicePdfContentWalk; F: TFontFacts; D: TLandrixEInvoicePdfObject;
  AStandard: Integer);
var
  V: TLandrixEInvoicePdfObject;
  First, Last: Int64;
  HasFirst, HasLast, Maybe: Boolean;
begin
  if AStandard = 2 then
    Exit;
  Maybe := AStandard = 1;
  HasFirst := IntegerOf(AWalk.DGetRef(D, 'FirstChar'), First);
  HasLast := IntegerOf(AWalk.DGetRef(D, 'LastChar'), Last);
  if not HasFirst then
  begin
    F.Add(pcc_FirstChar, Maybe, ' has no /FirstChar');
    First := 0;
  end;
  if not HasLast then
  begin
    F.Add(pcc_LastChar, Maybe, ' has no /LastChar');
    Last := 0;
  end;
  V := AWalk.DGetRef(D, 'Widths');
  if (V = nil) or (V.Kind <> pok_Arr) then
    F.Add(pcc_Widths, Maybe, ' has no /Widths array')
  else if (First > 1000000000000) or (First < -1000000000000) or (Last > 1000000000000) or
    (Last < -1000000000000) then
    F.Add(pcc_Widths, True, ' /FirstChar or /LastChar beyond what is decided')
  else if V.ArrCount <> Last - First + 1 then
    F.Add(pcc_Widths, Maybe, ' /Widths has ' + IntToStr(V.ArrCount) + ' entries for ' + IntToStr(Last - First + 1) +
      ' codes');
end;

{ Symbolic as veraPDF reads it: bit 3 of the descriptor's /Flags. }
function FontSymbolic(AWalk: TLandrixEInvoicePdfContentWalk; D: TLandrixEInvoicePdfObject): Boolean;
var
  Desc: TLandrixEInvoicePdfObject;
  Flags: Int64;
begin
  Desc := FontDescriptor(AWalk, D);
  Result := (Desc <> nil) and IntegerOf(AWalk.DGetRef(Desc, 'Flags'), Flags) and (Narrow32(Flags) and 4 <> 0);
end;

{ The TrueType program of the stream AStream, read once; nil where its data
  are not decided (or the decoding budget is spent). }
function TrueTypeOf(AWalk: TLandrixEInvoicePdfContentWalk;
  AStream: TLandrixEInvoicePdfObject): TLandrixEInvoicePdfTrueTypeProgram;
var
  Key: string;
  Idx: Integer;
  Data: TLandrixEInvoicePdfBytes;
begin
  Key := AWalk.ObjId(AStream);
  if AWalk.FTrueTypeCache.Find(Key, Idx) then
  begin
    Result := TLandrixEInvoicePdfTrueTypeProgram(AWalk.FTrueTypeCache.Objects[Idx]);
    Exit;
  end;
  Result := nil;
  Data := nil;
  if not AWalk.FBudgetSpent and AWalk.StreamBytes(AStream, Data) then
  begin
    Inc(AWalk.FTotalBytes, Int64(Length(Data)));
    if AWalk.FTotalBytes > MaxTotalBytes then
    begin
      AWalk.FBudgetSpent := True;
      AWalk.FIncomplete := True;
    end
    else
    begin
      Result := TLandrixEInvoicePdfTrueTypeProgram.Create(Data, Length(Data) < LandrixEInvoicePdfFontMemoryLimit);
      { the cmap entries count against the same budget }
      Inc(AWalk.FTotalBytes, 4 * Result.Work);
      if AWalk.FTotalBytes > MaxTotalBytes then
      begin
        AWalk.FBudgetSpent := True;
        AWalk.FIncomplete := True;
      end;
    end;
  end;
  AWalk.FTrueTypeCache.AddObject(Key, Result);
end;

{ The state of a TrueType program as Prog (TFontFacts) and AThrows: an
  accepted program is parsed (2), a rejected one built but not parsed (3). }
function TrueTypeProg(P: TLandrixEInvoicePdfTrueTypeProgram; var AThrows: Boolean): Integer;
begin
  Result := 1;
  if P = nil then
    Exit;
  case P.Load of
    pfl_Accepted:
      Result := 2;
    pfl_Rejected:
      Result := 3;
    pfl_Throws:
      AThrows := True;
  else
    { not decided: 1 }
  end;
end;

{ After reading a TrueType program, veraPDF builds the code-to-name table
  of a non-symbolic font with /Encoding: a name other than MacRomanEncoding
  or WinAnsiEncoding, or a value that is no dictionary, makes it count as
  not parsed (3); a /Differences code below -1 (after narrowing to 32 bits)
  makes it throw. }
function TrueTypeEncodingProg(AWalk: TLandrixEInvoicePdfContentWalk; D: TLandrixEInvoicePdfObject;
  AProg: Integer; var AThrows: Boolean): Integer;
var
  Raw, E, A, It: TLandrixEInvoicePdfObject;
  I: Integer;
  Code: Int64;
begin
  Result := AProg;
  if (AProg <> 2) or FontSymbolic(AWalk, D) then
    Exit;
  Raw := AWalk.DictGet(D, 'Encoding');
  if (Raw = nil) or (Raw.Kind = pok_Null) then
    Exit;
  E := AWalk.ResolveRef(Raw);
  if (E <> nil) and (E.Kind = pok_Name) then
  begin
    if (E.NameVal <> 'MacRomanEncoding') and (E.NameVal <> 'WinAnsiEncoding') then
      Result := 3;
    Exit;
  end;
  if (E = nil) or (E.Kind <> pok_Dict) then
  begin
    Result := 3;
    Exit;
  end;
  A := AWalk.DGetRef(E, 'Differences');
  if (A = nil) or (A.Kind <> pok_Arr) then
    Exit;
  Code := 0;
  for I := 0 to A.ArrCount - 1 do
  begin
    It := AWalk.ResolveRef(A.ArrItem(I));
    if It = nil then
      Continue;
    if (It.Kind = pok_Num) and It.NumExact then
      Code := Narrow32(It.NumInt)
    else if (It.Kind = pok_Name) and (Code <> -1) then
    begin
      if Code < -1 then
      begin
        AThrows := True;
        Exit;
      end;
      Code := Narrow32(Code + 1);
    end;
  end;
end;

{ 6.2.11.6-1 and -4 on the parsed TrueType program of a simple font: a
  non-symbolic font has a cmap subtable (two with a (3,0) one); a symbolic
  one has one subtable or a (3,0) one. }
procedure TrueTypeCmapRules(F: TFontFacts; P: TLandrixEInvoicePdfTrueTypeProgram; ASymbolic: Boolean);
var
  Has30: Boolean;
begin
  Has30 := P.HasCmapFor(3, 0);
  if not ASymbolic and ((Has30 and (P.CmapCount <= 1)) or (not Has30 and (P.CmapCount <= 0))) then
    F.Add(pcc_TrueTypeCmaps, False, ' TrueType program of a non-symbolic font without a usable cmap subtable');
  if ASymbolic and (P.CmapCount <> 1) and not Has30 then
    F.Add(pcc_SymbolicCmaps, False, ' TrueType program of a symbolic font with ' + IntToStr(P.CmapCount) +
      ' cmap subtables and none (3,0)');
end;

{ 6.2.11.6-2 and -3 on a TrueType font: a non-symbolic one has the encoding
  MacRomanEncoding or WinAnsiEncoding (the name, or the /BaseEncoding of an
  encoding dictionary) and, with /Differences, a font program with a (3,1)
  cmap and glyph names of the Adobe Glyph List (not decided where there is
  a program); a symbolic one has no encoding. Symbolic: bit 3 of the
  descriptor's /Flags. }
procedure FontTrueType(AWalk: TLandrixEInvoicePdfContentWalk; F: TFontFacts; D: TLandrixEInvoicePdfObject;
  AProg: Integer; AProgram: TLandrixEInvoicePdfTrueTypeProgram);
var
  Desc, E, V: TLandrixEInvoicePdfObject;
  Flags: Int64;
  Symbolic: Boolean;
  Enc: AnsiString;
  EncKind: Integer;
begin
  Desc := FontDescriptor(AWalk, D);
  Symbolic := (Desc <> nil) and IntegerOf(AWalk.DGetRef(Desc, 'Flags'), Flags) and (Narrow32(Flags) and 4 <> 0);
  E := AWalk.DGetRef(D, 'Encoding');
  { veraPDF reads /BaseEncoding of any /Encoding that is no name for
    6.2.11.6-2 and throws on one that is no dictionary }
  V := AWalk.DictGet(D, 'Encoding');
  if (V <> nil) and (V.Kind <> pok_Null) and ((E = nil) or not ((E.Kind = pok_Name) or E.IsDictLike)) then
  begin
    F.Throws := True;
    Exit;
  end;
  EncKind := 0;
  Enc := '';
  if E <> nil then
  begin
    if E.Kind = pok_Name then
    begin
      Enc := E.NameVal;
      EncKind := 1;
    end
    else if E.IsDictLike then
      EncKind := FontText(AWalk.DGetRef(E, 'BaseEncoding'), False, Enc);
  end;
  if Symbolic then
  begin
    if EncKind = 1 then
      F.Add(pcc_TrueTypeSymbolic, False, ' is symbolic and has an encoding')
    else if EncKind = 2 then
      F.Add(pcc_TrueTypeSymbolic, True, ' is symbolic and may have an encoding');
    Exit;
  end;
  if EncKind = 2 then
  begin
    F.Add(pcc_TrueTypeEncoding, True, ' encoding not decided');
    Exit;
  end;
  if (EncKind = 0) or ((Enc <> 'MacRomanEncoding') and (Enc <> 'WinAnsiEncoding')) then
  begin
    F.Add(pcc_TrueTypeEncoding, False, ' is not symbolic and has neither MacRomanEncoding nor WinAnsiEncoding');
    Exit;
  end;
  if (E = nil) or (E.Kind <> pok_Dict) then
    Exit;
  V := AWalk.DictGet(E, 'Differences');
  if V = nil then
    Exit;
  if V.Kind = pok_Null then
    F.Add(pcc_TrueTypeEncoding, True, ' /Differences null')
  else if AProg = 1 then
    F.Add(pcc_TrueTypeEncoding, True, ' /Differences with a font program')
  else if AProg = 3 then
    F.Add(pcc_TrueTypeEncoding, False, ' /Differences with a font program veraPDF does not parse')
  else if (AProg = 2) and (AProgram <> nil) and not AProgram.HasCmapFor(3, 1) then
    F.Add(pcc_TrueTypeEncoding, False, ' /Differences with a font program without a (3,1) cmap')
  else if AProg = 2 then
    { the glyph names of /Differences: not decided yet }
    F.Add(pcc_TrueTypeEncoding, True, ' /Differences with a (3,1) cmap');
end;

{ The CIDSystemInfo veraPDF takes for the /Encoding E of a Type 0 font: a
  predefined CMap by its name, otherwise E's /CIDSystemInfo dictionary (or
  the first element of an array). AKnown False: no such dictionary. }
procedure CMapSystemInfo(AWalk: TLandrixEInvoicePdfContentWalk; E: TLandrixEInvoicePdfObject;
  out AKnown: Boolean; out AReg, AOrd: AnsiString; out ARegKind, AOrdKind: Integer; out ASup: Int64);
var
  I: Integer;
  Info: TLandrixEInvoicePdfObject;
begin
  AKnown := False;
  AReg := '';
  AOrd := '';
  ARegKind := 0;
  AOrdKind := 0;
  ASup := 0;
  if E = nil then
    Exit;
  if E.Kind = pok_Name then
  begin
    AKnown := True;
    I := PredefIndex(E.NameVal);
    if I < 0 then
      Exit;
    AReg := 'Adobe';
    ARegKind := 1;
    AOrd := PredefOrdering[I];
    AOrdKind := 1;
    ASup := PredefSupplement[I];
    Exit;
  end;
  if not E.IsDictLike then
    Exit;
  Info := AWalk.DGetRef(E, 'CIDSystemInfo');
  if (Info <> nil) and (Info.Kind = pok_Arr) then
    if Info.ArrCount > 0 then
      Info := AWalk.ResolveRef(Info.ArrItem(0))
    else
      Info := nil;
  if (Info = nil) or (Info.Kind <> pok_Dict) then
    Exit;
  AKnown := True;
  ARegKind := FontText(AWalk.DGetRef(Info, 'Registry'), True, AReg);
  AOrdKind := FontText(AWalk.DGetRef(Info, 'Ordering'), True, AOrd);
  if not IntegerOf(AWalk.DGetRef(Info, 'Supplement'), ASup) then
    ASup := 0;
end;

{ 6.2.11.3.3-1 and -3 on a CMap named by /UseCMap (ARaw) and the ones it
  names in turn: -3 needs the name of a predefined CMap (a name, or the
  /CMapName of a stream), -1 also takes an embedded CMap stream. }
procedure FontUseCMap(AWalk: TLandrixEInvoicePdfContentWalk; F: TFontFacts; ARaw: TLandrixEInvoicePdfObject);
var
  V: TLandrixEInvoicePdfObject;
  Depth, Kind: Integer;
  Seen: TObjectList;
  Name: AnsiString;
begin
  Seen := TObjectList.Create(False);
  try
    Depth := 0;
    while ARaw <> nil do
    begin
      Inc(Depth);
      if Depth > 16 then
      begin
        F.Add(pcc_UseCMapName, True, ' /UseCMap chain too long');
        F.Add(pcc_CMapName, True, ' /UseCMap chain too long');
        Exit;
      end;
      if ARaw.Kind = pok_Null then
      begin
        F.Add(pcc_UseCMapName, True, ' /UseCMap null');
        F.Add(pcc_CMapName, True, ' /UseCMap null');
        Exit;
      end;
      V := AWalk.ResolveRef(ARaw);
      if (V <> nil) and (Seen.IndexOf(V) >= 0) then
        Exit;
      Seen.Add(V);
      Kind := 0;
      Name := '';
      if V <> nil then
        if V.Kind = pok_Name then
        begin
          Name := V.NameVal;
          Kind := 1;
        end
        else if V.Kind = pok_Stream then
          Kind := FontText(AWalk.DGetRef(V, 'CMapName'), False, Name);
      if Kind = 2 then
        F.Add(pcc_UseCMapName, True, ' /UseCMap CMap name not decided')
      else if PredefIndex(Name) < 0 then
        F.Add(pcc_UseCMapName, False, ' /UseCMap names CMap /' + TextOf(Name) + ', which is not predefined');
      if ((V = nil) or (V.Kind <> pok_Stream)) and (PredefIndex(Name) < 0) then
        F.Add(pcc_CMapName, False, ' /UseCMap names no predefined or embedded CMap');
      if (V = nil) or not V.IsDictLike then
        Exit;
      ARaw := AWalk.DictGet(V, 'UseCMap');
    end;
  finally
    Seen.Free;
  end;
end;

{ The widths of /W as veraPDF reads them: groups of a first CID and either
  an array of widths (numbers only) or a last CID and one width; a group
  that does not start with an integer makes veraPDF throw (AThrows), one
  whose width is missing or no number ends the reading; a real first CID
  is not decided (AUnsure). }
procedure CidWidths(AWalk: TLandrixEInvoicePdfContentWalk; G: TLandrixEInvoicePdfCidGlyphs;
  W: TLandrixEInvoicePdfObject; var AThrows, AUnsure: Boolean);
var
  I, J: Integer;
  First, Item, Width: TLandrixEInvoicePdfObject;
  CidBegin, CidEnd: Int64;
begin
  I := 0;
  while I < W.ArrCount do
  begin
    First := AWalk.ResolveRef(W.ArrItem(I));
    Inc(I);
    if (First <> nil) and (First.Kind = pok_Str) then
    begin
      { read as its length: not modelled }
      AUnsure := True;
      Exit;
    end;
    if (First = nil) or (First.Kind <> pok_Num) then
    begin
      AThrows := True;
      Exit;
    end;
    if not First.NumExact then
    begin
      AUnsure := True;
      Exit;
    end;
    CidBegin := Narrow32(First.NumInt);
    Item := nil;
    if I < W.ArrCount then
      Item := AWalk.ResolveRef(W.ArrItem(I));
    if (Item <> nil) and (Item.Kind = pok_Num) and not Item.NumExact then
    begin
      { a real, or an integer beyond 64 bits that veraPDF reads as an
        integer: not decided }
      AUnsure := True;
      Exit;
    end;
    if (Item <> nil) and (Item.Kind = pok_Num) and Item.NumExact then
    begin
      CidEnd := Narrow32(Item.NumInt);
      Inc(I);
      Width := nil;
      if I < W.ArrCount then
        Width := AWalk.ResolveRef(W.ArrItem(I));
      if (Width = nil) or (Width.Kind <> pok_Num) then
        Exit;
      if G <> nil then
        G.AddRange(CidBegin, CidEnd, Width.NumVal);
    end
    else if (Item <> nil) and (Item.Kind = pok_Arr) then
      for J := 0 to Item.ArrCount - 1 do
      begin
        Width := AWalk.ResolveRef(Item.ArrItem(J));
        if (Width <> nil) and (Width.Kind = pok_Num) and (G <> nil) then
          G.AddSingle(CidBegin + J, Width.NumVal);
      end;
    Inc(I);
  end;
end;

{ The glyph rules for a Type 0 font T with the descendant D: decided for an
  Identity CMap over a CIDFontType2 font whose TrueType program veraPDF
  parses (AProg 2); nothing to find without such a program; else not
  decided. }
procedure CidGlyphKind(AWalk: TLandrixEInvoicePdfContentWalk; F: TFontFacts; T, D: TLandrixEInvoicePdfObject;
  const ASub: AnsiString; AProg: Integer);
var
  E, FF, V, Dw: TLandrixEInvoicePdfObject;
  TT: TLandrixEInvoicePdfTrueTypeProgram;
  Data: TLandrixEInvoicePdfBytes;
  Gids: array of Integer;
  G: TLandrixEInvoicePdfCidGlyphs;
  I, N: Integer;
  Identity, Throws, Unsure: Boolean;
  DefW: Double;
begin
  if (D = nil) or (AProg = 0) or (AProg = 3) then
  begin
    F.GlyphKind := 0;
    Exit;
  end;
  F.GlyphKind := 1;
  { veraPDF reads /W for the glyphs of any Type 0 font with a program }
  V := AWalk.DGetRef(D, 'W');
  if (V <> nil) and (V.Kind = pok_Arr) then
  begin
    Throws := False;
    Unsure := False;
    CidWidths(AWalk, nil, V, Throws, Unsure);
    if Throws then
    begin
      F.WThrows := True;
      Exit;
    end;
  end;
  E := AWalk.DGetRef(T, 'Encoding');
  FF := DescStream(AWalk, FontDescriptor(AWalk, D), 'FontFile2');
  if (AProg <> 2) or (ASub <> 'CIDFontType2') or (FF = nil) or (E = nil) or (E.Kind <> pok_Name) or
    ((E.NameVal <> 'Identity-H') and (E.NameVal <> 'Identity-V')) then
    Exit;
  TT := TrueTypeOf(AWalk, FF);
  if (TT = nil) or (TT.Load <> pfl_Accepted) then
    Exit;
  Gids := nil;
  Data := nil;
  Identity := True;
  V := AWalk.DGetRef(D, 'CIDToGIDMap');
  if (V <> nil) and (V.Kind = pok_Stream) then
  begin
    if not AWalk.StreamBytes(V, Data) then
      Exit;
    Identity := False;
    N := (Integer(Length(Data)) + 1) div 2;
    SetLength(Gids, N);
    for I := 0 to N - 1 do
      if 2 * I + 1 < Integer(Length(Data)) then
        Gids[I] := Data[2 * I] * 256 + Data[2 * I + 1]
      else
        Gids[I] := Data[2 * I] * 256;
  end;
  DefW := 1000;
  Dw := AWalk.DGetRef(D, 'DW');
  if (Dw <> nil) and (Dw.Kind = pok_Num) then
    DefW := Dw.NumVal;
  G := TLandrixEInvoicePdfCidGlyphs.Create(TT, Identity, Gids, DefW);
  F.Glyphs := G;
  V := AWalk.DGetRef(D, 'W');
  Throws := False;
  Unsure := False;
  if (V <> nil) and (V.Kind = pok_Arr) then
    CidWidths(AWalk, G, V, Throws, Unsure);
  { the tables and the work count against the decoding budget }
  Inc(AWalk.FTotalBytes, Int64(Length(Data)) + 12 * Int64(G.TableSize) + G.Work);
  if AWalk.FTotalBytes > MaxTotalBytes then
  begin
    AWalk.FBudgetSpent := True;
    AWalk.FIncomplete := True;
  end
  else if Throws then
    F.WThrows := True
  else if not Unsure and not G.Unsure then
    F.GlyphKind := 2;
end;

{ 6.2.11.3.1-1, 6.2.11.3.3-1 and -3 on a Type 0 font T, and 6.2.11.2-1 to
  -3 and -7, 6.2.11.3.2-1 and 6.2.11.4.1-1 on its descendant CIDFont D
  (veraPDF also takes the Type 0 font's /Type, name and descriptor from D). }
procedure FontType0(AWalk: TLandrixEInvoicePdfContentWalk; F: TFontFacts; T: TLandrixEInvoicePdfObject);
var
  A, D, E, V, Info, FF: TLandrixEInvoicePdfObject;
  Data: TLandrixEInvoicePdfBytes;
  Sub, Name, CReg, COrd, FReg, FOrd: AnsiString;
  NameKind, RegKind, OrdKind, FRegKind, FOrdKind: Integer;
  Known, Throws: Boolean;
  Sup, FSup: Int64;
  Prog: Integer;
begin
  D := nil;
  A := AWalk.DGetRef(T, 'DescendantFonts');
  if (A <> nil) and (A.Kind = pok_Arr) and (A.ArrCount > 0) then
  begin
    D := AWalk.ResolveRef(A.ArrItem(0));
    if (D <> nil) and (D.Kind <> pok_Dict) then
      D := nil;
  end;
  if D = nil then
  begin
    F.Add(pcc_FontType, False, ' has no descendant font with /Type /Font');
    F.Add(pcc_FontName, False, ' has no descendant font with a /BaseFont name');
  end
  else
  begin
    FontCommon(AWalk, F, D, False);
    Sub := SubtypeName(AWalk, D);
    if not InList(Sub, ['Type1', 'MMType1', 'TrueType', 'Type3', 'Type0', 'CIDFontType0', 'CIDFontType2']) then
      F.Add(pcc_FontSubtype, False, ' descendant font has no /Subtype of ISO 32000-1');
    Prog := FontProgram(AWalk, D, Sub, True, Throws);
    if Throws then
      F.Throws := True;
    if (Sub = 'CIDFontType2') and (Prog = 1) then
    begin
      FF := DescStream(AWalk, FontDescriptor(AWalk, D), 'FontFile2');
      V := AWalk.DGetRef(D, 'CIDToGIDMap');
      { veraPDF reads a /CIDToGIDMap stream when it builds the program }
      Data := nil;
      if (FF <> nil) and not ((V <> nil) and (V.Kind = pok_Stream) and not AWalk.StreamBytes(V, Data)) then
      begin
        Inc(AWalk.FTotalBytes, Int64(Length(Data)));
        Throws := False;
        Prog := TrueTypeProg(TrueTypeOf(AWalk, FF), Throws);
        if Throws then
          F.Throws := True;
      end;
    end;
    F.Need := (Sub <> 'Type3') and (Sub <> 'Type0');
    F.Prog := Prog;
    { 6.2.11.4.2-2 reads the name of a CIDFont with a program it parses:
      none makes veraPDF throw }
    V := AWalk.DGetRef(D, 'BaseFont');
    if ((Prog = 1) or (Prog = 2)) and ((V = nil) or (V.Kind <> pok_Name)) then
      F.Throws := True;
    CidGlyphKind(AWalk, F, T, D, Sub, Prog);
    if (Sub = 'CIDFontType2') and ((Prog = 1) or (Prog = 2)) then
    begin
      V := AWalk.DGetRef(D, 'CIDToGIDMap');
      if (V = nil) or not ((V.Kind = pok_Stream) or ((V.Kind = pok_Name) and (V.NameVal = 'Identity'))) then
        { fails only where veraPDF parses the font program }
        F.Add(pcc_CidToGid, Prog = 1, ' CIDFontType2 without /CIDToGIDMap');
    end;
  end;
  E := AWalk.DGetRef(T, 'Encoding');
  { veraPDF reads the CIDSystemInfo of any /Encoding for 6.2.11.3.1-1 and
    throws on one that is neither a name nor a dictionary }
  V := AWalk.DictGet(T, 'Encoding');
  if (V <> nil) and (V.Kind <> pok_Null) and ((E = nil) or not ((E.Kind = pok_Name) or E.IsDictLike)) then
    F.Throws := True;
  { the CMap name: a name, or /CMapName of a stream }
  NameKind := 0;
  Name := '';
  if E <> nil then
    if E.Kind = pok_Name then
    begin
      Name := E.NameVal;
      NameKind := 1;
    end
    else if E.Kind = pok_Stream then
      NameKind := FontText(AWalk.DGetRef(E, 'CMapName'), False, Name);
  { 6.2.11.3.3-1 }
  if (E = nil) or (E.Kind <> pok_Stream) then
    if NameKind = 2 then
      F.Add(pcc_CMapName, True, ' CMap name not decided')
    else if PredefIndex(Name) < 0 then
      F.Add(pcc_CMapName, False, ' CMap /' + TextOf(Name) + ' is neither predefined nor embedded');
  if (E <> nil) and E.IsDictLike then
    FontUseCMap(AWalk, F, AWalk.DictGet(E, 'UseCMap'));
  { 6.2.11.3.1-1 }
  if NameKind = 2 then
  begin
    F.Add(pcc_CidSystemInfo, True, ' CMap name not decided');
    Exit;
  end;
  if (NameKind = 1) and ((Name = 'Identity-H') or (Name = 'Identity-V')) then
    Exit;
  FRegKind := 0;
  FOrdKind := 0;
  FReg := '';
  FOrd := '';
  FSup := 0;
  if D <> nil then
  begin
    Info := AWalk.DGetRef(D, 'CIDSystemInfo');
    if (Info <> nil) and Info.IsDictLike then
    begin
      FRegKind := FontText(AWalk.DGetRef(Info, 'Registry'), True, FReg);
      FOrdKind := FontText(AWalk.DGetRef(Info, 'Ordering'), True, FOrd);
      if not IntegerOf(AWalk.DGetRef(Info, 'Supplement'), FSup) then
        FSup := 0;
    end;
  end;
  CMapSystemInfo(AWalk, E, Known, CReg, COrd, RegKind, OrdKind, Sup);
  if (FRegKind = 2) or (FOrdKind = 2) or (RegKind = 2) or (OrdKind = 2) then
    F.Add(pcc_CidSystemInfo, True, ' CIDSystemInfo not decided')
  else if (FOrdKind = 0) or (FRegKind = 0) or not Known or (OrdKind = 0) or (RegKind = 0) or (FOrd <> COrd) or
    (FReg <> CReg) or (FSup > Sup) then
    F.Add(pcc_CidSystemInfo, False, ' CIDSystemInfo of the CIDFont and the CMap differ');
end;

{ The facts of the font F, once per font object. }
function FontFactsOf(AWalk: TLandrixEInvoicePdfContentWalk; F: TLandrixEInvoicePdfObject): TFontFacts;
var
  Key: string;
  Sub: AnsiString;
  Idx, Prog, Std: Integer;
  V, FF, Raw: TLandrixEInvoicePdfObject;
  TT: TLandrixEInvoicePdfTrueTypeProgram;
  Throws: Boolean;
begin
  Key := AWalk.ObjId(F);
  if AWalk.FFontCache.Find(Key, Idx) then
  begin
    Result := TFontFacts(AWalk.FFontCache.Objects[Idx]);
    Exit;
  end;
  Result := TFontFacts.Create;
  AWalk.FFontCache.AddObject(Key, Result);
  V := AWalk.DGetRef(F, 'BaseFont');
  if (V <> nil) and (V.Kind = pok_Name) then
    Result.Lbl := 'font /' + TextOf(V.NameVal)
  else
    Result.Lbl := 'font';
  Sub := SubtypeName(AWalk, F);
  if Sub = 'Type0' then
  begin
    FontType0(AWalk, Result, F);
    Exit;
  end;
  FontCommon(AWalk, Result, F, Sub = 'Type3');
  if Sub = 'Type3' then
  begin
    Result.GlyphKind := 1;
    FontWidths(AWalk, Result, F, 0);
    Exit;
  end;
  Prog := FontProgram(AWalk, F, Sub, False, Throws);
  if Throws then
    Result.Throws := True;
  TT := nil;
  if (Sub = 'TrueType') and (Prog = 1) then
  begin
    FF := DescStream(AWalk, FontDescriptor(AWalk, F), 'FontFile2');
    if FF <> nil then
    begin
      TT := TrueTypeOf(AWalk, FF);
      Throws := False;
      Prog := TrueTypeEncodingProg(AWalk, F, TrueTypeProg(TT, Throws), Throws);
      if Throws then
        Result.Throws := True;
      { veraPDF reads a program once for all fonts with the same stream,
        symbolic flag and /Encoding object (any direct one counts as the
        same), with the encoding of the font it meets first }
      Raw := AWalk.DictGet(F, 'Encoding');
      if (Raw <> nil) and (Raw.Kind = pok_Ref) then
        Result.EncKey := IntToStr(AWalk.LastRefNum(Raw))
      else if Raw <> nil then
        Result.EncKey := 'direct'
      else
        Result.EncKey := 'none';
      Result.EncKey := AWalk.ObjId(FF) + '/' + IntToStr(Ord(FontSymbolic(AWalk, F))) + '/' + Result.EncKey;
      if Throws then
        Result.EncOut := 4
      else
        Result.EncOut := Prog;
    end;
  end;
  Result.Need := True;
  Result.Prog := Prog;
  { the glyph names of simple fonts are not decided yet; presence and widths
    need a program veraPDF parses }
  if (Prog = 0) or (Prog = 3) then
    Result.GlyphKind := 3
  else
    Result.GlyphKind := 1;
  { 6.2.11.4.2-1 reads the name of a Type 1 font with a program it parses:
    none makes veraPDF throw }
  if ((Sub = 'Type1') or (Sub = 'MMType1')) and (Prog = 1) and ((V = nil) or (V.Kind <> pok_Name)) then
    Result.Throws := True;
  Std := 0;
  if (Sub = 'Type1') or (Sub = 'MMType1') then
    if (V <> nil) and (V.Kind = pok_Name) and InList(V.NameVal, Standard14) then
      if Prog = 0 then
        Std := 2
      else
        { veraPDF takes the font as standard only without a program, which
          a stream it cannot decode leaves out }
        Std := 1;
  FontWidths(AWalk, Result, F, Std);
  if Sub = 'TrueType' then
  begin
    FontTrueType(AWalk, Result, F, Prog, TT);
    if (Prog = 2) and (TT <> nil) then
      TrueTypeCmapRules(Result, TT, FontSymbolic(AWalk, F))
    else if (Prog = 1) and FontSymbolic(AWalk, F) then
      Result.Add(pcc_SymbolicCmaps, True, ' cmap subtables of a program not decided')
    else if Prog = 1 then
      Result.Add(pcc_TrueTypeCmaps, True, ' cmap subtables of a program not decided');
  end;
end;

{ 6.2.11: the font of a text operator as veraPDF checks it; no font makes
  veraPDF throw. 6.2.11.4.1-1 does not apply with rendering mode 3.
  DE: 6.2.11: die Schrift eines Textoperators, wie veraPDF sie prueft;
  ohne Schrift wirft veraPDF eine Ausnahme. 6.2.11.4.1-1 gilt nicht bei
  Darstellungsmodus 3. }
procedure TInterpreter.CheckFont;
var
  Facts: TFontFacts;
  I, N: Integer;
begin
  if FState.Font = nil then
  begin
    FWalk.FThrows := True;
    FWalk.FMayThrow := True;
    FWalk.FIncomplete := True;
    Exit;
  end;
  Facts := FontFactsOf(FWalk, FState.Font);
  if FState.FontName = '' then
    Facts.MultiCtx := True
  else if not Facts.CtxSet then
  begin
    Facts.CtxSet := True;
    Facts.CtxParse := FParseIndex;
    Facts.CtxName := FState.FontName;
  end
  else if (Facts.CtxParse <> FParseIndex) or (Facts.CtxName <> FState.FontName) then
    Facts.MultiCtx := True;
  if FState.TextMode = 3 then
    Facts.Modes := Facts.Modes or 1
  else if FState.TextMode < 0 then
    Facts.Modes := Facts.Modes or 4
  else
    Facts.Modes := Facts.Modes or 2;
  if SeenBefore('T' + FWalk.ObjId(FState.Font) + '/' + IntToStr(FState.TextMode)) then
    Exit;
  if Facts.Throws then
  begin
    FWalk.FThrows := True;
    FWalk.FMayThrow := True;
    FWalk.FIncomplete := True;
  end;
  for I := 0 to Integer(Length(Facts.Checks)) - 1 do
  begin
    N := FWalk.FFCount;
    Mark(Facts.Checks[I], Facts.Maybes[I], Facts.Texts[I]);
    if not Facts.Maybes[I] and (FWalk.FFCount > N) then
      FWalk.AddFontMark(N, Facts);
  end;
  if not Facts.Need or (FState.TextMode = 3) or (Facts.Prog = 2) then
    Exit;
  if Facts.Prog = 1 then
    Mark(pcc_FontEmbedded, True, Facts.Lbl + ': whether veraPDF parses its font program is not decided')
  else if FState.TextMode < 0 then
    Mark(pcc_FontEmbedded, True, Facts.Lbl + ' is not embedded')
  else
  begin
    { certain unless the font is also shown in mode 3 (Finish) }
    N := FWalk.FFCount;
    Mark(pcc_FontEmbedded, False, Facts.Lbl + ' is not embedded');
    if FWalk.FFCount > N then
      FWalk.AddFontMark(N, Facts);
  end;
end;

{ 6.2.11.4.1-2, 6.2.11.5-1 and 6.2.11.8-1 for the glyphs of the strings of
  the first operand (veraPDF reads two bytes per code for an Identity CMap,
  a last single byte with FF). Presence and widths do not apply in
  rendering mode 3. A finding of presence or width is certain for a font
  shown in a single parse under a single resource name (see FinishFonts);
  veraPDF takes the glyph names from the program it has parsed. Each code
  is checked once per font, paint and certainty of the mode.
  DE: 6.2.11.4.1-2, 6.2.11.5-1 und 6.2.11.8-1 fuer die Glyphen der Strings
  des ersten Operanden (veraPDF liest bei einer Identity-CMap zwei Bytes je
  Code, ein letztes einzelnes Byte mit FF). Vorhandensein und Breiten gelten
  nicht im Darstellungsmodus 3. Ein Befund zu Vorhandensein oder Breite ist
  sicher fuer eine Schrift, die in einer einzigen Parse unter einem
  einzigen Ressourcennamen gezeigt wird (siehe FinishFonts); die
  Glyphnamen nimmt veraPDF aus dem geparsten Programm. Jeder Code wird je
  Schrift, Malen und Sicherheit des Modus einmal geprueft. }
procedure TInterpreter.GlyphMark(AFacts: TObject; ACheck: TLandrixEInvoicePdfContentCheck; AMaybe: Boolean;
  const AText: string);
var
  N: Integer;
begin
  N := FWalk.FFCount;
  Mark(ACheck, AMaybe, TFontFacts(AFacts).Lbl + AText);
  if not AMaybe and (FWalk.FFCount > N) then
    FWalk.AddFontMark(N, AFacts);
end;

procedure TInterpreter.CheckGlyphs(AFirst: TCv);
var
  Facts: TFontFacts;
  Strs: array of TCv;
  I, J, K, Code, N, Bit: Integer;
  Any, Paint, Unsure: Boolean;
  G: TLandrixEInvoicePdfCidGlyphs;
  Diff: Double;
begin
  if (FState.Font = nil) or (AFirst = nil) then
    Exit;
  Strs := nil;
  if AFirst.Kind = cvk_Str then
  begin
    SetLength(Strs, 1);
    Strs[0] := AFirst;
  end
  else if AFirst.Kind = cvk_Arr then
  begin
    SetLength(Strs, AFirst.Items.Count);
    N := 0;
    for I := 0 to Integer(AFirst.Items.Count) - 1 do
      if TCv(AFirst.Items[I]).Kind = cvk_Str then
      begin
        Strs[N] := TCv(AFirst.Items[I]);
        Inc(N);
      end;
    SetLength(Strs, N);
  end;
  Any := False;
  for I := 0 to Integer(Length(Strs)) - 1 do
    if Strs[I].ByteLen > 0 then
      Any := True;
  if not Any then
    Exit;
  Facts := FontFactsOf(FWalk, FState.Font);
  Paint := FState.TextMode <> 3;
  Unsure := FState.TextMode < 0;
  if Facts.WThrows then
  begin
    FWalk.FThrows := True;
    FWalk.FMayThrow := True;
    FWalk.FIncomplete := True;
    Exit;
  end;
  case Facts.GlyphKind of
    1:
      begin
        if Paint then
        begin
          Mark(pcc_GlyphPresent, True, Facts.Lbl + ': glyphs not decided');
          Mark(pcc_GlyphWidth, True, Facts.Lbl + ': glyph widths not decided');
        end;
        Mark(pcc_GlyphNotdef, True, Facts.Lbl + ': glyph names not decided');
      end;
    3:
      Mark(pcc_GlyphNotdef, True, Facts.Lbl + ': glyph names not decided');
    2:
      begin
        G := TLandrixEInvoicePdfCidGlyphs(Facts.Glyphs);
        for I := 0 to Integer(Length(Strs)) - 1 do
        begin
          if Strs[I].CodesUnsure then
          begin
            Mark(pcc_GlyphNotdef, True, Facts.Lbl + ': codes not decided');
            if Paint then
            begin
              Mark(pcc_GlyphPresent, True, Facts.Lbl + ': codes not decided');
              Mark(pcc_GlyphWidth, True, Facts.Lbl + ': codes not decided');
            end;
            Continue;
          end;
          N := Strs[I].ByteLen;
          J := 0;
          while J < N do
          begin
            if J + 1 < N then
              Code := Strs[I].Data[J] * 256 + Strs[I].Data[J + 1]
            else
              Code := Strs[I].Data[J] * 256 + 255;
            Inc(J, 2);
            if Facts.Seen = nil then
            begin
              SetLength(Facts.Seen, LandrixEInvoicePdfCidCodes div 2);
              for K := 0 to Integer(Length(Facts.Seen)) - 1 do
                Facts.Seen[K] := 0;
            end;
            Bit := 1 shl ((Code and 1) * 4 + Ord(Paint) * 2 + Ord(Unsure));
            if Facts.Seen[Code shr 1] and Bit <> 0 then
              Continue;
            Facts.Seen[Code shr 1] := Byte(Facts.Seen[Code shr 1] or Bit);
            if not G.Present(Code) then
            begin
              GlyphMark(Facts, pcc_GlyphNotdef, False, ': code ' + IntToStr(Code) + ' is .notdef');
              if Paint and (Code <> 0) then
                GlyphMark(Facts, pcc_GlyphPresent, Unsure, ': no glyph for code ' + IntToStr(Code));
            end;
            if Paint then
            begin
              Diff := Abs(G.ProgramWidth(Code) - G.DictWidth(Code));
              if not (Diff <= 0.99) then
                GlyphMark(Facts, pcc_GlyphWidth, Unsure or not (Diff > 1.01), ': widths of code ' + IntToStr(Code) +
                  ' differ');
            end;
          end;
        end;
      end;
  end;
end;

procedure TInterpreter.ShowText;
var
  F, Sub, CP, S, Raw, FontRes, Local: TLandrixEInvoicePdfObject;
  I, Num, Idx: Integer;
  Entry: TContentParse;
  Key: string;
  Res: TRes;
begin
  FLastType3 := nil;
  CheckFont;
  F := FState.Font;
  if F = nil then
    Exit;
  Sub := FWalk.DGetRef(F, 'Subtype');
  if (Sub = nil) or (Sub.Kind <> pok_Name) or (Sub.NameVal <> 'Type3') then
    Exit;
  Key := FWalk.ObjId(F) + '/' + FWalk.ObjId(FRes.Page) + '/' + IntToStr(Ord(FState.ColorOn)) +
    IntToStr(Ord(FState.FillPattern)) + IntToStr(Ord(FState.StrokePattern)) + IntToStr(Ord(FState.Unsure)) +
    IntToStr(Ord(FState.Under)) + '/' + CsKey(FWalk, FState.FillCs) + '/' + CsKey(FWalk, FState.StrokeCs) + '/' +
    IntToStr(FState.TextMode) + '/' + OpKey(FState) + '/' + IntToStr(FState.FillPat) + ',' +
    IntToStr(FState.StrokePat);
  Num := FWalk.FType3Seen.IndexOf(Key);
  if Num >= 0 then
  begin
    FLastType3 := TContentParse(FWalk.FType3Seen.Objects[Num]);
    { reached before from this page: the same glyph parses, once into each
      parse }
    if (Length(TContentParse(FWalk.FType3Seen.Objects[Num]).Children) = 0) or
       (FWalk.FType3Replayed.IndexOf(Key + '@' + IntToStr(FParse.Index)) >= 0) then
      Exit;
    FWalk.FType3Replayed.Add(Key + '@' + IntToStr(FParse.Index));
    for I := 0 to Integer(Length(TContentParse(FWalk.FType3Seen.Objects[Num]).Children)) - 1 do
      FParse.AddChild(TContentParse(FWalk.FType3Seen.Objects[Num]).Children[I]);
    Exit;
  end;
  { the entry itself: glyphs may add entries before it in the sorted list }
  Entry := TContentParse.Create;
  FWalk.FType3Seen.AddObject(Key, Entry);
  FLastType3 := Entry;
  CP := FWalk.DGetRef(F, 'CharProcs');
  if (CP = nil) or (CP.Kind <> pok_Dict) then
    Exit;
  FontRes := FWalk.DGetRef(F, 'Resources');
  if (FontRes <> nil) and (FontRes.Kind <> pok_Dict) then
    FontRes := nil;
  Entry.Building := True;
  for I := 0 to Integer(CP.DVals.Count) - 1 do
  begin
    Raw := TLandrixEInvoicePdfObject(CP.DVals[I]);
    { a key given twice: veraPDF keeps the last value }
    if FWalk.DictGet(CP, CP.DKeys[I]) <> Raw then
      Continue;
    S := FWalk.ResolveRef(Raw);
    if (S = nil) or (S.Kind <> pok_Stream) or (Raw.Kind <> pok_Ref) then
      Continue;
    { a glyph with /Resources uses them (none if they are no dictionary),
      any other the font's }
    if (S.RawGet('Resources') <> nil) and (S.RawGet('Resources').Kind <> pok_Null) then
    begin
      Local := FWalk.DGetRef(S, 'Resources');
      if (Local <> nil) and not Local.IsDictLike then
        Local := nil;
    end
    else
      Local := FontRes;
    Res.Local := Local;
    Res.Page := FRes.Page;
    Res.InheritAll := False;
    Idx := ParseStreams(FWalk, 'S' + IntToStr(Raw.RefNum), Raw.RefNum, [S], Res, FState, False);
    Entry.AddChild(Idx);
    SetLength(Entry.GlyphNames, Length(Entry.GlyphNames) + 1);
    SetLength(Entry.GlyphIdx, Length(Entry.GlyphIdx) + 1);
    Entry.GlyphNames[High(Entry.GlyphNames)] := CP.DKeys[I];
    Entry.GlyphIdx[High(Entry.GlyphIdx)] := Idx;
  end;
  Entry.Building := False;
  { the most any glyph brings (for codes named by a base table) }
  for I := 0 to Integer(Length(Entry.GlyphIdx)) - 1 do
    Entry.Transp := MaxOf(Entry.Transp, FWalk.ParseTransp(Entry.GlyphIdx[I]));
  for I := 0 to Integer(Length(Entry.Children)) - 1 do
    FParse.AddChild(Entry.Children[I]);
end;

{ 6.2.10-2: an image is transparent with a soft mask stream or
  /SMaskInData above 0.
  DE: 6.2.10-2: ein Bild ist transparent mit einem Soft-Mask-Stream oder
  /SMaskInData ueber 0. }
function ImageTransp(AWalk: TLandrixEInvoicePdfContentWalk; X: TLandrixEInvoicePdfObject): Integer;
var
  V: TLandrixEInvoicePdfObject;
begin
  Result := 0;
  V := AWalk.DGetRef(X, 'SMask');
  if (V <> nil) and (V.Kind = pok_Stream) then
  begin
    Result := 2;
    Exit;
  end;
  V := AWalk.DGetRef(X, 'SMaskInData');
  if (V = nil) or (V.Kind <> pok_Num) then
    Exit;
  if V.NumExact then
  begin
    if Narrow32(V.NumInt) > 0 then
      Result := 2;
  end
  else if Abs(V.NumVal) < 2147483647.0 then
  begin
    if Trunc(V.NumVal) > 0 then
      Result := 2;
  end
  else
    Result := 1;
end;

{ 6.2.10-2: a form (or an appearance) whose /Group dictionary has /S
  /Transparency.
  DE: 6.2.10-2: eine Form (oder ein Erscheinungsbild), deren /Group-
  Dictionary /S /Transparency hat. }
function FormGroupTransp(AWalk: TLandrixEInvoicePdfContentWalk; X: TLandrixEInvoicePdfObject): Integer;
var
  G, S: TLandrixEInvoicePdfObject;
begin
  Result := 0;
  G := AWalk.DGetRef(X, 'Group');
  if (G = nil) or (G.Kind <> pok_Dict) then
    Exit;
  S := AWalk.DGetRef(G, 'S');
  if (S <> nil) and (S.Kind = pok_Name) and (S.NameVal = 'Transparency') then
    Result := 2;
end;

{ Do with a form XObject: its content with its own resources (none if
  missing) and the page's; the graphics state passes on, the q stack does
  not. }
procedure TInterpreter.ReachForm(const AName: AnsiString);
var
  Raw, X, Sub, Local: TLandrixEInvoicePdfObject;
  Res: TRes;
  Idx: Integer;
begin
  X := Lookup('XObject', AName, Raw);
  if X = nil then
    Exit;
  { the lookup gives only /Image, /Form and /PS: veraPDF checks the
    dictionary of each (also one that is no stream) }
  Sub := FWalk.DGetRef(X, 'Subtype');
  if (Sub = nil) or (Sub.Kind <> pok_Name) then
    Exit;
  if Sub.NameVal = 'PS' then
  begin
    Mark(pcc_PSXObject, False, 'PostScript XObject ' + ObjLabel(FWalk, Raw));
    Exit;
  end;
  if Sub.NameVal = 'Image' then
  begin
    FDoTransp := ImageTransp(FWalk, X);
    CheckImage(X, Raw, ik_Image, 0);
    FSiteFrom := FLookupFrom;
    ImageColour(X, Raw, 0);
    FSiteFrom := nil;
    Exit;
  end;
  CheckForm(X, Raw);
  FDoTransp := FormGroupTransp(FWalk, X);
  { a form's /Resources counts only as a dictionary (a stream: none) }
  Local := FWalk.DGetRef(X, 'Resources');
  if (Local <> nil) and (Local.Kind <> pok_Dict) then
    Local := nil;
  { the form's group (also of a form that is no stream) }
  if (Raw <> nil) and (Raw.Kind = pok_Ref) then
    OwnerGroup(X, Local, 'XG' + IntToStr(Raw.RefNum), Raw.RefNum)
  else
    OwnerGroup(X, Local, '', -1);
  if (X.Kind <> pok_Stream) or (Raw = nil) or (Raw.Kind <> pok_Ref) then
    Exit;
  Res.Local := Local;
  Res.Page := FRes.Page;
  Res.InheritAll := False;
  Idx := ParseStreams(FWalk, 'S' + IntToStr(Raw.RefNum), Raw.RefNum, [X], Res, FState, False);
  FParse.AddChild(Idx);
  FDoTransp := MaxOf(FDoTransp, ChildTransp(Idx, 'S' + IntToStr(Raw.RefNum)));
end;

{ scn or SCN with a pattern colour space: a tiling pattern's content with
  its own resources and the page's, starting with the state the calling
  stream started with; an uncoloured one with colour operators off. A name that selects no pattern leaves no pattern space
  active (AFill: the fill space, else the stroke space). }
procedure TInterpreter.ReachPattern(const AName: AnsiString; AFill: Boolean);
var
  Raw, P, Local: TLandrixEInvoicePdfObject;
  Res: TRes;
  St: TGState;
  PaintType: Int64;
  K: Integer;
  Uncoloured: Boolean;
  ShRaw: TLandrixEInvoicePdfObject;
  Idx: Integer;
begin
  if AFill then
    FState.FillPat := -1
  else
    FState.StrokePat := -1;
  P := Lookup('Pattern', AName, Raw);
  K := 0;
  while (P <> nil) and (P.Kind = pok_Arr) and (P.ArrCount = 1) do
  begin
    Inc(K);
    if K > MaxCsDepth then
    begin
      FParse.Uncertain := True;
      Exit;
    end;
    Raw := P.ArrItem(0);
    P := FWalk.ResolveRef(Raw);
  end;
  if P = nil then
  begin
    { the space becomes null: veraPDF links its empty space }
    if AFill then
    begin
      FState.FillPattern := False;
      FState.FillCs := NullCs;
    end
    else
    begin
      FState.StrokePattern := False;
      FState.StrokeCs := NullCs;
    end;
    ExposeCs(NullCs, True, 0);
    Exit;
  end;
  { a pattern space with an underlying space as the pattern: veraPDF keeps
    the underlying space for the next tiling pattern }
  if (P.Kind = pok_Arr) and (ClassifyIn(FWalk, FRes, nil, P, -1, 0, True, True) = csc_PatternUnder) then
  begin
    FState.Under := True;
    Exit;
  end;
  if P.IsDictLike and (PatternTypeOf(FWalk, P) = 2) then
  begin
    { a shading pattern: the colour space of its shading, in a context
      not modelled }
    Inc(FCsMaybe);
    try
      ShRaw := P.RawGet('Shading');
      FSiteFrom := FLookupFrom;
      ShadingColour(FWalk.ResolveRef(ShRaw), ShRaw);
    finally
      FSiteFrom := nil;
      Dec(FCsMaybe);
    end;
    Exit;
  end;
  if not P.IsDictLike or (PatternTypeOf(FWalk, P) <> 1) then
    Exit;
  { veraPDF builds every tiling pattern of a stream (also one without a
    stream) on the stream's shared start state, after the stream's last
    operator: an underlying space changes it, an uncoloured pattern turns
    colour off for all of them. Not followed: not decided. }
  if FState.Under or FInit.Under then
    FParse.Uncertain := True;
  Uncoloured := IntegerOf(FWalk.DGetRef(P, 'PaintType'), PaintType) and (PaintType = 2);
  if Uncoloured and FInit.ColorOn then
    FParse.Uncertain := True;
  if (P.Kind <> pok_Stream) or (Raw = nil) or (Raw.Kind <> pok_Ref) then
    Exit;
  Local := FWalk.DGetRef(P, 'Resources');
  if (Local <> nil) and (Local.Kind <> pok_Dict) then
    Local := nil;
  Res.Local := Local;
  Res.Page := FRes.Page;
  Res.InheritAll := False;
  St := FInit;
  if Uncoloured then
    St.ColorOn := False;
  Idx := ParseStreams(FWalk, 'S' + IntToStr(Raw.RefNum), Raw.RefNum, [P], Res, St, False);
  FParse.AddChild(Idx);
  if Idx < 0 then
  begin
    if ChildTransp(Idx, 'S' + IntToStr(Raw.RefNum)) > 0 then
      Idx := -2
    else
      Idx := -1;
  end;
  if AFill then
    FState.FillPat := Idx
  else
    FState.StrokePat := Idx;
end;

procedure TInterpreter.NoteTransp(ALevel: Integer);
begin
  if ALevel > FParse.Transp then
    FParse.Transp := ALevel;
end;

{ veraPDF's base check: a soft mask or a blend mode. }
function TInterpreter.TranspBase: Integer;
begin
  Result := MaxOf(FState.TSMask, FState.TBM);
end;

{ A tiling pattern (FillPat, StrokePat) as a paint meets it. }
function TInterpreter.PatTransp(AIndex: Integer): Integer;
begin
  if AIndex = -1 then
    Result := 0
  else if AIndex < 0 then
    Result := 1
  else
    Result := FWalk.ParseTransp(AIndex);
end;

{ 6.2.10-2: a path painted (fill, stroke or both) is transparent with a
  soft mask, a blend mode, an alpha below 1 of a painting side or a
  transparent tiling pattern there.
  DE: 6.2.10-2: ein gemalter Pfad (Fuellen, Linie oder beides) ist
  transparent mit einer Soft-Mask, einem Blend-Mode, einem Alpha unter 1
  einer malenden Seite oder einem transparenten Kachelmuster dort. }
procedure TInterpreter.TranspPaint(AFill, AStroke: Boolean);
var
  L: Integer;
begin
  L := TranspBase;
  if AFill then
    L := MaxOf(L, MaxOf(FState.TFillA, PatTransp(FState.FillPat)));
  if AStroke then
    L := MaxOf(L, MaxOf(FState.TStrokeA, PatTransp(FState.StrokePat)));
  NoteTransp(L);
end;

{ 6.2.10-2: the glyphs of a Type 3 font that a text operator shows, as
  veraPDF selects them: the bytes of the strings in its first operand (a
  string, or the strings of an array), the codes from 128 on selecting
  nothing, named by the /Differences of an /Encoding dictionary (a
  /BaseEncoding WinAnsi, MacRoman or MacExpert, or such an /Encoding name,
  adds names not modelled), and the CharProcs stream of that name.
  DE: 6.2.10-2: die Glyphen einer Type-3-Schrift, die ein Textoperator
  zeigt, wie veraPDF sie waehlt: die Bytes der Strings in seinem ersten
  Operanden (ein String oder die Strings eines Arrays), wobei Codes ab 128
  nichts waehlen, benannt durch die /Differences
  eines /Encoding-Dictionarys (eine /BaseEncoding WinAnsi, MacRoman oder
  MacExpert, oder ein solcher /Encoding-Name, fuegt nicht nachgebildete
  Namen hinzu), und der CharProcs-Stream dieses Namens. }
function TInterpreter.Type3Transp(AFirst: TCv): Integer;
var
  Codes: set of Byte;
  Unsure: Boolean;
  E: TLandrixEInvoicePdfObject;
  Code, I, Lvl, Slot: Integer;
begin
  Result := 0;
  if (FLastType3 = nil) or (AFirst = nil) then
    Exit;
  Codes := [];
  Unsure := False;
  if AFirst.Kind = cvk_Str then
  begin
    Codes := AFirst.Codes;
    Unsure := AFirst.CodesUnsure;
  end
  else if AFirst.Kind = cvk_Arr then
    for I := 0 to Integer(AFirst.Items.Count) - 1 do
      if TCv(AFirst.Items[I]).Kind = cvk_Str then
      begin
        Codes := Codes + TCv(AFirst.Items[I]).Codes;
        if TCv(AFirst.Items[I]).CodesUnsure then
          Unsure := True;
      end;
  if Unsure then
    Codes := Codes + [10, 13];
  if Codes = [] then
    Exit;
  E := FWalk.DGetRef(FState.Font, 'Encoding');
  if (E = nil) or ((E.Kind <> pok_Name) and (E.Kind <> pok_Dict)) then
    Exit;
  { a glyph shows text in its own font: the glyphs are being parsed }
  if FLastType3.Building then
  begin
    Result := 1;
    Exit;
  end;
  if not FLastType3.CodesDone then
    Type3Codes(FLastType3, E);
  for Code := 0 to 127 do
  begin
    if not (Byte(Code) in Codes) then
      Continue;
    Slot := FLastType3.CodeGlyph[Code];
    if Slot = -1 then
      Continue;
    if Slot = -2 then
    begin
      { a name from the base table: any glyph may be it }
      if FLastType3.Transp > 0 then
        Lvl := 1
      else
        Lvl := 0;
    end
    else
      Lvl := FWalk.ParseTransp(FLastType3.GlyphIdx[Slot]);
    if Unsure and ((Code = 10) or (Code = 13)) and (Lvl > 1) then
      Lvl := 1;
    Result := MaxOf(Result, Lvl);
  end;
end;

{ The glyph slot of each code 0 to 127 of a finished Type 3 entry (see
  Type3Transp): /Differences of an /Encoding dictionary; a /BaseEncoding
  WinAnsi, MacRoman or MacExpert (or such an /Encoding name) for the codes
  it leaves.
  DE: Der Glyphenplatz jedes Codes 0 bis 127 eines fertigen Type-3-Eintrags
  (siehe Type3Transp): /Differences eines /Encoding-Dictionarys; eine
  /BaseEncoding WinAnsi, MacRoman oder MacExpert (oder ein solcher
  /Encoding-Name) fuer die Codes, die es offen laesst. }
procedure TInterpreter.Type3Codes(AEntry: TContentParse; E: TLandrixEInvoicePdfObject);
var
  D, It: TLandrixEInvoicePdfObject;
  Names: array[0..127] of AnsiString;
  Has: array[0..127] of Boolean;
  Table: Boolean;
  Code, J, K: Integer;
  Idx: Int64;
begin
  AEntry.CodesDone := True;
  SetLength(AEntry.CodeGlyph, 128);
  for Code := 0 to 127 do
  begin
    Names[Code] := '';
    Has[Code] := False;
    AEntry.CodeGlyph[Code] := -1;
  end;
  if E.Kind = pok_Name then
    Table := (E.NameVal = 'WinAnsiEncoding') or (E.NameVal = 'MacRomanEncoding') or (E.NameVal = 'MacExpertEncoding')
  else
  begin
    D := FWalk.DGetRef(E, 'BaseEncoding');
    Table := (D <> nil) and (D.Kind = pok_Name) and ((D.NameVal = 'WinAnsiEncoding') or
      (D.NameVal = 'MacRomanEncoding') or (D.NameVal = 'MacExpertEncoding'));
    D := FWalk.DGetRef(E, 'Differences');
    if (D <> nil) and (D.Kind = pok_Arr) then
    begin
      Idx := 0;
      for K := 0 to D.ArrCount - 1 do
      begin
        It := FWalk.ResolveRef(D.ArrItem(K));
        if It = nil then
          Continue;
        if (It.Kind = pok_Num) and It.NumExact then
          Idx := Narrow32(It.NumInt)
        else if (It.Kind = pok_Name) and (Idx <> -1) then
        begin
          if (Idx >= 0) and (Idx <= 127) then
          begin
            Names[Integer(Idx)] := It.NameVal;
            Has[Integer(Idx)] := True;
          end;
          { far beyond the codes that count }
          if Idx < 1000000 then
            Inc(Idx);
        end;
      end;
    end;
  end;
  for Code := 0 to 127 do
    if Has[Code] then
    begin
      for J := 0 to Integer(Length(AEntry.GlyphNames)) - 1 do
        if AEntry.GlyphNames[J] = Names[Code] then
        begin
          AEntry.CodeGlyph[Code] := J;
          Break;
        end;
    end
    else if Table and (Length(AEntry.GlyphNames) > 0) then
      AEntry.CodeGlyph[Code] := -2;
end;

{ 6.2.10-2 for Tj, TJ, ' and ": the painting sides of the rendering mode
  (none for 3 and 7) and, for a Type 3 font, the glyphs shown.
  DE: 6.2.10-2 fuer Tj, TJ, ' und ": die malenden Seiten des Darstellungs-
  modus (keine bei 3 und 7) und bei einer Type-3-Schrift die gezeigten
  Glyphen. }
procedure TInterpreter.TextTransp(AFirst: TCv);
var
  M, F, S, G: Integer;
begin
  G := Type3Transp(AFirst);
  F := MaxOf(TranspBase, MaxOf(MaxOf(FState.TFillA, PatTransp(FState.FillPat)), G));
  S := MaxOf(TranspBase, MaxOf(MaxOf(FState.TStrokeA, PatTransp(FState.StrokePat)), G));
  M := FState.TextMode;
  if (M = 0) or (M = 4) then
    NoteTransp(F)
  else if (M = 1) or (M = 5) then
    NoteTransp(S)
  else if (M = 2) or (M = 6) then
    NoteTransp(MaxOf(F, S))
  else if (M < 0) or (M > 7) then
  begin
    if MaxOf(F, S) > 0 then
      NoteTransp(1);
  end;
end;

{ The transparency of a stream parsed from this one (AIndex from
  ParseStreams for AKey): -1 is a cycle (veraPDF reads the stream as
  empty) or a limit (not decided). }
function TInterpreter.ChildTransp(AIndex: Integer; const AKey: string): Integer;
begin
  if AIndex >= 0 then
    Result := FWalk.ParseTransp(AIndex)
  else if FWalk.FActive.IndexOf(AKey) >= 0 then
  begin
    FParse.CycleCut := True;
    Result := 0;
  end
  else
    Result := 1;
end;

{ 6.2.2-2 for a colour space name veraPDF looks up for the stream. }
procedure TInterpreter.CsInherit(const AName: AnsiString);
begin
  case CsInheritLevel(FWalk, FRes, AName) of
    1:
      Mark(pcc_Inherited, True, 'colour space /' + TextOf(AName) + ' maybe taken from the page''s resources');
    2:
      Mark(pcc_Inherited, False, 'ColorSpace /' + TextOf(AName) + ' taken from the page''s resources');
  end;
end;

{ BDC and DP with a name: veraPDF looks the properties up (6.2.2-2). }
procedure TInterpreter.TouchProperties(const AName: AnsiString);
var
  Raw: TLandrixEInvoicePdfObject;
begin
  Lookup('Properties', AName, Raw);
end;

procedure TInterpreter.RegisterAF(const AName: AnsiString);
var
  A, Item, Raw: TLandrixEInvoicePdfObject;
  I: Integer;
begin
  A := Lookup('Properties', AName, Raw);
  if (A = nil) or (A.Kind <> pok_Arr) then
    Exit;
  for I := 0 to A.ArrCount - 1 do
  begin
    Item := A.ArrItem(I);
    { the key of the object in use: number and generation }
    if (Item <> nil) and (Item.Kind = pok_Ref) and (FWalk.ResolveRef(Item) <> nil) then
      FParse.AddAssoc(FWalk.LastRefNum(Item));
  end;
end;

procedure TInterpreter.InlineImage(D: TCv);
var
  F, IM, Item: TCv;
  I: Integer;
  AllNames: Boolean;
begin
  IM := D.Get('IM');
  if not FState.ColorOn and not ((IM <> nil) and (IM.Kind = cvk_Bool) and (IM.IntVal = 1)) then
    Exit;
  ExposeCos(D, True);
  CheckInline(D);
  InlineColour(D);
  F := D.Get('F');
  if F = nil then
    F := D.Get('Filter');
  if F = nil then
    Exit;
  if F.Kind = cvk_Name then
  begin
    if not InList(F.Text, InlineFilters) then
      Mark(pcc_InlineFilter, False, 'inline image filter /' + TextOf(F.Text));
  end
  else if F.Kind = cvk_Arr then
  begin
    AllNames := True;
    for I := 0 to Integer(F.Items.Count) - 1 do
      if TCv(F.Items[I]).Kind <> cvk_Name then
        AllNames := False;
    if AllNames then
      for I := 0 to Integer(F.Items.Count) - 1 do
      begin
        Item := TCv(F.Items[I]);
        if not InList(Item.Text, InlineFilters) then
          Mark(pcc_InlineFilter, False, 'inline image filter /' + TextOf(Item.Text));
      end;
  end;
end;

{ 6.2.6-1: a rendering intent (a name) is one of the four.
  DE: 6.2.6-1: ein Rendering-Intent (ein Name) ist einer der vier. }
procedure TInterpreter.CheckIntent(const AName: AnsiString; const AWhere: string);
begin
  if not InList(AName, RenderingIntents) then
    Mark(pcc_Intent, False, AWhere + ' rendering intent /' + TextOf(AName));
end;

{ 6.2.5-1 to -3, 6.2.6-1 (/RI), 6.2.10-1 (/BM) and the halftone of an
  ExtGState selected by gs. /BM: a name, or the first name of an array.
  DE: 6.2.5-1 bis -3, 6.2.6-1 (/RI), 6.2.10-1 (/BM) und der Halftone eines
  mit gs gewaehlten ExtGState. /BM: ein Name oder der erste Name eines
  Arrays. }
procedure TInterpreter.CheckExtGState(G, ARaw: TLandrixEInvoicePdfObject);
var
  V, It: TLandrixEInvoicePdfObject;
  W: string;
  N: AnsiString;
  I: Integer;
begin
  if SeenBefore('G' + FWalk.ObjId(G)) then
    Exit;
  W := 'ExtGState ' + ObjLabel(FWalk, ARaw);
  if HasKey(G, 'TR') then
    Mark(pcc_TR, False, W + ' has /TR');
  if HasKey(G, 'TR2') and not (NameKey(FWalk, G, 'TR2', N) and (N = 'Default')) then
    Mark(pcc_TR2, False, W + ' has /TR2 other than /Default');
  if HasKey(G, 'HTP') then
    Mark(pcc_HTP, False, W + ' has /HTP');
  if NameKey(FWalk, G, 'RI', N) then
    CheckIntent(N, W);
  V := FWalk.DGetRef(G, 'BM');
  if (V <> nil) and (V.Kind = pok_Name) then
  begin
    if not InList(V.NameVal, BlendModes) then
      Mark(pcc_BlendMode, False, W + ' blend mode /' + TextOf(V.NameVal));
  end
  else if (V <> nil) and (V.Kind = pok_Arr) then
    for I := 0 to V.ArrCount - 1 do
    begin
      It := FWalk.ResolveRef(V.ArrItem(I));
      if (It <> nil) and (It.Kind = pok_Name) then
      begin
        if not InList(It.NameVal, BlendModes) then
          Mark(pcc_BlendMode, False, W + ' blend mode /' + TextOf(It.NameVal));
        Break;
      end;
    end;
  V := FWalk.DGetRef(G, 'HT');
  if (V <> nil) and ((V.Kind = pok_Name) or V.IsDictLike) then
    CheckHalftone(V, G.RawGet('HT'), HtPrimary, 0);
end;

{ 6.2.5-4 to -6 for a halftone visited in the colorant class AClass (the
  top level counts as HtPrimary): a name other than /Default has no type
  and is its own name; a Type 5 halftone visits every dictionary or
  stream it holds with the key as colorant. veraPDF checks an indirect
  halftone once, in the first class it meets it: a failure of 6.2.5-6 is
  certain only where no other class it may meet it in passes.
  DE: 6.2.5-4 bis -6 fuer einen Halftone, besucht in der Farbmittelklasse
  AClass (die oberste Ebene zaehlt als HtPrimary): ein Name ausser
  /Default hat keinen Typ und ist sein eigener Name; ein Halftone vom Typ
  5 besucht jedes Dictionary und jeden Stream darin mit dem Schluessel als
  Farbmittel. veraPDF prueft einen indirekten Halftone einmal, in der
  ersten Klasse, in der er ihn trifft: ein Verstoss gegen 6.2.5-6 ist nur
  sicher, wo keine andere Klasse, in der er ihn treffen kann, besteht. }
procedure TInterpreter.CheckHalftone(V, ARaw: TLandrixEInvoicePdfObject; AClass: Integer; ADepth: Integer);
var
  W: string;
  T: Int64;
  HasType, TfNull, Bad: Boolean;
  Tf, Nm, C, Raw: TLandrixEInvoicePdfObject;
  Num, I: Integer;
begin
  if ADepth > MaxHalftoneDepth then
  begin
    FParse.Uncertain := True;
    Exit;
  end;
  if SeenBefore('H' + FWalk.ObjId(V) + ':' + IntToStr(AClass)) then
    Exit;
  W := 'halftone ' + ObjLabel(FWalk, ARaw);
  if V.Kind = pok_Name then
  begin
    if V.NameVal <> 'Default' then
    begin
      Mark(pcc_HalftoneType, False, W + ' is the name /' + TextOf(V.NameVal));
      Mark(pcc_HalftoneName, False, W + ' is the name /' + TextOf(V.NameVal));
    end;
    { a name has no transfer function; it is met at the top level only }
    Exit;
  end;
  HasType := IntegerOf(FWalk.DGetRef(V, 'HalftoneType'), T);
  if not HasType or ((T <> 1) and (T <> 5)) then
    Mark(pcc_HalftoneType, False, W + ' has no HalftoneType 1 or 5');
  Nm := FWalk.DGetRef(V, 'HalftoneName');
  if (Nm <> nil) and (Nm.Kind = pok_Str) then
    Mark(pcc_HalftoneName, False, W + ' has /HalftoneName');
  Tf := FWalk.DGetRef(V, 'TransferFunction');
  { any value counts, also an empty string or name }
  TfNull := (Tf = nil) or (Tf.Kind = pok_Null);
  Bad := ((AClass = HtPrimary) and not TfNull) or ((AClass = HtOther) and TfNull);
  Num := -1;
  if (ARaw <> nil) and (ARaw.Kind = pok_Ref) then
    Num := FWalk.LastRefNum(ARaw);
  if Bad then
    Mark(pcc_HalftoneTransfer, (Num >= 0) and FWalk.HalftonePassesElsewhere(Num, TfNull),
      W + ' /TransferFunction against its colorant');
  if HasType and (T = 5) then
    for I := 0 to Integer(V.DVals.Count) - 1 do
    begin
      Raw := TLandrixEInvoicePdfObject(V.DVals[I]);
      C := FWalk.ResolveRef(Raw);
      if (C <> nil) and C.IsDictLike then
        CheckHalftone(C, Raw, HalftoneClass(V.DKeys[I]), ADepth + 1);
    end;
end;

{ 6.2.8-1 to -5, 6.2.6-1 (/Intent) and 6.2.9-3 for an image veraPDF builds
  (AKind): an image reached by Do or as an alternate, the /Mask stream of
  one (an image mask: its own BitsPerComponent rule, no /Intent, no
  nested /Mask), the /SMask stream of one (no nested masks or alternates).
  An alternate dictionary without an image stream makes veraPDF throw: it
  then reports nothing, so no content finding is certain.
  DE: 6.2.8-1 bis -5, 6.2.6-1 (/Intent) und 6.2.9-3 fuer ein Bild, das
  veraPDF baut (AKind): ein Bild ueber Do oder als Alternative, der
  /Mask-Stream eines Bilds (eine Bildmaske: eigene
  BitsPerComponent-Regel, kein /Intent, keine weitere /Mask), der
  /SMask-Stream eines Bilds (keine weiteren Masken oder Alternativen). Ein
  Alternativen-Dictionary ohne Bild-Stream laesst veraPDF eine Ausnahme
  werfen: es meldet dann nichts, also ist kein Content-Befund sicher. }
type
  { What veraPDF takes from the boxes of JPEG 2000 data (defaults where it
    finds nothing; EnumSet False: null). }
  TJpxFacts = record
    Channels: Int64;
    Specs: Int64;
    Approx: Int64;
    Method: Int64;
    EnumSet: Boolean;
    Enum: Int64;
    Depth: Int64;
    Bpcc: Boolean;
  end;

  { The raw bytes of a JPX stream as veraPDF reads them: a read of
    fewer bytes than asked fails, a skip stops at the end. }
  TJpxReader = record
    Data: TLandrixEInvoicePdfBytes;
    Pos: Integer;
    Len: Integer;
  end;

{ N bytes as an unsigned number (N at most 4), or the 8 bytes of an XLBox
  (-1 for a value veraPDF reads as negative, -2 - k for -2^63 + k with k
  below 16, whose box length minus its header comes out positive there).
  False: fewer bytes. }
function JpxRead(var R: TJpxReader; N: Integer; out AValue: Int64): Boolean;
var
  I: Integer;
begin
  AValue := 0;
  Result := R.Len - R.Pos >= N;
  if not Result then
  begin
    R.Pos := R.Len;
    Exit;
  end;
  if (N = 8) and (R.Data[R.Pos] >= $80) then
  begin
    AValue := -2 - Int64(R.Data[R.Pos + 7]);
    if R.Data[R.Pos] <> $80 then
      AValue := -1;
    for I := 1 to 6 do
      if R.Data[R.Pos + I] <> 0 then
        AValue := -1;
    if R.Data[R.Pos + 7] >= 16 then
      AValue := -1;
  end
  else
    for I := 0 to N - 1 do
      AValue := AValue * 256 + R.Data[R.Pos + I];
  Inc(R.Pos, N);
end;

procedure JpxSkip(var R: TJpxReader; N: Int64);
begin
  if N <= 0 then
    Exit;
  if N > Int64(R.Len) - R.Pos then
    R.Pos := R.Len
  else
    Inc(R.Pos, Integer(N));
end;

{ A box header: LBox, TBox and (LBox 1) XLBox; ASkipped 8 or 16. }
function JpxBox(var R: TJpxReader; out ALength: Int64; out AType: AnsiString; out ASkipped: Integer): Boolean;
var
  T: Int64;
  I: Integer;
begin
  AType := '';
  ASkipped := 8;
  Result := False;
  if not JpxRead(R, 4, ALength) then
    Exit;
  if R.Len - R.Pos < 4 then
  begin
    R.Pos := R.Len;
    Exit;
  end;
  SetLength(AType, 4);
  for I := 0 to 3 do
    AType[I + 1] := AnsiChar(R.Data[R.Pos + I]);
  Inc(R.Pos, 4);
  if ALength = 1 then
  begin
    if not JpxRead(R, 8, T) then
      Exit;
    ALength := T;
    ASkipped := 16;
  end;
  Result := True;
end;

{ 6.2.8.3: what veraPDF 1.30.4 takes from JPEG 2000 data, from the raw
  stream bytes: the JP2 signature, the first jp2h box among the top-level
  boxes, in it ihdr (channels, bit depth byte plus 1, from 128 on negative), bpcc
  and colr (METH, APPROX, EnumCS). False where veraPDF may throw (a profile
  length it cannot allocate).
  DE: 6.2.8.3: was veraPDF 1.30.4 aus JPEG-2000-Daten liest, aus den
  rohen Stream-Bytes: die JP2-Signatur, die erste jp2h-Box unter den Boxen
  der obersten Ebene, darin ihdr (Kanaele, Bittiefen-Byte plus 1, ab
  128 negativ), bpcc und colr (METH, APPROX, EnumCS). False, wo
  veraPDF eine Ausnahme werfen kann (eine Profillaenge, die es nicht
  anlegen kann). }
function JpxFacts(const AData: TLandrixEInvoicePdfBytes; out F: TJpxFacts): Boolean;
const
  Sign: array[0..11] of Byte = ($00, $00, $00, $0C, $6A, $50, $20, $20, $0D, $0A, $87, $0A);
  MaxProfile = 256 * 1024 * 1024;
var
  R: TJpxReader;
  I, Skipped: Integer;
  Len, Left, LeftInHeader, LeftInBox, V, Meth, Approx, ReadCount, P: Int64;
  T: AnsiString;
  ReachEnd, HasSpecs, HasApprox, HasFirstMeth, HasFirstEnum, HasMeth, HasEnum: Boolean;
  Specs, ApproxCount, FirstMeth, FirstEnum, ColrMeth, ColrEnum: Int64;
begin
  Result := True;
  F.Channels := 0;
  F.Specs := 0;
  F.Approx := 0;
  F.Method := 0;
  F.EnumSet := False;
  F.Enum := 0;
  F.Depth := 0;
  F.Bpcc := False;
  R.Data := AData;
  R.Pos := 0;
  R.Len := Integer(Length(AData));
  if R.Len < 12 then
    Exit;
  for I := 0 to 11 do
    if AData[I] <> Sign[I] then
      Exit;
  R.Pos := 12;
  { the header box among the top-level boxes }
  { 0: the header box runs to the end of the data }
  LeftInHeader := 0;
  while True do
  begin
    if not JpxBox(R, Len, T, Skipped) then
      Exit;
    Left := Len - Skipped;
    if T = 'jp2h' then
    begin
      if (Len <= -2) and (Len >= -17) then
        { the header length comes out as 2^63 - 16 + k }
        LeftInHeader := High(Int64) - 15 + (-2 - Len)
      else if Len <> 0 then
      begin
        if Left <= 0 then
          Exit;
        LeftInHeader := Left;
      end;
      Break;
    end;
    if (Len = 0) or (Left < 0) then
      Exit;
    JpxSkip(R, Left);
  end;
  ReachEnd := LeftInHeader = 0;
  HasSpecs := False;
  HasApprox := False;
  HasFirstMeth := False;
  HasFirstEnum := False;
  HasMeth := False;
  HasEnum := False;
  Specs := 0;
  ApproxCount := 0;
  FirstMeth := 0;
  FirstEnum := 0;
  ColrMeth := 0;
  ColrEnum := 0;
  while True do
  begin
    if not JpxBox(R, Len, T, Skipped) then
      Break;
    if (Len < 0) or (not ReachEnd and ((Len = 0) or (Len > LeftInHeader))) then
      Break;
    LeftInBox := Len - Skipped;
    if T = 'ihdr' then
    begin
      if (LeftInBox <> 14) and (Len <> 0) then
        Break;
      JpxSkip(R, 8);
      if not JpxRead(R, 2, V) then
        Break;
      F.Channels := V;
      if not JpxRead(R, 1, V) then
        Break;
      if V >= 128 then
        F.Depth := V - 256 + 1
      else
        F.Depth := V + 1;
      JpxSkip(R, 3);
    end
    else if T = 'bpcc' then
    begin
      F.Bpcc := True;
      JpxSkip(R, LeftInBox);
    end
    else if T = 'colr' then
    begin
      if LeftInBox < 3 then
        Break;
      HasSpecs := True;
      Inc(Specs);
      if not JpxRead(R, 1, Meth) then
        Break;
      if not HasFirstMeth then
      begin
        FirstMeth := Meth;
        HasFirstMeth := True;
      end;
      JpxSkip(R, 1);
      if not JpxRead(R, 1, Approx) then
        Break;
      if Approx = 1 then
      begin
        HasApprox := True;
        Inc(ApproxCount);
        if not HasMeth then
        begin
          ColrMeth := Meth;
          HasMeth := True;
        end;
      end;
      ReadCount := 3;
      if Meth = 1 then
      begin
        if LeftInBox < 7 then
          Break;
        if not JpxRead(R, 4, V) then
          Break;
        Inc(ReadCount, 4);
        if not HasFirstEnum then
        begin
          FirstEnum := V;
          HasFirstEnum := True;
        end;
        if (Approx = 1) and not HasEnum then
        begin
          ColrEnum := V;
          HasEnum := True;
        end;
      end
      else if Meth = 2 then
      begin
        { the profile length as veraPDF narrows it to 32 bits: a negative one
          throws, a very large one may run out of memory there }
        P := (LeftInBox - ReadCount) and $FFFFFFFF;
        if (P >= $80000000) or ((P > MaxProfile) and (P > Int64(R.Len) - R.Pos)) then
        begin
          Result := False;
          Exit;
        end;
        if Int64(R.Len) - R.Pos < P then
          Break;
        Inc(R.Pos, Integer(P));
        Inc(ReadCount, P);
      end;
      JpxSkip(R, LeftInBox - ReadCount);
    end
    else
      JpxSkip(R, LeftInBox);
    if not ReachEnd then
      Dec(LeftInHeader, Len);
    if (ReachEnd and (Len = 0)) or (not ReachEnd and (LeftInHeader = 0)) then
      Break;
  end;
  if HasSpecs then
    F.Specs := Specs;
  if HasApprox then
  begin
    F.Approx := ApproxCount;
    if HasMeth then
      F.Method := ColrMeth;
    if HasEnum then
    begin
      F.EnumSet := True;
      F.Enum := ColrEnum;
    end;
  end
  else if HasSpecs and (Specs = 1) then
  begin
    if HasFirstMeth then
      F.Method := FirstMeth;
    if HasFirstEnum then
    begin
      F.EnumSet := True;
      F.Enum := FirstEnum;
    end;
  end;
end;

type
  { The JPEG 2000 facts of one image stream: Sure (the stored bytes are
    those veraPDF reads), Throws (veraPDF may throw on them). }
  TJpxEntry = class(TObject)
  public
    Sure: Boolean;
    Throws: Boolean;
    Facts: TJpxFacts;
  end;

{ The JPEG 2000 facts of the image stream V, once per object. }
function JpxEntryOf(AWalk: TLandrixEInvoicePdfContentWalk; V: TLandrixEInvoicePdfObject): TJpxEntry;
var
  Key: string;
  Idx: Integer;
  Data: TLandrixEInvoicePdfBytes;
  L: TLandrixEInvoicePdfObject;
begin
  Key := AWalk.ObjId(V);
  if AWalk.FJpxCache.Find(Key, Idx) then
  begin
    Result := TJpxEntry(AWalk.FJpxCache.Objects[Idx]);
    Exit;
  end;
  Result := TJpxEntry.Create;
  AWalk.FJpxCache.AddObject(Key, Result);
  Data := nil;
  L := AWalk.DGetRef(V, 'Length');
  Result.Sure := not AWalk.FDoc.Encrypted and AWalk.FDoc.GetStreamRaw(V, Data) and (L <> nil) and
    (L.Kind = pok_Num) and L.NumExact and (L.NumInt = Length(Data));
  { whether veraPDF throws is decided on these bytes even where they may not
    be exactly its own }
  Result.Throws := not JpxFacts(Data, Result.Facts);
end;

{ 6.2.8.3-1 to -5: the JPEG 2000 data of an image as veraPDF reads it (the
  stored bytes, whatever other filters there are); certain only where they
  are surely the bytes veraPDF reads (not encrypted, an exact /Length).
  -2 to -4 only without /ColorSpace.
  DE: 6.2.8.3-1 bis -5: die JPEG-2000-Daten eines Bilds, wie veraPDF sie
  liest (die gespeicherten Bytes, gleich welche anderen Filter es gibt);
  sicher nur, wo es sicher die Bytes sind, die veraPDF liest (nicht
  verschluesselt, eine genaue /Length). -2 bis -4 nur ohne /ColorSpace. }
procedure TInterpreter.CheckJpx(V: TLandrixEInvoicePdfObject; const AWhat: string);
var
  C: TLandrixEInvoicePdfObject;
  E: TJpxEntry;
  F: TJpxFacts;
  HasCs: Boolean;
  Chk: TLandrixEInvoicePdfContentCheck;
begin
  if V.Kind <> pok_Stream then
  begin
    { no data: veraPDF's reader fails on it }
    FWalk.FThrows := True;
    FWalk.FMayThrow := True;
    FWalk.FIncomplete := True;
    Exit;
  end;
  E := JpxEntryOf(FWalk, V);
  F := E.Facts;
  if E.Throws then
  begin
    { veraPDF may throw on this profile length }
    FWalk.FThrows := True;
    FWalk.FMayThrow := True;
    FWalk.FIncomplete := True;
    Exit;
  end;
  if not E.Sure then
  begin
    for Chk := pcc_JpxChannels to pcc_JpxDepth do
      Mark(Chk, True, AWhat + ': JPEG 2000 data not read with certainty');
    Exit;
  end;
  C := FWalk.ResolveRef(V.RawGet('ColorSpace'));
  HasCs := (C <> nil) and (C.Kind <> pok_Null);
  if (F.Channels <> 1) and (F.Channels <> 3) and (F.Channels <> 4) then
    Mark(pcc_JpxChannels, False, AWhat + ': JPEG 2000 data with ' + IntToStr(F.Channels) + ' colour channels');
  if not HasCs and (F.Specs <> 1) and (F.Approx <> 1) then
    Mark(pcc_JpxSpecs, False, AWhat + ': JPEG 2000 data with ' + IntToStr(F.Specs) + ' colour specifications, ' +
      IntToStr(F.Approx) + ' with APPROX 1');
  if not HasCs and (F.Method <> 1) and (F.Method <> 2) and (F.Method <> 3) then
    Mark(pcc_JpxMethod, False, AWhat + ': JPEG 2000 colour specification METH ' + IntToStr(F.Method));
  if not HasCs and F.EnumSet and (F.Enum = 19) then
    Mark(pcc_JpxEnum, False, AWhat + ': JPEG 2000 enumerated colour space 19 (CIEJab)');
  if F.Bpcc or (F.Depth < 1) or (F.Depth > 38) then
  begin
    if F.Bpcc then
      Mark(pcc_JpxDepth, False, AWhat + ': JPEG 2000 data with a bpcc box')
    else
      Mark(pcc_JpxDepth, False, AWhat + ': JPEG 2000 bit depth ' + IntToStr(F.Depth));
  end;
end;

procedure TInterpreter.CheckImage(V, ARaw: TLandrixEInvoicePdfObject; AKind, ADepth: Integer);
const
  KindNames: array[ik_Image..ik_SMask] of string = ('image ', 'image mask ', 'soft mask ');
var
  W: string;
  B, A, Item, Img, Raw: TLandrixEInvoicePdfObject;
  Bits: Int64;
  N: AnsiString;
  I: Integer;
begin
  if (V = nil) or not V.IsDictLike then
    Exit;
  if ADepth > MaxImageDepth then
  begin
    FParse.Uncertain := True;
    Exit;
  end;
  if SeenBefore('I' + FWalk.ObjId(V) + ':' + IntToStr(AKind)) then
    Exit;
  W := KindNames[AKind] + ObjLabel(FWalk, ARaw);
  if HasKey(V, 'Alternates') then
    Mark(pcc_ImageAlternates, False, W + ' has /Alternates');
  if HasKey(V, 'OPI') then
    Mark(pcc_ImageOPI, False, W + ' has /OPI');
  B := FWalk.DGetRef(V, 'Interpolate');
  if (B <> nil) and (B.Kind = pok_Bool) and B.BoolVal then
    Mark(pcc_Interpolate, False, W + ' has /Interpolate true');
  if IntegerOf(FWalk.DGetRef(V, 'BitsPerComponent'), Bits) then
  begin
    if AKind = ik_Mask then
    begin
      if Bits <> 1 then
        Mark(pcc_MaskBits, False, W + ' has BitsPerComponent ' + IntToStr(Bits));
    end
    else if (Bits <> 1) and (Bits <> 2) and (Bits <> 4) and (Bits <> 8) and (Bits <> 16) then
      Mark(pcc_ImageBits, False, W + ' has BitsPerComponent ' + IntToStr(Bits));
  end;
  if NameKey(FWalk, V, 'Subtype', N) and (N = 'PS') then
    Mark(pcc_PSXObject, False, W + ' has /Subtype /PS');
  if (AKind <> ik_Mask) and NameKey(FWalk, V, 'Intent', N) then
    CheckIntent(N, W);
  if IsJpxRead(FWalk, V) then
    CheckJpx(V, W);
  if AKind = ik_SMask then
    Exit;
  if AKind = ik_Image then
  begin
    Raw := V.RawGet('Mask');
    Img := FWalk.ResolveRef(Raw);
    if (Img <> nil) and (Img.Kind = pok_Stream) then
      CheckImage(Img, Raw, ik_Mask, ADepth + 1);
  end;
  Raw := V.RawGet('SMask');
  Img := FWalk.ResolveRef(Raw);
  if (Img <> nil) and (Img.Kind = pok_Stream) then
    CheckImage(Img, Raw, ik_SMask, ADepth + 1);
  A := FWalk.DGetRef(V, 'Alternates');
  if (A <> nil) and (A.Kind = pok_Arr) then
    for I := 0 to A.ArrCount - 1 do
    begin
      { veraPDF takes dictionaries only (no streams) }
      Item := FWalk.ResolveRef(A.ArrItem(I));
      if (Item = nil) or (Item.Kind <> pok_Dict) then
        Continue;
      Raw := Item.RawGet('Image');
      Img := FWalk.ResolveRef(Raw);
      if (Img = nil) or (Img.Kind <> pok_Stream) then
      begin
        { veraPDF throws and reports nothing }
        FWalk.FThrows := True;
        FWalk.FMayThrow := True;
        FWalk.FIncomplete := True;
        Continue;
      end;
      CheckImage(Img, Raw, ik_Image, ADepth + 1);
    end;
end;

{ 6.2.9-1 to -3 for a form XObject reached by Do. DE: 6.2.9-1 bis -3 fuer
  ein mit Do erreichtes Form-XObject. }
procedure TInterpreter.CheckForm(V, ARaw: TLandrixEInvoicePdfObject);
var
  APs, ARef, ASub: string;
begin
  FormFaults(FWalk, V, APs, ARef, ASub);
  if APs <> '' then
    Mark(pcc_FormPS, False, 'form XObject ' + ObjLabel(FWalk, ARaw) + ' has' + APs);
  if ARef <> '' then
    Mark(pcc_FormRef, False, 'form XObject ' + ObjLabel(FWalk, ARaw) + ' has' + ARef);
  if ASub <> '' then
    Mark(pcc_PSXObject, False, 'form XObject ' + ObjLabel(FWalk, ARaw) + ' has' + ASub);
end;

{ An inline image is an image for 6.2.8-1 to -4 and 6.2.6-1 (veraPDF gives
  it no subtype, so 6.2.9-3 never applies); /I and /BPC are read before
  /Interpolate and /BitsPerComponent.
  DE: Ein Inline-Bild ist ein Bild fuer 6.2.8-1 bis -4 und 6.2.6-1 (veraPDF
  gibt ihm keinen Subtype, 6.2.9-3 gilt also nie); /I und /BPC werden vor
  /Interpolate und /BitsPerComponent gelesen. }
procedure TInterpreter.CheckInline(D: TCv);
var
  V: TCv;
  Bits: Int64;
begin
  V := D.Get('Intent');
  if (V <> nil) and (V.Kind = cvk_Name) then
    CheckIntent(V.Text, 'inline image');
  if D.Get('Alternates') <> nil then
    Mark(pcc_ImageAlternates, False, 'inline image has /Alternates');
  if D.Get('OPI') <> nil then
    Mark(pcc_ImageOPI, False, 'inline image has /OPI');
  V := D.Get('I');
  if V = nil then
    V := D.Get('Interpolate');
  if (V <> nil) and (V.Kind = cvk_Bool) and (V.IntVal = 1) then
    Mark(pcc_Interpolate, False, 'inline image has /Interpolate true');
  V := D.Get('BPC');
  if V = nil then
    V := D.Get('BitsPerComponent');
  if V <> nil then
  begin
    Bits := 1;
    if V.Kind = cvk_Int then
      Bits := V.IntVal
    else if V.Kind = cvk_Real then
    begin
      if V.RealVal >= 9.0E18 then
        Bits := High(Int64)
      else if V.RealVal <= -9.0E18 then
        Bits := Low(Int64)
      else
        Bits := Trunc(V.RealVal);
    end
    else if V.Kind = cvk_Str then
    begin
      { a string counts its decoded bytes }
      Bits := V.ByteLen;
    end;
    if (Bits <> 1) and (Bits <> 2) and (Bits <> 4) and (Bits <> 8) and (Bits <> 16) then
      Mark(pcc_ImageBits, False, 'inline image has BitsPerComponent ' + IntToStr(Bits));
  end;
end;

{ A colour space veraPDF may link that is not decided: every colour check
  may fail, and what it reaches is not known (a shared object may be met
  there first). }
procedure TInterpreter.MaybeColour(const AWhat: string);
var
  C: TLandrixEInvoicePdfContentCheck;
begin
  FWalk.FSharedUnsure := True;
  for C := pcc_DeviceGray to pcc_SeparationConsistency do
    Mark(C, True, AWhat);
end;

{ Writes to the virtual parse of AKey in the context ACtx (a child of this
  parse) when it is new; False if it exists already (veraPDF validates it
  once) or a limit was reached. }
function TInterpreter.EnterVirtual(const AKey, ACtx: string; ANum: Integer; out ASave: TVSave): Boolean;
var
  Idx: Integer;
  New: Boolean;
begin
  Result := False;
  ASave.Parse := FParse;
  ASave.Index := FParseIndex;
  Idx := VirtualParse(FWalk, AKey, ACtx + '/' + IntToStr(Ord(FCsMaybe > 0)), ANum, False, New);
  if Idx < 0 then
    Exit;
  FParse.AddChild(Idx);
  if not New then
    Exit;
  FParse := TContentParse(FWalk.FParses[Idx]);
  FParseIndex := Idx;
  Result := True;
end;

procedure TInterpreter.LeaveVirtual(const ASave: TVSave);
begin
  FParse := ASave.Parse;
  FParseIndex := ASave.Index;
end;

{ veraPDF links the colour space C: a device space is a finding of its rule
  (whether it fails depends on the output intent); null is veraPDF's empty
  space, of type DeviceGray, where the link takes it (ANullGray); a space
  array is looked into. An indirect array is validated once by its
  identity, and the direct CMYK ICC spaces share one identity: a virtual
  parse per context.
  DE: veraPDF verknuepft den Farbraum C: ein Geraeteraum ist ein Befund
  seiner Regel (ob er scheitert, haengt vom Output-Intent ab); null ist
  veraPDFs leerer Raum vom Typ DeviceGray, wo die Verknuepfung ihn nimmt
  (ANullGray); in ein Raum-Array wird hineingesehen. Ein indirektes Array
  wird einmal nach seiner Identitaet geprueft, und die direkten
  CMYK-ICC-Raeume teilen sich eine Identitaet: eine virtuelle Analyse je
  Kontext. }
procedure TInterpreter.ExposeCs(const C: TCsRef; ANullGray: Boolean; ADepth: Integer);
var
  Save: TVSave;
  Key, Ctx, Pair: string;
  ShRaw: TLandrixEInvoicePdfObject;
  Paint: Boolean;
begin
  { the overprint state goes only with the space a paint links directly }
  Paint := FPaintActive and (ADepth = 0);
  FPaintActive := False;
  if ADepth > MaxCsDepth then
  begin
    MaybeColour('colour spaces nested too deep');
    Exit;
  end;
  { veraPDF's ICCBased CMYK wrapper carries the overprint mode and flag in
    its identity; (0, false) for every link that is no paint }
  Pair := '';
  if Paint and (C.Kind = csk_Value) and (IccComponents(FWalk, C.V) = 4) and
    (FPaintFlag or not FPaintOPMKnown or (FPaintOPM <> 0)) then
    Pair := '/' + IntToStr(FPaintOPM) + IntToStr(Ord(FPaintOPMKnown)) + IntToStr(Ord(FPaintFlag));
  { the same space array in the same parse and mode adds nothing new }
  if (ADepth = 0) and (C.Kind = csk_Value) and
    SeenBefore('C' + IntToStr(FParseIndex) + '/' + CsKey(FWalk, C) + '/' + IntToStr(Ord(ANullGray)) +
    IntToStr(Ord(FCsMaybe > 0)) + Pair) then
    Exit;
  if ADepth > 0 then
  begin
    Inc(FWalk.FCsSteps);
    if FWalk.FCsSteps > MaxCsSteps then
    begin
      { not followed: anything may be reached first }
      FWalk.FIncomplete := True;
      FWalk.FLimitHit := True;
      Exit;
    end;
  end;
  case C.Kind of
    csk_Null:
      if ANullGray then
        Mark(pcc_DeviceGray, False, 'empty colour space (DeviceGray to veraPDF)');
    csk_Gray:
      Mark(pcc_DeviceGray, False, 'DeviceGray colour space');
    csk_RGB:
      Mark(pcc_DeviceRGB, False, 'DeviceRGB colour space');
    csk_CMYK:
      Mark(pcc_DeviceCMYK, False, 'DeviceCMYK colour space');
    csk_Unknown:
      MaybeColour('colour space not decided');
    csk_Pattern:
      if (C.V <> nil) and (PatternTypeOf(FWalk, C.V) = 2) and (FPatternNest > MaxCsDepth) then
        MaybeColour('shading patterns nested too deep')
      else if (C.V <> nil) and (PatternTypeOf(FWalk, C.V) = 2) then
      begin
        { a shading pattern selected as a space: its shading, in a context
          not modelled }
        Inc(FCsMaybe);
        Inc(FPatternNest);
        try
          ShRaw := C.V.RawGet('Shading');
          FSiteFrom := C.R;
          ShadingColour(FWalk.ResolveRef(ShRaw), ShRaw);
        finally
          FSiteFrom := nil;
          Dec(FPatternNest);
          Dec(FCsMaybe);
        end;
      end;
    csk_PatternUnder:
      begin
        { the underlying space of a pattern space: not modelled }
        Inc(FCsMaybe);
        try
          ExposeCs(CsValue(FWalk, C.R, C.V.ArrItem(1), C.WasDefault, 0), False, ADepth + 1);
        finally
          Dec(FCsMaybe);
        end;
      end;
    csk_Value:
      begin
        Key := '';
        Ctx := FWalk.ObjId(C.R) + '/' + IntToStr(Ord(C.WasDefault));
        if C.Num >= 0 then
          Key := 'XK' + IntToStr(C.Num) + Pair
        else if IccComponents(FWalk, C.V) = 4 then
        begin
          Key := 'XC' + Pair;
          Ctx := FWalk.ObjId(C.V);
        end;
        { a component count not decided: whether this is the CMYK wrapper
          (and its identity) is not known }
        if IccComponents(FWalk, C.V) = -2 then
        begin
          Inc(FCsMaybe);
          try
            ExposeArray(C, ADepth, False);
          finally
            Dec(FCsMaybe);
          end;
          Exit;
        end;
        { the direct CMYK ICC spaces share one identity per overprint pair:
          with (0, false) veraPDF may meet one first on a route not
          modelled (a JPEG 2000 image, a 3D stream), so their findings stay
          uncertain; only a paint gives another pair }
        if Key = 'XC' then
          Inc(FCsMaybe);
        try
          if Key = '' then
            ExposeArray(C, ADepth, Paint)
          else if EnterVirtual(Key, Ctx, C.Num, Save) then
            try
              ExposeArray(C, ADepth, Paint);
            finally
              LeaveVirtual(Save);
            end;
        finally
          if Key = 'XC' then
            Dec(FCsMaybe);
        end;
      end;
  else
    { bare /Pattern: the pattern scn selects is linked there }
  end;
end;

{ The spaces inside a space array: the profile of an ICCBased space, the
  base of an Indexed space (defaults apply again), the alternate of a
  Separation space, the parts of a DeviceN space. Nested names are looked
  up in the resources the array was found in.
  DE: Die Raeume in einem Raum-Array: das Profil eines ICCBased-Raums, die
  Basis eines Indexed-Raums (Defaults gelten wieder), die Alternative
  eines Separation-Raums, die Teile eines DeviceN-Raums. Verschachtelte
  Namen werden in den Ressourcen gesucht, in denen das Array gefunden
  wurde. }
procedure TInterpreter.ExposeArray(const C: TCsRef; ADepth: Integer; APaint: Boolean);
var
  N: AnsiString;
begin
  N := FirstName(FWalk, C.V);
  if N = 'ICCBased' then
    ExposeIcc(C, APaint)
  else if N = 'Indexed' then
    ExposeCs(CsValue(FWalk, C.R, C.V.ArrItem(1), False, 0), True, ADepth + 1)
  else if N = 'Separation' then
  begin
    RecordSeparation(C);
    if C.V.ArrCount > 2 then
      ExposeCs(CsValue(FWalk, C.R, C.V.ArrItem(2), C.WasDefault, 0), True, ADepth + 1)
    else
      MaybeColour('Separation colour space without an alternate');
  end
  else if N = 'DeviceN' then
    ExposeDeviceN(C, ADepth);
end;

{ 6.2.4.2-1: the profile of an ICCBased space (a stream in element 1) is an
  input, display, output or colour space profile for RGB, CMYK, Gray or Lab
  below ICC version 5; a header not read as veraPDF reads it leaves the
  rule open.
  DE: 6.2.4.2-1: das Profil eines ICCBased-Raums (ein Stream in Element 1)
  ist ein Eingabe-, Anzeige-, Ausgabe- oder Farbraumprofil fuer RGB, CMYK,
  Gray oder Lab unter ICC-Version 5; ein Kopf, der sich nicht so lesen
  laesst wie von veraPDF, laesst die Regel offen. }
procedure TInterpreter.ExposeIcc(const C: TCsRef; APaint: Boolean);
var
  S: TLandrixEInvoicePdfObject;
  H: TLandrixEInvoicePdfIccHeader;
begin
  { 6.2.4.2-2: an ICCBased space with /N 4 painted with overprint on needs
    overprint mode 0
    DE: 6.2.4.2-2: ein ICCBased-Raum mit /N 4, mit dem bei eingeschaltetem
    Ueberdrucken gemalt wird, braucht den Ueberdruckmodus 0 }
  if APaint and FPaintFlag and (IccComponents(FWalk, C.V) = 4) then
  begin
    if not FPaintOPMKnown then
      Mark(pcc_Overprint, True, 'ICCBased CMYK colour space painted with overprint on, mode not decided')
    else if FPaintOPM <> 0 then
      Mark(pcc_Overprint, False, 'ICCBased CMYK colour space painted with overprint on and OPM ' +
        IntToStr(FPaintOPM));
  end;
  S := FWalk.ResolveRef(C.V.ArrItem(1));
  if (S = nil) or (S.Kind <> pok_Stream) then
    Exit;
  H := CachedIccHeader(FWalk, S);
  if not H.Known then
    Mark(pcc_IccInput, True, 'ICC profile not read the way veraPDF reads it')
  else if not (((H.DeviceClass = 'prtr') or (H.DeviceClass = 'mntr') or (H.DeviceClass = 'scnr') or
    (H.DeviceClass = 'spac')) and ((H.ColorSpace = 'RGB ') or (H.ColorSpace = 'CMYK') or (H.ColorSpace = 'GRAY') or
    (H.ColorSpace = 'Lab ')) and (H.Major < 5)) then
    Mark(pcc_IccInput, False, 'ICC profile with device class "' + TextOf(H.DeviceClass) + '", colour space "' +
      TextOf(H.ColorSpace) + '", major version ' + IntToStr(H.Major));
end;

const
  { COS comparison results }
  ceq_Equal = 0;
  ceq_Different = 1;
  ceq_Unknown = 2;
  MaxSepsPerName = 200;
  MaxSepsPerParse = 5000;
  { comparison steps and stream bytes for Separations per document }
  MaxSepWork = 50000000;

{ veraPDF's equals of two COS values. AInArray: inside an array, where a
  reference is followed before comparing; elsewhere a reference equals only
  a reference to an equal object. Streams compare their entries except
  /Length, /Filter and /DecodeParms and their stored bytes. Anything this
  cannot decide is ceq_Unknown: a string with the same bytes (veraPDF also
  compares how it was written), a real 0 (its sign), a number beyond a long,
  a null against a missing value, a stream whose stored bytes are not
  certain, a reference chain too long; a reference to no object may make
  veraPDF throw. The work is counted against a budget.
  DE: veraPDFs equals zweier COS-Werte. AInArray: in einem Array, wo ein
  Verweis vor dem Vergleich verfolgt wird; sonst gleicht ein Verweis nur
  einem Verweis auf ein gleiches Objekt. Streams vergleichen ihre Eintraege
  ausser /Length, /Filter und /DecodeParms und ihre gespeicherten Bytes.
  Was sich so nicht entscheiden laesst, ist ceq_Unknown: ein String mit
  denselben Bytes (veraPDF vergleicht auch, wie er geschrieben wurde), eine
  reelle 0 (ihr Vorzeichen), eine Zahl jenseits von long, ein null gegen
  einen fehlenden Wert, ein Stream, dessen gespeicherte Bytes nicht sicher
  sind, eine zu lange Verweiskette; ein Verweis auf kein Objekt kann
  veraPDF eine Ausnahme werfen lassen. Die Arbeit zaehlt gegen ein Budget. }
function CosCompare(AWalk: TLandrixEInvoicePdfContentWalk; A, B: TLandrixEInvoicePdfObject; AInArray: Boolean;
  ADepth: Integer): Integer;
var
  I, R: Integer;
  Ra, Rb: TLandrixEInvoicePdfBytes;
  AnyUnknown, Gone: Boolean;

  function Follow(X: TLandrixEInvoicePdfObject; var AGone: Boolean): TLandrixEInvoicePdfObject;
  var
    Unsure: Boolean;
  begin
    Unsure := False;
    Result := LandrixEInvoicePdfResolveRef(AWalk.FDoc, X, Unsure);
    if Unsure then
      AGone := True
    else if Result = nil then
    begin
      AWalk.FThrows := True;
      AWalk.FMayThrow := True;
      AWalk.FIncomplete := True;
      AGone := True;
    end;
  end;

  function StoredBytes(X: TLandrixEInvoicePdfObject; out AData: TLandrixEInvoicePdfBytes): Boolean;
  var
    L: TLandrixEInvoicePdfObject;
  begin
    Result := False;
    AData := nil;
    if AWalk.FDoc.Encrypted then
      Exit;
    L := AWalk.DGetRef(X, 'Length');
    if (L = nil) or (L.Kind <> pok_Num) or not L.NumExact or (L.NumInt < 0) then
      Exit;
    if L.NumInt > MaxSepWork - AWalk.FSepWork then
    begin
      AWalk.FSepUnsure := True;
      Exit;
    end;
    Inc(AWalk.FSepWork, L.NumInt);
    if not AWalk.FDoc.GetStreamRaw(X, AData) then
      Exit;
    Result := L.NumInt = Length(AData);
  end;

  function DictEntries(X, Y: TLandrixEInvoicePdfObject; ASkipStream: Boolean): Integer;
  var
    J, Cx, Cy: Integer;
    Key: AnsiString;
    V: TLandrixEInvoicePdfObject;
  begin
    Result := ceq_Unknown;
    { each key is looked up in both dictionaries }
    Inc(AWalk.FSepWork, Int64(X.DVals.Count) * (Int64(X.DVals.Count) + Int64(Y.DVals.Count)) +
      Int64(Y.DVals.Count) * Int64(Y.DVals.Count));
    if AWalk.FSepWork > MaxSepWork then
    begin
      AWalk.FSepUnsure := True;
      Exit;
    end;
    Result := ceq_Equal;
    Cx := 0;
    Cy := 0;
    for J := 0 to Integer(X.DVals.Count) - 1 do
    begin
      Key := X.DKeys[J];
      if ASkipStream and ((Key = 'Length') or (Key = 'Filter') or (Key = 'DecodeParms')) then
        Continue;
      V := TLandrixEInvoicePdfObject(X.DVals[J]);
      { a key given twice, a null value: not decided }
      if (X.RawGet(Key) <> V) or (V.Kind = pok_Null) then
      begin
        Result := ceq_Unknown;
        Exit;
      end;
      Inc(Cx);
      if Y.RawGet(Key) = nil then
      begin
        Result := ceq_Different;
        Exit;
      end;
      case CosCompare(AWalk, V, Y.RawGet(Key), False, ADepth + 1) of
        ceq_Different:
          begin
            Result := ceq_Different;
            Exit;
          end;
        ceq_Unknown:
          Result := ceq_Unknown;
      end;
    end;
    for J := 0 to Integer(Y.DVals.Count) - 1 do
    begin
      Key := Y.DKeys[J];
      if ASkipStream and ((Key = 'Length') or (Key = 'Filter') or (Key = 'DecodeParms')) then
        Continue;
      V := TLandrixEInvoicePdfObject(Y.DVals[J]);
      if (Y.RawGet(Key) <> V) or (V.Kind = pok_Null) then
      begin
        Result := ceq_Unknown;
        Exit;
      end;
      Inc(Cy);
    end;
    if Cx <> Cy then
      Result := ceq_Different;
  end;

begin
  Result := ceq_Unknown;
  Inc(AWalk.FSepWork);
  if (ADepth > MaxCsDepth) or (AWalk.FSepWork > MaxSepWork) then
  begin
    AWalk.FSepUnsure := True;
    Exit;
  end;
  if (A = nil) or (B = nil) then
  begin
    if (A = nil) and (B = nil) then
      Result := ceq_Equal
    else if ((A <> nil) and (A.Kind = pok_Null)) or ((B <> nil) and (B.Kind = pok_Null)) then
      Result := ceq_Unknown
    else
      Result := ceq_Different;
    Exit;
  end;
  Gone := False;
  if AInArray or ((A.Kind = pok_Ref) and (B.Kind = pok_Ref)) then
  begin
    if A.Kind = pok_Ref then
      A := Follow(A, Gone);
    if B.Kind = pok_Ref then
      B := Follow(B, Gone);
    if Gone then
      Exit;
  end
  else if (A.Kind = pok_Ref) or (B.Kind = pok_Ref) then
  begin
    { a reference against a direct value }
    Result := ceq_Different;
    Exit;
  end;
  if A = B then
  begin
    Result := ceq_Equal;
    Exit;
  end;
  if A.Kind <> B.Kind then
  begin
    Result := ceq_Different;
    Exit;
  end;
  AnyUnknown := False;
  case A.Kind of
    pok_Null:
      Result := ceq_Equal;
    pok_Bool:
      if A.BoolVal = B.BoolVal then
        Result := ceq_Equal
      else
        Result := ceq_Different;
    pok_Num:
      if (not A.NumExact and (Abs(A.NumVal) >= 9.0E18)) or (not B.NumExact and (Abs(B.NumVal) >= 9.0E18)) then
        { a token beyond a long: not decided }
        Result := ceq_Unknown
      else if A.NumExact <> B.NumExact then
        Result := ceq_Different
      else if A.NumExact then
      begin
        if A.NumInt = B.NumInt then
          Result := ceq_Equal
        else
          Result := ceq_Different;
      end
      else if A.NumVal <> B.NumVal then
        Result := ceq_Different
      else if A.NumVal = 0 then
        Result := ceq_Unknown
      else
        Result := ceq_Equal;
    pok_Name:
      if A.NameVal = B.NameVal then
        Result := ceq_Equal
      else
        Result := ceq_Different;
    pok_Str:
      { veraPDF also compares how a string was written, and this reader may
        not keep the bytes veraPDF reads (an ASCII85 token): not decided }
      Result := ceq_Unknown;
    pok_Arr:
      begin
        if A.ArrCount <> B.ArrCount then
        begin
          Result := ceq_Different;
          Exit;
        end;
        for I := 0 to A.ArrCount - 1 do
        begin
          R := CosCompare(AWalk, A.ArrItem(I), B.ArrItem(I), True, ADepth + 1);
          if R = ceq_Different then
          begin
            Result := ceq_Different;
            Exit;
          end;
          if R = ceq_Unknown then
            AnyUnknown := True;
        end;
        if AnyUnknown then
          Result := ceq_Unknown
        else
          Result := ceq_Equal;
      end;
    pok_Dict:
      Result := DictEntries(A, B, False);
    pok_Stream:
      begin
        R := DictEntries(A, B, True);
        if R = ceq_Different then
        begin
          Result := ceq_Different;
          Exit;
        end;
        if not StoredBytes(A, Ra) or not StoredBytes(B, Rb) then
          Exit;
        if (Length(Ra) <> Length(Rb)) or ((Length(Ra) > 0) and not CompareMem(@Ra[0], @Rb[0], Length(Ra))) then
        begin
          Result := ceq_Different;
          Exit;
        end;
        { the same bytes: veraPDF also compares how they are filtered }
        if (R = ceq_Equal) and (CosCompare(AWalk, A.RawGet('Filter'), B.RawGet('Filter'), False, ADepth + 1) =
          ceq_Equal) and (CosCompare(AWalk, A.RawGet('DecodeParms'), B.RawGet('DecodeParms'), False, ADepth + 1) =
          ceq_Equal) then
          Result := ceq_Equal;
      end;
  else
    { references are resolved above }
  end;
end;

{ The alternate spaces of two Separations as veraPDF compares them (the
  objects of the spaces it builds): device spaces by family, a device space
  against an array differs, two arrays differ where their values differ; two
  equal arrays that are different objects are not decided (a reference may
  stand where the other has a direct value).
  DE: Die Alternativraeume zweier Separations, wie veraPDF sie vergleicht
  (die Objekte der Raeume, die es baut): Geraeteraeume nach Familie, ein
  Geraeteraum gegen ein Array ist verschieden, zwei Arrays verschieden, wo
  ihre Werte verschieden sind; zwei gleiche Arrays, die verschiedene Objekte
  sind, bleiben offen (ein Verweis kann stehen, wo das andere einen direkten
  Wert hat). }
function AltCompare(AWalk: TLandrixEInvoicePdfContentWalk; const A, B: TCsRef): Integer;
var
  DevA, DevB: Boolean;
begin
  Result := ceq_Unknown;
  DevA := A.Kind in [csk_Gray, csk_RGB, csk_CMYK];
  DevB := B.Kind in [csk_Gray, csk_RGB, csk_CMYK];
  if DevA and DevB then
  begin
    if A.Kind = B.Kind then
      Result := ceq_Equal
    else
      Result := ceq_Different;
  end
  else if (DevA and (B.Kind = csk_Value)) or (DevB and (A.Kind = csk_Value)) then
    Result := ceq_Different
  else if (A.Kind = csk_Value) and (B.Kind = csk_Value) then
  begin
    if A.V = B.V then
      Result := ceq_Equal
    else if CosCompare(AWalk, A.V, B.V, True, 0) = ceq_Different then
      Result := ceq_Different;
  end
  else if (A.Kind = csk_Null) and (B.Kind = csk_Null) then
    Result := ceq_Unknown;
end;

{ 6.2.4.4-2: veraPDF registers every Separation space it builds under its
  colourant name, document-wide; the rule compares them in Finish.
  DE: 6.2.4.4-2: veraPDF registriert jeden Separation-Raum, den es baut,
  unter seinem Farbmittelnamen, im ganzen Dokument; die Regel vergleicht
  sie in Finish. }
procedure TInterpreter.RecordSeparation(const C: TCsRef);
var
  Key: string;
  K: Integer;
  Sig: TSepSig;
  N: TLandrixEInvoicePdfObject;
  Alt: TCsRef;
begin
  if C.V.ArrCount > 2 then
    Alt := CsValue(FWalk, C.R, C.V.ArrItem(2), C.WasDefault, 0)
  else
    Alt := NullCs;
  { an indirect Separation is one object to veraPDF wherever it is used }
  if C.Num >= 0 then
    Key := 'N' + IntToStr(C.Num)
  else
    Key := 'D' + FWalk.ObjId(C.V) + '/' + FWalk.ObjId(C.R) + '/' + IntToStr(Ord(C.WasDefault));
  if FWalk.FSepKeys.Find(Key, K) then
  begin
    Sig := TSepSig(FWalk.FSepKeys.Objects[K]);
    if AltCompare(FWalk, Sig.Alt, Alt) <> ceq_Equal then
    begin
      Sig.Unsure := True;
      if Alt.Kind = csk_Null then
      begin
        FWalk.FThrows := True;
        FWalk.FMayThrow := True;
        FWalk.FIncomplete := True;
      end;
    end;
  end
  else
  begin
    Sig := TSepSig.Create;
    N := FWalk.ResolveRef(C.V.ArrItem(1));
    Sig.NameOk := (N <> nil) and (N.Kind = pok_Name);
    if Sig.NameOk then
      Sig.Name := N.NameVal;
    Sig.Alt := Alt;
    Sig.Tint := nil;
    if C.V.ArrCount > 3 then
      Sig.Tint := C.V.ArrItem(3);
    Sig.Num := C.Num;
    Sig.Index := Integer(FWalk.FSeps.Add(Sig));
    FWalk.FSepKeys.AddObject(Key, Sig);
  end;
  if Length(FParse.SepIdx) >= MaxSepsPerParse then
  begin
    FWalk.FSepUnsure := True;
    Exit;
  end;
  FParse.AddSep(Sig.Index, FCsMaybe > 0);
end;

{ A paint or text link of C: the overprint flag of the side and the mode
  go with it. }
procedure TInterpreter.PaintLink(const C: TCsRef; AStroke: Boolean);
begin
  if AStroke then
    FPaintFlag := FState.OPStroke
  else
    FPaintFlag := FState.OPFill;
  FPaintOPM := FState.OPM;
  FPaintOPMKnown := FState.OPMKnown;
  FPaintActive := True;
  { a mode not decided may be 0, the identity of every link that is no
    paint: nothing reached here is certain }
  if not FState.OPMKnown then
  begin
    Inc(FCsMaybe);
    FWalk.FOpmUnsure := True;
  end;
  try
    ExposeCs(C, True, 0);
  finally
    FPaintActive := False;
    if not FState.OPMKnown then
      Dec(FCsMaybe);
  end;
end;

{ 6.1.13-9 and 6.2.4.4-1: a DeviceN space has at most 32 colourants (every
  element of its names array counts), and each colourant other than None,
  Cyan, Magenta, Yellow and Black is a key of /Colorants or a name in
  /Process /Components of its attributes (with or without /Subtype
  /NChannel). Then its alternate space, its process space and the
  Separation spaces of /Colorants are linked.
  DE: 6.1.13-9 und 6.2.4.4-1: ein DeviceN-Raum hat hoechstens 32
  Farbmittel (jedes Element seines Namens-Arrays zaehlt), und jedes
  Farbmittel ausser None, Cyan, Magenta, Yellow und Black ist ein
  Schluessel von /Colorants oder ein Name in /Process /Components seiner
  Attribute (mit oder ohne /Subtype /NChannel). Danach werden sein
  Alternativraum, sein Prozessraum und die Separation-Raeume von
  /Colorants verknuepft. }
procedure TInterpreter.ExposeDeviceN(const C: TCsRef; ADepth: Integer);
var
  Names, Attrs, Colorants, Process, Comps, E, Item: TLandrixEInvoicePdfObject;
  I, K, Count: Integer;
  Found, Unsure, Missing: Boolean;
  Miss: string;
  B: TCsRef;
begin
  Names := FWalk.ResolveRef(C.V.ArrItem(1));
  Count := 0;
  if (Names <> nil) and (Names.Kind = pok_Arr) then
    Count := Names.ArrCount;
  if Count > 32 then
    Mark(pcc_DeviceNComponents, False, 'DeviceN colour space with ' + IntToStr(Count) + ' colourants');
  Attrs := nil;
  if C.V.ArrCount > 4 then
  begin
    Attrs := FWalk.ResolveRef(C.V.ArrItem(4));
    if (Attrs <> nil) and (Attrs.Kind <> pok_Dict) then
      Attrs := nil;
  end;
  Colorants := FWalk.DGetRef(Attrs, 'Colorants');
  if (Colorants <> nil) and (Colorants.Kind <> pok_Dict) then
    Colorants := nil;
  { the components count from a /Process stream too; its colour space
    only from a dictionary }
  Process := FWalk.DGetRef(Attrs, 'Process');
  if (Process <> nil) and not Process.IsDictLike then
    Process := nil;
  Comps := FWalk.DGetRef(Process, 'Components');
  if (Comps <> nil) and (Comps.Kind <> pok_Arr) then
    Comps := nil;
  if (Process <> nil) and (Process.Kind <> pok_Dict) then
    Process := nil;
  Miss := '';
  Missing := False;
  Unsure := False;
  { very many names: not compared one by one }
  if (Count > MaxColorantScan) or ((Comps <> nil) and (Comps.ArrCount > MaxColorantScan)) then
  begin
    Unsure := True;
    Count := 0;
  end;
  if Comps <> nil then
    Inc(FWalk.FCsSteps, Count * (Comps.ArrCount + 1))
  else
    Inc(FWalk.FCsSteps, Count);
  if FWalk.FCsSteps > MaxCsSteps then
  begin
    FWalk.FIncomplete := True;
    FWalk.FLimitHit := True;
    Exit;
  end;
  for I := 0 to Count - 1 do
  begin
    E := FWalk.ResolveRef(Names.ArrItem(I));
    if (E = nil) or (E.Kind <> pok_Name) then
    begin
      Unsure := True;
      Continue;
    end;
    if (E.NameVal = 'None') or (E.NameVal = 'Cyan') or (E.NameVal = 'Magenta') or (E.NameVal = 'Yellow') or
      (E.NameVal = 'Black') then
      Continue;
    Found := (Colorants <> nil) and (Colorants.RawGet(E.NameVal) <> nil);
    if not Found and (Comps <> nil) then
      for K := 0 to Comps.ArrCount - 1 do
      begin
        Item := FWalk.ResolveRef(Comps.ArrItem(K));
        if (Item <> nil) and (Item.Kind = pok_Name) and (Item.NameVal = E.NameVal) then
          Found := True;
      end;
    if not Found and not Missing then
    begin
      Missing := True;
      Miss := TextOf(E.NameVal);
    end;
  end;
  if Missing then
    Mark(pcc_DeviceNColorants, False, 'DeviceN colourant /' + Miss + ' neither in /Colorants nor a process component')
  else if Unsure then
    Mark(pcc_DeviceNColorants, True, 'DeviceN colourant that is no name');
  if C.V.ArrCount > 2 then
    ExposeCs(CsValue(FWalk, C.R, C.V.ArrItem(2), C.WasDefault, 0), True, ADepth + 1)
  else
    MaybeColour('DeviceN colour space without an alternate');
  if Process <> nil then
    ExposeCs(CsValue(FWalk, C.R, Process.RawGet('ColorSpace'), C.WasDefault, 0), False, ADepth + 1);
  if Colorants <> nil then
    for I := 0 to Integer(Colorants.DVals.Count) - 1 do
    begin
      Inc(FWalk.FCsSteps);
      if FWalk.FCsSteps > MaxCsSteps then
      begin
        FWalk.FIncomplete := True;
        FWalk.FLimitHit := True;
        Exit;
      end;
      B := CsValue(FWalk, C.R, TLandrixEInvoicePdfObject(Colorants.DVals[I]), False, 0);
      if (B.Kind = csk_Value) and (FirstName(FWalk, B.V) = 'Separation') then
        ExposeCs(B, False, ADepth + 1)
      else if B.Kind = csk_Unknown then
        MaybeColour('DeviceN colourant space not decided');
    end;
end;

{ The colour space of an image or a shading as veraPDF builds it: an
  image's name, or one-name array, through the resources of the invoking
  stream; any other value in the resources that supplied the object
  (FSiteFrom). }
function TInterpreter.SiteSpace(ARaw: TLandrixEInvoicePdfObject; AShading: Boolean): TCsRef;
var
  V, E, From: TLandrixEInvoicePdfObject;
begin
  From := FSiteFrom;
  if From = nil then
    From := FRes.Local;
  if From = nil then
    From := FRes.Page;
  V := FWalk.ResolveRef(ARaw);
  if not AShading and (V <> nil) and (V.Kind = pok_Arr) and (V.ArrCount = 1) then
  begin
    E := FWalk.ResolveRef(V.ArrItem(0));
    if (E <> nil) and (E.Kind = pok_Name) then
      V := E;
  end;
  if not AShading and (V <> nil) and (V.Kind = pok_Name) then
  begin
    Result := ResolveName(FWalk, FRes, V.NameVal);
    { veraPDF looks it up for the stream that met the image
      first, when the image is validated: 6.2.2-2 not decided }
    if CsInheritLevel(FWalk, FRes, V.NameVal) > 0 then
      FWalk.FInheritUnsure := True;
  end
  else
    Result := CsValue(FWalk, From, ARaw, False, 0);
end;

{ The link of an image's or a shading's colour space ARaw: none for null;
  bare /Pattern makes veraPDF throw. Certain only in the page's own content
  and where the resources make no difference.
  DE: Die Verknuepfung des Farbraums ARaw eines Bilds oder Shadings: keine
  fuer null; ein blosses /Pattern laesst veraPDF eine Ausnahme werfen.
  Sicher nur im eigenen Inhalt der Seite und wo die Ressourcen keinen
  Unterschied machen. }
procedure TInterpreter.SiteLink(ARaw: TLandrixEInvoicePdfObject; AShading: Boolean);
var
  C, Plain: TCsRef;
  Loose: Boolean;
  N: AnsiString;
begin
  C := SiteSpace(ARaw, AShading);
  Plain := CsValue(FWalk, nil, ARaw, False, 0);
  Loose := (FRes.Local <> FRes.Page) or (C.Kind <> Plain.Kind) or (C.V <> Plain.V);
  if C.Kind = csk_Value then
  begin
    N := FirstName(FWalk, C.V);
    if ((N = 'Indexed') or (N = 'Separation') or (N = 'DeviceN')) and (FWalk.DGetRef(C.R, 'ColorSpace') <> nil) then
      Loose := True;
  end;
  if C.Kind = csk_Null then
  begin
    { veraPDF may build a space where this lookup builds none }
    if Loose and (Plain.Kind <> csk_Null) then
      MaybeColour('image or shading colour space not decided');
    Exit;
  end;
  if (C.Kind = csk_Pattern) and (C.V = nil) and not Loose and (FCsMaybe = 0) then
  begin
    FWalk.FThrows := True;
    FWalk.FMayThrow := True;
    FWalk.FIncomplete := True;
    Exit;
  end;
  if Loose then
    Inc(FCsMaybe);
  try
    if (C.Kind = csk_PatternUnder) or (C.Kind = csk_Pattern) then
      MaybeColour('pattern as an image or shading colour space')
    else
    begin
      ExposeCs(C, False, 0);
      { the space veraPDF may build instead }
      if Loose and ((C.Kind <> Plain.Kind) or (C.V <> Plain.V)) and (Plain.Kind <> csk_Pattern) and
        (Plain.Kind <> csk_PatternUnder) then
        ExposeCs(Plain, False, 0);
    end;
  finally
    if Loose then
      Dec(FCsMaybe);
  end;
end;

{ An image XObject (Do; colour off by d1 does not matter): a stencil mask
  (/ImageMask true) takes the current fill space (null: no link), another
  image its /ColorSpace (missing or not built: no link; JPEG 2000 data: not
  decided). An indirect image is validated once, in the context veraPDF
  meets it first (a virtual parse per context). The colour spaces of its
  /SMask, /Mask and alternate images are not modelled: uncertain.
  DE: Ein Bild-XObject (Do; ob d1 die Farbe abgeschaltet hat, spielt keine
  Rolle): eine Schablonenmaske (/ImageMask true) nimmt den aktuellen
  Fuellfarbraum (null: keine Verknuepfung), ein anderes Bild seinen
  /ColorSpace (fehlt oder nicht gebaut: keine Verknuepfung; JPEG-2000-Daten:
  nicht entschieden). Ein indirektes Bild wird einmal geprueft, in dem
  Kontext, in dem veraPDF es zuerst trifft (eine virtuelle Analyse je
  Kontext). Die Farbraeume seiner /SMask-, /Mask- und Alternativbilder
  sind nicht nachgebildet: unsicher. }
procedure TInterpreter.ImageColour(V, ARaw: TLandrixEInvoicePdfObject; ADepth: Integer);
var
  Save: TVSave;
  Num: Integer;
  Ctx: string;
  B: TLandrixEInvoicePdfObject;
begin
  if (V = nil) or not V.IsDictLike then
    Exit;
  if ADepth > MaxImageDepth then
  begin
    MaybeColour('images nested too deep');
    Exit;
  end;
  B := FWalk.DGetRef(V, 'ImageMask');
  if (B <> nil) and (B.Kind = pok_Bool) and B.BoolVal then
    Ctx := 'M' + CsKey(FWalk, FState.FillCs)
  else
    Ctx := FWalk.ObjId(FRes.Local) + '/' + FWalk.ObjId(FRes.Page);
  if (ARaw <> nil) and (ARaw.Kind = pok_Ref) then
  begin
    Num := FWalk.LastRefNum(ARaw);
    if EnterVirtual('XI' + IntToStr(Num), Ctx, Num, Save) then
      try
        ImageSpace(V, ADepth);
      finally
        LeaveVirtual(Save);
      end;
  end
  else
    ImageSpace(V, ADepth);
end;

procedure TInterpreter.ImageSpace(V: TLandrixEInvoicePdfObject; ADepth: Integer);
var
  B, Raw, Img, A, Item: TLandrixEInvoicePdfObject;
  I: Integer;
begin
  B := FWalk.DGetRef(V, 'ImageMask');
  if (B <> nil) and (B.Kind = pok_Bool) and B.BoolVal then
  begin
    if FState.FillCs.Kind <> csk_Null then
      ExposeCs(FState.FillCs, False, 0);
  end
  else if IsJpx(FWalk, V) then
  begin
    { JPEG 2000: /ColorSpace (if any) is taken in a way not modelled }
    Inc(FCsMaybe);
    try
      MaybeColour('JPEG 2000 image');
      SiteLink(V.RawGet('ColorSpace'), False);
    finally
      Dec(FCsMaybe);
    end;
  end
  else
    SiteLink(V.RawGet('ColorSpace'), False);
  Inc(FCsMaybe);
  try
    Raw := V.RawGet('SMask');
    Img := FWalk.ResolveRef(Raw);
    if (Img <> nil) and (Img.Kind = pok_Stream) then
      ImageColour(Img, Raw, ADepth + 1);
    Raw := V.RawGet('Mask');
    Img := FWalk.ResolveRef(Raw);
    if (Img <> nil) and (Img.Kind = pok_Stream) then
      ImageColour(Img, Raw, ADepth + 1);
    A := FWalk.DGetRef(V, 'Alternates');
    if (A <> nil) and (A.Kind = pok_Arr) then
      for I := 0 to A.ArrCount - 1 do
      begin
        Item := FWalk.ResolveRef(A.ArrItem(I));
        if (Item = nil) or (Item.Kind <> pok_Dict) then
          Continue;
        Raw := Item.RawGet('Image');
        Img := FWalk.ResolveRef(Raw);
        if (Img <> nil) and (Img.Kind = pok_Stream) then
          ImageColour(Img, Raw, ADepth + 1);
      end;
  finally
    Dec(FCsMaybe);
  end;
end;

{ sh (and a shading pattern): the shading's /ColorSpace (missing or not
  built: no link); an indirect shading once per context.
  DE: sh (und ein Shading-Muster): der /ColorSpace des Shadings (fehlt oder
  nicht gebaut: keine Verknuepfung); ein indirektes Shading einmal je
  Kontext. }
procedure TInterpreter.ShadingColour(S, ARaw: TLandrixEInvoicePdfObject);
var
  Save: TVSave;
  Num: Integer;
begin
  if (S = nil) or not S.IsDictLike then
    Exit;
  if (ARaw <> nil) and (ARaw.Kind = pok_Ref) then
  begin
    Num := FWalk.LastRefNum(ARaw);
    if EnterVirtual('XH' + IntToStr(Num), FWalk.ObjId(FRes.Local) + '/' + FWalk.ObjId(FRes.Page), Num, Save) then
      try
        SiteLink(S.RawGet('ColorSpace'), True);
      finally
        LeaveVirtual(Save);
      end;
  end
  else
    SiteLink(S.RawGet('ColorSpace'), True);
end;

{ The space C is or holds (as an Indexed base or a pattern's underlying
  space) a Separation or DeviceN space, or that is not decided. }
function SpaceHasSpecial(AWalk: TLandrixEInvoicePdfContentWalk; const C: TCsRef; ADepth: Integer): Boolean;
var
  N: AnsiString;
begin
  Result := True;
  if (ADepth > MaxCsDepth) or (C.Kind = csk_Unknown) then
    Exit;
  Result := False;
  if C.Kind = csk_PatternUnder then
  begin
    Result := SpaceHasSpecial(AWalk, CsValue(AWalk, C.R, C.V.ArrItem(1), C.WasDefault, 0), ADepth + 1);
    Exit;
  end;
  if C.Kind <> csk_Value then
    Exit;
  N := FirstName(AWalk, C.V);
  if (N = 'Separation') or (N = 'DeviceN') then
    Result := True
  else if N = 'Indexed' then
    Result := SpaceHasSpecial(AWalk, CsValue(AWalk, C.R, C.V.ArrItem(1), False, 0), ADepth + 1);
end;

{ A name in V (an inline value, at any depth) selects a space that is or
  holds a Separation or DeviceN space in the stream's resources. }
function TInterpreter.CvSelectsSpecial(V: TCv; ADepth: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (V = nil) or (ADepth > MaxCsDepth) then
    Exit;
  if V.Kind = cvk_Name then
    Result := SpaceHasSpecial(FWalk, ResolveName(FWalk, FRes, V.Text), 0)
  else if V.Kind = cvk_Arr then
    for I := 0 to Integer(V.Items.Count) - 1 do
      if CvSelectsSpecial(TCv(V.Items[I]), ADepth + 1) then
      begin
        Result := True;
        Exit;
      end;
end;

{ The name AName occurs in V (an inline value), at any depth. }
function CvHasName(V: TCv; const AName: AnsiString; ADepth: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (V = nil) or (ADepth > MaxCsDepth) then
    Exit;
  if V.Kind = cvk_Name then
    Result := V.Text = AName
  else if V.Kind = cvk_Arr then
    for I := 0 to Integer(V.Items.Count) - 1 do
      if CvHasName(TCv(V.Items[I]), AName, ADepth + 1) then
      begin
        Result := True;
        Exit;
      end;
end;

{ A name of an inline image as veraPDF expands it (one table for colour
  spaces and filters). }
function InlineSpaceName(const AName: AnsiString): AnsiString;
begin
  if AName = 'AHx' then
    Result := 'ASCIIHexDecode'
  else if AName = 'A85' then
    Result := 'ASCII85Decode'
  else if AName = 'LZW' then
    Result := 'LZWDecode'
  else if AName = 'Fl' then
    Result := 'FlateDecode'
  else if AName = 'RL' then
    Result := 'RunLengthDecode'
  else if AName = 'CCF' then
    Result := 'CCITTFaxDecode'
  else if AName = 'DCT' then
    Result := 'DCTDecode'
  else if AName = 'G' then
    Result := 'DeviceGray'
  else if AName = 'RGB' then
    Result := 'DeviceRGB'
  else if AName = 'CMYK' then
    Result := 'DeviceCMYK'
  else if AName = 'I' then
    Result := 'Indexed'
  else
    Result := AName;
end;

{ An inline image at EI: a stencil (/IM or /ImageMask true) takes the
  current fill space (null: no link); another image its /CS: missing, a
  name that selects nothing or no name at all is veraPDF's empty space
  (DeviceGray); abbreviations count only as a name, not inside an array.
  An array is decided only as an /Indexed space with a named base.
  DE: Ein Inline-Bild bei EI: eine Schablone (/IM oder /ImageMask true)
  nimmt den aktuellen Fuellfarbraum (null: keine Verknuepfung); ein anderes
  Bild seinen /CS: fehlend, ein Name, der nichts auswaehlt, oder gar kein
  Name ist veraPDFs leerer Raum (DeviceGray); Abkuerzungen gelten nur als
  Name, nicht in einem Array. Ein Array wird nur als /Indexed-Raum mit
  benannter Basis entschieden. }
procedure TInterpreter.InlineColour(D: TCv);
var
  M, CS, First, Base: TCv;
  C, Plain: TCsRef;
  R: TLandrixEInvoicePdfObject;
  Loose, Differs: Boolean;
begin
  M := D.Get('IM');
  if M = nil then
    M := D.Get('ImageMask');
  if (M <> nil) and (M.Kind = cvk_Bool) and (M.IntVal = 1) then
  begin
    if FState.FillCs.Kind <> csk_Null then
      ExposeCs(FState.FillCs, False, 0);
    Exit;
  end;
  CS := D.Get('CS');
  if CS = nil then
    CS := D.Get('ColorSpace');
  Loose := FRes.Local <> FRes.Page;
  if Loose then
    Inc(FCsMaybe);
  try
    if (CS <> nil) and (CS.Kind = cvk_Name) then
    begin
      { veraPDF looks up an inline image's space otherwise than other
        names where the resources matter: then not decided }
      C := ResolveName(FWalk, FRes, InlineSpaceName(CS.Text));
      Plain := CsName(FWalk, nil, InlineSpaceName(CS.Text), False, 0);
      Differs := (C.Kind <> Plain.Kind) or (C.V <> Plain.V);
      if Differs then
        Inc(FCsMaybe);
      try
        if (C.Kind = csk_PatternUnder) or (Plain.Kind = csk_PatternUnder) then
          MaybeColour('inline image with a pattern colour space')
        else
        begin
          ExposeCs(C, True, 0);
          if Differs then
            ExposeCs(Plain, True, 0);
        end;
      finally
        if Differs then
          Dec(FCsMaybe);
      end;
    end
    else if (CS <> nil) and (CS.Kind = cvk_Arr) then
    begin
      First := nil;
      Base := nil;
      if CS.Items.Count >= 2 then
      begin
        First := TCv(CS.Items[0]);
        Base := TCv(CS.Items[1]);
      end;
      { veraPDF builds the array as it is: abbreviations inside it are
        names like any other }
      if (First <> nil) and (First.Kind = cvk_Name) and (First.Text = 'Indexed') and (Base.Kind = cvk_Name) then
      begin
        { the stream's own resources (none for a form without them) }
        R := FRes.Local;
        ExposeCs(CsName(FWalk, R, Base.Text, False, 0), True, 0);
      end
      else
      begin
        { an array not modelled may reach a shared colour space first; one
          with a Separation in it may make veraPDF throw }
        FWalk.FColourUnsure := True;
        if CvHasName(CS, 'Separation', 0) or CvHasName(CS, 'DeviceN', 0) or CvSelectsSpecial(CS, 0) then
        begin
          FWalk.FThrows := True;
          FWalk.FMayThrow := True;
          FWalk.FIncomplete := True;
        end;
        MaybeColour('inline image colour space array');
      end;
    end
    else if (CS <> nil) and (CS.Kind = cvk_Dict) then
      MaybeColour('inline image colour space dictionary')
    else
      Mark(pcc_DeviceGray, False, 'inline image without a colour space (DeviceGray to veraPDF)');
  finally
    if Loose then
      Dec(FCsMaybe);
  end;
end;

{ The /CS of a transparency group (a page's or a form's /Group dictionary;
  /S not needed), built in the resources of its owner only; missing or not
  built: no link.
  DE: Der /CS einer Transparenzgruppe (das /Group-Dictionary einer Seite
  oder eines Formulars; /S nicht noetig), gebaut nur in den Ressourcen
  seines Besitzers; fehlt oder nicht gebaut: keine Verknuepfung. }
procedure TInterpreter.GroupColour(G, R: TLandrixEInvoicePdfObject);
var
  C: TCsRef;
begin
  C := CsValue(FWalk, R, G.RawGet('CS'), False, 0);
  if C.Kind = csk_Null then
    Exit;
  if (C.Kind = csk_Pattern) and (C.V = nil) then
  begin
    FWalk.FThrows := True;
    FWalk.FMayThrow := True;
    FWalk.FIncomplete := True;
  end
  else if (C.Kind = csk_PatternUnder) or (C.Kind = csk_Pattern) then
    MaybeColour('group colour space with a pattern')
  else
    ExposeCs(C, False, 0);
end;

{ The identity veraPDF validates the /Group of AOwner under: an indirect
  group its own (context: the owner's resources R), a direct one its
  owner's (AOwnerKey; '' when the owner has none). False without a group
  dictionary.
  DE: Die Identitaet, unter der veraPDF die /Group von AOwner prueft: eine
  indirekte Gruppe ihre eigene (Kontext: die Ressourcen R des Besitzers),
  eine direkte die des Besitzers (AOwnerKey; '', wenn der Besitzer keine
  hat). False ohne Gruppen-Dictionary. }
function GroupKey(AWalk: TLandrixEInvoicePdfContentWalk; AOwner, R: TLandrixEInvoicePdfObject;
  const AOwnerKey: string; AOwnerNum: Integer; out AG: TLandrixEInvoicePdfObject; out AKey, ACtx: string;
  out ANum: Integer): Boolean;
var
  GRaw: TLandrixEInvoicePdfObject;
begin
  AKey := '';
  ACtx := '';
  ANum := -1;
  AG := nil;
  Result := False;
  if (AOwner = nil) or not AOwner.IsDictLike then
    Exit;
  GRaw := AOwner.RawGet('Group');
  AG := AWalk.ResolveRef(GRaw);
  Result := (AG <> nil) and (AG.Kind = pok_Dict);
  if not Result then
    Exit;
  if (GRaw <> nil) and (GRaw.Kind = pok_Ref) then
  begin
    ANum := AWalk.LastRefNum(GRaw);
    AKey := 'XQ' + IntToStr(ANum);
    ACtx := AWalk.ObjId(R);
  end
  else
  begin
    AKey := AOwnerKey;
    ANum := AOwnerNum;
  end;
end;

{ The group of a form XObject reached by Do. }
procedure TInterpreter.OwnerGroup(AOwner, R: TLandrixEInvoicePdfObject; const AOwnerKey: string;
  AOwnerNum: Integer);
var
  G: TLandrixEInvoicePdfObject;
  Key, Ctx: string;
  Num: Integer;
  Save: TVSave;
begin
  if not GroupKey(FWalk, AOwner, R, AOwnerKey, AOwnerNum, G, Key, Ctx, Num) then
    Exit;
  if Key = '' then
    GroupColour(G, R)
  else if EnterVirtual(Key, Ctx, Num, Save) then
    try
      GroupColour(G, R);
    finally
      LeaveVirtual(Save);
    end;
end;

{ Text shows link the fill space in rendering modes 0 and 4, the stroke
  space in 1 and 5, both in 2 and 6, none in 3 and 7.
  DE: Textausgaben verknuepfen den Fuellraum in den Darstellungsmodi 0 und
  4, den Strichraum in 1 und 5, beide in 2 und 6, keinen in 3 und 7. }
procedure TInterpreter.TextColour;
var
  M: Integer;
  Undecided: Boolean;
begin
  if not FState.ColorOn then
    Exit;
  M := FState.TextMode;
  Undecided := (M < 0) or (M > 7);
  if Undecided then
    Inc(FCsMaybe);
  try
    if Undecided or (M = 0) or (M = 4) or (M = 2) or (M = 6) then
      PaintLink(FState.FillCs, False);
    if Undecided or (M = 1) or (M = 5) or (M = 2) or (M = 6) then
      PaintLink(FState.StrokeCs, True);
  finally
    if Undecided then
      Dec(FCsMaybe);
  end;
end;

function IsNum(V: TCv): Boolean;
begin
  Result := (V <> nil) and ((V.Kind = cvk_Int) or (V.Kind = cvk_Real));
end;

function IsKind(V: TCv; AKind: TCvKind): Boolean;
begin
  Result := (V <> nil) and (V.Kind = AKind);
end;

{ The operands an operator passes on to the checks, as veraPDF's operator
  model does: positions count from the end (-1 the last operand), and a
  position with the wrong type passes nothing. }
procedure TInterpreter.Operate(AOp: TCv; AOps: TObjectList);
var
  L1, L2, L3: TCv;
  N: Integer;
  Pat, Stroke: Boolean;
  Cs: TCsRef;
  DevName: AnsiString;
  Sh, Raw: TLandrixEInvoicePdfObject;
begin
  FOp := TextOf(AOp.Text);
  N := Integer(AOps.Count);
  L1 := nil;
  L2 := nil;
  L3 := nil;
  if N >= 1 then
    L1 := TCv(AOps[N - 1]);
  if N >= 2 then
    L2 := TCv(AOps[N - 2]);
  if N >= 3 then
    L3 := TCv(AOps[N - 3]);
  case OpCode(AOp.Text) of
    oc_Number:
      if IsNum(L1) then
        ExposeNumber(L1);
    oc_Integer:
      if IsKind(L1, cvk_Int) then
        ExposeNumber(L1);
    oc_Dash:
      begin
        if IsKind(L2, cvk_Arr) then
          ExposeCos(L2, False);
        if IsNum(L1) then
          ExposeNumber(L1);
      end;
    oc_Intent:
      { veraPDF builds ri only while colour operators count. DE: veraPDF baut
      ri nur, solange Farboperatoren zaehlen. }
    if FState.ColorOn and IsKind(L1, cvk_Name) then
      begin
        ExposeName(L1);
        CheckIntent(L1.Text, 'ri');
      end;
    oc_Push:
      begin
        if Length(FStack) < MaxStack then
        begin
          SetLength(FStack, Length(FStack) + 1);
          FStack[High(FStack)] := FState;
        end
        else
          { not kept: only counted }
          Inc(FStackOver);
        if Length(FStack) + FStackOver > MaxNesting then
          Mark(pcc_Nesting, False, 'q nested ' + IntToStr(Length(FStack) + FStackOver) + ' levels deep');
      end;
    oc_Pop:
      if FStackOver > 0 then
      begin
        { the state this Q restores was not kept }
        Dec(FStackOver);
        FParse.Uncertain := True;
      end
      else if Length(FStack) > 0 then
      begin
        FState := FStack[High(FStack)];
        SetLength(FStack, Length(FStack) - 1);
      end;
    oc_NumberList:
      NumberList(AOps);
    oc_Glyph:
      begin
        NumberList(AOps);
        FState.ColorOn := False;
      end;
    oc_TwoNumbers:
      begin
        if IsNum(L2) then
          ExposeNumber(L2);
        if IsNum(L1) then
          ExposeNumber(L1);
      end;
    oc_Font:
      begin
        if IsKind(L2, cvk_Name) then
          ExposeName(L2);
        if IsNum(L1) then
          ExposeNumber(L1);
        SelectFont(AOps);
      end;
    oc_Show:
      begin
        if IsKind(L1, cvk_Str) then
          ExposeString(L1);
        ShowText;
        TextColour;
        if N >= 1 then
        begin
          TextTransp(TCv(AOps[0]));
          CheckGlyphs(TCv(AOps[0]));
        end
        else
          TextTransp(nil);
      end;
    oc_ShowSpaced:
      begin
        if IsKind(L1, cvk_Str) then
          ExposeString(L1);
        if N >= 3 then
        begin
          if IsNum(L3) then
            ExposeNumber(L3);
          if IsNum(L2) then
            ExposeNumber(L2);
        end;
        ShowText;
        TextColour;
        if N >= 1 then
        begin
          TextTransp(TCv(AOps[0]));
          CheckGlyphs(TCv(AOps[0]));
        end
        else
          TextTransp(nil);
      end;
    oc_ShowArray:
      begin
        if IsKind(L1, cvk_Arr) then
          ExposeCos(L1, False);
        ShowText;
        TextColour;
        if N >= 1 then
        begin
          TextTransp(TCv(AOps[0]));
          CheckGlyphs(TCv(AOps[0]));
        end
        else
          TextTransp(nil);
      end;
    oc_Color:
      if FState.ColorOn then
        TopNumbers(AOps);
    oc_SpaceStroke, oc_SpaceFill:
      { cs and CS select a space and link it at once (null: the empty space) }
      if FState.ColorOn then
      begin
        TopNumbers(AOps);
        Stroke := OpCode(AOp.Text) = oc_SpaceStroke;
        if Stroke then
          FState.StrokePat := -1
        else
          FState.FillPat := -1;
        if IsKind(L1, cvk_Name) then
        begin
          ExposeName(L1);
          CsInherit(L1.Text);
          Pat := IsPatternSpace(L1.Text);
          Cs := ResolveName(FWalk, FRes, L1.Text);
        end
        else
        begin
          Pat := False;
          Cs := NullCs;
        end;
        if Stroke then
        begin
          FState.StrokePattern := Pat;
          FState.StrokeCs := Cs;
        end
        else
        begin
          FState.FillPattern := Pat;
          FState.FillCs := Cs;
        end;
        { the pattern state and the space disagree (a default that leads
          to no object): not decided }
        if (Cs.Kind <> csk_Unknown) and (Pat <> ((Cs.Kind = csk_Pattern) or (Cs.Kind = csk_PatternUnder))) then
          FParse.Uncertain := True;
        ExposeCs(Cs, True, 0);
      end;
    oc_ColorNStroke, oc_ColorNFill:
      { scn and SCN: in a pattern space the pattern of the name, otherwise
        the current space is linked }
      if FState.ColorOn then
      begin
        TopNumbers(AOps);
        Stroke := OpCode(AOp.Text) = oc_ColorNStroke;
        if Stroke then
          Pat := FState.StrokePattern
        else
          Pat := FState.FillPattern;
        if IsKind(L1, cvk_Name) then
          ExposeName(L1);
        if Pat and IsKind(L1, cvk_Name) then
          ReachPattern(L1.Text, not Stroke)
        else if Pat then
        begin
          { without a pattern name veraPDF leaves the pattern space }
          Cs := NullCs;
          Cs.Kind := csk_Unknown;
          if Stroke then
            FState.StrokePat := -1
          else
            FState.FillPat := -1;
          if Stroke then
          begin
            FState.StrokePattern := False;
            FState.StrokeCs := Cs;
          end
          else
          begin
            FState.FillPattern := False;
            FState.FillCs := Cs;
          end;
          MaybeColour('pattern colour without a pattern name');
        end
        else if Stroke then
          ExposeCs(FState.StrokeCs, True, 0)
        else
          ExposeCs(FState.FillCs, True, 0);
      end;
    oc_DeviceStroke, oc_DeviceFill:
      { g, rg, k and the stroke forms: the device space, or the default
        space of the resources; where that gives nothing, the device space }
      if FState.ColorOn then
      begin
        TopNumbers(AOps);
        if IsKind(L1, cvk_Name) then
          ExposeName(L1);
        if (AOp.Text = 'G') or (AOp.Text = 'g') then
          DevName := 'DeviceGray'
        else if (AOp.Text = 'RG') or (AOp.Text = 'rg') then
          DevName := 'DeviceRGB'
        else
          DevName := 'DeviceCMYK';
        CsInherit(DevName);
        if OpCode(AOp.Text) = oc_DeviceStroke then
          FState.StrokePat := -1
        else
          FState.FillPat := -1;
        Pat := IsPatternSpace(DevName);
        Cs := ResolveName(FWalk, FRes, DevName);
        if Cs.Kind = csk_Null then
          Cs.Kind := DeviceKind(DevName);
        if OpCode(AOp.Text) = oc_DeviceStroke then
        begin
          FState.StrokePattern := Pat;
          FState.StrokeCs := Cs;
        end
        else
        begin
          FState.FillPattern := Pat;
          FState.FillCs := Cs;
        end;
        if (Cs.Kind <> csk_Unknown) and (Pat <> ((Cs.Kind = csk_Pattern) or (Cs.Kind = csk_PatternUnder))) then
          FParse.Uncertain := True;
        ExposeCs(Cs, True, 0);
      end;
    oc_PaintFill:
      begin
        TranspPaint(True, False);
        if FState.ColorOn then
          PaintLink(FState.FillCs, False);
      end;
    oc_PaintStroke:
      begin
        TranspPaint(False, True);
        if FState.ColorOn then
          PaintLink(FState.StrokeCs, True);
      end;
    oc_PaintBoth:
      begin
        TranspPaint(True, True);
        if FState.ColorOn then
        begin
          PaintLink(FState.FillCs, False);
          PaintLink(FState.StrokeCs, True);
        end;
      end;
    oc_TextMode:
      { veraPDF reads the first operand as an int; a missing, other or
        invalid mode is 0 (fill); a real number is not decided }
      begin
        FState.TextMode := 0;
        if (N >= 1) and IsKind(TCv(AOps[0]), cvk_Real) then
          FState.TextMode := -1;
        if (N >= 1) and IsKind(TCv(AOps[0]), cvk_Int) and (Narrow32(TCv(AOps[0]).IntVal) >= 0) and
          (Narrow32(TCv(AOps[0]).IntVal) <= 7) then
          FState.TextMode := Integer(Narrow32(TCv(AOps[0]).IntVal));
      end;
    oc_Shading:
      begin
        { 6.2.10-2: sh paints like a fill (any operands)
          DE: 6.2.10-2: sh malt wie ein Fuellen (gleich welche Operanden) }
        NoteTransp(MaxOf(TranspBase, FState.TFillA));
        if FState.ColorOn and IsKind(L1, cvk_Name) then
        begin
          Sh := Lookup('Shading', L1.Text, Raw);
          FSiteFrom := FLookupFrom;
          ShadingColour(Sh, Raw);
          FSiteFrom := nil;
        end;
      end;
    oc_ExtGState:
      if IsKind(L1, cvk_Name) then
        SetExtGState(L1.Text);
    oc_Do:
      begin
        { 6.2.10-2: Do paints like a fill, with what the XObject brings
          DE: 6.2.10-2: Do malt wie ein Fuellen, mit dem, was das XObject
          mitbringt }
        FDoTransp := 0;
        if IsKind(L1, cvk_Name) then
          ReachForm(L1.Text);
        NoteTransp(MaxOf(TranspBase, MaxOf(FState.TFillA, FDoTransp)));
      end;
    oc_Tag:
      if IsKind(L1, cvk_Name) then
        ExposeName(L1);
    oc_TagProps, oc_TagPropsBegin:
      begin
        if IsKind(L2, cvk_Name) then
          ExposeName(L2);
        if IsKind(L1, cvk_Dict) then
          ExposeCos(L1, True);
        if (OpCode(AOp.Text) = oc_TagPropsBegin) and IsKind(L2, cvk_Name) and (L2.Text = 'AF') and
          IsKind(L1, cvk_Name) then
          RegisterAF(L1.Text)
        else if IsKind(L1, cvk_Name) then
          TouchProperties(L1.Text);
      end;
    oc_Inline:
      if AOp.ImageDict <> nil then
        InlineImage(AOp.ImageDict);
    oc_None:
      { 6.2.2-1, also between BX and EX. DE: 6.2.2-1, auch zwischen BX und
        EX. }
      begin
        { 6.2.10-2: an EI without its image is still checked as a fill
          DE: 6.2.10-2: ein EI ohne sein Bild wird trotzdem wie ein Fuellen
          geprueft }
        if AOp.Text = 'EI' then
          NoteTransp(MaxOf(TranspBase, FState.TFillA));
        Mark(pcc_Undefined, False, 'undefined operator');
      end;
  else
    { n, h, W, W*, text objects, marked content end, BX/EX and unknown
      operators pass nothing on }
  end;
end;

procedure TInterpreter.Run(ALex: TContentLexer);
var
  T: TCv;
  Ops: TObjectList;
begin
  Ops := TObjectList.Create(False);
  try
    while True do
    begin
      T := ALex.Next;
      if T = nil then
        Break;
      if T.Kind <> cvk_Op then
      begin
        Ops.Add(T);
        if Ops.Count > MaxPending then
        begin
          FParse.Uncertain := True;
          Break;
        end;
        Continue;
      end;
      Operate(T, Ops);
      Ops.Clear;
      ALex.Release;
    end;
    { the operands kept for an operator may reach a limit the first pass
      did not }
    if ALex.Status <> lxs_Ok then
      FParse.Uncertain := True;
  finally
    Ops.Free;
  end;
end;

//==============================================================================
// TLandrixEInvoicePdfContentWalk
//==============================================================================

type
  TObjArray = array of TLandrixEInvoicePdfObject;

  { The parts of a contents array object as WalkPage reads them. }
  TPartsEntry = class(TObject)
  public
    First: Integer;
    Streams: TObjArray;
  end;

  { A sorted index of a dictionary's keys (DictGet). }
  TKeyIndex = class(TObject)
  public
    Keys: array of AnsiString;
    Vals: array of TLandrixEInvoicePdfObject;
    procedure Build(ADict: TLandrixEInvoicePdfObject);
    function Find(const AKey: AnsiString): TLandrixEInvoicePdfObject;
  end;

constructor TLandrixEInvoicePdfContentWalk.Create(ADoc: TLandrixEInvoicePdfDocument);
begin
  inherited Create;
  FDoc := ADoc;
  FParses := TObjectList.Create(True);
  FMemo := TStringList.Create;
  FMemo.Sorted := True;
  FMemo.Duplicates := dupIgnore;
  FActive := TStringList.Create;
  FType3Seen := TStringList.Create;
  FType3Seen.Sorted := True;
  FType3Seen.Duplicates := dupIgnore;
  FIccCache := TStringList.Create;
  FIccCache.Sorted := True;
  FSeps := TObjectList.Create(True);
  FSepKeys := TStringList.Create;
  FSepKeys.Sorted := True;
  FPageTpKey := TStringList.Create;
  FJpxCache := TStringList.Create;
  FJpxCache.Sorted := True;
  FFontCache := TStringList.Create;
  FFontCache.Sorted := True;
  FTrueTypeCache := TStringList.Create;
  FTrueTypeCache.Sorted := True;
  FCurPageNum := -1;
  FType3Replayed := TStringList.Create;
  FType3Replayed.Sorted := True;
  FType3Replayed.Duplicates := dupIgnore;
  FWalkedPages := TStringList.Create;
  FWalkedPages.Sorted := True;
  FWalkedPages.Duplicates := dupIgnore;
  FPartsCache := TStringList.Create;
  FPartsCache.Sorted := True;
  FDictIndex := TStringList.Create;
  FDictIndex.Sorted := True;
  { built at run time: literals of this size lose precision as Extended }
  FMaxReal := FloatOf('3.403e38');
  FMinReal := FloatOf('1.175e-38');
  FMaxDouble := FloatOf('1.7976931348623157e308');
  FTiny := FloatOf('1e-300');
  FTwo31 := FloatOf('2147483648');
  { a decimal this close to a limit may round to either side of it }
  FNearHigh := FloatOf('3.4029e38');
  FNearHighTop := FloatOf('3.4031e38');
  FNearLow := FloatOf('1.1749e-38');
  FNearLowTop := FloatOf('1.1751e-38');
end;

destructor TLandrixEInvoicePdfContentWalk.Destroy;
var
  I: Integer;
begin
  for I := 0 to FType3Seen.Count - 1 do
    FType3Seen.Objects[I].Free;
  FType3Seen.Free;
  for I := 0 to FIccCache.Count - 1 do
    FIccCache.Objects[I].Free;
  FIccCache.Free;
  FSepKeys.Free;
  FSeps.Free;
  FPageTpKey.Free;
  for I := 0 to FJpxCache.Count - 1 do
    FJpxCache.Objects[I].Free;
  FJpxCache.Free;
  for I := 0 to FFontCache.Count - 1 do
    FFontCache.Objects[I].Free;
  FFontCache.Free;
  for I := 0 to FTrueTypeCache.Count - 1 do
    FTrueTypeCache.Objects[I].Free;
  FTrueTypeCache.Free;
  for I := 0 to FPartsCache.Count - 1 do
    FPartsCache.Objects[I].Free;
  FPartsCache.Free;
  for I := 0 to FDictIndex.Count - 1 do
    FDictIndex.Objects[I].Free;
  FDictIndex.Free;
  FWalkedPages.Free;
  FType3Replayed.Free;
  FActive.Free;
  FMemo.Free;
  FParses.Free;
  inherited Destroy;
end;

{ A reference to the object in use with that number and generation; nil if
  there is none (veraPDF reads null); a direct object as it is. }
function TLandrixEInvoicePdfContentWalk.ResolveRef(ARaw: TLandrixEInvoicePdfObject): TLandrixEInvoicePdfObject;
var
  Unsure: Boolean;
begin
  Unsure := False;
  Result := LandrixEInvoicePdfResolveRef(FDoc, ARaw, Unsure);
  if Unsure then
  begin
    FIncomplete := True;
    FLimitHit := True;
  end;
end;

{ The number of the object at the end of a reference chain (an object that
  holds a reference stands for the object it names). }
function TLandrixEInvoicePdfContentWalk.LastRefNum(ARaw: TLandrixEInvoicePdfObject): Integer;
var
  O: TLandrixEInvoicePdfObject;
  Depth: Integer;
begin
  Result := -1;
  O := ARaw;
  Depth := 0;
  while (O <> nil) and (O.Kind = pok_Ref) and (Depth <= 32) do
  begin
    Result := O.RefNum;
    O := FDoc.GetObject(O.RefNum);
    Inc(Depth);
  end;
end;

{ The entry AKey of a dictionary or stream, resolved as ResolveRef does. }
function TLandrixEInvoicePdfContentWalk.DGetRef(AObj: TLandrixEInvoicePdfObject;
  const AKey: AnsiString): TLandrixEInvoicePdfObject;
begin
  Result := nil;
  if (AObj = nil) or not AObj.IsDictLike then
    Exit;
  Result := ResolveRef(DictGet(AObj, AKey));
end;

{ Byte order of two keys (no locale): <0, 0, >0. }
function CompareKeys(const A, B: AnsiString): Integer;
var
  I, N: Integer;
begin
  N := Length(A);
  if Length(B) < N then
    N := Length(B);
  for I := 1 to N do
    if A[I] <> B[I] then
    begin
      Result := Ord(A[I]) - Ord(B[I]);
      Exit;
    end;
  Result := Length(A) - Length(B);
end;

procedure TKeyIndex.Build(ADict: TLandrixEInvoicePdfObject);
var
  P, Temp: TIntArray;
  N, Width, Lo, Mid, Hi, L, R, K, I: Integer;
begin
  N := Integer(ADict.DVals.Count);
  P := nil;
  Temp := nil;
  SetLength(P, N);
  SetLength(Temp, N);
  for I := 0 to N - 1 do
    P[I] := I;
  { stable merge sort of the positions by key: equal keys keep their order }
  Width := 1;
  while Width < N do
  begin
    Lo := 0;
    while Lo < N do
    begin
      Mid := Lo + Width;
      if Mid > N then
        Mid := N;
      Hi := Mid + Width;
      if Hi > N then
        Hi := N;
      L := Lo;
      R := Mid;
      for K := Lo to Hi - 1 do
        if (L < Mid) and ((R >= Hi) or (CompareKeys(ADict.DKeys[P[L]], ADict.DKeys[P[R]]) <= 0)) then
        begin
          Temp[K] := P[L];
          Inc(L);
        end
        else
        begin
          Temp[K] := P[R];
          Inc(R);
        end;
      Lo := Hi;
    end;
    for K := 0 to N - 1 do
      P[K] := Temp[K];
    Width := Width * 2;
  end;
  { of repeated keys the last one counts, as in RawGet }
  SetLength(Keys, N);
  SetLength(Vals, N);
  K := 0;
  for I := 0 to N - 1 do
  begin
    if (I + 1 < N) and (CompareKeys(ADict.DKeys[P[I]], ADict.DKeys[P[I + 1]]) = 0) then
      Continue;
    Keys[K] := ADict.DKeys[P[I]];
    Vals[K] := TLandrixEInvoicePdfObject(ADict.DVals[P[I]]);
    Inc(K);
  end;
  SetLength(Keys, K);
  SetLength(Vals, K);
end;

function TKeyIndex.Find(const AKey: AnsiString): TLandrixEInvoicePdfObject;
var
  Lo, Hi, Mid, Cmp: Integer;
begin
  Result := nil;
  Lo := 0;
  Hi := Integer(Length(Keys)) - 1;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    Cmp := CompareKeys(Keys[Mid], AKey);
    if Cmp = 0 then
    begin
      Result := Vals[Mid];
      Exit;
    end;
    if Cmp < 0 then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
end;

{ ADict.RawGet(AKey) (the last of repeated keys); a dictionary with many
  keys gets a sorted index once (a resource dictionary of thousands of
  entries looked into for every Do would be quadratic).
  DE: ADict.RawGet(AKey); ein Dictionary mit vielen Schluesseln bekommt
  einmal einen sortierten Index. }
function TLandrixEInvoicePdfContentWalk.DictGet(ADict: TLandrixEInvoicePdfObject;
  const AKey: AnsiString): TLandrixEInvoicePdfObject;
var
  Idx: Integer;
  L: TKeyIndex;
  Id: string;
begin
  if Integer(ADict.DVals.Count) <= DictIndexFrom then
  begin
    Result := ADict.RawGet(AKey);
    Exit;
  end;
  Id := IntToStr(ADict.Serial);
  Idx := FDictIndex.IndexOf(Id);
  if Idx < 0 then
  begin
    L := TKeyIndex.Create;
    try
      L.Build(ADict);
    except
      L.Free;
      raise;
    end;
    Idx := FDictIndex.AddObject(Id, L);
  end;
  Result := TKeyIndex(FDictIndex.Objects[Idx]).Find(AKey);
end;

{ A key of a parsed object for the memo: its serial number. }
function TLandrixEInvoicePdfContentWalk.ObjId(AObj: TLandrixEInvoicePdfObject): string;
begin
  if AObj = nil then
    Result := '-'
  else
    Result := IntToStr(AObj.Serial);
end;

{ The data veraPDF reads from a stream: none for an unknown filter or
  DCTDecode; False (not decided) for an encrypted document, a /Length that
  does not hold, decode parameters, other filters and Flate data that is not
  a clean zlib stream. }
function TLandrixEInvoicePdfContentWalk.StreamBytes(AStream: TLandrixEInvoicePdfObject;
  out AData: TLandrixEInvoicePdfBytes): Boolean;
var
  Raw, Cur, Next: TLandrixEInvoicePdfBytes;
  F, Item, L, Parms: TLandrixEInvoicePdfObject;
  Names: array of AnsiString;
  I: Integer;
begin
  Result := False;
  AData := nil;
  Cur := nil;
  Next := nil;
  if FDoc.Encrypted then
    Exit;
  if not FDoc.GetStreamRaw(AStream, Raw) then
    Exit;
  L := DGetRef(AStream, 'Length');
  if (L = nil) or (L.Kind <> pok_Num) or (L.AsInt <> Length(Raw)) then
    Exit;
  F := DGetRef(AStream, 'Filter');
  if (F = nil) or (F.Kind = pok_Null) then
  begin
    AData := Raw;
    Result := True;
    Exit;
  end;
  Names := nil;
  if F.Kind = pok_Name then
  begin
    SetLength(Names, 1);
    Names[0] := F.NameVal;
  end
  else if F.Kind = pok_Arr then
  begin
    SetLength(Names, F.ArrCount);
    for I := 0 to F.ArrCount - 1 do
    begin
      Item := ResolveRef(F.ArrItem(I));
      if (Item = nil) or (Item.Kind <> pok_Name) then
        Exit;
      Names[I] := Item.NameVal;
    end;
  end
  else
    Exit;
  for I := 0 to Integer(Length(Names)) - 1 do
    if (Names[I] = 'DCTDecode') or (Names[I] = 'DCT') or not InList(Names[I], KnownFilters) then
    begin
      { veraPDF has no decoder here: the stream reads as empty }
      Result := True;
      Exit;
    end;
  for I := 0 to Integer(Length(Names)) - 1 do
    if Names[I] <> 'FlateDecode' then
      Exit;
  Parms := DGetRef(AStream, 'DecodeParms');
  if (Parms <> nil) and (Parms.Kind <> pok_Null) then
    Exit;
  Cur := Raw;
  for I := 0 to Integer(Length(Names)) - 1 do
  begin
    if not LandrixEInvoicePdfInflateStrict(Cur, Next) then
      Exit;
    Cur := Next;
  end;
  AData := Cur;
  Result := True;
end;

procedure TLandrixEInvoicePdfContentWalk.Run;
var
  Pages: TLandrixEInvoicePdfObject;
begin
  if FDoc.Catalog = nil then
    FIncomplete := True
  else
  begin
    { the catalog as veraPDF reaches it, generations checked }
    if (FDoc.RootRef = nil) or (FDoc.RootRef.Kind <> pok_Ref) or (ResolveRef(FDoc.RootRef) <> FDoc.Catalog) then
    begin
      FIncomplete := True;
      FPagesUnsure := True;
    end;
    Pages := DGetRef(FDoc.Catalog, 'Pages');
    WalkPages(Pages, nil, 0);
  end;
  ScanTiling;
  ScanAlternates;
  Finish;
end;

{ veraPDF throws (and reports nothing) on an image whose /Alternates holds a
  dictionary without an image stream, and on a Type 0 font it cannot build. Whether it reaches such an image
  depends on the content it reads first, so any such dictionary anywhere
  in the file leaves every content rule incomplete.
  DE: veraPDF wirft eine Ausnahme (und meldet nichts) bei einem Bild, dessen
  /Alternates ein Dictionary ohne Bild-Stream enthaelt, und bei einer
  Type-0-Schrift, die es nicht aufbauen kann. Ob es so ein Bild
  erreicht, haengt davon ab, welchen Inhalt es zuerst liest; daher laesst
  jedes solche Dictionary irgendwo in der Datei jede Content-Regel
  unvollstaendig. }
procedure TLandrixEInvoicePdfContentWalk.ScanAlternates;
const
  MaxScanNodes = 2000000;
  MaxScanDepth = 200;
var
  N, Count, Nodes: Integer;
  O: TLandrixEInvoicePdfObject;
  X: TLandrixEInvoicePdfXrefEntry;
  Done: array of Boolean;

  { veraPDF throws when it builds a Type 0 font without /Encoding, or one
    whose embedded CMap reaches a stream of its /UseCMap chain again }
  function Type0Throws(T: TLandrixEInvoicePdfObject): Boolean;
  var
    E, U: TLandrixEInvoicePdfObject;
    Seen: TObjectList;
  begin
    Result := True;
    E := DictGet(T, 'Encoding');
    if (E = nil) or (E.Kind = pok_Null) then
      Exit;
    Result := False;
    Seen := TObjectList.Create(False);
    try
      U := ResolveRef(E);
      while (U <> nil) and (U.Kind = pok_Stream) do
      begin
        if (Seen.IndexOf(U) >= 0) or (Seen.Count > 64) then
        begin
          Result := True;
          Exit;
        end;
        Seen.Add(U);
        U := DGetRef(U, 'UseCMap');
      end;
    finally
      Seen.Free;
    end;
  end;

  procedure Visit(V: TLandrixEInvoicePdfObject; ADepth: Integer);
  var
    I, M: Integer;
    A, Item, Img, Raw: TLandrixEInvoicePdfObject;
  begin
    if (V = nil) or FThrows then
      Exit;
    Inc(Nodes);
    if (Nodes > MaxScanNodes) or (ADepth > MaxScanDepth) then
    begin
      FThrows := True;
      Exit;
    end;
    case V.Kind of
      pok_Arr:
        for I := 0 to V.ArrCount - 1 do
          if (V.ArrItem(I) <> nil) and (V.ArrItem(I).Kind <> pok_Ref) then
            Visit(V.ArrItem(I), ADepth + 1);
      pok_Dict, pok_Stream:
        begin
          Raw := V.RawGet('Alternates');
          A := ResolveRef(Raw);
          { an indirect array is looked at once }
          M := LastRefNum(Raw);
          if (M >= 0) and (M < Count) then
          begin
            if Done[M] then
              A := nil
            else
              Done[M] := True;
          end;
          if (A <> nil) and (A.Kind = pok_Arr) then
            for I := 0 to A.ArrCount - 1 do
            begin
              Inc(Nodes);
              if Nodes > MaxScanNodes then
              begin
                FThrows := True;
                Exit;
              end;
              Item := ResolveRef(A.ArrItem(I));
              if (Item = nil) or (Item.Kind <> pok_Dict) then
                Continue;
              Img := DGetRef(Item, 'Image');
              if (Img = nil) or (Img.Kind <> pok_Stream) then
              begin
                FThrows := True;
                FMayThrow := True;
                Exit;
              end;
            end;
          { an image with JPEG 2000 data that makes veraPDF throw: it reads
            the images of resources before validating anything }
          Raw := DGetRef(V, 'Subtype');
          if (Raw <> nil) and (Raw.Kind = pok_Name) and (Raw.NameVal = 'Image') and IsJpxRead(Self, V) and
            ((V.Kind <> pok_Stream) or JpxEntryOf(Self, V).Throws) then
          begin
            FThrows := True;
            FMayThrow := True;
            Exit;
          end;
          if (V.Kind = pok_Dict) and (Raw <> nil) and (Raw.Kind = pok_Name) and (Raw.NameVal = 'Type0') and
            Type0Throws(V) then
          begin
            FThrows := True;
            FMayThrow := True;
            Exit;
          end;
          for I := 0 to Integer(V.DVals.Count) - 1 do
            if (V.DVals[I] <> nil) and (TLandrixEInvoicePdfObject(V.DVals[I]).Kind <> pok_Ref) then
              Visit(TLandrixEInvoicePdfObject(V.DVals[I]), ADepth + 1);
        end;
    else
      { numbers, strings, names: nothing }
    end;
  end;

begin
  Count := FDoc.XrefCount;
  Nodes := 0;
  Done := nil;
  SetLength(Done, Count);
  for N := 0 to Count - 1 do
    Done[N] := False;
  for N := 0 to Count - 1 do
  begin
    if FThrows then
      Break;
    X := FDoc.XrefEntry(N);
    if not X.Known or (X.Kind = pxk_Free) then
      Continue;
    O := FDoc.GetObject(N);
    if O <> nil then
      Visit(O, 0);
  end;
  if FThrows then
    FIncomplete := True;
end;

{ veraPDF also reads a tiling pattern that stands where a colour space is
  expected (a /ColorSpace entry or default, an Indexed base, a Separation or
  DeviceN alternate, the colour space of a shading, of a group or of an
  inline image). The walk reaches tiling patterns through scn only, so one
  referenced from anywhere but a /Pattern resource leaves the content rules
  incomplete. }
procedure TLandrixEInvoicePdfContentWalk.ScanTiling;
const
  MaxScanNodes = 2000000;
  MaxScanDepth = 200;
var
  N, Count, Nodes: Integer;
  Tiling, PatDict: array of Boolean;
  O: TLandrixEInvoicePdfObject;
  Found, Bad, Collect: Boolean;
  X: TLandrixEInvoicePdfXrefEntry;
  Pass: Integer;

  { AAllowed: V stands where a tiling pattern may; APatterns: V is a
    /Pattern resource dictionary (its values may be tiling patterns) }
  procedure Visit(V: TLandrixEInvoicePdfObject; AAllowed, APatterns: Boolean; ADepth: Integer);
  var
    I, M, Hops: Integer;
    K, T: TLandrixEInvoicePdfObject;
  begin
    if (V = nil) or Bad then
      Exit;
    Inc(Nodes);
    if (Nodes > MaxScanNodes) or (ADepth > MaxScanDepth) then
    begin
      Bad := True;
      Exit;
    end;
    case V.Kind of
      pok_Ref:
        if not Collect and not AAllowed then
        begin
          { the object at the end of a reference chain }
          M := V.RefNum;
          T := FDoc.GetObject(M);
          Hops := 0;
          while (T <> nil) and (T.Kind = pok_Ref) and (Hops < 32) do
          begin
            M := T.RefNum;
            T := FDoc.GetObject(M);
            Inc(Hops);
          end;
          if (M >= 0) and (M < Count) and Tiling[M] then
            Bad := True;
        end;
      pok_Arr:
        if V.ArrCount = 1 then
          Visit(V.ArrItem(0), AAllowed, False, ADepth + 1)
        else
          for I := 0 to V.ArrCount - 1 do
            Visit(V.ArrItem(I), False, False, ADepth + 1);
      pok_Dict, pok_Stream:
        for I := 0 to Integer(V.DVals.Count) - 1 do
        begin
          K := TLandrixEInvoicePdfObject(V.DVals[I]);
          if not APatterns and (V.DKeys[I] = 'Pattern') and (K <> nil) and (K.Kind = pok_Ref) then
          begin
            if Collect and (K.RefNum >= 0) and (K.RefNum < Count) then
              PatDict[K.RefNum] := True;
          end
          else if APatterns then
            Visit(K, True, False, ADepth + 1)
          else
            Visit(K, False, (V.DKeys[I] = 'Pattern') and (K <> nil) and (K.Kind = pok_Dict), ADepth + 1);
        end;
    else
      { numbers, strings, names: nothing }
    end;
  end;

begin
  Count := FDoc.XrefCount;
  Tiling := nil;
  PatDict := nil;
  SetLength(Tiling, Count);
  SetLength(PatDict, Count);
  Found := False;
  for N := 0 to Count - 1 do
  begin
    Tiling[N] := False;
    PatDict[N] := False;
    X := FDoc.XrefEntry(N);
    if not X.Known or (X.Kind = pxk_Free) then
      Continue;
    O := FDoc.GetObject(N);
    if (O <> nil) and (O.Kind = pok_Stream) and (PatternTypeOf(Self, O) = 1) then
    begin
      Tiling[N] := True;
      Found := True;
    end;
  end;
  if not Found then
    Exit;
  Bad := False;
  { first the indirect /Pattern dictionaries, then every reference }
  for Pass := 0 to 1 do
  begin
    Collect := Pass = 0;
    Nodes := 0;
    for N := 0 to Count - 1 do
    begin
      if Bad then
        Break;
      X := FDoc.XrefEntry(N);
      if not X.Known or (X.Kind = pxk_Free) then
        Continue;
      O := FDoc.GetObject(N);
      if O = nil then
        Continue;
      Visit(O, False, not Collect and PatDict[N] and (O.Kind = pok_Dict), 0);
    end;
  end;
  if Bad then
  begin
    FIncomplete := True;
    FLimitHit := True;
  end;
end;

{ The pages below ANode; the number of leaves walked. veraPDF finds a page
  by its index through the /Count of the nodes: where a node's /Count does
  not match its leaves, it may see fewer or other pages. }
{ The resources of a page tree node: its own /Resources where it has the
  entry (nil if that is no dictionary), else AInherited from the node above
  in the walk (not from /Parent). }
function NodeResources(AWalk: TLandrixEInvoicePdfContentWalk; ANode, AInherited: TLandrixEInvoicePdfObject):
  TLandrixEInvoicePdfObject;
var
  R: TLandrixEInvoicePdfObject;
begin
  Result := AInherited;
  R := ANode.RawGet('Resources');
  if R = nil then
    Exit;
  Result := AWalk.ResolveRef(R);
  if (Result <> nil) and not Result.IsDictLike then
    Result := nil;
end;

function TLandrixEInvoicePdfContentWalk.WalkPages(ANode, AInherited: TLandrixEInvoicePdfObject; ADepth: Integer): Integer;
var
  Kids, T, Inh: TLandrixEInvoicePdfObject;
  Count: Int64;
  I: Integer;
  PageKey: string;
begin
  Result := 0;
  if (ANode = nil) or not ANode.IsDictLike then
  begin
    FIncomplete := True;
    FPagesUnsure := True;
    Exit;
  end;
  Inc(FPageNodes);
  if (ADepth > MaxPageDepth) or (FPageNodes > MaxPageNodes) then
  begin
    FIncomplete := True;
    FPagesUnsure := True;
    Exit;
  end;
  { the root's /Type is not read; a page's /Kids neither }
  T := nil;
  if ADepth > 0 then
    T := DGetRef(ANode, 'Type');
  Kids := nil;
  if not ((T <> nil) and (T.Kind = pok_Name) and (T.NameVal = 'Page')) then
    Kids := DGetRef(ANode, 'Kids');
  Inh := NodeResources(Self, ANode, AInherited);
  { veraPDF makes the root a node and tells the kids by /Type; another type
    stops its walk }
  if (ADepth > 0) and ((T = nil) or (T.Kind <> pok_Name) or ((T.NameVal <> 'Page') and (T.NameVal <> 'Pages'))) then
  begin
    FIncomplete := True;
    FPagesUnsure := True;
  end;
  if (ADepth = 0) or ((T <> nil) and (T.Kind = pok_Name) and (T.NameVal = 'Pages')) or
    ((Kids <> nil) and (Kids.Kind = pok_Arr) and not ((T <> nil) and (T.Kind = pok_Name) and (T.NameVal = 'Page'))) then
  begin
    if (Kids <> nil) and (Kids.Kind = pok_Arr) then
      for I := 0 to Kids.ArrCount - 1 do
      begin
        if Kids.ArrItem(I).Kind = pok_Ref then
          FCurPageNum := LastRefNum(Kids.ArrItem(I))
        else
          FCurPageNum := -1;
        Inc(Result, WalkPages(ResolveRef(Kids.ArrItem(I)), Inh, ADepth + 1));
      end;
    { a /Count that is no integer counts 0 }
    if not IntegerOf(DGetRef(ANode, 'Count'), Count) then
      Count := 0;
    if Narrow32(Count) <> Result then
    begin
      FIncomplete := True;
      FPagesUnsure := True;
    end;
    Exit;
  end;
  Result := 1;
  { a page object reached again with the same resources gives the same
    parses: walked once (a tree of many references to one page would
    repeat the whole work) }
  PageKey := ObjId(ANode) + '/' + ObjId(Inh);
  if FWalkedPages.IndexOf(PageKey) >= 0 then
    Exit;
  FWalkedPages.Add(PageKey);
  WalkPage(ANode, Inh);
end;

{ The /Group of a page or an annotation appearance (AOwner, resources R):
  a virtual parse reached from the page, once per key. }
procedure RootGroup(AWalk: TLandrixEInvoicePdfContentWalk; const AKey: string; ANum: Integer;
  AOwner, R: TLandrixEInvoicePdfObject);
var
  G: TLandrixEInvoicePdfObject;
  Idx, Num: Integer;
  New: Boolean;
  Interp: TInterpreter;
  Key, Ctx: string;
begin
  if not GroupKey(AWalk, AOwner, R, AKey, ANum, G, Key, Ctx, Num) then
    Exit;
  Idx := VirtualParse(AWalk, Key, Ctx + '/0', Num, True, New);
  if not New then
    Exit;
  Interp := TInterpreter.Create;
  try
    Interp.FWalk := AWalk;
    Interp.FDoc := AWalk.FDoc;
    Interp.FParse := TContentParse(AWalk.FParses[Idx]);
    Interp.FParseIndex := Idx;
    Interp.FRes.Local := R;
    Interp.FRes.Page := R;
    Interp.FOp := 'Group';
    Interp.GroupColour(G, R);
  finally
    Interp.Free;
  end;
end;

{ A page: its /Contents (a stream or the streams of an array) and the
  appearances /N, /D and /R (a stream or the streams of a state dictionary)
  of its annotations; resources from the page or up the /Parent chain. }
function ApTransp(AWalk: TLandrixEInvoicePdfContentWalk; AIndex: Integer): Integer; forward;

procedure TLandrixEInvoicePdfContentWalk.WalkPage(APage, AInherited: TLandrixEInvoicePdfObject);
const
  ApKeys: array[0..2] of AnsiString = ('N', 'D', 'R');
var
  PageNum, Tp, Idx, NoCs: Integer;
  PageRes, C, Raw, S, Annots, A, AP, V, Raw2, S2, Local: TLandrixEInvoicePdfObject;
  Streams: TObjArray;
  Key, CacheKey, Part: string;
  I, K, J, First, KeyLen, Cached: Integer;
  IsRef: Boolean;
  Parts: TPartsEntry;
  Res, ApRes: TRes;
begin
  Inc(FPageCount);
  { the page's resources: own or inherited in the walk }
  PageRes := AInherited;
  Res.Local := PageRes;
  Res.Page := PageRes;
  { 6.2.2-2: veraPDF counts every resource it finds for the page's content
    as inherited when the page has no /Resources key; a key whose value veraPDF
    may read as empty (null, a reference to no object) is not modelled, nor
    the initial gray of such a page where its resources have a /DeviceGray
    entry
    DE: 6.2.2-2: veraPDF zaehlt jede fuer den Inhalt der Seite gefundene
    Ressource als geerbt, wenn die Seite keinen /Resources-Schluessel hat; ein
    Schluessel, dessen Wert veraPDF als leer lesen kann (null, ein Verweis
    auf kein Objekt), ist nicht nachgebildet, ebenso wenig das anfaengliche
    Grau einer solchen Seite, deren Ressourcen einen /DeviceGray-Eintrag
    haben }
  Raw := APage.RawGet('Resources');
  Res.InheritAll := Raw = nil;
  if (Raw <> nil) and ((Raw.Kind = pok_Null) or ((Raw.Kind = pok_Ref) and (ResolveRef(Raw) = nil))) then
    FInheritUnsure := True;
  if Res.InheritAll and (CsRaw(Self, PageRes, 'DeviceGray') <> nil) then
    FInheritUnsure := True;

  Streams := nil;
  Key := 'C';
  First := -1;
  Raw := APage.RawGet('Contents');
  C := ResolveRef(Raw);
  if (C <> nil) and (C.Kind = pok_Stream) and (Raw.Kind = pok_Ref) then
  begin
    { one stream: the same object as a form or appearance elsewhere }
    SetLength(Streams, 1);
    Streams[0] := C;
    Key := 'S' + IntToStr(Raw.RefNum);
    First := Raw.RefNum;
  end
  else if (C <> nil) and (C.Kind = pok_Arr) then
  begin
    { an array object is one identity (shared by pages or not); a direct
      array belongs to its page }
    { an array object: its number is the key (its parts are the same each
      time; a key of all parts would cost their number for every page) }
    IsRef := Raw.Kind = pok_Ref;
    if IsRef then
      Key := 'A' + IntToStr(Raw.RefNum)
    else
      Key := 'D' + IntToStr(FPageCount);
    if C.ArrCount > MaxParts then
    begin
      { not read: it may reach anything first }
      FIncomplete := True;
      FLimitHit := True;
      Exit;
    end;
    Cached := -1;
    CacheKey := IntToStr(C.Serial);
    if IsRef then
      Cached := FPartsCache.IndexOf(CacheKey);
    if Cached >= 0 then
    begin
      { an array object shared by many pages: its parts once (the list is
        only read) }
      Parts := TPartsEntry(FPartsCache.Objects[Cached]);
      Streams := Parts.Streams;
      First := Parts.First;
    end
    else
    begin
      SetLength(Streams, C.ArrCount);
      { the key in one buffer: ',' and at most 11 characters a part }
      KeyLen := Length(Key);
      SetLength(Key, KeyLen + 12 * C.ArrCount);
      K := 0;
      for I := 0 to C.ArrCount - 1 do
      begin
        Raw := C.ArrItem(I);
        S := ResolveRef(Raw);
        if (S = nil) or (S.Kind <> pok_Stream) or (Raw.Kind <> pok_Ref) then
          Continue;
        Streams[K] := S;
        Inc(K);
        if not IsRef then
        begin
          Part := ',' + IntToStr(Raw.RefNum);
          for J := 1 to Length(Part) do
            Key[KeyLen + J] := Part[J];
          Inc(KeyLen, Length(Part));
        end;
        if First < 0 then
          First := Raw.RefNum;
      end;
      SetLength(Key, KeyLen);
      SetLength(Streams, K);
      if IsRef then
      begin
        Parts := TPartsEntry.Create;
        Parts.First := First;
        Parts.Streams := Copy(Streams, 0, Length(Streams));
        FPartsCache.AddObject(CacheKey, Parts);
      end;
    end;
  end;
  PageNum := FCurPageNum;
  Tp := 0;
  if Length(Streams) > 0 then
  begin
    Idx := ParseStreams(Self, Key, First, Streams, Res, FreshState(Self, Res), True);
    if Idx >= 0 then
      Tp := ParseTransp(Idx)
    else
      Tp := 1;
  end;
  RootGroup(Self, 'XGP' + IntToStr(FPageCount), -1, APage, PageRes);
  try

  Annots := DGetRef(APage, 'Annots');
  if (Annots = nil) or (Annots.Kind <> pok_Arr) then
    Exit;
  for I := 0 to Annots.ArrCount - 1 do
  begin
    { veraPDF builds annotations from dictionaries only }
    A := ResolveRef(Annots.ArrItem(I));
    if (A = nil) or (A.Kind <> pok_Dict) then
      Continue;
    { veraPDF reaches colour spaces through a 3D stream, not modelled }
    V := DGetRef(A, 'Subtype');
    if (V <> nil) and (V.Kind = pok_Name) and (V.NameVal = '3D') then
      FColourUnsure := True;
    { an /AP that is a stream gives veraPDF no appearances }
    AP := DGetRef(A, 'AP');
    if (AP = nil) or (AP.Kind <> pok_Dict) then
      Continue;
    for K := 0 to High(ApKeys) do
    begin
      Raw := AP.RawGet(ApKeys[K]);
      V := ResolveRef(Raw);
      if V = nil then
        Continue;
      if V.Kind = pok_Stream then
      begin
        if Raw.Kind <> pok_Ref then
          Continue;
        CheckAppearanceForm(V, Raw);
        Local := DGetRef(V, 'Resources');
        if (Local <> nil) and (Local.Kind <> pok_Dict) then
          Local := nil;
        RootGroup(Self, 'XG' + IntToStr(Raw.RefNum), Raw.RefNum, V, Local);
        ApRes.Local := Local;
        ApRes.Page := PageRes;
        ApRes.InheritAll := False;
        Idx := ParseStreams(Self, 'S' + IntToStr(Raw.RefNum), Raw.RefNum, [V], ApRes, FreshState(Self, ApRes),
          True);
        Tp := MaxOf(Tp, MaxOf(FormGroupTransp(Self, V), ApTransp(Self, Idx)));
      end
      else if V.Kind = pok_Dict then
        for J := 0 to Integer(V.DVals.Count) - 1 do
        begin
          Raw2 := TLandrixEInvoicePdfObject(V.DVals[J]);
          S2 := ResolveRef(Raw2);
          if (S2 = nil) or (S2.Kind <> pok_Stream) or (Raw2.Kind <> pok_Ref) then
            Continue;
          CheckAppearanceForm(S2, Raw2);
          Local := DGetRef(S2, 'Resources');
          if (Local <> nil) and (Local.Kind <> pok_Dict) then
            Local := nil;
          RootGroup(Self, 'XG' + IntToStr(Raw2.RefNum), Raw2.RefNum, S2, Local);
          ApRes.Local := Local;
          ApRes.Page := PageRes;
          ApRes.InheritAll := False;
          Idx := ParseStreams(Self, 'S' + IntToStr(Raw2.RefNum), Raw2.RefNum, [S2], ApRes, FreshState(Self, ApRes),
            True);
          Tp := MaxOf(Tp, MaxOf(FormGroupTransp(Self, S2), ApTransp(Self, Idx)));
        end;
    end;
  end;
  finally
    { 6.2.10-2: the page's group colour space as veraPDF builds it
      without resources
      DE: 6.2.10-2: der Gruppen-Farbraum der Seite, wie veraPDF ihn
      ohne Ressourcen baut }
    NoCs := 2;
    V := DGetRef(APage, 'Group');
    if (V <> nil) and (V.Kind = pok_Dict) and (V.RawGet('CS') <> nil) then
      case CsValue(Self, nil, V.RawGet('CS'), False, 0).Kind of
        csk_Null:
          ;
        csk_Unknown:
          NoCs := 1;
      else
        NoCs := 0;
      end;
    if NoCs < Tp then
      Tp := NoCs;
    I := FPageTpKey.Count;
    FPageTpKey.Add(ObjId(APage));
    SetLength(FPageTpNum, I + 1);
    SetLength(FPageTpLevel, I + 1);
    FPageTpNum[I] := PageNum;
    FPageTpLevel[I] := Tp;
  end;
end;

{ 6.2.10-2: what an appearance brings (AIndex from ParseStreams): -1 is a
  cycle (impossible at the top) or a limit. }
function ApTransp(AWalk: TLandrixEInvoicePdfContentWalk; AIndex: Integer): Integer;
begin
  if AIndex >= 0 then
    Result := AWalk.ParseTransp(AIndex)
  else
    Result := 1;
end;

{ 6.2.10-2: the transparency of a parse as a caller meets it: a parse not
  read with certainty (veraPDF may drop all its operators) or one that cut a
  cycle (reused, it may miss a stream veraPDF reads) is not decided. }
function TLandrixEInvoicePdfContentWalk.ParseTransp(AIndex: Integer): Integer;
var
  P: TContentParse;
begin
  Result := 1;
  if (AIndex < 0) or (AIndex >= Integer(FParses.Count)) then
    Exit;
  P := TContentParse(FParses[AIndex]);
  if P.Uncertain then
    Exit;
  { a parse that reaches a stream being read now: veraPDF reads that one as
    empty there, which this parse (made elsewhere) did not }
  if ReachesActive(AIndex) then
    Exit;
  Result := P.Transp;
  if P.CycleCut and (Result = 0) then
    Result := 1;
end;

{ The parse AIndex, or one it reaches, is of a stream being read now
  (FActive); True also beyond the budget. }
function TLandrixEInvoicePdfContentWalk.ReachesActive(AIndex: Integer): Boolean;
const
  MaxNodes = 100000;
var
  Stack: TIntArray;
  N, Top, I, C: Integer;
  P, Q: TContentParse;
begin
  Result := False;
  if FActive.Count = 0 then
    Exit;
  P := TContentParse(FParses[AIndex]);
  if P.ReachGen = FActiveGen then
  begin
    Result := P.ReachVal;
    Exit;
  end;
  Inc(FVisitGen);
  Stack := nil;
  SetLength(Stack, 16);
  Stack[0] := AIndex;
  Top := 1;
  N := 0;
  while Top > 0 do
  begin
    Dec(Top);
    Q := TContentParse(FParses[Stack[Top]]);
    if Q.VisitGen = FVisitGen then
      Continue;
    Q.VisitGen := FVisitGen;
    { a known answer for the same active streams }
    if (Q <> P) and (Q.ReachGen = FActiveGen) then
    begin
      if Q.ReachVal then
      begin
        Result := True;
        Break;
      end;
      Continue;
    end;
    Inc(N);
    if (N > MaxNodes) or (FActive.IndexOf(Q.Key) >= 0) then
    begin
      Result := True;
      Break;
    end;
    for I := 0 to Integer(Length(Q.Children)) - 1 do
    begin
      C := Q.Children[I];
      if (C < 0) or (C >= Integer(FParses.Count)) then
        Continue;
      if Top >= Length(Stack) then
        SetLength(Stack, 2 * Length(Stack));
      Stack[Top] := C;
      Inc(Top);
    end;
  end;
  P.ReachGen := FActiveGen;
  P.ReachVal := Result;
end;

{ Byte order (equal keys adjacent, whatever the locale). }
function OrdinalCompare(List: TStringList; Index1, Index2: Integer): Integer;
begin
  Result := CompareStr(List[Index1], List[Index2]);
end;

function PageTpKeyOf(const S: string): string;
begin
  Result := Copy(S, 1, Pos(#1, S) - 1);
end;

function PageTpIndex(const S: string): Integer;
begin
  Result := StrToInt(Copy(S, Pos(#1, S) + 1, MaxInt));
end;

{ 6.2.10-2: veraPDF validates a page object once: one reached in several
  walks (other inherited resources) is decided where they agree. }
procedure TLandrixEInvoicePdfContentWalk.FinishPageTransparency;
var
  Sorted: TStringList;
  I, J, K, L: Integer;
begin
  Sorted := TStringList.Create;
  try
    { key, then the walk's index }
    for I := 0 to FPageTpKey.Count - 1 do
      Sorted.Add(FPageTpKey[I] + #1 + IntToStr(I));
    Sorted.CustomSort(OrdinalCompare);
    I := 0;
    while I < Sorted.Count do
    begin
      J := I;
      K := PageTpIndex(Sorted[I]);
      L := FPageTpLevel[K];
      while (J + 1 < Sorted.Count) and (PageTpKeyOf(Sorted[J + 1]) = PageTpKeyOf(Sorted[I])) do
      begin
        Inc(J);
        if FPageTpLevel[PageTpIndex(Sorted[J])] <> L then
          L := 1;
      end;
      { a parse failed with an exception somewhere: veraPDF may read other
        uses of its streams as empty }
      if (L = 2) and FAnyParseFailed then
        L := 1;
      if L = 2 then
        AddRootFinding(pcc_PageTransparency, FPageTpNum[K], 'page contains transparency without a group colour space')
      else if L = 1 then
        FUncertain[pcc_PageTransparency] := True;
      I := J + 1;
    end;
  finally
    Sorted.Free;
  end;
end;

{ A finding outside any parse, once per check and object (at most
  MaxFindingsPerCheck per check). }
procedure TLandrixEInvoicePdfContentWalk.AddRootFinding(ACheck: TLandrixEInvoicePdfContentCheck; ANum: Integer;
  const ADetail: string);
var
  I, N: Integer;
begin
  N := 0;
  for I := 0 to FRCount - 1 do
    if FRCheck[I] = ACheck then
    begin
      if FRNum[I] = ANum then
        Exit;
      Inc(N);
    end;
  if N >= MaxFindingsPerCheck then
    Exit;
  if FRCount >= Length(FRCheck) then
  begin
    SetLength(FRCheck, 16 + 2 * FRCount);
    SetLength(FRNum, 16 + 2 * FRCount);
    SetLength(FRDetail, 16 + 2 * FRCount);
  end;
  FRCheck[FRCount] := ACheck;
  FRNum[FRCount] := ANum;
  FRDetail[FRCount] := ADetail;
  Inc(FRCount);
end;

{ 6.2.9-1 to -3: veraPDF builds every appearance stream as a form XObject,
  whatever its /Subtype.
  DE: 6.2.9-1 bis -3: veraPDF baut jeden Erscheinungsbild-Stream als
  Form-XObject, gleich welchen /Subtype er hat. }
procedure TLandrixEInvoicePdfContentWalk.CheckAppearanceForm(V, ARaw: TLandrixEInvoicePdfObject);
var
  APs, ARef, ASub: string;
  Num: Integer;
begin
  FormFaults(Self, V, APs, ARef, ASub);
  Num := LastRefNum(ARaw);
  if APs <> '' then
    AddRootFinding(pcc_FormPS, Num, 'appearance form XObject has' + APs);
  if ARef <> '' then
    AddRootFinding(pcc_FormRef, Num, 'appearance form XObject has' + ARef);
  if ASub <> '' then
    AddRootFinding(pcc_PSXObject, Num, 'appearance form XObject has' + ASub);
end;

{ The colorant classes each object may be visited in as a halftone: the
  value of any /HT (top level) and of any key of a dictionary whose
  HalftoneType reads as 5 (more than veraPDF visits, never less).
  DE: Die Farbmittelklassen, in denen jedes Objekt als Halftone besucht
  werden kann: der Wert jedes /HT (oberste Ebene) und jedes Schluessels
  eines Dictionarys, dessen HalftoneType als 5 gelesen wird (mehr, als
  veraPDF besucht, nie weniger). }
procedure TLandrixEInvoicePdfContentWalk.BuildHalftoneContexts;
const
  MaxScanNodes = 2000000;
  MaxScanDepth = 200;
var
  N, Count, Nodes: Integer;
  O: TLandrixEInvoicePdfObject;
  X: TLandrixEInvoicePdfXrefEntry;

  procedure Note(ARaw: TLandrixEInvoicePdfObject; AClass: Integer);
  var
    M: Integer;
  begin
    if (ARaw = nil) or (ARaw.Kind <> pok_Ref) then
      Exit;
    M := LastRefNum(ARaw);
    if (M >= 0) and (M < Count) then
      FHtCtx[M] := Byte(FHtCtx[M] or AClass);
  end;

  procedure Visit(V: TLandrixEInvoicePdfObject; ADepth: Integer);
  var
    I: Integer;
    T: Int64;
    K: TLandrixEInvoicePdfObject;
    Five: Boolean;
  begin
    if (V = nil) or FHtBroken then
      Exit;
    Inc(Nodes);
    if (Nodes > MaxScanNodes) or (ADepth > MaxScanDepth) then
    begin
      FHtBroken := True;
      Exit;
    end;
    case V.Kind of
      pok_Arr:
        for I := 0 to V.ArrCount - 1 do
          if (V.ArrItem(I) <> nil) and (V.ArrItem(I).Kind <> pok_Ref) then
            Visit(V.ArrItem(I), ADepth + 1);
      pok_Dict, pok_Stream:
        begin
          Note(V.RawGet('HT'), HtPrimary);
          Five := IntegerOf(DGetRef(V, 'HalftoneType'), T) and (T = 5);
          for I := 0 to Integer(V.DVals.Count) - 1 do
          begin
            K := TLandrixEInvoicePdfObject(V.DVals[I]);
            if K = nil then
              Continue;
            if K.Kind = pok_Ref then
            begin
              if Five then
                Note(K, HalftoneClass(V.DKeys[I]));
            end
            else
              Visit(K, ADepth + 1);
          end;
        end;
    else
      { numbers, strings, names: nothing }
    end;
  end;

begin
  FHtBuilt := True;
  Count := FDoc.XrefCount;
  SetLength(FHtCtx, Count);
  for N := 0 to Count - 1 do
    FHtCtx[N] := 0;
  Nodes := 0;
  for N := 0 to Count - 1 do
  begin
    if FHtBroken then
      Break;
    X := FDoc.XrefEntry(N);
    if not X.Known or (X.Kind = pxk_Free) then
      Continue;
    O := FDoc.GetObject(N);
    if O <> nil then
      Visit(O, 0);
  end;
end;

{ Object ANum, visited as a halftone with a transfer function or not
  (ATransferNull), may pass 6.2.5-6 in another class veraPDF may meet it
  in first.
  DE: Objekt ANum, als Halftone mit oder ohne Transferfunktion
  (ATransferNull) besucht, kann 6.2.5-6 in einer anderen Klasse bestehen,
  in der veraPDF es zuerst treffen kann. }
function TLandrixEInvoicePdfContentWalk.HalftonePassesElsewhere(ANum: Integer; ATransferNull: Boolean): Boolean;
var
  M: Integer;
begin
  if not FHtBuilt then
    BuildHalftoneContexts;
  Result := True;
  if FHtBroken or (ANum < 0) or (ANum >= Integer(Length(FHtCtx))) then
    Exit;
  M := FHtCtx[ANum];
  Result := ((M and HtDefault) <> 0) or (((M and HtPrimary) <> 0) and ATransferNull) or
    (((M and HtOther) <> 0) and not ATransferNull);
end;

{ veraPDF validates a content stream once, in whichever context it meets it
  first. A check fails for certain where every parse of a stream (all
  contexts) fails it and the stream is certainly reached; a stream is
  certainly reached from a page, or as a child that every parse of a
  certainly reached stream reaches. Anything else is uncertain. }
{ 6.2.11.4.1-1: veraPDF checks a font once, with the rendering mode of the
  use it meets first; a font also shown in mode 3 (or in a mode not
  decided) gives no certain finding. Fonts that share a TrueType program
  with different encoding outcomes leave the content rules undecided. A parse keeps level 2 only with a
  certain finding left.
  DE: 6.2.11.4.1-1: veraPDF prueft eine Schrift einmal, mit dem
  Darstellungsmodus der Verwendung, die es zuerst trifft; eine Schrift, die
  auch im Modus 3 (oder in einem nicht entschiedenen Modus) gezeigt wird,
  ergibt keinen sicheren Befund. Schriften, die ein TrueType-Programm mit
  verschiedenen Ergebnissen der Kodierung teilen, lassen die Content-Regeln
  offen. Eine Parse behaelt Stufe 2 nur mit einem
  verbleibenden sicheren Befund. }
procedure TLandrixEInvoicePdfContentWalk.AddFontMark(AIndex: Integer; AFacts: TObject);
begin
  SetLength(FEmbIdx, FEmbCount + 1);
  SetLength(FEmbFont, FEmbCount + 1);
  FEmbIdx[FEmbCount] := AIndex;
  FEmbFont[FEmbCount] := AFacts;
  Inc(FEmbCount);
end;

procedure TLandrixEInvoicePdfContentWalk.FinishFonts;
var
  K, I, J: Integer;
  P: TContentParse;
  Sure: array of Boolean;
  A, B: TFontFacts;
  Chk: TLandrixEInvoicePdfContentCheck;
begin
  { fonts that share a TrueType program with different encoding outcomes:
    which font veraPDF meets first decides for all of them }
  for I := 0 to FFontCache.Count - 1 do
  begin
    A := TFontFacts(FFontCache.Objects[I]);
    if A.EncKey <> '' then
      for J := 0 to I - 1 do
      begin
        B := TFontFacts(FFontCache.Objects[J]);
        if (B.EncKey = A.EncKey) and (B.EncOut <> A.EncOut) then
        begin
          FIncomplete := True;
          A.Mixed := True;
          B.Mixed := True;
        end;
      end;
  end;
  for K := 0 to FEmbCount - 1 do
    if TFontFacts(FEmbFont[K]).Mixed or ((FFCheck[FEmbIdx[K]] = pcc_FontEmbedded) and
      (TFontFacts(FEmbFont[K]).Modes and 5 <> 0)) or ((FFCheck[FEmbIdx[K]] in [pcc_GlyphPresent, pcc_GlyphWidth]) and
      TFontFacts(FEmbFont[K]).MultiCtx) then
      FFMaybe[FEmbIdx[K]] := True;
  { a parse keeps level 2 for a font check only with a certain finding left }
  Sure := nil;
  SetLength(Sure, FParses.Count);
  for Chk := pcc_FontType to pcc_GlyphNotdef do
  begin
    for I := 0 to Integer(FParses.Count) - 1 do
      Sure[I] := False;
    for J := 0 to FFCount - 1 do
      if (FFCheck[J] = Chk) and not FFMaybe[J] then
        Sure[FFParse[J]] := True;
    for I := 0 to Integer(FParses.Count) - 1 do
    begin
      P := TContentParse(FParses[I]);
      if (P.Level[Chk] = 2) and not Sure[I] then
        P.Level[Chk] := 1;
    end;
  end;
end;

procedure TLandrixEInvoicePdfContentWalk.Finish;
var
  Sorted: TStringList;
  GroupStart: array of Integer;
  Members: array of Integer;
  Reach: array of Boolean;
  Head, Link: array of Integer;
  G, NG, I, J, K, M, C, CG, P0: Integer;
  P, Q: TContentParse;
  Changed, InAll, Found, AnyUnc, AllDef, AnyLvl, Emitted: Boolean;
  Chk: TLandrixEInvoicePdfContentCheck;
  Num, MaxNum: Integer;
begin
  SeparationThrows;
  Members := nil;
  GroupStart := nil;
  Reach := nil;
  Head := nil;
  Link := nil;
  SetLength(Head, Integer(FParses.Count));
  for I := 0 to Integer(FParses.Count) - 1 do
    Head[I] := -1;
  SetLength(Link, FFCount);
  for J := FFCount - 1 downto 0 do
  begin
    Link[J] := Head[FFParse[J]];
    Head[FFParse[J]] := J;
  end;
  FinishFonts;
  Sorted := TStringList.Create;
  try
    for I := 0 to Integer(FParses.Count) - 1 do
      Sorted.AddObject(TContentParse(FParses[I]).Key, FParses[I]);
    Sorted.CustomSort(OrdinalCompare);
    SetLength(Members, Sorted.Count);
    SetLength(GroupStart, Sorted.Count + 1);
    NG := 0;
    for I := 0 to Sorted.Count - 1 do
    begin
      Members[I] := TContentParse(Sorted.Objects[I]).Index;
      if (I = 0) or (Sorted[I] <> Sorted[I - 1]) then
      begin
        GroupStart[NG] := I;
        Inc(NG);
      end;
      TContentParse(FParses[Members[I]]).Group := NG - 1;
    end;
    GroupStart[NG] := Sorted.Count;
  finally
    Sorted.Free;
  end;

  SetLength(Reach, NG);
  for G := 0 to NG - 1 do
  begin
    Reach[G] := False;
    for M := GroupStart[G] to GroupStart[G + 1] - 1 do
      if TContentParse(FParses[Members[M]]).Root then
        Reach[G] := True;
  end;
  Changed := True;
  while Changed do
  begin
    Changed := False;
    for G := 0 to NG - 1 do
    begin
      if not Reach[G] then
        Continue;
      P := TContentParse(FParses[Members[GroupStart[G]]]);
      for C := 0 to Integer(Length(P.Children)) - 1 do
      begin
        CG := TContentParse(FParses[P.Children[C]]).Group;
        if Reach[CG] then
          Continue;
        InAll := True;
        for M := GroupStart[G] + 1 to GroupStart[G + 1] - 1 do
        begin
          Q := TContentParse(FParses[Members[M]]);
          Found := False;
          for K := 0 to Integer(Length(Q.Children)) - 1 do
            if TContentParse(FParses[Q.Children[K]]).Group = CG then
              Found := True;
          if not Found then
            InAll := False;
        end;
        if InAll then
        begin
          Reach[CG] := True;
          Changed := True;
        end;
      end;
    end;
  end;

  { a stream not read with certainty may reach any form, pattern or glyph
    in another context first, and may associate anything }
  { the associations without duplicates, sorted (HasAssoc) }
  for I := 0 to Integer(FParses.Count) - 1 do
    TContentParse(FParses[I]).CompactAssoc;
  FAnyUncertain := False;
  for I := 0 to Integer(FParses.Count) - 1 do
    if TContentParse(FParses[I]).Uncertain then
      FAnyUncertain := True;
  FAssocAll := FIncomplete or FAnyUncertain;
  { a stream not read with certainty, or not parsed at a limit, may reach
    any stream (also page contents and appearances) in another context
    first }
  if FPagesUnsure or FAnyUncertain or FLimitHit or FThrows then
    for G := 0 to NG - 1 do
      Reach[G] := False;
  for Chk := Low(TLandrixEInvoicePdfContentCheck) to High(TLandrixEInvoicePdfContentCheck) do
    FUncertain[Chk] := FIncomplete or (FColourUnsure and (Chk in ColourChecks) and (Chk <> pcc_Overprint)) or
      (FInheritUnsure and (Chk = pcc_Inherited));
  FinishPageTransparency;
  MaxNum := FDoc.XrefCount;
  SetLength(FAssocSure, MaxNum);
  SetLength(FAssocMaybe, MaxNum);
  for I := 0 to MaxNum - 1 do
  begin
    FAssocSure[I] := False;
    FAssocMaybe[I] := False;
  end;
  FFindingCount := 0;

  for G := 0 to NG - 1 do
  begin
    P0 := Members[GroupStart[G]];
    AnyUnc := False;
    for M := GroupStart[G] to GroupStart[G + 1] - 1 do
      if TContentParse(FParses[Members[M]]).Uncertain then
        AnyUnc := True;
    if AnyUnc then
    begin
      for Chk := Low(TLandrixEInvoicePdfContentCheck) to High(TLandrixEInvoicePdfContentCheck) do
        FUncertain[Chk] := True;
    end
    else
      for Chk := Low(TLandrixEInvoicePdfContentCheck) to High(TLandrixEInvoicePdfContentCheck) do
      begin
        AllDef := True;
        AnyLvl := False;
        for M := GroupStart[G] to GroupStart[G + 1] - 1 do
        begin
          P := TContentParse(FParses[Members[M]]);
          if P.Level[Chk] < 2 then
            AllDef := False;
          if P.Level[Chk] > 0 then
            AnyLvl := True;
        end;
        { the overprint pair of a failing paint is in the identity: no
          route that is not modelled gives it }
        if AllDef and Reach[G] and not ((FColourUnsure or (FSharedUnsure and TContentParse(FParses[P0]).Virtual)) and
          (Chk in ColourChecks) and (Chk <> pcc_Overprint)) and
          not (FOpmUnsure and (Chk = pcc_IccInput) and TContentParse(FParses[P0]).Virtual) then
        begin
          Emitted := False;
          J := Head[P0];
          while J >= 0 do
          begin
            if (FFCheck[J] = Chk) and not FFMaybe[J] then
            begin
              if FFindingCount >= Length(FFindings) then
                SetLength(FFindings, 16 + 2 * FFindingCount);
              Num := TContentParse(FParses[P0]).Num;
              FFindings[FFindingCount].Check := Chk;
              FFindings[FFindingCount].ObjNum := Num;
              if Num >= 0 then
                FFindings[FFindingCount].ObjGen := FDoc.XrefEntry(Num).Gen
              else
                FFindings[FFindingCount].ObjGen := -1;
              if not TContentParse(FParses[P0]).Virtual then
                FFindings[FFindingCount].Detail := 'content of object ' + IntToStr(Num) + ': ' + FFDetail[J]
              else if Num >= 0 then
                FFindings[FFindingCount].Detail := 'object ' + IntToStr(Num) + ': ' + FFDetail[J]
              else
                FFindings[FFindingCount].Detail := FFDetail[J];
              Inc(FFindingCount);
              Emitted := True;
            end;
            J := Link[J];
          end;
          if not Emitted then
            FUncertain[Chk] := True;
        end
        else if AnyLvl then
          FUncertain[Chk] := True;
      end;

    { associations: sure where every parse of a certainly reached stream
      makes them }
    for M := GroupStart[G] to GroupStart[G + 1] - 1 do
    begin
      P := TContentParse(FParses[Members[M]]);
      for K := 0 to P.AssocCount - 1 do
      begin
        Num := P.Assoc[K];
        if (Num < 0) or (Num >= MaxNum) then
          Continue;
        FAssocMaybe[Num] := True;
        if not Reach[G] or AnyUnc then
          Continue;
        InAll := True;
        for J := GroupStart[G] to GroupStart[G + 1] - 1 do
        begin
          Q := TContentParse(FParses[Members[J]]);
          if not Q.HasAssoc(Num) then
            InAll := False;
        end;
        if InAll then
          FAssocSure[Num] := True;
      end;
    end;
  end;

  FinishSeparations(GroupStart, Members, Reach, NG);

  { the findings outside any parse: certain where the pages are. DE: die
    Befunde ausserhalb jeder Analyse: sicher, wo die Seiten es sind. }
  for I := 0 to FRCount - 1 do
    { an uncertain stream may throw in veraPDF, which then reports nothing }
    if FPagesUnsure or FThrows or FAnyUncertain then
      FUncertain[FRCheck[I]] := True
    else
    begin
      if FFindingCount >= Length(FFindings) then
        SetLength(FFindings, 16 + 2 * FFindingCount);
      Num := FRNum[I];
      FFindings[FFindingCount].Check := FRCheck[I];
      FFindings[FFindingCount].ObjNum := Num;
      if Num >= 0 then
        FFindings[FFindingCount].ObjGen := FDoc.XrefEntry(Num).Gen
      else
        FFindings[FFindingCount].ObjGen := -1;
      FFindings[FFindingCount].Detail := 'object ' + IntToStr(Num) + ': ' + FRDetail[I];
      Inc(FFindingCount);
    end;
end;

{ V (a stored COS value) holds a reference to no object at any depth. }
function HasDangling(AWalk: TLandrixEInvoicePdfContentWalk; V: TLandrixEInvoicePdfObject; ADepth: Integer;
  var ABudget: Integer; var ALimit: Boolean): Boolean;
var
  I: Integer;
  Unsure: Boolean;
  T: TLandrixEInvoicePdfObject;
begin
  Result := False;
  Dec(ABudget);
  if V = nil then
    Exit;
  if (ADepth > MaxCsDepth) or (ABudget < 0) then
  begin
    { not searched to the end: no throw found, but not decided }
    ALimit := True;
    Exit;
  end;
  if V.Kind = pok_Ref then
  begin
    Unsure := False;
    T := LandrixEInvoicePdfResolveRef(AWalk.FDoc, V, Unsure);
    if Unsure then
    begin
      ALimit := True;
      Exit;
    end;
    if T = nil then
    begin
      Result := True;
      Exit;
    end;
    Result := HasDangling(AWalk, T, ADepth + 1, ABudget, ALimit);
    Exit;
  end;
  case V.Kind of
    pok_Arr:
      for I := 0 to V.ArrCount - 1 do
        if HasDangling(AWalk, V.ArrItem(I), ADepth + 1, ABudget, ALimit) then
        begin
          Result := True;
          Exit;
        end;
    pok_Dict, pok_Stream:
      for I := 0 to Integer(V.DVals.Count) - 1 do
        if HasDangling(AWalk, TLandrixEInvoicePdfObject(V.DVals[I]), ADepth + 1, ABudget, ALimit) then
        begin
          Result := True;
          Exit;
        end;
  else
    { numbers, strings, names }
  end;
end;

{ The bytes of AText as hex digits: a sort key that keeps every byte. }
function HexKey(const AText: AnsiString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AText) do
    Result := Result + IntToHex(Ord(AText[I]), 2);
end;

{ veraPDF stops with an exception (and reports nothing) when it compares a
  Separation whose alternate space it cannot build with another of the same
  name; two uses of one such object by two names already make two. Any
  Separation without a buildable alternate is taken as that risk.
  DE: veraPDF bricht mit einer Ausnahme ab (und meldet nichts), wenn es eine
  Separation, deren Alternativraum es nicht bauen kann, mit einer anderen
  gleichen Namens vergleicht; zwei Verwendungen eines solchen Objekts unter
  zwei Namen ergeben schon zwei. Jede Separation ohne baubaren
  Alternativraum gilt als dieses Risiko. }
procedure TLandrixEInvoicePdfContentWalk.SeparationThrows;
var
  I: Integer;
begin
  for I := 0 to Integer(FSeps.Count) - 1 do
    if TSepSig(FSeps[I]).Alt.Kind = csk_Null then
    begin
      FThrows := True;
      FMayThrow := True;
      FIncomplete := True;
      Exit;
    end;
end;

{ 6.2.4.4-2: two Separation spaces of one colourant name have the same
  alternate space and tint transform. A conflict is certain only between
  two Separations that are certainly linked (every parse of a certainly
  reached stream links them); a pair veraPDF might not both meet, or whose
  comparison is not decided, leaves the rule open.
  DE: 6.2.4.4-2: zwei Separation-Raeume eines Farbmittelnamens haben
  denselben Alternativraum und dieselbe Tint-Funktion. Ein Widerspruch ist
  nur zwischen zwei sicher verknuepften Separations sicher (jede Analyse
  eines sicher erreichten Streams verknuepft sie); ein Paar, das veraPDF
  vielleicht nicht beide trifft oder dessen Vergleich nicht entschieden
  ist, laesst die Regel offen. }
procedure TLandrixEInvoicePdfContentWalk.FinishSeparations(var AGroupStart, AMembers: array of Integer;
  var AReach: array of Boolean; ANG: Integer);
var
  Certain, Any: array of Boolean;
  Cnt, Touched: array of Integer;
  G, M, K, I, J, Idx, Count, NT, NM, Cmp, Num, First, Last: Integer;
  P: TContentParse;
  AnyUnc, Emitted, Blocked: Boolean;
  A, B: TSepSig;
  ByName: TStringList;
  Budget: Integer;
  Limit: Boolean;
begin
  Count := Integer(FSeps.Count);
  { colour spaces reached on routes not modelled may be more Separations }
  if FColourUnsure or FSharedUnsure or FSepUnsure then
    FUncertain[pcc_SeparationConsistency] := True;
  if Count = 0 then
    Exit;
  Certain := nil;
  Any := nil;
  Cnt := nil;
  Touched := nil;
  SetLength(Certain, Count);
  SetLength(Any, Count);
  SetLength(Cnt, Count);
  SetLength(Touched, Count);
  for I := 0 to Count - 1 do
  begin
    Certain[I] := False;
    Any[I] := False;
    Cnt[I] := 0;
  end;
  for G := 0 to ANG - 1 do
  begin
    AnyUnc := False;
    NM := AGroupStart[G + 1] - AGroupStart[G];
    for M := AGroupStart[G] to AGroupStart[G + 1] - 1 do
      if TContentParse(FParses[AMembers[M]]).Uncertain then
        AnyUnc := True;
    NT := 0;
    for M := AGroupStart[G] to AGroupStart[G + 1] - 1 do
    begin
      P := TContentParse(FParses[AMembers[M]]);
      for K := 0 to Integer(Length(P.SepIdx)) - 1 do
      begin
        Idx := P.SepIdx[K];
        Any[Idx] := True;
        if P.SepMaybe[K] then
          Continue;
        if Cnt[Idx] = 0 then
        begin
          Touched[NT] := Idx;
          Inc(NT);
        end;
        Inc(Cnt[Idx]);
      end;
    end;
    for K := 0 to NT - 1 do
    begin
      Idx := Touched[K];
      if (Cnt[Idx] = NM) and AReach[G] and not AnyUnc then
        Certain[Idx] := True;
      Cnt[Idx] := 0;
    end;
  end;
  Blocked := FColourUnsure or FSharedUnsure or FSepUnsure or FPagesUnsure or FThrows;
  ByName := TStringList.Create;
  try
    for I := 0 to Count - 1 do
    begin
      A := TSepSig(FSeps[I]);
      if not Any[I] then
        Continue;
      if not A.NameOk or A.Unsure then
        FUncertain[pcc_SeparationConsistency] := True;
      if A.NameOk then
        ByName.AddObject(HexKey(A.Name), A);
    end;
    ByName.CaseSensitive := True;
    ByName.Sort;
    First := 0;
    while First < ByName.Count do
    begin
      Last := First;
      while (Last + 1 < ByName.Count) and (TSepSig(ByName.Objects[Last + 1]).Name =
        TSepSig(ByName.Objects[First]).Name) do
        Inc(Last);
      { a reference to no object in a tint or an alternate of a name veraPDF
        compares: its comparison may throw, in an order not followed here }
      if Last > First then
        for I := First to Last do
        begin
          A := TSepSig(ByName.Objects[I]);
          Budget := 100000;
          Limit := False;
          if HasDangling(Self, A.Tint, 0, Budget, Limit) or ((A.Alt.Kind = csk_Value) and HasDangling(Self, A.Alt.V,
            0, Budget, Limit)) then
          begin
            FThrows := True;
            FMayThrow := True;
            FIncomplete := True;
          end;
          if Limit then
            FSepUnsure := True;
        end;
      if Last - First + 1 > MaxSepsPerName then
        FUncertain[pcc_SeparationConsistency] := True
      else
      begin
        Emitted := False;
        for I := First to Last - 1 do
        begin
          if Emitted then
            Break;
          A := TSepSig(ByName.Objects[I]);
          for J := I + 1 to Last do
          begin
            B := TSepSig(ByName.Objects[J]);
            Cmp := AltCompare(Self, A.Alt, B.Alt);
            if Cmp <> ceq_Different then
            begin
              K := CosCompare(Self, A.Tint, B.Tint, False, 0);
              if (Cmp = ceq_Equal) or (K = ceq_Different) then
                Cmp := K;
            end;
            if Cmp = ceq_Equal then
              Continue;
            if (Cmp = ceq_Different) and Certain[A.Index] and Certain[B.Index] and not A.Unsure and not B.Unsure and
              not Blocked and not FThrows and not FSepUnsure then
            begin
              Emitted := True;
              if FFindingCount >= Length(FFindings) then
                SetLength(FFindings, 16 + 2 * FFindingCount);
              Num := B.Num;
              FFindings[FFindingCount].Check := pcc_SeparationConsistency;
              FFindings[FFindingCount].ObjNum := Num;
              if Num >= 0 then
                FFindings[FFindingCount].ObjGen := FDoc.XrefEntry(Num).Gen
              else
                FFindings[FFindingCount].ObjGen := -1;
              FFindings[FFindingCount].Detail := 'Separation /' + TextOf(A.Name) +
                ': alternate space or tint transform differs from another Separation of that name';
              Inc(FFindingCount);
              Break;
            end
            else
              FUncertain[pcc_SeparationConsistency] := True;
          end;
        end;
      end;
      First := Last + 1;
    end;
  finally
    ByName.Free;
  end;
  { a comparison stopped at its budget or met a reference to no object }
  if FSepUnsure or FThrows then
    FUncertain[pcc_SeparationConsistency] := True;
end;

function TLandrixEInvoicePdfContentWalk.FindingCount: Integer;
begin
  Result := FFindingCount;
end;

function TLandrixEInvoicePdfContentWalk.Finding(AIndex: Integer): TLandrixEInvoicePdfContentFinding;
begin
  Result := FFindings[AIndex];
end;

function TLandrixEInvoicePdfContentWalk.Uncertain(ACheck: TLandrixEInvoicePdfContentCheck): Boolean;
begin
  Result := FUncertain[ACheck];
end;

function TLandrixEInvoicePdfContentWalk.AssociatedSure(ANum: Integer): Boolean;
begin
  Result := (ANum >= 0) and (ANum < Integer(Length(FAssocSure))) and FAssocSure[ANum];
end;

function TLandrixEInvoicePdfContentWalk.Throws: Boolean;
begin
  Result := FMayThrow;
end;

function TLandrixEInvoicePdfContentWalk.AssociatedMaybe(ANum: Integer): Boolean;
begin
  Result := FAssocAll or ((ANum >= 0) and (ANum < Integer(Length(FAssocMaybe))) and FAssocMaybe[ANum]);
end;

function LandrixEInvoicePdfResolveRef(ADoc: TLandrixEInvoicePdfDocument; ARaw: TLandrixEInvoicePdfObject;
  var AUnsure: Boolean): TLandrixEInvoicePdfObject;
var
  E: TLandrixEInvoicePdfXrefEntry;
  Depth, Num, Gen: Integer;
begin
  Result := ARaw;
  Depth := 0;
  while (Result <> nil) and (Result.Kind = pok_Ref) do
  begin
    Inc(Depth);
    E := ADoc.XrefEntry(Result.RefNum);
    if Depth > 32 then
    begin
      AUnsure := True;
      Result := nil;
      Exit;
    end;
    if not E.Known or (E.Kind = pxk_Free) or (E.Gen <> Result.RefGen) then
    begin
      Result := nil;
      Exit;
    end;
    Gen := Result.RefGen;
    Num := Result.RefNum;
    Result := ADoc.GetObject(Num);
    { the object header must carry the generation too }
    if (Result <> nil) and (Result.OwnerNum = Num) and ((Result.OwnerGen <> Gen) or Result.HeaderGenBad) then
    begin
      Result := nil;
      Exit;
    end;
  end;
end;

{ A stream dictionary value that the decoder of this library reads as
  veraPDF does: direct, or a reference veraPDF follows to the same object.
  DE: Ein Wert eines Stream-Dictionarys, den der Dekoder dieser Bibliothek
  wie veraPDF liest: direkt oder eine Referenz, der veraPDF zum selben
  Objekt folgt. }
function SameAsVeraPdf(ADoc: TLandrixEInvoicePdfDocument; ARaw: TLandrixEInvoicePdfObject): Boolean;
var
  Unsure: Boolean;
begin
  Result := True;
  if (ARaw = nil) or (ARaw.Kind <> pok_Ref) then
    Exit;
  Unsure := False;
  Result := (LandrixEInvoicePdfResolveRef(ADoc, ARaw, Unsure) <> nil) and not Unsure;
end;

{ Four header bytes from AStart as veraPDF takes them: empty when fewer were
  read or all are zero.
  DE: Vier Kopfbytes ab AStart, wie veraPDF sie nimmt: leer, wenn weniger
  gelesen wurden oder alle null sind. }
function IccField(const AData: TLandrixEInvoicePdfBytes; ACount, AStart: Integer): AnsiString;
var
  I: Integer;
  AllZero: Boolean;
begin
  Result := '';
  if ACount < AStart + 4 then
    Exit;
  AllZero := True;
  for I := AStart to AStart + 3 do
    if AData[I] <> 0 then
      AllZero := False;
  if AllZero then
    Exit;
  SetLength(Result, 4);
  for I := 0 to 3 do
    Result[I + 1] := AnsiChar(AData[AStart + I]);
end;

function LandrixEInvoicePdfIccHeader(ADoc: TLandrixEInvoicePdfDocument;
  AStream: TLandrixEInvoicePdfObject): TLandrixEInvoicePdfIccHeader;
var
  F, L: TLandrixEInvoicePdfObject;
  Raw, Data: TLandrixEInvoicePdfBytes;
  Flate: Boolean;
begin
  Result.Known := False;
  Result.Count := 0;
  Result.DeviceClass := '';
  Result.ColorSpace := '';
  Result.Major := -1;
  if (AStream = nil) or (AStream.Kind <> pok_Stream) then
    Exit;
  { an external file or an encrypted document: not read here }
  if (ADoc.DGet(AStream, 'F') <> nil) or ADoc.Encrypted or (ADoc.CryptError <> '') then
    Exit;
  { decided only where veraPDF and the decoder of this library certainly read
    the same bytes: no /DP or /DecodeParms entry, no filter or FlateDecode
    alone, a /Length that is a non-negative integer, directly or by a
    reference veraPDF follows to the same object }
  if (AStream.RawGet('DP') <> nil) or (AStream.RawGet('DecodeParms') <> nil) then
    Exit;
  if not SameAsVeraPdf(ADoc, AStream.RawGet('Filter')) or not SameAsVeraPdf(ADoc, AStream.RawGet('Length')) then
    Exit;
  L := ADoc.DGet(AStream, 'Length');
  if (L = nil) or (L.Kind <> pok_Num) or not L.NumExact or (L.NumInt < 0) then
    Exit;
  F := ADoc.DGet(AStream, 'Filter');
  if (F <> nil) and (F.Kind = pok_Arr) then
  begin
    if (F.ArrCount <> 1) or not SameAsVeraPdf(ADoc, F.ArrItem(0)) then
      Exit;
    F := ADoc.Resolve(F.ArrItem(0));
    if F = nil then
      Exit;
  end;
  if F = nil then
    Flate := False
  else if (F.Kind = pok_Name) and (F.NameVal = 'FlateDecode') then
    Flate := True
  else
    Exit;
  if not ADoc.GetStreamRaw(AStream, Raw) then
    Exit;
  { damaged zlib data: whether veraPDF reads the header before it notices
    depends on where the damage is }
  if Flate then
  begin
    if not LandrixEInvoicePdfInflateStrict(Raw, Data) then
      Exit;
  end
  else
  begin
    { a short unfiltered profile: a /Length that cuts off white space before
      endstream may be read differently }
    if Length(Raw) < 20 then
      Exit;
    Data := Raw;
  end;
  Result.Known := True;
  Result.Count := Integer(Length(Data));
  if Result.Count > 128 then
    Result.Count := 128;
  Result.DeviceClass := IccField(Data, Result.Count, 12);
  Result.ColorSpace := IccField(Data, Result.Count, 16);
  if Result.Count >= 10 then
    Result.Major := Data[8];
end;

end.
