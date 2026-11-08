{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program ATMOSPH;

{ Atmosphere standard internationale (ISA, jusqu'a 51 km) et vitesses :
   - temperature, pression, densite et vitesse du son a l'altitude ;
   - altitude-pression et altitude-densite ;
   - conversion entre IAS, CAS, EAS, TAS et Mach ;
   - calage altimetrique (QNH, QFE) et altitude indiquee. }

Const
 T0=288.15;            { Temperature ISA au niveau de la mer (K) }
 P0=101325.0;          { Pression ISA au niveau de la mer (Pa) }
 G=9.80665;            { Gravite normale (m/s2) }
 RGaz=287.05287;       { Constante specifique de l'air (J/kg/K) }
 Gamma=1.4;            { Rapport des chaleurs specifiques de l'air }
 A0=340.294;           { Vitesse du son ISA au niveau de la mer (m/s) }
 Rho0=1.225;           { Densite ISA au niveau de la mer (kg/m3) }
 FtM=0.3048;           { Metres par pied }
 KtMS=0.514444;        { Metres par seconde par noeud }
 MphMS=0.44704;        { Metres par seconde par mile a l'heure }
 KmhMS=0.277778;       { Metres par seconde par km/h }
 InHgPa=3386.389;      { Pascals par pouce de mercure }
 MinH=-2000.0;         { Altitude geopotentielle minimale (m) }
 MaxH=51000.0;         { Altitude geopotentielle maximale (m) }
 LayerBase:Array[0..4]of Real=(0,11000,20000,32000,47000);
 LayerLapse:Array[0..4]of Real=(-0.0065,0,0.001,0.0028,0);

Type
 TAtm=Record
  H,T,P,Rho,A,Mu,Nu,Theta,Delta,Sigma:Real;
 End;

 TSpeed=Record
  Mach,CAS,EAS,TAS,A,T,P,Qc,Tat:Real;
 End;

Var
 Option:Set of (_Metres,_Fahrenheit,_InHg);
 SpeedUnit:Integer;           { 1=kt, 2=km/h, 3=m/s, 4=mph }
 Arg:Array[1..8]of String;
 NPos,I:Integer;
 Param,Cmd:String;

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

Procedure Erreur(Msg:String);Begin
 WriteLn(Msg);
 Halt(1);
End;

Function ParseReal(Const S,Nom:String):Real;
Var
 T:String;
 R:Real;
 Code,I:Integer;
Begin
 T:=Trim(S);
 For I:=1 to Length(T)do If T[I]=','Then T[I]:='.';
 Val(T,R,Code);
 If(Code<>0)or(T='')Then Erreur('Valeur invalide pour '+Nom+' : '+S);
 ParseReal:=R;
End;

{ ---------------------------------------------------------------------
  Conversions d'unites d'entree (vers SI) et de sortie
  --------------------------------------------------------------------- }

Function AltToM(V:Real):Real;Begin
 If _Metres in Option Then AltToM:=V Else AltToM:=V*FtM;
End;

Function PressToPa(V:Real):Real;Begin
 If _InHg in Option Then PressToPa:=V*InHgPa Else PressToPa:=V*100.0;
End;

Function TempToK(V:Real):Real;Begin
 If _Fahrenheit in Option Then TempToK:=(V-32.0)*5.0/9.0+273.15
                          Else TempToK:=V+273.15;
End;

Function SpeedToMS(V:Real):Real;Begin
 Case SpeedUnit of
  2:SpeedToMS:=V*KmhMS;
  3:SpeedToMS:=V;
  4:SpeedToMS:=V*MphMS;
  Else SpeedToMS:=V*KtMS;
 End;
End;

Function FmtAlt(Hm:Real):String;Begin
 FmtAlt:=Fmt(Hm/FtM,0)+' ft ('+Fmt(Hm,0)+' m)';
End;

Function FmtPress(P:Real):String;Begin
 FmtPress:=Fmt(P/100.0,2)+' hPa ('+Fmt(P/InHgPa,2)+' inHg)';
End;

Function FmtTemp(TK:Real):String;Begin
 FmtTemp:=Fmt(TK-273.15,1)+' C ('+Fmt(TK,2)+' K, '+
          Fmt((TK-273.15)*1.8+32.0,1)+' F)';
End;

Function FmtSpeed(MS:Real):String;Begin
 FmtSpeed:=Pad(Fmt(MS/KtMS,1)+' kt',13)+Pad(Fmt(MS/KmhMS,1)+' km/h',14)+
           Pad(Fmt(MS,1)+' m/s',12)+Fmt(MS/MphMS,1)+' mph';
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

{ Proprietes ISA a l'altitude geopotentielle H (en metres). }
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
 A.Mu:=1.458E-6*T*Sqrt(T)/(T+110.4);
 A.Nu:=A.Mu/A.Rho;
 A.Theta:=T/T0;
 A.Delta:=P/P0;
 A.Sigma:=A.Rho/Rho0;
End;

{ Altitude geopotentielle ISA correspondant a une pression statique (Pa). }
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

{ Altitude geopotentielle ISA correspondant a une densite (kg/m3). }
Function AltFromRho(Rho:Real):Real;
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
  If A.Rho>Rho Then Lo:=Mid Else Hi:=Mid;
 End;
 AltFromRho:=(Lo+Hi)/2;
End;

Procedure VerifierAltitude(Hm:Real);Begin
 If(Hm<MinH)or(Hm>MaxH)Then
  Erreur('Altitude hors limites (de '+Fmt(MinH/FtM,0)+' ft a '+
         Fmt(MaxH/FtM,0)+' ft)');
End;

Procedure VerifierPression(P:Real;Nom:String);Begin
 If(P<30000.0)or(P>127000.0)Then
  Erreur(Nom+' hors limites (300 a 1270 hPa)');
End;

{ ---------------------------------------------------------------------
  Vitesses : pression d'impact (subsonique et supersonique, Rayleigh)
  --------------------------------------------------------------------- }

{ Rapport de la pression d'impact a la pression statique, qc/P, en
  fonction du nombre de Mach. }
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

{ Kind : 1 = IAS/CAS, 2 = EAS, 3 = TAS, 4 = Mach. PAm est l'altitude-pression
  en metres ; HasT/TK donnent la temperature statique reelle (sinon ISA). }
Procedure CalcSpeeds(Kind:Integer;V,PAm:Real;HasT:Boolean;TK:Real;
                     Var S:TSpeed);
Var
 A:TAtm;
 M,Qc:Real;
Begin
 ISAAt(PAm,A);
 If HasT Then S.T:=TK Else S.T:=A.T;
 S.P:=A.P;
 S.A:=Sqrt(Gamma*RGaz*S.T);
 Case Kind of
  1:Begin
   Qc:=P0*QcRatio(V/A0);
   M:=MachFromRatio(Qc/A.P);
  End;
  2:M:=V/(A0*Sqrt(A.Delta));
  3:M:=V/S.A;
  Else M:=V;
 End;
 If(M<0)or(M>6.0)Then Erreur('Nombre de Mach hors limites (0 a 6)');
 S.Mach:=M;
 S.TAS:=M*S.A;
 S.EAS:=M*A0*Sqrt(A.Delta);
 S.Qc:=A.P*QcRatio(M);
 S.CAS:=A0*MachFromRatio(S.Qc/P0);
 S.Tat:=S.T*(1.0+0.2*M*M);
End;

{ ---------------------------------------------------------------------
  Commandes
  --------------------------------------------------------------------- }

Procedure CmdISA(Hm:Real;HasT:Boolean;TK:Real);
Var
 A:TAtm;
 RhoR,DA:Real;
Begin
 VerifierAltitude(Hm);
 ISAAt(Hm,A);
 WriteLn('Atmosphere standard (ISA)');
 WriteLn('-------------------------');
 WriteLn('Altitude (pression)       : ',FmtAlt(Hm));
 WriteLn('Temperature ISA           : ',FmtTemp(A.T));
 WriteLn('Pression statique         : ',FmtPress(A.P));
 WriteLn('Densite                   : ',Fmt(A.Rho,4),' kg/m3');
 WriteLn('Rapports                  : sigma=',Fmt(A.Sigma,4),
         ' delta=',Fmt(A.Delta,4),' theta=',Fmt(A.Theta,4));
 WriteLn('Vitesse du son            : ',FmtSpeed(A.A));
 WriteLn('Viscosite dynamique       : ',Fmt(A.Mu*1E6,3),' E-6 Pa.s');
 WriteLn('Viscosite cinematique     : ',Fmt(A.Nu*1E6,3),' E-6 m2/s');
 If HasT Then Begin
  RhoR:=A.P/(RGaz*TK);
  DA:=AltFromRho(RhoR);
  WriteLn;
  WriteLn('Avec la temperature reelle');
  WriteLn('Temperature               : ',FmtTemp(TK));
  WriteLn('Ecart a l''ISA             : ',Fmt(TK-A.T,1),' C');
  WriteLn('Densite reelle            : ',Fmt(RhoR,4),' kg/m3 (sigma=',
          Fmt(RhoR/Rho0,4),')');
  WriteLn('Vitesse du son reelle     : ',FmtSpeed(Sqrt(Gamma*RGaz*TK)));
  WriteLn('Altitude-pression         : ',FmtAlt(Hm));
  WriteLn('Altitude-densite          : ',FmtAlt(DA));
 End;
End;

Procedure CmdVitesse(Kind:Integer;V,Hm:Real;HasT:Boolean;TK:Real);
Var
 S:TSpeed;
 A:TAtm;
Begin
 VerifierAltitude(Hm);
 If V<0 Then Erreur('La vitesse doit etre positive');
 CalcSpeeds(Kind,V,Hm,HasT,TK,S);
 ISAAt(Hm,A);
 WriteLn('Conversion des vitesses');
 WriteLn('-----------------------');
 WriteLn('Altitude-pression : ',FmtAlt(Hm));
 If HasT Then WriteLn('Temperature       : ',FmtTemp(S.T),' (ecart ISA ',
                      Fmt(S.T-A.T,1),' C)')
         Else WriteLn('Temperature       : ',FmtTemp(S.T),' (ISA)');
 WriteLn('Vitesse du son    : ',FmtSpeed(S.A));
 WriteLn;
 WriteLn(Pad('IAS (= CAS)',13),FmtSpeed(S.CAS));
 WriteLn(Pad('CAS',13),FmtSpeed(S.CAS));
 WriteLn(Pad('EAS',13),FmtSpeed(S.EAS));
 WriteLn(Pad('TAS',13),FmtSpeed(S.TAS));
 WriteLn(Pad('Mach',13),Fmt(S.Mach,4));
 WriteLn;
 WriteLn('Pression d''impact  : ',FmtPress(S.Qc));
 WriteLn('Temperature totale: ',FmtTemp(S.Tat),' (recuperation ideale)');
 WriteLn('IAS suppose egal a CAS (sans erreur d''instrument ni de position).');
 If S.Mach>1.0 Then WriteLn('Regime supersonique : onde de choc devant la prise de pression.');
End;

Procedure CmdTerrain(Elev,Qnh:Real;HasT:Boolean;TK:Real);
Var
 A,B:TAtm;
 Qfe,PA,RhoR,DA:Real;
Begin
 VerifierAltitude(Elev);
 VerifierPression(Qnh,'Le QNH');
 ISAAt(Elev,A);
 Qfe:=Qnh*A.P/P0;
 PA:=AltFromP(Qfe);
 ISAAt(PA,B);
 WriteLn('Conditions du terrain');
 WriteLn('---------------------');
 WriteLn('Altitude du terrain : ',FmtAlt(Elev));
 WriteLn('QNH                 : ',FmtPress(Qnh));
 WriteLn('QFE                 : ',FmtPress(Qfe));
 WriteLn('Altitude-pression   : ',FmtAlt(PA),'  (',
         Fmt((PA-Elev)/FtM,0),' ft par rapport au terrain)');
 If HasT Then Begin
  RhoR:=Qfe/(RGaz*TK);
  DA:=AltFromRho(RhoR);
  WriteLn('Temperature         : ',FmtTemp(TK),' (ecart ISA ',
          Fmt(TK-B.T,1),' C)');
  WriteLn('Densite de l''air    : ',Fmt(RhoR,4),' kg/m3 (sigma=',
          Fmt(RhoR/Rho0,4),')');
  WriteLn('Altitude-densite    : ',FmtAlt(DA),'  (',
          Fmt((DA-Elev)/FtM,0),' ft par rapport au terrain)');
  If DA>Elev+300.0 Then
   WriteLn('Les performances sont celles d''un terrain plus haut de ',
           Fmt((DA-Elev)/FtM,0),' ft.');
 End;
End;

Procedure CmdQNH(Elev,Qfe:Real);
Var
 A:TAtm;
Begin
 VerifierAltitude(Elev);
 VerifierPression(Qfe,'Le QFE');
 ISAAt(Elev,A);
 WriteLn('Altitude du terrain : ',FmtAlt(Elev));
 WriteLn('QFE                 : ',FmtPress(Qfe));
 WriteLn('QNH                 : ',FmtPress(Qfe*P0/A.P));
End;

Procedure CmdQFE(Elev,Qnh:Real);
Var
 A:TAtm;
Begin
 VerifierAltitude(Elev);
 VerifierPression(Qnh,'Le QNH');
 ISAAt(Elev,A);
 WriteLn('Altitude du terrain : ',FmtAlt(Elev));
 WriteLn('QNH                 : ',FmtPress(Qnh));
 WriteLn('QFE                 : ',FmtPress(Qnh*A.P/P0));
End;

Procedure CmdAlti(PAm,Setting:Real);
Var
 A:TAtm;
 Ind:Real;
Begin
 VerifierAltitude(PAm);
 VerifierPression(Setting,'Le calage');
 ISAAt(PAm,A);
 Ind:=AltFromP(A.P*P0/Setting);
 WriteLn('Altitude-pression   : ',FmtAlt(PAm));
 WriteLn('Calage altimetrique : ',FmtPress(Setting));
 WriteLn('Altitude indiquee   : ',FmtAlt(Ind));
 WriteLn('Difference          : ',Fmt((Ind-PAm)/FtM,0),' ft');
End;

Procedure AfficherAide;Begin
 WriteLn('ATMOSPH : Cette commande permet de calculer l''atmosphere standard ',
         '(ISA), les vitesses');
 WriteLn('          (IAS, CAS, EAS, TAS, Mach) et le calage altimetrique ',
         '(QNH, QFE).');
 WriteLn;
 WriteLn('Syntaxe : ATMOSPH commande parametres [options]');
 WriteLn;
 WriteLn(' ISA alt [temp]                   Temperature, pression, densite et vitesse du son');
 WriteLn('                                  a l''altitude-pression ; avec la temperature');
 WriteLn('                                  reelle, ecart ISA et altitude-densite');
 WriteLn(' VITESSE type valeur alt [temp]   Conversion entre IAS, CAS, EAS, TAS et Mach ;');
 WriteLn('                                  type = IAS, CAS, EAS, TAS ou MACH');
 WriteLn(' TERRAIN elev qnh [temp]          QFE, altitude-pression et altitude-densite');
 WriteLn('                                  d''un terrain');
 WriteLn(' QNH elev qfe                     Calcule le QNH a partir du QFE');
 WriteLn(' QFE elev qnh                     Calcule le QFE a partir du QNH');
 WriteLn(' ALTI alt_pression calage         Altitude indiquee pour un calage donne');
 WriteLn;
 WriteLn(' alt, elev   Altitudes (en pieds par defaut)');
 WriteLn(' temp        Temperature statique de l''air (Celsius par defaut)');
 WriteLn(' qnh, qfe    Pressions (hPa par defaut)');
 WriteLn;
 WriteLn('Options :');
 WriteLn(' /M          Altitudes en metres');
 WriteLn(' /F          Temperature en Fahrenheit');
 WriteLn(' /INHG       Pressions en pouces de mercure');
 WriteLn(' /KT /KMH /MS /MPH   Unite de la vitesse donnee (/KT par defaut)');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn(' ATMOSPH ISA 35000');
 WriteLn(' ATMOSPH ISA 5000 25');
 WriteLn(' ATMOSPH VITESSE IAS 250 30000');
 WriteLn(' ATMOSPH VITESSE MACH 0.82 37000 -56.5');
 WriteLn(' ATMOSPH TERRAIN 5430 1008 30');
 WriteLn(' ATMOSPH QNH 1000 1003.5');
 WriteLn(' ATMOSPH ALTI 5000 1030');
 WriteLn;
 WriteLn('Code de sortie : 0 = Ok, 1 = erreur');
End;

Function LireOuNul(Prompt:String;Var HasVal:Boolean):Real;
Var
 S:String;
Begin
 Write(Prompt);
 ReadLn(S);
 If Trim(S)=''Then Begin
  HasVal:=False;
  LireOuNul:=0;
 End
  Else
 Begin
  HasVal:=True;
  LireOuNul:=ParseReal(S,'la valeur');
 End;
End;

Function LireValeur(Prompt:String):Real;
Var
 S:String;
Begin
 Write(Prompt);
 ReadLn(S);
 LireValeur:=ParseReal(S,'la valeur');
End;

Procedure Interactif;
Var
 Choix:String;
 HasT:Boolean;
 V,H,T,Q:Real;
 Kind:Integer;
Begin
 WriteLn('Atmosphere et vitesses');
 WriteLn('----------------------');
 WriteLn(' 1 - Atmosphere standard a une altitude');
 WriteLn(' 2 - Conversion de vitesses (IAS, CAS, EAS, TAS, Mach)');
 WriteLn(' 3 - Conditions d''un terrain (QFE, altitude-densite)');
 WriteLn(' 4 - QNH a partir du QFE');
 WriteLn(' 5 - QFE a partir du QNH');
 WriteLn(' 6 - Altitude indiquee selon le calage');
 Write('Choix : ');
 ReadLn(Choix);
 WriteLn('(altitudes en pieds, temperatures en Celsius, pressions en hPa, ',
         'vitesses en noeuds)');
 Choix:=Trim(Choix);
 If Choix=''Then Erreur('Choix invalide');
 Case Choix[1] of
  '1':Begin
   H:=AltToM(LireValeur('Altitude-pression : '));
   T:=LireOuNul('Temperature (vide = ISA) : ',HasT);
   WriteLn;
   CmdISA(H,HasT,TempToK(T));
  End;
  '2':Begin
   Write('Type (IAS, CAS, EAS, TAS ou MACH) : ');
   ReadLn(Choix);
   Choix:=StrToUpper(Trim(Choix));
   If(Choix='IAS')or(Choix='CAS')Then Kind:=1 Else
   If Choix='EAS'Then Kind:=2 Else
   If Choix='TAS'Then Kind:=3 Else
   If Choix='MACH'Then Kind:=4
    Else Erreur('Type de vitesse inconnu');
   V:=LireValeur('Valeur : ');
   If Kind<4 Then V:=SpeedToMS(V);
   H:=AltToM(LireValeur('Altitude-pression : '));
   T:=LireOuNul('Temperature (vide = ISA) : ',HasT);
   WriteLn;
   CmdVitesse(Kind,V,H,HasT,TempToK(T));
  End;
  '3':Begin
   H:=AltToM(LireValeur('Altitude du terrain : '));
   Q:=PressToPa(LireValeur('QNH : '));
   T:=LireOuNul('Temperature (vide = aucune) : ',HasT);
   WriteLn;
   CmdTerrain(H,Q,HasT,TempToK(T));
  End;
  '4':Begin
   H:=AltToM(LireValeur('Altitude du terrain : '));
   Q:=PressToPa(LireValeur('QFE : '));
   WriteLn;
   CmdQNH(H,Q);
  End;
  '5':Begin
   H:=AltToM(LireValeur('Altitude du terrain : '));
   Q:=PressToPa(LireValeur('QNH : '));
   WriteLn;
   CmdQFE(H,Q);
  End;
  '6':Begin
   H:=AltToM(LireValeur('Altitude-pression : '));
   Q:=PressToPa(LireValeur('Calage altimetrique : '));
   WriteLn;
   CmdAlti(H,Q);
  End;
  Else Erreur('Choix invalide');
 End;
End;

Procedure ExigerParametres(Min,Max:Integer;Syntaxe:String);Begin
 If(NPos<Min)or(NPos>Max)Then Erreur('Syntaxe : ATMOSPH '+Syntaxe);
End;

Procedure LireOption(Param:String);
Var
 U:String;
Begin
 U:=StrToUpper(Param);
 If U='/M'Then Option:=Option+[_Metres] Else
 If U='/F'Then Option:=Option+[_Fahrenheit] Else
 If U='/INHG'Then Option:=Option+[_InHg] Else
 If U='/KT'Then SpeedUnit:=1 Else
 If U='/KMH'Then SpeedUnit:=2 Else
 If U='/MS'Then SpeedUnit:=3 Else
 If U='/MPH'Then SpeedUnit:=4
  Else Erreur('Option inconnue : '+Param);
End;

Var
 HasT:Boolean;
 Kind:Integer;
 TypeStr:String;
 V:Real;

BEGIN
 Option:=[];
 SpeedUnit:=1;
 NPos:=0;
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
   If NPos>=8 Then Erreur('Trop de parametres');
   Inc(NPos);
   Arg[NPos]:=Param;
  End;
 End;
 If NPos=0 Then Begin
  Interactif;
  Halt(0);
 End;
 Cmd:=StrToUpper(Arg[1]);
 If Cmd='ISA'Then Begin
  ExigerParametres(2,3,'ISA alt [temp]');
  HasT:=NPos=3;
  V:=0;
  If HasT Then V:=TempToK(ParseReal(Arg[3],'la temperature'));
  CmdISA(AltToM(ParseReal(Arg[2],'l''altitude')),HasT,V);
 End
  Else
 If(Cmd='VITESSE')or(Cmd='SPEED')Then Begin
  ExigerParametres(4,5,'VITESSE type valeur alt [temp]');
  TypeStr:=StrToUpper(Arg[2]);
  If(TypeStr='IAS')or(TypeStr='CAS')Then Kind:=1 Else
  If TypeStr='EAS'Then Kind:=2 Else
  If TypeStr='TAS'Then Kind:=3 Else
  If TypeStr='MACH'Then Kind:=4
   Else Erreur('Type de vitesse inconnu : '+Arg[2]+
               ' (IAS, CAS, EAS, TAS ou MACH)');
  V:=ParseReal(Arg[3],'la vitesse');
  If Kind<4 Then V:=SpeedToMS(V);
  HasT:=NPos=5;
  If HasT Then
   CmdVitesse(Kind,V,AltToM(ParseReal(Arg[4],'l''altitude')),True,
              TempToK(ParseReal(Arg[5],'la temperature')))
  Else
   CmdVitesse(Kind,V,AltToM(ParseReal(Arg[4],'l''altitude')),False,0);
 End
  Else
 If(Cmd='TERRAIN')or(Cmd='FIELD')Then Begin
  ExigerParametres(3,4,'TERRAIN elev qnh [temp]');
  HasT:=NPos=4;
  V:=0;
  If HasT Then V:=TempToK(ParseReal(Arg[4],'la temperature'));
  CmdTerrain(AltToM(ParseReal(Arg[2],'l''altitude du terrain')),
             PressToPa(ParseReal(Arg[3],'le QNH')),HasT,V);
 End
  Else
 If Cmd='QNH'Then Begin
  ExigerParametres(3,3,'QNH elev qfe');
  CmdQNH(AltToM(ParseReal(Arg[2],'l''altitude du terrain')),
         PressToPa(ParseReal(Arg[3],'le QFE')));
 End
  Else
 If Cmd='QFE'Then Begin
  ExigerParametres(3,3,'QFE elev qnh');
  CmdQFE(AltToM(ParseReal(Arg[2],'l''altitude du terrain')),
         PressToPa(ParseReal(Arg[3],'le QNH')));
 End
  Else
 If(Cmd='ALTI')or(Cmd='ALTIMETRE')Then Begin
  ExigerParametres(3,3,'ALTI alt_pression calage');
  CmdAlti(AltToM(ParseReal(Arg[2],'l''altitude-pression')),
          PressToPa(ParseReal(Arg[3],'le calage')));
 End
  Else
 Erreur('Commande inconnue : '+Arg[1]+' (ISA, VITESSE, TERRAIN, QNH, QFE, ALTI)');
END.
