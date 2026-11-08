{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program PLANEGRA;

{ Calcul des limites du centre de gravite d'un avion a partir d'un
  graphique d'enveloppe au format XAML de l'application Avionix
  (<graph:LineSeries> contenant des <graph:DataPoint> de deux
  <x:Double> : position du centre de gravite puis masse). }

Uses DOS;

Const
 MaxPts=256;
 Eps=1E-6;
 LbToKg=0.453592;
 TagSerie='<graph:LineSeries';
 TagSerieFin='</graph:LineSeries>';
 TagDouble='<x:Double>';
 TagDoubleFin='</x:Double>';
 TagTitre='Title="';

Type
 TPoint=Record
  X,Y:Real;                { X = centre de gravite, Y = masse }
 End;

 TEnveloppe=Record
  Titre:String;
  Nombre:Integer;
  Pt:Array[1..MaxPts]of TPoint;
 End;

 TLimites=Record
  MinX,MaxX,MinY,MaxY:Real;
 End;

Var
 Env:TEnveloppe;
 Bornes:TLimites;
 Option:Set of (_KG,_Table);
 I,Serie,TotalSeries,Err,Pas:Integer;
 NbPositionnel:Integer;
 HasMasse,HasCG,Trouve,Dedans,Surface:Boolean;
 Masse,CG,Avant,Arriere,Nb:Real;
 FileName,Param,Tmp:String;
 Dir:DirStr;
 Name:NameStr;
 Ext:ExtStr;

Function StrToUpper(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 to Length(S)do Begin
  If S[I]in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Function Fmt(R:Real):String;
Var
 S:String;
Begin
 Str(R:0:2,S);
 Fmt:=S;
End;

Function FmtInt(N:Integer):String;
Var
 S:String;
Begin
 Str(N,S);
 FmtInt:=S;
End;

Function FmtKg(R:Real):String;Begin
 If _KG in Option Then FmtKg:=' ('+Fmt(R*LbToKg)+' kg)'
                  Else FmtKg:='';
End;

Function Trim(S:String):String;Begin
 While(Length(S)>0)and(S[1]in[' ',#9])do Delete(S,1,1);
 While(Length(S)>0)and(S[Length(S)]in[' ',#9])do Delete(S,Length(S),1);
 Trim:=S;
End;

Function ParseNombre(S:String;Var R:Real):Boolean;
Var
 Code,I:Integer;
Begin
 S:=Trim(S);
 For I:=1 to Length(S)do If S[I]=','Then S[I]:='.';
 Val(S,R,Code);
 ParseNombre:=(Code=0)and(S<>'');
End;

Function StartsAt(Const S,Pat:String;I:Integer):Boolean;
Var
 J:Integer;
Begin
 StartsAt:=False;
 If I+Length(Pat)-1>Length(S)Then Exit;
 For J:=1 to Length(Pat)do Begin
  If S[I+J-1]<>Pat[J]Then Exit;
 End;
 StartsAt:=True;
End;

Function FileExists(Const Path:String):Boolean;
Var
 F:File;
 Old:Word;
Begin
 Old:=FileMode;
 FileMode:=0;
 Assign(F,Path);
 {$I-}Reset(F,1);{$I+}
 FileExists:=IOResult=0;
 If IOResult=0 Then ;
 {$I-}Close(F);{$I+}
 If IOResult=0 Then ;
 FileMode:=Old;
End;

{ Charge la serie numero 'Serie' du fichier XAML dans l'enveloppe.
  Err : 0 = Ok, 1 = fichier illisible, 2 = serie vide ou introuvable,
        3 = trop de points }
Procedure ChargerEnveloppe(Const FileName:String;Serie:Integer;
                           Var E:TEnveloppe;Var Total,Err:Integer);
Var
 F:Text;
 Line,Tmp:String;
 I,J,K,Cur:Integer;
 HaveX:Boolean;
 XV,V:Real;
Begin
 E.Nombre:=0;
 E.Titre:='';
 Total:=0;
 Cur:=0;
 Err:=0;
 HaveX:=False;
 XV:=0;
 Assign(F,FileName);
 {$I-}Reset(F);{$I+}
 If IOResult<>0Then Begin
  Err:=1;
  Exit;
 End;
 While Not EOF(F)do Begin
  ReadLn(F,Line);
  I:=1;
  While I<=Length(Line)do Begin
   If StartsAt(Line,TagSerieFin,I)Then Begin
    Cur:=0;
    HaveX:=False;
    Inc(I,Length(TagSerieFin));
   End
    Else
   If StartsAt(Line,TagSerie,I)and
     ((I+Length(TagSerie)>Length(Line))or
      (Line[I+Length(TagSerie)]in[' ',#9,'>','/']))Then Begin
    Inc(Total);
    Cur:=Total;
    HaveX:=False;
    Inc(I,Length(TagSerie));
   End
    Else
   If StartsAt(Line,TagDouble,I)Then Begin
    J:=I+Length(TagDouble);
    K:=J;
    While(K<=Length(Line))and Not StartsAt(Line,TagDoubleFin,K)do Inc(K);
    If K>Length(Line)Then Inc(I,Length(TagDouble))
     Else
    Begin
     Tmp:=Copy(Line,J,K-J);
     If(Cur=Serie)and ParseNombre(Tmp,V)Then Begin
      If HaveX Then Begin
       If E.Nombre>=MaxPts Then Err:=3
        Else
       Begin
        Inc(E.Nombre);
        E.Pt[E.Nombre].X:=XV;
        E.Pt[E.Nombre].Y:=V;
       End;
       HaveX:=False;
      End
       Else
      Begin
       XV:=V;
       HaveX:=True;
      End;
     End;
     I:=K+Length(TagDoubleFin);
    End;
   End
    Else
   If(Total=0)and(E.Titre='')and StartsAt(Line,TagTitre,I)and
     ((I=1)or(Line[I-1]in[' ',#9]))Then Begin
    J:=I+Length(TagTitre);
    K:=J;
    While(K<=Length(Line))and(Line[K]<>'"')do Inc(K);
    E.Titre:=Copy(Line,J,K-J);
    I:=K+1;
   End
    Else
   Inc(I);
  End;
 End;
 Close(F);
 If(Err=0)and(E.Nombre<3)Then Err:=2;
End;

Procedure CalculerBornes(Var E:TEnveloppe;Var B:TLimites);
Var
 I:Integer;
Begin
 B.MinX:=E.Pt[1].X;B.MaxX:=E.Pt[1].X;
 B.MinY:=E.Pt[1].Y;B.MaxY:=E.Pt[1].Y;
 For I:=2 to E.Nombre do Begin
  If E.Pt[I].X<B.MinX Then B.MinX:=E.Pt[I].X;
  If E.Pt[I].X>B.MaxX Then B.MaxX:=E.Pt[I].X;
  If E.Pt[I].Y<B.MinY Then B.MinY:=E.Pt[I].Y;
  If E.Pt[I].Y>B.MaxY Then B.MaxY:=E.Pt[I].Y;
 End;
End;

{ Limites avant et arriere du centre de gravite a une masse donnee : plus
  petite et plus grande abscisse des intersections de la droite horizontale
  Y = Masse avec le contour de l'enveloppe. }
Procedure LimitesALaMasse(Var E:TEnveloppe;M:Real;Var Av,Ar:Real;
                          Var Trouve:Boolean);
Var
 I,J:Integer;
 X,Y1,Y2,LoY,HiY:Real;

 Procedure Retenir(X:Real);Begin
  If Not Trouve Then Begin
   Av:=X;Ar:=X;
   Trouve:=True;
  End
   Else
  Begin
   If X<Av Then Av:=X;
   If X>Ar Then Ar:=X;
  End;
 End;

Begin
 Trouve:=False;
 Av:=0;Ar:=0;
 For I:=1 to E.Nombre do Begin
  If I=1Then J:=E.Nombre Else J:=I-1;
  Y1:=E.Pt[J].Y;
  Y2:=E.Pt[I].Y;
  If Y1<Y2 Then Begin LoY:=Y1;HiY:=Y2;End
           Else Begin LoY:=Y2;HiY:=Y1;End;
  If(M>=LoY-Eps)and(M<=HiY+Eps)Then Begin
   If Abs(Y2-Y1)<=Eps Then Begin
    Retenir(E.Pt[J].X);
    Retenir(E.Pt[I].X);
   End
    Else
   Begin
    X:=E.Pt[J].X+(M-Y1)*(E.Pt[I].X-E.Pt[J].X)/(Y2-Y1);
    Retenir(X);
   End;
  End;
 End;
End;

{ Distance d'un point (PX,PY) au segment [A,B], en tenant compte de
  l'echelle des deux axes (distance dans l'espace brut). }
Function DistanceSegment(PX,PY,AX,AY,BX,BY:Real):Real;
Var
 DX,DY,T,CX,CY:Real;
Begin
 DX:=BX-AX;
 DY:=BY-AY;
 If(Abs(DX)<Eps)and(Abs(DY)<Eps)Then T:=0
  Else
 Begin
  T:=((PX-AX)*DX+(PY-AY)*DY)/(DX*DX+DY*DY);
  If T<0 Then T:=0;
  If T>1 Then T:=1;
 End;
 CX:=AX+T*DX;
 CY:=AY+T*DY;
 DistanceSegment:=Sqrt((PX-CX)*(PX-CX)+(PY-CY)*(PY-CY));
End;

{ Test d'appartenance a l'enveloppe (regle pair/impair) ; Surface vaut
  True si le point se trouve sur le contour. }
Function DansEnveloppe(Var E:TEnveloppe;PX,PY:Real;Var Surface:Boolean):Boolean;
Var
 I,J:Integer;
 Dedans:Boolean;
Begin
 Dedans:=False;
 Surface:=False;
 For I:=1 to E.Nombre do Begin
  If I=1Then J:=E.Nombre Else J:=I-1;
  If DistanceSegment(PX,PY,E.Pt[J].X,E.Pt[J].Y,E.Pt[I].X,E.Pt[I].Y)<=Eps Then
   Surface:=True;
  If(E.Pt[I].Y>PY)<>(E.Pt[J].Y>PY)Then Begin
   If PX<(E.Pt[J].X-E.Pt[I].X)*(PY-E.Pt[I].Y)/(E.Pt[J].Y-E.Pt[I].Y)+
         E.Pt[I].X Then Dedans:=Not Dedans;
  End;
 End;
 DansEnveloppe:=Dedans or Surface;
End;

Procedure AfficherAide;Begin
 WriteLn('PLANEGRA : Cette commande permet de calculer les limites du centre ',
                    'de gravite d''un avion');
 WriteLn('           a partir d''une enveloppe masse/centre de gravite au ',
                    'format XAML (Avionix).');
 WriteLn;
 WriteLn('Syntaxe : PLANEGRA fichier [masse [cg]] [/T[:n]] [/S:n] [/KG]');
 WriteLn;
 WriteLn(' fichier  Ce parametre permet d''indiquer le fichier XAML contenant ',
                   'l''enveloppe');
 WriteLn('          (extension .XAML ou .XML ajoutee si absente)');
 WriteLn(' masse    Masse de l''avion : affiche les limites avant et arriere ',
                   'a cette masse');
 WriteLn(' cg       Position du centre de gravite : indique s''il est dans ',
                   'l''enveloppe');
 WriteLn(' /T[:n]   Affiche un tableau des limites en n+1 masses ',
                   '(10 par defaut)');
 WriteLn(' /S:n     Numero de la serie <graph:LineSeries> utilisee comme ',
                   'enveloppe (1 par defaut)');
 WriteLn(' /KG      Ajoute l''equivalent en kilogrammes (masses du fichier ',
                   'en livres)');
 WriteLn;
 WriteLn('Code de sortie : 0 = Ok, 1 = erreur, 2 = hors de l''enveloppe');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn(' PLANEGRA SAMPLES\PLANEGRA\B747 600000 20      Dans l''enveloppe ',
         '(limite avant 12,67, arriere 33,00)');
 WriteLn(' PLANEGRA SAMPLES\PLANEGRA\B747 875000 18      Hors de l''enveloppe, ',
         'trop avance de 1,00 (code de sortie 2)');
 WriteLn(' PLANEGRA SAMPLES\PLANEGRA\CONCORDE 300000 56  Dans l''enveloppe ',
         '(marges 3,46 et 3,00)');
 WriteLn(' PLANEGRA SAMPLES\PLANEGRA\C172 /T:5 /KG       Tableau des limites ',
         'en 6 masses, avec equivalent en kg');
End;

Procedure ErreurEtSortie(Msg:String);Begin
 WriteLn(Msg);
 Halt(1);
End;

Procedure AfficherTableau(Var E:TEnveloppe;Var B:TLimites;N:Integer);
Var
 K:Integer;
 M,Av,Ar:Real;
 Ok:Boolean;
Begin
 WriteLn;
 WriteLn('Masse':14,'Limite avant':16,'Limite arriere':16,'Plage':12);
 WriteLn('-----':14,'------------':16,'--------------':16,'-----':12);
 For K:=0 to N do Begin
  M:=B.MinY+(B.MaxY-B.MinY)*K/N;
  LimitesALaMasse(E,M,Av,Ar,Ok);
  If Ok Then WriteLn(M:14:2,Av:16:2,Ar:16:2,(Ar-Av):12:2)
        Else WriteLn(M:14:2,'hors enveloppe':32);
 End;
End;

BEGIN
 Option:=[];
 Serie:=1;
 Pas:=10;
 HasMasse:=False;
 HasCG:=False;
 FileName:='';
 NbPositionnel:=0;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  AfficherAide;
  Halt(0);
 End;
 If ParamCount=0 Then Begin
  WriteLn('Calcul des limites du centre de gravite d''un avion');
  WriteLn('---------------------------------------------------');
  Write('Fichier XAML de l''enveloppe : ');
  ReadLn(FileName);
  FileName:=Trim(FileName);
  Write('Masse de l''avion (vide = aucune) : ');
  ReadLn(Tmp);
  If Trim(Tmp)<>''Then Begin
   If Not ParseNombre(Tmp,Masse)Then ErreurEtSortie('La masse n''est pas valide');
   HasMasse:=True;
   Write('Centre de gravite (vide = aucun) : ');
   ReadLn(Tmp);
   If Trim(Tmp)<>''Then Begin
    If Not ParseNombre(Tmp,CG)Then
     ErreurEtSortie('Le centre de gravite n''est pas valide');
    HasCG:=True;
   End;
  End;
 End
  Else
 For I:=1 to ParamCount do Begin
  Param:=ParamStr(I);
  If(Length(Param)>0)and(Param[1]='/')Then Begin
   Tmp:=StrToUpper(Param);
   If Tmp='/KG'Then Option:=Option+[_KG]
    Else
   If Copy(Tmp,1,2)='/T'Then Begin
    Option:=Option+[_Table];
    If Length(Tmp)>2 Then Begin
     If(Tmp[3]<>':')or Not ParseNombre(Copy(Tmp,4,255),Nb)or
       (Nb<1)or(Nb>100)Then
      ErreurEtSortie('Le nombre de lignes du tableau n''est pas valide (1 a 100)');
     Pas:=Trunc(Nb);
    End;
   End
    Else
   If Copy(Tmp,1,3)='/S:'Then Begin
    If Not ParseNombre(Copy(Tmp,4,255),Nb)or(Nb<1)Then
     ErreurEtSortie('Le numero de serie n''est pas valide');
    Serie:=Trunc(Nb);
   End
    Else
   ErreurEtSortie('Option inconnue : '+Param);
  End
   Else
  Begin
   Inc(NbPositionnel);
   Case NbPositionnel of
    1:FileName:=Param;
    2:Begin
     If Not ParseNombre(Param,Masse)Then ErreurEtSortie('La masse n''est pas valide');
     HasMasse:=True;
    End;
    3:Begin
     If Not ParseNombre(Param,CG)Then
      ErreurEtSortie('Le centre de gravite n''est pas valide');
     HasCG:=True;
    End;
    Else ErreurEtSortie('Trop de parametres');
   End;
  End;
 End;
 If FileName=''Then ErreurEtSortie('Le nom du fichier est requis');
 If Not FileExists(FileName)Then Begin
  FSplit(FileName,Dir,Name,Ext);
  If Ext=''Then Begin
   If FileExists(FileName+'.XAML')Then FileName:=FileName+'.XAML'
    Else
   If FileExists(FileName+'.XML')Then FileName:=FileName+'.XML';
  End;
 End;
 ChargerEnveloppe(FileName,Serie,Env,TotalSeries,Err);
 Case Err of
  1:ErreurEtSortie('Impossible de lire le fichier : '+FileName);
  2:ErreurEtSortie('La serie '+FmtInt(Serie)+' ne contient pas au moins 3 points ('+
                   'series trouvees : '+FmtInt(TotalSeries)+')');
  3:ErreurEtSortie('L''enveloppe contient trop de points (maximum '+
                   FmtInt(MaxPts)+')');
 End;
 CalculerBornes(Env,Bornes);
 WriteLn('Fichier : ',FileName);
 If Env.Titre<>''Then WriteLn('Enveloppe : ',Env.Titre);
 WriteLn('Serie ',Serie,' sur ',TotalSeries,', ',Env.Nombre,' points');
 WriteLn;
 WriteLn('Masse minimale        : ',Fmt(Bornes.MinY),FmtKg(Bornes.MinY));
 WriteLn('Masse maximale        : ',Fmt(Bornes.MaxY),FmtKg(Bornes.MaxY));
 WriteLn('Limite avant extreme  : ',Fmt(Bornes.MinX));
 WriteLn('Limite arriere extreme: ',Fmt(Bornes.MaxX));
 If HasMasse Then Begin
  WriteLn;
  LimitesALaMasse(Env,Masse,Avant,Arriere,Trouve);
  If Not Trouve Then Begin
   WriteLn('A la masse de ',Fmt(Masse),FmtKg(Masse),
           ' : hors de l''enveloppe de masse');
   Halt(2);
  End;
  WriteLn('A la masse de ',Fmt(Masse),FmtKg(Masse),' :');
  WriteLn('  Limite avant du centre de gravite   : ',Fmt(Avant));
  WriteLn('  Limite arriere du centre de gravite : ',Fmt(Arriere));
  WriteLn('  Plage admissible                    : ',Fmt(Arriere-Avant));
  If HasCG Then Begin
   Dedans:=DansEnveloppe(Env,CG,Masse,Surface);
   WriteLn;
   If Dedans Then Begin
    If Surface Then WriteLn('Centre de gravite ',Fmt(CG),
                            ' : SUR LA LIMITE de l''enveloppe')
               Else WriteLn('Centre de gravite ',Fmt(CG),
                            ' : DANS l''enveloppe');
    WriteLn('  Marge avant   : ',Fmt(CG-Avant));
    WriteLn('  Marge arriere : ',Fmt(Arriere-CG));
   End
    Else
   Begin
    WriteLn('Centre de gravite ',Fmt(CG),' : HORS de l''enveloppe');
    If CG<Avant Then WriteLn('  Trop avance de ',Fmt(Avant-CG))
                Else WriteLn('  Trop recule de ',Fmt(CG-Arriere));
    Halt(2);
   End;
  End;
 End
  Else
 If HasCG Then ErreurEtSortie('Une masse est requise avec le centre de gravite');
 If _Table in Option Then AfficherTableau(Env,Bornes,Pas);
END.
