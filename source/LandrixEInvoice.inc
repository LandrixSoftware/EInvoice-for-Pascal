{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Central compiler switches. Included at the top of every unit, directly
  after the unit header.

  Defines set here:
    LANDRIXEINVOICE_UNICODE  Delphi 2009 or later: the native string is
                             UTF-16 (string = UnicodeString, Char = WideChar).
                             Not defined on Delphi 6-2007 and not on FPC. It
                             describes the native string, not whether invoice
                             text is Unicode-safe: TLandrixEInvoiceString is
                             UTF-16 and lossless on every compiler.
    LANDRIXEINVOICE_WIN32W   Delphi 6-2007: Unicode file names need the W
                             functions of kernel32 (LandrixEInvoiceFiles).

  DE: Zentrale Compiler-Schalter. Werden in jeder Unit direkt nach dem
  Unit-Kopf eingebunden. LANDRIXEINVOICE_UNICODE ist ab Delphi 2009 gesetzt:
  Der native string ist UTF-16 (string = UnicodeString, Char = WideChar).
  Unter Delphi 6 bis 2007 und unter FPC ist er nicht gesetzt. Er beschreibt
  den nativen string, nicht ob Rechnungstext Unicode-sicher ist:
  TLandrixEInvoiceString ist unter jedem Compiler UTF-16 und verlustfrei.
  LANDRIXEINVOICE_WIN32W ist unter Delphi 6 bis 2007 gesetzt: Unicode-
  Dateinamen brauchen dort die W-Funktionen von kernel32
  (LandrixEInvoiceFiles). }

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
  { Note 6058 "call to subroutine marked as inline is not inlined" is about
    RTL routines (Move, CompareMem) on some targets, not about our code. }
  {$WARN 6058 OFF}
{$ENDIF}

{$B-} { short-circuit boolean evaluation }
{$H+} { long strings }
{$J-} { typed constants are read-only }
{$T-} { untyped @ operator, as in default Delphi projects }
{$X+} { extended syntax }

{$IFNDEF FPC}
  {$IF CompilerVersion >= 20.0}
    { Delphi 2009+: string = UnicodeString, Char = WideChar }
    {$DEFINE LANDRIXEINVOICE_UNICODE}
  {$IFEND}
  {$IFNDEF LANDRIXEINVOICE_UNICODE}
    { Delphi 6-2007 }
    {$DEFINE LANDRIXEINVOICE_WIN32W}
  {$ENDIF}
{$ENDIF}
