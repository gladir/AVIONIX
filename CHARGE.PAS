{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program CHARGE;

{ Masse et centrage : calcul du centre de gravite d'un avion a partir de son
  chargement (masse et bras de levier de chaque poste).
   - total des masses et des moments, centre de gravite, % MAC ;
   - verification de la masse maximale et d'une enveloppe masse/centre de
     gravite au format XAML de PLANEGRA ;
   - deplacement du centre de gravite pendant la consommation du
     carburant. }

Const
 MaxItems=64;
 MaxPts=256;
 Eps=1E-6;
 TagSerie='<graph:LineSeries';
 TagSerieFin='</graph:LineSeries>';
 TagDouble='<x:Double>';
 TagDoubleFin='</x:Double>';

Type
 TPoste=Record
  Nom:String[40];
  Masse,Bras,Moment:Real;
 End;

 TChargement=Record
  Nombre:Integer;
  Poste:Array[1..MaxItems]of TPoste;
  MasseTotale,MomentTotal,CG:Real;
 End;

 TPoint=Record
  X,Y:Real;
 End;

 TEnveloppe=Record
  Nombre:Integer;
  Pt:Array[1..MaxPts]of TPoint;
 End;

Var
 Chg:TChargement;
 Env:TEnveloppe;
 Option:Set of (_Livres,_Conso);
 UniteBras:String;
 Arg:Array[1..MaxItems]of String;
 NArg,I:Integer;
 Param,FichierCharge,FichierEnv:String;
 HasMAC,HasMTOW,HasEnv:Boolean;
 LeMAC,LongMAC,MTOW:Real;

Function StrToUpper(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 to Length(S)do Begin
  If S[I]in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Function Trim(S:String):String;Begin
 While(Length(S)>0)and(S[1]in[' ',#9])do Delete(S,1,1);
 While(Length(S)>0)and(S[Length(S)]in[' ',#9])do Delete(S,Length(S),1);
 Trim:=S;
End;

Function Fmt(R:Real;N:Integer):String;
Var
 S:String;
 I:Integer;
 Zero:Boolean;
Begin
 Str(R:0:N,S);
 Zero:=True;
 For I:=1 to Length(S)do If S[I]in['1'..'9']Then Zero:=False;
 If Zero and(S[1]='-')Then Delete(S,1,1);
 Fmt:=S;
End;

Function Pad(S:String;N:Integer):String;Begin
 While Length(S)<N do S:=S+' ';
 Pad:=S;
End;

Function PadGauche(S:String;N:Integer):String;Begin
 While Length(S)<N do S:=' '+S;
 PadGauche:=S;
End;

Procedure Erreur(Msg:String);Begin
 WriteLn(Msg);
 Halt(1);
End;

Function EstNombre(S:String;Var R:Real):Boolean;
Var
 Code,I:Integer;
Begin
 S:=Trim(S);
 For I:=1 to Length(S)do If S[I]=','Then S[I]:='.';
 Val(S,R,Code);
 EstNombre:=(Code=0)and(S<>'');
End;

Function ParseReal(Const S,Nom:String):Real;
Var
 R:Real;
Begin
 If Not EstNombre(S,R)Then Erreur('Valeur invalide pour '+Nom+' : '+S);
 ParseReal:=R;
End;

Function UniteMasse:String;Begin
 If _Livres in Option Then UniteMasse:='lb' Else UniteMasse:='kg';
End;

Function ToutMajuscule(S:String):String;Begin
 ToutMajuscule:=StrToUpper(S);
End;

{ ---------------------------------------------------------------------
  Chargement
  --------------------------------------------------------------------- }

Procedure AjouterPoste(Var Ch:TChargement;Nom:String;Masse,Bras:Real);Begin
 If Ch.Nombre>=MaxItems Then Erreur('Trop de postes de chargement (maximum '+
                                   Fmt(MaxItems,0)+')');
 Inc(Ch.Nombre);
 If Nom='' Then Nom:='Poste '+Fmt(Ch.Nombre,0);
 Ch.Poste[Ch.Nombre].Nom:=Copy(Nom,1,40);
 Ch.Poste[Ch.Nombre].Masse:=Masse;
 Ch.Poste[Ch.Nombre].Bras:=Bras;
 Ch.Poste[Ch.Nombre].Moment:=Masse*Bras;
End;

{ Poste de la ligne de commande : [nom=]masse:bras }
Procedure LirePoste(Var Ch:TChargement;Const Jeton:String);
Var
 Nom,Reste,SM,SB:String;
 P:Integer;
 M,B:Real;
Begin
 Nom:='';
 Reste:=Jeton;
 P:=Pos('=',Reste);
 If P>0 Then Begin
  Nom:=Copy(Reste,1,P-1);
  Reste:=Copy(Reste,P+1,255);
 End;
 P:=Pos(':',Reste);
 If P=0 Then Erreur('Poste invalide : '+Jeton+' (format [nom=]masse:bras)');
 SM:=Copy(Reste,1,P-1);
 SB:=Copy(Reste,P+1,255);
 If Not EstNombre(SM,M)or Not EstNombre(SB,B)Then
  Erreur('Poste invalide : '+Jeton+' (format [nom=]masse:bras)');
 AjouterPoste(Ch,Nom,M,B);
End;

{ Fichier texte : une ligne par poste "nom masse bras" (separateurs : espace,
  point-virgule ou tabulation) ; les lignes vides et celles qui commencent
  par # sont ignorees. }
Procedure LireFichierCharge(Var Ch:TChargement;Const Nom:String);
Var
 F:Text;
 Ligne,Mot,NomPoste:String;
 I,N:Integer;
 Mots:Array[1..32]of String;
 M,B:Real;
Begin
 Assign(F,Nom);
 {$I-}Reset(F);{$I+}
 If IOResult<>0 Then Erreur('Impossible de lire le fichier : '+Nom);
 While Not EOF(F)do Begin
  ReadLn(F,Ligne);
  Ligne:=Trim(Ligne);
  If(Ligne<>'')and(Ligne[1]<>'#')Then Begin
   N:=0;
   Mot:='';
   For I:=1 to Length(Ligne)+1 do Begin
    If(I>Length(Ligne))or(Ligne[I]in[' ',#9,';'])Then Begin
     If Mot<>''Then Begin
      If N<32 Then Begin
       Inc(N);
       Mots[N]:=Mot;
      End;
      Mot:='';
     End;
    End
     Else
    Mot:=Mot+Ligne[I];
   End;
   If N<2 Then Begin
    Close(F);
    Erreur('Ligne invalide dans '+Nom+' : '+Ligne);
   End;
   If Not EstNombre(Mots[N-1],M)or Not EstNombre(Mots[N],B)Then Begin
    Close(F);
    Erreur('Ligne invalide dans '+Nom+' (masse et bras attendus a la fin) : '+Ligne);
   End;
   NomPoste:='';
   For I:=1 to N-2 do Begin
    If NomPoste<>''Then NomPoste:=NomPoste+' ';
    NomPoste:=NomPoste+Mots[I];
   End;
   AjouterPoste(Ch,NomPoste,M,B);
  End;
 End;
 Close(F);
End;

Procedure Totaliser(Var Ch:TChargement);
Var
 I:Integer;
Begin
 Ch.MasseTotale:=0;
 Ch.MomentTotal:=0;
 For I:=1 to Ch.Nombre do Begin
  Ch.MasseTotale:=Ch.MasseTotale+Ch.Poste[I].Masse;
  Ch.MomentTotal:=Ch.MomentTotal+Ch.Poste[I].Moment;
 End;
 If Ch.MasseTotale<=0 Then Erreur('La masse totale doit etre positive');
 Ch.CG:=Ch.MomentTotal/Ch.MasseTotale;
End;

Function PourcentMAC(Bras:Real):Real;Begin
 PourcentMAC:=(Bras-LeMAC)/LongMAC*100.0;
End;

Function FmtCG(Bras:Real):String;Begin
 FmtCG:=Fmt(Bras,3)+' '+UniteBras;
 If HasMAC Then FmtCG:=FmtCG+' ('+Fmt(PourcentMAC(Bras),1)+' % MAC)';
End;

{ Position du centre de gravite comparee a l'enveloppe : en % MAC si une
  MAC est donnee, sinon en bras de levier. }
Function ValeurEnveloppe(Bras:Real):Real;Begin
 If HasMAC Then ValeurEnveloppe:=PourcentMAC(Bras) Else ValeurEnveloppe:=Bras;
End;

{ ---------------------------------------------------------------------
  Enveloppe XAML (meme format que PLANEGRA)
  --------------------------------------------------------------------- }

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

Procedure ChargerEnveloppe(Const Nom:String;Var E:TEnveloppe);
Var
 F:Text;
 Line,Tmp:String;
 I,J,K,Cur,Total:Integer;
 HaveX:Boolean;
 XV,V:Real;
Begin
 E.Nombre:=0;
 Total:=0;
 Cur:=0;
 HaveX:=False;
 XV:=0;
 Assign(F,Nom);
 {$I-}Reset(F);{$I+}
 If IOResult<>0 Then Erreur('Impossible de lire l''enveloppe : '+Nom);
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
     If(Cur=1)and EstNombre(Tmp,V)Then Begin
      If HaveX Then Begin
       If E.Nombre>=MaxPts Then Begin
        Close(F);
        Erreur('L''enveloppe contient trop de points');
       End;
       Inc(E.Nombre);
       E.Pt[E.Nombre].X:=XV;
       E.Pt[E.Nombre].Y:=V;
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
   Inc(I);
  End;
 End;
 Close(F);
 If E.Nombre<3 Then Erreur('L''enveloppe ne contient pas au moins 3 points : '+Nom);
End;

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

Function DansEnveloppe(Var E:TEnveloppe;PX,PY:Real):Boolean;
Var
 I,J:Integer;
 Dedans,Surface:Boolean;
Begin
 Dedans:=False;
 Surface:=False;
 For I:=1 to E.Nombre do Begin
  If I=1 Then J:=E.Nombre Else J:=I-1;
  If DistanceSegment(PX,PY,E.Pt[J].X,E.Pt[J].Y,E.Pt[I].X,E.Pt[I].Y)<=Eps Then
   Surface:=True;
  If(E.Pt[I].Y>PY)<>(E.Pt[J].Y>PY)Then Begin
   If PX<(E.Pt[J].X-E.Pt[I].X)*(PY-E.Pt[I].Y)/(E.Pt[J].Y-E.Pt[I].Y)+
         E.Pt[I].X Then Dedans:=Not Dedans;
  End;
 End;
 DansEnveloppe:=Dedans or Surface;
End;

{ Limites avant et arriere du centre de gravite a la masse M. }
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
  If I=1 Then J:=E.Nombre Else J:=I-1;
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

{ Affiche la position par rapport a l'enveloppe ; retourne False si le point
  est hors de l'enveloppe. }
Function VerifierEnveloppe(Masse,Bras:Real;Detail:Boolean):Boolean;
Var
 Av,Ar,CG:Real;
 Trouve,Ok:Boolean;
Begin
 CG:=ValeurEnveloppe(Bras);
 Ok:=DansEnveloppe(Env,CG,Masse);
 VerifierEnveloppe:=Ok;
 If Detail Then Begin
  LimitesALaMasse(Env,Masse,Av,Ar,Trouve);
  If Ok Then Begin
   WriteLn('Enveloppe              : DANS l''enveloppe (',FichierEnv,')');
   WriteLn('  Marge avant           : ',Fmt(CG-Av,2));
   WriteLn('  Marge arriere         : ',Fmt(Ar-CG,2));
  End
   Else
  Begin
   If Not Trouve Then
    WriteLn('Enveloppe              : HORS enveloppe, masse hors des limites')
   Else Begin
    WriteLn('Enveloppe              : HORS enveloppe (',FichierEnv,')');
    WriteLn('  Limites a cette masse : ',Fmt(Av,2),' a ',Fmt(Ar,2));
    If CG<Av Then WriteLn('  Trop avance de ',Fmt(Av-CG,2))
             Else WriteLn('  Trop recule de ',Fmt(CG-Ar,2));
   End;
  End;
 End;
End;

{ ---------------------------------------------------------------------
  Affichage
  --------------------------------------------------------------------- }

Function IndexCarburant(Var Ch:TChargement):Integer;
Var
 I:Integer;
 U:String;
Begin
 IndexCarburant:=0;
 For I:=1 to Ch.Nombre do Begin
  U:=StrToUpper(Ch.Poste[I].Nom);
  If(Copy(U,1,4)='CARB')or(Copy(U,1,4)='FUEL')Then Begin
   IndexCarburant:=I;
   Exit;
  End;
 End;
End;

Procedure AfficherChargement(Var Ch:TChargement);
Var
 I:Integer;
Begin
 WriteLn('Masse et centrage');
 WriteLn('-----------------');
 WriteLn(Pad('Poste',34),PadGauche('Masse ('+UniteMasse+')',12),
         PadGauche('Bras ('+UniteBras+')',12),PadGauche('Moment',14));
 WriteLn(Pad('-----',34),PadGauche('-----------',12),PadGauche('-----------',12),
         PadGauche('------------',14));
 For I:=1 to Ch.Nombre do Begin
  WriteLn(Pad(Ch.Poste[I].Nom,34),PadGauche(Fmt(Ch.Poste[I].Masse,1),12),
          PadGauche(Fmt(Ch.Poste[I].Bras,3),12),
          PadGauche(Fmt(Ch.Poste[I].Moment,1),14));
 End;
 WriteLn(Pad('Total',34),PadGauche(Fmt(Ch.MasseTotale,1),12),
         PadGauche('',12),PadGauche(Fmt(Ch.MomentTotal,1),14));
 WriteLn;
End;

Procedure AfficherConso(Var Ch:TChargement);
Var
 K,F:Integer;
 Fraction,M,Mo,CG:Real;
 Carb:TPoste;
 Ok:Boolean;
Begin
 K:=IndexCarburant(Ch);
 If K=0 Then Begin
  WriteLn('Consommation du carburant : aucun poste dont le nom commence par ',
          'CARB ou FUEL.');
  Exit;
 End;
 Carb:=Ch.Poste[K];
 WriteLn;
 WriteLn('Deplacement du centre de gravite avec la consommation du carburant');
 WriteLn('(poste "',Carb.Nom,'", bras suppose constant)');
 WriteLn(Pad('Carburant',12),PadGauche('Masse ('+UniteMasse+')',14),
         PadGauche('CG ('+UniteBras+')',12),
         PadGauche('% MAC',9),PadGauche('Enveloppe',12));
 For F:=0 to 4 do Begin
  Fraction:=1.0-F*0.25;
  M:=Ch.MasseTotale-(1.0-Fraction)*Carb.Masse;
  Mo:=Ch.MomentTotal-(1.0-Fraction)*Carb.Moment;
  If M>0 Then Begin
   CG:=Mo/M;
   Write(Pad(Fmt(Fraction*100.0,0)+' %',12),PadGauche(Fmt(M,1),14),
         PadGauche(Fmt(CG,3),12));
   If HasMAC Then Write(PadGauche(Fmt(PourcentMAC(CG),1),9))
             Else Write(PadGauche('-',9));
   If HasEnv Then Begin
    Ok:=DansEnveloppe(Env,ValeurEnveloppe(CG),M);
    If Ok Then WriteLn(PadGauche('dans',12))
          Else WriteLn(PadGauche('HORS',12));
   End
    Else WriteLn(PadGauche('-',12));
  End;
 End;
End;

Procedure AfficherAide;Begin
 WriteLn('CHARGE : Cette commande permet de calculer le centre de gravite d''un ',
         'avion a partir');
 WriteLn('         de son chargement (masse et bras de levier de chaque poste).');
 WriteLn;
 WriteLn('Syntaxe : CHARGE [nom=]masse:bras ... [options]');
 WriteLn('          CHARGE /FICHIER:chargement.txt [options]');
 WriteLn;
 WriteLn(' [nom=]masse:bras   Un poste de chargement (avion vide, pilote, carburant...)');
 WriteLn('                    Les noms de carburant commencent par CARB ou FUEL');
 WriteLn;
 WriteLn('Options :');
 WriteLn(' /FICHIER:nom   Lit les postes dans un fichier texte : une ligne "nom masse bras"');
 WriteLn('                par poste (# = commentaire)');
 WriteLn(' /LB            Masses en livres (kg par defaut)');
 WriteLn(' /BRAS:unite    Unite des bras : M, CM, MM, IN ou FT (M par defaut), pour');
 WriteLn('                l''affichage seulement ; tous les bras doivent etre dans la meme');
 WriteLn(' /MAC:lemac:longueur   Bras du bord d''attaque de la MAC et sa longueur, pour');
 WriteLn('                obtenir le centre de gravite en % MAC');
 WriteLn(' /MTOW:masse    Masse maximale au decollage');
 WriteLn(' /ENV:fichier   Enveloppe masse/centre de gravite au format XAML de PLANEGRA');
 WriteLn('                (comparee en % MAC avec /MAC, sinon en bras de levier)');
 WriteLn(' /CONSO         Deplacement du centre de gravite pendant la consommation du');
 WriteLn('                carburant (100, 75, 50, 25 et 0 %)');
 WriteLn;
 WriteLn('Code de sortie : 0 = Ok, 1 = erreur, 2 = masse ou centre de gravite hors limites');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn(' CHARGE vide=1663:38.5 pilote=170:37 passager=170:37 bagages=40:95 carburant=190:48');
 WriteLn(' CHARGE /FICHIER:SAMPLES\CHARGE\C172.TXT /ENV:SAMPLES\PLANEGRA\C172.XAML /LB /BRAS:IN /CONSO');
End;

Procedure LireOption(Param:String);
Var
 U,Nom,Valeur:String;
 P:Integer;
Begin
 U:=StrToUpper(Param);
 P:=Pos(':',U);
 If P>0 Then Begin
  Nom:=Copy(U,1,P-1);
  Valeur:=Copy(Param,P+1,255);
 End
  Else
 Begin
  Nom:=U;
  Valeur:='';
 End;
 If Nom='/LB'Then Option:=Option+[_Livres] Else
 If Nom='/CONSO'Then Option:=Option+[_Conso] Else
 If Nom='/FICHIER'Then FichierCharge:=Valeur Else
 If Nom='/ENV'Then Begin
  FichierEnv:=Valeur;
  HasEnv:=True;
 End
  Else
 If Nom='/BRAS'Then Begin
  Valeur:=StrToUpper(Valeur);
  If(Valeur<>'M')and(Valeur<>'CM')and(Valeur<>'MM')and(Valeur<>'IN')and
    (Valeur<>'FT')Then Erreur('Unite de bras inconnue : '+Valeur+' (M, CM, MM, IN ou FT)');
  UniteBras:=Valeur;
  If Valeur='M'Then UniteBras:='m' Else
  If Valeur='CM'Then UniteBras:='cm' Else
  If Valeur='MM'Then UniteBras:='mm' Else
  If Valeur='IN'Then UniteBras:='in'
   Else UniteBras:='ft';
 End
  Else
 If Nom='/MTOW'Then Begin
  MTOW:=ParseReal(Valeur,'la masse maximale');
  HasMTOW:=True;
 End
  Else
 If Nom='/MAC'Then Begin
  P:=Pos(':',Valeur);
  If P=0 Then Erreur('Syntaxe de l''option : /MAC:lemac:longueur');
  LeMAC:=ParseReal(Copy(Valeur,1,P-1),'le bras du bord d''attaque de la MAC');
  LongMAC:=ParseReal(Copy(Valeur,P+1,255),'la longueur de la MAC');
  If LongMAC<=0 Then Erreur('La longueur de la MAC doit etre positive');
  HasMAC:=True;
 End
  Else Erreur('Option inconnue : '+Param);
End;

Procedure Interactif;
Var
 S,NomP:String;
 M,B:Real;
Begin
 WriteLn('Calcul du centre de gravite');
 WriteLn('---------------------------');
 WriteLn('Un poste par ligne : nom masse bras (ligne vide pour terminer)');
 Repeat
  Write('Poste ',Chg.Nombre+1,' : ');
  ReadLn(S);
  S:=Trim(S);
  If S<>''Then Begin
   I:=Length(S);
   While(I>0)and Not(S[I]in[' ',#9])do Dec(I);
   If I=0 Then Erreur('Format : nom masse bras');
   If Not EstNombre(Copy(S,I+1,255),B)Then Erreur('Bras invalide');
   S:=Trim(Copy(S,1,I));
   I:=Length(S);
   While(I>0)and Not(S[I]in[' ',#9])do Dec(I);
   If Not EstNombre(Copy(S,I+1,255),M)Then Erreur('Masse invalide');
   NomP:=Trim(Copy(S,1,I));
   AjouterPoste(Chg,NomP,M,B);
  End;
 Until S='';
End;

Var
 Ok,OkEnv,OkMTOW:Boolean;

BEGIN
 Option:=[];
 UniteBras:='m';
 FichierCharge:='';
 FichierEnv:='';
 HasMAC:=False;
 HasMTOW:=False;
 HasEnv:=False;
 LeMAC:=0;
 LongMAC:=1;
 MTOW:=0;
 NArg:=0;
 Chg.Nombre:=0;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  AfficherAide;
  Halt(0);
 End;
 For I:=1 to ParamCount do Begin
  Param:=ParamStr(I);
  If(Length(Param)>0)and(Param[1]='/')Then LireOption(Param)
   Else
  Begin
   If NArg>=MaxItems Then Erreur('Trop de postes de chargement');
   Inc(NArg);
   Arg[NArg]:=Param;
  End;
 End;
 If FichierCharge<>''Then LireFichierCharge(Chg,FichierCharge);
 For I:=1 to NArg do LirePoste(Chg,Arg[I]);
 If(Chg.Nombre=0)and(FichierCharge='')and(NArg=0)Then Interactif;
 If Chg.Nombre=0 Then Erreur('Aucun poste de chargement');
 If HasEnv Then ChargerEnveloppe(FichierEnv,Env);
 Totaliser(Chg);
 AfficherChargement(Chg);
 Ok:=True;
 WriteLn('Masse totale           : ',Fmt(Chg.MasseTotale,1),' ',UniteMasse);
 WriteLn('Moment total           : ',Fmt(Chg.MomentTotal,1),' ',UniteMasse,'.',UniteBras);
 WriteLn('Centre de gravite      : ',FmtCG(Chg.CG));
 If HasMTOW Then Begin
  OkMTOW:=Chg.MasseTotale<=MTOW;
  If OkMTOW Then WriteLn('Masse maximale         : Ok, marge de ',
                         Fmt(MTOW-Chg.MasseTotale,1),' ',UniteMasse)
   Else Begin
    WriteLn('Masse maximale         : DEPASSEE de ',
            Fmt(Chg.MasseTotale-MTOW,1),' ',UniteMasse);
    Ok:=False;
   End;
 End;
 If HasEnv Then Begin
  OkEnv:=VerifierEnveloppe(Chg.MasseTotale,Chg.CG,True);
  If Not OkEnv Then Ok:=False;
 End;
 If _Conso in Option Then AfficherConso(Chg);
 If Not Ok Then Halt(2);
END.
