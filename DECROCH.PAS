{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program DECROCH;

{ Vitesse de decrochage et performances en virage d'un avion :
   - vitesse de decrochage a 1 g et sous facteur de charge ;
   - virage en palier : facteur de charge, rayon, taux de virage, temps
     d'un tour complet, vitesse de decrochage en virage ;
   - inclinaison necessaire pour un taux ou un rayon donne (virage standard) ;
   - vitesse de manoeuvre et inclinaison maximale. }

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

Type
 TAvion=Record
  Masse,Surface:Real;          { kg, m2 }
  CLmax,CL2:Real;              { coefficients de portance maximaux }
  Rho,Sigma:Real;              { densite de l'air (kg/m3), rapport a Rho0 }
  NLim:Real;                   { facteur de charge limite }
 End;

 TVirage=Record
  Vitesse:Real;                { vitesse vraie (m/s) }
  Incl:Real;                   { inclinaison (radians) }
  N:Real;                      { facteur de charge }
  Rayon:Real;                  { rayon du virage (m) }
  Taux:Real;                   { taux de virage (degres/s) }
  Tour:Real;                   { duree d'un tour complet (s) }
  Vsn:Real;                    { vitesse de decrochage en virage (m/s) }
  CLreq:Real;                  { coefficient de portance necessaire }
 End;

Var
 A:TAvion;
 V:TVirage;
 Option:Set of (_Livres,_Pieds2,_Metres,_Fahrenheit,_Table,_Std);
 Arg:Array[1..8]of String;
 NArg,I,ModeVit,ModeIncl:Integer;
 Param:String;
 Altitude,Temperature,VitesseSaisie,InclSaisie,TauxSaisie,RayonSaisie:Real;
 HasT,HasCL2:Boolean;
 TK,Hm:Real;

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

Function Puissance(X,Y:Real):Real;Begin
 Puissance:=Exp(Y*Ln(X));
End;

Function Tangente(X:Real):Real;Begin
 Tangente:=Sin(X)/Cos(X);
End;

Function ArcCosinus(X:Real):Real;Begin
 If X>=1.0 Then ArcCosinus:=0 Else
 If X<=-1.0 Then ArcCosinus:=PiVal
  Else ArcCosinus:=ArcTan(Sqrt(1.0-X*X)/X)+(1.0-Abs(X)/X)*PiVal/2.0;
End;

Function ArcTangente(X:Real):Real;Begin
 ArcTangente:=ArcTan(X);
End;

Function FmtVitesse(MS:Real):String;Begin
 FmtVitesse:=Fmt(MS/KtMS,0)+' kt ('+Fmt(MS/KmhMS,0)+' km/h, '+Fmt(MS,1)+' m/s)';
End;

{ Vitesse de decrochage (m/s, vitesse vraie) sous le facteur de charge N. }
Function VitesseDecrochage(Var Av:TAvion;CL,N:Real):Real;Begin
 VitesseDecrochage:=Sqrt(2.0*N*Av.Masse*G/(Av.Rho*Av.Surface*CL));
End;

{ Densite de l'air (troposphere ISA) a l'altitude-pression Hm (m), avec la
  temperature TK (K) si elle est donnee. }
Procedure CalculerDensite(Var Av:TAvion;Hm:Real;HasT:Boolean;TK:Real);
Var
 P,T:Real;
Begin
 If(Hm<-500.0)or(Hm>MaxH)Then
  Erreur('Altitude hors limites (de -1640 ft a 36089 ft)');
 T:=T0-0.0065*Hm;
 P:=P0*Puissance(T/T0,5.255876);
 If HasT Then T:=TK;
 If(T<200.0)or(T>340.0)Then Erreur('Temperature hors limites (-73 a 67 C)');
 Av.Rho:=P/(RGaz*T);
 Av.Sigma:=Av.Rho/Rho0;
End;

Procedure Verifier(Var Av:TAvion);Begin
 If Av.Masse<=0 Then Erreur('La masse doit etre positive');
 If Av.Surface<=0 Then Erreur('La surface alaire doit etre positive');
 If(Av.CLmax<=0)or(Av.CLmax>5.0)Then
  Erreur('Le coefficient de portance maximal doit etre entre 0 et 5');
 If HasCL2 and((Av.CL2<=0)or(Av.CL2>5.0))Then
  Erreur('Le second coefficient de portance maximal doit etre entre 0 et 5');
 If Av.NLim<1.0 Then Erreur('Le facteur de charge limite doit etre superieur ou egal a 1');
End;

{ Virage en palier a la vitesse vraie Vit et a l'inclinaison Incl. }
Procedure CalculerVirage(Var Av:TAvion;Var Vi:TVirage;Vit,Incl:Real);
Var
 Omega:Real;
Begin
 Vi.Vitesse:=Vit;
 Vi.Incl:=Incl;
 Vi.N:=1.0/Cos(Incl);
 Omega:=G*Tangente(Incl)/Vit;
 If Omega>0 Then Begin
  Vi.Rayon:=Vit/Omega;
  Vi.Taux:=Omega*180.0/PiVal;
  Vi.Tour:=360.0/Vi.Taux;
 End
  Else
 Begin
  Vi.Rayon:=0;
  Vi.Taux:=0;
  Vi.Tour:=0;
 End;
 Vi.Vsn:=VitesseDecrochage(Av,Av.CLmax,Vi.N);
 Vi.CLreq:=2.0*Vi.N*Av.Masse*G/(Av.Rho*Vit*Vit*Av.Surface);
End;

Procedure AfficherDecrochage(Var Av:TAvion);
Var
 Vs,Vs2,Va:Real;
 Ias:Real;
Begin
 Ias:=Sqrt(Av.Sigma);
 WriteLn('Vitesse de decrochage');
 WriteLn('---------------------');
 WriteLn('Masse                  : ',Fmt(Av.Masse,0),' kg (',
         Fmt(Av.Masse/LbKg,0),' lb)');
 WriteLn('Surface alaire         : ',Fmt(Av.Surface,1),' m2 (charge alaire ',
         Fmt(Av.Masse/Av.Surface,1),' kg/m2)');
 WriteLn('Densite de l''air       : ',Fmt(Av.Rho,4),' kg/m3 (sigma=',
         Fmt(Av.Sigma,4),')');
 WriteLn;
 Vs:=VitesseDecrochage(Av,Av.CLmax,1.0);
 WriteLn('Configuration principale (CL max ',Fmt(Av.CLmax,2),')');
 WriteLn(' Vs a 1 g, vitesse vraie   : ',FmtVitesse(Vs));
 WriteLn(' Vs a 1 g, IAS approchee   : ',FmtVitesse(Vs*Ias));
 If HasCL2 Then Begin
  Vs2:=VitesseDecrochage(Av,Av.CL2,1.0);
  WriteLn;
  WriteLn('Seconde configuration (CL max ',Fmt(Av.CL2,2),')');
  WriteLn(' Vs a 1 g, vitesse vraie   : ',FmtVitesse(Vs2));
  WriteLn(' Vs a 1 g, IAS approchee   : ',FmtVitesse(Vs2*Ias));
 End;
 Va:=Vs*Sqrt(Av.NLim);
 WriteLn;
 WriteLn('Facteur de charge limite ',Fmt(Av.NLim,1),' g :');
 WriteLn(' Vitesse de manoeuvre Va   : ',FmtVitesse(Va),' (IAS ',
         Fmt(Va*Ias/KtMS,0),' kt)');
 WriteLn(' Inclinaison maximale      : ',
         Fmt(ArcCosinus(1.0/Av.NLim)*180.0/PiVal,0),' degres en virage en palier');
End;

Function AfficherVirage(Var Av:TAvion;Var Vi:TVirage):Boolean;
Var
 Vs,Marge,NMax:Real;
 Ias:Real;
Begin
 Ias:=Sqrt(Av.Sigma);
 Vs:=VitesseDecrochage(Av,Av.CLmax,1.0);
 WriteLn;
 WriteLn('Virage en palier');
 WriteLn('----------------');
 WriteLn('Vitesse vraie           : ',FmtVitesse(Vi.Vitesse),' (IAS ',
         Fmt(Vi.Vitesse*Ias/KtMS,0),' kt)');
 WriteLn('Inclinaison             : ',Fmt(Vi.Incl*180.0/PiVal,1),' degres');
 WriteLn('Facteur de charge       : ',Fmt(Vi.N,2),' g');
 WriteLn('Rayon du virage         : ',Fmt(Vi.Rayon,0),' m (',
         Fmt(Vi.Rayon/FtM,0),' ft)');
 WriteLn('Taux de virage          : ',Fmt(Vi.Taux,2),' degres/s');
 WriteLn('Duree d''un demi-tour    : ',Fmt(Vi.Tour/2.0,1),' s');
 WriteLn('Duree d''un tour complet : ',Fmt(Vi.Tour,1),' s');
 WriteLn('Vs en virage            : ',FmtVitesse(Vi.Vsn),' (IAS ',
         Fmt(Vi.Vsn*Ias/KtMS,0),' kt)');
 WriteLn('CL necessaire           : ',Fmt(Vi.CLreq,2),' (CL max ',
         Fmt(Av.CLmax,2),')');
 Marge:=Vi.Vitesse/Vi.Vsn;
 WriteLn('Marge au decrochage     : ',Fmt((Marge-1.0)*100.0,0),' % (V = ',
         Fmt(Marge,2),' x Vs en virage)');
 NMax:=Sqr(Vi.Vitesse/Vs);
 If NMax>=1.0 Then Begin
  WriteLn('Inclinaison maximale    : ',
          Fmt(ArcCosinus(1.0/NMax)*180.0/PiVal,0),
          ' degres avant le decrochage a cette vitesse');
 End;
 If Vi.N>Av.NLim Then
  WriteLn('ATTENTION : le facteur de charge depasse la limite de ',
          Fmt(Av.NLim,1),' g.');
 AfficherVirage:=Vi.Vitesse>=Vi.Vsn;
 If Vi.Vitesse<Vi.Vsn Then
  WriteLn('DECROCHAGE : la vitesse est inferieure a la vitesse de decrochage ',
          'en virage.');
End;

Procedure AfficherTableau(Var Av:TAvion;Vit:Real);
Var
 K:Integer;
 Vi:TVirage;
 Ias:Real;
Begin
 Ias:=Sqrt(Av.Sigma);
 WriteLn;
 WriteLn('Tableau pour la vitesse vraie de ',FmtVitesse(Vit));
 WriteLn;
 WriteLn('Inclinaison':12,'n (g)':8,'Vs virage':14,'Rayon (m)':12,
         'Taux (/s)':12,'Tour (s)':10);
 WriteLn('(degres)':12,'':8,'(IAS kt)':14,'':12,'(degres)':12,'':10);
 For K:=0 to 7 do Begin
  If K<7 Then CalculerVirage(Av,Vi,Vit,K*10.0*PiVal/180.0)
   Else CalculerVirage(Av,Vi,Vit,75.0*PiVal/180.0);
  Write(Fmt(Vi.Incl*180.0/PiVal,0):12,Fmt(Vi.N,2):8,
        Fmt(Vi.Vsn*Ias/KtMS,0):14);
  If Vi.Rayon>0 Then WriteLn(Fmt(Vi.Rayon,0):12,Fmt(Vi.Taux,2):12,
                             Fmt(Vi.Tour,0):10)
                Else WriteLn('-':12,'0':12,'-':10);
 End;
End;

Procedure AfficherAide;Begin
 WriteLn('DECROCH : Cette commande permet de calculer la vitesse de ',
         'decrochage et les performances');
 WriteLn('          en virage d''un avion.');
 WriteLn;
 WriteLn('Syntaxe : DECROCH masse surface clmax altitude [temp] [options]');
 WriteLn;
 WriteLn(' masse      Masse de l''avion (kg)');
 WriteLn(' surface    Surface alaire (m2)');
 WriteLn(' clmax      Coefficient de portance maximal de la configuration');
 WriteLn(' altitude   Altitude-pression (pieds)');
 WriteLn(' temp       Temperature de l''air (Celsius, ISA par defaut)');
 WriteLn;
 WriteLn('Options :');
 WriteLn(' /LB /FT2 /M /F   Masse en livres, surface en pieds carres, altitude en');
 WriteLn('                  metres, temperature en Fahrenheit');
 WriteLn(' /CL2:x           Seconde configuration (par exemple volets sortis)');
 WriteLn(' /NLIM:x          Facteur de charge limite (3,8 g par defaut)');
 WriteLn(' /IAS:kt          Vitesse indiquee du virage en noeuds');
 WriteLn(' /TAS:kt          Vitesse vraie du virage en noeuds');
 WriteLn('                  (par defaut 1,3 fois la vitesse de decrochage)');
 WriteLn(' /INCL:deg        Inclinaison du virage (30 degres par defaut)');
 WriteLn(' /TAUX:deg/s      Inclinaison calculee pour un taux de virage donne');
 WriteLn(' /STD             Virage standard, taux de 3 degres par seconde');
 WriteLn(' /RAYON:m         Inclinaison calculee pour un rayon de virage donne');
 WriteLn(' /T               Tableau pour des inclinaisons de 0 a 75 degres');
 WriteLn;
 WriteLn('Code de sortie : 0 = Ok, 1 = erreur, 2 = decrochage en virage');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn(' DECROCH 1043 16.2 2.1 0');
 WriteLn(' DECROCH 1043 16.2 1.5 0 /CL2:2.1 /IAS:90 /STD');
 WriteLn(' DECROCH 1043 16.2 2.1 5000 25 /INCL:45 /T');
 WriteLn(' DECROCH 60000 122 2.6 0 /TAS:250 /RAYON:3000');
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
 If Nom='/T'Then Option:=Option+[_Table] Else
 If Nom='/CL2'Then Begin
  A.CL2:=ParseReal(Valeur,'le second CL max');
  HasCL2:=True;
 End
  Else
 If Nom='/NLIM'Then A.NLim:=ParseReal(Valeur,'le facteur de charge limite') Else
 If Nom='/IAS'Then Begin
  VitesseSaisie:=ParseReal(Valeur,'la vitesse');
  ModeVit:=1;
 End
  Else
 If Nom='/TAS'Then Begin
  VitesseSaisie:=ParseReal(Valeur,'la vitesse');
  ModeVit:=2;
 End
  Else
 If Nom='/INCL'Then Begin
  InclSaisie:=ParseReal(Valeur,'l''inclinaison');
  If ModeIncl<>0 Then Erreur('Une seule de /INCL, /TAUX, /STD et /RAYON est permise');
  ModeIncl:=1;
 End
  Else
 If Nom='/TAUX'Then Begin
  TauxSaisie:=ParseReal(Valeur,'le taux de virage');
  If ModeIncl<>0 Then Erreur('Une seule de /INCL, /TAUX, /STD et /RAYON est permise');
  ModeIncl:=2;
 End
  Else
 If Nom='/STD'Then Begin
  TauxSaisie:=3.0;
  If ModeIncl<>0 Then Erreur('Une seule de /INCL, /TAUX, /STD et /RAYON est permise');
  ModeIncl:=2;
 End
  Else
 If Nom='/RAYON'Then Begin
  RayonSaisie:=ParseReal(Valeur,'le rayon');
  If ModeIncl<>0 Then Erreur('Une seule de /INCL, /TAUX, /STD et /RAYON est permise');
  ModeIncl:=3;
 End
  Else Erreur('Option inconnue : '+Param);
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
 WriteLn('Vitesse de decrochage et virage');
 WriteLn('-------------------------------');
 A.Masse:=LireValeur('Masse (kg) : ');
 A.Surface:=LireValeur('Surface alaire (m2) : ');
 A.CLmax:=LireValeur('CL max de la configuration : ');
 Altitude:=LireValeur('Altitude-pression (ft) : ');
 Write('Temperature en Celsius (vide = ISA) : ');
 ReadLn(S);
 If Trim(S)<>''Then Begin
  Temperature:=ParseReal(S,'la temperature');
  HasT:=True;
 End;
 Write('Vitesse indiquee du virage en noeuds (vide = 1,3 Vs) : ');
 ReadLn(S);
 If Trim(S)<>''Then Begin
  VitesseSaisie:=ParseReal(S,'la vitesse');
  ModeVit:=1;
 End;
 Write('Inclinaison en degres (vide = 30) : ');
 ReadLn(S);
 If Trim(S)<>''Then Begin
  InclSaisie:=ParseReal(S,'l''inclinaison');
  ModeIncl:=1;
 End;
 WriteLn;
End;

Var
 Vit,Incl,Vs:Real;
 Ok:Boolean;

BEGIN
 Option:=[];
 A.CL2:=0;
 A.NLim:=3.8;
 HasCL2:=False;
 HasT:=False;
 Temperature:=0;
 Altitude:=0;
 VitesseSaisie:=0;
 InclSaisie:=30.0;
 TauxSaisie:=0;
 RayonSaisie:=0;
 ModeVit:=0;
 ModeIncl:=0;
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
  If NArg<4 Then Erreur('Syntaxe : DECROCH masse surface clmax altitude [temp] [options]');
  A.Masse:=ParseReal(Arg[1],'la masse');
  A.Surface:=ParseReal(Arg[2],'la surface alaire');
  A.CLmax:=ParseReal(Arg[3],'le coefficient de portance maximal');
  Altitude:=ParseReal(Arg[4],'l''altitude');
  If NArg=5 Then Begin
   Temperature:=ParseReal(Arg[5],'la temperature');
   HasT:=True;
  End;
 End;
 If _Livres in Option Then A.Masse:=A.Masse*LbKg;
 If _Pieds2 in Option Then A.Surface:=A.Surface*Ft2M2;
 If _Metres in Option Then Hm:=Altitude Else Hm:=Altitude*FtM;
 TK:=0;
 If HasT Then Begin
  If _Fahrenheit in Option Then TK:=(Temperature-32.0)*5.0/9.0+273.15
                           Else TK:=Temperature+273.15;
 End;
 Verifier(A);
 CalculerDensite(A,Hm,HasT,TK);
 AfficherDecrochage(A);
 { Vitesse vraie du virage }
 Vs:=VitesseDecrochage(A,A.CLmax,1.0);
 Case ModeVit of
  1:Vit:=VitesseSaisie*KtMS/Sqrt(A.Sigma);
  2:Vit:=VitesseSaisie*KtMS;
  Else Vit:=1.3*Vs;
 End;
 If Vit<=0 Then Erreur('La vitesse du virage doit etre positive');
 { Inclinaison du virage }
 Case ModeIncl of
  2:Begin
   If TauxSaisie<=0 Then Erreur('Le taux de virage doit etre positif');
   Incl:=ArcTangente(Vit*TauxSaisie*PiVal/180.0/G);
  End;
  3:Begin
   If RayonSaisie<=0 Then Erreur('Le rayon doit etre positif');
   Incl:=ArcTangente(Vit*Vit/(G*RayonSaisie));
  End;
  Else Incl:=InclSaisie*PiVal/180.0;
 End;
 If(Incl<0)or(Incl>85.0*PiVal/180.0)Then
  Erreur('L''inclinaison doit etre entre 0 et 85 degres');
 CalculerVirage(A,V,Vit,Incl);
 Ok:=AfficherVirage(A,V);
 If _Table in Option Then AfficherTableau(A,Vit);
 If Not Ok Then Halt(2);
END.
