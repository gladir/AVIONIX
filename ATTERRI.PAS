{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program ATTERRI;

{ Estimation de la distance d'atterrissage d'un avion :
   - phase aerienne : approche a pente constante, des l'obstacle de 15 m
     (50 ft) jusqu'a l'arrondi et au toucher des roues ;
   - temps de reaction (inversion, freins) pendant lequel l'avion roule
     sans decelerer ;
   - roulage freine, integre numeriquement de la vitesse sol au
     toucher des roues jusqu'a l'arret (freins, trainee, portance
     residuelle, pente de piste, vent et inverseurs) ;
   - distance requise avec marge de securite et piste mouillee. }

Const
 T0=288.15;            { Temperature ISA au niveau de la mer (K) }
 P0=101325.0;          { Pression ISA au niveau de la mer (Pa) }
 G=9.80665;            { Gravite normale (m/s2) }
 RGaz=287.05287;       { Constante specifique de l'air (J/kg/K) }
 Rho0=1.225;           { Densite ISA au niveau de la mer (kg/m3) }
 FtM=0.3048;           { Metres par pied }
 KtMS=0.514444;        { Metres par seconde par noeud }
 KmhMS=0.277778;       { Metres par seconde par km/h }
 LbKg=0.45359237;      { Kilogrammes par livre }
 Ft2M2=0.09290304;     { Metres carres par pied carre }
 PiVal=3.14159265358979;
 MaxH=11000.0;         { Limite de la formule de troposphere (m) }
 NbPas=500;            { Nombre de pas de l'integration du freinage }

Type
 TCond=Record
  Masse,Surface,CLmax:Real;    { kg, m2, coefficient de portance maximal }
  Rho,Sigma:Real;              { densite de l'air (kg/m3), rapport a Rho0 }
  Vent:Real;                   { vent de face (m/s), negatif = arriere }
  Pente:Real;                  { pente de piste, positive = montante }
  Mu:Real;                     { coefficient de freinage }
  CLg,CDg:Real;                { portance et trainee en roulage }
  Inv:Real;                    { poussee inverse / poids }
  Delai:Real;                  { temps avant freinage (s) }
  Obst:Real;                   { hauteur de l'obstacle (m) }
  Angle:Real;                  { pente d'approche (degres) }
  Marge:Real;                  { coefficient de marge de securite }
 End;

 TResultat=Record
  Vs,Vapp,Vflare,Vtd,Vsol:Real;  { vitesses vraies (m/s) }
  Rayon,Hflare:Real;             { rayon et hauteur de l'arrondi }
  Aerienne,Delai,Freinage:Real;  { distances des trois phases (m) }
  Total,Requise,Mouillee:Real;   { distances (m) }
  Decel0:Real;                   { deceleration au toucher des roues }
 End;

Var
 C:TCond;
 R:TResultat;
 Option:Set of (_Livres,_Pieds2,_Metres,_Fahrenheit);
 Arg:Array[1..8]of String;
 NArg,I:Integer;
 Param:String;
 Altitude,Temperature,QNH,Piste:Real;
 HasT,HasQNH,HasPiste,HasMu:Boolean;
 MuForce:Real;
 Surface:String;

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
 V:Real;
 Code,I:Integer;
Begin
 T:=Trim(S);
 For I:=1 to Length(T)do If T[I]=','Then T[I]:='.';
 Val(T,V,Code);
 If(Code<>0)or(T='')Then Erreur('Valeur invalide pour '+Nom+' : '+S);
 ParseReal:=V;
End;

Function Puissance(X,Y:Real):Real;Begin
 Puissance:=Exp(Y*Ln(X));
End;

Function FmtVitesse(MS:Real):String;Begin
 FmtVitesse:=Fmt(MS/KtMS,0)+' kt ('+Fmt(MS/KmhMS,0)+' km/h, '+Fmt(MS,1)+' m/s)';
End;

Function FmtDistance(M:Real):String;Begin
 FmtDistance:=Fmt(M,0)+' m ('+Fmt(M/FtM,0)+' ft)';
End;

{ Densite de l'air (troposphere) : la pression vient de l'altitude-pression
  ISA, ou du QNH et de l'altitude du terrain ; la temperature vient de
  l'ISA ou de la valeur donnee (K, negatif si non donnee). }
Procedure CalculerDensite(Var Cd:TCond;Hm:Real;HasQNH:Boolean;QNHpa:Real;
                          HasT:Boolean;TK:Real);
Var
 Ratio,P,T:Real;
Begin
 If(Hm<-500.0)or(Hm>MaxH)Then
  Erreur('Altitude hors limites (de -1640 ft a 36089 ft)');
 T:=T0-0.0065*Hm;
 Ratio:=Puissance(T/T0,5.255876);
 If HasQNH Then P:=QNHpa*Ratio Else P:=P0*Ratio;
 If HasT Then T:=TK;
 If(T<200.0)or(T>340.0)Then Erreur('Temperature hors limites (-73 a 67 C)');
 Cd.Rho:=P/(RGaz*T);
 Cd.Sigma:=Cd.Rho/Rho0;
End;

Procedure ValeursParDefaut(Var Cd:TCond);Begin
 Cd.Vent:=0;
 Cd.Pente:=0;
 Cd.Mu:=0.40;
 Cd.CLg:=0.10;
 Cd.CDg:=0.10;
 Cd.Inv:=0;
 Cd.Delai:=2.0;
 Cd.Obst:=15.24;
 Cd.Angle:=3.0;
 Cd.Marge:=1.0/0.6;
End;

Procedure Verifier(Var Cd:TCond);Begin
 If Cd.Masse<=0 Then Erreur('La masse doit etre positive');
 If Cd.Surface<=0 Then Erreur('La surface alaire doit etre positive');
 If(Cd.CLmax<=0)or(Cd.CLmax>5.0)Then
  Erreur('Le coefficient de portance maximal doit etre entre 0 et 5');
 If(Cd.Mu<0.01)or(Cd.Mu>1.0)Then
  Erreur('Le coefficient de freinage doit etre entre 0,01 et 1');
 If(Cd.Angle<=0)or(Cd.Angle>10.0)Then
  Erreur('La pente d''approche doit etre entre 0 et 10 degres');
 If Cd.Obst<0 Then Erreur('La hauteur de l''obstacle doit etre positive');
 If Cd.Delai<0 Then Erreur('Le delai doit etre positif');
 If Cd.Marge<1.0 Then Erreur('La marge doit etre superieure ou egale a 1');
 If(Cd.Pente<-0.2)or(Cd.Pente>0.2)Then
  Erreur('La pente de piste doit etre entre -20 et 20 %');
End;

Procedure CalculerAtterrissage(Var Cd:TCond;Var Rs:TResultat);
Var
 Gam,Ha,Sa,Sf,Q,A,Dv,V,S,Va:Real;
 K:Integer;
Begin
 Rs.Vs:=Sqrt(2.0*Cd.Masse*G/(Cd.Rho*Cd.Surface*Cd.CLmax));
 Rs.Vapp:=1.3*Rs.Vs;
 Rs.Vflare:=1.23*Rs.Vs;
 Rs.Vtd:=1.15*Rs.Vs;
 { Phase aerienne : arrondi de rayon V2/(0.2 g), puis pente constante }
 Gam:=Cd.Angle*PiVal/180.0;
 Rs.Rayon:=Rs.Vflare*Rs.Vflare/(0.2*G);
 Rs.Hflare:=Rs.Rayon*(1.0-Cos(Gam));
 If Cd.Obst>Rs.Hflare Then Ha:=Cd.Obst-Rs.Hflare Else Ha:=0;
 Sa:=Ha/Sin(Gam)*Cos(Gam);
 Sf:=Rs.Rayon*Sin(Gam);
 If Cd.Obst<Rs.Hflare Then Sf:=Sf*Cd.Obst/Rs.Hflare;
 Rs.Aerienne:=Sa+Sf;
 { Vitesse sol au toucher des roues }
 Rs.Vsol:=Rs.Vtd-Cd.Vent;
 If Rs.Vsol<0 Then Rs.Vsol:=0;
 Rs.Delai:=Rs.Vsol*Cd.Delai;
 { Roulage freine : integration de V dV / a(V) de Vsol a zero }
 Dv:=Rs.Vsol/NbPas;
 S:=0;
 Rs.Decel0:=0;
 For K:=1 to NbPas do Begin
  V:=(K-0.5)*Dv;
  Va:=V+Cd.Vent;
  Q:=0.5*Cd.Rho*Va*Va;
  A:=G*(Cd.Mu+Cd.Pente+Cd.Inv)+
     Q*Cd.Surface*(Cd.CDg-Cd.Mu*Cd.CLg)/Cd.Masse;
  If A<0.05 Then A:=0.05;
  S:=S+V*Dv/A;
  If K=NbPas Then Rs.Decel0:=A;
 End;
 Rs.Freinage:=S;
 Rs.Total:=Rs.Aerienne+Rs.Delai+Rs.Freinage;
 Rs.Requise:=Rs.Total*Cd.Marge;
 Rs.Mouillee:=Rs.Requise*1.15;
End;

Procedure AfficherResultats(Var Cd:TCond;Var Rs:TResultat;Surf:String;
                            HasPiste:Boolean;PisteM:Real);
Var
 Ias:Real;
Begin
 WriteLn('Distance d''atterrissage');
 WriteLn('-----------------------');
 WriteLn('Masse                 : ',Fmt(Cd.Masse,0),' kg (',
         Fmt(Cd.Masse/LbKg,0),' lb)');
 WriteLn('Surface alaire        : ',Fmt(Cd.Surface,1),' m2 (charge alaire ',
         Fmt(Cd.Masse/Cd.Surface,1),' kg/m2)');
 WriteLn('CL max (atterrissage) : ',Fmt(Cd.CLmax,2));
 WriteLn('Densite de l''air      : ',Fmt(Cd.Rho,4),' kg/m3 (sigma=',
         Fmt(Cd.Sigma,4),')');
 WriteLn('Piste                 : ',Surf,' (mu=',Fmt(Cd.Mu,2),'), pente ',
         Fmt(Cd.Pente*100.0,1),' %');
 If Cd.Vent>=0 Then WriteLn('Vent                  : ',Fmt(Cd.Vent/KtMS,0),
                            ' kt de face')
               Else WriteLn('Vent                  : ',Fmt(-Cd.Vent/KtMS,0),
                            ' kt arriere');
 WriteLn;
 WriteLn('Vitesses (vitesses vraies, IAS approchee entre parentheses)');
 Ias:=Sqrt(Cd.Sigma);
 WriteLn(' Decrochage Vs      : ',FmtVitesse(Rs.Vs),' (IAS ',
         Fmt(Rs.Vs*Ias/KtMS,0),' kt)');
 WriteLn(' Approche 1,30 Vs   : ',FmtVitesse(Rs.Vapp),' (IAS ',
         Fmt(Rs.Vapp*Ias/KtMS,0),' kt)');
 WriteLn(' Arrondi 1,23 Vs    : ',FmtVitesse(Rs.Vflare));
 WriteLn(' Toucher 1,15 Vs    : ',FmtVitesse(Rs.Vtd),' (IAS ',
         Fmt(Rs.Vtd*Ias/KtMS,0),' kt)');
 WriteLn(' Vitesse sol toucher: ',FmtVitesse(Rs.Vsol));
 If Rs.Vsol<=0 Then WriteLn(' Attention : le vent de face depasse la vitesse de toucher des roues.');
 WriteLn;
 WriteLn('Distances');
 WriteLn(' ',Pad('Phase aerienne (obstacle '+Fmt(Cd.Obst,1)+' m, pente '+
         Fmt(Cd.Angle,1)+' deg)',46),': ',FmtDistance(Rs.Aerienne));
 WriteLn(' ',Pad('Roulage libre ('+Fmt(Cd.Delai,1)+' s)',46),': ',
         FmtDistance(Rs.Delai));
 WriteLn(' ',Pad('Roulage freine',46),': ',FmtDistance(Rs.Freinage));
 WriteLn(' ',Pad('Distance d''atterrissage (depuis l''obstacle)',46),': ',
         FmtDistance(Rs.Total));
 WriteLn(' ',Pad('Distance au sol (toucher a l''arret)',46),': ',
         FmtDistance(Rs.Delai+Rs.Freinage));
 WriteLn;
 WriteLn(' ',Pad('Distance requise (x'+Fmt(Cd.Marge,2)+')',46),': ',
         FmtDistance(Rs.Requise));
 WriteLn(' ',Pad('Distance requise piste mouillee (x'+Fmt(Cd.Marge*1.15,2)+')',46),
         ': ',FmtDistance(Rs.Mouillee));
 If HasPiste Then Begin
  WriteLn;
  WriteLn('Longueur de piste disponible : ',FmtDistance(PisteM));
  If Rs.Requise<=PisteM Then
   WriteLn('Atterrissage possible, marge de ',Fmt(PisteM-Rs.Requise,0),' m (',
           Fmt((PisteM-Rs.Requise)/FtM,0),' ft)')
  Else Begin
   WriteLn('PISTE TROP COURTE : il manque ',Fmt(Rs.Requise-PisteM,0),' m (',
           Fmt((Rs.Requise-PisteM)/FtM,0),' ft)');
   If Rs.Total<=PisteM Then
    WriteLn('(la distance reelle de ',Fmt(Rs.Total,0),
            ' m tient sans la marge de securite)');
   Halt(2);
  End;
 End;
End;

Procedure AfficherAide;Begin
 WriteLn('ATTERRI : Cette commande permet de calculer la distance d''atterrissage ',
         'd''un avion.');
 WriteLn;
 WriteLn('Syntaxe : ATTERRI masse surface clmax altitude [temp] [options]');
 WriteLn;
 WriteLn(' masse      Masse a l''atterrissage (kg)');
 WriteLn(' surface    Surface alaire (m2)');
 WriteLn(' clmax      Coefficient de portance maximal en configuration d''atterrissage');
 WriteLn(' altitude   Altitude-pression de la piste (pieds)');
 WriteLn(' temp       Temperature de l''air (Celsius, ISA par defaut)');
 WriteLn;
 WriteLn('Options :');
 WriteLn(' /LB /FT2 /M /F   Masse en livres, surface en pieds carres, altitude en');
 WriteLn('                  metres, temperature en Fahrenheit');
 WriteLn(' /QNH:hPa         L''altitude est celle du terrain et la pression est donnee');
 WriteLn('                  par le QNH');
 WriteLn(' /VENT:kt         Vent de face en noeuds (negatif = vent arriere)');
 WriteLn(' /PENTE:%         Pente de piste (positive = montante)');
 WriteLn(' /SEC /MOUILLE /NEIGE /GLACE /HERBE   Etat de la piste (/SEC par defaut)');
 WriteLn(' /MU:x            Coefficient de freinage (remplace l''etat de la piste)');
 WriteLn(' /CLG:x /CDG:x    Portance et trainee pendant le roulage (0,10 et 0,10)');
 WriteLn(' /INV:x           Poussee inverse en fraction du poids (0 par defaut)');
 WriteLn(' /DELAI:s         Temps avant le freinage (2 s par defaut)');
 WriteLn(' /OBST:m          Hauteur de l''obstacle (15,24 m = 50 ft par defaut)');
 WriteLn(' /ANGLE:deg       Pente d''approche (3 degres par defaut)');
 WriteLn(' /MARGE:x         Coefficient de marge de securite (1,67 par defaut)');
 WriteLn(' /PISTE:m         Compare a une piste de cette longueur (metres)');
 WriteLn(' /PISTEFT:ft      Idem, longueur en pieds');
 WriteLn;
 WriteLn('Code de sortie : 0 = Ok, 1 = erreur, 2 = piste trop courte');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn(' ATTERRI 1043 16.2 2.1 0');
 WriteLn(' ATTERRI 1043 16.2 2.1 5000 30 /VENT:10 /MOUILLE');
 WriteLn(' ATTERRI 60000 122 2.6 0 /INV:0.1 /PISTE:2500 /CDG:0.15');
End;

Procedure ChoisirSurface(Name:String;Var Mu:Real;Var Libelle:String);Begin
 If Name='SEC'Then Begin Mu:=0.40;Libelle:='seche'End Else
 If Name='MOUILLE'Then Begin Mu:=0.20;Libelle:='mouillee'End Else
 If Name='NEIGE'Then Begin Mu:=0.12;Libelle:='neige'End Else
 If Name='GLACE'Then Begin Mu:=0.05;Libelle:='glacee'End Else
 If Name='HERBE'Then Begin Mu:=0.30;Libelle:='herbe seche'End;
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
 If Nom='/FT2'Then Option:=Option+[_Pieds2] Else
 If Nom='/M'Then Option:=Option+[_Metres] Else
 If Nom='/F'Then Option:=Option+[_Fahrenheit] Else
 If(Nom='/SEC')or(Nom='/MOUILLE')or(Nom='/NEIGE')or(Nom='/GLACE')or
   (Nom='/HERBE')Then Begin
  If Not HasMu Then ChoisirSurface(Copy(Nom,2,20),C.Mu,Surface);
 End
  Else
 If Nom='/QNH'Then Begin
  QNH:=ParseReal(Valeur,'le QNH')*100.0;
  If(QNH<80000.0)or(QNH>110000.0)Then Erreur('Le QNH est hors limites (800 a 1100 hPa)');
  HasQNH:=True;
 End
  Else
 If Nom='/VENT'Then C.Vent:=ParseReal(Valeur,'le vent')*KtMS Else
 If Nom='/PENTE'Then C.Pente:=ParseReal(Valeur,'la pente')/100.0 Else
 If Nom='/MU'Then Begin
  C.Mu:=ParseReal(Valeur,'mu');
  Surface:='personnalisee';
  HasMu:=True;
 End
  Else
 If Nom='/CLG'Then C.CLg:=ParseReal(Valeur,'CLg') Else
 If Nom='/CDG'Then C.CDg:=ParseReal(Valeur,'CDg') Else
 If Nom='/INV'Then C.Inv:=ParseReal(Valeur,'la poussee inverse') Else
 If Nom='/DELAI'Then C.Delai:=ParseReal(Valeur,'le delai') Else
 If Nom='/OBST'Then C.Obst:=ParseReal(Valeur,'l''obstacle') Else
 If Nom='/ANGLE'Then C.Angle:=ParseReal(Valeur,'l''angle') Else
 If Nom='/MARGE'Then C.Marge:=ParseReal(Valeur,'la marge') Else
 If Nom='/PISTE'Then Begin
  Piste:=ParseReal(Valeur,'la longueur de piste');
  HasPiste:=True;
 End
  Else
 If Nom='/PISTEFT'Then Begin
  Piste:=ParseReal(Valeur,'la longueur de piste')*FtM;
  HasPiste:=True;
 End
  Else
 Erreur('Option inconnue : '+Param);
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
 S:String;
Begin
 WriteLn('Calcul de la distance d''atterrissage');
 WriteLn('-------------------------------------');
 C.Masse:=LireValeur('Masse a l''atterrissage (kg) : ');
 C.Surface:=LireValeur('Surface alaire (m2) : ');
 C.CLmax:=LireValeur('CL max en configuration d''atterrissage : ');
 Altitude:=LireValeur('Altitude-pression de la piste (ft) : ');
 Write('Temperature en Celsius (vide = ISA) : ');
 ReadLn(S);
 If Trim(S)<>''Then Begin
  Temperature:=ParseReal(S,'la temperature');
  HasT:=True;
 End;
 Write('Vent de face en noeuds (vide = 0) : ');
 ReadLn(S);
 If Trim(S)<>''Then C.Vent:=ParseReal(S,'le vent')*KtMS;
 Write('Etat de la piste (SEC, MOUILLE, NEIGE, GLACE ou HERBE ; vide = SEC) : ');
 ReadLn(S);
 S:=StrToUpper(Trim(S));
 If S<>''Then Begin
  If(S<>'SEC')and(S<>'MOUILLE')and(S<>'NEIGE')and(S<>'GLACE')and
    (S<>'HERBE')Then Erreur('Etat de piste inconnu');
  ChoisirSurface(S,C.Mu,Surface);
 End;
 Write('Longueur de piste en metres (vide = aucune) : ');
 ReadLn(S);
 If Trim(S)<>''Then Begin
  Piste:=ParseReal(S,'la longueur de piste');
  HasPiste:=True;
 End;
 WriteLn;
End;

Var
 TK,Hm:Real;

BEGIN
 Option:=[];
 ValeursParDefaut(C);
 Surface:='seche';
 HasT:=False;
 HasQNH:=False;
 HasPiste:=False;
 HasMu:=False;
 Temperature:=0;
 QNH:=0;
 Piste:=0;
 NArg:=0;
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
   If NArg>=5 Then Erreur('Trop de parametres');
   Inc(NArg);
   Arg[NArg]:=Param;
  End;
 End;
 If NArg=0 Then Interactif
  Else
 Begin
  If(NArg<4)Then Erreur('Syntaxe : ATTERRI masse surface clmax altitude [temp] [options]');
  C.Masse:=ParseReal(Arg[1],'la masse');
  C.Surface:=ParseReal(Arg[2],'la surface alaire');
  C.CLmax:=ParseReal(Arg[3],'le coefficient de portance maximal');
  Altitude:=ParseReal(Arg[4],'l''altitude');
  If NArg=5 Then Begin
   Temperature:=ParseReal(Arg[5],'la temperature');
   HasT:=True;
  End;
 End;
 If _Livres in Option Then C.Masse:=C.Masse*LbKg;
 If _Pieds2 in Option Then C.Surface:=C.Surface*Ft2M2;
 If _Metres in Option Then Hm:=Altitude Else Hm:=Altitude*FtM;
 TK:=0;
 If HasT Then Begin
  If _Fahrenheit in Option Then TK:=(Temperature-32.0)*5.0/9.0+273.15
                           Else TK:=Temperature+273.15;
 End;
 Verifier(C);
 CalculerDensite(C,Hm,HasQNH,QNH,HasT,TK);
 CalculerAtterrissage(C,R);
 AfficherResultats(C,R,Surface,HasPiste,Piste);
END.
