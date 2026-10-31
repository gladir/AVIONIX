{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application OPENVSP - modeleur parametrique de
                geometrie d'avions : ailes multi-sections, fuselages a
                stations, pods, helices, conduits, vue 3D (fil de fer,
                lignes cachees, ombre), panneau de parametres a curseurs,
                hierarchie parent/enfant, annulation, sauvegarde .VSP,
                import de profils .PRO (comme SOUFFLE), exports STL/OBJ/CSV,
                geometrie calculee (surfaces mouillees, volumes), masse et
                centrage, trainee parasite et aerodynamique (ligne portante
                de Prandtl avec polaires).

  Ligne de commande :
    OPENVSP [fichier.VSP]

  Souris : gauche = tourner, droite = zoom, milieu = deplacer, clic = choisir
  Touches principales :
    Fleches : rotation de la vue      +/- ou PgUp/PgDn : zoom
    1..7    : vues Haut/Dessous/Face/Arriere/Gauche/Droite/Iso
    W/H/D   : fil de fer / lignes cachees / ombre     F : ajuster la vue
    Tab     : clavier vers les parametres             F1 : aide
    Del     : supprimer la geometrie  F2  : renommer  Ctrl+Z : annuler
}

Program OPENVSP;

{ Niveaux de fonctionnalites :
    FULL : tout ce qui est decrit ci-dessus.
    LITE : ailes, fuselages, pods et vides ; vues 3D ; parametres ; undo ;
           sauvegarde .VSP ; export STL ; planforme des ailes.
    Par defaut FULL est actif sous Free Pascal. Sous Turbo Pascal 7 le
    code d'un programme est limite a 64 Ko : la version allegee (LITE)
    est alors compilee. Pour forcer l'un ou l'autre :
      - LITE sous Free Pascal : compiler avec -dLITE
      - FULL sous Turbo Pascal : ajouter une directive DEFINE FULL juste
        apres ce commentaire (risque de depasser les 64 Ko de code) }
{$IFNDEF LITE}
 {$IFDEF FPC}
  {$DEFINE FULL}
 {$ENDIF}
{$ENDIF}

{$IFDEF FPC}
 {$MODE TP}
 {$Q-}
 {$R-}
{$ELSE}
 {$S-}
 {$M 28672,0,655360}
{$ENDIF}

Uses {$IFDEF FPC}
      DOS,Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      DOS,Crt,Graph
     {$ENDIF};

Const
 PROG_TITLE     = 'OpenVSP 1.00 - Avionix';

 { Disposition de l'ecran (640x480) }
 MENUBAR_H      = 20;
 TOOLBAR_Y      = 20;
 TOOLBAR_H      = 22;
 STATUS_H       = 20;
 PANEL_W        = 216;
 PANEL_Y        = 42;
 BROW_Y         = 58;
 BROW_ROWS      = 8;
 BROW_RH        = 12;
 BTN_Y          = 158;
 TAB_Y          = 178;
 PAR_Y          = 198;
 PAR_RH         = 14;
 PAR_ROWS       = 18;

 MAX_GEOM       = 16;
 MAX_SECT       = 4;
 MAX_STAT       = 9;
 MAX_AF         = 3;
 MAX_AFPT       = 128;
 MAX_PARAM      = 100;
 MAX_VERT       = 4000;
 MAX_QUAD       = 4000;
 MAX_RNV        = 64;
 MAX_REP        = 140;

 { Types de geometrie }
 GT_WING        = 0;
 GT_FUSE        = 1;
 GT_POD         = 2;
 GT_PROP        = 3;
 GT_DUCT        = 4;
 GT_BLANK       = 5;
 NUM_KIND       = 6;

 { Menus }
 NUM_MENUS      = 6;
 MENU_FILE      = 0;
 MENU_EDIT      = 1;
 MENU_GEOM      = 2;
 MENU_VIEW      = 3;
 MENU_ANALYSE   = 4;
 MENU_HELP      = 5;
 MAX_MENU_ITEMS = 20;

 { Modes de rendu }
 RM_WIRE        = 0;
 RM_HIDDEN      = 1;
 RM_SHADED      = 2;

 { Types de parametres }
 PK_REAL        = 0;
 PK_INT         = 1;
 PK_BOOL        = 2;
 PK_ENUM        = 3;

 PI2            = 6.28318530717959;
 DEG            = 0.0174532925199433;

Type
 PReal = ^Real;

 TGeom = Record
  Used     : Boolean;
  Visible  : Boolean;
  Kind     : Byte;
  Name     : String[20];
  Sym, Parent, Mass : Real;
  X, Y, Z, RX, RY, RZ : Real;
  { Aile }
  RootChord, SweepLoc, NSect, Incid : Real;
  Thick, Camber, CamPos, AFSrc : Real;
  SSpan, STip, SSweep, SDih, STwist, SThick, SCamb : Array[1..MAX_SECT] Of Real;
  { Fuselage / pod / conduit / helice }
  Len, Diam, NStat : Real;
  StPos, StW, StH, StZ, StE : Array[1..MAX_STAT] Of Real;
  NoseF, TailF, TailR : Real;
  NBlade, HubD, Pitch, ChordMax, ThkRoot, ThkTip, SpinL : Real;
 End;

 TGeomArr  = Array[0..MAX_GEOM-1] Of TGeom;
 PGeomArr  = ^TGeomArr;

 TAirfoil = Record
  Used   : Boolean;
  Name   : String[24];
  NU, NL : Integer;
  UX, UZ, LX, LZ : Array[0..MAX_AFPT-1] Of Real;
  Thick  : Real;
 End;
 TAFLib  = Array[1..MAX_AF] Of TAirfoil;
 PAFLib  = ^TAFLib;

 TParam = Record
  Key   : String[8];
  Lbl   : String[11];
  P     : PReal;
  Mn, Mx, St : Real;
  Kind  : Byte;
  Dec   : Byte;
  Tab   : Byte;
  Grp   : Byte;
 End;

 TVert = Record
  X, Y, Z : LongInt;
 End;
 TVertArr = Array[0..MAX_VERT-1] Of TVert;
 PVertArr = ^TVertArr;

 TQuad = Record
  A, B, C, D : Word;
  G, F       : Byte;
  NX, NY, NZ : ShortInt;
 End;
 TQuadArr = Array[0..MAX_QUAD-1] Of TQuad;
 PQuadArr = ^TQuadArr;

 TIntArr  = Array[0..MAX_VERT-1] Of Integer;
 PIntArr  = ^TIntArr;
 TLongArr = Array[0..MAX_VERT-1] Of LongInt;
 PLongArr = ^TLongArr;
 TWordArr = Array[0..MAX_QUAD-1] Of Word;
 PWordArr = ^TWordArr;

 TRing = Record
  C, X0, Y0, Z0, Tw, Th, Cm, A, B, D, E, F : Real;
 End;

 TMenuItem = Record
  Caption   : String[30];
  Shortcut  : String[10];
  Enabled   : Boolean;
  Checked   : Boolean;
  Separator : Boolean;
  Act       : Integer;
 End;

 TMenu = Record
  Title     : String[15];
  Items     : Array[0..MAX_MENU_ITEMS-1] Of TMenuItem;
  ItemCount : Byte;
  X, Width  : Integer;
 End;

 TMat = Array[0..2, 0..2] Of Real;

Var
 ScreenWidth, ScreenHeight : Integer;
 VX1, VY1, VX2, VY2 : Integer;      { zone de la vue 3D }

 Geoms     : PGeomArr;
 UndoBuf   : PGeomArr;
 UndoCount, UndoSel : Integer;
 UndoValid : Boolean;
 GeomCount : Integer;
 Sel       : Integer;
 BrowTop   : Integer;
 AFLib     : PAFLib;
 AFNext    : Integer;
 ModelName : String;
 Modified  : Boolean;
 SkinDens  : Real;

 { Parametres / panneau }
 Par       : Array[0..MAX_PARAM-1] Of TParam;
 ParN      : Integer;
 VisIdx    : Array[0..MAX_PARAM-1] Of Integer;
 VisN      : Integer;
 CurTab    : Integer;
 CurGrp    : Integer;
 ParSel    : Integer;
 ParFocus  : Boolean;

 { Transformations }
 GR        : Array[0..MAX_GEOM-1] Of TMat;
 GT        : Array[0..MAX_GEOM-1, 0..2] Of Real;

 { Maillage }
 MV        : PVertArr;
 MQ        : PQuadArr;
 PSX, PSY  : PIntArr;
 PSZ       : PLongArr;
 QDep      : PLongArr;
 QOrd      : PWordArr;
 NV, NQ    : Integer;
 MeshDirty : Boolean;
 MeshOver  : Boolean;
 EffRes    : Integer;
 Res       : Integer;
 BMinX, BMinY, BMinZ, BMaxX, BMaxY, BMaxZ : Real;
 Ring      : TRing;

 { Camera }
 CamAz, CamEl, CamZoom : Real;
 CamPX, CamPY : Real;
 PivX, PivY, PivZ : Real;
 VR, VU, VF : Array[0..2] Of Real;
 RenderMode : Integer;
 ShowAxes, ShowGrid, ShowSel : Boolean;
 ViewName   : String[12];
 LightX, LightY, LightZ : Real;

 { Menus et ecran }
 Menus      : Array[0..NUM_MENUS-1] Of TMenu;
 MenuActive : Boolean;
 ActiveMenu : Integer;
 ActiveMenuItem : Integer;
 MenuSave   : Pointer;
 MenuSaveSz : LongInt;
 MenuSaveX, MenuSaveY : Integer;
 MenuSaved  : Boolean;

 MouseX, MouseY, MouseButtons : Integer;
 OldMouseX, OldMouseY, OldMouseButtons : Integer;
 MouseAvailable : Boolean;
 DragMode   : Integer;
 DragX, DragY : Integer;
 DragStartX, DragStartY : Integer;
 DragRow    : Integer;
 DragMoved  : Boolean;

 Running    : Boolean;
 NeedAll, NeedView, NeedPanel : Boolean;
 StatusMsg  : String;

 { Rapport }
 Rep        : Array[0..MAX_REP-1] Of String[78];
 RepN       : Integer;

 { Analyse }
 FlAlt, FlMach, AlphaMin, AlphaMax, MiscDrag : Real;
 PolA, PolCL, PolCD : Array[0..30] Of Real;
 PolN       : Integer;
 PolCLa, PolAlpha0, PolE, PolSref, PolBref, PolAR, PolCD0 : Real;
 PolOK      : Boolean;

 { Resultats de l'integration }
 RA : Array[0..MAX_RNV-1] Of Real;
 RB : Array[0..MAX_RNV-1] Of Real;
 RC : Array[0..MAX_RNV-1] Of Real;
 RD : Array[0..MAX_RNV-1] Of Real;
 RE : Array[0..MAX_RNV-1] Of Real;
 RF : Array[0..MAX_RNV-1] Of Real;

{ --------------------------------------------------------------------- }
{ Utilitaires                                                            }
{ --------------------------------------------------------------------- }

Function IntToStr(N: LongInt): String;
Var S: String;
Begin
 Str(N, S);
 IntToStr := S;
End;

Function RealToStr(R: Real; Decim: Integer): String;
Var S: String;
Begin
 Str(R:0:Decim, S);
 RealToStr := S;
End;

Function UpStr(Const S: String): String;
Var I: Integer; R: String;
Begin
 R := S;
 For I := 1 To Length(R) Do R[I] := UpCase(R[I]);
 UpStr := R;
End;

Function TrimStr(Const S: String): String;
Var I, J: Integer;
Begin
 I := 1; J := Length(S);
 While (I <= J) And ((S[I] = ' ') Or (S[I] = #9)) Do Inc(I);
 While (J >= I) And ((S[J] = ' ') Or (S[J] = #9) Or (S[J] = #13)) Do Dec(J);
 If J < I Then TrimStr := '' Else TrimStr := Copy(S, I, J - I + 1);
End;

Function MinI(A, B: Integer): Integer;
Begin If A < B Then MinI := A Else MinI := B; End;

Function MaxI(A, B: Integer): Integer;
Begin If A > B Then MaxI := A Else MaxI := B; End;

Function MaxR(A, B: Real): Real;
Begin If A > B Then MaxR := A Else MaxR := B; End;

Function MinR(A, B: Real): Real;
Begin If A < B Then MinR := A Else MinR := B; End;

Function Clamp(V, Lo, Hi: Real): Real;
Begin
 If V < Lo Then V := Lo;
 If V > Hi Then V := Hi;
 Clamp := V;
End;

Function Tan(A: Real): Real;
Var C: Real;
Begin
 C := Cos(A);
 If Abs(C) < 1E-9 Then C := 1E-9;
 Tan := Sin(A) / C;
End;

Function ArcSin(X: Real): Real;
Begin
 If X >= 1 Then ArcSin := 1.5707963267949
 Else If X <= -1 Then ArcSin := -1.5707963267949
 Else ArcSin := ArcTan(X / Sqrt(1 - X * X));
End;

Function Pow(X, Y: Real): Real;
Begin
 If X <= 0 Then Pow := 0 Else Pow := Exp(Y * Ln(X));
End;

Function Sqr2(X: Real): Real;
Begin Sqr2 := X * X; End;

Function Sgn(X: Real): Real;
Begin
 If X < 0 Then Sgn := -1 Else If X > 0 Then Sgn := 1 Else Sgn := 0;
End;

{$IFDEF FULL}
Function Log10(X: Real): Real;
Begin
 If X <= 0 Then Log10 := 0 Else Log10 := Ln(X) / 2.30258509299405;
End;

{$ENDIF}
Function HeapFree: LongInt;
Begin
 {$IFDEF FPC}
  HeapFree := 100000000;
 {$ELSE}
  HeapFree := MaxAvail;
 {$ENDIF}
End;

{ metres -> millimetres (LongInt), borne a +/- 2000 km }
Function ToMM(R: Real): LongInt;
Begin
 If R > 2.0E6 Then R := 2.0E6;
 If R < -2.0E6 Then R := -2.0E6;
 If R <> R Then R := 0;
 ToMM := Round(R * 1000.0);
End;

Function ToInt(R: Real): Integer;
Begin
 If R <> R Then R := 0;
 If R > 30000 Then R := 30000;
 If R < -30000 Then R := -30000;
 ToInt := Round(R);
End;

Function F1(R: Real): String;
Begin F1 := RealToStr(R, 1); End;

Function F2(R: Real): String;
Begin F2 := RealToStr(R, 2); End;

Function F3(R: Real): String;
Begin F3 := RealToStr(R, 3); End;

Function F4(R: Real): String;
Begin F4 := RealToStr(R, 4); End;

Function PadR(Const S: String; N: Integer): String;
Var T: String;
Begin
 T := S;
 While Length(T) < N Do T := T + ' ';
 If Length(T) > N Then T := Copy(T, 1, N);
 PadR := T;
End;

Function PadL(Const S: String; N: Integer): String;
Var T: String;
Begin
 T := S;
 While Length(T) < N Do T := ' ' + T;
 PadL := T;
End;

Function ParseReal(Const S: String; Var V: Real): Boolean;
Var Code: Integer; T: String; I: Integer;
Begin
 T := TrimStr(S);
 For I := 1 To Length(T) Do If T[I] = ',' Then T[I] := '.';
 Val(T, V, Code);
 ParseReal := (Code = 0) And (T <> '');
End;

{ --------------------------------------------------------------------- }
{ Gestion de la souris                                                   }
{ --------------------------------------------------------------------- }

{$IFNDEF FPC}
Procedure InitMouseDriver;
Var Regs: Registers;
Begin
 Regs.AX := $0000;
 Intr($33, Regs);
 MouseAvailable := Regs.AX = $FFFF;
End;

Procedure ShowMouseCursor;
Var Regs: Registers;
Begin
 If Not MouseAvailable Then Exit;
 Regs.AX := $0001;
 Intr($33, Regs);
End;

Procedure HideMouseCursor;
Var Regs: Registers;
Begin
 If Not MouseAvailable Then Exit;
 Regs.AX := $0002;
 Intr($33, Regs);
End;

Procedure GetMouseLocal(Var X, Y, Buttons: Integer);
Var Regs: Registers;
Begin
 If Not MouseAvailable Then Begin
  X := 0; Y := 0; Buttons := 0;
  Exit;
 End;
 Regs.AX := $0003;
 Intr($33, Regs);
 X := Regs.CX;
 Y := Regs.DX;
 Buttons := Regs.BX;
End;
{$ELSE}
Procedure InitMouseDriver;
Begin
 PtcMouse.InitMouse;
 MouseAvailable := True;
End;

Procedure ShowMouseCursor;
Begin
 PtcMouse.ShowMouse;
End;

Procedure HideMouseCursor;
Begin
 PtcMouse.HideMouse;
End;

Procedure GetMouseLocal(Var X, Y, Buttons: Integer);
Var LX, LY, LB: LongInt;
Begin
 PtcMouse.GetMouseState(LX, LY, LB);
 X := LX; Y := LY; Buttons := LB;
End;
{$ENDIF}

{ --------------------------------------------------------------------- }
{ Atmosphere standard                                                    }
{ --------------------------------------------------------------------- }

{$IFDEF FULL}
Procedure ISAAtm(H: Real; Var T, P, Rho, Mu, A: Real);
Begin
 If H < 0 Then H := 0;
 If H > 20000 Then H := 20000;
 If H <= 11000 Then Begin
  T := 288.15 - 0.0065 * H;
  P := 101325.0 * Pow(T / 288.15, 5.25588);
 End
 Else Begin
  T := 216.65;
  P := 22632.1 * Exp(-(H - 11000.0) / 6341.62);
 End;
 Rho := P / (287.058 * T);
 Mu  := 1.458E-6 * T * Sqrt(T) / (T + 110.4);
 A   := Sqrt(1.4 * 287.058 * T);
End;

{$ENDIF}
{ --------------------------------------------------------------------- }
{ Profils d'aile : NACA 4 chiffres et profils importes (.PRO)            }
{ --------------------------------------------------------------------- }

{ Profil NACA a 4 chiffres. Param. X = abscisse (0..1), Upper = extrados.
  Retourne l'ordonnee Z et l'abscisse corrigee XO. }
Procedure NacaPoint(T, M, P, X: Real; Upper: Boolean; Var XO, ZO: Real);
Var Yt, Yc, Dy, Th, S, C: Real;
Begin
 If X < 0 Then X := 0;
 If X > 1 Then X := 1;
 If P < 0.05 Then P := 0.05;
 If P > 0.95 Then P := 0.95;
 Yt := 5.0 * T * (0.2969 * Sqrt(X) - 0.1260 * X - 0.3516 * X * X
                  + 0.2843 * X * X * X - 0.1036 * X * X * X * X);
 If M < 0.0001 Then Begin
  Yc := 0; Dy := 0;
 End
 Else If X < P Then Begin
  Yc := M / (P * P) * (2 * P * X - X * X);
  Dy := 2 * M / (P * P) * (P - X);
 End
 Else Begin
  Yc := M / Sqr2(1 - P) * ((1 - 2 * P) + 2 * P * X - X * X);
  Dy := 2 * M / Sqr2(1 - P) * (P - X);
 End;
 Th := ArcTan(Dy);
 S := Sin(Th); C := Cos(Th);
 If Upper Then Begin
  XO := X - Yt * S; ZO := Yc + Yt * C;
 End
 Else Begin
  XO := X + Yt * S; ZO := Yc - Yt * C;
 End;
End;

{$IFDEF FULL}
Function AFInterp(Var XS, ZS: Array Of Real; N: Integer; X: Real): Real;
Var I: Integer; T: Real;
Begin
 If N < 2 Then Begin AFInterp := 0; Exit; End;
 If X <= XS[0] Then Begin AFInterp := ZS[0]; Exit; End;
 If X >= XS[N - 1] Then Begin AFInterp := ZS[N - 1]; Exit; End;
 I := 0;
 While (I < N - 2) And (XS[I + 1] < X) Do Inc(I);
 If XS[I + 1] - XS[I] < 1E-9 Then AFInterp := ZS[I]
 Else Begin
  T := (X - XS[I]) / (XS[I + 1] - XS[I]);
  AFInterp := ZS[I] + T * (ZS[I + 1] - ZS[I]);
 End;
End;

{ Point d'un profil importe pour l'abscisse X (0..1) }
Procedure AFPoint(Idx: Integer; X: Real; Upper: Boolean; Var ZO: Real);
Begin
 If (Idx < 1) Or (Idx > MAX_AF) Then Begin ZO := 0; Exit; End;
 If Not AFLib^[Idx].Used Then Begin ZO := 0; Exit; End;
 If Upper Then ZO := AFInterp(AFLib^[Idx].UX, AFLib^[Idx].UZ, AFLib^[Idx].NU, X)
 Else ZO := AFInterp(AFLib^[Idx].LX, AFLib^[Idx].LZ, AFLib^[Idx].NL, X);
End;

{ Lit un fichier .PRO (format $nom / $coord / $endcoord, x et y en %) et
  le range dans la bibliotheque. Retourne l'indice du profil ou 0. }
Function LoadPRO(Const FileName: String): Integer;
Var
 F : Text;
 Line, Tag, SX, SY : String;
 InCoord : Boolean;
 PX, PZ  : Array[0..255] Of Real;
 N, I, K, ILE, ITE, NA, NB, Slot, Code : Integer;
 X, Y, MinX, MaxX, Sc, SA, SB, T : Real;
 AX, AZ, BX, BZ : Array[0..255] Of Real;
 Nm : String;
 P : Integer;
Begin
 LoadPRO := 0;
 N := 0; Nm := '';
 {$I-}
 Assign(F, FileName);
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 InCoord := False;
 While Not Eof(F) Do Begin
  ReadLn(F, Line);
  Line := TrimStr(Line);
  If Line = '' Then Continue;
  Tag := UpStr(Line);
  If Tag = '$NOM' Then Begin
   If Not Eof(F) Then Begin ReadLn(F, Line); Nm := TrimStr(Line); End;
   Continue;
  End;
  If Tag = '$COORD' Then Begin InCoord := True; Continue; End;
  If Tag = '$ENDCOORD' Then Begin InCoord := False; Continue; End;
  If InCoord And (N < 256) Then Begin
   P := 1;
   SX := '';
   While (P <= Length(Line)) And (Line[P] <> ' ') And (Line[P] <> #9) Do Begin
    SX := SX + Line[P]; Inc(P);
   End;
   While (P <= Length(Line)) And ((Line[P] = ' ') Or (Line[P] = #9)) Do Inc(P);
   SY := Copy(Line, P, 40);
   Val(SX, X, Code);
   If Code = 0 Then Begin
    Val(TrimStr(SY), Y, Code);
    If Code = 0 Then Begin PX[N] := X; PZ[N] := Y; Inc(N); End;
   End;
  End;
 End;
 Close(F);
 If N < 5 Then Exit;
 If Nm = '' Then Nm := FileName;

 { Normalisation et recherche du bord d'attaque / de fuite }
 MinX := PX[0]; MaxX := PX[0]; ILE := 0; ITE := 0;
 For I := 1 To N - 1 Do Begin
  If PX[I] < MinX Then Begin MinX := PX[I]; ILE := I; End;
  If PX[I] > MaxX Then Begin MaxX := PX[I]; ITE := I; End;
 End;
 If MaxX - MinX < 1E-6 Then Exit;
 Sc := 1.0 / (MaxX - MinX);
 For I := 0 To N - 1 Do Begin
  PX[I] := (PX[I] - MinX) * Sc;
  PZ[I] := PZ[I] * Sc;
 End;
 { Chemin A : ILE -> ITE (indices croissants, cyclique) ; chemin B : ITE -> ILE }
 NA := 0; K := ILE;
 Repeat
  AX[NA] := PX[K]; AZ[NA] := PZ[K]; Inc(NA);
  If K = ITE Then Break;
  K := (K + 1) Mod N;
 Until NA >= 250;
 NB := 0; K := ITE;
 Repeat
  BX[NB] := PX[K]; BZ[NB] := PZ[K]; Inc(NB);
  If K = ILE Then Break;
  K := (K + 1) Mod N;
 Until NB >= 250;
 { chemin B : renverser pour aller de LE a TE }
 For I := 0 To NB Div 2 - 1 Do Begin
  T := BX[I]; BX[I] := BX[NB - 1 - I]; BX[NB - 1 - I] := T;
  T := BZ[I]; BZ[I] := BZ[NB - 1 - I]; BZ[NB - 1 - I] := T;
 End;
 SA := 0; For I := 0 To NA - 1 Do SA := SA + AZ[I];
 SB := 0; For I := 0 To NB - 1 Do SB := SB + BZ[I];
 If NA < 2 Then Exit;
 If NB < 2 Then Exit;
 If NA > MAX_AFPT Then NA := MAX_AFPT;
 If NB > MAX_AFPT Then NB := MAX_AFPT;
 Slot := AFNext;
 AFNext := AFNext + 1;
 If AFNext > MAX_AF Then AFNext := 1;
 AFLib^[Slot].Used := True;
 AFLib^[Slot].Name := Copy(Nm, 1, 24);
 If SA >= SB Then Begin
  AFLib^[Slot].NU := NA; AFLib^[Slot].NL := NB;
  For I := 0 To NA - 1 Do Begin AFLib^[Slot].UX[I] := AX[I]; AFLib^[Slot].UZ[I] := AZ[I]; End;
  For I := 0 To NB - 1 Do Begin AFLib^[Slot].LX[I] := BX[I]; AFLib^[Slot].LZ[I] := BZ[I]; End;
 End
 Else Begin
  AFLib^[Slot].NU := NB; AFLib^[Slot].NL := NA;
  For I := 0 To NB - 1 Do Begin AFLib^[Slot].UX[I] := BX[I]; AFLib^[Slot].UZ[I] := BZ[I]; End;
  For I := 0 To NA - 1 Do Begin AFLib^[Slot].LX[I] := AX[I]; AFLib^[Slot].LZ[I] := AZ[I]; End;
 End;
 { epaisseur maximale }
 T := 0;
 For I := 0 To 40 Do Begin
  X := I / 40.0;
  AFPoint(Slot, X, True, Y);
  AFPoint(Slot, X, False, SA);
  If Y - SA > T Then T := Y - SA;
 End;
 AFLib^[Slot].Thick := T;
 LoadPRO := Slot;
End;
{$ENDIF}

{ --------------------------------------------------------------------- }
{ Interpolation des stations de fuselage (Hermite / Catmull-Rom)         }
{ --------------------------------------------------------------------- }

Function StPosOf(Var G: TGeom; N, K: Integer): Real;
Begin
 If K <= 1 Then StPosOf := 0
 Else If K >= N Then StPosOf := 1
 Else StPosOf := G.StPos[K];
End;

Function Herm1(Var G: TGeom; Var V: Array Of Real; N: Integer; T: Real): Real;
Var
 K : Integer;
 P0, P1, D, U, M0, M1, A, B, Dl : Real;
Begin
 If N < 2 Then Begin Herm1 := V[0]; Exit; End;
 K := 1;
 While (K < N - 1) And (T > StPosOf(G, N, K + 1)) Do Inc(K);
 P0 := StPosOf(G, N, K);
 P1 := StPosOf(G, N, K + 1);
 D := P1 - P0;
 If D < 1E-4 Then Begin Herm1 := V[K - 1]; Exit; End;
 U := (T - P0) / D;
 If U < 0 Then U := 0;
 If U > 1 Then U := 1;
 Dl := (V[K] - V[K - 1]) / D;
 { tangentes (differences centrees) }
 If K > 1 Then
  M0 := (V[K] - V[K - 2]) / MaxR(StPosOf(G, N, K + 1) - StPosOf(G, N, K - 1), 1E-4)
 Else M0 := Dl;
 If K + 1 < N Then
  M1 := (V[K + 1] - V[K - 1]) / MaxR(StPosOf(G, N, K + 2) - StPosOf(G, N, K), 1E-4)
 Else M1 := Dl;
 { limiteur monotone : pas de depassement entre deux stations }
 If Dl = 0 Then Begin M0 := 0; M1 := 0; End
 Else Begin
  If M0 * Dl < 0 Then M0 := 0;
  If M1 * Dl < 0 Then M1 := 0;
  If Abs(M0) > 3 * Abs(Dl) Then M0 := 3 * Dl;
  If Abs(M1) > 3 * Abs(Dl) Then M1 := 3 * Dl;
 End;
 A := 2 * U * U * U - 3 * U * U + 1;
 B := -2 * U * U * U + 3 * U * U;
 Herm1 := A * V[K - 1] + (U * U * U - 2 * U * U + U) * D * M0
          + B * V[K] + (U * U * U - U * U) * D * M1;
End;

Procedure StationEval(Var G: TGeom; N: Integer; T: Real;
                      Var W, H, Z, E: Real);
Begin
 W := Herm1(G, G.StW, N, T);
 H := Herm1(G, G.StH, N, T);
 Z := Herm1(G, G.StZ, N, T);
 E := Herm1(G, G.StE, N, T);
 If W < 0 Then W := 0;
 If H < 0 Then H := 0;
 If E < 1.2 Then E := 1.2;
 If E > 10 Then E := 10;
End;

Procedure ResampleStations(Var G: TGeom; OldN, NewN: Integer);
Var
 K : Integer;
 T, W, H, Z, E : Real;
 NW, NH, NZ, NE, NP : Array[1..MAX_STAT] Of Real;
Begin
 For K := 1 To NewN Do Begin
  T := (K - 1) / (NewN - 1);
  StationEval(G, OldN, T, W, H, Z, E);
  NW[K] := W; NH[K] := H; NZ[K] := Z; NE[K] := E; NP[K] := T;
 End;
 For K := 1 To NewN Do Begin
  G.StW[K] := NW[K]; G.StH[K] := NH[K]; G.StZ[K] := NZ[K];
  G.StE[K] := NE[K]; G.StPos[K] := NP[K];
 End;
End;

{ --------------------------------------------------------------------- }
{ Creation des geometries                                                }
{ --------------------------------------------------------------------- }

Function KindName(K: Integer): String;
Begin
 Case K Of
  GT_WING  : KindName := 'Aile';
  GT_FUSE  : KindName := 'Fuselage';
  GT_POD   : KindName := 'Pod';
{$IFDEF FULL}
  GT_PROP  : KindName := 'Helice';
  GT_DUCT  : KindName := 'Conduit';
{$ENDIF}
  GT_BLANK : KindName := 'Vide';
 Else KindName := '?';
 End;
End;

Procedure InitGeom(Var G: TGeom; K: Byte);
Var
 I : Integer;
Const
 FP : Array[1..7] Of Real = (0.0, 0.05, 0.15, 0.35, 0.6, 0.85, 1.0);
 FW : Array[1..7] Of Real = (0.0, 0.9, 1.4, 1.7, 1.4, 0.6, 0.1);
Begin
 FillChar(G, SizeOf(G), 0);
 G.Used := True;
 G.Visible := True;
 G.Kind := K;
 G.Sym := 0; G.Parent := 0; G.Mass := 0;
 G.CamPos := 0.4;
 Case K Of
  GT_WING: Begin
   G.Sym := 1;
   G.RootChord := 2.5; G.SweepLoc := 0.25; G.NSect := 1; G.Incid := 0;
   G.Thick := 12; G.Camber := 0; G.CamPos := 0.4; G.AFSrc := 0;
   For I := 1 To MAX_SECT Do Begin
    G.SSpan[I] := 4.0; G.STip[I] := 1.2; G.SSweep[I] := 20;
    G.SDih[I] := 0; G.STwist[I] := 0; G.SThick[I] := 10; G.SCamb[I] := 0;
   End;
  End;
  GT_FUSE: Begin
   G.Len := 10; G.NStat := 7;
   For I := 1 To 7 Do Begin
    G.StPos[I] := FP[I]; G.StW[I] := FW[I]; G.StH[I] := FW[I] * 1.0;
    G.StZ[I] := 0; G.StE[I] := 2.2;
   End;
   G.StZ[6] := 0.1; G.StZ[7] := 0.3;
   For I := 8 To MAX_STAT Do Begin
    G.StPos[I] := 1; G.StW[I] := 0.1; G.StH[I] := 0.1; G.StE[I] := 2.2;
   End;
  End;
  GT_POD: Begin
   G.Len := 3; G.Diam := 0.8; G.NoseF := 0.25; G.TailF := 0.35; G.TailR := 0.1;
  End;
{$IFDEF FULL}
  GT_PROP: Begin
   G.Diam := 2.0; G.HubD := 0.3; G.NBlade := 3; G.Pitch := 1.5;
   G.ChordMax := 0.18; G.ThkRoot := 16; G.ThkTip := 8; G.Camber := 3;
   G.CamPos := 0.4; G.SpinL := 0.3;
  End;
  GT_DUCT: Begin
   G.Len := 1.2; G.Diam := 1.5; G.Thick := 12; G.Camber := 3; G.CamPos := 0.4;
  End;
{$ENDIF}
 End;
End;

Function UniqueName(K: Integer): String;
Var N, I: Integer; S: String; Ok: Boolean;
Begin
 N := 1;
 Repeat
  S := KindName(K) + '_' + IntToStr(N);
  Ok := True;
  For I := 0 To GeomCount - 1 Do
   If Geoms^[I].Name = S Then Ok := False;
  If Not Ok Then Inc(N);
 Until Ok;
 UniqueName := S;
End;

Function AddGeom(K: Integer): Integer;
Begin
 If GeomCount >= MAX_GEOM Then Begin AddGeom := -1; Exit; End;
 InitGeom(Geoms^[GeomCount], K);
 Geoms^[GeomCount].Name := UniqueName(K);
 AddGeom := GeomCount;
 Inc(GeomCount);
End;

Procedure DeleteGeom(Idx: Integer);
Var I: Integer;
Begin
 If (Idx < 0) Or (Idx >= GeomCount) Then Exit;
 For I := Idx To GeomCount - 2 Do Geoms^[I] := Geoms^[I + 1];
 Dec(GeomCount);
 Geoms^[GeomCount].Used := False;
 { corriger les parents }
 For I := 0 To GeomCount - 1 Do Begin
  If Round(Geoms^[I].Parent) = Idx + 1 Then Geoms^[I].Parent := 0
  Else If Round(Geoms^[I].Parent) > Idx + 1 Then
   Geoms^[I].Parent := Geoms^[I].Parent - 1;
 End;
 If Sel >= GeomCount Then Sel := GeomCount - 1;
End;

Procedure ClearModel;
Begin
 GeomCount := 0;
 Sel := -1;
 BrowTop := 0;
 ModelName := '';
End;

{ Exemples d'avions }
Procedure ExampleLight;
Var F, W, HT, VT, P, Pr, I: Integer;
Begin
 ClearModel;
 F := AddGeom(GT_FUSE);
 With Geoms^[F] Do Begin
  Name := 'Fuselage'; Len := 8.3; X := 0; Z := 0;
  NStat := 7;
  StPos[1] := 0; StPos[2] := 0.04; StPos[3] := 0.18; StPos[4] := 0.4;
  StPos[5] := 0.62; StPos[6] := 0.85; StPos[7] := 1;
  StW[1] := 0; StW[2] := 0.7; StW[3] := 1.15; StW[4] := 1.2; StW[5] := 0.95;
  StW[6] := 0.35; StW[7] := 0.06;
  StH[1] := 0; StH[2] := 0.75; StH[3] := 1.35; StH[4] := 1.5; StH[5] := 1.1;
  StH[6] := 0.45; StH[7] := 0.08;
  StZ[1] := -0.1; StZ[2] := -0.05; StZ[3] := 0; StZ[4] := 0.05; StZ[5] := 0.12;
  StZ[6] := 0.35; StZ[7] := 0.5;
  For I := 1 To 7 Do StE[I] := 2.4;
 End;
 W := AddGeom(GT_WING);
 With Geoms^[W] Do Begin
  Name := 'Aile'; X := 2.4; Z := 0.75; Sym := 1;
  RootChord := 1.65; NSect := 2; Incid := 2; Thick := 12; Camber := 2.0;
  SSpan[1] := 1.5; STip[1] := 1.65; SSweep[1] := 0; SDih[1] := 0;
  SThick[1] := 12; SCamb[1] := 2;
  SSpan[2] := 3.9; STip[2] := 1.05; SSweep[2] := 2; SDih[2] := 1.5;
  STwist[2] := -2; SThick[2] := 10; SCamb[2] := 1.5;
 End;
 HT := AddGeom(GT_WING);
 With Geoms^[HT] Do Begin
  Name := 'Stab_horizontal'; X := 7.0; Z := 0.55; Sym := 1;
  RootChord := 1.2; NSect := 1; Incid := -1; Thick := 9;
  SSpan[1] := 1.7; STip[1] := 0.75; SSweep[1] := 8; SThick[1] := 8;
 End;
 VT := AddGeom(GT_WING);
 With Geoms^[VT] Do Begin
  Name := 'Derive'; X := 6.7; Z := 0.7; Sym := 0; RX := 90;
  RootChord := 1.5; NSect := 1; Thick := 9;
  SSpan[1] := 1.4; STip[1] := 0.75; SSweep[1] := 35; SThick[1] := 8;
 End;
{$IFDEF FULL}
 Pr := AddGeom(GT_PROP);
 With Geoms^[Pr] Do Begin
  Name := 'Helice'; X := -0.05; Z := -0.05; Diam := 1.9; HubD := 0.25;
  NBlade := 2; Pitch := 1.3; ChordMax := 0.14;
 End;
{$ENDIF}
 P := AddGeom(GT_POD);
 With Geoms^[P] Do Begin
  Name := 'Train_roue'; X := 2.8; Y := 1.4; Z := -0.9; Len := 0.7; Diam := 0.22;
  NoseF := 0.4; TailF := 0.4; TailR := 0.2; Sym := 1;
 End;
 Sel := F;
 ModelName := 'LEGER.VSP';
End;

{$IFDEF FULL}
Procedure ExampleJet;
Var F, W, HT, VT, N, I: Integer;
Begin
 ClearModel;
 F := AddGeom(GT_FUSE);
 With Geoms^[F] Do Begin
  Name := 'Fuselage'; Len := 37.5; NStat := 7;
  StPos[1] := 0; StPos[2] := 0.025; StPos[3] := 0.1; StPos[4] := 0.3;
  StPos[5] := 0.7; StPos[6] := 0.9; StPos[7] := 1;
  StW[1] := 0; StW[2] := 2.0; StW[3] := 3.4; StW[4] := 3.9; StW[5] := 3.9;
  StW[6] := 2.4; StW[7] := 0.4;
  StH[1] := 0; StH[2] := 2.0; StH[3] := 3.5; StH[4] := 4.1; StH[5] := 4.1;
  StH[6] := 2.6; StH[7] := 0.5;
  StZ[1] := -0.3; StZ[2] := -0.2; StZ[3] := 0; StZ[4] := 0; StZ[5] := 0;
  StZ[6] := 0.8; StZ[7] := 1.4;
  For I := 1 To 7 Do StE[I] := 2.0;
 End;
 W := AddGeom(GT_WING);
 With Geoms^[W] Do Begin
  Name := 'Aile'; X := 13.0; Z := -1.3; Sym := 1;
  RootChord := 7.0; NSect := 2; Incid := 2.5; Thick := 13; SweepLoc := 0.25;
  SSpan[1] := 5.0; STip[1] := 4.2; SSweep[1] := 28; SDih[1] := 5;
  SThick[1] := 12; STwist[1] := -0.5;
  SSpan[2] := 12.0; STip[2] := 1.6; SSweep[2] := 25; SDih[2] := 5;
  SThick[2] := 9; STwist[2] := -3.0;
 End;
 HT := AddGeom(GT_WING);
 With Geoms^[HT] Do Begin
  Name := 'Stab_horizontal'; X := 31.5; Z := 1.6; Sym := 1;
  RootChord := 4.2; NSect := 1; Incid := -1; Thick := 9; Camber := 0;
  SSpan[1] := 6.2; STip[1] := 1.5; SSweep[1] := 32; SDih[1] := 4; SThick[1] := 8;
 End;
 VT := AddGeom(GT_WING);
 With Geoms^[VT] Do Begin
  Name := 'Derive'; X := 29.0; Z := 1.9; Sym := 0; RX := 90;
  RootChord := 6.5; NSect := 1; Thick := 10;
  SSpan[1] := 6.0; STip[1] := 2.4; SSweep[1] := 40; SThick[1] := 9;
 End;
 N := AddGeom(GT_POD);
 With Geoms^[N] Do Begin
  Name := 'Nacelle'; X := 10.2; Y := 5.6; Z := -2.6; Len := 4.4; Diam := 1.9;
  NoseF := 0.18; TailF := 0.35; TailR := 0.35; Sym := 1;
 End;
 Sel := F;
 ModelName := 'LIGNE.VSP';
End;

{$ENDIF}
{ --------------------------------------------------------------------- }
{ Descripteurs de parametres                                             }
{ --------------------------------------------------------------------- }

Var
 ParAll : Boolean;

Procedure AddP(Const Key, Lbl: String; P: PReal; Mn, Mx, St: Real;
               Kd, Dc, Tb, Gp: Byte);
Begin
 If ParN >= MAX_PARAM Then Exit;
 Par[ParN].Key := Key;
 Par[ParN].Lbl := Lbl;
 Par[ParN].P := P;
 Par[ParN].Mn := Mn; Par[ParN].Mx := Mx; Par[ParN].St := St;
 Par[ParN].Kind := Kd; Par[ParN].Dec := Dc;
 Par[ParN].Tab := Tb; Par[ParN].Grp := Gp;
 Inc(ParN);
End;

Procedure BuildParams(Var G: TGeom);
Var S: Integer; N: String;
Begin
 ParN := 0;
 AddP('SYM', 'Symetrie', @G.Sym, 0, 1, 1, PK_BOOL, 0, 0, 0);
 AddP('PARENT', 'Parent #', @G.Parent, 0, MAX_GEOM, 1, PK_INT, 0, 0, 0);
 AddP('MASS', 'Masse kg', @G.Mass, 0, 200000, 5, PK_REAL, 1, 0, 0);
 AddP('X', 'X', @G.X, -300, 300, 0.05, PK_REAL, 2, 1, 0);
 AddP('Y', 'Y', @G.Y, -300, 300, 0.05, PK_REAL, 2, 1, 0);
 AddP('Z', 'Z', @G.Z, -300, 300, 0.05, PK_REAL, 2, 1, 0);
 AddP('RX', 'Rot X', @G.RX, -180, 180, 1, PK_REAL, 1, 1, 0);
 AddP('RY', 'Rot Y', @G.RY, -180, 180, 1, PK_REAL, 1, 1, 0);
 AddP('RZ', 'Rot Z', @G.RZ, -180, 180, 1, PK_REAL, 1, 1, 0);
 Case G.Kind Of
  GT_WING: Begin
   AddP('RCHORD', 'Corde rac.', @G.RootChord, 0.05, 30, 0.05, PK_REAL, 2, 2, 0);
   AddP('SWLOC', 'Axe balay.', @G.SweepLoc, 0, 1, 0.05, PK_REAL, 2, 2, 0);
   AddP('NSECT', 'Sections', @G.NSect, 1, MAX_SECT, 1, PK_INT, 0, 2, 0);
   AddP('INCID', 'Incidence', @G.Incid, -15, 15, 0.25, PK_REAL, 2, 2, 0);
   For S := 1 To MAX_SECT Do
    If (S <= Round(G.NSect)) Or ParAll Then Begin
     N := IntToStr(S);
     AddP('SPAN' + N, 'Envergure', @G.SSpan[S], 0.05, 60, 0.05, PK_REAL, 2, 3, S);
     AddP('TIP' + N, 'Corde bout', @G.STip[S], 0.02, 30, 0.05, PK_REAL, 2, 3, S);
     AddP('SWEEP' + N, 'Fleche', @G.SSweep[S], -60, 80, 0.5, PK_REAL, 1, 3, S);
     AddP('DIH' + N, 'Dihedre', @G.SDih[S], -30, 30, 0.5, PK_REAL, 1, 3, S);
     AddP('TWIST' + N, 'Vrillage', @G.STwist[S], -15, 15, 0.25, PK_REAL, 2, 3, S);
     AddP('THK' + N, 'Epais. %', @G.SThick[S], 1, 30, 0.5, PK_REAL, 1, 3, S);
     AddP('CAM' + N, 'Cambr. %', @G.SCamb[S], 0, 9, 0.5, PK_REAL, 1, 3, S);
    End;
   AddP('THICK', 'Epais. %', @G.Thick, 1, 30, 0.5, PK_REAL, 1, 4, 0);
   AddP('CAMBER', 'Cambrure %', @G.Camber, 0, 9, 0.5, PK_REAL, 1, 4, 0);
   AddP('CAMPOS', 'Pos.cambr.', @G.CamPos, 0.1, 0.9, 0.05, PK_REAL, 2, 4, 0);
{$IFDEF FULL}
   AddP('AFSRC', 'Profil', @G.AFSrc, 0, MAX_AF, 1, PK_ENUM, 0, 4, 0);
{$ENDIF}
  End;
  GT_FUSE: Begin
   AddP('LEN', 'Longueur', @G.Len, 0.2, 100, 0.1, PK_REAL, 2, 2, 0);
   AddP('NSTAT', 'Stations', @G.NStat, 2, MAX_STAT, 1, PK_INT, 0, 2, 0);
   For S := 1 To MAX_STAT Do
    If (S <= Round(G.NStat)) Or ParAll Then Begin
     N := IntToStr(S);
     If ((S > 1) And (S < Round(G.NStat))) Or ParAll Then
      AddP('POS' + N, 'Position', @G.StPos[S], 0, 1, 0.01, PK_REAL, 2, 3, S);
     AddP('W' + N, 'Largeur', @G.StW[S], 0, 40, 0.05, PK_REAL, 2, 3, S);
     AddP('H' + N, 'Hauteur', @G.StH[S], 0, 40, 0.05, PK_REAL, 2, 3, S);
     AddP('Z' + N, 'Decal. Z', @G.StZ[S], -10, 10, 0.05, PK_REAL, 2, 3, S);
     AddP('E' + N, 'Exposant', @G.StE[S], 1.2, 10, 0.1, PK_REAL, 1, 3, S);
    End;
  End;
  GT_POD: Begin
   AddP('LEN', 'Longueur', @G.Len, 0.1, 60, 0.05, PK_REAL, 2, 2, 0);
   AddP('DIAM', 'Diametre', @G.Diam, 0.02, 20, 0.02, PK_REAL, 2, 2, 0);
   AddP('NOSEF', 'Nez frac.', @G.NoseF, 0.05, 0.9, 0.05, PK_REAL, 2, 2, 0);
   AddP('TAILF', 'Queue frac.', @G.TailF, 0.05, 0.9, 0.05, PK_REAL, 2, 2, 0);
   AddP('TAILR', 'Rayon queue', @G.TailR, 0, 0.95, 0.05, PK_REAL, 2, 2, 0);
  End;
{$IFDEF FULL}
  GT_PROP: Begin
   AddP('DIAM', 'Diametre', @G.Diam, 0.1, 20, 0.05, PK_REAL, 2, 2, 0);
   AddP('HUBD', 'Moyeu diam.', @G.HubD, 0, 3, 0.02, PK_REAL, 2, 2, 0);
   AddP('NBLADE', 'Pales', @G.NBlade, 2, 8, 1, PK_INT, 0, 2, 0);
   AddP('PITCH', 'Pas (m)', @G.Pitch, 0.05, 20, 0.05, PK_REAL, 2, 2, 0);
   AddP('CHMAX', 'Corde max', @G.ChordMax, 0.01, 3, 0.01, PK_REAL, 2, 2, 0);
   AddP('SPINL', 'Cone long.', @G.SpinL, 0, 3, 0.05, PK_REAL, 2, 2, 0);
   AddP('THKR', 'Epais.rac.%', @G.ThkRoot, 2, 40, 0.5, PK_REAL, 1, 3, 0);
   AddP('THKT', 'Epais.bout%', @G.ThkTip, 2, 40, 0.5, PK_REAL, 1, 3, 0);
   AddP('CAMBER', 'Cambrure %', @G.Camber, 0, 9, 0.5, PK_REAL, 1, 3, 0);
  End;
  GT_DUCT: Begin
   AddP('LEN', 'Corde', @G.Len, 0.05, 30, 0.05, PK_REAL, 2, 2, 0);
   AddP('DIAM', 'Diam. int.', @G.Diam, 0.05, 30, 0.05, PK_REAL, 2, 2, 0);
   AddP('THICK', 'Epais. %', @G.Thick, 2, 40, 0.5, PK_REAL, 1, 2, 0);
   AddP('CAMBER', 'Cambrure %', @G.Camber, 0, 9, 0.5, PK_REAL, 1, 2, 0);
  End;
{$ENDIF}
 End;
End;

Function TabCount(K: Integer): Integer;
Begin
 Case K Of
  GT_WING: TabCount := 5;
  GT_FUSE: TabCount := 4;
  GT_POD:  TabCount := 3;
{$IFDEF FULL}
  GT_PROP: TabCount := 4;
  GT_DUCT: TabCount := 3;
{$ENDIF}
 Else TabCount := 2;
 End;
End;

Function TabName(K, T: Integer): String;
Begin
 TabName := '';
 Case T Of
  0: TabName := 'Gen';
  1: TabName := 'Pos';
  2: Case K Of
      GT_WING: TabName := 'Plan';
{$IFDEF FULL}
      GT_PROP: TabName := 'Pale';
{$ENDIF}
     Else TabName := 'Forme';
     End;
  3: If K = GT_PROP Then TabName := 'Prof' Else TabName := 'Sect';
  4: TabName := 'Prof';
 End;
End;

{ Nombre de groupes (sections) pour l'onglet Sect }
Function GrpCount(Var G: TGeom): Integer;
Begin
 Case G.Kind Of
  GT_WING: GrpCount := Round(G.NSect);
  GT_FUSE: GrpCount := Round(G.NStat);
 Else GrpCount := 0;
 End;
End;

Procedure BuildVisible;
Var I: Integer;
Begin
 VisN := 0;
 For I := 0 To ParN - 1 Do
  If (Par[I].Tab = CurTab) And ((Par[I].Grp = 0) Or (Par[I].Grp = CurGrp)) Then Begin
   VisIdx[VisN] := I;
   Inc(VisN);
  End;
End;

Procedure RefreshParams;
Begin
 If (Sel < 0) Or (Sel >= GeomCount) Then Begin
  ParN := 0; VisN := 0; Exit;
 End;
 ParAll := False;
 BuildParams(Geoms^[Sel]);
 If CurTab >= TabCount(Geoms^[Sel].Kind) Then CurTab := 0;
 If (CurTab = 3) And (GrpCount(Geoms^[Sel]) > 0) Then Begin
  If CurGrp < 1 Then CurGrp := 1;
  If CurGrp > GrpCount(Geoms^[Sel]) Then CurGrp := GrpCount(Geoms^[Sel]);
 End;
 BuildVisible;
 If ParSel >= VisN Then ParSel := VisN - 1;
 If ParSel < 0 Then ParSel := 0;
End;

Procedure SelectGeom(Idx: Integer);
Begin
 If Idx <> Sel Then Begin
  Sel := Idx;
  CurTab := 0;
  CurGrp := 1;
  ParSel := 0;
 End;
 If Sel >= 0 Then Begin
  If Sel < BrowTop Then BrowTop := Sel;
  If Sel >= BrowTop + BROW_ROWS Then BrowTop := Sel - BROW_ROWS + 1;
 End;
 RefreshParams;
End;

{ Reaction apres modification d'un parametre }
Procedure ParamChanged(Var G: TGeom; Const Key: String; OldV: Real);
Var N, O, S: Integer;
Begin
 If Key = 'NSECT' Then Begin
  N := Round(G.NSect);
  O := Round(OldV);
  For S := O + 1 To N Do Begin
   G.SSpan[S] := G.SSpan[O] * 0.6;
   G.STip[S] := G.STip[O] * 0.7;
   G.SSweep[S] := G.SSweep[O];
   G.SDih[S] := G.SDih[O];
   G.STwist[S] := G.STwist[O];
   G.SThick[S] := G.SThick[O];
   G.SCamb[S] := G.SCamb[O];
  End;
 End
 Else If Key = 'NSTAT' Then Begin
  N := Round(G.NStat);
  O := Round(OldV);
  If N <> O Then ResampleStations(G, O, N);
 End
 Else If Copy(Key, 1, 3) = 'POS' Then Begin
  S := Ord(Key[4]) - Ord('0');
  If (S > 1) And (S < Round(G.NStat)) Then Begin
   If G.StPos[S] < StPosOf(G, Round(G.NStat), S - 1) + 0.01 Then
    G.StPos[S] := StPosOf(G, Round(G.NStat), S - 1) + 0.01;
   If G.StPos[S] > StPosOf(G, Round(G.NStat), S + 1) - 0.01 Then
    G.StPos[S] := StPosOf(G, Round(G.NStat), S + 1) - 0.01;
  End;
 End
 Else If Key = 'PARENT' Then Begin
  If Round(G.Parent) > GeomCount Then G.Parent := 0;
 End
{$IFDEF FULL}
 Else If Key = 'AFSRC' Then Begin
  S := Round(G.AFSrc);
  If (S >= 1) And (S <= MAX_AF) Then
   If AFLib^[S].Used Then G.Thick := AFLib^[S].Thick * 100
   Else G.AFSrc := 0
  Else G.AFSrc := 0;
 End
{$ENDIF}
 ;
End;

Procedure PushUndo;
Begin
 Move(Geoms^, UndoBuf^, SizeOf(TGeomArr));
 UndoCount := GeomCount;
 UndoSel := Sel;
 UndoValid := True;
 Modified := True;
End;

{ Modifie le parametre d'indice Idx (dans Par[]) }
Procedure SetParam(Idx: Integer; V: Real);
Var OldV: Real;
Begin
 If (Idx < 0) Or (Idx >= ParN) Then Exit;
 OldV := Par[Idx].P^;
 If V < Par[Idx].Mn Then V := Par[Idx].Mn;
 If V > Par[Idx].Mx Then V := Par[Idx].Mx;
 If (Par[Idx].Kind = PK_INT) Or (Par[Idx].Kind = PK_ENUM) Or
    (Par[Idx].Kind = PK_BOOL) Then V := Round(V);
 If V = OldV Then Exit;
 Par[Idx].P^ := V;
 ParamChanged(Geoms^[Sel], Par[Idx].Key, OldV);
 MeshDirty := True;
 Modified := True;
 RefreshParams;
End;

{ --------------------------------------------------------------------- }
{ Transformations                                                        }
{ --------------------------------------------------------------------- }

Procedure MatMul(Var A, B, C: TMat);
Var I, J, K: Integer; T: TMat; S: Real;
Begin
 For I := 0 To 2 Do
  For J := 0 To 2 Do Begin
   S := 0;
   For K := 0 To 2 Do S := S + A[I, K] * B[K, J];
   T[I, J] := S;
  End;
 C := T;
End;

Procedure LocalRot(Var G: TGeom; Var R: TMat);
Var
 Rx, Ry, Rz, T : TMat;
 A, B, C : Real;
 I, J : Integer;
Begin
 A := G.RX * DEG; B := G.RY * DEG; C := G.RZ * DEG;
 For I := 0 To 2 Do For J := 0 To 2 Do Begin
  Rx[I, J] := 0; Ry[I, J] := 0; Rz[I, J] := 0;
 End;
 Rx[0, 0] := 1; Rx[1, 1] := Cos(A); Rx[1, 2] := -Sin(A);
 Rx[2, 1] := Sin(A); Rx[2, 2] := Cos(A);
 Ry[1, 1] := 1; Ry[0, 0] := Cos(B); Ry[0, 2] := Sin(B);
 Ry[2, 0] := -Sin(B); Ry[2, 2] := Cos(B);
 Rz[2, 2] := 1; Rz[0, 0] := Cos(C); Rz[0, 1] := -Sin(C);
 Rz[1, 0] := Sin(C); Rz[1, 1] := Cos(C);
 MatMul(Rz, Ry, T);
 MatMul(T, Rx, R);
End;

Procedure ComputeXforms;
Var
 Done : Array[0..MAX_GEOM-1] Of Boolean;
 G, Pass, P, I : Integer;
 R : TMat;
 Prog : Boolean;
Begin
 For G := 0 To GeomCount - 1 Do Done[G] := False;
 For Pass := 1 To MAX_GEOM + 1 Do Begin
  Prog := False;
  For G := 0 To GeomCount - 1 Do If Not Done[G] Then Begin
   P := Round(Geoms^[G].Parent) - 1;
   If (P < 0) Or (P >= GeomCount) Or (P = G) Then Begin
    LocalRot(Geoms^[G], GR[G]);
    GT[G, 0] := Geoms^[G].X; GT[G, 1] := Geoms^[G].Y; GT[G, 2] := Geoms^[G].Z;
    Done[G] := True; Prog := True;
   End
   Else If Done[P] Then Begin
    LocalRot(Geoms^[G], R);
    MatMul(GR[P], R, GR[G]);
    For I := 0 To 2 Do
     GT[G, I] := GR[P][I, 0] * Geoms^[G].X + GR[P][I, 1] * Geoms^[G].Y
               + GR[P][I, 2] * Geoms^[G].Z + GT[P, I];
    Done[G] := True; Prog := True;
   End;
  End;
  If Not Prog Then Break;
 End;
 { cycles : traiter comme sans parent }
 For G := 0 To GeomCount - 1 Do If Not Done[G] Then Begin
  LocalRot(Geoms^[G], GR[G]);
  GT[G, 0] := Geoms^[G].X; GT[G, 1] := Geoms^[G].Y; GT[G, 2] := Geoms^[G].Z;
 End;
End;

Procedure ToWorld(G: Integer; Mirror: Boolean; Var X, Y, Z: Real);
Var WX, WY, WZ: Real;
Begin
 WX := GR[G][0, 0] * X + GR[G][0, 1] * Y + GR[G][0, 2] * Z + GT[G, 0];
 WY := GR[G][1, 0] * X + GR[G][1, 1] * Y + GR[G][1, 2] * Z + GT[G, 1];
 WZ := GR[G][2, 0] * X + GR[G][2, 1] * Y + GR[G][2, 2] * Z + GT[G, 2];
 If Mirror Then WY := -WY;
 X := WX; Y := WY; Z := WZ;
End;

{ --------------------------------------------------------------------- }
{ Resolution du maillage                                                 }
{ --------------------------------------------------------------------- }

Function ResWingSub: Integer;
Begin
 Case EffRes Of 0: ResWingSub := 3; 1: ResWingSub := 5; Else ResWingSub := 8; End;
End;

Function ResWingNV: Integer;
Begin
 Case EffRes Of 0: ResWingNV := 16; 1: ResWingNV := 24; Else ResWingNV := 36; End;
End;

Function ResRevNU: Integer;
Begin
 Case EffRes Of 0: ResRevNU := 16; 1: ResRevNU := 26; Else ResRevNU := 40; End;
End;

Function ResRevNV: Integer;
Begin
 Case EffRes Of 0: ResRevNV := 12; 1: ResRevNV := 20; Else ResRevNV := 28; End;
End;

{$IFDEF FULL}
Function ResBladeNU: Integer;
Begin
 Case EffRes Of 0: ResBladeNU := 6; 1: ResBladeNU := 9; Else ResBladeNU := 14; End;
End;

Function ResSmallNU: Integer;
Begin
 Case EffRes Of 0: ResSmallNU := 8; 1: ResSmallNU := 12; Else ResSmallNU := 16; End;
End;

Function ResDuctNU: Integer;
Begin
 Case EffRes Of 0: ResDuctNU := 16; 1: ResDuctNU := 24; Else ResDuctNU := 36; End;
End;

{$ENDIF}
{ --------------------------------------------------------------------- }
{ Parties d'une geometrie                                                }
{ --------------------------------------------------------------------- }

{$IFDEF FULL}
Function HasSpinner(Var G: TGeom): Boolean;
Begin
 HasSpinner := (G.HubD > 0.01) And (G.SpinL > 0.01);
End;

{$ENDIF}
Function BasePartCount(Var G: TGeom): Integer;
Begin
 Case G.Kind Of
  GT_WING, GT_FUSE, GT_POD: BasePartCount := 1;
{$IFDEF FULL}
  GT_DUCT: BasePartCount := 1;
  GT_PROP: Begin
   BasePartCount := Round(G.NBlade);
   If HasSpinner(G) Then BasePartCount := Round(G.NBlade) + 1;
  End;
{$ENDIF}
 Else BasePartCount := 0;
 End;
End;

Function PartCount(Var G: TGeom): Integer;
Begin
 If G.Sym > 0.5 Then PartCount := BasePartCount(G) * 2
 Else PartCount := BasePartCount(G);
End;

Procedure PartDims(Var G: TGeom; BP: Integer; Var NU, NVv: Integer;
                   Var Caps: Boolean);
Begin
 Caps := True;
 Case G.Kind Of
  GT_WING: Begin
   NU := Round(G.NSect) * ResWingSub + 1; NVv := ResWingNV;
  End;
  GT_FUSE, GT_POD: Begin
   NU := ResRevNU; NVv := ResRevNV;
  End;
{$IFDEF FULL}
  GT_PROP: Begin
   If BP < Round(G.NBlade) Then Begin
    NU := ResBladeNU; NVv := ResWingNV Div 2 + 4;
   End
   Else Begin NU := ResSmallNU; NVv := ResRevNV; End;
  End;
  GT_DUCT: Begin
   NU := ResDuctNU + 1; NVv := ResWingNV; Caps := False;
  End;
{$ENDIF}
 Else Begin NU := 0; NVv := 0; End;
 End;
 If NVv Mod 2 = 1 Then Inc(NVv);
 If NVv > MAX_RNV Then NVv := MAX_RNV;
End;

{ Section d'indice I d'une partie : remplit la variable Ring }
Procedure PrepRing(Var G: TGeom; BP, I, NU: Integer);
Var
 S, Q, K, NS, NSb, NB : Integer;
 X0, Y0, Z0, C0, C1, Tw0, Th0, Cm0, T, Sp : Real;
 Rr, R0, Rho, Sh, Rh : Real;
 W, H, Z, E, Tt : Real;
Begin
 Ring.C := 0; Ring.X0 := 0; Ring.Y0 := 0; Ring.Z0 := 0; Ring.Tw := 0;
 Ring.Th := 0; Ring.Cm := 0; Ring.A := 0; Ring.B := 0; Ring.D := 0;
 Ring.E := 0; Ring.F := 0;
 Case G.Kind Of
  GT_WING: Begin
   NS := Round(G.NSect);
   NSb := ResWingSub;
   If I >= NS * NSb Then Begin S := NS; K := NSb; End
   Else Begin S := I Div NSb + 1; K := I Mod NSb; End;
   X0 := 0; Y0 := 0; Z0 := 0; C0 := G.RootChord;
   Tw0 := G.Incid; Th0 := G.Thick; Cm0 := G.Camber;
   For Q := 1 To S - 1 Do Begin
    Sp := G.SSpan[Q];
    X0 := X0 + Sp * Tan(G.SSweep[Q] * DEG) + G.SweepLoc * (C0 - G.STip[Q]);
    Y0 := Y0 + Sp;
    Z0 := Z0 + Sp * Tan(G.SDih[Q] * DEG);
    C0 := G.STip[Q];
    Tw0 := G.Incid + G.STwist[Q];
    Th0 := G.SThick[Q];
    Cm0 := G.SCamb[Q];
   End;
   T := K / NSb;
   Sp := G.SSpan[S];
   C1 := G.STip[S];
   Ring.C := C0 + (C1 - C0) * T;
   Ring.X0 := X0 + T * Sp * Tan(G.SSweep[S] * DEG) + G.SweepLoc * (C0 - Ring.C);
   Ring.Y0 := Y0 + T * Sp;
   Ring.Z0 := Z0 + T * Sp * Tan(G.SDih[S] * DEG);
   Ring.Tw := (Tw0 + (G.Incid + G.STwist[S] - Tw0) * T) * DEG;
   Ring.Th := (Th0 + (G.SThick[S] - Th0) * T) / 100.0;
   Ring.Cm := (Cm0 + (G.SCamb[S] - Cm0) * T) / 100.0;
  End;
  GT_FUSE: Begin
   Tt := (1 - Cos(3.14159265358979 * I / (NU - 1))) / 2;
   StationEval(G, Round(G.NStat), Tt, W, H, Z, E);
   Ring.A := W / 2; Ring.D := H / 2; Ring.B := G.Len * Tt;
   Ring.F := Z; Ring.E := E;
  End;
  GT_POD: Begin
   Tt := (1 - Cos(3.14159265358979 * I / (NU - 1))) / 2;
   Rr := G.Diam / 2;
   Sp := Tt * G.Len;
   W := MinR(G.NoseF, 0.95);
   H := MinR(G.TailF, 1.0 - W);
   If H < 0.02 Then H := 0.02;
   E := W * G.Len;           { longueur du nez }
   Z := H * G.Len;           { longueur de la queue }
   If Sp < E Then Rr := Rr * Sqrt(MaxR(0, 1 - Sqr2(1 - Sp / E)))
   Else If Sp > G.Len - Z Then Begin
    T := (Sp - (G.Len - Z)) / Z;
    Rr := Rr * (G.TailR + (1 - G.TailR) * Sqrt(MaxR(0, 1 - T * T)));
   End;
   Ring.A := Rr; Ring.B := Sp;
  End;
{$IFDEF FULL}
  GT_PROP: Begin
   NB := Round(G.NBlade);
   If BP < NB Then Begin
    Rr := G.Diam / 2;
    R0 := MaxR(G.HubD / 2 * 0.9, 0.04 * Rr);
    Rho := I / (NU - 1);
    Ring.Y0 := R0 + (Rr - R0) * Rho;
    Sh := Sqrt(MaxR(0, 1 - Sqr2((Rho - 0.45) / 0.55)));
    Ring.C := G.ChordMax * MaxR(0.05, Sh);
    Ring.Tw := ArcTan(G.Pitch / (PI2 * Ring.Y0));
    Ring.Th := (G.ThkRoot + (G.ThkTip - G.ThkRoot) * Rho) / 100.0;
    Ring.Cm := G.Camber / 100.0;
    Ring.A := BP * PI2 / NB;
   End
   Else Begin
    Rh := G.HubD / 2;
    Tt := (1 - Cos(3.14159265358979 * I / (NU - 1))) / 2;
    Ring.A := Rh * Sqrt(MaxR(0, 1 - Sqr2(1 - Tt)));
    Ring.B := -G.SpinL * (1 - Tt);
   End;
  End;
  GT_DUCT: Begin
   Tt := PI2 * I / (NU - 1);
   Ring.A := Cos(Tt); Ring.B := Sin(Tt);
  End;
{$ENDIF}
 End;
End;

{ Point J (0..NV-1) de la section courante, en coordonnees locales }
Procedure RingPoint(Var G: TGeom; BP, J, NVv: Integer; Var X, Y, Z: Real);
Var
 Beta, Xa, Xo, Za, Px, Pz, Cb, Sb, Ph, Cc, Sc, U, V, Zt, Xax : Real;
 Upper : Boolean;
 Af : Integer;
Begin
 X := 0; Y := 0; Z := 0;
 Case G.Kind Of
{$IFDEF FULL}
  GT_WING, GT_PROP, GT_DUCT: Begin
   If (G.Kind = GT_PROP) And (BP >= Round(G.NBlade)) Then Begin
    Beta := PI2 * J / NVv;
    X := Ring.B; Y := Ring.A * Cos(Beta); Z := Ring.A * Sin(Beta);
    Exit;
   End;
   Beta := PI2 * J / NVv;
   Xa := (1 + Cos(Beta)) / 2;
   Upper := J <= NVv Div 2;
   If G.Kind = GT_DUCT Then
    NacaPoint(G.Thick / 100.0, G.Camber / 100.0, G.CamPos, Xa, Upper, Xo, Za)
   Else Begin
{$IFDEF FULL}
    Af := Round(G.AFSrc);
    If (G.Kind = GT_WING) And (Af >= 1) And (Af <= MAX_AF) And
       AFLib^[Af].Used And (AFLib^[Af].Thick > 0.001) Then Begin
     Xo := Xa;
     AFPoint(Af, Xa, Upper, Za);
     Za := Za * Ring.Th / AFLib^[Af].Thick;
    End
    Else
{$ENDIF}
     NacaPoint(Ring.Th, Ring.Cm, G.CamPos, Xa, Upper, Xo, Za);
   End;
   If G.Kind = GT_WING Then Begin
    Px := (Xo - 0.25) * Ring.C; Pz := Za * Ring.C;
    Cb := Cos(Ring.Tw); Sb := Sin(Ring.Tw);
    X := Ring.X0 + 0.25 * Ring.C + Px * Cb + Pz * Sb;
    Y := Ring.Y0;
    Z := Ring.Z0 - Px * Sb + Pz * Cb;
   End
   Else If G.Kind = GT_PROP Then Begin
    U := (Xo - 0.25) * Ring.C; V := Za * Ring.C;
    Cb := Cos(Ring.Tw); Sb := Sin(Ring.Tw);
    Zt := U * Cb + V * Sb;
    Xax := -U * Sb + V * Cb;
    Ph := Ring.A; Cc := Cos(Ph); Sc := Sin(Ph);
    X := Xax;
    Y := Ring.Y0 * Cc - Zt * Sc;
    Z := Ring.Y0 * Sc + Zt * Cc;
   End
   Else Begin
    X := Xo * G.Len;
    U := G.Diam / 2 + Za * G.Len;
    Y := U * Ring.A; Z := U * Ring.B;
   End;
  End;
{$ELSE}
  GT_WING: Begin
   Beta := PI2 * J / NVv;
   Xa := (1 + Cos(Beta)) / 2;
   Upper := J <= NVv Div 2;
   NacaPoint(Ring.Th, Ring.Cm, G.CamPos, Xa, Upper, Xo, Za);
   Px := (Xo - 0.25) * Ring.C; Pz := Za * Ring.C;
   Cb := Cos(Ring.Tw); Sb := Sin(Ring.Tw);
   X := Ring.X0 + 0.25 * Ring.C + Px * Cb + Pz * Sb;
   Y := Ring.Y0;
   Z := Ring.Z0 - Px * Sb + Pz * Cb;
  End;
{$ENDIF}
  GT_FUSE: Begin
   Beta := PI2 * J / NVv;
   Cc := Cos(Beta); Sc := Sin(Beta);
   X := Ring.B;
   If Ring.E < 1.2 Then Ring.E := 1.2;
   Y := Ring.A * Sgn(Cc) * Pow(Abs(Cc), 2 / Ring.E);
   Z := Ring.F + Ring.D * Sgn(Sc) * Pow(Abs(Sc), 2 / Ring.E);
  End;
  GT_POD: Begin
   Beta := PI2 * J / NVv;
   X := Ring.B; Y := Ring.A * Cos(Beta); Z := Ring.A * Sin(Beta);
  End;
 End;
End;

{ --------------------------------------------------------------------- }
{ Construction du maillage                                               }
{ --------------------------------------------------------------------- }

Procedure CountMesh(Var Vn, Qn: Integer);
Var G, P, NU, NVv: Integer; Caps: Boolean;
Begin
 Vn := 0; Qn := 0;
 For G := 0 To GeomCount - 1 Do
  If Geoms^[G].Used And Geoms^[G].Visible Then
   For P := 0 To PartCount(Geoms^[G]) - 1 Do Begin
    PartDims(Geoms^[G], P Mod BasePartCount(Geoms^[G]), NU, NVv, Caps);
    Vn := Vn + NU * NVv;
    Qn := Qn + (NU - 1) * NVv;
    If Caps Then Begin Vn := Vn + 2; Qn := Qn + 2 * NVv; End;
   End;
End;

Procedure AddQuad(A, B, C, D: Integer; G, F: Integer);
Var
 Ax, Ay, Az, Bx, By, Bz, Nx, Ny, Nz, L : Real;
Begin
 If NQ >= MAX_QUAD Then Begin MeshOver := True; Exit; End;
 MQ^[NQ].A := A; MQ^[NQ].B := B; MQ^[NQ].C := C; MQ^[NQ].D := D;
 MQ^[NQ].G := G; MQ^[NQ].F := F;
 Ax := (MV^[C].X - MV^[A].X) / 1000.0;
 Ay := (MV^[C].Y - MV^[A].Y) / 1000.0;
 Az := (MV^[C].Z - MV^[A].Z) / 1000.0;
 Bx := (MV^[D].X - MV^[B].X) / 1000.0;
 By := (MV^[D].Y - MV^[B].Y) / 1000.0;
 Bz := (MV^[D].Z - MV^[B].Z) / 1000.0;
 Nx := Ay * Bz - Az * By;
 Ny := Az * Bx - Ax * Bz;
 Nz := Ax * By - Ay * Bx;
 L := Sqrt(Nx * Nx + Ny * Ny + Nz * Nz);
 If L < 1E-9 Then Begin
  MQ^[NQ].NX := 0; MQ^[NQ].NY := 0; MQ^[NQ].NZ := 127;
 End
 Else Begin
  MQ^[NQ].NX := Round(Nx / L * 127);
  MQ^[NQ].NY := Round(Ny / L * 127);
  MQ^[NQ].NZ := Round(Nz / L * 127);
 End;
 Inc(NQ);
End;

Procedure AddPartMesh(GI, P: Integer);
Var
 BP, NBase, NU, NVv, I, J, Base, J1, CV, K : Integer;
 Caps, Mir : Boolean;
 X, Y, Z, Sx, Sy, Sz : Real;
 Fl : Integer;
Begin
 NBase := BasePartCount(Geoms^[GI]);
 If NBase = 0 Then Exit;
 BP := P Mod NBase;
 Mir := P >= NBase;
 PartDims(Geoms^[GI], BP, NU, NVv, Caps);
 If (NV + NU * NVv + 2 > MAX_VERT) Or (NQ + (NU - 1) * NVv + 2 * NVv > MAX_QUAD) Then Begin
  MeshOver := True; Exit;
 End;
 Base := NV;
 For I := 0 To NU - 1 Do Begin
  PrepRing(Geoms^[GI], BP, I, NU);
  For J := 0 To NVv - 1 Do Begin
   RingPoint(Geoms^[GI], BP, J, NVv, X, Y, Z);
   ToWorld(GI, Mir, X, Y, Z);
   MV^[NV].X := ToMM(X); MV^[NV].Y := ToMM(Y); MV^[NV].Z := ToMM(Z);
   Inc(NV);
  End;
 End;
 For I := 0 To NU - 2 Do Begin
  If I = NU - 2 Then Fl := 1 Else Fl := 0;
  For J := 0 To NVv - 1 Do Begin
   J1 := (J + 1) Mod NVv;
   AddQuad(Base + I * NVv + J, Base + I * NVv + J1,
           Base + (I + 1) * NVv + J1, Base + (I + 1) * NVv + J, GI, Fl);
  End;
 End;
 If Caps Then
  For K := 0 To 1 Do Begin
   If K = 0 Then I := 0 Else I := NU - 1;
   Sx := 0; Sy := 0; Sz := 0;
   For J := 0 To NVv - 1 Do Begin
    Sx := Sx + MV^[Base + I * NVv + J].X;
    Sy := Sy + MV^[Base + I * NVv + J].Y;
    Sz := Sz + MV^[Base + I * NVv + J].Z;
   End;
   CV := NV;
   MV^[NV].X := Round(Sx / NVv); MV^[NV].Y := Round(Sy / NVv);
   MV^[NV].Z := Round(Sz / NVv);
   Inc(NV);
   For J := 0 To NVv - 1 Do Begin
    J1 := (J + 1) Mod NVv;
    AddQuad(CV, Base + I * NVv + J, Base + I * NVv + J1, CV, GI, 2);
   End;
  End;
End;

Procedure BuildMesh;
Var
 G, P, I, Vn, Qn : Integer;
 First : Boolean;
 X, Y, Z : Real;
Begin
 ComputeXforms;
 EffRes := Res;
 CountMesh(Vn, Qn);
 While ((Vn > MAX_VERT - 4) Or (Qn > MAX_QUAD - 4)) And (EffRes > 0) Do Begin
  Dec(EffRes);
  CountMesh(Vn, Qn);
 End;
 NV := 0; NQ := 0; MeshOver := False;
 For G := 0 To GeomCount - 1 Do
  If Geoms^[G].Used And Geoms^[G].Visible Then
   For P := 0 To PartCount(Geoms^[G]) - 1 Do
    AddPartMesh(G, P);
 First := True;
 BMinX := 0; BMaxX := 1; BMinY := 0; BMaxY := 1; BMinZ := 0; BMaxZ := 1;
 For I := 0 To NV - 1 Do Begin
  X := MV^[I].X / 1000.0; Y := MV^[I].Y / 1000.0; Z := MV^[I].Z / 1000.0;
  If First Then Begin
   BMinX := X; BMaxX := X; BMinY := Y; BMaxY := Y; BMinZ := Z; BMaxZ := Z;
   First := False;
  End
  Else Begin
   If X < BMinX Then BMinX := X; If X > BMaxX Then BMaxX := X;
   If Y < BMinY Then BMinY := Y; If Y > BMaxY Then BMaxY := Y;
   If Z < BMinZ Then BMinZ := Z; If Z > BMaxZ Then BMaxZ := Z;
  End;
 End;
 MeshDirty := False;
End;

{ --------------------------------------------------------------------- }
{ Camera et projection                                                   }
{ --------------------------------------------------------------------- }

Procedure ComputeView;
Var Sa, Ca, Se, Ce, L: Real;
Begin
 Sa := Sin(CamAz * DEG); Ca := Cos(CamAz * DEG);
 Se := Sin(CamEl * DEG); Ce := Cos(CamEl * DEG);
 VR[0] := -Sa; VR[1] := Ca; VR[2] := 0;
 VU[0] := -Ca * Se; VU[1] := -Sa * Se; VU[2] := Ce;
 VF[0] := -Ce * Ca; VF[1] := -Ce * Sa; VF[2] := -Se;
 { lumiere : en haut a gauche, vers la camera }
 LightX := -0.35 * VR[0] + 0.55 * VU[0] - 0.75 * VF[0];
 LightY := -0.35 * VR[1] + 0.55 * VU[1] - 0.75 * VF[1];
 LightZ := -0.35 * VR[2] + 0.55 * VU[2] - 0.75 * VF[2];
 L := Sqrt(LightX * LightX + LightY * LightY + LightZ * LightZ);
 LightX := LightX / L; LightY := LightY / L; LightZ := LightZ / L;
End;

Procedure ProjPt(X, Y, Z: Real; Var Sx, Sy: Integer; Var D: Real);
Var Px, Py, Pz: Real;
Begin
 Px := X - PivX; Py := Y - PivY; Pz := Z - PivZ;
 Sx := ToInt((VX2 - VX1) / 2 + CamPX + (VR[0] * Px + VR[1] * Py + VR[2] * Pz) * CamZoom);
 Sy := ToInt((VY2 - VY1) / 2 + CamPY - (VU[0] * Px + VU[1] * Py + VU[2] * Pz) * CamZoom);
 D := VF[0] * Px + VF[1] * Py + VF[2] * Pz;
End;

Procedure ProjectAll;
Var
 I : Integer;
 Px, Py, Pz, Cx, Cy : Real;
Begin
 Cx := (VX2 - VX1) / 2 + CamPX;
 Cy := (VY2 - VY1) / 2 + CamPY;
 For I := 0 To NV - 1 Do Begin
  Px := MV^[I].X / 1000.0 - PivX;
  Py := MV^[I].Y / 1000.0 - PivY;
  Pz := MV^[I].Z / 1000.0 - PivZ;
  PSX^[I] := ToInt(Cx + (VR[0] * Px + VR[1] * Py + VR[2] * Pz) * CamZoom);
  PSY^[I] := ToInt(Cy - (VU[0] * Px + VU[1] * Py + VU[2] * Pz) * CamZoom);
  PSZ^[I] := Round((VF[0] * Px + VF[1] * Py + VF[2] * Pz) * 1000.0);
 End;
End;

Procedure FitView;
Var Dx, Dy, Dz, M, Z1, Z2: Real;
Begin
 If NV = 0 Then Begin
  PivX := 0; PivY := 0; PivZ := 0; CamZoom := 40; CamPX := 0; CamPY := 0;
  Exit;
 End;
 PivX := (BMinX + BMaxX) / 2; PivY := (BMinY + BMaxY) / 2;
 PivZ := (BMinZ + BMaxZ) / 2;
 Dx := BMaxX - BMinX; Dy := BMaxY - BMinY; Dz := BMaxZ - BMinZ;
 M := Sqrt(Dx * Dx + Dy * Dy + Dz * Dz);
 If M < 0.1 Then M := 0.1;
 Z1 := (VX2 - VX1) * 0.9 / M;
 Z2 := (VY2 - VY1) * 0.9 / M;
 CamZoom := MinR(Z1, Z2);
 CamPX := 0; CamPY := 0;
End;

Procedure SetView(Az, El: Real; Const Nm: String);
Begin
 CamAz := Az; CamEl := El; ViewName := Nm;
 ComputeView;
 NeedView := True;
End;

{ --------------------------------------------------------------------- }
{ Codes d'action                                                        }
{ --------------------------------------------------------------------- }

Const
 ACT_NONE     = 0;
 ACT_NEW      = 1;
 ACT_OPEN     = 2;
 ACT_SAVE     = 3;
 ACT_SAVEAS   = 4;
 ACT_EX1      = 5;
 ACT_EX2      = 6;
 ACT_IMPORT   = 7;
 ACT_EXSTL    = 8;
 ACT_EXOBJ    = 9;
 ACT_EXCSV    = 10;
 ACT_QUIT     = 11;
 ACT_UNDO     = 20;
 ACT_DUP      = 21;
 ACT_DEL      = 22;
 ACT_RENAME   = 23;
 ACT_SYM      = 24;
 ACT_VISIBLE  = 25;
 ACT_HIDEALL  = 26;
 ACT_SHOWALL  = 27;
 ACT_ADD      = 40;      { + type de geometrie }
 ACT_WIRE     = 60;
 ACT_HIDDEN   = 61;
 ACT_SHADED   = 62;
 ACT_AXES     = 63;
 ACT_GRID     = 64;
 ACT_MESH     = 65;
 ACT_VTOP     = 70;
 ACT_VBOTTOM  = 71;
 ACT_VFRONT   = 72;
 ACT_VBACK    = 73;
 ACT_VLEFT    = 74;
 ACT_VRIGHT   = 75;
 ACT_VISO     = 76;
 ACT_FIT      = 77;
 ACT_ZOOMIN   = 78;
 ACT_ZOOMOUT  = 79;
 ACT_COMPGEOM = 80;
 ACT_MASS     = 81;
 ACT_DRAG     = 82;
 ACT_AERO     = 83;
 ACT_ATMOS    = 84;
 ACT_PLAN     = 85;
 ACT_REPORT   = 86;
 ACT_KEYS     = 90;
 ACT_ABOUT    = 91;

 TB_COUNT     = 14;

Var
 TbCap  : Array[0..TB_COUNT-1] Of String[8];
 TbAct  : Array[0..TB_COUNT-1] Of Integer;
 TbX1, TbX2 : Array[0..TB_COUNT-1] Of Integer;

{ --------------------------------------------------------------------- }
{ Primitives d'interface                                                 }
{ --------------------------------------------------------------------- }

Function GeomColor(K: Integer): Word;
Begin
 Case K Of
  GT_WING  : GeomColor := LightCyan;
  GT_FUSE  : GeomColor := LightGray;
  GT_POD   : GeomColor := LightGreen;
{$IFDEF FULL}
  GT_PROP  : GeomColor := LightMagenta;
  GT_DUCT  : GeomColor := LightRed;
{$ENDIF}
 Else GeomColor := White;
 End;
End;

Procedure DrawBevel(X1, Y1, X2, Y2: Integer; Inset: Boolean);
Begin
 If Inset Then SetColor(DarkGray) Else SetColor(White);
 Line(X1, Y1, X2, Y1);
 Line(X1, Y1, X1, Y2);
 If Inset Then SetColor(White) Else SetColor(DarkGray);
 Line(X2, Y1, X2, Y2);
 Line(X1, Y2, X2, Y2);
End;

Procedure DrawButton(X1, Y1, X2, Y2: Integer; Const Cap: String; Down: Boolean);
Var TW: Integer;
Begin
 SetFillStyle(SolidFill, LightGray);
 Bar(X1, Y1, X2, Y2);
 DrawBevel(X1, Y1, X2, Y2, Down);
 SetColor(Black);
 TW := TextWidth(Cap);
 OutTextXY(X1 + (X2 - X1 + 1 - TW) Div 2 + Ord(Down), Y1 + (Y2 - Y1 - 7) Div 2 + Ord(Down), Cap);
End;

Procedure DrawCheck(X, Y: Integer);
Begin
 Line(X, Y + 3, X + 2, Y + 5);
 Line(X + 2, Y + 5, X + 7, Y);
 Line(X, Y + 4, X + 2, Y + 6);
 Line(X + 2, Y + 6, X + 7, Y + 1);
End;

{ --------------------------------------------------------------------- }
{ Menus                                                                  }
{ --------------------------------------------------------------------- }

Procedure ZeroMenu(Var M: TMenu);
Var I: Integer;
Begin
 M.ItemCount := 0;
 For I := 0 To MAX_MENU_ITEMS - 1 Do Begin
  M.Items[I].Caption := ''; M.Items[I].Shortcut := '';
  M.Items[I].Enabled := True; M.Items[I].Checked := False;
  M.Items[I].Separator := False; M.Items[I].Act := ACT_NONE;
 End;
End;

Procedure MI(Mn: Integer; Const Cap, Sc: String; Act: Integer);
Begin
 With Menus[Mn] Do Begin
  Items[ItemCount].Caption := Cap;
  Items[ItemCount].Shortcut := Sc;
  Items[ItemCount].Act := Act;
  Inc(ItemCount);
 End;
End;

Procedure MSep(Mn: Integer);
Begin
 With Menus[Mn] Do Begin
  Items[ItemCount].Separator := True;
  Inc(ItemCount);
 End;
End;

Procedure InitMenus;
Var I: Integer;
Begin
 For I := 0 To NUM_MENUS - 1 Do ZeroMenu(Menus[I]);
 Menus[MENU_FILE].Title := 'Fichier';
 MI(MENU_FILE, 'Nouveau', 'Ctrl+N', ACT_NEW);
 MI(MENU_FILE, 'Ouvrir...', 'Ctrl+O', ACT_OPEN);
 MI(MENU_FILE, 'Enregistrer', 'Ctrl+S', ACT_SAVE);
 MI(MENU_FILE, 'Enregistrer sous...', '', ACT_SAVEAS);
 MSep(MENU_FILE);
 MI(MENU_FILE, 'Exemple: avion leger', '', ACT_EX1);
{$IFDEF FULL}
 MI(MENU_FILE, 'Exemple: avion de ligne', '', ACT_EX2);
{$ENDIF}
 MSep(MENU_FILE);
{$IFDEF FULL}
 MI(MENU_FILE, 'Importer profil .PRO...', '', ACT_IMPORT);
{$ENDIF}
 MI(MENU_FILE, 'Exporter STL...', '', ACT_EXSTL);
{$IFDEF FULL}
 MI(MENU_FILE, 'Exporter OBJ...', '', ACT_EXOBJ);
 MI(MENU_FILE, 'Exporter degen .CSV...', '', ACT_EXCSV);
{$ENDIF}
 MSep(MENU_FILE);
 MI(MENU_FILE, 'Quitter', 'Alt+F4', ACT_QUIT);

 Menus[MENU_EDIT].Title := 'Edition';
 MI(MENU_EDIT, 'Annuler', 'Ctrl+Z', ACT_UNDO);
 MSep(MENU_EDIT);
 MI(MENU_EDIT, 'Dupliquer', 'Ctrl+D', ACT_DUP);
 MI(MENU_EDIT, 'Supprimer', 'Del', ACT_DEL);
 MI(MENU_EDIT, 'Renommer...', 'F2', ACT_RENAME);
 MSep(MENU_EDIT);
 MI(MENU_EDIT, 'Symetrie (plan XZ)', 'S', ACT_SYM);
 MI(MENU_EDIT, 'Visible', 'V', ACT_VISIBLE);
 MI(MENU_EDIT, 'Masquer tout', '', ACT_HIDEALL);
 MI(MENU_EDIT, 'Afficher tout', '', ACT_SHOWALL);

 Menus[MENU_GEOM].Title := 'Geometrie';
 MI(MENU_GEOM, 'Aile', '', ACT_ADD + GT_WING);
 MI(MENU_GEOM, 'Fuselage', '', ACT_ADD + GT_FUSE);
 MI(MENU_GEOM, 'Pod / nacelle', '', ACT_ADD + GT_POD);
{$IFDEF FULL}
 MI(MENU_GEOM, 'Helice', '', ACT_ADD + GT_PROP);
 MI(MENU_GEOM, 'Conduit (duct)', '', ACT_ADD + GT_DUCT);
{$ENDIF}
 MI(MENU_GEOM, 'Vide (blank)', '', ACT_ADD + GT_BLANK);

 Menus[MENU_VIEW].Title := 'Vue';
 MI(MENU_VIEW, 'Fil de fer', 'W', ACT_WIRE);
 MI(MENU_VIEW, 'Lignes cachees', 'H', ACT_HIDDEN);
 MI(MENU_VIEW, 'Ombre', 'D', ACT_SHADED);
 MSep(MENU_VIEW);
 MI(MENU_VIEW, 'Axes', 'A', ACT_AXES);
 MI(MENU_VIEW, 'Grille', 'G', ACT_GRID);
 MI(MENU_VIEW, 'Maillage: Normal', 'M', ACT_MESH);
 MSep(MENU_VIEW);
 MI(MENU_VIEW, 'Dessus', '1', ACT_VTOP);
 MI(MENU_VIEW, 'Dessous', '2', ACT_VBOTTOM);
 MI(MENU_VIEW, 'Face', '3', ACT_VFRONT);
 MI(MENU_VIEW, 'Arriere', '4', ACT_VBACK);
 MI(MENU_VIEW, 'Gauche', '5', ACT_VLEFT);
 MI(MENU_VIEW, 'Droite', '6', ACT_VRIGHT);
 MI(MENU_VIEW, 'Isometrique', '7', ACT_VISO);
 MI(MENU_VIEW, 'Ajuster', 'Home', ACT_FIT);

 Menus[MENU_ANALYSE].Title := 'Analyse';
{$IFDEF FULL}
 MI(MENU_ANALYSE, 'Geometrie calculee', '', ACT_COMPGEOM);
 MI(MENU_ANALYSE, 'Masse et centrage', '', ACT_MASS);
 MI(MENU_ANALYSE, 'Trainee parasite', '', ACT_DRAG);
 MI(MENU_ANALYSE, 'Aerodynamique', '', ACT_AERO);
{$ENDIF}
 MI(MENU_ANALYSE, 'Planforme des ailes', '', ACT_PLAN);
{$IFDEF FULL}
 MSep(MENU_ANALYSE);
 MI(MENU_ANALYSE, 'Conditions de vol...', '', ACT_ATMOS);
 MI(MENU_ANALYSE, 'Rapport complet .TXT', '', ACT_REPORT);
{$ENDIF}

 Menus[MENU_HELP].Title := 'Aide';
 MI(MENU_HELP, 'Touches...', 'F1', ACT_KEYS);
 MI(MENU_HELP, 'A propos...', '', ACT_ABOUT);
End;

Procedure FindItem(Act: Integer; Var M, I: Integer);
Var A, B: Integer;
Begin
 M := -1; I := -1;
 For A := 0 To NUM_MENUS - 1 Do
  For B := 0 To Menus[A].ItemCount - 1 Do
   If Menus[A].Items[B].Act = Act Then Begin M := A; I := B; End;
End;

Procedure SetItem(Act: Integer; Chk, En: Boolean);
Var M, I: Integer;
Begin
 FindItem(Act, M, I);
 If M >= 0 Then Begin
  Menus[M].Items[I].Checked := Chk;
  Menus[M].Items[I].Enabled := En;
 End;
End;

Procedure UpdateMenuStates;
Var M, I, K: Integer; Has: Boolean;
Begin
 Has := (Sel >= 0) And (Sel < GeomCount);
 SetItem(ACT_WIRE, RenderMode = RM_WIRE, True);
 SetItem(ACT_HIDDEN, RenderMode = RM_HIDDEN, True);
 SetItem(ACT_SHADED, RenderMode = RM_SHADED, True);
 SetItem(ACT_AXES, ShowAxes, True);
 SetItem(ACT_GRID, ShowGrid, True);
 SetItem(ACT_UNDO, False, UndoValid);
 SetItem(ACT_DUP, False, Has);
 SetItem(ACT_DEL, False, Has);
 SetItem(ACT_RENAME, False, Has);
 SetItem(ACT_SYM, Has And (Geoms^[Sel].Sym > 0.5), Has);
 SetItem(ACT_VISIBLE, Has And Geoms^[Sel].Visible, Has);
 SetItem(ACT_IMPORT, False, True);
 FindItem(ACT_MESH, M, I);
 If M >= 0 Then Begin
  Case Res Of
   0: Menus[M].Items[I].Caption := 'Maillage: Grossier';
   1: Menus[M].Items[I].Caption := 'Maillage: Normal';
  Else Menus[M].Items[I].Caption := 'Maillage: Fin';
  End;
 End;
 For K := 0 To 5 Do
  SetItem(ACT_ADD + K, False, GeomCount < MAX_GEOM);
End;

Procedure DrawMenuBar;
Var
 I, X, W: Integer;
Begin
 SetFillStyle(SolidFill, LightGray);
 Bar(0, 0, ScreenWidth - 1, MENUBAR_H - 1);
 SetColor(DarkGray);
 Line(0, MENUBAR_H - 1, ScreenWidth - 1, MENUBAR_H - 1);
 X := 5;
 For I := 0 To NUM_MENUS - 1 Do Begin
  Menus[I].X := X;
  W := TextWidth(Menus[I].Title);
  If MenuActive And (ActiveMenu = I) Then Begin
   SetFillStyle(SolidFill, Blue);
   Bar(X - 2, 2, X + W + 2, MENUBAR_H - 3);
   SetColor(White);
  End
  Else SetColor(Black);
  OutTextXY(X, 6, Menus[I].Title);
  X := X + W + 16;
 End;
 SetColor(DarkGray);
 OutTextXY(ScreenWidth - 8 * Length(PROG_TITLE) - 5, 6, PROG_TITLE);
End;

Procedure MenuGeom(MenuIdx: Integer; Var X, Y, W, H: Integer);
Var I, Wmax, Wi: Integer;
Begin
 Wmax := 0;
 For I := 0 To Menus[MenuIdx].ItemCount - 1 Do Begin
  Wi := TextWidth(Menus[MenuIdx].Items[I].Caption) + 30
        + TextWidth(Menus[MenuIdx].Items[I].Shortcut) + 12;
  If Wi > Wmax Then Wmax := Wi;
 End;
 If Wmax < 130 Then Wmax := 130;
 Menus[MenuIdx].Width := Wmax;
 X := Menus[MenuIdx].X - 2;
 If X + Wmax + 2 > ScreenWidth Then X := ScreenWidth - Wmax - 2;
 Y := MENUBAR_H;
 W := Wmax;
 H := Menus[MenuIdx].ItemCount * 16 + 4;
End;

Procedure DrawMenuPopup(MenuIdx: Integer);
Var
 I, X, Y, W, H, WSc : Integer;
 Sc : String;
Begin
 If (MenuIdx < 0) Or (MenuIdx >= NUM_MENUS) Then Exit;
 MenuGeom(MenuIdx, X, Y, W, H);
 SetFillStyle(SolidFill, LightGray);
 Bar(X, Y, X + W, Y + H);
 SetColor(White);
 Line(X, Y, X + W, Y);
 Line(X, Y, X, Y + H);
 SetColor(DarkGray);
 Line(X + W, Y, X + W, Y + H);
 Line(X, Y + H, X + W, Y + H);
 SetColor(Black);
 Line(X + W + 1, Y + 1, X + W + 1, Y + H + 1);
 Line(X + 1, Y + H + 1, X + W + 1, Y + H + 1);
 For I := 0 To Menus[MenuIdx].ItemCount - 1 Do Begin
  If Menus[MenuIdx].Items[I].Separator Then Begin
   SetColor(DarkGray);
   Line(X + 4, Y + 2 + I * 16 + 8, X + W - 4, Y + 2 + I * 16 + 8);
   SetColor(White);
   Line(X + 4, Y + 2 + I * 16 + 9, X + W - 4, Y + 2 + I * 16 + 9);
  End
  Else Begin
   If ActiveMenuItem = I Then Begin
    SetFillStyle(SolidFill, Blue);
    Bar(X + 2, Y + 2 + I * 16, X + W - 2, Y + 2 + (I + 1) * 16 - 1);
    SetColor(White);
   End
   Else If Menus[MenuIdx].Items[I].Enabled Then SetColor(Black)
   Else SetColor(DarkGray);
   If Menus[MenuIdx].Items[I].Checked Then DrawCheck(X + 7, Y + 5 + I * 16);
   OutTextXY(X + 22, Y + 6 + I * 16, Menus[MenuIdx].Items[I].Caption);
   Sc := Menus[MenuIdx].Items[I].Shortcut;
   If Sc <> '' Then Begin
    WSc := TextWidth(Sc);
    OutTextXY(X + W - WSc - 8, Y + 6 + I * 16, Sc);
   End;
  End;
 End;
End;

{ Sauvegarde / restauration de l'arriere-plan sous un menu }
Procedure MenuSaveBG(MenuIdx: Integer);
Var X, Y, W, H: Integer; Sz: LongInt; Ok: Boolean;
Begin
 MenuGeom(MenuIdx, X, Y, W, H);
 MenuSaveX := X; MenuSaveY := Y;
 Sz := ImageSize(X, Y, X + W + 2, Y + H + 2);
 Ok := (Sz > 0) And (HeapFree > Sz + 2048);
 {$IFNDEF FPC}
  If Sz >= 65000 Then Ok := False;
 {$ENDIF}
 If Ok Then Begin
  GetMem(MenuSave, Sz);
  MenuSaveSz := Sz;
  GetImage(X, Y, X + W + 2, Y + H + 2, MenuSave^);
  MenuSaved := True;
 End
 Else MenuSaved := False;
End;

Procedure MenuRestoreBG;
Begin
 If MenuSaved Then Begin
  PutImage(MenuSaveX, MenuSaveY, MenuSave^, NormalPut);
  FreeMem(MenuSave, MenuSaveSz);
  MenuSaved := False;
 End
 Else NeedAll := True;
End;

Function MenuBarHitTest(Mx, My: Integer): Integer;
Var I, X1, X2: Integer;
Begin
 MenuBarHitTest := -1;
 If My >= MENUBAR_H Then Exit;
 For I := 0 To NUM_MENUS - 1 Do Begin
  X1 := Menus[I].X - 2;
  X2 := Menus[I].X + TextWidth(Menus[I].Title) + 2;
  If (Mx >= X1) And (Mx <= X2) Then Begin MenuBarHitTest := I; Exit; End;
 End;
End;

Function MenuItemHitTest(Mx, My, MenuIdx: Integer): Integer;
Var Idx, X, Y, W, H: Integer;
Begin
 MenuItemHitTest := -1;
 If (MenuIdx < 0) Or (MenuIdx >= NUM_MENUS) Then Exit;
 MenuGeom(MenuIdx, X, Y, W, H);
 If (Mx < X) Or (Mx > X + W) Or (My < Y) Or (My > Y + H) Then Exit;
 Idx := (My - Y - 2) Div 16;
 If (Idx < 0) Or (Idx >= Menus[MenuIdx].ItemCount) Then Exit;
 MenuItemHitTest := Idx;
End;

Procedure MenuNextItem(Step: Integer);
Var N, I: Integer;
Begin
 If (ActiveMenu < 0) Or (ActiveMenu >= NUM_MENUS) Then Exit;
 N := Menus[ActiveMenu].ItemCount;
 If N <= 0 Then Exit;
 If ActiveMenuItem < 0 Then Begin
  If Step > 0 Then ActiveMenuItem := -1 Else ActiveMenuItem := N;
 End;
 For I := 1 To N Do Begin
  ActiveMenuItem := ActiveMenuItem + Step;
  If ActiveMenuItem < 0 Then ActiveMenuItem := N - 1;
  If ActiveMenuItem >= N Then ActiveMenuItem := 0;
  If Not Menus[ActiveMenu].Items[ActiveMenuItem].Separator Then Exit;
 End;
End;

{ --------------------------------------------------------------------- }
{ Barre d'outils                                                         }
{ --------------------------------------------------------------------- }

Procedure InitToolbar;
Var I, X: Integer;
 Procedure T(N: Integer; Const C: String; A: Integer);
 Begin TbCap[N] := C; TbAct[N] := A; End;
Begin
 T(0, 'Haut', ACT_VTOP);   T(1, 'Face', ACT_VFRONT);
 T(2, 'Cote', ACT_VLEFT);  T(3, 'Iso', ACT_VISO);
 T(4, 'Ajust', ACT_FIT);   T(5, 'Fil', ACT_WIRE);
 T(6, 'Cache', ACT_HIDDEN); T(7, 'Ombre', ACT_SHADED);
 T(8, 'Axes', ACT_AXES);  T(9, 'Grille', ACT_GRID);
 T(10, '+', ACT_ZOOMIN); T(11, '-', ACT_ZOOMOUT);
 T(12, 'Annul', ACT_UNDO); T(13, 'Maill', ACT_MESH);
 X := 4;
 For I := 0 To TB_COUNT - 1 Do Begin
  If (I = 5) Or (I = 8) Or (I = 10) Or (I = 12) Then X := X + 6;
  TbX1[I] := X;
  TbX2[I] := X + TextWidth(TbCap[I]) + 8;
  X := TbX2[I] + 2;
 End;
End;

Function ToolOn(Act: Integer): Boolean;
Begin
 Case Act Of
  ACT_WIRE:   ToolOn := RenderMode = RM_WIRE;
  ACT_HIDDEN: ToolOn := RenderMode = RM_HIDDEN;
  ACT_SHADED: ToolOn := RenderMode = RM_SHADED;
  ACT_AXES:   ToolOn := ShowAxes;
  ACT_GRID:   ToolOn := ShowGrid;
 Else ToolOn := False;
 End;
End;

Procedure DrawToolbar;
Var I: Integer;
Begin
 SetFillStyle(SolidFill, LightGray);
 Bar(0, TOOLBAR_Y, ScreenWidth - 1, TOOLBAR_Y + TOOLBAR_H - 1);
 SetColor(White);
 Line(0, TOOLBAR_Y, ScreenWidth - 1, TOOLBAR_Y);
 SetColor(DarkGray);
 Line(0, TOOLBAR_Y + TOOLBAR_H - 1, ScreenWidth - 1, TOOLBAR_Y + TOOLBAR_H - 1);
 For I := 0 To TB_COUNT - 1 Do
  DrawButton(TbX1[I], TOOLBAR_Y + 3, TbX2[I], TOOLBAR_Y + TOOLBAR_H - 4,
             TbCap[I], ToolOn(TbAct[I]));
End;

Function ToolbarHit(Mx, My: Integer): Integer;
Var I: Integer;
Begin
 ToolbarHit := -1;
 If (My < TOOLBAR_Y + 3) Or (My > TOOLBAR_Y + TOOLBAR_H - 4) Then Exit;
 For I := 0 To TB_COUNT - 1 Do
  If (Mx >= TbX1[I]) And (Mx <= TbX2[I]) Then ToolbarHit := I;
End;

{ --------------------------------------------------------------------- }
{ Panneau gauche : navigateur et parametres                              }
{ --------------------------------------------------------------------- }

Function RowOffset: Integer;
Begin
 RowOffset := 0;
 If (Sel >= 0) And (Sel < GeomCount) Then
  If (CurTab = 3) And (GrpCount(Geoms^[Sel]) > 0) Then RowOffset := 1;
End;

Function ParamText(I: Integer): String;
Var V: Real; K: Integer;
Begin
 V := Par[I].P^;
 Case Par[I].Kind Of
  PK_BOOL: If V > 0.5 Then ParamText := 'Oui' Else ParamText := 'Non';
  PK_INT:  ParamText := IntToStr(Round(V));
  PK_ENUM: Begin
   K := Round(V);
   If (K >= 1) And (K <= MAX_AF) And AFLib^[K].Used Then
    ParamText := Copy(AFLib^[K].Name, 1, 7)
   Else ParamText := 'NACA';
  End;
 Else ParamText := RealToStr(V, Par[I].Dec);
 End;
End;

Procedure SliderBounds(Var SX1, SX2: Integer);
Begin
 SX1 := 94; SX2 := 150;
End;

Procedure DrawPanel;
Var
 I, K, Y, X, Row, SX1, SX2, KX, N, Cnt, TW : Integer;
 Fr : Real;
 S : String;
Begin
 SetFillStyle(SolidFill, LightGray);
 Bar(0, PANEL_Y, PANEL_W - 1, ScreenHeight - STATUS_H - 1);
 SetColor(DarkGray);
 Line(PANEL_W, PANEL_Y, PANEL_W, ScreenHeight - STATUS_H - 1);

 { navigateur }
 SetColor(Black);
 OutTextXY(6, PANEL_Y + 4, 'Geometries');
 DrawButton(PANEL_W - 38, PANEL_Y + 1, PANEL_W - 21, PANEL_Y + 13, '^', False);
 DrawButton(PANEL_W - 20, PANEL_Y + 1, PANEL_W - 3, PANEL_Y + 13, 'v', False);
 SetFillStyle(SolidFill, White);
 Bar(3, BROW_Y - 1, PANEL_W - 4, BROW_Y + BROW_ROWS * BROW_RH);
 DrawBevel(2, BROW_Y - 2, PANEL_W - 3, BROW_Y + BROW_ROWS * BROW_RH + 1, True);
 For I := BrowTop To MinI(GeomCount - 1, BrowTop + BROW_ROWS - 1) Do Begin
  Y := BROW_Y + (I - BrowTop) * BROW_RH;
  If I = Sel Then Begin
   SetFillStyle(SolidFill, Blue);
   Bar(4, Y, PANEL_W - 5, Y + BROW_RH - 1);
   SetColor(White);
  End
  Else SetColor(Black);
  { icone de visibilite }
  SetFillStyle(SolidFill, LightGray);
  Bar(6, Y + 2, 14, Y + 9);
  If Geoms^[I].Visible Then Begin
   SetColor(Black);
   Line(6, Y + 5, 10, Y + 2); Line(10, Y + 2, 14, Y + 5);
   Line(6, Y + 5, 10, Y + 9); Line(10, Y + 9, 14, Y + 5);
   PutPixel(10, Y + 5, Black);
  End;
  If I = Sel Then SetColor(White) Else SetColor(Black);
  OutTextXY(19, Y + 2, Copy(Geoms^[I].Name, 1, 13));
  If I <> Sel Then SetColor(DarkGray);
  S := KindName(Geoms^[I].Kind);
  OutTextXY(PANEL_W - 8 - 8 * Length(S) - 4, Y + 2, S);
 End;

 { boutons }
 DrawButton(4, BTN_Y, 56, BTN_Y + 16, 'Ajout', False);
 DrawButton(58, BTN_Y, 108, BTN_Y + 16, 'Copie', False);
 DrawButton(110, BTN_Y, 160, BTN_Y + 16, 'Suppr', False);
 DrawButton(162, BTN_Y, 212, BTN_Y + 16, 'Nom', False);

 If (Sel < 0) Or (Sel >= GeomCount) Then Begin
  SetColor(DarkGray);
  OutTextXY(10, PAR_Y + 10, 'Aucune geometrie.');
  OutTextXY(10, PAR_Y + 24, 'Menu Geometrie ou');
  OutTextXY(10, PAR_Y + 36, 'Fichier > Exemples');
  Exit;
 End;

 { onglets }
 N := TabCount(Geoms^[Sel].Kind);
 X := 3;
 For I := 0 To N - 1 Do Begin
  TW := TextWidth(TabName(Geoms^[Sel].Kind, I)) + 10;
  If I = CurTab Then Begin
   SetFillStyle(SolidFill, White);
   Bar(X, TAB_Y, X + TW, TAB_Y + 17);
   DrawBevel(X, TAB_Y, X + TW, TAB_Y + 18, False);
   SetColor(Black);
  End
  Else Begin
   SetFillStyle(SolidFill, LightGray);
   Bar(X, TAB_Y + 2, X + TW, TAB_Y + 17);
   DrawBevel(X, TAB_Y + 2, X + TW, TAB_Y + 18, False);
   SetColor(DarkGray);
  End;
  OutTextXY(X + 5, TAB_Y + 7, TabName(Geoms^[Sel].Kind, I));
  X := X + TW + 2;
 End;
 SetColor(White);
 Line(3, TAB_Y + 19, PANEL_W - 4, TAB_Y + 19);

 { selecteur de section }
 Row := 0;
 If RowOffset = 1 Then Begin
  Cnt := GrpCount(Geoms^[Sel]);
  For K := 1 To Cnt Do Begin
   DrawButton(4 + (K - 1) * 22, PAR_Y + 2, 4 + (K - 1) * 22 + 20, PAR_Y + 14,
              IntToStr(K), K = CurGrp);
  End;
  Row := 1;
 End;

 SliderBounds(SX1, SX2);
 For I := 0 To VisN - 1 Do Begin
  K := VisIdx[I];
  Y := PAR_Y + (I + Row) * PAR_RH + 4;
  If (I + Row) >= PAR_ROWS Then Break;
  If ParFocus And (I = ParSel) Then Begin
   SetFillStyle(SolidFill, Blue);
   Bar(3, Y - 1, PANEL_W - 4, Y + PAR_RH - 2);
   SetColor(White);
  End
  Else SetColor(Black);
  OutTextXY(5, Y + 1, Par[K].Lbl);
  S := ParamText(K);
  If Par[K].Kind = PK_BOOL Then Begin
   { case a cocher }
   SetFillStyle(SolidFill, White);
   Bar(SX1, Y, SX1 + 10, Y + 10);
   DrawBevel(SX1, Y, SX1 + 10, Y + 10, True);
   SetColor(Black);
   If Par[K].P^ > 0.5 Then DrawCheck(SX1 + 2, Y + 2);
   If ParFocus And (I = ParSel) Then SetColor(White) Else SetColor(Black);
   OutTextXY(SX1 + 16, Y + 1, S);
  End
  Else Begin
   SetFillStyle(SolidFill, White);
   Bar(SX1, Y + 3, SX2, Y + 7);
   DrawBevel(SX1, Y + 3, SX2, Y + 7, True);
   If Par[K].Mx > Par[K].Mn Then
    Fr := (Par[K].P^ - Par[K].Mn) / (Par[K].Mx - Par[K].Mn)
   Else Fr := 0;
   If Fr < 0 Then Fr := 0;
   If Fr > 1 Then Fr := 1;
   KX := SX1 + Round(Fr * (SX2 - SX1 - 5));
   SetFillStyle(SolidFill, LightGray);
   Bar(KX, Y, KX + 5, Y + 10);
   DrawBevel(KX, Y, KX + 5, Y + 10, False);
   If ParFocus And (I = ParSel) Then SetColor(White) Else SetColor(Black);
   OutTextXY(SX2 + 5, Y + 1, S);
  End;
 End;
End;

Function BrowserHit(Mx, My: Integer): Integer;
Var R: Integer;
Begin
 BrowserHit := -1;
 If (Mx < 3) Or (Mx > PANEL_W - 4) Then Exit;
 If (My < BROW_Y) Or (My >= BROW_Y + BROW_ROWS * BROW_RH) Then Exit;
 R := BrowTop + (My - BROW_Y) Div BROW_RH;
 If R < GeomCount Then BrowserHit := R;
End;

Function TabHit(Mx, My: Integer): Integer;
Var I, X, TW, N: Integer;
Begin
 TabHit := -1;
 If (Sel < 0) Or (Sel >= GeomCount) Then Exit;
 If (My < TAB_Y + 2) Or (My > TAB_Y + 18) Then Exit;
 N := TabCount(Geoms^[Sel].Kind);
 X := 3;
 For I := 0 To N - 1 Do Begin
  TW := TextWidth(TabName(Geoms^[Sel].Kind, I)) + 10;
  If (Mx >= X) And (Mx <= X + TW) Then Begin TabHit := I; Exit; End;
  X := X + TW + 2;
 End;
End;

{ --------------------------------------------------------------------- }
{ Scene 3D                                                               }
{ --------------------------------------------------------------------- }

Var
 Poly : Array[0..4] Of PointType;

{ Rampe d'ombrage (niveau 0 = sombre ... 4 = eclaire). Les tons sombres sont
  trames (75/50/25 %) ; retourne la couleur a utiliser pour le contour. }
Function SetShade(Kind: Integer; Selected: Boolean; Lvl: Integer): Word;
Var
 Pat : FillPatternType;
 Br, Dk : Word;
 Dens, I : Integer;      { Dens : 0 plein, 1 = 75 %, 2 = 50 %, 3 = 25 % }
 Col : Word;
Begin
 If Selected Then Begin Br := Yellow; Dk := Brown; End
 Else Case Kind Of
  GT_WING: Begin Br := LightCyan;    Dk := Cyan; End;
  GT_FUSE: Begin Br := White;        Dk := DarkGray; End;
  GT_POD:  Begin Br := LightGreen;   Dk := Green; End;
{$IFDEF FULL}
  GT_PROP: Begin Br := LightMagenta; Dk := Magenta; End;
  GT_DUCT: Begin Br := LightRed;     Dk := Red; End;
{$ENDIF}
 Else Begin Br := White; Dk := LightGray; End;
 End;
 If (Kind = GT_FUSE) And (Not Selected) Then Begin
  { fuselage : blanc, gris clair, gris fonce plein puis tramage }
  Case Lvl Of
   4: Begin Col := White; Dens := 0; End;
   3: Begin Col := LightGray; Dens := 0; End;
   2: Begin Col := DarkGray; Dens := 0; End;
   1: Begin Col := DarkGray; Dens := 1; End;
  Else Begin Col := DarkGray; Dens := 2; End;
  End;
 End
 Else Case Lvl Of
  4: Begin Col := Br; Dens := 0; End;
  3: Begin Col := Dk; Dens := 0; End;
  2: Begin Col := Dk; Dens := 1; End;
  1: Begin Col := Dk; Dens := 2; End;
 Else Begin Col := Dk; Dens := 3; End;
 End;
 If Dens = 0 Then SetFillStyle(SolidFill, Col)
 Else Begin
  For I := 1 To 8 Do
   Case Dens Of
    1: If Odd(I) Then Pat[I] := $EE Else Pat[I] := $BB;
    2: If Odd(I) Then Pat[I] := $AA Else Pat[I] := $55;
   Else If Odd(I) Then Pat[I] := $88 Else Pat[I] := $22;
   End;
  SetFillPattern(Pat, Col);
  SetFillStyle(UserFill, Col);
 End;
 SetShade := Col;
End;

Procedure ShellSortQuads(N: Integer);
Var Gap, I, J: Integer; T: Word; D: LongInt;
Begin
 Gap := N Div 2;
 While Gap > 0 Do Begin
  For I := Gap To N - 1 Do Begin
   T := QOrd^[I]; D := QDep^[T];
   J := I;
   While (J >= Gap) And (QDep^[QOrd^[J - Gap]] < D) Do Begin
    QOrd^[J] := QOrd^[J - Gap];
    J := J - Gap;
   End;
   QOrd^[J] := T;
  End;
  Gap := Gap Div 2;
 End;
End;

Procedure LoadPoly(Q: Integer);
Begin
 Poly[0].X := PSX^[MQ^[Q].A]; Poly[0].Y := PSY^[MQ^[Q].A];
 Poly[1].X := PSX^[MQ^[Q].B]; Poly[1].Y := PSY^[MQ^[Q].B];
 Poly[2].X := PSX^[MQ^[Q].C]; Poly[2].Y := PSY^[MQ^[Q].C];
 Poly[3].X := PSX^[MQ^[Q].D]; Poly[3].Y := PSY^[MQ^[Q].D];
 Poly[4] := Poly[0];
End;

Procedure DrawEdges(Q: Integer; Col: Word);
Var A, B, C, D: Word;
Begin
 A := MQ^[Q].A; B := MQ^[Q].B; C := MQ^[Q].C; D := MQ^[Q].D;
 If MQ^[Q].F = 2 Then Exit;
 SetColor(Col);
 Line(PSX^[A], PSY^[A], PSX^[B], PSY^[B]);
 Line(PSX^[A], PSY^[A], PSX^[D], PSY^[D]);
 If MQ^[Q].F = 1 Then Line(PSX^[C], PSY^[C], PSX^[D], PSY^[D]);
End;

Procedure DrawGridAndAxes;
Var
 Step, Ext, X, Z0, Mx : Real;
 Sx1, Sy1, Sx2, Sy2 : Integer;
 D : Real;
 Cx, Cy : Real;
Begin
 Mx := MaxR(BMaxX - BMinX, BMaxY - BMinY);
 If Mx < 1 Then Mx := 1;
 Step := 0.1;
 While Mx / Step > 12 Do Begin
  If Step < 0.15 Then Step := 0.2
  Else If Step < 0.3 Then Step := 0.5
  Else If Step < 0.7 Then Step := 1
  Else If Step < 1.5 Then Step := 2
  Else If Step < 3 Then Step := 5
  Else Step := Step * 2;
 End;
 If ShowGrid Then Begin
  Ext := Int(Mx * 0.7 / Step + 1) * Step;
  Z0 := BMinZ;
  Cx := Int((BMinX + BMaxX) / 2 / Step) * Step;
  Cy := Int((BMinY + BMaxY) / 2 / Step) * Step;
  SetColor(DarkGray);
  X := -Ext;
  While X <= Ext + 0.001 Do Begin
   ProjPt(Cx + X, Cy - Ext, Z0, Sx1, Sy1, D);
   ProjPt(Cx + X, Cy + Ext, Z0, Sx2, Sy2, D);
   Line(Sx1, Sy1, Sx2, Sy2);
   ProjPt(Cx - Ext, Cy + X, Z0, Sx1, Sy1, D);
   ProjPt(Cx + Ext, Cy + X, Z0, Sx2, Sy2, D);
   Line(Sx1, Sy1, Sx2, Sy2);
   X := X + Step;
  End;
 End;
 If ShowAxes Then Begin
  ProjPt(0, 0, 0, Sx1, Sy1, D);
  ProjPt(Step * 2, 0, 0, Sx2, Sy2, D);
  SetColor(LightRed); Line(Sx1, Sy1, Sx2, Sy2);
  OutTextXY(Sx2 + 3, Sy2 - 3, 'X');
  ProjPt(0, Step * 2, 0, Sx2, Sy2, D);
  SetColor(LightGreen); Line(Sx1, Sy1, Sx2, Sy2);
  OutTextXY(Sx2 + 3, Sy2 - 3, 'Y');
  ProjPt(0, 0, Step * 2, Sx2, Sy2, D);
  SetColor(LightBlue); Line(Sx1, Sy1, Sx2, Sy2);
  OutTextXY(Sx2 + 3, Sy2 - 3, 'Z');
 End;
End;

Procedure DrawTriad;
Var X0, Y0, L: Integer;
Begin
 X0 := 30; Y0 := VY2 - VY1 - 30; L := 20;
 SetColor(LightRed);
 Line(X0, Y0, X0 + Round(VR[0] * L), Y0 - Round(VU[0] * L));
 OutTextXY(X0 + Round(VR[0] * (L + 4)) - 3, Y0 - Round(VU[0] * (L + 4)) - 3, 'X');
 SetColor(LightGreen);
 Line(X0, Y0, X0 + Round(VR[1] * L), Y0 - Round(VU[1] * L));
 OutTextXY(X0 + Round(VR[1] * (L + 4)) - 3, Y0 - Round(VU[1] * (L + 4)) - 3, 'Y');
 SetColor(LightBlue);
 Line(X0, Y0, X0 + Round(VR[2] * L), Y0 - Round(VU[2] * L));
 OutTextXY(X0 + Round(VR[2] * (L + 4)) - 3, Y0 - Round(VU[2] * (L + 4)) - 3, 'Z');
End;

Procedure DrawScene(Fast: Boolean);
Var
 Q, N, Lvl : Integer;
 Mode : Integer;
 Col, OutCol : Word;
 Sh, Nx, Ny, Nz : Real;
 G, LastG : Integer;
 LastLvl : Integer;
Begin
 If MeshDirty Then BuildMesh;
 HideMouseCursor;
 SetViewPort(VX1, VY1, VX2, VY2, True);
 SetFillStyle(SolidFill, Black);
 Bar(0, 0, VX2 - VX1, VY2 - VY1);
 ProjectAll;
 DrawGridAndAxes;
 Mode := RenderMode;
 If Fast Then Mode := RM_WIRE;
 If Mode = RM_WIRE Then Begin
  For Q := 0 To NQ - 1 Do Begin
   G := MQ^[Q].G;
   If (G = Sel) And ShowSel Then DrawEdges(Q, Yellow)
   Else DrawEdges(Q, GeomColor(Geoms^[G].Kind));
  End;
 End
 Else Begin
  For Q := 0 To NQ - 1 Do Begin
   QOrd^[Q] := Q;
   QDep^[Q] := (PSZ^[MQ^[Q].A] + PSZ^[MQ^[Q].B] + PSZ^[MQ^[Q].C]
                + PSZ^[MQ^[Q].D]) Div 4;
  End;
  ShellSortQuads(NQ);
  LastG := -1; LastLvl := -1;
  For N := 0 To NQ - 1 Do Begin
   Q := QOrd^[N];
   G := MQ^[Q].G;
   Col := GeomColor(Geoms^[G].Kind);
   LoadPoly(Q);
   If Mode = RM_HIDDEN Then Begin
    SetFillStyle(SolidFill, Black);
    If (G = Sel) And ShowSel Then SetColor(Yellow) Else SetColor(Col);
    FillPoly(4, Poly);
   End
   Else Begin
    Nx := MQ^[Q].NX / 127.0; Ny := MQ^[Q].NY / 127.0; Nz := MQ^[Q].NZ / 127.0;
    Sh := Abs(Nx * LightX + Ny * LightY + Nz * LightZ);
    Sh := 0.1 + 0.9 * Sh;
    Lvl := Trunc(Sh * 5.0);
    If Lvl > 4 Then Lvl := 4;
    If Lvl < 0 Then Lvl := 0;
    If (Lvl <> LastLvl) Or (G <> LastG) Then Begin
     OutCol := SetShade(Geoms^[G].Kind, (G = Sel) And ShowSel, Lvl);
     LastLvl := Lvl; LastG := G;
    End;
    SetColor(OutCol);
    FillPoly(4, Poly);
   End;
  End;
 End;
 { blanks : repere de la geometrie }
 For G := 0 To GeomCount - 1 Do
  If Geoms^[G].Visible And (Geoms^[G].Kind = GT_BLANK) Then Begin
   Sh := 0;
   ProjPt(GT[G, 0], GT[G, 1], GT[G, 2], Lvl, N, Sh);
   If G = Sel Then SetColor(Yellow) Else SetColor(LightGray);
   Line(Lvl - 6, N, Lvl + 6, N);
   Line(Lvl, N - 6, Lvl, N + 6);
   Circle(Lvl, N, 4);
  End;
 DrawTriad;
 SetColor(DarkGray);
 OutTextXY(6, 6, 'Vue: ' + ViewName);
 OutTextXY(6, 16, F1(CamZoom) + ' px/m');
 If MeshOver Then Begin
  SetColor(LightRed);
  OutTextXY(6, 26, 'Maillage tronque');
 End;
 SetViewPort(0, 0, ScreenWidth - 1, ScreenHeight - 1, True);
 SetColor(White);
 Rectangle(VX1 - 1, VY1 - 1, VX2 + 1, VY2 + 1);
 ShowMouseCursor;
End;

{ Selection par clic dans la vue : retourne l'indice de la geometrie }
Function PickGeom(Mx, My: Integer): Integer;
Var
 Q, Best : Integer;
 X, Y : Integer;
 BestD, D : LongInt;
 Ax, Ay, Bx, By, Cx, Cy, Dx, Dy : LongInt;
 Function Side(X1, Y1, X2, Y2, Px, Py: LongInt): LongInt;
 Begin
  Side := (X2 - X1) * (Py - Y1) - (Y2 - Y1) * (Px - X1);
 End;
 Function InTri(X1, Y1, X2, Y2, X3, Y3: LongInt): Boolean;
 Var S1, S2, S3: LongInt;
 Begin
  S1 := Side(X1, Y1, X2, Y2, X, Y);
  S2 := Side(X2, Y2, X3, Y3, X, Y);
  S3 := Side(X3, Y3, X1, Y1, X, Y);
  InTri := ((S1 >= 0) And (S2 >= 0) And (S3 >= 0)) Or
           ((S1 <= 0) And (S2 <= 0) And (S3 <= 0));
 End;
Begin
 PickGeom := -1;
 If MeshDirty Then BuildMesh;
 ProjectAll;
 X := Mx - VX1; Y := My - VY1;
 Best := -1; BestD := 2000000000;
 For Q := 0 To NQ - 1 Do Begin
  Ax := PSX^[MQ^[Q].A]; Ay := PSY^[MQ^[Q].A];
  Bx := PSX^[MQ^[Q].B]; By := PSY^[MQ^[Q].B];
  Cx := PSX^[MQ^[Q].C]; Cy := PSY^[MQ^[Q].C];
  Dx := PSX^[MQ^[Q].D]; Dy := PSY^[MQ^[Q].D];
  If (X < MinI(MinI(Ax, Bx), MinI(Cx, Dx))) Or (X > MaxI(MaxI(Ax, Bx), MaxI(Cx, Dx))) Or
     (Y < MinI(MinI(Ay, By), MinI(Cy, Dy))) Or (Y > MaxI(MaxI(Ay, By), MaxI(Cy, Dy))) Then Continue;
  If InTri(Ax, Ay, Bx, By, Cx, Cy) Or InTri(Ax, Ay, Cx, Cy, Dx, Dy) Then Begin
   D := (PSZ^[MQ^[Q].A] + PSZ^[MQ^[Q].B] + PSZ^[MQ^[Q].C] + PSZ^[MQ^[Q].D]) Div 4;
   If D < BestD Then Begin BestD := D; Best := MQ^[Q].G; End;
  End;
 End;
 PickGeom := Best;
End;

{ --------------------------------------------------------------------- }
{ Barre d'etat                                                           }
{ --------------------------------------------------------------------- }

Procedure DrawStatusBar;
Var S, S2: String;
Begin
 SetFillStyle(SolidFill, LightGray);
 Bar(0, ScreenHeight - STATUS_H, ScreenWidth - 1, ScreenHeight - 1);
 SetColor(White);
 Line(0, ScreenHeight - STATUS_H, ScreenWidth - 1, ScreenHeight - STATUS_H);
 SetColor(Black);
 If StatusMsg <> '' Then S := StatusMsg
 Else If (Sel >= 0) And (Sel < GeomCount) Then
  S := Geoms^[Sel].Name + ' (' + KindName(Geoms^[Sel].Kind) + ')  X=' +
       F2(Geoms^[Sel].X) + ' Y=' + F2(Geoms^[Sel].Y) + ' Z=' + F2(Geoms^[Sel].Z)
 Else S := 'Pret';
 If Modified Then S := S + ' *';
 OutTextXY(6, ScreenHeight - STATUS_H + 7, Copy(S, 1, 56));
 S2 := IntToStr(NQ) + ' facettes  Rez:' + IntToStr(EffRes);
 SetColor(DarkGray);
 OutTextXY(ScreenWidth - 8 * Length(S2) - 6, ScreenHeight - STATUS_H + 7, S2);
End;

Procedure RedrawAll;
Begin
 If MeshDirty Then BuildMesh;
 HideMouseCursor;
 DrawMenuBar;
 DrawToolbar;
 DrawPanel;
 DrawStatusBar;
 ShowMouseCursor;
 DrawScene(False);
 If MenuActive Then Begin
  HideMouseCursor;
  MenuSaveBG(ActiveMenu);
  DrawMenuPopup(ActiveMenu);
  ShowMouseCursor;
 End;
 NeedAll := False; NeedView := False; NeedPanel := False;
End;

{ --------------------------------------------------------------------- }
{ Boites de dialogue                                                     }
{ --------------------------------------------------------------------- }

Procedure FlushKeys;
Var K: Char;
Begin
 While KeyPressed Do Begin
  K := ReadKey;
  If K = #0 Then If KeyPressed Then K := ReadKey;
 End;
End;

Procedure WaitMouseRelease;
Begin
 Repeat
  GetMouseLocal(MouseX, MouseY, MouseButtons);
  If (MouseButtons And 1) = 0 Then Break;
  Delay(10);
 Until False;
 OldMouseButtons := 0;
End;

Procedure DrawDialogBox(X1, Y1, X2, Y2: Integer; Const Title: String);
Begin
 SetFillStyle(SolidFill, LightGray);
 Bar(X1, Y1, X2, Y2);
 SetColor(White);
 Rectangle(X1, Y1, X2, Y2);
 SetColor(DarkGray);
 Rectangle(X1 + 1, Y1 + 1, X2 - 1, Y2 - 1);
 SetFillStyle(SolidFill, Blue);
 Bar(X1 + 2, Y1 + 2, X2 - 2, Y1 + 16);
 SetColor(White);
 OutTextXY(X1 + 6, Y1 + 6, Title);
 SetColor(Black);
End;

{ Les lignes d'un message sont separees par '|' }
Procedure ShowMessage(Const Title, Msg: String);
Var
 X1, Y1, X2, Y2, W, H, N, I, P, MW : Integer;
 L : Array[1..12] Of String[70];
 S : String;
 K : Char;
Begin
 N := 0; S := Msg; MW := TextWidth(Title);
 While (S <> '') And (N < 12) Do Begin
  P := Pos('|', S);
  Inc(N);
  If P = 0 Then Begin L[N] := Copy(S, 1, 70); S := ''; End
  Else Begin L[N] := Copy(S, 1, P - 1); S := Copy(S, P + 1, 255); End;
  If TextWidth(L[N]) > MW Then MW := TextWidth(L[N]);
 End;
 W := MW + 40; If W < 220 Then W := 220;
 H := 60 + N * 12;
 X1 := (ScreenWidth - W) Div 2; Y1 := (ScreenHeight - H) Div 2;
 X2 := X1 + W; Y2 := Y1 + H;
 HideMouseCursor;
 DrawDialogBox(X1, Y1, X2, Y2, Title);
 For I := 1 To N Do OutTextXY(X1 + 20, Y1 + 26 + (I - 1) * 12, L[I]);
 DrawButton(X1 + W Div 2 - 28, Y2 - 26, X1 + W Div 2 + 28, Y2 - 8, 'OK', False);
 ShowMouseCursor;
 WaitMouseRelease;
 FlushKeys;
 Repeat
  If KeyPressed Then Begin
   K := ReadKey;
   If K = #0 Then Begin If KeyPressed Then ReadKey; End
   Else If (K = #13) Or (K = #27) Or (K = ' ') Then Break;
  End;
  GetMouseLocal(MouseX, MouseY, MouseButtons);
  If ((MouseButtons And 1) <> 0) And ((OldMouseButtons And 1) = 0) Then Begin
   If (MouseX >= X1 + W Div 2 - 28) And (MouseX <= X1 + W Div 2 + 28) And
      (MouseY >= Y2 - 26) And (MouseY <= Y2 - 8) Then Break;
  End;
  OldMouseButtons := MouseButtons;
  Delay(15);
 Until False;
 WaitMouseRelease;
 NeedAll := True;
End;

Function Confirm(Const Title, Msg: String): Boolean;
Var
 X1, Y1, X2, Y2, W : Integer;
 K : Char;
 Done, Res2 : Boolean;
Begin
 W := TextWidth(Msg) + 40; If W < 260 Then W := 260;
 X1 := (ScreenWidth - W) Div 2; Y1 := (ScreenHeight - 90) Div 2;
 X2 := X1 + W; Y2 := Y1 + 90;
 HideMouseCursor;
 DrawDialogBox(X1, Y1, X2, Y2, Title);
 OutTextXY(X1 + 20, Y1 + 30, Msg);
 DrawButton(X1 + W Div 2 - 70, Y2 - 28, X1 + W Div 2 - 10, Y2 - 8, 'Oui', False);
 DrawButton(X1 + W Div 2 + 10, Y2 - 28, X1 + W Div 2 + 70, Y2 - 8, 'Non', False);
 ShowMouseCursor;
 WaitMouseRelease;
 FlushKeys;
 Done := False; Res2 := False;
 Repeat
  If KeyPressed Then Begin
   K := ReadKey;
   If K = #0 Then Begin If KeyPressed Then ReadKey; End
   Else If (K = #13) Or (UpCase(K) = 'O') Or (UpCase(K) = 'Y') Then Begin
    Done := True; Res2 := True;
   End
   Else If (K = #27) Or (UpCase(K) = 'N') Then Done := True;
  End;
  GetMouseLocal(MouseX, MouseY, MouseButtons);
  If ((MouseButtons And 1) <> 0) And ((OldMouseButtons And 1) = 0) And
     (MouseY >= Y2 - 28) And (MouseY <= Y2 - 8) Then Begin
   If (MouseX >= X1 + W Div 2 - 70) And (MouseX <= X1 + W Div 2 - 10) Then Begin
    Done := True; Res2 := True;
   End
   Else If (MouseX >= X1 + W Div 2 + 10) And (MouseX <= X1 + W Div 2 + 70) Then
    Done := True;
  End;
  OldMouseButtons := MouseButtons;
  Delay(15);
 Until Done;
 WaitMouseRelease;
 NeedAll := True;
 Confirm := Res2;
End;

Function InputString(Const Title, Prompt: String; Var Value: String): Boolean;
Var
 X1, Y1, X2, Y2, W : Integer;
 K : Char;
 Done, OK, First : Boolean;
Begin
 W := 400;
 X1 := (ScreenWidth - W) Div 2; Y1 := (ScreenHeight - 110) Div 2;
 X2 := X1 + W; Y2 := Y1 + 110;
 HideMouseCursor;
 DrawDialogBox(X1, Y1, X2, Y2, Title);
 OutTextXY(X1 + 15, Y1 + 28, Prompt);
 DrawButton(X1 + W Div 2 - 70, Y2 - 28, X1 + W Div 2 - 10, Y2 - 8, 'OK', False);
 DrawButton(X1 + W Div 2 + 10, Y2 - 28, X1 + W Div 2 + 70, Y2 - 8, 'Annuler', False);
 ShowMouseCursor;
 WaitMouseRelease;
 FlushKeys;
 Done := False; OK := False; First := True;
 While Not Done Do Begin
  HideMouseCursor;
  SetFillStyle(SolidFill, White);
  Bar(X1 + 15, Y1 + 44, X2 - 15, Y1 + 62);
  SetColor(Black);
  Rectangle(X1 + 14, Y1 + 43, X2 - 14, Y1 + 63);
  If First Then Begin
   SetFillStyle(SolidFill, Blue);
   Bar(X1 + 17, Y1 + 47, X1 + 19 + TextWidth(Value), Y1 + 59);
   SetColor(White);
  End;
  OutTextXY(X1 + 18, Y1 + 49, Copy(Value + '_', 1, 44));
  ShowMouseCursor;
  Repeat
   GetMouseLocal(MouseX, MouseY, MouseButtons);
   If ((MouseButtons And 1) <> 0) And ((OldMouseButtons And 1) = 0) And
      (MouseY >= Y2 - 28) And (MouseY <= Y2 - 8) Then Begin
    If (MouseX >= X1 + W Div 2 - 70) And (MouseX <= X1 + W Div 2 - 10) Then Begin
     Done := True; OK := True;
    End
    Else If (MouseX >= X1 + W Div 2 + 10) And (MouseX <= X1 + W Div 2 + 70) Then
     Done := True;
   End;
   OldMouseButtons := MouseButtons;
   If Done Then Break;
   Delay(10);
  Until KeyPressed;
  If Done Then Break;
  K := ReadKey;
  If K = #0 Then ReadKey
  Else If K = #13 Then Begin Done := True; OK := True; End
  Else If K = #27 Then Done := True
  Else If K = #8 Then Begin
   If First Then Value := ''
   Else If Length(Value) > 0 Then Delete(Value, Length(Value), 1);
   First := False;
  End
  Else If (K >= ' ') And (Length(Value) < 60) Then Begin
   If First Then Value := '';
   Value := Value + K;
   First := False;
  End;
 End;
 WaitMouseRelease;
 NeedAll := True;
 InputString := OK;
End;

Function InputReal(Const Title, Prompt: String; Var V: Real): Boolean;
Var S: String; R: Real;
Begin
 S := RealToStr(V, 3);
 While (Length(S) > 1) And (S[Length(S)] = '0') And (Pos('.', S) > 0) Do
  Delete(S, Length(S), 1);
 If (Length(S) > 0) And (S[Length(S)] = '.') Then Delete(S, Length(S), 1);
 InputReal := False;
 If InputString(Title, Prompt, S) Then
  If ParseReal(S, R) Then Begin V := R; InputReal := True; End
  Else ShowMessage('Erreur', 'Valeur numerique invalide');
End;

{$IFDEF FULL}
{ --------------------------------------------------------------------- }
{ Selecteur de fichiers                                                  }
{ --------------------------------------------------------------------- }

Const
 FD_MAX = 120;

Var
 FDName : Array[0..FD_MAX-1] Of String[12];
 FDDir  : Array[0..FD_MAX-1] Of Boolean;
 FDN    : Integer;

Procedure FDScan(Const Ext: String);
Var
 SR : SearchRec;
 I, J : Integer;
 Nm : String;
 T : String[12];
 TD : Boolean;
Begin
 FDN := 0;
 FindFirst('*.*', AnyFile, SR);
 While (DosError = 0) And (FDN < FD_MAX) Do Begin
  Nm := SR.Name;
  If (SR.Attr And Directory) <> 0 Then Begin
   If Nm <> '.' Then Begin
    FDName[FDN] := Nm; FDDir[FDN] := True; Inc(FDN);
   End;
  End
  Else If (Ext = '') Or (Pos('.' + Ext, UpStr(Nm)) = Length(Nm) - Length(Ext)) Then Begin
   FDName[FDN] := Nm; FDDir[FDN] := False; Inc(FDN);
  End;
  FindNext(SR);
 End;
 { tri : dossiers d'abord puis ordre alphabetique }
 For I := 0 To FDN - 2 Do
  For J := I + 1 To FDN - 1 Do
   If (FDDir[J] And Not FDDir[I]) Or
      ((FDDir[J] = FDDir[I]) And (UpStr(FDName[J]) < UpStr(FDName[I]))) Then Begin
    T := FDName[I]; FDName[I] := FDName[J]; FDName[J] := T;
    TD := FDDir[I]; FDDir[I] := FDDir[J]; FDDir[J] := TD;
   End;
End;

Function FileDialog(Const Title, Ext: String; Var FN: String): Boolean;
Const
 ROWS = 12;
Var
 X1, Y1, X2, Y2, W : Integer;
 Top, SelI, I, Y, LastClick : Integer;
 K : Char;
 Done, OK, Redraw, First : Boolean;
 Cwd : String;
 Tick, ClickTick : LongInt;
 Hit : Integer;
Begin
 W := 420;
 X1 := (ScreenWidth - W) Div 2; Y1 := 60;
 X2 := X1 + W; Y2 := Y1 + 330;
 FDScan(Ext);
 Top := 0; SelI := 0; OK := False; Done := False; Redraw := True; First := True;
 Tick := 0; ClickTick := -1000; LastClick := -1;
 WaitMouseRelease;
 FlushKeys;
 While Not Done Do Begin
  If Redraw Then Begin
   HideMouseCursor;
   GetDir(0, Cwd);
   DrawDialogBox(X1, Y1, X2, Y2, Title);
   SetColor(Black);
   OutTextXY(X1 + 12, Y1 + 24, 'Dossier: ' + Copy(Cwd, 1, 44));
   SetFillStyle(SolidFill, White);
   Bar(X1 + 12, Y1 + 40, X2 - 12, Y1 + 40 + ROWS * 14 + 2);
   DrawBevel(X1 + 11, Y1 + 39, X2 - 11, Y1 + 40 + ROWS * 14 + 3, True);
   For I := Top To MinI(FDN - 1, Top + ROWS - 1) Do Begin
    Y := Y1 + 42 + (I - Top) * 14;
    If I = SelI Then Begin
     SetFillStyle(SolidFill, Blue);
     Bar(X1 + 14, Y, X2 - 14, Y + 13);
     SetColor(White);
    End
    Else SetColor(Black);
    If FDDir[I] Then OutTextXY(X1 + 18, Y + 3, '[' + FDName[I] + ']')
    Else OutTextXY(X1 + 18, Y + 3, FDName[I]);
   End;
   SetColor(Black);
   OutTextXY(X1 + 12, Y2 - 62, 'Nom:');
   SetFillStyle(SolidFill, White);
   Bar(X1 + 48, Y2 - 66, X2 - 12, Y2 - 50);
   DrawBevel(X1 + 47, Y2 - 67, X2 - 11, Y2 - 49, True);
   SetColor(Black);
   OutTextXY(X1 + 52, Y2 - 62, Copy(FN + '_', 1, 42));
   DrawButton(X1 + W Div 2 - 70, Y2 - 30, X1 + W Div 2 - 10, Y2 - 10, 'OK', False);
   DrawButton(X1 + W Div 2 + 10, Y2 - 30, X1 + W Div 2 + 70, Y2 - 10, 'Annuler', False);
   ShowMouseCursor;
   Redraw := False;
  End;
  Inc(Tick);
  GetMouseLocal(MouseX, MouseY, MouseButtons);
  If ((MouseButtons And 1) <> 0) And ((OldMouseButtons And 1) = 0) Then Begin
   If (MouseX >= X1 + 14) And (MouseX <= X2 - 14) And
      (MouseY >= Y1 + 42) And (MouseY < Y1 + 42 + ROWS * 14) Then Begin
    Hit := Top + (MouseY - Y1 - 42) Div 14;
    If Hit < FDN Then Begin
     If (Hit = LastClick) And (Tick - ClickTick < 25) Then Begin
      K := #13;
      SelI := Hit;
      If FDDir[SelI] Then Begin
       ChDir(FDName[SelI]); FDScan(Ext); Top := 0; SelI := 0;
      End
      Else Begin FN := FDName[SelI]; OK := True; Done := True; End;
     End
     Else Begin
      SelI := Hit;
      If Not FDDir[SelI] Then Begin FN := FDName[SelI]; First := True; End;
     End;
     LastClick := Hit; ClickTick := Tick;
     Redraw := True;
    End;
   End
   Else If (MouseY >= Y2 - 30) And (MouseY <= Y2 - 10) Then Begin
    If (MouseX >= X1 + W Div 2 - 70) And (MouseX <= X1 + W Div 2 - 10) Then Begin
     OK := FN <> ''; Done := True;
    End
    Else If (MouseX >= X1 + W Div 2 + 10) And (MouseX <= X1 + W Div 2 + 70) Then
     Done := True;
   End;
  End;
  OldMouseButtons := MouseButtons;
  If KeyPressed Then Begin
   K := ReadKey;
   Redraw := True;
   If K = #0 Then Begin
    K := ReadKey;
    Case K Of
     #72: If SelI > 0 Then Dec(SelI);
     #80: If SelI < FDN - 1 Then Inc(SelI);
     #73: SelI := MaxI(0, SelI - ROWS);
     #81: SelI := MinI(FDN - 1, SelI + ROWS);
     #71: SelI := 0;
     #79: SelI := FDN - 1;
    End;
    If (SelI >= 0) And (SelI < FDN) And Not FDDir[SelI] Then Begin
     FN := FDName[SelI]; First := True;
    End;
   End
   Else If K = #13 Then Begin
    If (FN <> '') And ((SelI >= FDN) Or (Not FDDir[SelI]) Or
       (FN <> FDName[SelI])) Then Begin OK := True; Done := True; End
    Else If (SelI < FDN) And FDDir[SelI] Then Begin
     ChDir(FDName[SelI]); FDScan(Ext); Top := 0; SelI := 0;
    End;
   End
   Else If K = #27 Then Done := True
   Else If K = #8 Then Begin
    If First Then FN := ''
    Else If Length(FN) > 0 Then Delete(FN, Length(FN), 1);
    First := False;
   End
   Else If (K >= ' ') And (Length(FN) < 60) Then Begin
    If First Then FN := '';
    FN := FN + K;
    First := False;
   End;
  End;
  If SelI < Top Then Top := SelI;
  If SelI >= Top + ROWS Then Top := SelI - ROWS + 1;
  Delay(15);
 End;
 WaitMouseRelease;
 NeedAll := True;
 FileDialog := OK;
End;

{$ELSE}
Function FileDialog(Const Title, Ext: String; Var FN: String): Boolean;
Begin
 FileDialog := InputString(Title, 'Nom du fichier (.' + Ext + ') :', FN);
End;

{$ENDIF}
{ --------------------------------------------------------------------- }
{ Rapport texte                                                          }
{ --------------------------------------------------------------------- }

Procedure RepClear;
Begin RepN := 0; End;

Procedure RepAdd(Const S: String);
Begin
 If RepN < MAX_REP Then Begin
  Rep[RepN] := Copy(S, 1, 78);
  Inc(RepN);
 End;
End;

Procedure RepSave(Const FN: String);
Var F: Text; I: Integer;
Begin
 {$I-}
 Assign(F, FN);
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Begin ShowMessage('Erreur', 'Ecriture impossible'); Exit; End;
 For I := 0 To RepN - 1 Do WriteLn(F, Rep[I]);
 Close(F);
End;

Procedure ShowReport(Const Title: String);
Var
 X1, Y1, X2, Y2, W, H, Rows, Top, I : Integer;
 K : Char;
 Done, Redraw : Boolean;
 FN : String;
Begin
 W := 616; H := 440;
 X1 := (ScreenWidth - W) Div 2; Y1 := (ScreenHeight - H) Div 2;
 X2 := X1 + W; Y2 := Y1 + H;
 Rows := (H - 66) Div 11;
 Top := 0; Done := False; Redraw := True;
 WaitMouseRelease;
 FlushKeys;
 While Not Done Do Begin
  If Redraw Then Begin
   HideMouseCursor;
   DrawDialogBox(X1, Y1, X2, Y2, Title);
   SetFillStyle(SolidFill, Black);
   Bar(X1 + 8, Y1 + 22, X2 - 8, Y1 + 24 + Rows * 11);
   SetColor(LightGreen);
   For I := Top To MinI(RepN - 1, Top + Rows - 1) Do
    OutTextXY(X1 + 12, Y1 + 25 + (I - Top) * 11, Rep[I]);
   DrawButton(X1 + 20, Y2 - 26, X1 + 150, Y2 - 8, 'Enregistrer .TXT', False);
   DrawButton(X2 - 100, Y2 - 26, X2 - 20, Y2 - 8, 'Fermer', False);
   SetColor(Black);
   OutTextXY(X1 + 170, Y2 - 22, IntToStr(Top + 1) + '/' + IntToStr(MaxI(RepN, 1)));
   ShowMouseCursor;
   Redraw := False;
  End;
  GetMouseLocal(MouseX, MouseY, MouseButtons);
  If ((MouseButtons And 1) <> 0) And ((OldMouseButtons And 1) = 0) And
     (MouseY >= Y2 - 26) And (MouseY <= Y2 - 8) Then Begin
   If (MouseX >= X2 - 100) And (MouseX <= X2 - 20) Then Done := True
   Else If (MouseX >= X1 + 20) And (MouseX <= X1 + 150) Then Begin
    WaitMouseRelease;
    FN := 'RAPPORT.TXT';
    If InputString('Enregistrer le rapport', 'Nom du fichier :', FN) Then RepSave(FN);
    Redraw := True;
    NeedAll := False;
   End;
  End;
  OldMouseButtons := MouseButtons;
  If KeyPressed Then Begin
   K := ReadKey;
   If K = #0 Then Begin
    K := ReadKey;
    Case K Of
     #72: Top := MaxI(0, Top - 1);
     #80: Top := MaxI(0, MinI(RepN - Rows, Top + 1));
     #73: Top := MaxI(0, Top - Rows);
     #81: Top := MaxI(0, MinI(RepN - Rows, Top + Rows));
     #71: Top := 0;
     #79: Top := MaxI(0, RepN - Rows);
    End;
    Redraw := True;
   End
   Else If (K = #27) Or (K = #13) Then Done := True;
  End;
  Delay(15);
 End;
 WaitMouseRelease;
 NeedAll := True;
End;

{$IFDEF FULL}
{ --------------------------------------------------------------------- }
{ Graphique de polaires                                                  }
{ --------------------------------------------------------------------- }

Procedure PlotAxes(X1, Y1, X2, Y2: Integer; Const Title, XL, YL: String;
                   XMin, XMax, YMin, YMax: Real);
Var
 I, PX, PY : Integer;
Begin
 SetFillStyle(SolidFill, Black);
 Bar(X1, Y1, X2, Y2);
 SetColor(White);
 Rectangle(X1, Y1, X2, Y2);
 SetColor(DarkGray);
 For I := 1 To 4 Do Begin
  PX := X1 + I * (X2 - X1) Div 5;
  PY := Y1 + I * (Y2 - Y1) Div 5;
  Line(PX, Y1 + 1, PX, Y2 - 1);
  Line(X1 + 1, PY, X2 - 1, PY);
 End;
 If (YMin < 0) And (YMax > 0) Then Begin
  PY := Y2 - Round((0 - YMin) / (YMax - YMin) * (Y2 - Y1));
  SetColor(LightGray); Line(X1 + 1, PY, X2 - 1, PY);
 End;
 If (XMin < 0) And (XMax > 0) Then Begin
  PX := X1 + Round((0 - XMin) / (XMax - XMin) * (X2 - X1));
  SetColor(LightGray); Line(PX, Y1 + 1, PX, Y2 - 1);
 End;
 SetColor(Yellow);
 OutTextXY(X1 + 4, Y1 - 11, Title);
 SetColor(LightGray);
 OutTextXY(X1, Y2 + 3, RealToStr(XMin, 1));
 OutTextXY(X2 - 8 * Length(RealToStr(XMax, 1)), Y2 + 3, RealToStr(XMax, 1));
 OutTextXY((X1 + X2) Div 2 - 4 * Length(XL), Y2 + 3, XL);
 OutTextXY(X1 + 3, Y1 + 3, RealToStr(YMax, 2));
 OutTextXY(X1 + 3, Y2 - 11, RealToStr(YMin, 2));
 OutTextXY(X1 + 3, (Y1 + Y2) Div 2 - 4, YL);
End;

Procedure PlotCurve(X1, Y1, X2, Y2: Integer; Var XS, YS: Array Of Real; N: Integer;
                    XMin, XMax, YMin, YMax: Real; Col: Word);
Var I, PX, PY, OX, OY: Integer;
Begin
 SetColor(Col);
 OX := 0; OY := 0;
 For I := 0 To N - 1 Do Begin
  PX := X1 + ToInt((XS[I] - XMin) / (XMax - XMin) * (X2 - X1));
  PY := Y2 - ToInt((YS[I] - YMin) / (YMax - YMin) * (Y2 - Y1));
  If PY < Y1 Then PY := Y1;
  If PY > Y2 Then PY := Y2;
  If PX < X1 Then PX := X1;
  If PX > X2 Then PX := X2;
  If I > 0 Then Line(OX, OY, PX, PY);
  Circle(PX, PY, 1);
  OX := PX; OY := PY;
 End;
End;

Procedure ShowPolar;
Var
 X1, Y1, X2, Y2, W, H, I : Integer;
 CLmin, CLmax, CDmax, LDmax : Real;
 LDa : Array[0..30] Of Real;
 Done : Boolean;
 K : Char;
 PX1, PX2, PY1, PY2 : Integer;
 AMin, AMax, LMin, LMax : Real;
Begin
 If Not PolOK Then Exit;
 W := 616; H := 440;
 X1 := (ScreenWidth - W) Div 2; Y1 := (ScreenHeight - H) Div 2;
 X2 := X1 + W; Y2 := Y1 + H;
 CLmin := PolCL[0]; CLmax := PolCL[0]; CDmax := PolCD[0]; LDmax := 1;
 For I := 0 To PolN - 1 Do Begin
  If PolCL[I] < CLmin Then CLmin := PolCL[I];
  If PolCL[I] > CLmax Then CLmax := PolCL[I];
  If PolCD[I] > CDmax Then CDmax := PolCD[I];
  LDa[I] := PolCL[I] / PolCD[I];
  If LDa[I] > LDmax Then LDmax := LDa[I];
 End;
 LMin := 0;
 For I := 0 To PolN - 1 Do If LDa[I] < LMin Then LMin := LDa[I];
 LMax := Int(LDmax / 5 + 1) * 5;
 AMin := PolA[0]; AMax := PolA[PolN - 1];
 CLmin := Int(CLmin * 5 - 1) / 5; CLmax := Int(CLmax * 5 + 1) / 5;
 CDmax := Int(CDmax * 100 + 1) / 100;
 HideMouseCursor;
 DrawDialogBox(X1, Y1, X2, Y2, 'Polaires aerodynamiques (ligne portante)');
 { Courbe CL / alpha }
 PX1 := X1 + 40; PX2 := X1 + 290; PY1 := Y1 + 40; PY2 := Y1 + 190;
 PlotAxes(PX1, PY1, PX2, PY2, 'CL = f(alpha)', 'alpha', 'CL', AMin, AMax, CLmin, CLmax);
 PlotCurve(PX1, PY1, PX2, PY2, PolA, PolCL, PolN, AMin, AMax, CLmin, CLmax, LightGreen);
 { Polaire CL / CD }
 PX1 := X1 + 350; PX2 := X1 + 590;
 PlotAxes(PX1, PY1, PX2, PY2, 'Polaire CL = f(CD)', 'CD', 'CL', 0, CDmax, CLmin, CLmax);
 PlotCurve(PX1, PY1, PX2, PY2, PolCD, PolCL, PolN, 0, CDmax, CLmin, CLmax, LightCyan);
 { Finesse }
 PX1 := X1 + 40; PX2 := X1 + 290; PY1 := Y1 + 235; PY2 := Y1 + 360;
 PlotAxes(PX1, PY1, PX2, PY2, 'Finesse L/D = f(alpha)', 'alpha', 'L/D', AMin, AMax, LMin, LMax);
 PlotCurve(PX1, PY1, PX2, PY2, PolA, LDa, PolN, AMin, AMax, LMin, LMax, Yellow);
 { Resume }
 SetColor(Black);
 OutTextXY(X1 + 330, Y1 + 220, 'Sref   = ' + F2(PolSref) + ' m2');
 OutTextXY(X1 + 330, Y1 + 232, 'bref   = ' + F2(PolBref) + ' m');
 OutTextXY(X1 + 330, Y1 + 244, 'AR     = ' + F2(PolAR));
 OutTextXY(X1 + 330, Y1 + 256, 'CLalpha= ' + F3(PolCLa) + ' /deg');
 OutTextXY(X1 + 330, Y1 + 268, 'alpha0 = ' + F2(PolAlpha0) + ' deg');
 OutTextXY(X1 + 330, Y1 + 280, 'e      = ' + F3(PolE));
 OutTextXY(X1 + 330, Y1 + 292, 'CD0    = ' + F4(PolCD0));
 OutTextXY(X1 + 330, Y1 + 304, 'L/D max= ' + F1(LDmax));
 OutTextXY(X1 + 330, Y1 + 316, 'Alt=' + F1(FlAlt) + ' m  Mach=' + F3(FlMach));
 DrawButton(X2 - 100, Y2 - 26, X2 - 20, Y2 - 8, 'Fermer', False);
 ShowMouseCursor;
 WaitMouseRelease;
 FlushKeys;
 Done := False;
 While Not Done Do Begin
  GetMouseLocal(MouseX, MouseY, MouseButtons);
  If ((MouseButtons And 1) <> 0) And ((OldMouseButtons And 1) = 0) And
     (MouseX >= X2 - 100) And (MouseX <= X2 - 20) And
     (MouseY >= Y2 - 26) And (MouseY <= Y2 - 8) Then Done := True;
  OldMouseButtons := MouseButtons;
  If KeyPressed Then Begin
   K := ReadKey;
   If K = #0 Then ReadKey Else If (K = #27) Or (K = #13) Then Done := True;
  End;
  Delay(15);
 End;
 WaitMouseRelease;
 NeedAll := True;
End;
{$ENDIF}

{$IFDEF FULL}
{ --------------------------------------------------------------------- }
{ Integration sur le maillage : surface mouillee, volume, centroides      }
{ --------------------------------------------------------------------- }

Type
 TInteg = Record
  Area, Vol, Vx, Vy, Vz, Ax, Ay, Az : Real;
  Sxx, Syy, Szz, Sxy, Sxz, Syz : Real;
 End;

Procedure ZeroInteg(Var R: TInteg);
Begin
 FillChar(R, SizeOf(R), 0);
End;

Procedure AccTri(Var R: TInteg; X1, Y1, Z1, X2, Y2, Z2, X3, Y3, Z3: Real;
                 AddArea: Boolean);
Var
 Ux, Uy, Uz, Wx, Wy, Wz, Nx, Ny, Nz, A, Vl, Cx, Cy, Cz : Real;
Begin
 Vl := (X1 * (Y2 * Z3 - Z2 * Y3) - Y1 * (X2 * Z3 - Z2 * X3)
        + Z1 * (X2 * Y3 - Y2 * X3)) / 6.0;
 R.Vol := R.Vol + Vl;
 R.Vx := R.Vx + Vl * (X1 + X2 + X3) / 4.0;
 R.Vy := R.Vy + Vl * (Y1 + Y2 + Y3) / 4.0;
 R.Vz := R.Vz + Vl * (Z1 + Z2 + Z3) / 4.0;
 If Not AddArea Then Exit;
 Ux := X2 - X1; Uy := Y2 - Y1; Uz := Z2 - Z1;
 Wx := X3 - X1; Wy := Y3 - Y1; Wz := Z3 - Z1;
 Nx := Uy * Wz - Uz * Wy; Ny := Uz * Wx - Ux * Wz; Nz := Ux * Wy - Uy * Wx;
 A := 0.5 * Sqrt(Nx * Nx + Ny * Ny + Nz * Nz);
 Cx := (X1 + X2 + X3) / 3.0; Cy := (Y1 + Y2 + Y3) / 3.0; Cz := (Z1 + Z2 + Z3) / 3.0;
 R.Area := R.Area + A;
 R.Ax := R.Ax + A * Cx; R.Ay := R.Ay + A * Cy; R.Az := R.Az + A * Cz;
 R.Sxx := R.Sxx + A * Cx * Cx; R.Syy := R.Syy + A * Cy * Cy;
 R.Szz := R.Szz + A * Cz * Cz; R.Sxy := R.Sxy + A * Cx * Cy;
 R.Sxz := R.Sxz + A * Cx * Cz; R.Syz := R.Syz + A * Cy * Cz;
End;

Procedure LoadRingW(GI, BP: Integer; Mir: Boolean; I, NU, NVv: Integer;
                    Var XA, YA, ZA: Array Of Real);
Var J: Integer; X, Y, Z: Real;
Begin
 PrepRing(Geoms^[GI], BP, I, NU);
 For J := 0 To NVv - 1 Do Begin
  RingPoint(Geoms^[GI], BP, J, NVv, X, Y, Z);
  ToWorld(GI, Mir, X, Y, Z);
  XA[J] := X; YA[J] := Y; ZA[J] := Z;
 End;
End;

Procedure IntegratePart(GI, P: Integer; Var R: TInteg);
Var
 NBase, BP, NU, NVv, I, J, J1, I1, J0 : Integer;
 Caps, Mir, RootCap : Boolean;
 Loc : TInteg;
 C0x, C0y, C0z, C1x, C1y, C1z, Cmx, Cmy, Cmz : Real;
 Ax, Ay, Az, Bx, By, Bz, Px, Py, Pz, Nx, Ny, Nz, S, Dx, Dy, Dz, Dot : Real;
Begin
 NBase := BasePartCount(Geoms^[GI]);
 If NBase = 0 Then Exit;
 BP := P Mod NBase;
 Mir := P >= NBase;
 PartDims(Geoms^[GI], BP, NU, NVv, Caps);
 If (NU < 2) Or (NVv < 3) Then Exit;
 ZeroInteg(Loc);
 RootCap := (Geoms^[GI].Kind = GT_WING) Or
            ((Geoms^[GI].Kind = GT_PROP) And (BP < Round(Geoms^[GI].NBlade)));
 { passe preliminaire : centroides et orientation }
 LoadRingW(GI, BP, Mir, 0, NU, NVv, RA, RB, RC);
 C0x := 0; C0y := 0; C0z := 0;
 For J := 0 To NVv - 1 Do Begin
  C0x := C0x + RA[J]; C0y := C0y + RB[J]; C0z := C0z + RC[J];
 End;
 C0x := C0x / NVv; C0y := C0y / NVv; C0z := C0z / NVv;
 LoadRingW(GI, BP, Mir, NU - 1, NU, NVv, RD, RE, RF);
 C1x := 0; C1y := 0; C1z := 0;
 For J := 0 To NVv - 1 Do Begin
  C1x := C1x + RD[J]; C1y := C1y + RE[J]; C1z := C1z + RF[J];
 End;
 C1x := C1x / NVv; C1y := C1y / NVv; C1z := C1z / NVv;
 I1 := (NU - 1) Div 2;
 If I1 >= NU - 1 Then I1 := NU - 2;
 J0 := NVv Div 4;
 J1 := (J0 + 1) Mod NVv;
 LoadRingW(GI, BP, Mir, I1, NU, NVv, RA, RB, RC);
 Cmx := 0; Cmy := 0; Cmz := 0;
 For J := 0 To NVv - 1 Do Begin
  Cmx := Cmx + RA[J]; Cmy := Cmy + RB[J]; Cmz := Cmz + RC[J];
 End;
 Cmx := Cmx / NVv; Cmy := Cmy / NVv; Cmz := Cmz / NVv;
 Ax := RA[J0]; Ay := RB[J0]; Az := RC[J0];
 Bx := RA[J1]; By := RB[J1]; Bz := RC[J1];
 LoadRingW(GI, BP, Mir, I1 + 1, NU, NVv, RD, RE, RF);
 Px := RD[J1]; Py := RE[J1]; Pz := RF[J1];
 Nx := (By - Ay) * (Pz - Az) - (Bz - Az) * (Py - Ay);
 Ny := (Bz - Az) * (Px - Ax) - (Bx - Ax) * (Pz - Az);
 Nz := (Bx - Ax) * (Py - Ay) - (By - Ay) * (Px - Ax);
 Dot := Nx * (Ax - Cmx) + Ny * (Ay - Cmy) + Nz * (Az - Cmz);
 If Dot >= 0 Then S := 1 Else S := -1;
 Dx := C1x - C0x; Dy := C1y - C0y; Dz := C1z - C0z;

 { passe principale }
 LoadRingW(GI, BP, Mir, 0, NU, NVv, RA, RB, RC);
 If Caps Then
  For J := 0 To NVv - 1 Do Begin
   J1 := (J + 1) Mod NVv;
   Nx := (RB[J] - C0y) * (RC[J1] - C0z) - (RC[J] - C0z) * (RB[J1] - C0y);
   Ny := (RC[J] - C0z) * (RA[J1] - C0x) - (RA[J] - C0x) * (RC[J1] - C0z);
   Nz := (RA[J] - C0x) * (RB[J1] - C0y) - (RB[J] - C0y) * (RA[J1] - C0x);
   Dot := Nx * Dx + Ny * Dy + Nz * Dz;
   If Dot * (-S) >= 0 Then
    AccTri(Loc, C0x, C0y, C0z, RA[J], RB[J], RC[J], RA[J1], RB[J1], RC[J1], Not RootCap)
   Else
    AccTri(Loc, C0x, C0y, C0z, RA[J1], RB[J1], RC[J1], RA[J], RB[J], RC[J], Not RootCap);
  End;
 For I := 1 To NU - 1 Do Begin
  LoadRingW(GI, BP, Mir, I, NU, NVv, RD, RE, RF);
  For J := 0 To NVv - 1 Do Begin
   J1 := (J + 1) Mod NVv;
   AccTri(Loc, RA[J], RB[J], RC[J], RA[J1], RB[J1], RC[J1], RD[J1], RE[J1], RF[J1], True);
   AccTri(Loc, RA[J], RB[J], RC[J], RD[J1], RE[J1], RF[J1], RD[J], RE[J], RF[J], True);
  End;
  For J := 0 To NVv - 1 Do Begin
   RA[J] := RD[J]; RB[J] := RE[J]; RC[J] := RF[J];
  End;
 End;
 If Caps Then
  For J := 0 To NVv - 1 Do Begin
   J1 := (J + 1) Mod NVv;
   Nx := (RB[J] - C1y) * (RC[J1] - C1z) - (RC[J] - C1z) * (RB[J1] - C1y);
   Ny := (RC[J] - C1z) * (RA[J1] - C1x) - (RA[J] - C1x) * (RC[J1] - C1z);
   Nz := (RA[J] - C1x) * (RB[J1] - C1y) - (RB[J] - C1y) * (RA[J1] - C1x);
   Dot := Nx * Dx + Ny * Dy + Nz * Dz;
   If Dot * S >= 0 Then
    AccTri(Loc, C1x, C1y, C1z, RA[J], RB[J], RC[J], RA[J1], RB[J1], RC[J1], True)
   Else
    AccTri(Loc, C1x, C1y, C1z, RA[J1], RB[J1], RC[J1], RA[J], RB[J], RC[J], True);
  End;
 If Loc.Vol < 0 Then Begin
  Loc.Vol := -Loc.Vol; Loc.Vx := -Loc.Vx; Loc.Vy := -Loc.Vy; Loc.Vz := -Loc.Vz;
 End;
 R.Area := R.Area + Loc.Area; R.Vol := R.Vol + Loc.Vol;
 R.Vx := R.Vx + Loc.Vx; R.Vy := R.Vy + Loc.Vy; R.Vz := R.Vz + Loc.Vz;
 R.Ax := R.Ax + Loc.Ax; R.Ay := R.Ay + Loc.Ay; R.Az := R.Az + Loc.Az;
 R.Sxx := R.Sxx + Loc.Sxx; R.Syy := R.Syy + Loc.Syy; R.Szz := R.Szz + Loc.Szz;
 R.Sxy := R.Sxy + Loc.Sxy; R.Sxz := R.Sxz + Loc.Sxz; R.Syz := R.Syz + Loc.Syz;
End;

Procedure IntegrateGeom(GI: Integer; Var R: TInteg);
Var P: Integer;
Begin
 ZeroInteg(R);
 ComputeXforms;
 EffRes := Res;
 If EffRes < 1 Then EffRes := 1;
 For P := 0 To PartCount(Geoms^[GI]) - 1 Do IntegratePart(GI, P, R);
End;

{$ENDIF}
{ --------------------------------------------------------------------- }
{ Statistiques d'aile                                                    }
{ --------------------------------------------------------------------- }

{ Planforme d'un panneau (demi-aile) : surface, envergure, MAC, fleche c/4 }
Procedure WingPlan(Var G: TGeom; Var Sh, Span, MAC, Taper, SweepC4, TipC: Real);
Var
 S, N : Integer;
 C0, C1, Sp, Sum2, Sm, X0, X1, Y1 : Real;
Begin
 N := Round(G.NSect);
 Sh := 0; Sp := 0; Sum2 := 0;
 C0 := G.RootChord; X0 := 0.25 * C0; Y1 := 0;
 X1 := X0; C1 := C0;
 Sm := 0;
 For S := 1 To N Do Begin
  C1 := G.STip[S];
  Sh := Sh + G.SSpan[S] * (C0 + C1) / 2;
  Sum2 := Sum2 + G.SSpan[S] * (C0 * C0 + C0 * C1 + C1 * C1) / 3;
  Sp := Sp + G.SSpan[S];
  Sm := Sm + G.SSpan[S] * Tan(G.SSweep[S] * DEG);
  { position c/4 au bout }
  X1 := X1 + G.SSpan[S] * Tan(G.SSweep[S] * DEG)
        + G.SweepLoc * (C0 - C1) + 0.25 * (C1 - C0);
  Y1 := Y1 + G.SSpan[S];
  C0 := C1;
 End;
 TipC := C1;
 If Sh > 1E-9 Then MAC := Sum2 / Sh Else MAC := G.RootChord;
 If G.RootChord > 1E-9 Then Taper := C1 / G.RootChord Else Taper := 1;
 If Y1 > 1E-9 Then SweepC4 := ArcTan((X1 - 0.25 * G.RootChord) / Y1) / DEG
 Else SweepC4 := 0;
 If G.Sym > 0.5 Then Span := 2 * Sp Else Span := Sp;
End;

{$IFDEF FULL}
Function WingArea(Var G: TGeom): Real;
Var Sh, Sp, M, T, Sw, Tc: Real;
Begin
 WingPlan(G, Sh, Sp, M, T, Sw, Tc);
 If G.Sym > 0.5 Then WingArea := 2 * Sh Else WingArea := Sh;
End;

Function MainWing: Integer;
Var I, B: Integer; A, BA: Real;
Begin
 B := -1; BA := 0;
 For I := 0 To GeomCount - 1 Do
  If Geoms^[I].Kind = GT_WING Then Begin
   A := WingArea(Geoms^[I]);
   If A > BA Then Begin BA := A; B := I; End;
  End;
 MainWing := B;
End;

{ Valeurs locales a la position Y (de la racine) }
Procedure WingAt(Var G: TGeom; Y: Real; Var C, Tw, A0L, Lam: Real);
Var
 S, N : Integer;
 Y0, C0, Tw0, Cm0, T, Sp, C1, Th : Real;
Begin
 N := Round(G.NSect);
 Y0 := 0; C0 := G.RootChord; Tw0 := G.Incid; Cm0 := G.Camber;
 S := 1;
 While (S < N) And (Y > Y0 + G.SSpan[S]) Do Begin
  Y0 := Y0 + G.SSpan[S]; C0 := G.STip[S]; Tw0 := G.Incid + G.STwist[S];
  Cm0 := G.SCamb[S];
  Inc(S);
 End;
 Sp := G.SSpan[S]; C1 := G.STip[S];
 T := (Y - Y0) / Sp;
 If T < 0 Then T := 0;
 If T > 1 Then T := 1;
 C := C0 + (C1 - C0) * T;
 Tw := Tw0 + (G.Incid + G.STwist[S] - Tw0) * T + G.RY;
 A0L := -1.04 * (Cm0 + (G.SCamb[S] - Cm0) * T);
 Th := Tan(G.SSweep[S] * DEG) + (G.SweepLoc - 0.25) * (C0 - C1) / Sp;
 Lam := ArcTan(Th);
 Cm0 := 0;
End;

{ Systeme lineaire n x (n+2) : elimination de Gauss avec pivot }
Procedure SolveSys(N: Integer; Var M: Array Of Real; Cols: Integer);
Var I, J, K, P: Integer; T, F: Real;
Begin
 For I := 0 To N - 1 Do Begin
  P := I;
  For J := I + 1 To N - 1 Do
   If Abs(M[J * Cols + I]) > Abs(M[P * Cols + I]) Then P := J;
  If P <> I Then
   For K := 0 To Cols - 1 Do Begin
    T := M[I * Cols + K]; M[I * Cols + K] := M[P * Cols + K]; M[P * Cols + K] := T;
   End;
  If Abs(M[I * Cols + I]) < 1E-14 Then M[I * Cols + I] := 1E-14;
  For J := I + 1 To N - 1 Do Begin
   F := M[J * Cols + I] / M[I * Cols + I];
   For K := I To Cols - 1 Do M[J * Cols + K] := M[J * Cols + K] - F * M[I * Cols + K];
  End;
 End;
 For K := N To Cols - 1 Do
  For I := N - 1 DownTo 0 Do Begin
   T := M[I * Cols + K];
   For J := I + 1 To N - 1 Do T := T - M[I * Cols + J] * M[J * Cols + K];
   M[I * Cols + K] := T / M[I * Cols + I];
  End;
End;

{$ENDIF}
{ --------------------------------------------------------------------- }
{ Rapports                                                               }
{ --------------------------------------------------------------------- }

{$IFDEF FULL}
Function Num(R: Real; Dec, W: Integer): String;
Begin
 Num := PadL(RealToStr(R, Dec), W);
End;

Procedure RepCompGeom;
Var
 G : Integer;
 R, T : TInteg;
 V : Real;
 Cnt : Integer;
Begin
 RepAdd('=== GEOMETRIE CALCULEE (CompGeom) ===');
 RepAdd('Modele : ' + ModelName);
 RepAdd('');
 RepAdd(PadR('Composant', 18) + PadR('Type', 9) + PadL('Swet m2', 10) + PadL('Vol m3', 10) +
        PadL('Xcg', 8) + PadL('Ycg', 8) + PadL('Zcg', 8));
 ZeroInteg(T);
 Cnt := 0;
 For G := 0 To GeomCount - 1 Do
  If Geoms^[G].Visible And (BasePartCount(Geoms^[G]) > 0) Then Begin
   IntegrateGeom(G, R);
   If R.Vol > 1E-9 Then
    RepAdd(PadR(Geoms^[G].Name, 18) + PadR(KindName(Geoms^[G].Kind), 9) +
           Num(R.Area, 3, 10) + Num(R.Vol, 3, 10) + Num(R.Vx / R.Vol, 2, 8) +
           Num(R.Vy / R.Vol, 2, 8) + Num(R.Vz / R.Vol, 2, 8))
   Else
    RepAdd(PadR(Geoms^[G].Name, 18) + PadR(KindName(Geoms^[G].Kind), 9) +
           Num(R.Area, 3, 10) + Num(R.Vol, 3, 10));
   T.Area := T.Area + R.Area; T.Vol := T.Vol + R.Vol;
   T.Vx := T.Vx + R.Vx; T.Vy := T.Vy + R.Vy; T.Vz := T.Vz + R.Vz;
   Inc(Cnt);
  End;
 RepAdd('-------------------------------------------------------------------');
 If T.Vol > 1E-9 Then V := T.Vol Else V := 1;
 RepAdd(PadR('TOTAL (' + IntToStr(Cnt) + ' composants)', 27) + Num(T.Area, 3, 10) +
        Num(T.Vol, 3, 10) + Num(T.Vx / V, 2, 8) + Num(T.Vy / V, 2, 8) + Num(T.Vz / V, 2, 8));
 RepAdd('');
 If NV > 0 Then Begin
  RepAdd('Boite englobante : L(x)=' + F2(BMaxX - BMinX) + '  B(y)=' + F2(BMaxY - BMinY) +
         '  H(z)=' + F2(BMaxZ - BMinZ) + ' m');
  RepAdd('X: ' + F2(BMinX) + ' .. ' + F2(BMaxX) + '   Y: ' + F2(BMinY) + ' .. ' + F2(BMaxY) +
         '   Z: ' + F2(BMinZ) + ' .. ' + F2(BMaxZ));
 End;
 RepAdd('Les surfaces sont integrees sur le maillage (resolution ' + IntToStr(EffRes) + ').');
 RepAdd('');
End;

Procedure RepMass;
Var
 G : Integer;
 R : TInteg;
 K, M, TM, Cx, Cy, Cz : Real;
 TXX, TYY, TZZ, TXY, TXZ, TYZ, TAx, TAy, TAz : Real;
 Ixx, Iyy, Izz, Ixz : Real;
Begin
 RepAdd('=== MASSE ET CENTRAGE ===');
 RepAdd('Modele mince (coque) : masse surfacique = ' + F2(SkinDens) + ' kg/m2');
 RepAdd('Une masse imposee (parametre Masse kg) est repartie sur la surface.');
 RepAdd('');
 RepAdd(PadR('Composant', 18) + PadL('Masse kg', 10) + PadL('Xcg', 9) + PadL('Ycg', 9) + PadL('Zcg', 9));
 TM := 0; TXX := 0; TYY := 0; TZZ := 0; TXY := 0; TXZ := 0; TYZ := 0;
 TAx := 0; TAy := 0; TAz := 0;
 For G := 0 To GeomCount - 1 Do
  If Geoms^[G].Visible Then Begin
   If BasePartCount(Geoms^[G]) > 0 Then Begin
    IntegrateGeom(G, R);
    If R.Area < 1E-9 Then Continue;
    If Geoms^[G].Mass > 0 Then K := Geoms^[G].Mass / R.Area Else K := SkinDens;
    M := K * R.Area;
    TM := TM + M;
    TAx := TAx + K * R.Ax; TAy := TAy + K * R.Ay; TAz := TAz + K * R.Az;
    TXX := TXX + K * R.Sxx; TYY := TYY + K * R.Syy; TZZ := TZZ + K * R.Szz;
    TXY := TXY + K * R.Sxy; TXZ := TXZ + K * R.Sxz; TYZ := TYZ + K * R.Syz;
    RepAdd(PadR(Geoms^[G].Name, 18) + Num(M, 1, 10) + Num(R.Ax / R.Area, 2, 9) +
           Num(R.Ay / R.Area, 2, 9) + Num(R.Az / R.Area, 2, 9));
   End
   Else If (Geoms^[G].Kind = GT_BLANK) And (Geoms^[G].Mass > 0) Then Begin
    ComputeXforms;
    M := Geoms^[G].Mass;
    TM := TM + M;
    TAx := TAx + M * GT[G, 0]; TAy := TAy + M * GT[G, 1]; TAz := TAz + M * GT[G, 2];
    TXX := TXX + M * GT[G, 0] * GT[G, 0]; TYY := TYY + M * GT[G, 1] * GT[G, 1];
    TZZ := TZZ + M * GT[G, 2] * GT[G, 2]; TXY := TXY + M * GT[G, 0] * GT[G, 1];
    TXZ := TXZ + M * GT[G, 0] * GT[G, 2]; TYZ := TYZ + M * GT[G, 1] * GT[G, 2];
    RepAdd(PadR(Geoms^[G].Name, 18) + Num(M, 1, 10) + Num(GT[G, 0], 2, 9) +
           Num(GT[G, 1], 2, 9) + Num(GT[G, 2], 2, 9) + '  (masse ponctuelle)');
   End;
  End;
 RepAdd('');
 If TM < 1E-9 Then Begin
  RepAdd('Aucune masse a calculer.');
  RepAdd('');
  Exit;
 End;
 Cx := TAx / TM; Cy := TAy / TM; Cz := TAz / TM;
 RepAdd('Masse totale : ' + F1(TM) + ' kg');
 RepAdd('Centre de gravite : X=' + F3(Cx) + '  Y=' + F3(Cy) + '  Z=' + F3(Cz) + ' m');
 Ixx := TYY + TZZ - TM * (Cy * Cy + Cz * Cz);
 Iyy := TXX + TZZ - TM * (Cx * Cx + Cz * Cz);
 Izz := TXX + TYY - TM * (Cx * Cx + Cy * Cy);
 Ixz := -(TXZ - TM * Cx * Cz);
 RepAdd('Moments d''inertie au CG (kg.m2) :');
 RepAdd('  Ixx=' + F1(Ixx) + '  Iyy=' + F1(Iyy) + '  Izz=' + F1(Izz));
 RepAdd('  Ixz=' + F1(Ixz) + '  Ixy=' + F1(-(TXY - TM * Cx * Cy)) +
        '  Iyz=' + F1(-(TYZ - TM * Cy * Cz)));
 RepAdd('');
End;

{$ENDIF}
Procedure RepPlan;
Var
 G, S : Integer;
 Sh, Sp, MAC, Tp, Sw, Tc, SArea : Real;
 Cnt : Integer;
Begin
 RepAdd('=== PLANFORME DES SURFACES PORTANTES ===');
 RepAdd('');
 Cnt := 0;
 For G := 0 To GeomCount - 1 Do
  If Geoms^[G].Kind = GT_WING Then Begin
   WingPlan(Geoms^[G], Sh, Sp, MAC, Tp, Sw, Tc);
   If Geoms^[G].Sym > 0.5 Then SArea := 2 * Sh Else SArea := Sh;
   RepAdd(Geoms^[G].Name + ' :');
   RepAdd('  Envergure b = ' + F3(Sp) + ' m    Surface S = ' + F3(SArea) + ' m2');
   RepAdd('  Allongement = ' + F2(Sp * Sp / MaxR(SArea, 1E-9)) + '    Effilement = ' + F3(Tp));
   RepAdd('  Corde racine = ' + F3(Geoms^[G].RootChord) + ' m   Corde bout = ' + F3(Tc) +
          ' m   MAC = ' + F3(MAC) + ' m');
   RepAdd('  Fleche c/4 = ' + F2(Sw) + ' deg   Sections : ' + IntToStr(Round(Geoms^[G].NSect)));
   For S := 1 To Round(Geoms^[G].NSect) Do
    RepAdd('    #' + IntToStr(S) + ' env=' + F2(Geoms^[G].SSpan[S]) + ' bout=' +
           F2(Geoms^[G].STip[S]) + ' fl=' + F1(Geoms^[G].SSweep[S]) + ' dih=' +
           F1(Geoms^[G].SDih[S]) + ' vr=' + F2(Geoms^[G].STwist[S]));
   RepAdd('');
   Inc(Cnt);
  End;
 If Cnt = 0 Then Begin RepAdd('Aucune aile dans le modele.'); RepAdd(''); End;
End;

{$IFDEF FULL}
{ Trainee parasite : retourne CD0 et ajoute le tableau au rapport }
Function RepDrag(Show: Boolean): Real;
Var
 T, P, Rho, Mu, A, V, Re, Cf, FF, Q, L, Tc, CD, Tot, Sref, Sh, Sp, MAC, Tp, Sw, Tcc, M : Real;
 W, G : Integer;
 R : TInteg;
 F, Amax, Cmp : Real;
 S : Integer;
Begin
 RepDrag := 0.0;
 ISAAtm(FlAlt, T, P, Rho, Mu, A);
 V := FlMach * A;
 If V < 1 Then V := 1;
 M := FlMach;
 W := MainWing;
 If W >= 0 Then Sref := WingArea(Geoms^[W]) Else Sref := 1;
 If Sref < 1E-6 Then Sref := 1;
 If Show Then Begin
  RepAdd('=== TRAINEE PARASITE (methode des facteurs de forme) ===');
  RepAdd('Altitude ' + F1(FlAlt) + ' m  Mach ' + F3(FlMach) + '  V=' + F1(V) + ' m/s  rho=' +
         F4(Rho) + ' kg/m3  T=' + F1(T) + ' K');
  RepAdd('Sref = ' + F3(Sref) + ' m2');
  RepAdd('');
  RepAdd(PadR('Composant', 16) + PadL('Swet', 8) + PadL('L m', 7) + PadL('Re', 11) +
         PadL('Cf', 8) + PadL('FF', 7) + PadL('Q', 5) + PadL('CD0', 9));
 End;
 Tot := 0;
 For G := 0 To GeomCount - 1 Do
  If Geoms^[G].Visible And (BasePartCount(Geoms^[G]) > 0) And
     (Geoms^[G].Kind <> GT_PROP) Then Begin
   IntegrateGeom(G, R);
   If R.Area < 1E-9 Then Continue;
   Q := 1.0;
   Case Geoms^[G].Kind Of
    GT_WING: Begin
     WingPlan(Geoms^[G], Sh, Sp, MAC, Tp, Sw, Tcc);
     L := MAC;
     Tc := (Geoms^[G].Thick + Geoms^[G].SThick[Round(Geoms^[G].NSect)]) / 200.0;
     FF := (1 + 0.6 / 0.3 * Tc + 100 * Pow(Tc, 4)) *
           MaxR(1.0, 1.34 * Pow(MaxR(M, 0.05), 0.18) * Pow(Cos(Sw * DEG), 0.28));
    End;
    GT_FUSE: Begin
     L := Geoms^[G].Len;
     Amax := 0;
     For S := 1 To Round(Geoms^[G].NStat) Do
      Amax := MaxR(Amax, 0.7854 * Geoms^[G].StW[S] * Geoms^[G].StH[S]);
     F := L / Sqrt(MaxR(4 / 3.14159265 * Amax, 1E-6));
     FF := 1 + 60 / (F * F * F) + F / 400.0;
    End;
    GT_POD: Begin
     L := Geoms^[G].Len;
     F := L / MaxR(Geoms^[G].Diam, 1E-3);
     FF := 1 + 0.35 / F;
     Q := 1.3;
    End;
   Else Begin
    L := Geoms^[G].Len;
    FF := 1.2; Q := 1.3;
   End;
   End;
   Re := Rho * V * L / Mu;
   Cf := 0.455 / (Pow(Log10(MaxR(Re, 1E4)), 2.58) * Pow(1 + 0.144 * M * M, 0.65));
   CD := Cf * FF * Q * R.Area / Sref;
   Tot := Tot + CD;
   If Show Then
    RepAdd(PadR(Geoms^[G].Name, 16) + Num(R.Area, 2, 8) + Num(L, 2, 7) +
           PadL(RealToStr(Re / 1E6, 2) + 'e6', 11) + Num(Cf, 5, 8) + Num(FF, 3, 7) +
           Num(Q, 1, 5) + Num(CD, 5, 9));
  End;
 Cmp := Tot * MiscDrag;
 If Show Then Begin
  RepAdd('');
  RepAdd('CD0 composants = ' + F4(Tot));
  RepAdd('Divers (' + F1(MiscDrag * 100) + ' %) = ' + F4(Cmp));
  RepAdd('CD0 total      = ' + F4(Tot + Cmp));
  RepAdd('');
 End;
 RepDrag := Tot + Cmp;
End;
{$ENDIF}

{$IFDEF FULL}
{ --------------------------------------------------------------------- }
{ Aerodynamique : ligne portante de Prandtl (serie de Fourier)           }
{ --------------------------------------------------------------------- }

Function LiftingLine(Show: Boolean): Boolean;
Const
 NT = 12;
 Cols = NT + 2;
Var
 W, K, M, I : Integer;
 Mat : Array[0..NT * Cols - 1] Of Real;
 A0, A1 : Array[1..NT] Of Real;
 B, S, AR, Th, Y, C, Tw, A0L, Lam, A0s, Mu, Mach, CD0, Al, CL, CDi, Sh, Sp, Mc, Tp, Sw, Tc : Real;
 N : Integer;
 An, Sum, CLa, CL0, E5, Step : Real;
 T, P, Rho, Mus, Asd : Real;
Begin
 LiftingLine := False;
 PolOK := False;
 W := MainWing;
 If W < 0 Then Begin
  If Show Then Begin RepAdd('Aucune aile : analyse impossible.'); RepAdd(''); End;
  Exit;
 End;
 WingPlan(Geoms^[W], Sh, Sp, Mc, Tp, Sw, Tc);
 { WingPlan renvoie l'envergure totale : la demi-aile sert de base (miroir) }
 If Geoms^[W].Sym > 0.5 Then B := Sp Else B := 2 * Sp;
 S := 2 * Sh;
 If S < 1E-6 Then Exit;
 AR := B * B / S;
 Mach := MinR(FlMach, 0.9);
 For K := 1 To NT Do Begin
  Th := K * 3.14159265358979 / (2 * NT);
  Y := (B / 2) * Cos(Th);
  WingAt(Geoms^[W], Y, C, Tw, A0L, Lam);
  A0s := PI2 * Cos(Lam) / Sqrt(1 - Sqr2(Mach * Cos(Lam)));
  Mu := C * A0s / (4 * B);
  For M := 1 To NT Do Begin
   N := 2 * M - 1;
   Mat[(K - 1) * Cols + (M - 1)] := Sin(N * Th) * (Sin(Th) + N * Mu);
  End;
  Mat[(K - 1) * Cols + NT] := Mu * ((Tw - A0L) * DEG) * Sin(Th);
  Mat[(K - 1) * Cols + NT + 1] := Mu * ((1 + Tw - A0L) * DEG) * Sin(Th);
 End;
 SolveSys(NT, Mat, Cols);
 For M := 1 To NT Do Begin
  A0[M] := Mat[(M - 1) * Cols + NT];
  A1[M] := Mat[(M - 1) * Cols + NT + 1];
 End;
 CL0 := 3.14159265358979 * AR * A0[1];
 CLa := 3.14159265358979 * AR * (A1[1] - A0[1]);
 If Abs(CLa) < 1E-6 Then Exit;
 { efficacite d'envergure a alpha = 5 deg }
 Sum := 0;
 For M := 1 To NT Do Begin
  An := A0[M] + 5 * (A1[M] - A0[M]);
  Sum := Sum + (2 * M - 1) * An * An;
 End;
 An := A0[1] + 5 * (A1[1] - A0[1]);
 If Sum > 1E-12 Then E5 := An * An / Sum Else E5 := 1;
 CD0 := RepDrag(False);
 PolSref := S; PolBref := B; PolAR := AR; PolCLa := CLa;
 PolAlpha0 := -CL0 / CLa; PolE := E5; PolCD0 := CD0;
 PolN := Round(AlphaMax - AlphaMin) + 1;
 If PolN < 2 Then PolN := 2;
 If PolN > 31 Then PolN := 31;
 Step := (AlphaMax - AlphaMin) / (PolN - 1);
 For I := 0 To PolN - 1 Do Begin
  Al := AlphaMin + I * Step;
  Sum := 0;
  For M := 1 To NT Do Begin
   An := A0[M] + Al * (A1[M] - A0[M]);
   Sum := Sum + (2 * M - 1) * An * An;
  End;
  CL := 3.14159265358979 * AR * (A0[1] + Al * (A1[1] - A0[1]));
  CDi := 3.14159265358979 * AR * Sum;
  PolA[I] := Al; PolCL[I] := CL; PolCD[I] := CD0 + CDi;
 End;
 PolOK := True;
 LiftingLine := True;
 If Show Then Begin
  ISAAtm(FlAlt, T, P, Rho, Mus, Asd);
  RepAdd('=== AERODYNAMIQUE (ligne portante, aile principale : ' + Geoms^[W].Name + ') ===');
  RepAdd('Altitude ' + F1(FlAlt) + ' m   Mach ' + F3(FlMach) + '   V = ' + F1(FlMach * Asd) +
         ' m/s   q = ' + F1(0.5 * Rho * Sqr2(FlMach * Asd)) + ' Pa');
  RepAdd('Sref = ' + F3(S) + ' m2   b = ' + F3(B) + ' m   AR = ' + F2(AR));
  RepAdd('CL_alpha = ' + F4(CLa) + ' /deg  (' + F3(CLa / DEG) + ' /rad)   alpha(CL=0) = ' +
         F2(PolAlpha0) + ' deg');
  RepAdd('Efficacite d''envergure e = ' + F3(E5) + '    CD0 (parasite) = ' + F4(CD0));
  RepAdd('');
  RepAdd(PadL('alpha', 8) + PadL('CL', 9) + PadL('CD', 10) + PadL('CDi', 10) + PadL('L/D', 9));
  For I := 0 To PolN - 1 Do
   RepAdd(Num(PolA[I], 1, 8) + Num(PolCL[I], 4, 9) + Num(PolCD[I], 5, 10) +
          Num(PolCD[I] - CD0, 5, 10) + Num(PolCL[I] / PolCD[I], 2, 9));
  RepAdd('');
  RepAdd('Modele lineaire sans decrochage ; l''empennage et le fuselage ne sont pas');
  RepAdd('pris en compte dans la portance. Compressibilite : Prandtl-Glauert.');
  RepAdd('');
 End;
End;

{$ENDIF}
{ --------------------------------------------------------------------- }
{ Sauvegarde / chargement du modele (.VSP, format texte)                 }
{ --------------------------------------------------------------------- }

Function SaveModel(Const FN: String): Boolean;
Var
 F : Text;
 G, I, S : Integer;
Begin
 SaveModel := False;
 {$I-}
 Assign(F, FN);
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 WriteLn(F, 'OPENVSP 1');
 WriteLn(F, 'RES ', Res);
 WriteLn(F, 'VIEW ', RealToStr(CamAz, 2), ' ', RealToStr(CamEl, 2));
{$IFDEF FULL}
 For S := 1 To MAX_AF Do
  If AFLib^[S].Used Then Begin
   WriteLn(F, 'AF ', S, ' ', AFLib^[S].Name);
   WriteLn(F, 'AFN ', AFLib^[S].NU, ' ', AFLib^[S].NL, ' ', RealToStr(AFLib^[S].Thick, 6));
   For I := 0 To AFLib^[S].NU - 1 Do
    WriteLn(F, 'U ', RealToStr(AFLib^[S].UX[I], 6), ' ', RealToStr(AFLib^[S].UZ[I], 6));
   For I := 0 To AFLib^[S].NL - 1 Do
    WriteLn(F, 'L ', RealToStr(AFLib^[S].LX[I], 6), ' ', RealToStr(AFLib^[S].LZ[I], 6));
  End;
{$ENDIF}
 For G := 0 To GeomCount - 1 Do Begin
  WriteLn(F, 'GEOM ', Geoms^[G].Kind, ' ', Ord(Geoms^[G].Visible), ' ', Geoms^[G].Name);
  ParAll := True;
  BuildParams(Geoms^[G]);
  For I := 0 To ParN - 1 Do
   WriteLn(F, Par[I].Key, '=', RealToStr(Par[I].P^, 6));
  WriteLn(F, 'END');
 End;
 Close(F);
 ParAll := False;
 RefreshParams;
 SaveModel := True;
End;

Function SplitWord(Var S: String): String;
Var P: Integer;
Begin
 S := TrimStr(S);
 P := Pos(' ', S);
 If P = 0 Then Begin SplitWord := S; S := ''; End
 Else Begin SplitWord := Copy(S, 1, P - 1); S := TrimStr(Copy(S, P + 1, 255)); End;
End;

Function LoadModel(Const FN: String): Boolean;
Var
 F : Text;
 Line, W, Rest, Key : String;
 Cur, I, S, N, Code, Eq : Integer;
 V, V2 : Real;
 Ok : Boolean;
Begin
 LoadModel := False;
 {$I-}
 Assign(F, FN);
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 ReadLn(F, Line);
 If Copy(UpStr(TrimStr(Line)), 1, 7) <> 'OPENVSP' Then Begin Close(F); Exit; End;
 ClearModel;
 For S := 1 To MAX_AF Do AFLib^[S].Used := False;
 AFNext := 1;
 Cur := -1; S := 0;
 While Not Eof(F) Do Begin
  ReadLn(F, Line);
  Line := TrimStr(Line);
  If Line = '' Then Continue;
  Eq := Pos('=', Line);
  If (Eq > 0) And (Cur >= 0) Then Begin
   Key := Copy(Line, 1, Eq - 1);
   If ParseReal(Copy(Line, Eq + 1, 40), V) Then
    For I := 0 To ParN - 1 Do
     If Par[I].Key = Key Then Par[I].P^ := V;
   Continue;
  End;
  Rest := Line;
  W := UpStr(SplitWord(Rest));
  If W = 'RES' Then Begin
   Val(Rest, N, Code);
   If (Code = 0) And (N >= 0) And (N <= 2) Then Res := N;
  End
  Else If W = 'VIEW' Then Begin
   If ParseReal(SplitWord(Rest), V) And ParseReal(SplitWord(Rest), V2) Then Begin
    CamAz := V; CamEl := V2;
   End;
  End
{$IFDEF FULL}
  Else If W = 'AF' Then Begin
   Val(SplitWord(Rest), S, Code);
   If (Code = 0) And (S >= 1) And (S <= MAX_AF) Then Begin
    AFLib^[S].Used := True; AFLib^[S].Name := Copy(Rest, 1, 24);
    AFLib^[S].NU := 0; AFLib^[S].NL := 0; AFLib^[S].Thick := 0.1;
   End
   Else S := 0;
  End
  Else If (W = 'AFN') And (S > 0) Then Begin
   If ParseReal(SplitWord(Rest), V) And ParseReal(SplitWord(Rest), V2) Then Begin
    AFLib^[S].NU := 0; AFLib^[S].NL := 0;
    If ParseReal(SplitWord(Rest), V2) Then AFLib^[S].Thick := V2;
   End;
  End
  Else If ((W = 'U') Or (W = 'L')) And (S > 0) Then Begin
   Ok := ParseReal(SplitWord(Rest), V) And ParseReal(SplitWord(Rest), V2);
   If Ok Then
    If W = 'U' Then Begin
     If AFLib^[S].NU < MAX_AFPT Then Begin
      AFLib^[S].UX[AFLib^[S].NU] := V; AFLib^[S].UZ[AFLib^[S].NU] := V2;
      Inc(AFLib^[S].NU);
     End;
    End
    Else If AFLib^[S].NL < MAX_AFPT Then Begin
     AFLib^[S].LX[AFLib^[S].NL] := V; AFLib^[S].LZ[AFLib^[S].NL] := V2;
     Inc(AFLib^[S].NL);
    End;
  End
{$ENDIF}
  Else If W = 'GEOM' Then Begin
   Val(SplitWord(Rest), N, Code);
   If (Code = 0) And (N >= 0) And (N < NUM_KIND) And (GeomCount < MAX_GEOM) Then Begin
    Cur := AddGeom(N);
    Val(SplitWord(Rest), I, Code);
    Geoms^[Cur].Visible := I <> 0;
    If Rest <> '' Then Geoms^[Cur].Name := Copy(Rest, 1, 20);
    ParAll := True;
    BuildParams(Geoms^[Cur]);
   End
   Else Cur := -1;
  End
  Else If W = 'END' Then Begin
   ParAll := False;
   Cur := -1;
  End;
 End;
 Close(F);
 ParAll := False;
 { validation }
 For I := 0 To GeomCount - 1 Do Begin
  If Round(Geoms^[I].NSect) < 1 Then Geoms^[I].NSect := 1;
  If Round(Geoms^[I].NSect) > MAX_SECT Then Geoms^[I].NSect := MAX_SECT;
  If Round(Geoms^[I].NStat) < 2 Then Geoms^[I].NStat := 2;
  If Round(Geoms^[I].NStat) > MAX_STAT Then Geoms^[I].NStat := MAX_STAT;
  If Round(Geoms^[I].NBlade) < 2 Then Geoms^[I].NBlade := 2;
  If Round(Geoms^[I].NBlade) > 8 Then Geoms^[I].NBlade := 8;
  If Round(Geoms^[I].Parent) > GeomCount Then Geoms^[I].Parent := 0;
  If (Round(Geoms^[I].AFSrc) > MAX_AF) Or (Round(Geoms^[I].AFSrc) < 0) Then
   Geoms^[I].AFSrc := 0;
 End;
 ModelName := FN;
 If GeomCount > 0 Then Sel := 0 Else Sel := -1;
 CurTab := 0; CurGrp := 1;
 RefreshParams;
 MeshDirty := True;
 LoadModel := True;
End;

{ --------------------------------------------------------------------- }
{ Exportations                                                           }
{ --------------------------------------------------------------------- }

Function SameVert(A, B: Integer): Boolean;
Begin
 SameVert := (MV^[A].X = MV^[B].X) And (MV^[A].Y = MV^[B].Y) And (MV^[A].Z = MV^[B].Z);
End;

Function ExportSTL(Const FN: String): Boolean;
Var
 F : Text;
 Q, K : Integer;
 Idx : Array[0..3] Of Word;
 Tri : Array[0..1, 0..2] Of Integer;
 T, V : Integer;
 Nx, Ny, Nz : Real;
Begin
 ExportSTL := False;
 If MeshDirty Then BuildMesh;
 {$I-}
 Assign(F, FN);
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 WriteLn(F, 'solid openvsp');
 For Q := 0 To NQ - 1 Do Begin
  Idx[0] := MQ^[Q].A; Idx[1] := MQ^[Q].B; Idx[2] := MQ^[Q].C; Idx[3] := MQ^[Q].D;
  Tri[0, 0] := 0; Tri[0, 1] := 1; Tri[0, 2] := 2;
  Tri[1, 0] := 0; Tri[1, 1] := 2; Tri[1, 2] := 3;
  For T := 0 To 1 Do Begin
   If SameVert(Idx[Tri[T, 0]], Idx[Tri[T, 1]]) Or SameVert(Idx[Tri[T, 1]], Idx[Tri[T, 2]]) Or
      SameVert(Idx[Tri[T, 0]], Idx[Tri[T, 2]]) Then Continue;
   Nx := MQ^[Q].NX / 127.0; Ny := MQ^[Q].NY / 127.0; Nz := MQ^[Q].NZ / 127.0;
   WriteLn(F, ' facet normal ', RealToStr(Nx, 4), ' ', RealToStr(Ny, 4), ' ', RealToStr(Nz, 4));
   WriteLn(F, '  outer loop');
   For K := 0 To 2 Do Begin
    V := Idx[Tri[T, K]];
    WriteLn(F, '   vertex ', RealToStr(MV^[V].X / 1000.0, 4), ' ',
            RealToStr(MV^[V].Y / 1000.0, 4), ' ', RealToStr(MV^[V].Z / 1000.0, 4));
   End;
   WriteLn(F, '  endloop');
   WriteLn(F, ' endfacet');
  End;
 End;
 WriteLn(F, 'endsolid openvsp');
 Close(F);
 ExportSTL := True;
End;

{$IFDEF FULL}
Function ExportOBJ(Const FN: String): Boolean;
Var
 F : Text;
 I, Q, LastG : Integer;
Begin
 ExportOBJ := False;
 If MeshDirty Then BuildMesh;
 {$I-}
 Assign(F, FN);
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 WriteLn(F, '# OpenVSP (Avionix) - ', ModelName);
 For I := 0 To NV - 1 Do
  WriteLn(F, 'v ', RealToStr(MV^[I].X / 1000.0, 4), ' ', RealToStr(MV^[I].Y / 1000.0, 4),
          ' ', RealToStr(MV^[I].Z / 1000.0, 4));
 LastG := -1;
 For Q := 0 To NQ - 1 Do Begin
  If MQ^[Q].G <> LastG Then Begin
   LastG := MQ^[Q].G;
   WriteLn(F, 'g ', Geoms^[LastG].Name);
  End;
  If MQ^[Q].F = 2 Then
   WriteLn(F, 'f ', MQ^[Q].A + 1, ' ', MQ^[Q].B + 1, ' ', MQ^[Q].C + 1)
  Else
   WriteLn(F, 'f ', MQ^[Q].A + 1, ' ', MQ^[Q].B + 1, ' ', MQ^[Q].C + 1, ' ', MQ^[Q].D + 1);
 End;
 Close(F);
 ExportOBJ := True;
End;

{ Exportation "degenere" : une ligne par section de chaque composant }
Function ExportCSV(Const FN: String): Boolean;
Var
 F : Text;
 G, I, J, NU, NVv : Integer;
 Caps : Boolean;
 X, Y, Z, Cx, Cy, Cz, MinY, MaxY, MinZ, MaxZ, MinX, MaxX : Real;
Begin
 ExportCSV := False;
 {$I-}
 Assign(F, FN);
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 ComputeXforms;
 EffRes := Res;
 WriteLn(F, 'geom,type,station,xc,yc,zc,xmin,xmax,width,height');
 For G := 0 To GeomCount - 1 Do
  If BasePartCount(Geoms^[G]) > 0 Then Begin
   PartDims(Geoms^[G], 0, NU, NVv, Caps);
   For I := 0 To NU - 1 Do Begin
    PrepRing(Geoms^[G], 0, I, NU);
    Cx := 0; Cy := 0; Cz := 0;
    MinX := 1E9; MaxX := -1E9; MinY := 1E9; MaxY := -1E9; MinZ := 1E9; MaxZ := -1E9;
    For J := 0 To NVv - 1 Do Begin
     RingPoint(Geoms^[G], 0, J, NVv, X, Y, Z);
     ToWorld(G, False, X, Y, Z);
     Cx := Cx + X; Cy := Cy + Y; Cz := Cz + Z;
     If X < MinX Then MinX := X; If X > MaxX Then MaxX := X;
     If Y < MinY Then MinY := Y; If Y > MaxY Then MaxY := Y;
     If Z < MinZ Then MinZ := Z; If Z > MaxZ Then MaxZ := Z;
    End;
    WriteLn(F, Geoms^[G].Name, ',', KindName(Geoms^[G].Kind), ',', I, ',',
            RealToStr(Cx / NVv, 4), ',', RealToStr(Cy / NVv, 4), ',', RealToStr(Cz / NVv, 4), ',',
            RealToStr(MinX, 4), ',', RealToStr(MaxX, 4), ',',
            RealToStr(MaxY - MinY, 4), ',', RealToStr(MaxZ - MinZ, 4));
   End;
  End;
 Close(F);
 ExportCSV := True;
End;

{$ENDIF}
{ --------------------------------------------------------------------- }
{ Actions                                                                }
{ --------------------------------------------------------------------- }

Procedure Touch;
Begin
 MeshDirty := True; NeedView := True; NeedPanel := True; Modified := True;
End;

Procedure ModelLoaded;
Begin
 Modified := False;
 MeshDirty := True;
 ViewName := 'Libre';
 ComputeView;
 BuildMesh;
 FitView;
 UndoValid := False;
 NeedAll := True;
End;

Function BaseName(Const S: String): String;
Var P: Integer; T: String;
Begin
 T := S;
 P := Pos('.', T);
 If P > 0 Then T := Copy(T, 1, P - 1);
 If T = '' Then T := 'MODELE';
 BaseName := T;
End;

Function ConfirmDiscard: Boolean;
Begin
 If Modified Then ConfirmDiscard := Confirm('Modifications non enregistrees', 'Abandonner les modifications ?')
 Else ConfirmDiscard := True;
End;

Procedure DoSaveAs;
Var FN: String;
Begin
 FN := BaseName(ModelName) + '.VSP';
 If FileDialog('Enregistrer sous', 'VSP', FN) Then Begin
  If Pos('.', FN) = 0 Then FN := FN + '.VSP';
  If SaveModel(FN) Then Begin
   ModelName := FN; Modified := False;
   StatusMsg := 'Enregistre : ' + FN;
  End
  Else ShowMessage('Erreur', 'Impossible d''ecrire ' + FN);
 End;
End;

Procedure DoSave;
Begin
 If ModelName = '' Then DoSaveAs
 Else If SaveModel(ModelName) Then Begin
  Modified := False; StatusMsg := 'Enregistre : ' + ModelName;
 End
 Else ShowMessage('Erreur', 'Impossible d''ecrire ' + ModelName);
End;

Procedure DoExport(Kind: Integer);
Var FN, Ext: String; Ok: Boolean;
Begin
 Ext := '.STL';
{$IFDEF FULL}
 Case Kind Of
  2: Ext := '.OBJ';
  3: Ext := '.CSV';
 End;
{$ENDIF}
 FN := BaseName(ModelName) + Ext;
 If Not InputString('Exporter', 'Nom du fichier :', FN) Then Exit;
 If Pos('.', FN) = 0 Then FN := FN + Ext;
 Ok := ExportSTL(FN);
{$IFDEF FULL}
 Case Kind Of
  2: Ok := ExportOBJ(FN);
  3: Ok := ExportCSV(FN);
 End;
{$ENDIF}
 If Ok Then StatusMsg := 'Exporte : ' + FN
 Else ShowMessage('Erreur', 'Exportation impossible');
End;

{$IFDEF FULL}
Procedure DoImportPRO;
Var FN: String; Slot: Integer;
Begin
 FN := '';
 If Not FileDialog('Importer un profil (.PRO)', 'PRO', FN) Then Exit;
 Slot := LoadPRO(FN);
 If Slot = 0 Then Begin
  ShowMessage('Erreur', 'Profil invalide : ' + FN);
  Exit;
 End;
 If (Sel >= 0) And (Geoms^[Sel].Kind = GT_WING) Then Begin
  PushUndo;
  Geoms^[Sel].AFSrc := Slot;
  Geoms^[Sel].Thick := AFLib^[Slot].Thick * 100;
  Touch;
  RefreshParams;
  ShowMessage('Profil importe', AFLib^[Slot].Name + '|Applique a l''aile ' + Geoms^[Sel].Name + '|Epaisseur ' + F1(AFLib^[Slot].Thick * 100) + ' %');
 End
 Else
  ShowMessage('Profil importe', AFLib^[Slot].Name + '|Selectionnez une aile puis choisissez|le profil dans l''onglet Prof.');
End;

{$ENDIF}
Procedure DoAddGeom(K: Integer);
Var I: Integer;
Begin
 If GeomCount >= MAX_GEOM Then Begin
  ShowMessage('Limite', 'Nombre maximal de geometries atteint');
  Exit;
 End;
 PushUndo;
 I := AddGeom(K);
 If I >= 0 Then Begin
  SelectGeom(I);
  Touch;
  If GeomCount = 1 Then Begin BuildMesh; FitView; End;
 End;
End;

Procedure DoDup;
Var I: Integer;
Begin
 If (Sel < 0) Or (GeomCount >= MAX_GEOM) Then Exit;
 PushUndo;
 I := GeomCount;
 Geoms^[I] := Geoms^[Sel];
 Geoms^[I].Name := UniqueName(Geoms^[Sel].Kind);
 Inc(GeomCount);
 SelectGeom(I);
 Touch;
End;

Procedure DoDelete;
Begin
 If (Sel < 0) Or (Sel >= GeomCount) Then Exit;
 If Not Confirm('Supprimer', 'Supprimer ' + Geoms^[Sel].Name + ' ?') Then Exit;
 PushUndo;
 DeleteGeom(Sel);
 If Sel < 0 Then Begin ParN := 0; VisN := 0; End Else SelectGeom(Sel);
 Touch;
End;

Procedure DoRename;
Var S: String;
Begin
 If (Sel < 0) Or (Sel >= GeomCount) Then Exit;
 S := Geoms^[Sel].Name;
 If InputString('Renommer', 'Nouveau nom :', S) Then
  If S <> '' Then Begin
   PushUndo;
   Geoms^[Sel].Name := Copy(S, 1, 20);
   NeedPanel := True;
  End;
End;

Procedure DoUndo;
Begin
 If Not UndoValid Then Exit;
 Move(UndoBuf^, Geoms^, SizeOf(TGeomArr));
 GeomCount := UndoCount;
 Sel := UndoSel;
 If Sel >= GeomCount Then Sel := GeomCount - 1;
 UndoValid := False;
 If Sel >= 0 Then RefreshParams Else Begin ParN := 0; VisN := 0; End;
 Touch;
End;

Procedure DoNew;
Begin
 If Not ConfirmDiscard Then Exit;
 ClearModel;
 ParN := 0; VisN := 0;
 ModelLoaded;
 StatusMsg := 'Nouveau modele';
End;

Procedure DoOpen;
Var FN: String;
Begin
 If Not ConfirmDiscard Then Exit;
 FN := '';
 If FileDialog('Ouvrir un modele', 'VSP', FN) Then Begin
  If LoadModel(FN) Then Begin
   ModelLoaded; StatusMsg := 'Ouvert : ' + FN;
  End
  Else ShowMessage('Erreur', 'Fichier invalide : ' + FN);
 End;
End;

Procedure DoQuit;
Begin
 If ConfirmDiscard Then Running := False;
End;

{$IFDEF FULL}
Procedure DoConditions;
Var V: Real;
Begin
 V := FlAlt;
 If Not InputReal('Conditions de vol', 'Altitude (m, 0..20000) :', V) Then Exit;
 FlAlt := Clamp(V, 0, 20000);
 V := FlMach;
 If Not InputReal('Conditions de vol', 'Mach (0.05..0.9) :', V) Then Exit;
 FlMach := Clamp(V, 0.05, 0.9);
 V := AlphaMin;
 If Not InputReal('Conditions de vol', 'Alpha minimal (deg) :', V) Then Exit;
 AlphaMin := Clamp(V, -20, 25);
 V := AlphaMax;
 If Not InputReal('Conditions de vol', 'Alpha maximal (deg) :', V) Then Exit;
 AlphaMax := Clamp(V, AlphaMin + 2, 30);
 V := SkinDens;
 If Not InputReal('Masse et centrage', 'Masse surfacique (kg/m2) :', V) Then Exit;
 SkinDens := Clamp(V, 0.1, 200);
 StatusMsg := 'Conditions de vol mises a jour';
End;

Procedure DoReport;
Var FN: String;
Begin
 RepClear;
 RepAdd('OPENVSP (Avionix) - Rapport complet : ' + ModelName);
 RepAdd('');
 RepCompGeom;
 RepPlan;
 RepMass;
 RepDrag(True);
 LiftingLine(True);
 FN := BaseName(ModelName) + '.TXT';
 If InputString('Rapport complet', 'Enregistrer sous :', FN) Then Begin
  RepSave(FN);
  StatusMsg := 'Rapport : ' + FN;
 End;
End;

{$ENDIF}
{$IFDEF FULL}
Procedure ShowKeys;
Begin
 RepClear;
 RepAdd('=== TOUCHES ET SOURIS ===');
 RepAdd('');
 RepAdd('Souris (vue 3D)   gauche : tourner    droite : zoom    milieu : deplacer');
 RepAdd('                  clic sur un objet : le selectionner');
 RepAdd('Panneau gauche    clic sur le curseur : valeur ; clic sur le nombre : saisie');
 RepAdd('                  clic sur l''oeil : visible/masque');
 RepAdd('');
 RepAdd('Fleches           rotation de la vue');
 RepAdd('+ / - , PgUp/PgDn zoom            Home ou F : ajuster la vue');
 RepAdd('1 Dessus  2 Dessous  3 Face  4 Arriere  5 Gauche  6 Droite  7 Iso');
 RepAdd('W fil de fer   H lignes cachees   D ombre   M maillage');
 RepAdd('A axes   G grille   S symetrie   V visible');
 RepAdd('F2 renommer    Del supprimer    Ctrl+D dupliquer    Ctrl+Z annuler');
 RepAdd('Ctrl+N nouveau   Ctrl+O ouvrir   Ctrl+S enregistrer');
 RepAdd('Tab               clavier vers les parametres :');
 RepAdd('                  Haut/Bas choisir, Gauche/Droite modifier, Entree saisir');
 RepAdd('Alt+F/E/G/V/A/I   menus Fichier/Edition/Geometrie/Vue/Analyse/Aide');
 RepAdd('Esc               ferme le menu / quitte');
 RepAdd('');
 RepAdd('Formats : .VSP (modele, texte)  .PRO (profils d''aile, comme SOUFFLE)');
 ShowReport('Aide - Touches');
End;

{$ELSE}
Procedure ShowKeys;
Begin
 RepClear;
 RepAdd('Souris : gauche=tourner droite=zoom milieu=deplacer ; clic=selection');
 RepAdd('Fleches : rotation   +/- : zoom   F : ajuster   Tab : parametres');
 RepAdd('1..7 : vues   W/H/D : fil de fer / cache / ombre   A G M : axes grille maillage');
 RepAdd('S symetrie  V visible  F2 renommer  Del supprimer  Ctrl+N/O/S/Z/D');
 ShowReport('Aide - Touches');
End;

{$ENDIF}
Procedure DoAction(Act: Integer);
Var Slot: Integer;
Begin
 StatusMsg := '';
 Case Act Of
  ACT_NEW:    DoNew;
  ACT_OPEN:   DoOpen;
  ACT_SAVE:   DoSave;
  ACT_SAVEAS: DoSaveAs;
  ACT_EX1:    Begin
   If ConfirmDiscard Then Begin PushUndo; ExampleLight; ParAll := False; RefreshParams; ModelLoaded; End;
  End;
{$IFDEF FULL}
  ACT_EX2:    Begin
   If ConfirmDiscard Then Begin PushUndo; ExampleJet; ParAll := False; RefreshParams; ModelLoaded; End;
  End;
{$ENDIF}
{$IFDEF FULL}
  ACT_IMPORT: DoImportPRO;
{$ENDIF}
  ACT_EXSTL:  DoExport(1);
{$IFDEF FULL}
  ACT_EXOBJ:  DoExport(2);
  ACT_EXCSV:  DoExport(3);
{$ENDIF}
  ACT_QUIT:   DoQuit;
  ACT_UNDO:   DoUndo;
  ACT_DUP:    DoDup;
  ACT_DEL:    DoDelete;
  ACT_RENAME: DoRename;
  ACT_SYM:    If Sel >= 0 Then Begin
   PushUndo;
   If Geoms^[Sel].Sym > 0.5 Then Geoms^[Sel].Sym := 0 Else Geoms^[Sel].Sym := 1;
   RefreshParams; Touch;
  End;
  ACT_VISIBLE: If Sel >= 0 Then Begin
   PushUndo; Geoms^[Sel].Visible := Not Geoms^[Sel].Visible; Touch;
  End;
  ACT_HIDEALL: Begin
   PushUndo;
   For Slot := 0 To GeomCount - 1 Do Geoms^[Slot].Visible := False;
   Touch;
  End;
  ACT_SHOWALL: Begin
   PushUndo;
   For Slot := 0 To GeomCount - 1 Do Geoms^[Slot].Visible := True;
   Touch;
  End;
  ACT_ADD..ACT_ADD + NUM_KIND - 1: DoAddGeom(Act - ACT_ADD);
  ACT_WIRE:   Begin RenderMode := RM_WIRE; NeedView := True; NeedPanel := True; End;
  ACT_HIDDEN: Begin RenderMode := RM_HIDDEN; NeedView := True; End;
  ACT_SHADED: Begin RenderMode := RM_SHADED; NeedView := True; End;
  ACT_AXES:   Begin ShowAxes := Not ShowAxes; NeedAll := True; End;
  ACT_GRID:   Begin ShowGrid := Not ShowGrid; NeedAll := True; End;
  ACT_MESH:   Begin Res := (Res + 1) Mod 3; MeshDirty := True; NeedAll := True; End;
  ACT_VTOP:    SetView(0, 90, 'Dessus');
  ACT_VBOTTOM: SetView(0, -90, 'Dessous');
  ACT_VFRONT:  SetView(180, 0, 'Face');
  ACT_VBACK:   SetView(0, 0, 'Arriere');
  ACT_VLEFT:   SetView(-90, 0, 'Gauche');
  ACT_VRIGHT:  SetView(90, 0, 'Droite');
  ACT_VISO:    SetView(-145, 25, 'Iso');
  ACT_FIT:    Begin
   If MeshDirty Then BuildMesh;
   FitView; NeedView := True;
  End;
  ACT_ZOOMIN:  Begin CamZoom := CamZoom * 1.25; NeedView := True; End;
  ACT_ZOOMOUT: Begin CamZoom := CamZoom / 1.25; NeedView := True; End;
{$IFDEF FULL}
  ACT_COMPGEOM: Begin RepClear; RepCompGeom; ShowReport('Geometrie calculee'); End;
{$ENDIF}
  ACT_PLAN:     Begin RepClear; RepPlan; ShowReport('Planforme'); End;
{$IFDEF FULL}
  ACT_MASS:     Begin RepClear; RepMass; ShowReport('Masse et centrage'); End;
  ACT_DRAG:     Begin RepClear; RepDrag(True); ShowReport('Trainee parasite'); End;
  ACT_AERO: Begin
   RepClear;
   If LiftingLine(True) Then Begin ShowReport('Aerodynamique'); ShowPolar; End
   Else ShowReport('Aerodynamique');
  End;
  ACT_ATMOS:  DoConditions;
  ACT_REPORT: DoReport;
{$ENDIF}
  ACT_KEYS:   ShowKeys;
  ACT_ABOUT:  ShowMessage('A propos',
   'OPENVSP 1.00 - clone en Pascal|Modeleur parametrique de geometrie d''avions|' +
   'Avionix - Sylvain Maltais (gladir.com)|Turbo Pascal 7 / Free Pascal');
 End;
 NeedAll := NeedAll Or (Act < 60) Or (Act >= 80);
 If (Act >= 60) And (Act < 80) Then NeedPanel := True;
End;

{ --------------------------------------------------------------------- }
{ Menus : ouverture / fermeture                                          }
{ --------------------------------------------------------------------- }

Procedure ShowPopup(M: Integer);
Begin
 HideMouseCursor;
 MenuSaveBG(M);
 DrawMenuPopup(M);
 ShowMouseCursor;
End;

Procedure HidePopup;
Begin
 HideMouseCursor;
 MenuRestoreBG;
 ShowMouseCursor;
End;

Procedure MenuOpen(M: Integer);
Begin
 If MenuActive Then HidePopup;
 UpdateMenuStates;
 MenuActive := True;
 ActiveMenu := M;
 ActiveMenuItem := -1;
 HideMouseCursor;
 DrawMenuBar;
 ShowMouseCursor;
 ShowPopup(M);
End;

Procedure MenuClose;
Begin
 If MenuActive Then HidePopup;
 MenuActive := False;
 HideMouseCursor;
 DrawMenuBar;
 ShowMouseCursor;
End;

Procedure MenuExecute(M, I: Integer);
Var A: Integer;
Begin
 If (M < 0) Or (I < 0) Or (I >= Menus[M].ItemCount) Then Exit;
 If Menus[M].Items[I].Separator Or Not Menus[M].Items[I].Enabled Then Exit;
 A := Menus[M].Items[I].Act;
 MenuClose;
 DoAction(A);
End;

{ --------------------------------------------------------------------- }
{ Souris                                                                 }
{ --------------------------------------------------------------------- }

Procedure SliderUpdate(Mx: Integer);
Var
 K, SX1, SX2 : Integer;
 Fr, V : Real;
Begin
 If (DragRow < 0) Or (DragRow >= VisN) Then Exit;
 K := VisIdx[DragRow];
 SliderBounds(SX1, SX2);
 Fr := (Mx - (SX1 + 3)) / (SX2 - SX1 - 6);
 If Fr < 0 Then Fr := 0;
 If Fr > 1 Then Fr := 1;
 V := Par[K].Mn + Fr * (Par[K].Mx - Par[K].Mn);
 If Par[K].St > 0 Then V := Round(V / Par[K].St) * Par[K].St;
 If Abs(V - Par[K].P^) > 1E-9 Then Begin
  SetParam(K, V);
  NeedPanel := True;
  NeedView := True;
 End;
End;

Procedure EditParam(VI: Integer);
Var K: Integer; V: Real;
Begin
 If (VI < 0) Or (VI >= VisN) Then Exit;
 K := VisIdx[VI];
 If Par[K].Kind = PK_BOOL Then Begin
  PushUndo;
  If Par[K].P^ > 0.5 Then SetParam(K, 0) Else SetParam(K, 1);
  Touch;
  Exit;
 End;
 V := Par[K].P^;
 If InputReal(Par[K].Lbl, 'Valeur (' + RealToStr(Par[K].Mn, 2) + ' .. ' +
              RealToStr(Par[K].Mx, 2) + ') :', V) Then Begin
  PushUndo;
  SetParam(K, V);
  Touch;
 End;
 NeedAll := True;
End;

Procedure PanelClick(Mx, My: Integer);
Var
 H, T, K, Cnt, Row, SX1, SX2 : Integer;
Begin
 SliderBounds(SX1, SX2);
 { fleches du navigateur }
 If (My >= PANEL_Y + 1) And (My <= PANEL_Y + 13) Then Begin
  If (Mx >= PANEL_W - 38) And (Mx <= PANEL_W - 21) Then
   If BrowTop > 0 Then Begin Dec(BrowTop); NeedPanel := True; End;
  If (Mx >= PANEL_W - 20) And (Mx <= PANEL_W - 3) Then
   If BrowTop + BROW_ROWS < GeomCount Then Begin Inc(BrowTop); NeedPanel := True; End;
  Exit;
 End;
 H := BrowserHit(Mx, My);
 If H >= 0 Then Begin
  If Mx <= 16 Then Begin
   PushUndo;
   Geoms^[H].Visible := Not Geoms^[H].Visible;
   Touch;
  End
  Else Begin
   SelectGeom(H);
   NeedPanel := True; NeedView := True;
  End;
  Exit;
 End;
 If (My >= BTN_Y) And (My <= BTN_Y + 16) Then Begin
  If (Mx >= 4) And (Mx <= 56) Then Begin
   UpdateMenuStates;
   MenuOpen(MENU_GEOM);
  End
  Else If (Mx >= 58) And (Mx <= 108) Then DoAction(ACT_DUP)
  Else If (Mx >= 110) And (Mx <= 160) Then DoAction(ACT_DEL)
  Else If (Mx >= 162) And (Mx <= 212) Then DoAction(ACT_RENAME);
  Exit;
 End;
 If (Sel < 0) Or (Sel >= GeomCount) Then Exit;
 T := TabHit(Mx, My);
 If T >= 0 Then Begin
  CurTab := T; ParSel := 0;
  RefreshParams;
  NeedPanel := True;
  Exit;
 End;
 If (My < PAR_Y) Then Exit;
 Row := (My - PAR_Y) Div PAR_RH;
 If (RowOffset = 1) And (Row = 0) Then Begin
  Cnt := GrpCount(Geoms^[Sel]);
  K := (Mx - 4) Div 22 + 1;
  If (K >= 1) And (K <= Cnt) Then Begin
   CurGrp := K; RefreshParams; NeedPanel := True;
  End;
  Exit;
 End;
 Row := Row - RowOffset;
 If (Row < 0) Or (Row >= VisN) Then Exit;
 ParSel := Row;
 K := VisIdx[Row];
 If Par[K].Kind = PK_BOOL Then Begin
  EditParam(Row);
 End
 Else If Mx >= SX2 + 4 Then EditParam(Row)
 Else If Mx >= SX1 Then Begin
  PushUndo;
  DragMode := 4; DragRow := Row;
  SliderUpdate(Mx);
 End
 Else NeedPanel := True;
End;

Procedure HandleMouseEvent;
Var
 Pressed, PressedR, PressedM, Moved : Boolean;
 BarHit, ItemHit, T, Dx, Dy, PG : Integer;
Begin
 If Not MouseAvailable Then Exit;
 GetMouseLocal(MouseX, MouseY, MouseButtons);
 Pressed := ((MouseButtons And 1) <> 0) And ((OldMouseButtons And 1) = 0);
 PressedR := ((MouseButtons And 2) <> 0) And ((OldMouseButtons And 2) = 0);
 PressedM := ((MouseButtons And 4) <> 0) And ((OldMouseButtons And 4) = 0);
 Moved := (MouseX <> OldMouseX) Or (MouseY <> OldMouseY);

 If MenuActive Then Begin
  If Moved Then Begin
   BarHit := MenuBarHitTest(MouseX, MouseY);
   If (BarHit >= 0) And (BarHit <> ActiveMenu) Then MenuOpen(BarHit)
   Else Begin
    ItemHit := MenuItemHitTest(MouseX, MouseY, ActiveMenu);
    If ItemHit <> ActiveMenuItem Then Begin
     ActiveMenuItem := ItemHit;
     HideMouseCursor;
     DrawMenuPopup(ActiveMenu);
     ShowMouseCursor;
    End;
   End;
  End;
  If Pressed Then Begin
   BarHit := MenuBarHitTest(MouseX, MouseY);
   If BarHit >= 0 Then Begin
    If BarHit = ActiveMenu Then MenuClose Else MenuOpen(BarHit);
   End
   Else Begin
    ItemHit := MenuItemHitTest(MouseX, MouseY, ActiveMenu);
    If ItemHit >= 0 Then MenuExecute(ActiveMenu, ItemHit)
    Else MenuClose;
   End;
  End;
  OldMouseX := MouseX; OldMouseY := MouseY; OldMouseButtons := MouseButtons;
  Exit;
 End;

 { glissement en cours }
 If DragMode <> 0 Then Begin
  Dx := MouseX - DragX; Dy := MouseY - DragY;
  Case DragMode Of
   1: If (MouseButtons And 1) <> 0 Then Begin
       If (Dx <> 0) Or (Dy <> 0) Then Begin
        CamAz := CamAz - Dx * 0.5;
        CamEl := CamEl + Dy * 0.5;
        If CamEl > 90 Then CamEl := 90;
        If CamEl < -90 Then CamEl := -90;
        ViewName := 'Libre';
        ComputeView;
        NeedView := True;
        If (Abs(MouseX - DragStartX) > 3) Or (Abs(MouseY - DragStartY) > 3) Then DragMoved := True;
       End;
      End
      Else Begin
       If Not DragMoved Then Begin
        PG := PickGeom(DragStartX, DragStartY);
        If PG >= 0 Then Begin SelectGeom(PG); NeedPanel := True; End;
       End;
       DragMode := 0; NeedView := True;
      End;
   2: If (MouseButtons And 2) <> 0 Then Begin
       If Dy <> 0 Then Begin
        CamZoom := CamZoom * Exp(-Dy * 0.01);
        If CamZoom < 0.05 Then CamZoom := 0.05;
        If CamZoom > 20000 Then CamZoom := 20000;
        NeedView := True;
       End;
      End
      Else Begin DragMode := 0; NeedView := True; End;
   3: If (MouseButtons And 4) <> 0 Then Begin
       If (Dx <> 0) Or (Dy <> 0) Then Begin
        CamPX := CamPX + Dx; CamPY := CamPY + Dy;
        NeedView := True;
       End;
      End
      Else Begin DragMode := 0; NeedView := True; End;
   4: If (MouseButtons And 1) <> 0 Then Begin
       If Moved Then SliderUpdate(MouseX);
      End
      Else Begin DragMode := 0; NeedView := True; NeedPanel := True; End;
  End;
  DragX := MouseX; DragY := MouseY;
  OldMouseX := MouseX; OldMouseY := MouseY; OldMouseButtons := MouseButtons;
  Exit;
 End;

 If Pressed Or PressedR Or PressedM Then Begin
  If MouseY < MENUBAR_H Then Begin
   BarHit := MenuBarHitTest(MouseX, MouseY);
   If BarHit >= 0 Then MenuOpen(BarHit);
  End
  Else If MouseY < PANEL_Y Then Begin
   If Pressed Then Begin
    T := ToolbarHit(MouseX, MouseY);
    If T >= 0 Then Begin
     OldMouseButtons := MouseButtons;
     DoAction(TbAct[T]);
    End;
   End;
  End
  Else If (MouseX < PANEL_W) And (MouseY < ScreenHeight - STATUS_H) Then Begin
   If Pressed Then PanelClick(MouseX, MouseY);
  End
  Else If (MouseX >= VX1) And (MouseX <= VX2) And (MouseY >= VY1) And (MouseY <= VY2) Then Begin
   DragX := MouseX; DragY := MouseY;
   DragStartX := MouseX; DragStartY := MouseY;
   DragMoved := False;
   If Pressed Then DragMode := 1
   Else If PressedR Then DragMode := 2
   Else DragMode := 3;
  End;
 End;
 OldMouseX := MouseX; OldMouseY := MouseY; OldMouseButtons := MouseButtons;
End;

{ --------------------------------------------------------------------- }
{ Clavier                                                                }
{ --------------------------------------------------------------------- }

Procedure StepParam(Dir: Integer);
Var K: Integer; V, St: Real;
Begin
 If (ParSel < 0) Or (ParSel >= VisN) Then Exit;
 K := VisIdx[ParSel];
 St := Par[K].St;
 If St <= 0 Then St := 1;
 V := Par[K].P^ + Dir * St;
 PushUndo;
 SetParam(K, V);
 Touch;
End;

Procedure HandleKeyboardEvent;
Var Key, Ext: Char;
Begin
 If Not KeyPressed Then Exit;
 Key := ReadKey;
 If Key = #0 Then Begin
  Ext := ReadKey;
  If MenuActive Then Begin
   Case Ext Of
    #72: Begin MenuNextItem(-1); HideMouseCursor; DrawMenuPopup(ActiveMenu); ShowMouseCursor; Exit; End;
    #80: Begin MenuNextItem(+1); HideMouseCursor; DrawMenuPopup(ActiveMenu); ShowMouseCursor; Exit; End;
    #75: Begin MenuOpen((ActiveMenu + NUM_MENUS - 1) Mod NUM_MENUS); Exit; End;
    #77: Begin MenuOpen((ActiveMenu + 1) Mod NUM_MENUS); Exit; End;
   End;
  End;
  Case Ext Of
   #59: DoAction(ACT_KEYS);
   #60: DoAction(ACT_RENAME);
   #83: DoAction(ACT_DEL);
   #107: DoQuit;
   #33: MenuOpen(MENU_FILE);
   #18: MenuOpen(MENU_EDIT);
   #34: MenuOpen(MENU_GEOM);
   #47: MenuOpen(MENU_VIEW);
   #30: MenuOpen(MENU_ANALYSE);
   #35: MenuOpen(MENU_HELP);
   #71: DoAction(ACT_FIT);
   #73: DoAction(ACT_ZOOMIN);
   #81: DoAction(ACT_ZOOMOUT);
   #72: If ParFocus Then Begin
         If ParSel > 0 Then Dec(ParSel);
         NeedPanel := True;
        End
        Else Begin CamEl := CamEl + 5; If CamEl > 90 Then CamEl := 90; ViewName := 'Libre'; ComputeView; NeedView := True; End;
   #80: If ParFocus Then Begin
         If ParSel < VisN - 1 Then Inc(ParSel);
         NeedPanel := True;
        End
        Else Begin CamEl := CamEl - 5; If CamEl < -90 Then CamEl := -90; ViewName := 'Libre'; ComputeView; NeedView := True; End;
   #75: If ParFocus Then StepParam(-1)
        Else Begin CamAz := CamAz + 5; ViewName := 'Libre'; ComputeView; NeedView := True; End;
   #77: If ParFocus Then StepParam(1)
        Else Begin CamAz := CamAz - 5; ViewName := 'Libre'; ComputeView; NeedView := True; End;
  End;
  Exit;
 End;
 If MenuActive Then Begin
  If Key = #13 Then Begin
   If ActiveMenuItem >= 0 Then MenuExecute(ActiveMenu, ActiveMenuItem);
   Exit;
  End;
  If Key = #27 Then MenuClose;
  Exit;
 End;
 Case Key Of
  #27: Begin
        If ParFocus Then Begin ParFocus := False; NeedPanel := True; End
        Else DoQuit;
       End;
  #9:  Begin ParFocus := Not ParFocus; NeedPanel := True; End;
  #13: If ParFocus Then EditParam(ParSel);
  #14: DoAction(ACT_NEW);
  #15: DoAction(ACT_OPEN);
  #19: DoAction(ACT_SAVE);
  #26: DoAction(ACT_UNDO);
  #4:  DoAction(ACT_DUP);
  '+', '=': DoAction(ACT_ZOOMIN);
  '-', '_': DoAction(ACT_ZOOMOUT);
  '1': DoAction(ACT_VTOP);
  '2': DoAction(ACT_VBOTTOM);
  '3': DoAction(ACT_VFRONT);
  '4': DoAction(ACT_VBACK);
  '5': DoAction(ACT_VLEFT);
  '6': DoAction(ACT_VRIGHT);
  '7': DoAction(ACT_VISO);
  'w', 'W': DoAction(ACT_WIRE);
  'h', 'H': DoAction(ACT_HIDDEN);
  'd', 'D': DoAction(ACT_SHADED);
  'a', 'A': DoAction(ACT_AXES);
  'g', 'G': DoAction(ACT_GRID);
  'm', 'M': DoAction(ACT_MESH);
  's', 'S': DoAction(ACT_SYM);
  'v', 'V': DoAction(ACT_VISIBLE);
  'f', 'F': DoAction(ACT_FIT);
 End;
End;

{ --------------------------------------------------------------------- }
{ Initialisation                                                         }
{ --------------------------------------------------------------------- }

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 {$IFDEF FPC}
  Driver := VGA;
  Mode := VGAHi;
 {$ELSE}
  Driver := Detect;
  Mode := VGAHi;
 {$ENDIF}
 InitGraph(Driver, Mode, '');
 ErrCode := GraphResult;
 If ErrCode = grOk Then Begin
  SetColor(White);
  SetLineStyle(0, 0, 1);
 End
  Else
 Begin
  WriteLn('Erreur graphique : ', GraphErrorMsg(ErrCode));
  Halt(1);
 End;
 ScreenWidth := GetMaxX + 1;
 ScreenHeight := GetMaxY + 1;
 SetTextStyle(DefaultFont, HorizDir, 1);
 VX1 := PANEL_W + 2; VY1 := PANEL_Y + 1;
 VX2 := ScreenWidth - 2; VY2 := ScreenHeight - STATUS_H - 2;
End;

Procedure AllocAll;
Begin
 If HeapFree < 280000 Then Begin
  WriteLn('Memoire insuffisante');
  Halt(1);
 End;
 New(Geoms); New(UndoBuf); New(AFLib);
 New(MV); New(MQ); New(PSX); New(PSY); New(PSZ); New(QDep); New(QOrd);
 FillChar(Geoms^, SizeOf(TGeomArr), 0);
 FillChar(UndoBuf^, SizeOf(TGeomArr), 0);
 FillChar(AFLib^, SizeOf(TAFLib), 0);
End;

Procedure Initialize;
Var FN: String;
Begin
 AllocAll;
 InitializeGraphics;
 InitMouseDriver;
 InitMenus;
 InitToolbar;
 Res := 1; RenderMode := RM_SHADED;
 ShowAxes := True; ShowGrid := True; ShowSel := True;
 CamAz := -145; CamEl := 25; CamZoom := 40; CamPX := 0; CamPY := 0;
 ViewName := 'Iso';
 ComputeView;
 FlAlt := 1000; FlMach := 0.2; AlphaMin := -4; AlphaMax := 16;
 MiscDrag := 0.10; SkinDens := 3.0;
 AFNext := 1; PolOK := False;
 MenuActive := False; ActiveMenu := -1; ActiveMenuItem := -1; MenuSaved := False;
 DragMode := 0; DragRow := -1;
 Running := True; NeedAll := True; StatusMsg := '';
 OldMouseButtons := 0; OldMouseX := 0; OldMouseY := 0;
 CurTab := 0; CurGrp := 1; ParSel := 0; ParFocus := False; ParAll := False;
 UndoValid := False; Modified := False;
 GeomCount := 0; Sel := -1; BrowTop := 0; NV := 0; NQ := 0;
 ModelName := '';
 If ParamCount >= 1 Then Begin
  FN := ParamStr(1);
  If LoadModel(FN) Then StatusMsg := 'Ouvert : ' + FN
  Else Begin
   ExampleLight;
   StatusMsg := 'Echec : ' + FN;
  End;
 End
 Else ExampleLight;
 ParAll := False;
 If Sel >= 0 Then RefreshParams;
 BuildMesh;
 FitView;
 Modified := False;
 ShowMouseCursor;
End;

Procedure Cleanup;
Begin
 HideMouseCursor;
 CloseGraph;
End;

Procedure MainLoop;
Begin
 While Running Do Begin
  HandleMouseEvent;
  HandleKeyboardEvent;
  If NeedAll Or (MenuActive And (NeedView Or NeedPanel)) Then Begin
   If Not MenuActive Then RedrawAll
   Else Begin
    MenuClose;
    RedrawAll;
   End;
  End
  Else Begin
   If NeedPanel Then Begin
    If MeshDirty Then BuildMesh;
    HideMouseCursor;
    DrawPanel;
    DrawToolbar;
    DrawStatusBar;
    ShowMouseCursor;
    NeedPanel := False;
   End;
   If NeedView Then Begin
    DrawScene(DragMode <> 0);
    DrawStatusBar;
    NeedView := False;
   End;
  End;
  Delay(10);
 End;
End;

{ --------------------------------------------------------------------- }
{ Point d'entree                                                         }
{ --------------------------------------------------------------------- }

BEGIN
 If (ParamStr(1) = '/?') Or (ParamStr(1) = '--help') Or (ParamStr(1) = '-h') Then Begin
  WriteLn('OPENVSP - Clone d''OpenVSP : modeleur parametrique de geometrie d''avions.');
  WriteLn;
  WriteLn('Syntaxe : OPENVSP [fichier.VSP]');
  WriteLn;
  WriteLn(' fichier.VSP  Fichier de modele (optionnel)');
  Halt;
 End;
 Initialize;
 MainLoop;
 Cleanup;
END.
