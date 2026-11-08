{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program MONTEE;

{ Performances de montee d'un avion :
   - taux de montee maximal (Vy) et pente de montee maximale (Vx) a une
     altitude donnee, a partir de la puissance ou de la poussee disponible
     et de la trainee (polaire parabolique) ;
   - plafonds : absolu, pratique (taux de montee de 100 ou 500 ft/min) et
     de croisiere (300 ft/min) ;
   - tableau en fonction de l'altitude et temps de montee jusqu'a une
     altitude donnee. }

Const
 G=9.80665;            { Gravite normale (m/s2) }
 RGaz=287.05287;       { Constante specifique de l'air (J/kg/K) }
 Gamma=1.4;            { Rapport des chaleurs specifiques de l'air }
 T0=288.15;            { Temperature ISA au niveau de la mer (K) }
 P0=101325.0;          { Pression ISA au niveau de la mer (Pa) }
 Rho0=1.225;           { Densite ISA au niveau de la mer (kg/m3) }
 FtM=0.3048;           { Metres par pied }
 KtMS=0.514444;        { Metres par seconde par noeud }
 KmhMS=0.277778;       { Metres par seconde par km/h }
 LbKg=0.45359237;      { Kilogrammes par livre }
 Ft2M2=0.09290304;     { Metres carres par pied carre }
 HpKw=0.745700;        { Kilowatts par cheval-vapeur }
 LbfN=4.448222;        { Newtons par livre-force }
 PiVal=3.14159265358979;
 HMax=25000.0;         { Altitude maximale etudiee (m) }

Type
 TAvion=Record
  Helice:Boolean;
  Masse,Surface:Real;          { kg, m2 }
  Cd0,K:Real;                  { trainee parasite, facteur de trainee induite }
  CLmax:Real;                  { portance maximale (vitesse minimale) }
  Puissance,Rendement:Real;    { helice : puissance a l'arbre (W), rendement }
  Poussee:Real;                { reacteur : poussee au niveau de la mer (N) }
  Lapse:Real;                  { exposant de la perte avec la densite }
  HasLapse:Boolean;
  DeltaT:Real;                 { ecart de temperature a l'ISA (K) }
  VmaxKt:Real;                 { vitesse indiquee maximale de montee (kt), 0 = selon le type }
  MachMax:Real;                { nombre de Mach maximal de montee }
 End;

 TAtm=Record
  T,Rho,Sigma,A:Real;
 End;

 TMontee=Record
  Ok:Boolean;                  { montee possible }
  Rc,Vy,GammaVy:Real;          { taux max (m/s), vitesse (m/s), pente (rad) }
  Gradient,Vx:Real;            { pente max (rad), vitesse correspondante (m/s) }
  RcVx:Real;                   { taux de montee a Vx (m/s) }
  Borne:Integer;               { 1 = limite par la vitesse minimale, 2 = par la vitesse maximale }
 End;

Var
 Av:TAvion;
 Option:Set of (_Livres,_Pieds2,_Metres,_Hp,_Lbf,_Newton,_Table);
 Arg:Array[1..8]of String;
 NArg,I:Integer;
 Param:String;
 Altitude,HauteurCible,ServiceFpm:Real;
 HasHaut,HasService:Boolean;

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

Function Puissance(X,Y:Real):Real;Begin
 Puissance:=Exp(Y*Ln(X));
End;

{ ---------------------------------------------------------------------
  Atmosphere (ISA jusqu'a 25 km, avec ecart de temperature)
  --------------------------------------------------------------------- }

Procedure Atmosphere(H,DeltaT:Real;Var A:TAtm);
Var
 Tstd,P:Real;
Begin
 If H<=11000.0 Then Begin
  Tstd:=T0-0.0065*H;
  P:=P0*Puissance(Tstd/T0,5.255876);
 End
  Else
 Begin
  Tstd:=216.65;
  P:=22632.06*Exp(-G*(H-11000.0)/(RGaz*216.65));
 End;
 A.T:=Tstd+DeltaT;
 A.Rho:=P/(RGaz*A.T);
 A.Sigma:=A.Rho/Rho0;
 A.A:=Sqrt(Gamma*RGaz*A.T);
End;

{ ---------------------------------------------------------------------
  Puissance, poussee et trainee
  --------------------------------------------------------------------- }

{ Puissance utile de l'helice (W) ou poussee du reacteur (N) a la densite A
  et a la vitesse V (le reacteur perd de la poussee quand le Mach augmente) }
Function Motorisation(Var Ap:TAvion;Var A:TAtm;V:Real):Real;
Var
 F:Real;
Begin
 If Ap.Helice Then Begin
  If Ap.HasLapse Then Motorisation:=Ap.Puissance*Ap.Rendement*Puissance(A.Sigma,Ap.Lapse)
   Else Motorisation:=Ap.Puissance*Ap.Rendement*(A.Sigma-0.12)/0.88;
 End
  Else
 Begin
  F:=1.0-0.55*V/A.A;
  If F<0.2 Then F:=0.2;
  Motorisation:=Ap.Poussee*Puissance(A.Sigma,Ap.Lapse)*F;
 End;
End;

Function Trainee(Var Ap:TAvion;Var A:TAtm;V:Real):Real;
Var
 Q,CL:Real;
Begin
 Q:=0.5*A.Rho*V*V;
 CL:=Ap.Masse*G/(Q*Ap.Surface);
 Trainee:=Q*Ap.Surface*(Ap.Cd0+Ap.K*CL*CL);
End;

{ Poussee disponible (N) a la vitesse V }
Function PousseeDisponible(Var Ap:TAvion;Var A:TAtm;V:Real):Real;
Var
 M:Real;
Begin
 M:=Motorisation(Ap,A,V);
 If M<0 Then M:=0;
 If Ap.Helice Then PousseeDisponible:=M/V Else PousseeDisponible:=M;
End;

{ Vitesse de decrochage (m/s, vitesse vraie) }
Function VitesseDecrochage(Var Ap:TAvion;Var A:TAtm):Real;Begin
 VitesseDecrochage:=Sqrt(2.0*Ap.Masse*G/(A.Rho*Ap.Surface*Ap.CLmax));
End;

{ Etudie la montee a l'altitude H : taux de montee max et pente max }
Procedure EtudierMontee(Var Ap:TAvion;H:Real;Var Mt:TMontee);
Var
 A:TAtm;
 V,Vmin,Vmax,Vcap,Dv,Excedent,Rc,Gr:Real;
 K,N:Integer;
Begin
 Atmosphere(H,Ap.DeltaT,A);
 Vmin:=1.2*VitesseDecrochage(Ap,A);
 Vmax:=Vmin+400.0;
 Vcap:=Ap.MachMax*A.A;
 If Vcap<Vmax Then Vmax:=Vcap;
 If Ap.VmaxKt>0 Then Vcap:=Ap.VmaxKt*KtMS/Sqrt(A.Sigma)
  Else If Not Ap.Helice Then Begin
   If H<3048.0 Then Vcap:=250.0*KtMS/Sqrt(A.Sigma)
               Else Vcap:=300.0*KtMS/Sqrt(A.Sigma);
  End
  Else Vcap:=Vmax;
 If Vcap<Vmax Then Vmax:=Vcap;
 If Vmax<Vmin+1.0 Then Vmax:=Vmin+1.0;
 N:=1600;
 Dv:=(Vmax-Vmin)/N;
 Mt.Ok:=False;
 Mt.Rc:=0;
 Mt.Vy:=0;
 Mt.GammaVy:=0;
 Mt.Gradient:=0;
 Mt.Vx:=0;
 Mt.RcVx:=0;
 Mt.Borne:=0;
 For K:=0 to N do Begin
  V:=Vmin+K*Dv;
  Excedent:=PousseeDisponible(Ap,A,V)-Trainee(Ap,A,V);
  Rc:=Excedent*V/(Ap.Masse*G);
  Gr:=Excedent/(Ap.Masse*G);
  If Rc>Mt.Rc Then Begin
   Mt.Rc:=Rc;
   Mt.Vy:=V;
   If Gr>1.0 Then Gr:=1.0;
   Mt.GammaVy:=ArcTan(Gr/Sqrt(1.0-Gr*Gr+1E-12));
   Mt.Ok:=True;
  End;
  If Gr>Mt.Gradient Then Begin
   Mt.Gradient:=Gr;
   Mt.Vx:=V;
   Mt.RcVx:=Rc;
  End;
 End;
 If Mt.Ok Then Begin
  If Mt.Vy<=Vmin+2.0*Dv Then Mt.Borne:=1 Else
  If Mt.Vy>=Vmax-2.0*Dv Then Mt.Borne:=2;
 End;
 If Mt.Gradient>1.0 Then Mt.Gradient:=1.0;
 Mt.Gradient:=ArcTan(Mt.Gradient/Sqrt(1.0-Mt.Gradient*Mt.Gradient+1E-12));
End;

Function TauxMax(Var Ap:TAvion;H:Real):Real;
Var
 Mt:TMontee;
Begin
 EtudierMontee(Ap,H,Mt);
 TauxMax:=Mt.Rc;
End;

{ Altitude (m) ou le taux de montee maximal tombe a Seuil (m/s) ;
  retourne -1 si le seuil n'est meme pas atteint au niveau de la mer. }
Function Plafond(Var Ap:TAvion;Seuil:Real):Real;
Var
 Lo,Hi,Mid:Real;
 K:Integer;
Begin
 If TauxMax(Ap,0)<=Seuil Then Begin
  Plafond:=-1;
  Exit;
 End;
 If TauxMax(Ap,HMax)>Seuil Then Begin
  Plafond:=HMax;
  Exit;
 End;
 Lo:=0;
 Hi:=HMax;
 For K:=1 to 30 do Begin
  Mid:=(Lo+Hi)/2.0;
  If TauxMax(Ap,Mid)>Seuil Then Lo:=Mid Else Hi:=Mid;
 End;
 Plafond:=(Lo+Hi)/2.0;
End;

{ Temps de montee (s) de H1 a H2 en suivant le taux de montee maximal;
  retourne -1 si H2 ne peut etre atteinte. }
Function TempsMontee(Var Ap:TAvion;H1,H2:Real):Real;
Var
 N,K:Integer;
 Dh,Hm,Rc,T:Real;
Begin
 TempsMontee:=-1;
 If H2<=H1 Then Begin
  TempsMontee:=0;
  Exit;
 End;
 N:=Round((H2-H1)/100.0)+1;
 Dh:=(H2-H1)/N;
 T:=0;
 For K:=0 to N-1 do Begin
  Hm:=H1+(K+0.5)*Dh;
  Rc:=TauxMax(Ap,Hm);
  If Rc<=0.01 Then Exit;
  T:=T+Dh/Rc;
 End;
 TempsMontee:=T;
End;

{ ---------------------------------------------------------------------
  Affichage
  --------------------------------------------------------------------- }

Function FmtFpm(Ms:Real):String;Begin
 FmtFpm:=Fmt(Ms/FtM*60.0,0)+' ft/min ('+Fmt(Ms,2)+' m/s)';
End;

Function FmtVit(Ms:Real):String;Begin
 FmtVit:=Fmt(Ms/KtMS,0)+' kt ('+Fmt(Ms/KmhMS,0)+' km/h)';
End;

Function FmtAlt(Hm:Real):String;Begin
 FmtAlt:=Fmt(Hm/FtM,0)+' ft ('+Fmt(Hm,0)+' m)';
End;

Function FmtDuree(Sec:Real):String;
Var
 Minutes:LongInt;
Begin
 Minutes:=Round(Sec/60.0);
 FmtDuree:=Fmt(Minutes div 60,0)+' h '+Fmt(Minutes mod 60,0)+' min';
End;

Procedure Ligne(Titre,Texte:String);Begin
 WriteLn(Pad(Titre,34),': ',Texte);
End;

Procedure AfficherMontee(Var Ap:TAvion;H:Real);
Var
 Mt:TMontee;
 A:TAtm;
 Ias:Real;
Begin
 EtudierMontee(Ap,H,Mt);
 Atmosphere(H,Ap.DeltaT,A);
 Ias:=Sqrt(A.Sigma);
 WriteLn('Montee a ',FmtAlt(H));
 WriteLn('Densite de l''air : ',Fmt(A.Rho,4),' kg/m3 (sigma=',Fmt(A.Sigma,4),
         '), temperature ',Fmt(A.T-273.15,1),' C');
 WriteLn;
 If Not Mt.Ok Then Begin
  WriteLn('L''avion ne peut pas monter a cette altitude (au-dessus du plafond absolu).');
  Exit;
 End;
 Ligne('Taux de montee maximal (Vy)',FmtFpm(Mt.Rc));
 Ligne('  Vitesse vraie',FmtVit(Mt.Vy)+', Mach '+Fmt(Mt.Vy/A.A,2));
 Ligne('  Vitesse indiquee approchee',FmtVit(Mt.Vy*Ias));
 Ligne('  Pente de montee',Fmt(Mt.GammaVy*180.0/PiVal,1)+' deg ('+
       Fmt(Sin(Mt.GammaVy)*100.0,1)+' %)');
 If Mt.Borne=1 Then WriteLn('  (limite par la vitesse minimale de montee, 1,2 fois la vitesse de decrochage)');
 If Mt.Borne=2 Then WriteLn('  (limite par la vitesse maximale de montee : vitesse indiquee ou Mach)');
 Ligne('Pente de montee maximale (Vx)',Fmt(Mt.Gradient*180.0/PiVal,1)+' deg ('+
       Fmt(Sin(Mt.Gradient)*100.0,1)+' %)');
 Ligne('  Vitesse vraie',FmtVit(Mt.Vx));
 Ligne('  Vitesse indiquee approchee',FmtVit(Mt.Vx*Ias));
 Ligne('  Taux de montee a Vx',FmtFpm(Mt.RcVx));
End;

Procedure AfficherPlafonds(Var Ap:TAvion);
Var
 Pr,Pa,Ps,Pc:Real;
 Service:Real;
 Nom:String;

 Procedure Sortie(Titre:String;Seuil:Real);
 Var
  Hp:Real;
 Begin
  Hp:=Plafond(Ap,Seuil);
  If Hp<0 Then Ligne(Titre,'inatteignable (taux de montee insuffisant au sol)')
  Else If Hp>=HMax Then Ligne(Titre,'au-dela de '+FmtAlt(HMax))
  Else Ligne(Titre,FmtAlt(Hp));
 End;

Begin
 If HasService Then Service:=ServiceFpm
  Else If Ap.Helice Then Service:=100.0 Else Service:=500.0;
 WriteLn;
 WriteLn('Plafonds');
 WriteLn('--------');
 Sortie('Plafond absolu (taux nul)',0.01);
 Sortie('Plafond pratique ('+Fmt(Service,0)+' ft/min)',Service*FtM/60.0);
 Sortie('Plafond de croisiere (300 ft/min)',300.0*FtM/60.0);
End;

Procedure AfficherTableau(Var Ap:TAvion);
Var
 Ha,Pas,H:Real;
 Mt:TMontee;
 A:TAtm;
 K:Integer;
Begin
 Ha:=Plafond(Ap,0.01);
 If Ha<=0 Then Exit;
 If Ha<=7000.0 Then Pas:=500.0 Else If Ha<=12000.0 Then Pas:=1000.0 Else Pas:=2000.0;
 WriteLn;
 WriteLn('Montee en fonction de l''altitude');
 WriteLn(PadGauche('Altitude (ft)',14),PadGauche('Taux (ft/min)',15),
         PadGauche('Vy vraie (kt)',15),PadGauche('Vy indiquee (kt)',18),
         PadGauche('Pente (deg)',13));
 H:=0;
 K:=0;
 While(H<Ha)and(K<40)do Begin
  EtudierMontee(Ap,H,Mt);
  If Not Mt.Ok Then H:=Ha Else Begin
   Atmosphere(H,Ap.DeltaT,A);
   WriteLn(PadGauche(Fmt(H/FtM,0),14),PadGauche(Fmt(Mt.Rc/FtM*60.0,0),15),
           PadGauche(Fmt(Mt.Vy/KtMS,0),15),
           PadGauche(Fmt(Mt.Vy*Sqrt(A.Sigma)/KtMS,0),18),
           PadGauche(Fmt(Mt.GammaVy*180.0/PiVal,1),13));
  End;
  H:=H+Pas;
  Inc(K);
 End;
End;

Procedure AfficherTemps(Var Ap:TAvion;H1,H2:Real);
Var
 T:Real;
Begin
 WriteLn;
 T:=TempsMontee(Ap,H1,H2);
 If T<0 Then
  WriteLn('Temps de montee jusqu''a ',FmtAlt(H2),' : impossible (au-dessus du plafond absolu)')
 Else
  WriteLn('Temps de montee de ',FmtAlt(H1),' a ',FmtAlt(H2),' : ',FmtDuree(T),
          ' (',Fmt(T/60.0,1),' min)');
End;

Procedure AfficherEntrees(Var Ap:TAvion);
Var
 Ar:Real;
Begin
 Ar:=1.0/(PiVal*Ap.K*0.8);
 WriteLn('Taux de montee et plafond');
 WriteLn('-------------------------');
 If Ap.Helice Then Ligne('Propulsion','helice, '+Fmt(Ap.Puissance/1000.0,1)+' kW ('+
                          Fmt(Ap.Puissance/1000.0/HpKw,0)+' hp), rendement '+Fmt(Ap.Rendement,2))
  Else Ligne('Propulsion','reacteur(s), '+Fmt(Ap.Poussee/1000.0,1)+' kN au niveau de la mer');
 Ligne('Masse',Fmt(Ap.Masse,0)+' kg ('+Fmt(Ap.Masse/LbKg,0)+' lb)');
 Ligne('Surface alaire',Fmt(Ap.Surface,1)+' m2');
 Ligne('Trainee',   'CD0='+Fmt(Ap.Cd0,4)+', k='+Fmt(Ap.K,4));
 Ligne('CL max (vitesse minimale)',Fmt(Ap.CLmax,2)+' (Vmin = 1,2 Vs)');
 If Ap.DeltaT<>0 Then Ligne('Ecart a l''ISA',Fmt(Ap.DeltaT,0)+' C');
 WriteLn;
End;

Procedure AfficherAide;Begin
 WriteLn('MONTEE : Cette commande permet de calculer le taux de montee et ',
         'les plafonds d''un avion.');
 WriteLn;
 WriteLn('Syntaxe : MONTEE JET masse surface cd0 allongement poussee [options]');
 WriteLn('          MONTEE HELICE masse surface cd0 allongement puissance rendement [options]');
 WriteLn;
 WriteLn(' masse        Masse de l''avion (kg)');
 WriteLn(' surface      Surface alaire (m2)');
 WriteLn(' cd0          Coefficient de trainee parasite (par exemple 0,025)');
 WriteLn(' allongement  Allongement de l''aile (envergure2 / surface)');
 WriteLn(' poussee      Poussee totale au niveau de la mer (kN)');
 WriteLn(' puissance    Puissance de l''arbre au niveau de la mer (kW)');
 WriteLn(' rendement    Rendement de l''helice (0,7 a 0,85)');
 WriteLn;
 WriteLn('Options :');
 WriteLn(' /LB /FT2 /M    Masse en livres, surface en pieds carres, altitudes en metres');
 WriteLn(' /HP            Puissance en chevaux-vapeur');
 WriteLn(' /LBF /N        Poussee en livres-force ou en newtons');
 WriteLn(' /E:x           Facteur d''Oswald de l''aile (0,8 par defaut)');
 WriteLn(' /CLMAX:x       Portance maximale, pour la vitesse minimale (1,6 par defaut)');
 WriteLn(' /LAPSE:n       Exposant de la perte de puissance ou de poussee avec la densite');
 WriteLn('                (reacteur 0,8 par defaut ; helice : formule de Gagg et Ferrar)');
 WriteLn(' /VMAX:kt       Vitesse indiquee maximale de montee (reacteur : 250 kt sous');
 WriteLn('                10 000 ft puis 300 kt par defaut)');
 WriteLn(' /MACH:x        Nombre de Mach maximal de montee (0,78 par defaut)');
 WriteLn(' /ALT:ft        Altitude de l''etude (0 par defaut)');
 WriteLn(' /DISA:deg      Ecart de temperature a l''atmosphere standard');
 WriteLn(' /SERVICE:fpm   Taux de montee du plafond pratique (100 helice, 500 reacteur)');
 WriteLn(' /HAUT:ft       Calcule le temps de montee jusqu''a cette altitude');
 WriteLn(' /T             Tableau de la montee en fonction de l''altitude');
 WriteLn;
 WriteLn('Code de sortie : 0 = Ok, 1 = erreur');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn(' MONTEE HELICE 1111 16.2 0.036 7.5 119 0.65 /E:0.7 /CLMAX:1.5 /T /HAUT:10000');
 WriteLn(' MONTEE HELICE 2450 16.2 0.036 7.5 160 0.65 /HP /LB /E:0.7 /ALT:8000');
 WriteLn(' MONTEE JET 70000 125 0.021 9.5 242 /T /CLMAX:2.0 /HAUT:35000');
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
 If Nom='/HP'Then Option:=Option+[_Hp] Else
 If Nom='/LBF'Then Option:=Option+[_Lbf] Else
 If Nom='/N'Then Option:=Option+[_Newton] Else
 If Nom='/T'Then Option:=Option+[_Table] Else
 If Nom='/E'Then Begin
  Av.K:=ParseReal(Valeur,'le facteur d''Oswald');
  If(Av.K<=0)or(Av.K>1.0)Then Erreur('Le facteur d''Oswald doit etre entre 0 et 1');
 End
  Else
 If Nom='/CLMAX'Then Av.CLmax:=ParseReal(Valeur,'CL max') Else
 If Nom='/VMAX'Then Begin
  Av.VmaxKt:=ParseReal(Valeur,'la vitesse maximale');
  If Av.VmaxKt<=0 Then Erreur('La vitesse maximale doit etre positive');
 End
  Else
 If Nom='/MACH'Then Begin
  Av.MachMax:=ParseReal(Valeur,'le Mach maximal');
  If(Av.MachMax<=0)or(Av.MachMax>1.0)Then Erreur('Le Mach maximal doit etre entre 0 et 1');
 End
  Else
 If Nom='/LAPSE'Then Begin
  Av.Lapse:=ParseReal(Valeur,'l''exposant');
  Av.HasLapse:=True;
 End
  Else
 If Nom='/ALT'Then Altitude:=ParseReal(Valeur,'l''altitude') Else
 If Nom='/DISA'Then Av.DeltaT:=ParseReal(Valeur,'l''ecart de temperature') Else
 If Nom='/SERVICE'Then Begin
  ServiceFpm:=ParseReal(Valeur,'le taux du plafond pratique');
  If ServiceFpm<=0 Then Erreur('Le taux du plafond pratique doit etre positif');
  HasService:=True;
 End
  Else
 If Nom='/HAUT'Then Begin
  HauteurCible:=ParseReal(Valeur,'l''altitude cible');
  HasHaut:=True;
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

Procedure AjouterArg(S:String);Begin
 If NArg>=8 Then Erreur('Trop de parametres');
 Inc(NArg);
 Arg[NArg]:=S;
End;

Procedure Interactif;
Var
 S:String;
Begin
 WriteLn('Taux de montee et plafond');
 WriteLn('-------------------------');
 Write('Propulsion (HELICE ou JET) : ');
 ReadLn(S);
 AjouterArg(StrToUpper(Trim(S)));
 Str(LireValeur('Masse (kg) : '):0:3,S);AjouterArg(S);
 Str(LireValeur('Surface alaire (m2) : '):0:3,S);AjouterArg(S);
 Str(LireValeur('Coefficient de trainee parasite CD0 : '):0:4,S);AjouterArg(S);
 Str(LireValeur('Allongement de l''aile : '):0:3,S);AjouterArg(S);
 If Arg[1]='JET'Then Begin
  Str(LireValeur('Poussee totale au niveau de la mer (kN) : '):0:3,S);AjouterArg(S);
 End
  Else
 Begin
  Str(LireValeur('Puissance de l''arbre (kW) : '):0:3,S);AjouterArg(S);
  Str(LireValeur('Rendement de l''helice : '):0:3,S);AjouterArg(S);
 End;
 Option:=Option+[_Table];
 WriteLn;
End;

Var
 Facteur,Ar,E:Real;
 Hm:Real;

BEGIN
 Option:=[];
 NArg:=0;
 Av.K:=0.8;                   { /E remplace ce facteur d'Oswald provisoire }
 Av.CLmax:=1.6;
 Av.Lapse:=0.8;
 Av.VmaxKt:=0;
 Av.MachMax:=0.78;
 Av.HasLapse:=False;
 Av.DeltaT:=0;
 Altitude:=0;
 HauteurCible:=0;
 ServiceFpm:=0;
 HasHaut:=False;
 HasService:=False;
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
 E:=Av.K;                     { facteur d'Oswald }
 Arg[1]:=StrToUpper(Arg[1]);
 If Arg[1]='JET'Then Begin
  If NArg<>6 Then Erreur('Syntaxe : MONTEE JET masse surface cd0 allongement poussee');
  Av.Helice:=False;
 End
  Else
 If(Arg[1]='HELICE')or(Arg[1]='PROP')Then Begin
  If NArg<>7 Then Erreur('Syntaxe : MONTEE HELICE masse surface cd0 allongement puissance rendement');
  Av.Helice:=True;
  Av.Rendement:=ParseReal(Arg[7],'le rendement');
  If(Av.Rendement<=0)or(Av.Rendement>1.0)Then Erreur('Le rendement doit etre entre 0 et 1');
 End
  Else Erreur('Type de propulsion inconnu : '+Arg[1]+' (JET ou HELICE)');
 Av.Masse:=ParseReal(Arg[2],'la masse');
 Av.Surface:=ParseReal(Arg[3],'la surface alaire');
 Av.Cd0:=ParseReal(Arg[4],'CD0');
 Ar:=ParseReal(Arg[5],'l''allongement');
 If(Av.Masse<=0)or(Av.Surface<=0)Then Erreur('La masse et la surface doivent etre positives');
 If(Av.Cd0<=0)or(Av.Cd0>0.5)Then Erreur('CD0 doit etre entre 0 et 0,5');
 If(Ar<=0)or(Ar>40.0)Then Erreur('L''allongement doit etre entre 0 et 40');
 If(Av.CLmax<=0)or(Av.CLmax>5.0)Then Erreur('CL max doit etre entre 0 et 5');
 Av.K:=1.0/(PiVal*E*Ar);
 If _Livres in Option Then Av.Masse:=Av.Masse*LbKg;
 If _Pieds2 in Option Then Av.Surface:=Av.Surface*Ft2M2;
 If Av.Helice Then Begin
  Av.Puissance:=ParseReal(Arg[6],'la puissance');
  If Av.Puissance<=0 Then Erreur('La puissance doit etre positive');
  If _Hp in Option Then Av.Puissance:=Av.Puissance*HpKw*1000.0
   Else Av.Puissance:=Av.Puissance*1000.0;
 End
  Else
 Begin
  Av.Poussee:=ParseReal(Arg[6],'la poussee');
  If Av.Poussee<=0 Then Erreur('La poussee doit etre positive');
  If _Lbf in Option Then Av.Poussee:=Av.Poussee*LbfN
   Else If _Newton in Option Then
  Else Av.Poussee:=Av.Poussee*1000.0;
 End;
 If _Metres in Option Then Facteur:=1.0 Else Facteur:=FtM;
 Hm:=Altitude*Facteur;
 If(Hm<-500.0)or(Hm>HMax)Then Erreur('Altitude hors limites');
 AfficherEntrees(Av);
 AfficherMontee(Av,Hm);
 AfficherPlafonds(Av);
 If _Table in Option Then AfficherTableau(Av);
 If HasHaut Then AfficherTemps(Av,Hm,HauteurCible*Facteur);
END.
