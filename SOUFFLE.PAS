{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal 7, Free Pascal)
  @description: Soufflerie - simulateur aerodynamique 2D pour profils
                d'aile au format .PRO.

  Ligne de commande :
    SOUFFLE [fichier.PRO]

  Format .PRO supporte :
    $nom
    Nom du profil
    $coord
    x1   y1
    x2   y2
    ...
    $endcoord
}

Program Souffle;

{$IFDEF FPC}
 {$MODE TP}
 {$Q-}
 {$R-}
{$ENDIF}

Uses
 {$IFDEF FPC}
  Crt, PtcGraph, PtcCrt, PtcMouse, Dos
 {$ELSE}
  Crt, Graph, Dos
 {$ENDIF};

Const
 PROG_TITLE         = 'Soufflerie 1.00 - Avionix';

 MENUBAR_HEIGHT     = 20;
 STATUSBAR_HEIGHT   = 20;

 MAX_PROFILE_POINTS = 256;
 MAX_PARTICLES      = 220;
 TRAIL_LEN          = 10;

 NUM_MENUS          = 5;
 MENU_FILE          = 0;
 MENU_PROFILE       = 1;
 MENU_SIM           = 2;
 MENU_VIEW          = 3;
 MENU_HELP          = 4;

 MAX_MENU_ITEMS     = 12;

 { Modes d'affichage }
 SHOW_PROFILE       = 1;
 SHOW_CHORD         = 2;
 SHOW_GRID          = 4;
 SHOW_PARTICLES     = 8;
 SHOW_TRAILS        = 16;
 SHOW_PRESSURE      = 32;

Type
 TPoint2 = Record
  X, Y : Real;
 End;

 TProfile = Record
  Name        : String[40];
  Count       : Integer;
  Pts         : Array[0..MAX_PROFILE_POINTS-1] Of TPoint2;
  { Bornes brutes (avant rotation/normalisation) }
  MinX, MaxX  : Real;
  MinY, MaxY  : Real;
  Loaded      : Boolean;
  FileName    : String;
 End;

 TParticle = Record
  Active : Boolean;
  X, Y   : Real;
  TX, TY : Array[0..TRAIL_LEN-1] Of Integer;
  TLen   : Integer;
 End;

 TMenuItem = Record
  Caption   : String[30];
  Shortcut  : String[10];
  Enabled   : Boolean;
  Checked   : Boolean;
  Separator : Boolean;
 End;

 TMenu = Record
  Title     : String[15];
  Items     : Array[0..MAX_MENU_ITEMS-1] Of TMenuItem;
  ItemCount : Byte;
  X, Width  : Integer;
 End;

Var
 { Etat graphique }
 ScreenWidth, ScreenHeight : Integer;
 CanvasTop, CanvasBottom   : Integer;

 { Profil charge }
 Profile     : TProfile;

 { Vue / placement de l'airfoil sur le canvas }
 ChordPixels : Integer;       { longueur de corde a l'ecran }
 OriginX     : Integer;       { centre X de l'airfoil }
 OriginY     : Integer;       { centre Y de l'airfoil }

 { Parametres aerodynamiques }
 AoADeg      : Real;          { angle d'attaque, en degres }
 WindSpeed   : Real;          { vitesse d'avancement des particules (px/iter) }

 { Affichage }
 ViewFlags   : Word;
 SimRunning  : Boolean;

 { Particules }
 Parts       : Array[0..MAX_PARTICLES-1] Of TParticle;

 { Menus }
 Menus       : Array[0..NUM_MENUS-1] Of TMenu;
 MenuActive  : Boolean;
 ActiveMenu  : Integer;
 ActiveMenuItem : Integer;

 { Souris }
 MouseX, MouseY       : Integer;
 MouseButtons         : Integer;
 OldMouseX, OldMouseY : Integer;
 OldMouseButtons      : Integer;
 MouseAvailable       : Boolean;

 { Boucle principale }
 Running    : Boolean;
 NeedRedraw : Boolean;

 { Polygone airfoil pre-calcule (apres rotation+placement), en pixels }
 PolyX, PolyY : Array[0..MAX_PROFILE_POINTS-1] Of Integer;
 PolyN        : Integer;

 { Tampon de message en bas }
 StatusMsg    : String;

{ --------------------------------------------------------------------- }
{ Helpers                                                               }
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

Function MinI(A, B: Integer): Integer;
Begin If A < B Then MinI := A Else MinI := B; End;

Function MaxI(A, B: Integer): Integer;
Begin If A > B Then MaxI := A Else MaxI := B; End;

{ --------------------------------------------------------------------- }
{ Gestion de la souris                                                  }
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
{ Lecture d'un fichier .PRO                                             }
{ --------------------------------------------------------------------- }

Function TrimStr(Const S: String): String;
Var I, J: Integer;
Begin
 I := 1; J := Length(S);
 While (I <= J) And ((S[I] = ' ') Or (S[I] = #9)) Do Inc(I);
 While (J >= I) And ((S[J] = ' ') Or (S[J] = #9) Or (S[J] = #13)) Do Dec(J);
 If J < I Then TrimStr := '' Else TrimStr := Copy(S, I, J - I + 1);
End;

{ Lit deux reels dans une ligne separes par espaces/tabs.
  Retourne True si OK. }
Function ParseXY(Const S: String; Var X, Y: Real): Boolean;
Var
 I, L : Integer;
 SX, SY : String;
 Code : Integer;
Begin
 ParseXY := False;
 L := Length(S);
 I := 1;
 While (I <= L) And ((S[I] = ' ') Or (S[I] = #9)) Do Inc(I);
 If I > L Then Exit;
 SX := '';
 While (I <= L) And (S[I] <> ' ') And (S[I] <> #9) Do Begin
  SX := SX + S[I]; Inc(I);
 End;
 While (I <= L) And ((S[I] = ' ') Or (S[I] = #9)) Do Inc(I);
 If I > L Then Exit;
 SY := '';
 While (I <= L) And (S[I] <> ' ') And (S[I] <> #9) And (S[I] <> #13) Do Begin
  SY := SY + S[I]; Inc(I);
 End;
 Val(SX, X, Code); If Code <> 0 Then Exit;
 Val(SY, Y, Code); If Code <> 0 Then Exit;
 ParseXY := True;
End;

Function LoadProfile(Const FileName: String; Var P: TProfile): Boolean;
Var
 F      : Text;
 Line   : String;
 Tag    : String;
 InCoord: Boolean;
 X, Y   : Real;
 First  : Boolean;
Begin
 LoadProfile := False;
 P.Loaded := False;
 P.Count := 0;
 P.Name := '';
 P.FileName := FileName;

 {$I-}
 Assign(F, FileName);
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;

 InCoord := False;
 First   := True;

 While Not Eof(F) Do Begin
  ReadLn(F, Line);
  Line := TrimStr(Line);
  If Line = '' Then Continue;
  Tag := UpStr(Line);
  If Tag = '$NOM' Then Begin
   If Not Eof(F) Then Begin
    ReadLn(F, Line);
    P.Name := TrimStr(Line);
   End;
   Continue;
  End;
  If Tag = '$COORD' Then Begin
   InCoord := True;
   Continue;
  End;
  If Tag = '$ENDCOORD' Then Begin
   InCoord := False;
   Continue;
  End;
  If InCoord Then Begin
   If ParseXY(Line, X, Y) Then Begin
    If P.Count >= MAX_PROFILE_POINTS Then Continue;
    P.Pts[P.Count].X := X;
    P.Pts[P.Count].Y := Y;
    If First Then Begin
     P.MinX := X; P.MaxX := X;
     P.MinY := Y; P.MaxY := Y;
     First := False;
    End
    Else Begin
     If X < P.MinX Then P.MinX := X;
     If X > P.MaxX Then P.MaxX := X;
     If Y < P.MinY Then P.MinY := Y;
     If Y > P.MaxY Then P.MaxY := Y;
    End;
    Inc(P.Count);
   End;
  End;
 End;

 Close(F);

 If P.Count < 3 Then Exit;
 If P.Name = '' Then P.Name := FileName;
 P.Loaded := True;
 LoadProfile := True;
End;

{ Profil "par defaut" (NACA 0012 simplifie) si aucun fichier charge. }
Procedure MakeDefaultProfile(Var P: TProfile);
Var
 I : Integer;
 T, X, Yc : Real;
Const
 Steps = 32;
Begin
 P.Name := 'NACA 0012 (defaut)';
 P.FileName := '';
 P.Count := 0;
 { Extrados : x de 0 a 100 }
 For I := 0 To Steps Do Begin
  T := I / Steps;
  X := 100.0 * T;
  Yc := 50.0 * 0.12 * ( 0.2969*Sqrt(T)
                       - 0.1260*T
                       - 0.3516*T*T
                       + 0.2843*T*T*T
                       - 0.1015*T*T*T*T );
  P.Pts[P.Count].X := X;
  P.Pts[P.Count].Y := Yc;
  Inc(P.Count);
 End;
 { Intrados : x de 100 a 0 }
 For I := Steps - 1 DownTo 0 Do Begin
  T := I / Steps;
  X := 100.0 * T;
  Yc := -50.0 * 0.12 * ( 0.2969*Sqrt(T)
                        - 0.1260*T
                        - 0.3516*T*T
                        + 0.2843*T*T*T
                        - 0.1015*T*T*T*T );
  P.Pts[P.Count].X := X;
  P.Pts[P.Count].Y := Yc;
  Inc(P.Count);
 End;
 P.MinX := 0.0; P.MaxX := 100.0;
 P.MinY := -6.0; P.MaxY := 6.0;
 P.Loaded := True;
End;

{ --------------------------------------------------------------------- }
{ Geometrie : rotation AoA + projection en pixels                       }
{ --------------------------------------------------------------------- }

Procedure ComputePolygon;
Var
 I    : Integer;
 Ca, Sa : Real;
 Cx, Cy : Real;
 X, Y, Xr, Yr : Real;
 Scale  : Real;
Begin
 PolyN := 0;
 If Not Profile.Loaded Then Exit;

 { Centre de la corde (sur axe x). On considere [MinX..MaxX] comme corde. }
 Cx := (Profile.MinX + Profile.MaxX) * 0.5;
 Cy := 0.0;

 If (Profile.MaxX - Profile.MinX) > 0.001 Then
  Scale := ChordPixels / (Profile.MaxX - Profile.MinX)
 Else
  Scale := 1.0;

 Ca := Cos(-AoADeg * Pi / 180.0);
 Sa := Sin(-AoADeg * Pi / 180.0);

 For I := 0 To Profile.Count - 1 Do Begin
  X := Profile.Pts[I].X - Cx;
  Y := Profile.Pts[I].Y - Cy;
  Xr := X * Ca - Y * Sa;
  Yr := X * Sa + Y * Ca;
  PolyX[I] := OriginX + Round(Xr * Scale);
  PolyY[I] := OriginY - Round(Yr * Scale); { Y a l'envers a l'ecran }
 End;
 PolyN := Profile.Count;
End;

{ Point dans polygone (algorithme du ray-casting) }
Function PointInPoly(PxF, PyF: Real): Boolean;
Var
 I, J : Integer;
 Inside : Boolean;
 Xi, Yi, Xj, Yj : Real;
Begin
 Inside := False;
 If PolyN < 3 Then Begin PointInPoly := False; Exit; End;
 J := PolyN - 1;
 For I := 0 To PolyN - 1 Do Begin
  Xi := PolyX[I]; Yi := PolyY[I];
  Xj := PolyX[J]; Yj := PolyY[J];
  If ((Yi > PyF) <> (Yj > PyF)) And
     (PxF < (Xj - Xi) * (PyF - Yi) / (Yj - Yi + 0.0001) + Xi) Then
   Inside := Not Inside;
  J := I;
 End;
 PointInPoly := Inside;
End;

{ Distance au plus proche segment du polygone et tangente unitaire au segment.
  Retourne distance ; renvoie aussi (Tx,Ty) tangente normalisee dans le sens
  croissant de l'indice. }
Function NearestEdge(PxF, PyF: Real; Var Tx, Ty: Real): Real;
Var
 I, NextI : Integer;
 Ax, Ay, Bx, By : Real;
 Dx, Dy, T : Real;
 Cx, Cy, Dist, L : Real;
 BestDist : Real;
Begin
 BestDist := 1.0E30;
 Tx := 1.0; Ty := 0.0;
 If PolyN < 3 Then Begin NearestEdge := BestDist; Exit; End;
 For I := 0 To PolyN - 1 Do Begin
  NextI := I + 1;
  If NextI >= PolyN Then NextI := 0;
  Ax := PolyX[I]; Ay := PolyY[I];
  Bx := PolyX[NextI]; By := PolyY[NextI];
  Dx := Bx - Ax; Dy := By - Ay;
  L := Dx*Dx + Dy*Dy;
  If L < 0.0001 Then Continue;
  T := ((PxF - Ax)*Dx + (PyF - Ay)*Dy) / L;
  If T < 0.0 Then T := 0.0;
  If T > 1.0 Then T := 1.0;
  Cx := Ax + T*Dx;
  Cy := Ay + T*Dy;
  Dist := Sqrt((PxF-Cx)*(PxF-Cx) + (PyF-Cy)*(PyF-Cy));
  If Dist < BestDist Then Begin
   BestDist := Dist;
   L := Sqrt(Dx*Dx + Dy*Dy);
   Tx := Dx / L;
   Ty := Dy / L;
  End;
 End;
 NearestEdge := BestDist;
End;

{ --------------------------------------------------------------------- }
{ Particules / simulation                                               }
{ --------------------------------------------------------------------- }

Procedure ResetParticles;
Var I, J: Integer;
Begin
 For I := 0 To MAX_PARTICLES - 1 Do Begin
  Parts[I].Active := False;
  Parts[I].TLen := 0;
  For J := 0 To TRAIL_LEN - 1 Do Begin
   Parts[I].TX[J] := 0;
   Parts[I].TY[J] := 0;
  End;
 End;
End;

Procedure EmitParticle(I: Integer);
Var
 H : Integer;
 Y : Integer;
Begin
 H := CanvasBottom - CanvasTop - 4;
 If H < 10 Then H := 10;
 { Repartition reguliere + petit jitter pour ne pas saturer }
 Y := CanvasTop + 2 + ((I * 7 + Random(H)) Mod H);
 Parts[I].X := 4;
 Parts[I].Y := Y;
 Parts[I].Active := True;
 Parts[I].TLen := 0;
End;

Procedure StepParticles;
Var
 I, K : Integer;
 Vx, Vy : Real;
 Nx, Ny : Real;
 Tx, Ty : Real;
 Dist   : Real;
 Px, Py : Integer;
Begin
 Vx := WindSpeed;
 Vy := 0.0;
 For I := 0 To MAX_PARTICLES - 1 Do Begin
  If Not Parts[I].Active Then Begin
   { Reveille progressivement }
   If Random(8) = 0 Then EmitParticle(I);
   Continue;
  End;

  Nx := Parts[I].X + Vx;
  Ny := Parts[I].Y + Vy;

  { Si on est proche du polygone, on devie tangentiellement. }
  If PolyN >= 3 Then Begin
   Dist := NearestEdge(Nx, Ny, Tx, Ty);
   If PointInPoly(Nx, Ny) Or (Dist < 2.5) Then Begin
    { On choisit le sens de la tangente le plus proche du flux. }
    If (Tx * Vx + Ty * Vy) < 0 Then Begin
     Tx := -Tx; Ty := -Ty;
    End;
    Nx := Parts[I].X + Tx * WindSpeed;
    Ny := Parts[I].Y + Ty * WindSpeed;
   End
   Else If Dist < 18.0 Then Begin
    { Influence douce : on melange un peu de tangente. }
    If (Tx * Vx + Ty * Vy) < 0 Then Begin
     Tx := -Tx; Ty := -Ty;
    End;
    Nx := Parts[I].X + (Vx*0.6 + Tx*WindSpeed*0.4);
    Ny := Parts[I].Y + (Vy*0.6 + Ty*WindSpeed*0.4);
   End;
  End;

  { Decale la trainee. }
  If Parts[I].TLen < TRAIL_LEN Then Inc(Parts[I].TLen);
  For K := TRAIL_LEN - 1 DownTo 1 Do Begin
   Parts[I].TX[K] := Parts[I].TX[K-1];
   Parts[I].TY[K] := Parts[I].TY[K-1];
  End;
  Parts[I].TX[0] := Round(Parts[I].X);
  Parts[I].TY[0] := Round(Parts[I].Y);

  Parts[I].X := Nx;
  Parts[I].Y := Ny;

  Px := Round(Nx);
  Py := Round(Ny);

  { Sortie du canvas -> re-emission ailleurs. }
  If (Px > ScreenWidth - 4) Or
     (Px < 0) Or
     (Py < CanvasTop + 1) Or
     (Py > CanvasBottom - 1) Then
   Parts[I].Active := False;
 End;
End;

{ --------------------------------------------------------------------- }
{ Affichage                                                             }
{ --------------------------------------------------------------------- }

Procedure DrawAirfoil;
Var I, NextI: Integer;
Begin
 If PolyN < 3 Then Exit;

 { Remplissage indicatif (simple fill triangle fan depuis le centre).
   On laisse FloodFill de cote (peu fiable selon le BGI). }
 SetColor(LightGray);
 SetFillStyle(SolidFill, DarkGray);
 { Trace du contour }
 SetColor(White);
 For I := 0 To PolyN - 1 Do Begin
  NextI := I + 1;
  If NextI >= PolyN Then NextI := 0;
  Line(PolyX[I], PolyY[I], PolyX[NextI], PolyY[NextI]);
 End;
End;

Procedure DrawChord;
Var
 Ca, Sa : Real;
 X1, Y1, X2, Y2 : Integer;
 Half : Real;
Begin
 If Not Profile.Loaded Then Exit;
 Half := ChordPixels * 0.5;
 Ca := Cos(-AoADeg * Pi / 180.0);
 Sa := Sin(-AoADeg * Pi / 180.0);
 X1 := OriginX + Round(-Half * Ca);
 Y1 := OriginY - Round(-Half * Sa);
 X2 := OriginX + Round( Half * Ca);
 Y2 := OriginY - Round( Half * Sa);
 SetColor(Yellow);
 SetLineStyle(DottedLn, 0, NormWidth);
 Line(X1, Y1, X2, Y2);
 SetLineStyle(SolidLn, 0, NormWidth);
End;

Procedure DrawGrid;
Var
 X, Y, Step : Integer;
Begin
 Step := 40;
 SetColor(DarkGray);
 X := 0;
 While X < ScreenWidth Do Begin
  Line(X, CanvasTop + 1, X, CanvasBottom - 1);
  Inc(X, Step);
 End;
 Y := CanvasTop + 1;
 While Y < CanvasBottom Do Begin
  Line(0, Y, ScreenWidth - 1, Y);
  Inc(Y, Step);
 End;
End;

Procedure DrawParticles;
Var
 I, K : Integer;
 Col  : Integer;
Begin
 For I := 0 To MAX_PARTICLES - 1 Do Begin
  If Not Parts[I].Active Then Continue;
  If (ViewFlags And SHOW_TRAILS) <> 0 Then Begin
   For K := 0 To Parts[I].TLen - 2 Do Begin
    If K < 3 Then Col := LightCyan
    Else If K < 6 Then Col := Cyan
    Else Col := Blue;
    SetColor(Col);
    Line(Parts[I].TX[K], Parts[I].TY[K],
         Parts[I].TX[K+1], Parts[I].TY[K+1]);
   End;
  End;
  If (ViewFlags And SHOW_PARTICLES) <> 0 Then Begin
   SetColor(White);
   PutPixel(Round(Parts[I].X), Round(Parts[I].Y), White);
   PutPixel(Round(Parts[I].X)+1, Round(Parts[I].Y), LightCyan);
  End;
 End;
End;

Procedure DrawPressureHint;
{ Indication visuelle : marque le bord d'attaque (haute pression) en rouge
  et le bord de fuite (basse pression) en bleu. Purement decoratif :
  pas de resolution de Navier-Stokes ! }
Var
 Ca, Sa : Real;
 Half : Real;
 Xl, Yl, Xr, Yr : Integer;
Begin
 If Not Profile.Loaded Then Exit;
 Half := ChordPixels * 0.5;
 Ca := Cos(-AoADeg * Pi / 180.0);
 Sa := Sin(-AoADeg * Pi / 180.0);
 Xl := OriginX + Round(-Half * Ca);
 Yl := OriginY - Round(-Half * Sa);
 Xr := OriginX + Round( Half * Ca);
 Yr := OriginY - Round( Half * Sa);
 SetColor(LightRed);
 Circle(Xl, Yl, 5);
 SetColor(LightBlue);
 Circle(Xr, Yr, 5);
End;

Procedure DrawCanvas;
Begin
 { Fond du canvas }
 SetFillStyle(SolidFill, Black);
 Bar(0, CanvasTop, ScreenWidth - 1, CanvasBottom);

 If (ViewFlags And SHOW_GRID) <> 0 Then DrawGrid;
 If (ViewFlags And SHOW_CHORD) <> 0 Then DrawChord;
 If (ViewFlags And SHOW_PRESSURE) <> 0 Then DrawPressureHint;
 If (ViewFlags And SHOW_PROFILE) <> 0 Then DrawAirfoil;
 If ((ViewFlags And SHOW_PARTICLES) <> 0) Or
    ((ViewFlags And SHOW_TRAILS) <> 0) Then
  DrawParticles;
End;

Procedure DrawStatusBar;
Var
 Y : Integer;
 S : String;
Begin
 Y := ScreenHeight - STATUSBAR_HEIGHT;
 SetFillStyle(SolidFill, LightGray);
 Bar(0, Y, ScreenWidth - 1, ScreenHeight - 1);
 SetColor(DarkGray);
 Line(0, Y, ScreenWidth - 1, Y);

 SetColor(Black);
 OutTextXY(5, Y + 5, 'Profil: ' + Profile.Name);
 OutTextXY(250, Y + 5, 'AoA: ' + RealToStr(AoADeg, 1) + ' deg');
 OutTextXY(360, Y + 5, 'V: ' + RealToStr(WindSpeed, 1));
 If SimRunning Then S := '[Simulation ON]' Else S := '[Simulation OFF]';
 OutTextXY(460, Y + 5, S);
End;

{ --------------------------------------------------------------------- }
{ Menus                                                                 }
{ --------------------------------------------------------------------- }

Procedure ZeroItem(Var M: TMenu);
Var I: Integer;
Begin
 For I := 0 To MAX_MENU_ITEMS - 1 Do Begin
  M.Items[I].Caption   := '';
  M.Items[I].Shortcut  := '';
  M.Items[I].Enabled   := True;
  M.Items[I].Checked   := False;
  M.Items[I].Separator := False;
 End;
End;

Procedure InitMenus;
Begin
 ZeroItem(Menus[MENU_FILE]);
 Menus[MENU_FILE].Title := 'Fichier';
 Menus[MENU_FILE].ItemCount := 5;
 Menus[MENU_FILE].Items[0].Caption  := 'Ouvrir .PRO...';
 Menus[MENU_FILE].Items[0].Shortcut := 'Ctrl+O';
 Menus[MENU_FILE].Items[1].Caption  := 'Profil par defaut';
 Menus[MENU_FILE].Items[1].Shortcut := '';
 Menus[MENU_FILE].Items[2].Separator := True;
 Menus[MENU_FILE].Items[3].Caption  := 'Recharger';
 Menus[MENU_FILE].Items[3].Shortcut := 'F3';
 Menus[MENU_FILE].Items[4].Caption  := 'Quitter';
 Menus[MENU_FILE].Items[4].Shortcut := 'Alt+F4';

 ZeroItem(Menus[MENU_PROFILE]);
 Menus[MENU_PROFILE].Title := 'Profil';
 Menus[MENU_PROFILE].ItemCount := 5;
 Menus[MENU_PROFILE].Items[0].Caption  := 'Information';
 Menus[MENU_PROFILE].Items[0].Shortcut := 'F1';
 Menus[MENU_PROFILE].Items[1].Separator := True;
 Menus[MENU_PROFILE].Items[2].Caption  := 'AoA +1 degre';
 Menus[MENU_PROFILE].Items[2].Shortcut := '+';
 Menus[MENU_PROFILE].Items[3].Caption  := 'AoA -1 degre';
 Menus[MENU_PROFILE].Items[3].Shortcut := '-';
 Menus[MENU_PROFILE].Items[4].Caption  := 'AoA = 0';
 Menus[MENU_PROFILE].Items[4].Shortcut := '0';

 ZeroItem(Menus[MENU_SIM]);
 Menus[MENU_SIM].Title := 'Simulation';
 Menus[MENU_SIM].ItemCount := 6;
 Menus[MENU_SIM].Items[0].Caption  := 'Demarrer';
 Menus[MENU_SIM].Items[0].Shortcut := 'F5';
 Menus[MENU_SIM].Items[1].Caption  := 'Arreter';
 Menus[MENU_SIM].Items[1].Shortcut := 'F6';
 Menus[MENU_SIM].Items[2].Caption  := 'Reinitialiser';
 Menus[MENU_SIM].Items[2].Shortcut := 'F2';
 Menus[MENU_SIM].Items[3].Separator := True;
 Menus[MENU_SIM].Items[4].Caption  := 'Vent +';
 Menus[MENU_SIM].Items[4].Shortcut := 'PgUp';
 Menus[MENU_SIM].Items[5].Caption  := 'Vent -';
 Menus[MENU_SIM].Items[5].Shortcut := 'PgDn';

 ZeroItem(Menus[MENU_VIEW]);
 Menus[MENU_VIEW].Title := 'Affichage';
 Menus[MENU_VIEW].ItemCount := 6;
 Menus[MENU_VIEW].Items[0].Caption := 'Profil';
 Menus[MENU_VIEW].Items[0].Checked := True;
 Menus[MENU_VIEW].Items[1].Caption := 'Corde';
 Menus[MENU_VIEW].Items[1].Checked := True;
 Menus[MENU_VIEW].Items[2].Caption := 'Grille';
 Menus[MENU_VIEW].Items[3].Caption := 'Particules';
 Menus[MENU_VIEW].Items[3].Checked := True;
 Menus[MENU_VIEW].Items[4].Caption := 'Trainees';
 Menus[MENU_VIEW].Items[4].Checked := True;
 Menus[MENU_VIEW].Items[5].Caption := 'Indicateur pression';

 ZeroItem(Menus[MENU_HELP]);
 Menus[MENU_HELP].Title := 'Aide';
 Menus[MENU_HELP].ItemCount := 2;
 Menus[MENU_HELP].Items[0].Caption  := 'Touches...';
 Menus[MENU_HELP].Items[0].Shortcut := '';
 Menus[MENU_HELP].Items[1].Caption  := 'A propos...';
 Menus[MENU_HELP].Items[1].Shortcut := '';
End;

Procedure DrawMenuBar;
Var
 I, X, W: Integer;
Begin
 SetFillStyle(SolidFill, LightGray);
 Bar(0, 0, ScreenWidth - 1, MENUBAR_HEIGHT - 1);
 SetColor(DarkGray);
 Line(0, MENUBAR_HEIGHT - 1, ScreenWidth - 1, MENUBAR_HEIGHT - 1);

 X := 5;
 For I := 0 To NUM_MENUS - 1 Do Begin
  Menus[I].X := X;
  W := TextWidth(Menus[I].Title);
  Menus[I].Width := W + 80; { largeur du panneau deroulant }
  If MenuActive And (ActiveMenu = I) Then Begin
   SetFillStyle(SolidFill, Blue);
   Bar(X - 2, 2, X + W + 2, MENUBAR_HEIGHT - 3);
   SetColor(White);
  End
  Else SetColor(Black);
  OutTextXY(X, 5, Menus[I].Title);
  X := X + W + 15;
 End;

 { Titre du programme a droite }
 SetColor(DarkGray);
 OutTextXY(ScreenWidth - 8*Length(PROG_TITLE) - 5, 5, PROG_TITLE);
End;

Procedure DrawMenuPopup(MenuIdx: Integer);
Var
 I, ItemHeight, X, Y, W, H, Wmax, WSc : Integer;
 Cap, Sc : String;
Begin
 If (MenuIdx < 0) Or (MenuIdx >= NUM_MENUS) Then Exit;
 ItemHeight := 16;

 { Calcul largeur a partir du contenu }
 Wmax := 0;
 For I := 0 To Menus[MenuIdx].ItemCount - 1 Do Begin
  Cap := Menus[MenuIdx].Items[I].Caption;
  Sc  := Menus[MenuIdx].Items[I].Shortcut;
  W := TextWidth(Cap) + 25 + TextWidth(Sc) + 10;
  If W > Wmax Then Wmax := W;
 End;
 If Wmax < 130 Then Wmax := 130;
 Menus[MenuIdx].Width := Wmax;

 X := Menus[MenuIdx].X - 2;
 Y := MENUBAR_HEIGHT;
 W := Wmax;
 H := Menus[MenuIdx].ItemCount * ItemHeight + 4;

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
   Line(X + 4, Y + 2 + I * ItemHeight + ItemHeight Div 2,
        X + W - 4, Y + 2 + I * ItemHeight + ItemHeight Div 2);
  End
  Else Begin
   If ActiveMenuItem = I Then Begin
    SetFillStyle(SolidFill, Blue);
    Bar(X + 2, Y + 2 + I * ItemHeight,
        X + W - 2, Y + 2 + (I + 1) * ItemHeight);
    SetColor(White);
   End
   Else Begin
    If Menus[MenuIdx].Items[I].Enabled Then SetColor(Black)
    Else SetColor(DarkGray);
   End;
   If Menus[MenuIdx].Items[I].Checked Then
    OutTextXY(X + 5, Y + 4 + I * ItemHeight, #251);
   OutTextXY(X + 20, Y + 4 + I * ItemHeight,
             Menus[MenuIdx].Items[I].Caption);
   Sc := Menus[MenuIdx].Items[I].Shortcut;
   If Sc <> '' Then Begin
    WSc := TextWidth(Sc);
    OutTextXY(X + W - WSc - 8, Y + 4 + I * ItemHeight, Sc);
   End;
  End;
 End;
End;

Function MenuBarHitTest(Mx, My: Integer): Integer;
Var I, X1, X2: Integer;
Begin
 MenuBarHitTest := -1;
 If My >= MENUBAR_HEIGHT Then Exit;
 For I := 0 To NUM_MENUS - 1 Do Begin
  X1 := Menus[I].X - 2;
  X2 := Menus[I].X + TextWidth(Menus[I].Title) + 2;
  If (Mx >= X1) And (Mx <= X2) Then Begin
   MenuBarHitTest := I;
   Exit;
  End;
 End;
End;

Function MenuItemHitTest(Mx, My, MenuIdx: Integer): Integer;
Var Idx, Top, Bot: Integer;
Begin
 MenuItemHitTest := -1;
 If (MenuIdx < 0) Or (MenuIdx >= NUM_MENUS) Then Exit;
 Top := MENUBAR_HEIGHT;
 Bot := Top + Menus[MenuIdx].ItemCount * 16 + 4;
 If (Mx < Menus[MenuIdx].X - 2) Or
    (Mx > Menus[MenuIdx].X - 2 + Menus[MenuIdx].Width) Or
    (My < Top) Or (My > Bot) Then Exit;
 Idx := (My - Top - 2) Div 16;
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
{ Boites de dialogue simples (saisie et message)                        }
{ --------------------------------------------------------------------- }

Procedure DrawDialogBox(X1, Y1, X2, Y2: Integer; Const Title: String);
Begin
 SetFillStyle(SolidFill, LightGray);
 Bar(X1, Y1, X2, Y2);
 SetColor(White);
 Rectangle(X1, Y1, X2, Y2);
 SetColor(DarkGray);
 Rectangle(X1+1, Y1+1, X2-1, Y2-1);

 SetFillStyle(SolidFill, Blue);
 Bar(X1+2, Y1+2, X2-2, Y1+16);
 SetColor(White);
 OutTextXY(X1+6, Y1+5, Title);
 SetColor(Black);
End;

Procedure ShowMessage(Const Title, Msg: String);
Var
 X1, Y1, X2, Y2 : Integer;
 W : Integer;
 K : Char;
Begin
 W := TextWidth(Msg) + 40;
 If W < TextWidth(Title) + 40 Then W := TextWidth(Title) + 40;
 If W < 200 Then W := 200;
 X1 := (ScreenWidth - W) Div 2;
 Y1 := (ScreenHeight - 100) Div 2;
 X2 := X1 + W;
 Y2 := Y1 + 100;
 HideMouseCursor;
 DrawDialogBox(X1, Y1, X2, Y2, Title);
 OutTextXY(X1 + 20, Y1 + 35, Msg);
 SetFillStyle(SolidFill, DarkGray);
 Bar(X1 + W Div 2 - 25, Y2 - 25, X1 + W Div 2 + 25, Y2 - 10);
 SetColor(White);
 OutTextXY(X1 + W Div 2 - 8, Y2 - 22, 'OK');
 SetColor(Black);
 ShowMouseCursor;
 { Attend que le bouton de la souris soit relache pour ne pas
   interpreter le clic ayant declenche l'ouverture comme un clic
   sur OK. On purge aussi les touches en attente (p.ex. Enter qui
   a valide l'item de menu). }
 Repeat
  GetMouseLocal(MouseX, MouseY, MouseButtons);
  If (MouseButtons And 1) = 0 Then Break;
  Delay(10);
 Until False;
 While KeyPressed Do Begin
  K := ReadKey;
  If K = #0 Then If KeyPressed Then ReadKey;
 End;
 OldMouseButtons := 0;
 { Attend ENTER / ESC / espace / nouveau clic. }
 Repeat
  If KeyPressed Then Begin
   K := ReadKey;
   If K = #0 Then Begin
    If KeyPressed Then ReadKey;
   End
   Else If (K = #13) Or (K = #27) Or (K = ' ') Then Break;
  End;
  GetMouseLocal(MouseX, MouseY, MouseButtons);
  If ((MouseButtons And 1) <> 0) And ((OldMouseButtons And 1) = 0) Then Begin
   OldMouseButtons := MouseButtons;
   Break;
  End;
  OldMouseButtons := MouseButtons;
  Delay(15);
 Until False;
End;

Function InputString(Const Title, Prompt: String;
                     Var Value: String): Boolean;
Var
 X1, Y1, X2, Y2 : Integer;
 W              : Integer;
 K              : Char;
 Done, OK       : Boolean;
Begin
 W := 380;
 X1 := (ScreenWidth - W) Div 2;
 Y1 := (ScreenHeight - 120) Div 2;
 X2 := X1 + W;
 Y2 := Y1 + 120;

 HideMouseCursor;
 DrawDialogBox(X1, Y1, X2, Y2, Title);
 OutTextXY(X1 + 15, Y1 + 30, Prompt);

 Done := False;
 OK   := False;
 ShowMouseCursor;
 While Not Done Do Begin
  HideMouseCursor;
  SetFillStyle(SolidFill, White);
  Bar(X1 + 15, Y1 + 50, X2 - 15, Y1 + 70);
  SetColor(Black);
  Rectangle(X1 + 14, Y1 + 49, X2 - 14, Y1 + 71);
  OutTextXY(X1 + 18, Y1 + 56, Value + '_');
  ShowMouseCursor;

  While Not KeyPressed Do Delay(10);
  K := ReadKey;
  If K = #0 Then Begin
   ReadKey; { ignore touche etendue }
  End
  Else If K = #13 Then Begin Done := True; OK := True; End
  Else If K = #27 Then Begin Done := True; OK := False; End
  Else If K = #8 Then Begin
   If Length(Value) > 0 Then Delete(Value, Length(Value), 1);
  End
  Else If (Ord(K) >= 32) And (Length(Value) < 80) Then
   Value := Value + K;
 End;
 InputString := OK;
End;

{ --------------------------------------------------------------------- }
{ Actions                                                               }
{ --------------------------------------------------------------------- }

Procedure ComputePlacement;
Var Avail: Integer;
Begin
 Avail := ScreenWidth - 40;
 ChordPixels := Avail Div 2;
 If ChordPixels > 360 Then ChordPixels := 360;
 OriginX := ScreenWidth Div 2;
 OriginY := (CanvasTop + CanvasBottom) Div 2;
End;

Procedure ApplyLoaded;
Begin
 ComputePlacement;
 ComputePolygon;
 ResetParticles;
 NeedRedraw := True;
End;

{ --------------------------------------------------------------------- }
{ Boite de dialogue d'ouverture de fichier (style PSP.PAS)              }
{ --------------------------------------------------------------------- }

Const
 FD_MAXENT  = 256;
 FD_ROWH    = 12;
 FD_NAMECOL = 22;

Type
 TFDEntry = Record
  Name  : String[64];
  Size  : LongInt;
  IsDir : Boolean;
 End;

Var
 FD_Dirs   : Array[0..FD_MAXENT-1] Of TFDEntry;
 FD_Files  : Array[0..FD_MAXENT-1] Of TFDEntry;
 FD_NDirs  : Integer;
 FD_NFiles : Integer;
 FD_CurDir : String;
 FD_NameBuf: String;
 FD_Focus  : Integer; { 0=dossiers, 1=fichiers, 2=nom }
 FD_SelDir, FD_TopDir   : Integer;
 FD_SelFile, FD_TopFile : Integer;
 FD_ShowAll : Boolean;

Procedure FD_Sort(Var A: Array Of TFDEntry; N: Integer);
Var I, J: Integer; T: TFDEntry;
Begin
 For I := 0 To N - 2 Do
  For J := 0 To N - 2 - I Do
   If UpStr(A[J].Name) > UpStr(A[J+1].Name) Then Begin
    T := A[J]; A[J] := A[J+1]; A[J+1] := T;
   End;
End;

Function FD_HasPROExt(Const Nm: String): Boolean;
Var L: Integer;
Begin
 L := Length(Nm);
 FD_HasPROExt := (L >= 4) And
                 (UpCase(Nm[L-3]) = '.') And
                 (UpCase(Nm[L-2]) = 'P') And
                 (UpCase(Nm[L-1]) = 'R') And
                 (UpCase(Nm[L])   = 'O');
End;

Procedure FD_Scan;
Var
 SR : SearchRec;
 E  : TFDEntry;
Begin
 FD_NDirs  := 0;
 FD_NFiles := 0;
 GetDir(0, FD_CurDir);
 FindFirst('*.*', Directory, SR);
 While DosError = 0 Do Begin
  If (SR.Attr And Directory) <> 0 Then
   If (SR.Name <> '.') And (FD_NDirs < FD_MAXENT) Then Begin
    E.Name := SR.Name; E.IsDir := True; E.Size := 0;
    FD_Dirs[FD_NDirs] := E;
    Inc(FD_NDirs);
   End;
  FindNext(SR);
 End;
 {$IFDEF FPC}
  FindClose(SR);
 {$ENDIF}
 FindFirst('*.*', AnyFile, SR);
 While DosError = 0 Do Begin
  If ((SR.Attr And Directory) = 0) And ((SR.Attr And VolumeID) = 0) Then
   If (FD_ShowAll Or FD_HasPROExt(SR.Name)) And (FD_NFiles < FD_MAXENT) Then Begin
    E.Name := SR.Name; E.IsDir := False; E.Size := SR.Size;
    FD_Files[FD_NFiles] := E;
    Inc(FD_NFiles);
   End;
  FindNext(SR);
 End;
 {$IFDEF FPC}
 FindClose(SR);
 {$ENDIF}
 FD_Sort(FD_Dirs,  FD_NDirs);
 FD_Sort(FD_Files, FD_NFiles);
 If FD_SelDir  >= FD_NDirs  Then FD_SelDir  := 0;
 If FD_SelFile >= FD_NFiles Then FD_SelFile := 0;
 FD_TopDir := 0; FD_TopFile := 0;
End;

Procedure FD_EnsureVisible(Var Top: Integer; Sel, Rows: Integer);
Begin
 If Sel < Top Then Top := Sel;
 If Sel >= Top + Rows Then Top := Sel - Rows + 1;
 If Top < 0 Then Top := 0;
End;

Procedure FD_FmtSize(Sz: LongInt; Var S: String);
Begin
 Str(Sz, S);
 While Length(S) < 8 Do S := ' ' + S;
End;

Procedure FD_DrawBevel(X1, Y1, X2, Y2: Integer; Inset: Boolean);
Begin
 If Inset Then Begin
  SetColor(DarkGray);
  Line(X1, Y1, X2, Y1); Line(X1, Y1, X1, Y2);
  SetColor(White);
  Line(X1, Y2, X2, Y2); Line(X2, Y1, X2, Y2);
 End
 Else Begin
  SetColor(White);
  Line(X1, Y1, X2, Y1); Line(X1, Y1, X1, Y2);
  SetColor(DarkGray);
  Line(X1, Y2, X2, Y2); Line(X2, Y1, X2, Y2);
 End;
End;

Procedure FD_DrawButton(X1, Y1, X2, Y2: Integer; Const Caption: String);
Var W: Integer;
Begin
 SetFillStyle(SolidFill, LightGray);
 Bar(X1, Y1, X2, Y2);
 FD_DrawBevel(X1, Y1, X2, Y2, False);
 SetColor(Black);
 W := TextWidth(Caption);
 OutTextXY(X1 + (X2 - X1 - W) Div 2, Y1 + ((Y2 - Y1) - 8) Div 2, Caption);
End;

Procedure FD_DrawList(X1, Y1, X2, Y2: Integer;
                      Var Arr: Array Of TFDEntry; N, Top, Sel: Integer;
                      Active, IsDirList: Boolean);
Var
 Rows, I, Idx, RY: Integer;
 Nm, Sz : String;
Begin
 SetFillStyle(SolidFill, White);
 Bar(X1+1, Y1+1, X2-1, Y2-1);
 Rows := (Y2 - Y1 - 2) Div FD_ROWH;
 For I := 0 To Rows - 1 Do Begin
  Idx := Top + I;
  If Idx >= N Then Break;
  RY := Y1 + 2 + I * FD_ROWH;
  If Idx = Sel Then Begin
   SetFillStyle(SolidFill, Blue);
   If Not Active Then SetFillStyle(SolidFill, DarkGray);
   Bar(X1 + 1, RY - 1, X2 - 1, RY + FD_ROWH - 2);
   SetColor(White);
  End
  Else SetColor(Black);
  If IsDirList Then Nm := '[' + Arr[Idx].Name + ']'
  Else Nm := Arr[Idx].Name;
  If Length(Nm) > FD_NAMECOL Then Nm := Copy(Nm, 1, FD_NAMECOL);
  OutTextXY(X1 + 4, RY, Nm);
  If Not IsDirList Then Begin
   FD_FmtSize(Arr[Idx].Size, Sz);
   OutTextXY(X1 + 4 + FD_NAMECOL * 8 + 8, RY, Sz);
  End;
 End;
 FD_DrawBevel(X1, Y1, X2, Y2, True);
End;

Function FileOpenDialog(Const Title: String; Var FN: String): Boolean;
Var
 DX1, DY1, DX2, DY2 : Integer;
 DirX1, DirY1, DirX2, DirY2 : Integer;
 FilX1, FilY1, FilX2, FilY2 : Integer;
 NamX1, NamY1, NamX2, NamY2 : Integer;
 OkX1,  OkY1,  OkX2,  OkY2  : Integer;
 CcX1,  CcY1,  CcX2,  CcY2  : Integer;
 AllX1, AllY1, AllX2, AllY2 : Integer;
 DirRows, FileRows : Integer;
 Done, Result : Boolean;
 K   : Char;
 MX, MY, MB, OldMB : Integer;
 Idx : Integer;
 S   : String;
 LastClickT : LongInt;
 NowT       : LongInt;
 TickCnt    : LongInt;
 LastIdx, LastZone : Integer;

 Procedure RedrawAll;
 Var Path: String;
 Begin
  HideMouseCursor;
  { Cadre principal }
  SetFillStyle(SolidFill, LightGray);
  Bar(DX1, DY1, DX2, DY2);
  FD_DrawBevel(DX1, DY1, DX2, DY2, False);

  { Barre de titre }
  SetFillStyle(SolidFill, Blue);
  Bar(DX1 + 2, DY1 + 2, DX2 - 2, DY1 + 16);
  SetColor(White);
  OutTextXY(DX1 + 6, DY1 + 5, Title);

  SetColor(Black);
  OutTextXY(DX1 + 6, DY1 + 22, 'Chemin :');
  SetFillStyle(SolidFill, White);
  Bar(DX1 + 60, DY1 + 19, DX2 - 8, DY1 + 33);
  FD_DrawBevel(DX1 + 60, DY1 + 19, DX2 - 8, DY1 + 33, True);
  Path := FD_CurDir;
  If Length(Path) > 60 Then
   Path := '...' + Copy(Path, Length(Path) - 56, 57);
  OutTextXY(DX1 + 64, DY1 + 22, Path);

  OutTextXY(DirX1, DY1 + 40, 'Dossiers');
  OutTextXY(FilX1, DY1 + 40, 'Fichiers (*.PRO)');
  FD_DrawList(DirX1, DirY1, DirX2, DirY2, FD_Dirs,
              FD_NDirs, FD_TopDir, FD_SelDir,
              FD_Focus = 0, True);
  FD_DrawList(FilX1, FilY1, FilX2, FilY2, FD_Files,
              FD_NFiles, FD_TopFile, FD_SelFile,
              FD_Focus = 1, False);

  SetColor(Black);
  OutTextXY(DX1 + 6, NamY1 + 4, 'Nom :');
  SetFillStyle(SolidFill, White);
  Bar(NamX1, NamY1, NamX2, NamY2);
  FD_DrawBevel(NamX1, NamY1, NamX2, NamY2, True);
  SetColor(Black);
  OutTextXY(NamX1 + 4, NamY1 + 4, FD_NameBuf);
  If FD_Focus = 2 Then
   OutTextXY(NamX1 + 4 + Length(FD_NameBuf) * 8, NamY1 + 4, '_');

  { Case a cocher "Tous les fichiers" }
  SetFillStyle(SolidFill, White);
  Bar(AllX1, AllY1, AllX1 + 10, AllY1 + 10);
  FD_DrawBevel(AllX1, AllY1, AllX1 + 10, AllY1 + 10, True);
  If FD_ShowAll Then Begin
   SetColor(Black);
   Line(AllX1 + 2, AllY1 + 5, AllX1 + 4, AllY1 + 8);
   Line(AllX1 + 4, AllY1 + 8, AllX1 + 9, AllY1 + 2);
  End;
  SetColor(Black);
  OutTextXY(AllX1 + 16, AllY1 + 1, 'Tous (*.*)');

  FD_DrawButton(OkX1, OkY1, OkX2, OkY2, 'Ouvrir');
  FD_DrawButton(CcX1, CcY1, CcX2, CcY2, 'Annuler');
  ShowMouseCursor;
 End;

 Procedure DoActivate;
 Var Sel: String; I: Integer; OldDir: String;
 Begin
  { Si focus sur dossiers, on tente d'entrer dedans. }
  If (FD_Focus = 0) And (FD_NDirs > 0) Then Begin
   Sel := FD_Dirs[FD_SelDir].Name;
   OldDir := FD_CurDir;
   {$I-} ChDir(Sel); {$I+}
   If IOResult = 0 Then Begin
    FD_NameBuf := '';
    FD_SelDir := 0; FD_SelFile := 0;
    FD_Scan;
    RedrawAll;
   End
   Else
    FD_CurDir := OldDir;
   Exit;
  End;
  { Sinon : si Nom est un dossier connu, y entrer ; sinon valider. }
  Sel := FD_NameBuf;
  If Sel = '' Then
   If (FD_NFiles > 0) And (FD_SelFile < FD_NFiles) Then
    Sel := FD_Files[FD_SelFile].Name;
  If Sel = '' Then Exit;
  For I := 0 To FD_NDirs - 1 Do
   If UpStr(FD_Dirs[I].Name) = UpStr(Sel) Then Begin
    {$I-} ChDir(Sel); {$I+}
    If IOResult = 0 Then Begin
     FD_NameBuf := '';
     FD_SelDir := 0; FD_SelFile := 0;
     FD_Scan;
     RedrawAll;
    End;
    Exit;
   End;
  { Construction du chemin complet. }
  If (Length(Sel) >= 2) And (Sel[2] = ':') Then FN := Sel
  Else If (Length(Sel) >= 1) And (Sel[1] = '\') Then FN := Sel
  Else Begin
   FN := FD_CurDir;
   If (Length(FN) > 0) And (FN[Length(FN)] <> '\') Then FN := FN + '\';
   FN := FN + Sel;
  End;
  Result := True;
  Done   := True;
 End;

Begin
 FileOpenDialog := False;
 FD_NameBuf := '';
 FD_Focus   := 1;
 FD_SelDir  := 0; FD_SelFile := 0;
 FD_TopDir  := 0; FD_TopFile := 0;
 FD_ShowAll := False;
 FD_Scan;

 DX1 := (ScreenWidth  - 540) Div 2; If DX1 < 0 Then DX1 := 0;
 DY1 := (ScreenHeight - 340) Div 2; If DY1 < 0 Then DY1 := 0;
 DX2 := DX1 + 540;
 DY2 := DY1 + 340;

 DirX1 := DX1 + 8;   DirY1 := DY1 + 55;
 DirX2 := DX1 + 180; DirY2 := DY2 - 80;
 FilX1 := DX1 + 188; FilY1 := DY1 + 55;
 FilX2 := DX2 - 8;   FilY2 := DY2 - 80;

 NamX1 := DX1 + 50;  NamY1 := DY2 - 72;
 NamX2 := DX2 - 8;   NamY2 := DY2 - 56;

 AllX1 := DX1 + 8;   AllY1 := DY2 - 48;
 AllX2 := AllX1 + 10; AllY2 := AllY1 + 10;

 OkX1 := DX2 - 180;  OkY1 := DY2 - 30;
 OkX2 := DX2 - 100;  OkY2 := DY2 - 8;
 CcX1 := DX2 - 90;   CcY1 := DY2 - 30;
 CcX2 := DX2 - 10;   CcY2 := DY2 - 8;

 DirRows  := (DirY2 - DirY1 - 2) Div FD_ROWH;
 FileRows := (FilY2 - FilY1 - 2) Div FD_ROWH;

 RedrawAll;

 { Purge clavier + attente de relachement du bouton de la souris. }
 While KeyPressed Do Begin
  K := ReadKey;
  If K = #0 Then If KeyPressed Then ReadKey;
 End;
 Repeat
  GetMouseLocal(MX, MY, MB);
  If (MB And 1) = 0 Then Break;
  Delay(10);
 Until False;

 Done := False;
 Result := False;
 OldMB := 0;
 LastClickT := 0;
 TickCnt := 0;
 LastIdx := -1;
 LastZone := -1;

 Repeat
  If KeyPressed Then Begin
   K := ReadKey;
   If K = #0 Then Begin
    K := ReadKey;
    Case K Of
     #72: Begin { Up }
      If FD_Focus = 0 Then Begin
       If FD_SelDir > 0 Then Dec(FD_SelDir);
       FD_EnsureVisible(FD_TopDir, FD_SelDir, DirRows);
      End
      Else If FD_Focus = 1 Then Begin
       If FD_SelFile > 0 Then Dec(FD_SelFile);
       FD_EnsureVisible(FD_TopFile, FD_SelFile, FileRows);
       If FD_SelFile < FD_NFiles Then FD_NameBuf := FD_Files[FD_SelFile].Name;
      End;
      RedrawAll;
     End;
     #80: Begin { Down }
      If FD_Focus = 0 Then Begin
       If FD_SelDir < FD_NDirs - 1 Then Inc(FD_SelDir);
       FD_EnsureVisible(FD_TopDir, FD_SelDir, DirRows);
      End
      Else If FD_Focus = 1 Then Begin
       If FD_SelFile < FD_NFiles - 1 Then Inc(FD_SelFile);
       FD_EnsureVisible(FD_TopFile, FD_SelFile, FileRows);
       If FD_SelFile < FD_NFiles Then FD_NameBuf := FD_Files[FD_SelFile].Name;
      End;
      RedrawAll;
     End;
     #73: Begin { PgUp }
      If FD_Focus = 0 Then Begin
       Dec(FD_SelDir, DirRows);
       If FD_SelDir < 0 Then FD_SelDir := 0;
       FD_EnsureVisible(FD_TopDir, FD_SelDir, DirRows);
      End
      Else If FD_Focus = 1 Then Begin
       Dec(FD_SelFile, FileRows);
       If FD_SelFile < 0 Then FD_SelFile := 0;
       FD_EnsureVisible(FD_TopFile, FD_SelFile, FileRows);
      End;
      RedrawAll;
     End;
     #81: Begin { PgDn }
      If FD_Focus = 0 Then Begin
       Inc(FD_SelDir, DirRows);
       If FD_SelDir >= FD_NDirs Then FD_SelDir := FD_NDirs - 1;
       FD_EnsureVisible(FD_TopDir, FD_SelDir, DirRows);
      End
      Else If FD_Focus = 1 Then Begin
       Inc(FD_SelFile, FileRows);
       If FD_SelFile >= FD_NFiles Then FD_SelFile := FD_NFiles - 1;
       FD_EnsureVisible(FD_TopFile, FD_SelFile, FileRows);
      End;
      RedrawAll;
     End;
     #71: Begin { Home }
      If FD_Focus = 0 Then Begin FD_SelDir := 0; FD_TopDir := 0; End
      Else If FD_Focus = 1 Then Begin FD_SelFile := 0; FD_TopFile := 0; End;
      RedrawAll;
     End;
     #79: Begin { End }
      If FD_Focus = 0 Then Begin
       FD_SelDir := FD_NDirs - 1;
       FD_EnsureVisible(FD_TopDir, FD_SelDir, DirRows);
      End
      Else If FD_Focus = 1 Then Begin
       FD_SelFile := FD_NFiles - 1;
       FD_EnsureVisible(FD_TopFile, FD_SelFile, FileRows);
      End;
      RedrawAll;
     End;
    End;
   End
   Else Begin
    Case K Of
     #27: Done := True;
     #13: DoActivate;
     #9 : Begin FD_Focus := (FD_Focus + 1) Mod 3; RedrawAll; End;
     #8 : If FD_Focus = 2 Then Begin
           If Length(FD_NameBuf) > 0 Then
            Delete(FD_NameBuf, Length(FD_NameBuf), 1);
           RedrawAll;
          End;
    Else
     If K >= ' ' Then Begin
      If FD_Focus = 2 Then Begin
       If Length(FD_NameBuf) < 60 Then FD_NameBuf := FD_NameBuf + K;
       RedrawAll;
      End
      Else If FD_Focus = 0 Then Begin
       For Idx := 0 To FD_NDirs - 1 Do
        If (Length(FD_Dirs[Idx].Name) > 0) And
           (UpCase(FD_Dirs[Idx].Name[1]) = UpCase(K)) Then Begin
         FD_SelDir := Idx;
         FD_EnsureVisible(FD_TopDir, FD_SelDir, DirRows);
         Break;
        End;
       RedrawAll;
      End
      Else If FD_Focus = 1 Then Begin
       For Idx := 0 To FD_NFiles - 1 Do
        If (Length(FD_Files[Idx].Name) > 0) And
           (UpCase(FD_Files[Idx].Name[1]) = UpCase(K)) Then Begin
         FD_SelFile := Idx;
         FD_EnsureVisible(FD_TopFile, FD_SelFile, FileRows);
         FD_NameBuf := FD_Files[FD_SelFile].Name;
         Break;
        End;
       RedrawAll;
      End;
     End;
    End;
   End;
  End;

  GetMouseLocal(MX, MY, MB);
  Inc(TickCnt);
  If ((OldMB And 1) = 0) And ((MB And 1) <> 0) Then Begin
   NowT := TickCnt; { compteur d'iterations - sert pour double-clic }
   If (MX >= DirX1) And (MX <= DirX2) And
      (MY >= DirY1) And (MY <= DirY2) Then Begin
    Idx := FD_TopDir + (MY - DirY1 - 2) Div FD_ROWH;
    If (Idx >= 0) And (Idx < FD_NDirs) Then Begin
     If (LastZone = 0) And (LastIdx = Idx) And
        ((NowT - LastClickT) < 35) Then Begin
      FD_SelDir := Idx; FD_Focus := 0; DoActivate;
     End
     Else Begin
      FD_SelDir := Idx; FD_Focus := 0; RedrawAll;
     End;
     LastZone := 0; LastIdx := Idx; LastClickT := NowT;
    End
    Else Begin FD_Focus := 0; RedrawAll; LastZone := -1; End;
   End
   Else If (MX >= FilX1) And (MX <= FilX2) And
           (MY >= FilY1) And (MY <= FilY2) Then Begin
    Idx := FD_TopFile + (MY - FilY1 - 2) Div FD_ROWH;
    If (Idx >= 0) And (Idx < FD_NFiles) Then Begin
     If (LastZone = 1) And (LastIdx = Idx) And
        ((NowT - LastClickT) < 35) Then Begin
      FD_NameBuf := FD_Files[Idx].Name; FD_Focus := 1; DoActivate;
     End
     Else Begin
      FD_SelFile := Idx;
      FD_Focus := 1;
      FD_NameBuf := FD_Files[Idx].Name;
      RedrawAll;
     End;
     LastZone := 1; LastIdx := Idx; LastClickT := NowT;
    End
    Else Begin FD_Focus := 1; RedrawAll; LastZone := -1; End;
   End
   Else If (MX >= NamX1) And (MX <= NamX2) And
           (MY >= NamY1) And (MY <= NamY2) Then Begin
    FD_Focus := 2; RedrawAll; LastZone := -1;
   End
   Else If (MX >= AllX1) And (MX <= AllX2 + 100) And
           (MY >= AllY1) And (MY <= AllY2) Then Begin
    FD_ShowAll := Not FD_ShowAll;
    FD_Scan;
    RedrawAll;
    LastZone := -1;
   End
   Else If (MX >= OkX1) And (MX <= OkX2) And
           (MY >= OkY1) And (MY <= OkY2) Then DoActivate
   Else If (MX >= CcX1) And (MX <= CcX2) And
           (MY >= CcY1) And (MY <= CcY2) Then Done := True
   Else LastZone := -1;
  End;
  OldMB := MB;
  S := ''; { eviter avertissement variable inutilisee }
  If S <> '' Then ; { idem }
  Delay(15);
 Until Done;

 { Purge bouton et clavier avant de rendre la main. }
 Repeat
  GetMouseLocal(MX, MY, MB);
  If (MB And 1) = 0 Then Break;
  Delay(10);
 Until False;
 While KeyPressed Do Begin
  K := ReadKey;
  If K = #0 Then If KeyPressed Then ReadKey;
 End;
 MouseButtons := 0;
 OldMouseButtons := 0;

 FileOpenDialog := Result;
End;

Procedure ActOpenFile;
Var FN: String;
Begin
 FN := '';
 If FileOpenDialog('Ouvrir un profil .PRO', FN) Then Begin
  If FN <> '' Then Begin
   If LoadProfile(FN, Profile) Then ApplyLoaded
   Else ShowMessage('Erreur', 'Echec du chargement : ' + FN);
  End;
 End;
End;

Procedure ActReload;
Begin
 If Profile.FileName = '' Then Begin
  ShowMessage('Recharger', 'Aucun fichier charge.');
  Exit;
 End;
 If LoadProfile(Profile.FileName, Profile) Then ApplyLoaded
 Else ShowMessage('Erreur', 'Echec du rechargement.');
End;

Procedure ActDefault;
Begin
 MakeDefaultProfile(Profile);
 ApplyLoaded;
End;

Procedure ActShowInfo;
Var Msg: String;
Begin
 Msg := Profile.Name + '  -  ' + IntToStr(Profile.Count) + ' points';
 ShowMessage('Information', Msg);
End;

Procedure ToggleView(Flag: Word; ItemIdx: Integer);
Begin
 ViewFlags := ViewFlags Xor Flag;
 Menus[MENU_VIEW].Items[ItemIdx].Checked :=
  (ViewFlags And Flag) <> 0;
End;

Procedure HandleMenuClick(MenuIdx, ItemIdx: Integer);
Begin
 Case MenuIdx Of
  MENU_FILE:
   Case ItemIdx Of
    0: ActOpenFile;
    1: ActDefault;
    3: ActReload;
    4: Running := False;
   End;
  MENU_PROFILE:
   Case ItemIdx Of
    0: ActShowInfo;
    2: Begin AoADeg := AoADeg + 1.0; ApplyLoaded; End;
    3: Begin AoADeg := AoADeg - 1.0; ApplyLoaded; End;
    4: Begin AoADeg := 0.0; ApplyLoaded; End;
   End;
  MENU_SIM:
   Case ItemIdx Of
    0: SimRunning := True;
    1: SimRunning := False;
    2: Begin ResetParticles; NeedRedraw := True; End;
    4: Begin WindSpeed := WindSpeed + 0.5;
            If WindSpeed > 8.0 Then WindSpeed := 8.0; End;
    5: Begin WindSpeed := WindSpeed - 0.5;
            If WindSpeed < 0.5 Then WindSpeed := 0.5; End;
   End;
  MENU_VIEW:
   Case ItemIdx Of
    0: ToggleView(SHOW_PROFILE,   0);
    1: ToggleView(SHOW_CHORD,     1);
    2: ToggleView(SHOW_GRID,      2);
    3: ToggleView(SHOW_PARTICLES, 3);
    4: ToggleView(SHOW_TRAILS,    4);
    5: ToggleView(SHOW_PRESSURE,  5);
   End;
  MENU_HELP:
   Case ItemIdx Of
    0: ShowMessage('Touches',
       'F1 Info  F2 Reset  F3 Recharger  F5/F6 ON/OFF');
    1: ShowMessage('A propos',
       PROG_TITLE + ' - simulation 2D');
   End;
 End;
 NeedRedraw := True;
End;

{ --------------------------------------------------------------------- }
{ Boucle principale                                                     }
{ --------------------------------------------------------------------- }

Procedure RedrawAll;
Begin
 HideMouseCursor;
 DrawCanvas;
 DrawMenuBar;
 DrawStatusBar;
 If MenuActive Then DrawMenuPopup(ActiveMenu);
 ShowMouseCursor;
End;

Procedure MenuSwitch(NewMenu: Integer);
Begin
 If (NewMenu < 0) Or (NewMenu >= NUM_MENUS) Then Exit;
 ActiveMenu := NewMenu;
 ActiveMenuItem := -1;
 NeedRedraw := True;
End;

Procedure HandleMouseEvent;
Var
 Pressed : Boolean;
 BarHit, ItemHit : Integer;
Begin
 If Not MouseAvailable Then Exit;

 GetMouseLocal(MouseX, MouseY, MouseButtons);
 Pressed := ((MouseButtons And 1) <> 0) And
            ((OldMouseButtons And 1) = 0);

 If MenuActive And
    ((MouseX <> OldMouseX) Or (MouseY <> OldMouseY)) Then Begin
  BarHit := MenuBarHitTest(MouseX, MouseY);
  If (BarHit >= 0) And (BarHit <> ActiveMenu) Then
   MenuSwitch(BarHit)
  Else Begin
   ItemHit := MenuItemHitTest(MouseX, MouseY, ActiveMenu);
   If ItemHit <> ActiveMenuItem Then Begin
    ActiveMenuItem := ItemHit;
    NeedRedraw := True;
   End;
  End;
 End;

 If Pressed Then Begin
  BarHit := MenuBarHitTest(MouseX, MouseY);
  If BarHit >= 0 Then Begin
   If MenuActive And (ActiveMenu = BarHit) Then Begin
    MenuActive := False;
   End Else Begin
    MenuActive := True;
    ActiveMenu := BarHit;
    ActiveMenuItem := -1;
   End;
   NeedRedraw := True;
  End
  Else If MenuActive Then Begin
   ItemHit := MenuItemHitTest(MouseX, MouseY, ActiveMenu);
   If ItemHit >= 0 Then Begin
    If Not Menus[ActiveMenu].Items[ItemHit].Separator Then Begin
     HandleMenuClick(ActiveMenu, ItemHit);
     MenuActive := False;
     NeedRedraw := True;
    End;
   End
   Else Begin
    MenuActive := False;
    NeedRedraw := True;
   End;
  End;
 End;

 OldMouseX := MouseX;
 OldMouseY := MouseY;
 OldMouseButtons := MouseButtons;
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
    #72: Begin MenuNextItem(-1); NeedRedraw := True; Exit; End;
    #80: Begin MenuNextItem(+1); NeedRedraw := True; Exit; End;
    #75: Begin MenuSwitch((ActiveMenu + NUM_MENUS - 1) Mod NUM_MENUS);
              Exit; End;
    #77: Begin MenuSwitch((ActiveMenu + 1) Mod NUM_MENUS); Exit; End;
   End;
  End;
  Case Ext Of
   #59: HandleMenuClick(MENU_PROFILE, 0);          { F1 }
   #60: HandleMenuClick(MENU_SIM,     2);          { F2 }
   #61: HandleMenuClick(MENU_FILE,    3);          { F3 }
   #63: HandleMenuClick(MENU_SIM,     0);          { F5 }
   #64: HandleMenuClick(MENU_SIM,     1);          { F6 }
   #107: Running := False;                          { Alt+F4 }
   #33: Begin                                       { Alt+F }
        MenuActive := True; ActiveMenu := MENU_FILE;
        ActiveMenuItem := -1; NeedRedraw := True;
        End;
   #25: Begin                                       { Alt+P }
        MenuActive := True; ActiveMenu := MENU_PROFILE;
        ActiveMenuItem := -1; NeedRedraw := True;
        End;
   #31: Begin                                       { Alt+S }
        MenuActive := True; ActiveMenu := MENU_SIM;
        ActiveMenuItem := -1; NeedRedraw := True;
        End;
   #30: Begin                                       { Alt+A }
        MenuActive := True; ActiveMenu := MENU_VIEW;
        ActiveMenuItem := -1; NeedRedraw := True;
        End;
   #73: HandleMenuClick(MENU_SIM, 4);                { PgUp }
   #81: HandleMenuClick(MENU_SIM, 5);                { PgDn }
   #75: Begin AoADeg := AoADeg - 1.0; ApplyLoaded; End; { gauche }
   #77: Begin AoADeg := AoADeg + 1.0; ApplyLoaded; End; { droite }
  End;
 End
 Else Begin
  If MenuActive And (Key = #13) Then Begin
   If (ActiveMenuItem >= 0) And
      (ActiveMenuItem < Menus[ActiveMenu].ItemCount) And
      (Not Menus[ActiveMenu].Items[ActiveMenuItem].Separator) Then Begin
    HandleMenuClick(ActiveMenu, ActiveMenuItem);
    MenuActive := False;
    NeedRedraw := True;
   End;
   Exit;
  End;
  Case Key Of
   #27: Begin
        If MenuActive Then Begin
         MenuActive := False; NeedRedraw := True;
        End
        Else Running := False;
        End;
   '+', '=': Begin AoADeg := AoADeg + 1.0; ApplyLoaded; End;
   '-', '_': Begin AoADeg := AoADeg - 1.0; ApplyLoaded; End;
   '0':      Begin AoADeg := 0.0;          ApplyLoaded; End;
   'q', 'Q': Running := False;
   ' ':      SimRunning := Not SimRunning;
  End;
 End;
End;

Procedure InitGraphicsMode;
Var
 Driver, Mode, Err : Integer;
Begin
 {$IFDEF FPC}
  Driver := VGA;
  Mode   := VGAHi;
 {$ELSE}
  Driver := Detect;
  Mode   := VGAHi;
 {$ENDIF}
 InitGraph(Driver, Mode, '');
 Err := GraphResult;
 If Err <> grOk Then Begin
  WriteLn('Erreur graphique : ', GraphErrorMsg(Err));
  Halt(1);
 End;
 ScreenWidth  := GetMaxX + 1;
 ScreenHeight := GetMaxY + 1;
 CanvasTop    := MENUBAR_HEIGHT;
 CanvasBottom := ScreenHeight - STATUSBAR_HEIGHT - 1;
 SetTextStyle(DefaultFont, HorizDir, 1);
End;

Procedure Initialize;
Var FN: String;
Begin
 Randomize;
 InitGraphicsMode;
 InitMouseDriver;

 AoADeg     := 4.0;
 WindSpeed  := 2.5;
 ViewFlags  := SHOW_PROFILE Or SHOW_CHORD Or SHOW_PARTICLES Or SHOW_TRAILS;
 SimRunning := True;
 MenuActive := False;
 ActiveMenu := -1;
 ActiveMenuItem := -1;
 Running    := True;
 NeedRedraw := True;
 StatusMsg  := '';
 OldMouseButtons := 0;

 InitMenus;

 { Chargement initial : argument de ligne de commande s'il existe. }
 Profile.Loaded := False;
 Profile.FileName := '';
 If ParamCount >= 1 Then Begin
  FN := ParamStr(1);
  If Not LoadProfile(FN, Profile) Then Begin
   MakeDefaultProfile(Profile);
   StatusMsg := 'Echec : ' + FN;
  End;
 End
 Else
  MakeDefaultProfile(Profile);

 ComputePlacement;
 ComputePolygon;
 ResetParticles;
 ShowMouseCursor;
End;

Procedure Cleanup;
Begin
 HideMouseCursor;
 CloseGraph;
End;

Procedure MainLoop;
Var FrameTick: Integer;
Begin
 FrameTick := 0;
 While Running Do Begin
  HandleMouseEvent;
  HandleKeyboardEvent;

  If SimRunning And (Not MenuActive) Then Begin
   StepParticles;
   NeedRedraw := True;
  End;

  If NeedRedraw Then Begin
   RedrawAll;
   NeedRedraw := False;
  End;

  Inc(FrameTick);
  Delay(20);
 End;
End;

{ --------------------------------------------------------------------- }
{ Point d'entree                                                        }
{ --------------------------------------------------------------------- }

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('SOUFFLE - Cette commande permet de lancer un simulateur de ',
          'soufflerie en a'+#130+'rodynamique 2D.');
  WriteLn;
  WriteLn('Syntaxe : SOUFFLE [fichier.PRO]');
  WriteLn;
  WriteLn(' fichier.PRO  Fichier de profile de soufflerie (optionnel)');
  Halt;
 End;
 Initialize;
 If StatusMsg <> '' Then ShowMessage('Soufflerie', StatusMsg);
 MainLoop;
 Cleanup;
END.
