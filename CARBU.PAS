{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program CARBU;

{ Autonomie, portee et rayon d'action d'un avion :
   - mode simple : a partir du carburant, de la consommation horaire et de
     la vitesse, avec vent, reserves, deroutement, roulage et alea ;
   - mode Breguet : a partir de la masse, de la finesse et de la
     consommation specifique (reacteur ou helice). }

Const
 G=9.80665;            { Gravite normale (m/s2) }
 NmKm=1.852;           { Kilometres par mille marin }
 MiKm=1.609344;        { Kilometres par mille terrestre }
 GalL=3.785411784;     { Litres par gallon americain }
 LbKg=0.45359237;      { Kilogrammes par livre }
 DensAvgas=0.72;       { Densite de l'essence aviation (kg/L) }
 DensJetA=0.80;        { Densite du kerosene (kg/L) }

Type
 TSimple=Record
  Carburant:Real;      { carburant a bord (kg) }
  Debit:Real;          { consommation horaire (kg/h) }
  Vitesse:Real;        { vitesse vraie (kt) }
  Vent:Real;           { vent de face (kt), negatif = arriere }
  Reserve:Real;        { reserve finale (minutes) }
  Deroute:Real;        { distance du deroutement (NM) }
  Roulage:Real;        { carburant de roulage (kg) }
  Alea:Real;           { alea, fraction du carburant de route }
  Distance:Real;       { distance du trajet demande (NM), 0 = aucune }
 End;

 TBreguet=Record
  Helice:Boolean;      { True = helice, False = reacteur }
  MasseInit:Real;      { masse initiale (kg) }
  Carburant:Real;      { carburant consommable (kg) }
  Finesse:Real;        { rapport portance/trainee L/D }
  Vitesse:Real;        { vitesse vraie (kt) }
  Conso:Real;          { TSFC (1/h) ou SFC (kg/kWh) }
  Rendement:Real;      { rendement d'helice }
  Vent:Real;           { vent de face (kt) }
  ReservePC:Real;      { reserve en pourcentage du carburant }
 End;

Var
 Option:Set of (_Litres,_Gallons,_Livres);
 Densite:Real;
 S:TSimple;
 B:TBreguet;
 Arg:Array[1..9]of String;
 NArg,I:Integer;
 Param,Cmd:String;
 ModeBreguet:Boolean;

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
 T:String;
 I:Integer;
 Zero:Boolean;
Begin
 Str(R:0:N,T);
 Zero:=True;
 For I:=1 to Length(T)do If T[I]in['1'..'9']Then Zero:=False;
 If Zero and(T[1]='-')Then Delete(T,1,1);
 Fmt:=T;
End;

Procedure Erreur(Msg:String);Begin
 WriteLn(Msg);
 Halt(1);
End;

Function ParseReal(Const T,Nom:String):Real;
Var
 U:String;
 V:Real;
 Code,I:Integer;
Begin
 U:=Trim(T);
 For I:=1 to Length(U)do If U[I]=','Then U[I]:='.';
 Val(U,V,Code);
 If(Code<>0)or(U='')Then Erreur('Valeur invalide pour '+Nom+' : '+T);
 ParseReal:=V;
End;

{ Facteur de conversion de l'unite de carburant choisie vers le kilogramme. }
Function FacteurCarburant:Real;Begin
 If _Litres in Option Then FacteurCarburant:=Densite Else
 If _Gallons in Option Then FacteurCarburant:=Densite*GalL Else
 If _Livres in Option Then FacteurCarburant:=LbKg
  Else FacteurCarburant:=1.0;
End;

Function FmtCarburant(Kg:Real):String;Begin
 FmtCarburant:=Fmt(Kg,1)+' kg ('+Fmt(Kg/Densite,1)+' L, '+
               Fmt(Kg/Densite/GalL,1)+' gal US, '+Fmt(Kg/LbKg,1)+' lb)';
End;

Function FmtDuree(H:Real):String;
Var
 Minutes:LongInt;
 Hh,Mm:LongInt;
Begin
 Minutes:=Round(H*60.0);
 Hh:=Minutes div 60;
 Mm:=Minutes mod 60;
 If Mm<10 Then FmtDuree:=Fmt(Hh,0)+' h 0'+Fmt(Mm,0)+' min ('+Fmt(H,2)+' h)'
          Else FmtDuree:=Fmt(Hh,0)+' h '+Fmt(Mm,0)+' min ('+Fmt(H,2)+' h)';
End;

Function FmtDistance(Nm:Real):String;Begin
 FmtDistance:=Fmt(Nm,0)+' NM ('+Fmt(Nm*NmKm,0)+' km, '+
              Fmt(Nm*NmKm/MiKm,0)+' mi)';
End;

Function Pad(T:String;N:Integer):String;Begin
 While Length(T)<N do T:=T+' ';
 Pad:=T;
End;

{ Rayon d'action : distance maximale aller-retour pour une duree totale de
  vol donnee, avec les vitesses sol a l'aller (Ga) et au retour (Gr). C'est
  aussi la distance du point de non-retour. }
Function Rayon(Duree,Ga,Gr:Real):Real;Begin
 Rayon:=Duree*Ga*Gr/(Ga+Gr);
End;

Procedure Ligne(Titre,Valeur:String);Begin
 WriteLn(Pad(Titre,38),': ',Valeur);
End;

Procedure CalculerSimple(Var Si:TSimple);
Var
 Ga,Gr,CarbReserve,CarbDero,CarbDispo,CarbRoute,CarbAlea,Duree,Dist,Besoin:Real;
Begin
 If Si.Carburant<=0 Then Erreur('Le carburant doit etre positif');
 If Si.Debit<=0 Then Erreur('La consommation doit etre positive');
 If Si.Vitesse<=0 Then Erreur('La vitesse doit etre positive');
 If(Si.Reserve<0)or(Si.Deroute<0)or(Si.Roulage<0)or(Si.Alea<0)Then
  Erreur('Les reserves, le deroutement, le roulage et l''alea doivent etre positifs');
 Ga:=Si.Vitesse-Si.Vent;
 Gr:=Si.Vitesse+Si.Vent;
 If(Ga<=0)or(Gr<=0)Then
  Erreur('Le vent est superieur ou egal a la vitesse de l''avion');
 CarbReserve:=Si.Debit*Si.Reserve/60.0;
 CarbDero:=Si.Debit*Si.Deroute/Si.Vitesse;
 CarbDispo:=Si.Carburant-Si.Roulage-CarbReserve-CarbDero;
 WriteLn('Autonomie et rayon d''action');
 WriteLn('----------------------------');
 WriteLn(Pad('Carburant a bord',38),': ',FmtCarburant(Si.Carburant));
 WriteLn(Pad('Consommation',38),': ',Fmt(Si.Debit,1),' kg/h (',
         Fmt(Si.Debit/Densite,1),' L/h, ',Fmt(Si.Debit/Densite/GalL,1),
         ' gal/h)');
 WriteLn(Pad('Vitesse vraie',38),': ',Fmt(Si.Vitesse,0),' kt');
 If Si.Vent>=0 Then WriteLn(Pad('Vent',38),': ',Fmt(Si.Vent,0),
                            ' kt de face a l''aller (arriere au retour)')
               Else WriteLn(Pad('Vent',38),': ',Fmt(-Si.Vent,0),
                            ' kt arriere a l''aller (face au retour)');
 WriteLn(Pad('Vitesse sol aller / retour',38),': ',Fmt(Ga,0),' kt / ',
         Fmt(Gr,0),' kt');
 WriteLn(Pad('Consommation specifique',38),': ',Fmt(Si.Debit/Si.Vitesse,2),
         ' kg/NM en air calme (',Fmt(Si.Vitesse/Si.Debit*Densite*GalL,2),
         ' NM/gal US)');
 WriteLn;
 Ligne('Autonomie totale (reservoirs vides)',FmtDuree(Si.Carburant/Si.Debit));
 Ligne('Portee maximale en air calme',
       FmtDistance(Si.Carburant/Si.Debit*Si.Vitesse));
 WriteLn;
 WriteLn('Carburant a deduire');
 If Si.Roulage>0 Then Ligne(' Roulage',FmtCarburant(Si.Roulage));
 Ligne(' Reserve finale ('+Fmt(Si.Reserve,0)+' min)',FmtCarburant(CarbReserve));
 If Si.Deroute>0 Then
  Ligne(' Deroutement ('+Fmt(Si.Deroute,0)+' NM)',FmtCarburant(CarbDero));
 If CarbDispo<=0 Then Begin
  WriteLn;
  WriteLn('Carburant insuffisant : les reserves depassent le carburant a bord.');
  Halt(2);
 End;
 CarbRoute:=CarbDispo/(1.0+Si.Alea);
 CarbAlea:=CarbDispo-CarbRoute;
 If Si.Alea>0 Then
  Ligne(' Alea ('+Fmt(Si.Alea*100.0,1)+' %)',FmtCarburant(CarbAlea));
 WriteLn;
 Ligne('Carburant utilisable en route',FmtCarburant(CarbRoute));
 Duree:=CarbRoute/Si.Debit;
 Ligne('Autonomie utilisable',FmtDuree(Duree));
 Ligne('Portee utilisable (vent de face)',FmtDistance(Duree*Ga));
 Ligne('Portee utilisable (vent arriere)',FmtDistance(Duree*Gr));
 Ligne('Rayon d''action (aller-retour)',FmtDistance(Rayon(Duree,Ga,Gr)));
 Ligne('Point de non-retour',FmtDistance(Rayon(Duree,Ga,Gr))+' du depart');
 If Si.Distance>0 Then Begin
  Dist:=Si.Distance;
  Besoin:=Si.Roulage+Si.Debit*Dist/Ga*(1.0+Si.Alea)+CarbReserve+CarbDero;
  WriteLn;
  WriteLn('Trajet de ',FmtDistance(Dist));
  Ligne(' Duree du vol',FmtDuree(Dist/Ga));
  Ligne(' Carburant minimal necessaire',FmtCarburant(Besoin));
  If Besoin<=Si.Carburant Then
   Ligne(' Trajet possible, marge',FmtCarburant(Si.Carburant-Besoin))
  Else Begin
   Ligne(' TRAJET IMPOSSIBLE, il manque',FmtCarburant(Besoin-Si.Carburant));
   Halt(2);
  End;
 End;
End;

Procedure CalculerBreguet(Var Br:TBreguet);
Var
 W2,Ln_,Vms,Sfc,Autonomie,Portee,Ga,Gr,Consommable:Real;
Begin
 If Br.MasseInit<=0 Then Erreur('La masse initiale doit etre positive');
 If Br.Carburant<=0 Then Erreur('Le carburant doit etre positif');
 If Br.Finesse<=0 Then Erreur('La finesse doit etre positive');
 If Br.Vitesse<=0 Then Erreur('La vitesse doit etre positive');
 If Br.Conso<=0 Then Erreur('La consommation specifique doit etre positive');
 If(Br.ReservePC<0)or(Br.ReservePC>=100.0)Then
  Erreur('La reserve doit etre entre 0 et 100 %');
 If Br.Carburant>=Br.MasseInit Then
  Erreur('Le carburant doit etre inferieur a la masse initiale');
 If Br.Helice and((Br.Rendement<=0)or(Br.Rendement>1.0))Then
  Erreur('Le rendement d''helice doit etre entre 0 et 1');
 Consommable:=Br.Carburant*(1.0-Br.ReservePC/100.0);
 W2:=Br.MasseInit-Consommable;
 Ln_:=Ln(Br.MasseInit/W2);
 Vms:=Br.Vitesse*NmKm*1000.0/3600.0;
 If Br.Helice Then Begin
  Sfc:=Br.Conso/3.6E6;
  Portee:=Br.Rendement*Br.Finesse*Ln_/(Sfc*G)/1000.0/NmKm;
 End
  Else
 Portee:=Br.Vitesse*Br.Finesse/Br.Conso*Ln_;
 Autonomie:=Portee/Br.Vitesse;
 Ga:=Br.Vitesse-Br.Vent;
 Gr:=Br.Vitesse+Br.Vent;
 If(Ga<=0)or(Gr<=0)Then
  Erreur('Le vent est superieur ou egal a la vitesse de l''avion');
 WriteLn('Autonomie et rayon d''action (formule de Breguet)');
 WriteLn('------------------------------------------------');
 If Br.Helice Then WriteLn(Pad('Propulsion',38),': helice (rendement ',
                           Fmt(Br.Rendement,2),', SFC ',Fmt(Br.Conso,3),' kg/kWh)')
              Else WriteLn(Pad('Propulsion',38),': reacteur (TSFC ',
                           Fmt(Br.Conso,3),' 1/h)');
 WriteLn(Pad('Masse initiale',38),': ',Fmt(Br.MasseInit,0),' kg');
 WriteLn(Pad('Carburant',38),': ',FmtCarburant(Br.Carburant));
 If Br.ReservePC>0 Then
  WriteLn(Pad('Carburant consommable',38),': ',FmtCarburant(Consommable),
          ' (reserve ',Fmt(Br.ReservePC,1),' %)');
 WriteLn(Pad('Masse finale',38),': ',Fmt(W2,0),' kg (ln W1/W2 = ',
         Fmt(Ln_,4),')');
 WriteLn(Pad('Finesse L/D',38),': ',Fmt(Br.Finesse,1));
 WriteLn(Pad('Vitesse vraie',38),': ',Fmt(Br.Vitesse,0),' kt (',
         Fmt(Vms,1),' m/s)');
 WriteLn;
 Ligne('Autonomie',FmtDuree(Autonomie));
 Ligne('Portee en air calme',FmtDistance(Portee));
 Ligne('Rayon d''action',FmtDistance(Rayon(Autonomie,Ga,Gr)));
 If Br.Vent<>0 Then Begin
  Ligne('Portee vent de face',FmtDistance(Autonomie*Ga));
  Ligne('Portee vent arriere',FmtDistance(Autonomie*Gr));
 End;
End;

Procedure AfficherAide;Begin
 WriteLn('CARBU : Cette commande permet de calculer l''autonomie, la portee ',
         'et le rayon d''action');
 WriteLn('        d''un avion.');
 WriteLn;
 WriteLn('Syntaxe : CARBU carburant debit vitesse [options]');
 WriteLn('          CARBU BREGUET JET masse carburant finesse vitesse tsfc [options]');
 WriteLn('          CARBU BREGUET HELICE masse carburant finesse vitesse sfc [rendement] [options]');
 WriteLn;
 WriteLn(' carburant   Carburant a bord (kg par defaut)');
 WriteLn(' debit       Consommation horaire (kg/h par defaut)');
 WriteLn(' vitesse     Vitesse vraie de croisiere (noeuds)');
 WriteLn(' masse       Masse initiale de l''avion (kg)');
 WriteLn(' finesse     Rapport portance/trainee L/D en croisiere');
 WriteLn(' tsfc        Consommation specifique du reacteur (1/h, ex. 0,6)');
 WriteLn(' sfc         Consommation specifique de l''helice (kg/kWh, ex. 0,27)');
 WriteLn(' rendement   Rendement d''helice (0,80 par defaut)');
 WriteLn;
 WriteLn('Options :');
 WriteLn(' /L /GAL /LB      Carburant et debit en litres, gallons US ou livres');
 WriteLn(' /DENS:x          Densite du carburant en kg/L (0,72 par defaut)');
 WriteLn(' /AVGAS /JETA     Densite de l''essence (0,72) ou du kerosene (0,80)');
 WriteLn(' /VENT:kt         Vent de face a l''aller en noeuds (negatif = arriere)');
 WriteLn(' /RESERVE:min     Reserve finale en minutes (30 par defaut)');
 WriteLn(' /DERO:NM         Distance du deroutement en milles marins');
 WriteLn(' /ROUL:x          Carburant de roulage (dans l''unite du carburant)');
 WriteLn(' /ALEA:%          Alea en pourcentage du carburant de route');
 WriteLn(' /DISTANCE:NM     Verifie si un trajet de cette distance est possible');
 WriteLn(' /RESERVEPC:%     Mode Breguet : reserve en pourcentage du carburant');
 WriteLn;
 WriteLn('Code de sortie : 0 = Ok, 1 = erreur, 2 = carburant insuffisant');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn(' CARBU 150 35 100 /L /AVGAS');
 WriteLn(' CARBU 150 35 100 /L /VENT:15 /RESERVE:45 /DISTANCE:250');
 WriteLn(' CARBU BREGUET JET 70000 18000 17 450 0.6');
 WriteLn(' CARBU BREGUET HELICE 1100 150 10 110 0.27 0.8 /RESERVEPC:10');
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
 If Nom='/L'Then Option:=Option+[_Litres] Else
 If Nom='/GAL'Then Option:=Option+[_Gallons] Else
 If Nom='/LB'Then Option:=Option+[_Livres] Else
 If Nom='/DENS'Then Densite:=ParseReal(Valeur,'la densite') Else
 If Nom='/AVGAS'Then Densite:=DensAvgas Else
 If Nom='/JETA'Then Densite:=DensJetA Else
 If Nom='/VENT'Then Begin
  S.Vent:=ParseReal(Valeur,'le vent');
  B.Vent:=S.Vent;
 End
  Else
 If Nom='/RESERVE'Then S.Reserve:=ParseReal(Valeur,'la reserve') Else
 If Nom='/DERO'Then S.Deroute:=ParseReal(Valeur,'le deroutement') Else
 If Nom='/ROUL'Then S.Roulage:=ParseReal(Valeur,'le roulage') Else
 If Nom='/ALEA'Then S.Alea:=ParseReal(Valeur,'l''alea')/100.0 Else
 If Nom='/DISTANCE'Then S.Distance:=ParseReal(Valeur,'la distance') Else
 If Nom='/RESERVEPC'Then B.ReservePC:=ParseReal(Valeur,'la reserve')
  Else Erreur('Option inconnue : '+Param);
End;

Function LireValeur(Prompt:String):Real;
Var
 T:String;
Begin
 Write(Prompt);
 ReadLn(T);
 LireValeur:=ParseReal(T,'la valeur');
End;

Procedure Interactif;
Var
 T:String;
Begin
 WriteLn('Autonomie et rayon d''action');
 WriteLn('----------------------------');
 WriteLn('(carburant en kg, consommation en kg/h, vitesse en noeuds)');
 S.Carburant:=LireValeur('Carburant a bord : ');
 S.Debit:=LireValeur('Consommation horaire : ');
 S.Vitesse:=LireValeur('Vitesse vraie (kt) : ');
 Write('Vent de face en noeuds (vide = 0) : ');
 ReadLn(T);
 If Trim(T)<>''Then S.Vent:=ParseReal(T,'le vent');
 Write('Distance du trajet en NM (vide = aucune) : ');
 ReadLn(T);
 If Trim(T)<>''Then S.Distance:=ParseReal(T,'la distance');
 WriteLn;
End;

BEGIN
 Option:=[];
 Densite:=DensAvgas;
 S.Vent:=0;
 S.Reserve:=30.0;
 S.Deroute:=0;
 S.Roulage:=0;
 S.Alea:=0;
 S.Distance:=0;
 B.Vent:=0;
 B.ReservePC:=0;
 B.Rendement:=0.80;
 NArg:=0;
 ModeBreguet:=False;
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
   If NArg>=9 Then Erreur('Trop de parametres');
   Inc(NArg);
   Arg[NArg]:=Param;
  End;
 End;
 If Densite<=0.3 Then Erreur('La densite du carburant n''est pas valide');
 If NArg=0 Then Begin
  Interactif;
  CalculerSimple(S);
  Halt(0);
 End;
 Cmd:=StrToUpper(Arg[1]);
 If Cmd='BREGUET'Then Begin
  If NArg<2 Then Erreur('Syntaxe : CARBU BREGUET JET|HELICE ...');
  Cmd:=StrToUpper(Arg[2]);
  If Cmd='JET'Then Begin
   If NArg<7 Then Erreur('Syntaxe : CARBU BREGUET JET masse carburant finesse vitesse tsfc');
   If NArg>7 Then Erreur('Trop de parametres');
   B.Helice:=False;
  End
   Else
  If(Cmd='HELICE')or(Cmd='PROP')Then Begin
   If(NArg<7)or(NArg>8)Then
    Erreur('Syntaxe : CARBU BREGUET HELICE masse carburant finesse vitesse sfc [rendement]');
   B.Helice:=True;
   If NArg=8 Then B.Rendement:=ParseReal(Arg[8],'le rendement');
  End
   Else
  Erreur('Type de propulsion inconnu : '+Arg[2]+' (JET ou HELICE)');
  B.MasseInit:=ParseReal(Arg[3],'la masse initiale');
  If _Livres in Option Then B.MasseInit:=B.MasseInit*LbKg;
  B.Carburant:=ParseReal(Arg[4],'le carburant')*FacteurCarburant;
  B.Finesse:=ParseReal(Arg[5],'la finesse');
  B.Vitesse:=ParseReal(Arg[6],'la vitesse');
  B.Conso:=ParseReal(Arg[7],'la consommation specifique');
  CalculerBreguet(B);
 End
  Else
 Begin
  If NArg<>3 Then Erreur('Syntaxe : CARBU carburant debit vitesse [options]');
  S.Carburant:=ParseReal(Arg[1],'le carburant')*FacteurCarburant;
  S.Debit:=ParseReal(Arg[2],'la consommation')*FacteurCarburant;
  S.Vitesse:=ParseReal(Arg[3],'la vitesse');
  S.Roulage:=S.Roulage*FacteurCarburant;
  CalculerSimple(S);
 End;
END.
