{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program VITESSES;

{ Conversion des vitesses aeronautiques :
   - IAS (vitesse indiquee), CAS (corrigee), EAS (equivalente), TAS (vraie) et
     Mach, a une altitude-pression donnee, avec la temperature statique
     (SAT) ou totale (TAT) et une correction d'instrument ;
   - altitude de croisement entre une vitesse indiquee et un Mach ;
   - tableau d'une vitesse en fonction de l'altitude ;
   - conversion entre unites (noeuds, km/h, m/s, mph, ft/s). }

Const
 T0=288.15;            { Temperature ISA au niveau de la mer (K) }
 P0=101325.0;          { Pression ISA au niveau de la mer (Pa) }
 G=9.80665;            { Gravite normale (m/s2) }
 RGaz=287.05287;       { Constante specifique de l'air (J/kg/K) }
 Gamma=1.4;            { Rapport des chaleurs specifiques de l'air }
 A0=340.294;           { Vitesse du son ISA au niveau de la mer (m/s) }
 FtM=0.3048;           { Metres par pied }
 KtMS=0.514444;        { Metres par seconde par noeud }
 MphMS=0.44704;        { Metres par seconde par mile a l'heure }
 KmhMS=0.277778;       { Metres par seconde par km/h }
 MinH=-2000.0;         { Altitude geopotentielle minimale (m) }
 MaxH=51000.0;         { Altitude geopotentielle maximale (m) }
 LayerBase:Array[0..4]of Real=(0,11000,20000,32000,47000);
 LayerLapse:Array[0..4]of Real=(-0.0065,0,0.001,0.0028,0);

Type
 TAtm=Record
  H,T,P,Rho,A,Delta,Sigma:Real;
 End;

 TVitesse=Record
  Mach,Cas,Eas,Tas,Ias:Real;   { vitesses en m/s (Mach sans unite) }
  Sat,Tat,A,Qc,P:Real;         { temperatures (K), vitesse du son, pressions (Pa) }
 End;

Var
 Option:Set of (_Metres,_Fahrenheit,_Tat);
 UniteVit:Integer;              { 1 = kt, 2 = km/h, 3 = m/s, 4 = mph, 5 = ft/s }
 Arg:Array[1..8]of String;
 NArg,I:Integer;
 Param,Cmd:String;
 ErreurIas,Recup,DeltaIsa,PasAlt,MaxAlt:Real;
 HasTemp,HasPas,HasMax:Boolean;
 Temperature:Real;

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

{ ---------------------------------------------------------------------
  Unites
  --------------------------------------------------------------------- }

Function VersMS(V:Real;U:Integer):Real;Begin
 Case U of
  2:VersMS:=V*KmhMS;
  3:VersMS:=V;
  4:VersMS:=V*MphMS;
  5:VersMS:=V*FtM;
  Else VersMS:=V*KtMS;
 End;
End;

Function AltToM(V:Real):Real;Begin
 If _Metres in Option Then AltToM:=V Else AltToM:=V*FtM;
End;

Function TempToK(V:Real):Real;Begin
 If _Fahrenheit in Option Then TempToK:=(V-32.0)*5.0/9.0+273.15
                          Else TempToK:=V+273.15;
End;

Function FmtVit(MS:Real):String;Begin
 FmtVit:=PadGauche(Fmt(MS/KtMS,1),9)+' kt'+PadGauche(Fmt(MS/KmhMS,1),10)+' km/h'+
         PadGauche(Fmt(MS,1),8)+' m/s'+PadGauche(Fmt(MS/MphMS,1),9)+' mph';
End;

Function FmtAlt(Hm:Real):String;Begin
 FmtAlt:=Fmt(Hm/FtM,0)+' ft ('+Fmt(Hm,0)+' m)';
End;

Function FmtTemp(K:Real):String;Begin
 FmtTemp:=Fmt(K-273.15,1)+' C ('+Fmt(K,2)+' K, '+Fmt((K-273.15)*1.8+32.0,1)+' F)';
End;

Function Puissance(X,Y:Real):Real;Begin
 Puissance:=Exp(Y*Ln(X));
End;

{ ---------------------------------------------------------------------
  Atmosphere standard
  --------------------------------------------------------------------- }

Procedure LayerState(Tb,Pb,Hb,L,H:Real;Var T,P:Real);Begin
 If Abs(L)<1E-12 Then Begin
  T:=Tb;
  P:=Pb*Exp(-G*(H-Hb)/(RGaz*Tb));
 End
  Else
 Begin
  T:=Tb+L*(H-Hb);
  P:=Pb*Exp(-G/(RGaz*L)*Ln(T/Tb));
 End;
End;

Procedure ISAAt(H:Real;Var A:TAtm);
Var
 I:Integer;
 Tb,Pb,Top,T,P:Real;
 Done:Boolean;
Begin
 Tb:=T0;
 Pb:=P0;
 I:=0;
 Done:=False;
 Repeat
  If I<4 Then Top:=LayerBase[I+1] Else Top:=MaxH;
  If(H<=Top)or(I=4)Then Begin
   LayerState(Tb,Pb,LayerBase[I],LayerLapse[I],H,T,P);
   Done:=True;
  End
   Else
  Begin
   LayerState(Tb,Pb,LayerBase[I],LayerLapse[I],Top,T,P);
   Tb:=T;
   Pb:=P;
   Inc(I);
  End;
 Until Done;
 A.H:=H;
 A.T:=T;
 A.P:=P;
 A.Rho:=P/(RGaz*T);
 A.A:=Sqrt(Gamma*RGaz*T);
 A.Delta:=P/P0;
 A.Sigma:=A.Rho/1.225;
End;

Function AltFromP(P:Real):Real;
Var
 Lo,Hi,Mid:Real;
 K:Integer;
 A:TAtm;
Begin
 Lo:=MinH;
 Hi:=MaxH;
 For K:=1 to 60 do Begin
  Mid:=(Lo+Hi)/2;
  ISAAt(Mid,A);
  If A.P>P Then Lo:=Mid Else Hi:=Mid;
 End;
 AltFromP:=(Lo+Hi)/2;
End;

Procedure VerifierAltitude(Hm:Real);Begin
 If(Hm<MinH)or(Hm>MaxH)Then
  Erreur('Altitude hors limites (de '+Fmt(MinH/FtM,0)+' ft a '+Fmt(MaxH/FtM,0)+' ft)');
End;

{ ---------------------------------------------------------------------
  Pression d'impact (subsonique et supersonique)
  --------------------------------------------------------------------- }

{ Rapport de la pression d'impact a la pression statique, qc/P }
Function QcRatio(M:Real):Real;Begin
 If M<=1.0 Then QcRatio:=Exp(3.5*Ln(1.0+0.2*M*M))-1.0
  Else QcRatio:=166.92158*Exp(7.0*Ln(M))/Exp(2.5*Ln(7.0*M*M-1.0))-1.0;
End;

Function MachFromRatio(Ratio:Real):Real;
Var
 Lo,Hi,Mid:Real;
 K:Integer;
Begin
 Lo:=0.0;
 Hi:=10.0;
 For K:=1 to 60 do Begin
  Mid:=(Lo+Hi)/2;
  If QcRatio(Mid)<Ratio Then Lo:=Mid Else Hi:=Mid;
 End;
 MachFromRatio:=(Lo+Hi)/2;
End;

{ Conversion complete.
  Kind : 1 = IAS, 2 = CAS, 3 = EAS, 4 = TAS, 5 = Mach.
  V    : vitesse en m/s (ou Mach).
  HasT : une temperature est donnee (T ; statique, ou totale si TatMode).
  Sans temperature, la temperature statique est celle de l'ISA corrigee
  de l'ecart DeltaIsa. }
Procedure Convertir(Kind:Integer;V,Hm:Real;HasT:Boolean;T:Real;TatMode:Boolean;
                    Var S:TVitesse);
Var
 A:TAtm;
 M,Qc,Ts,Cas0:Real;
 K:Integer;
Begin
 ISAAt(Hm,A);
 S.P:=A.P;
 If HasT and Not TatMode Then Ts:=T Else Ts:=A.T+DeltaIsa;
 Case Kind of
  1,2:Begin
   If Kind=1 Then Cas0:=V+ErreurIas*KtMS Else Cas0:=V;
   If Cas0<0 Then Erreur('La vitesse corrigee est negative');
   Qc:=P0*QcRatio(Cas0/A0);
   M:=MachFromRatio(Qc/A.P);
  End;
  3:M:=V/(A0*Sqrt(A.Delta));
  5:M:=V;
  Else Begin
   { TAS : le Mach depend de la temperature, qui depend du Mach si elle est totale }
   M:=V/Sqrt(Gamma*RGaz*Ts);
   If HasT and TatMode Then
    For K:=1 to 40 do Begin
     Ts:=T/(1.0+0.2*Recup*M*M);
     M:=V/Sqrt(Gamma*RGaz*Ts);
    End;
  End;
 End;
 If(M<0)or(M>6.0)Then Erreur('Nombre de Mach hors limites (0 a 6)');
 If HasT and TatMode Then Ts:=T/(1.0+0.2*Recup*M*M);
 S.Mach:=M;
 S.Sat:=Ts;
 S.Tat:=Ts*(1.0+0.2*Recup*M*M);
 S.A:=Sqrt(Gamma*RGaz*Ts);
 S.Tas:=M*S.A;
 S.Eas:=M*A0*Sqrt(A.Delta);
 S.Qc:=A.P*QcRatio(M);
 S.Cas:=A0*MachFromRatio(S.Qc/P0);
 S.Ias:=S.Cas-ErreurIas*KtMS;
End;

Function TypeVitesse(S:String):Integer;Begin
 S:=StrToUpper(S);
 If S='IAS'Then TypeVitesse:=1 Else
 If S='CAS'Then TypeVitesse:=2 Else
 If S='EAS'Then TypeVitesse:=3 Else
 If S='TAS'Then TypeVitesse:=4 Else
 If S='MACH'Then TypeVitesse:=5
  Else TypeVitesse:=0;
End;

{ ---------------------------------------------------------------------
  Commandes
  --------------------------------------------------------------------- }

Procedure CmdConvertir(Kind:Integer;V,Hm:Real;HasT:Boolean;T:Real);
Var
 S:TVitesse;
 A:TAtm;
Begin
 VerifierAltitude(Hm);
 If V<0 Then Erreur('La vitesse doit etre positive');
 Convertir(Kind,V,Hm,HasT,T,_Tat in Option,S);
 ISAAt(Hm,A);
 WriteLn('Conversion des vitesses');
 WriteLn('-----------------------');
 WriteLn('Altitude-pression       : ',FmtAlt(Hm));
 WriteLn('Temperature statique    : ',FmtTemp(S.Sat),' (ecart ISA ',
         Fmt(S.Sat-A.T,1),' C)');
 WriteLn('Temperature totale      : ',FmtTemp(S.Tat),' (facteur de recuperation ',
         Fmt(Recup,2),')');
 WriteLn('Vitesse du son          : ',FmtVit(S.A));
 WriteLn;
 WriteLn(Pad('IAS',6),FmtVit(S.Ias));
 WriteLn(Pad('CAS',6),FmtVit(S.Cas));
 WriteLn(Pad('EAS',6),FmtVit(S.Eas));
 WriteLn(Pad('TAS',6),FmtVit(S.Tas));
 WriteLn(Pad('Mach',6),Fmt(S.Mach,4));
 WriteLn;
 WriteLn('Pression d''impact       : ',Fmt(S.Qc/100.0,2),' hPa');
 WriteLn('Pression dynamique      : ',Fmt(0.5*(S.P/(RGaz*S.Sat))*S.Tas*S.Tas/100.0,2),' hPa');
 If ErreurIas<>0 Then WriteLn('IAS = CAS - ',Fmt(ErreurIas,1),' kt (correction d''instrument)')
  Else WriteLn('IAS suppose egal a CAS (sans erreur d''instrument ni de position).');
 If S.Mach>1.0 Then WriteLn('Regime supersonique : onde de choc devant la prise de pression.');
End;

Procedure CmdCroisement(Cas,Mach:Real);
Var
 Qc,P,H:Real;
 A:TAtm;
Begin
 If(Cas<=0)or(Mach<=0)or(Mach>=1.0)Then
  Erreur('La CAS doit etre positive et le Mach entre 0 et 1');
 Qc:=P0*QcRatio(Cas/A0);
 P:=Qc/QcRatio(Mach);
 If(P<80.0)or(P>=P0*1.2)Then Erreur('Pas de croisement dans la plage de l''atmosphere standard');
 H:=AltFromP(P);
 ISAAt(H,A);
 WriteLn('Altitude de croisement CAS / Mach');
 WriteLn('---------------------------------');
 WriteLn('CAS                     : ',FmtVit(Cas));
 WriteLn('Mach                    : ',Fmt(Mach,3));
 WriteLn;
 WriteLn('Altitude de croisement  : ',FmtAlt(H),' (altitude-pression ISA)');
 WriteLn('Pression statique       : ',Fmt(P/100.0,1),' hPa');
 WriteLn('TAS au croisement       : ',FmtVit(Mach*A.A));
 WriteLn;
 WriteLn('Sous cette altitude la CAS de ',Fmt(Cas/KtMS,0),
         ' kt correspond a un Mach inferieur a ',Fmt(Mach,2),' ;');
 WriteLn('au-dessus, c''est le Mach ',Fmt(Mach,2),' que l''on tient en montee.');
End;

Procedure CmdTable(Kind:Integer;V:Real);
Var
 H,Pas,Hmax:Real;
 S:TVitesse;
 K:Integer;
Begin
 If HasPas Then Pas:=PasAlt Else Pas:=5000.0*FtM;
 If HasMax Then Hmax:=MaxAlt Else Hmax:=50000.0*FtM;
 If _Metres in Option Then Begin
  If Not HasPas Then Pas:=1000.0;
  If Not HasMax Then Hmax:=15000.0;
 End;
 If(Pas<=0)or(Hmax<0)Then Erreur('Le pas et l''altitude maximale doivent etre positifs');
 WriteLn('Vitesses en fonction de l''altitude (atmosphere standard',
         ' ecart ISA ',Fmt(DeltaIsa,0),' C)');
 WriteLn;
 WriteLn(PadGauche('Altitude (ft)',14),PadGauche('IAS (kt)',10),PadGauche('CAS (kt)',10),
         PadGauche('EAS (kt)',10),PadGauche('TAS (kt)',10),PadGauche('Mach',8));
 H:=0;
 K:=0;
 While(H<=Hmax+0.1)and(K<100)do Begin
  Convertir(Kind,V,H,False,0,False,S);
  WriteLn(PadGauche(Fmt(H/FtM,0),14),PadGauche(Fmt(S.Ias/KtMS,1),10),
          PadGauche(Fmt(S.Cas/KtMS,1),10),PadGauche(Fmt(S.Eas/KtMS,1),10),
          PadGauche(Fmt(S.Tas/KtMS,1),10),PadGauche(Fmt(S.Mach,3),8));
  H:=H+Pas;
  Inc(K);
 End;
End;

Procedure CmdUnites(V:Real;U:Integer);
Var
 MS:Real;
Begin
 MS:=VersMS(V,U);
 WriteLn('Conversion d''unites de vitesse');
 WriteLn('-------------------------------');
 WriteLn(PadGauche(Fmt(MS/KtMS,3),14),' noeuds (kt)');
 WriteLn(PadGauche(Fmt(MS/KmhMS,3),14),' kilometres par heure');
 WriteLn(PadGauche(Fmt(MS,3),14),' metres par seconde');
 WriteLn(PadGauche(Fmt(MS/MphMS,3),14),' milles par heure (mph)');
 WriteLn(PadGauche(Fmt(MS/FtM,3),14),' pieds par seconde');
 WriteLn(PadGauche(Fmt(MS/FtM*60.0,1),14),' pieds par minute');
 WriteLn(PadGauche(Fmt(MS/A0,4),14),' Mach au niveau de la mer (ISA)');
End;

Procedure AfficherAide;Begin
 WriteLn('VITESSES : Cette commande permet de convertir les vitesses ',
         'aeronautiques (IAS, CAS, EAS,');
 WriteLn('           TAS et Mach) et les unites de vitesse.');
 WriteLn;
 WriteLn('Syntaxe : VITESSES type valeur altitude [temp] [options]');
 WriteLn('          VITESSES CROISEMENT cas mach');
 WriteLn('          VITESSES TABLE type valeur [options]');
 WriteLn('          VITESSES UNITES valeur unite');
 WriteLn;
 WriteLn(' type       IAS, CAS, EAS, TAS ou MACH');
 WriteLn(' valeur     La vitesse (noeuds par defaut) ou le nombre de Mach');
 WriteLn(' altitude   Altitude-pression (pieds par defaut)');
 WriteLn(' temp       Temperature de l''air (Celsius), statique ou totale avec /TAT ;');
 WriteLn('            ISA par defaut');
 WriteLn(' unite      KT, KMH, MS, MPH ou FTS (pour UNITES)');
 WriteLn;
 WriteLn('Options :');
 WriteLn(' /KT /KMH /MS /MPH /FTS   Unite de la vitesse saisie (noeuds par defaut)');
 WriteLn(' /M             Altitudes en metres');
 WriteLn(' /F             Temperature en Fahrenheit');
 WriteLn(' /TAT           La temperature donnee est la temperature totale (TAT)');
 WriteLn(' /K:x           Facteur de recuperation de la sonde de TAT (1 par defaut)');
 WriteLn(' /ERREUR:kt     Correction d''instrument : CAS = IAS + valeur');
 WriteLn(' /DISA:deg      Ecart de temperature a l''ISA (TABLE)');
 WriteLn(' /PAS:ft        Pas d''altitude du tableau (5 000 ft par defaut)');
 WriteLn(' /MAX:ft        Altitude maximale du tableau (50 000 ft par defaut)');
 WriteLn;
 WriteLn('Code de sortie : 0 = Ok, 1 = erreur');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn(' VITESSES IAS 250 30000');
 WriteLn(' VITESSES MACH 0.82 37000 -56.5');
 WriteLn(' VITESSES TAS 480 35000 -38 /TAT');
 WriteLn(' VITESSES CROISEMENT 280 0.78');
 WriteLn(' VITESSES TABLE MACH 0.78 /PAS:10000');
 WriteLn(' VITESSES UNITES 250 KMH');
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
 If Nom='/KT'Then UniteVit:=1 Else
 If Nom='/KMH'Then UniteVit:=2 Else
 If Nom='/MS'Then UniteVit:=3 Else
 If Nom='/MPH'Then UniteVit:=4 Else
 If Nom='/FTS'Then UniteVit:=5 Else
 If Nom='/M'Then Option:=Option+[_Metres] Else
 If Nom='/F'Then Option:=Option+[_Fahrenheit] Else
 If Nom='/TAT'Then Option:=Option+[_Tat] Else
 If Nom='/K'Then Begin
  Recup:=ParseReal(Valeur,'le facteur de recuperation');
  If(Recup<=0)or(Recup>1.0)Then Erreur('Le facteur de recuperation doit etre entre 0 et 1');
 End
  Else
 If Nom='/ERREUR'Then ErreurIas:=ParseReal(Valeur,'la correction') Else
 If Nom='/DISA'Then DeltaIsa:=ParseReal(Valeur,'l''ecart de temperature') Else
 If Nom='/PAS'Then Begin
  PasAlt:=ParseReal(Valeur,'le pas');
  HasPas:=True;
 End
  Else
 If Nom='/MAX'Then Begin
  MaxAlt:=ParseReal(Valeur,'l''altitude maximale');
  HasMax:=True;
 End
  Else Erreur('Option inconnue : '+Param);
End;

Procedure AjouterArg(S:String);Begin
 If NArg>=8 Then Erreur('Trop de parametres');
 Inc(NArg);
 Arg[NArg]:=S;
End;

Procedure Interactif;
Var
 S:String;
 Choix:Char;
Begin
 WriteLn('Conversion des vitesses');
 WriteLn('-----------------------');
 WriteLn(' 1 - Conversion IAS / CAS / EAS / TAS / Mach');
 WriteLn(' 2 - Altitude de croisement CAS / Mach');
 WriteLn(' 3 - Tableau en fonction de l''altitude');
 WriteLn(' 4 - Conversion d''unites');
 Write('Choix : ');
 ReadLn(S);
 S:=Trim(S);
 If S='' Then Erreur('Choix invalide');
 Choix:=S[1];
 Case Choix of
  '1':Begin
   Write('Type (IAS, CAS, EAS, TAS ou MACH) : ');ReadLn(S);AjouterArg(StrToUpper(Trim(S)));
   Write('Valeur (noeuds ou Mach) : ');ReadLn(S);AjouterArg(Trim(S));
   Write('Altitude-pression (ft) : ');ReadLn(S);AjouterArg(Trim(S));
   Write('Temperature en Celsius (vide = ISA) : ');ReadLn(S);
   If Trim(S)<>''Then AjouterArg(Trim(S));
  End;
  '2':Begin
   AjouterArg('CROISEMENT');
   Write('CAS (kt) : ');ReadLn(S);AjouterArg(Trim(S));
   Write('Mach : ');ReadLn(S);AjouterArg(Trim(S));
  End;
  '3':Begin
   AjouterArg('TABLE');
   Write('Type (IAS, CAS, EAS, TAS ou MACH) : ');ReadLn(S);AjouterArg(StrToUpper(Trim(S)));
   Write('Valeur (noeuds ou Mach) : ');ReadLn(S);AjouterArg(Trim(S));
  End;
  '4':Begin
   AjouterArg('UNITES');
   Write('Valeur : ');ReadLn(S);AjouterArg(Trim(S));
   Write('Unite (KT, KMH, MS, MPH ou FTS) : ');ReadLn(S);AjouterArg(StrToUpper(Trim(S)));
  End;
  Else Erreur('Choix invalide');
 End;
 WriteLn;
End;

Function UniteDepuisNom(S:String):Integer;Begin
 S:=StrToUpper(S);
 If S='KT'Then UniteDepuisNom:=1 Else
 If S='KMH'Then UniteDepuisNom:=2 Else
 If S='MS'Then UniteDepuisNom:=3 Else
 If S='MPH'Then UniteDepuisNom:=4 Else
 If S='FTS'Then UniteDepuisNom:=5
  Else UniteDepuisNom:=0;
End;

Var
 Kind,U:Integer;
 V:Real;
 TK:Real;

BEGIN
 Option:=[];
 UniteVit:=1;
 NArg:=0;
 ErreurIas:=0;
 Recup:=1.0;
 DeltaIsa:=0;
 PasAlt:=0;
 MaxAlt:=0;
 HasPas:=False;
 HasMax:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  AfficherAide;
  Halt(0);
 End;
 For I:=1 to ParamCount do Begin
  Param:=ParamStr(I);
  If(Length(Param)>0)and(Param[1]='/')Then LireOption(Param)
   Else AjouterArg(Param);
 End;
 If NArg=0 Then Interactif;
 Cmd:=StrToUpper(Arg[1]);
 { Les options /PAS et /MAX sont saisies en pieds, ou en metres avec /M }
 If HasPas Then PasAlt:=AltToM(PasAlt);
 If HasMax Then MaxAlt:=AltToM(MaxAlt);
 If Cmd='CROISEMENT'Then Begin
  If NArg<>3 Then Erreur('Syntaxe : VITESSES CROISEMENT cas mach');
  CmdCroisement(VersMS(ParseReal(Arg[2],'la CAS'),UniteVit),ParseReal(Arg[3],'le Mach'));
 End
  Else
 If Cmd='UNITES'Then Begin
  If NArg<>3 Then Erreur('Syntaxe : VITESSES UNITES valeur unite');
  U:=UniteDepuisNom(Arg[3]);
  If U=0 Then Erreur('Unite inconnue : '+Arg[3]+' (KT, KMH, MS, MPH ou FTS)');
  CmdUnites(ParseReal(Arg[2],'la valeur'),U);
 End
  Else
 If Cmd='TABLE'Then Begin
  If NArg<>3 Then Erreur('Syntaxe : VITESSES TABLE type valeur');
  Kind:=TypeVitesse(Arg[2]);
  If Kind=0 Then Erreur('Type de vitesse inconnu : '+Arg[2]+' (IAS, CAS, EAS, TAS ou MACH)');
  V:=ParseReal(Arg[3],'la vitesse');
  If Kind<5 Then V:=VersMS(V,UniteVit);
  CmdTable(Kind,V);
 End
  Else
 Begin
  Kind:=TypeVitesse(Arg[1]);
  If Kind=0 Then Erreur('Commande inconnue : '+Arg[1]+
                        ' (IAS, CAS, EAS, TAS, MACH, CROISEMENT, TABLE ou UNITES)');
  If(NArg<3)or(NArg>4)Then Erreur('Syntaxe : VITESSES type valeur altitude [temp]');
  V:=ParseReal(Arg[2],'la vitesse');
  If Kind<5 Then V:=VersMS(V,UniteVit);
  TK:=0;
  If NArg=4 Then TK:=TempToK(ParseReal(Arg[4],'la temperature'));
  CmdConvertir(Kind,V,AltToM(ParseReal(Arg[3],'l''altitude')),NArg=4,TK);
 End;
END.
