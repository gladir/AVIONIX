{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program VENT;

{ Triangle des vents :
   - ROUTE : cap a tenir, angle de derive et vitesse sol pour suivre une
     route donnee avec un vent donne ;
   - CAP   : route suivie et vitesse sol pour un cap donne ;
   - MESURE: vent (direction et vitesse) deduit du cap, de la vitesse propre,
     de la route suivie et de la vitesse sol ;
   - PISTE : composantes de face et de travers du vent pour une ou plusieurs
     pistes. }

Const
 PiVal=3.14159265358979;
 Rad=PiVal/180.0;
 KtKmh=1.852;          { Kilometres par heure par noeud }
 KtMS=0.514444;        { Metres par seconde par noeud }
 KtMph=1.150779;       { Milles a l'heure par noeud }
 MaxPistes=16;

Type
 TPisteList=Array[0..MaxPistes-1]of String[12];

 TVecteur=Record
  E,N:Real;                    { composantes est et nord }
 End;

 TVent=Record
  Dir,Vit:Real;                { provenance (degres) et vitesse (kt) }
 End;

 TTriangle=Record
  Route:Real;                  { route suivie (degres vrais) }
  Cap:Real;                    { cap (degres vrais) }
  Tas,Gs:Real;                 { vitesses propre et sol (kt) }
  Derive:Real;                 { cap - route inverse : derive, positive = vers la droite }
  Ok:Boolean;
 End;

Var
 Option:Set of (_Kmh,_Ms,_Mph);
 Arg:Array[1..20]of String;
 NArg,I:Integer;
 Param,Cmd:String;
 Variation,Deviation,Distance,Rafales,Limite:Real;
 HasVar,HasDev,HasDist,HasRaf,HasLim:Boolean;

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
  Trigonometrie et unites
  --------------------------------------------------------------------- }

Function Atan2(Y,X:Real):Real;Begin
 If X>0 Then Atan2:=ArcTan(Y/X) Else
 If X<0 Then Begin
  If Y>=0 Then Atan2:=ArcTan(Y/X)+PiVal Else Atan2:=ArcTan(Y/X)-PiVal;
 End
  Else
 Begin
  If Y>0 Then Atan2:=PiVal/2.0 Else
  If Y<0 Then Atan2:=-PiVal/2.0 Else Atan2:=0;
 End;
End;

Function ArcSin(X:Real):Real;Begin
 If X>=1.0 Then ArcSin:=PiVal/2.0 Else
 If X<=-1.0 Then ArcSin:=-PiVal/2.0
  Else ArcSin:=ArcTan(X/Sqrt(1.0-X*X));
End;

Function Cap360(X:Real):Real;Begin
 While X<0 Do X:=X+360.0;
 While X>=360.0 Do X:=X-360.0;
 Cap360:=X;
End;

{ Difference d'angles ramenee entre -180 et 180 degres }
Function Ecart(X:Real):Real;Begin
 While X>180.0 Do X:=X-360.0;
 While X<=-180.0 Do X:=X+360.0;
 Ecart:=X;
End;

Function VitesseEnKt(V:Real):Real;Begin
 If _Kmh in Option Then VitesseEnKt:=V/KtKmh Else
 If _Ms in Option Then VitesseEnKt:=V/KtMS Else
 If _Mph in Option Then VitesseEnKt:=V/KtMph
  Else VitesseEnKt:=V;
End;

Function FmtVitesse(Kt:Real):String;Begin
 FmtVitesse:=Fmt(Kt,0)+' kt ('+Fmt(Kt*KtKmh,0)+' km/h)';
End;

Function FmtAngle(A:Real):String;
Var
 R:Integer;
 S:String;
Begin
 R:=Round(Cap360(A))mod 360;
 S:=Fmt(R,0);
 While Length(S)<3 Do S:='0'+S;
 FmtAngle:=S+' deg';
End;

Function FmtCote(A:Real;Droite,Gauche:String):String;Begin
 If A>=0 Then FmtCote:=Fmt(Abs(A),1)+' deg '+Droite
         Else FmtCote:=Fmt(Abs(A),1)+' deg '+Gauche;
End;

Function FmtDuree(H:Real):String;
Var
 Minutes:LongInt;
Begin
 Minutes:=Round(H*60.0);
 FmtDuree:=Fmt(Minutes div 60,0)+' h '+Fmt(Minutes mod 60,0)+' min';
End;

{ ---------------------------------------------------------------------
  Calculs
  --------------------------------------------------------------------- }

Procedure Vecteur(Var V:TVecteur;Direction,Vitesse:Real);Begin
 V.E:=Vitesse*Sin(Direction*Rad);
 V.N:=Vitesse*Cos(Direction*Rad);
End;

{ Composantes du vent par rapport a une direction (piste ou route) :
  Face > 0 : vent de face ; Travers > 0 : vent venant de la droite. }
Procedure Composantes(Var Vt:TVent;Direction:Real;Var Face,Travers:Real);Begin
 Face:=Vt.Vit*Cos((Vt.Dir-Direction)*Rad);
 Travers:=Vt.Vit*Sin((Vt.Dir-Direction)*Rad);
End;

{ Probleme direct : cap a tenir pour la route Route avec la vitesse propre Tas }
Procedure TriangleRoute(Route,Tas:Real;Var Vt:TVent;Var T:TTriangle);
Var
 S,Wca:Real;
Begin
 T.Ok:=False;
 T.Route:=Route;
 T.Tas:=Tas;
 S:=Vt.Vit*Sin((Vt.Dir-Route)*Rad)/Tas;
 If Abs(S)>=1.0 Then Exit;
 Wca:=ArcSin(S)/Rad;
 T.Cap:=Cap360(Route+Wca);
 T.Derive:=Wca;
 T.Gs:=Tas*Cos(Wca*Rad)-Vt.Vit*Cos((Vt.Dir-Route)*Rad);
 If T.Gs<=0 Then Exit;
 T.Ok:=True;
End;

{ Cap donne : route suivie et vitesse sol }
Procedure TriangleCap(Cap,Tas:Real;Var Vt:TVent;Var T:TTriangle);
Var
 A,W,G:TVecteur;
Begin
 Vecteur(A,Cap,Tas);
 Vecteur(W,Vt.Dir+180.0,Vt.Vit);
 G.E:=A.E+W.E;
 G.N:=A.N+W.N;
 T.Cap:=Cap;
 T.Tas:=Tas;
 T.Gs:=Sqrt(G.E*G.E+G.N*G.N);
 If T.Gs<1E-9 Then Begin
  T.Route:=Cap;
  T.Ok:=False;
  Exit;
 End;
 T.Route:=Cap360(Atan2(G.E,G.N)/Rad);
 T.Derive:=Ecart(T.Route-Cap);
 T.Ok:=True;
End;

{ Vent deduit de deux triangles : cap, vitesse propre, route et vitesse sol }
Procedure TrouverVent(Cap,Tas,Route,Gs:Real;Var Vt:TVent);
Var
 A,G,W:TVecteur;
Begin
 Vecteur(A,Cap,Tas);
 Vecteur(G,Route,Gs);
 W.E:=G.E-A.E;
 W.N:=G.N-A.N;
 Vt.Vit:=Sqrt(W.E*W.E+W.N*W.N);
 If Vt.Vit<1E-9 Then Vt.Dir:=0
  Else Vt.Dir:=Cap360(Atan2(-W.E,-W.N)/Rad);
End;

{ Numero de piste ("09", "27L") ou cap en degres }
Function LirePiste(S:String;Var Cap:Real):Boolean;
Var
 V:Real;
 T:String;
Begin
 LirePiste:=False;
 T:=StrToUpper(Trim(S));
 If(Length(T)>0)and(T[Length(T)]in['L','C','R'])Then Delete(T,Length(T),1);
 If Not EstNombre(T,V)Then Exit;
 If(V>=0)and(V<=36)and(Length(T)<=2)Then V:=V*10.0;
 If(V<0)or(V>360)Then Exit;
 If V=0 Then V:=360.0;
 Cap:=V;
 LirePiste:=True;
End;

{ ---------------------------------------------------------------------
  Affichage
  --------------------------------------------------------------------- }

Procedure Ligne(Titre,Texte:String);Begin
 WriteLn(Pad(Titre,28),': ',Texte);
End;

Function FmtCapMag(Vrai:Real):String;
Var
 S:String;
 Mag:Real;
Begin
 S:=FmtAngle(Vrai)+' vrai';
 Mag:=Vrai;
 If HasVar Then Begin
  Mag:=Cap360(Vrai-Variation);
  S:=S+', '+FmtAngle(Mag)+' magnetique';
 End;
 If HasDev Then S:=S+', '+FmtAngle(Cap360(Mag-Deviation))+' compas';
 FmtCapMag:=S;
End;

Procedure AfficherVent(Var Vt:TVent);Begin
 Ligne('Vent (provenance)',FmtAngle(Vt.Dir)+' a '+FmtVitesse(Vt.Vit));
End;

Procedure AfficherComposantes(Titre:String;Var Vt:TVent;Direction:Real);
Var
 Face,Travers:Real;
Begin
 Composantes(Vt,Direction,Face,Travers);
 If Face>=0 Then Ligne(Titre+' : face',FmtVitesse(Face))
            Else Ligne(Titre+' : arriere',FmtVitesse(-Face));
 If Travers>=0 Then Ligne(Titre+' : travers','venant de la droite, '+FmtVitesse(Travers))
               Else Ligne(Titre+' : travers','venant de la gauche, '+FmtVitesse(-Travers));
End;

Procedure AfficherTemps(Gs:Real);Begin
 If HasDist and(Gs>0)Then Begin
  Ligne('Distance',Fmt(Distance,0)+' NM ('+Fmt(Distance*KtKmh,0)+' km)');
  Ligne('Duree estimee',FmtDuree(Distance/Gs));
 End;
End;

Procedure CmdRoute(Route,Tas:Real;Var Vt:TVent);
Var
 T:TTriangle;
Begin
 TriangleRoute(Route,Tas,Vt,T);
 WriteLn('Triangle des vents : cap a tenir');
 WriteLn('---------------------------------');
 Ligne('Route vraie desiree',FmtAngle(Route));
 Ligne('Vitesse propre (TAS)',FmtVitesse(Tas));
 AfficherVent(Vt);
 WriteLn;
 If Not T.Ok Then Begin
  WriteLn('Route impossible : le vent est trop fort pour tenir cette route.');
  Halt(2);
 End;
 Ligne('Angle de correction',FmtCote(T.Derive,'a droite','a gauche'));
 Ligne('Cap a tenir',FmtCapMag(T.Cap));
 Ligne('Vitesse sol (GS)',FmtVitesse(T.Gs));
 AfficherComposantes('Vent sur la route',Vt,Route);
 AfficherTemps(T.Gs);
End;

Procedure CmdCap(Cap,Tas:Real;Var Vt:TVent);
Var
 T:TTriangle;
Begin
 TriangleCap(Cap,Tas,Vt,T);
 WriteLn('Triangle des vents : route suivie');
 WriteLn('---------------------------------');
 Ligne('Cap vrai',FmtCapMag(Cap));
 Ligne('Vitesse propre (TAS)',FmtVitesse(Tas));
 AfficherVent(Vt);
 WriteLn;
 If Not T.Ok Then Begin
  WriteLn('Vitesse sol nulle : l''avion fait du sur-place.');
  Halt(2);
 End;
 Ligne('Route suivie',FmtAngle(T.Route)+' vrai');
 Ligne('Derive',FmtCote(T.Derive,'vers la droite','vers la gauche'));
 Ligne('Vitesse sol (GS)',FmtVitesse(T.Gs));
 AfficherComposantes('Vent sur la route',Vt,T.Route);
 AfficherTemps(T.Gs);
End;

Procedure CmdMesure(Cap,Tas,Route,Gs:Real);
Var
 Vt:TVent;
Begin
 TrouverVent(Cap,Tas,Route,Gs,Vt);
 WriteLn('Triangle des vents : vent mesure');
 WriteLn('--------------------------------');
 Ligne('Cap vrai',FmtAngle(Cap));
 Ligne('Vitesse propre (TAS)',FmtVitesse(Tas));
 Ligne('Route suivie',FmtAngle(Route));
 Ligne('Vitesse sol (GS)',FmtVitesse(Gs));
 WriteLn;
 If Vt.Vit<0.5 Then Ligne('Vent','calme (moins de 1 kt)')
  Else Begin
   AfficherVent(Vt);
   Ligne('Direction vers laquelle','il souffle : '+FmtAngle(Cap360(Vt.Dir+180.0)));
   Ligne('Derive',FmtCote(Ecart(Route-Cap),'vers la droite','vers la gauche'));
   AfficherComposantes('Vent sur la route',Vt,Route);
  End;
End;

Procedure CmdPiste(Var Vt:TVent;Var Pistes:TPisteList;N:Integer);
Var
 K,Meilleure:Integer;
 Cap,Face,Travers,Rf,Rt,MeilleurF,MeilleurT:Real;
 Rafale:TVent;
 Txt,Flag:String;
Begin
 WriteLn('Composantes du vent par piste');
 WriteLn('-----------------------------');
 AfficherVent(Vt);
 If HasRaf Then Ligne('Rafales',FmtVitesse(Rafales));
 If HasLim Then Ligne('Limite de vent de travers',FmtVitesse(Limite));
 WriteLn;
 WriteLn(Pad('Piste',8),Pad('Cap',9),Pad('Face / arriere',22),Pad('Travers',24),'Remarque');
 Meilleure:=0;
 MeilleurF:=-1E9;
 MeilleurT:=1E9;
 For K:=0 to N-1 do Begin
  If Not LirePiste(Pistes[K],Cap)Then Erreur('Piste invalide : '+Pistes[K]+' (numero 1 a 36 ou cap)');
  Composantes(Vt,Cap,Face,Travers);
  If Face>=0 Then Txt:=Fmt(Face,0)+' kt de face' Else Txt:=Fmt(-Face,0)+' kt arriere';
  Write(Pad(Pistes[K],8),Pad(FmtAngle(Cap),9),Pad(Txt,22));
  If Travers>=0 Then Txt:=Fmt(Travers,0)+' kt de la droite' Else Txt:=Fmt(-Travers,0)+' kt de la gauche';
  Write(Pad(Txt,24));
  Flag:='';
  If HasRaf Then Begin
   Rafale.Dir:=Vt.Dir;
   Rafale.Vit:=Rafales;
   Composantes(Rafale,Cap,Rf,Rt);
   If Rf>=0 Then Flag:='rafales : '+Fmt(Rf,0)+' kt de face' Else Flag:='rafales : '+Fmt(-Rf,0)+' kt arriere';
   Flag:=Flag+', '+Fmt(Abs(Rt),0)+' kt de travers';
  End;
  If HasLim and(Abs(Travers)>Limite)Then Flag:=Flag+' LIMITE DEPASSEE';
  WriteLn(Flag);
  If(Not(HasLim and(Abs(Travers)>Limite)))and
    ((Face>MeilleurF+0.5)or((Abs(Face-MeilleurF)<=0.5)and(Abs(Travers)<MeilleurT)))Then Begin
   Meilleure:=K+1;
   MeilleurF:=Face;
   MeilleurT:=Abs(Travers);
  End;
 End;
 WriteLn;
 If Meilleure>0 Then Begin
  LirePiste(Pistes[Meilleure-1],Cap);
  Composantes(Vt,Cap,Face,Travers);
  WriteLn('Piste conseillee : ',Pistes[Meilleure-1],' (',FmtAngle(Cap),'), ',
          Fmt(Face,0),' kt de face, ',Fmt(Abs(Travers),0),' kt de travers');
 End
  Else WriteLn('Aucune piste dans les limites de vent de travers indiquees.');
End;

Procedure AfficherAide;Begin
 WriteLn('VENT : Cette commande permet de resoudre le triangle des vents ',
         '(cap a tenir, derive,');
 WriteLn('       vitesse sol, vent mesure et composantes du vent sur les pistes).');
 WriteLn;
 WriteLn('Syntaxe : VENT ROUTE route tas dir vit [options]');
 WriteLn('          VENT CAP cap tas dir vit [options]');
 WriteLn('          VENT MESURE cap tas route gs [options]');
 WriteLn('          VENT PISTE dir vit piste1 [piste2 ...] [options]');
 WriteLn;
 WriteLn(' route   Route vraie desiree (degres, 0 a 360)');
 WriteLn(' cap     Cap vrai de l''avion (degres)');
 WriteLn(' tas     Vitesse propre de l''avion (noeuds)');
 WriteLn(' dir     Direction d''ou vient le vent (degres)');
 WriteLn(' vit     Vitesse du vent (noeuds)');
 WriteLn(' gs      Vitesse sol mesuree (noeuds)');
 WriteLn(' piste   Numero de piste (09, 27L, 4...) ou cap en degres');
 WriteLn;
 WriteLn('Options :');
 WriteLn(' /VAR:deg      Declinaison magnetique, est positive : /VAR:14W ou /VAR:-14');
 WriteLn(' /DEV:deg      Deviation du compas, est positive, comme /VAR');
 WriteLn(' /DIST:NM      Distance a parcourir, pour calculer la duree (ROUTE et CAP)');
 WriteLn(' /RAF:kt       Vitesse des rafales (PISTE)');
 WriteLn(' /LIM:kt       Limite de vent de travers de l''avion (PISTE)');
 WriteLn(' /KMH /MS /MPH Unite des vitesses saisies (noeuds par defaut)');
 WriteLn;
 WriteLn('Les directions sont en degres vrais, sauf si toutes les valeurs sont magnetiques');
 WriteLn('(n''utilisez pas /VAR dans ce cas). Le vent d''un METAR est en degres vrais.');
 WriteLn;
 WriteLn('Code de sortie : 0 = Ok, 1 = erreur, 2 = route impossible');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn(' VENT ROUTE 090 120 360 25 /VAR:10W /DIST:200');
 WriteLn(' VENT CAP 270 450 300 60');
 WriteLn(' VENT MESURE 090 120 095 105');
 WriteLn(' VENT PISTE 240 18 09 27 04L 22R /RAF:30 /LIM:20');
End;

Function ParseAngle(S:String;Var V:Real):Boolean;
Var
 Neg:Boolean;
Begin
 ParseAngle:=False;
 S:=StrToUpper(Trim(S));
 If S='' Then Exit;
 Neg:=False;
 If S[Length(S)]in['E','W','O']Then Begin
  Neg:=S[Length(S)]in['W','O'];
  Delete(S,Length(S),1);
 End;
 If Not EstNombre(S,V)Then Exit;
 If Neg Then V:=-V;
 ParseAngle:=Abs(V)<=180.0;
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
 If Nom='/KMH'Then Option:=Option+[_Kmh] Else
 If Nom='/MS'Then Option:=Option+[_Ms] Else
 If Nom='/MPH'Then Option:=Option+[_Mph] Else
 If Nom='/VAR'Then Begin
  If Not ParseAngle(Valeur,Variation)Then Erreur('Declinaison invalide : '+Valeur);
  HasVar:=True;
 End
  Else
 If Nom='/DEV'Then Begin
  If Not ParseAngle(Valeur,Deviation)Then Erreur('Deviation invalide : '+Valeur);
  HasDev:=True;
 End
  Else
 If Nom='/DIST'Then Begin
  Distance:=ParseReal(Valeur,'la distance');
  If Distance<=0 Then Erreur('La distance doit etre positive');
  HasDist:=True;
 End
  Else
 If Nom='/RAF'Then Begin
  Rafales:=ParseReal(Valeur,'les rafales');
  HasRaf:=True;
 End
  Else
 If Nom='/LIM'Then Begin
  Limite:=ParseReal(Valeur,'la limite');
  HasLim:=True;
 End
  Else Erreur('Option inconnue : '+Param);
End;

Function LireAngleArg(Idx:Integer;Nom:String):Real;
Var
 V:Real;
Begin
 V:=ParseReal(Arg[Idx],Nom);
 If(V<0)or(V>360)Then Erreur(Nom+' doit etre entre 0 et 360 degres');
 LireAngleArg:=V;
End;

Function LireVitesseArg(Idx:Integer;Nom:String):Real;
Var
 V:Real;
Begin
 V:=VitesseEnKt(ParseReal(Arg[Idx],Nom));
 If V<0 Then Erreur(Nom+' doit etre positive');
 LireVitesseArg:=V;
End;

Procedure AjouterArguments(S:String);
Var
 Mot:String;
 K:Integer;
Begin
 Mot:='';
 For K:=1 to Length(S)+1 do Begin
  If(K>Length(S))or(S[K]in[' ',#9])Then Begin
   If Mot<>''Then Begin
    If NArg>=20 Then Erreur('Trop de parametres');
    Inc(NArg);
    Arg[NArg]:=Mot;
    Mot:='';
   End;
  End
   Else Mot:=Mot+S[K];
 End;
End;

Procedure Interactif;
Var
 S:String;
Begin
 WriteLn('Triangle des vents');
 WriteLn('------------------');
 WriteLn(' 1 - Cap a tenir pour une route (ROUTE)');
 WriteLn(' 2 - Route suivie pour un cap (CAP)');
 WriteLn(' 3 - Vent deduit des mesures (MESURE)');
 WriteLn(' 4 - Composantes du vent sur les pistes (PISTE)');
 Write('Choix : ');
 ReadLn(S);
 S:=Trim(S);
 If S='' Then Erreur('Choix invalide');
 Case S[1] of
  '1':Begin
   Arg[1]:='ROUTE';
   NArg:=1;
   Write('Route vraie (degres) : ');ReadLn(S);AjouterArguments(S);
   Write('Vitesse propre (kt) : ');ReadLn(S);AjouterArguments(S);
   Write('Direction du vent (degres) : ');ReadLn(S);AjouterArguments(S);
   Write('Vitesse du vent (kt) : ');ReadLn(S);AjouterArguments(S);
  End;
  '2':Begin
   Arg[1]:='CAP';
   NArg:=1;
   Write('Cap vrai (degres) : ');ReadLn(S);AjouterArguments(S);
   Write('Vitesse propre (kt) : ');ReadLn(S);AjouterArguments(S);
   Write('Direction du vent (degres) : ');ReadLn(S);AjouterArguments(S);
   Write('Vitesse du vent (kt) : ');ReadLn(S);AjouterArguments(S);
  End;
  '3':Begin
   Arg[1]:='MESURE';
   NArg:=1;
   Write('Cap vrai (degres) : ');ReadLn(S);AjouterArguments(S);
   Write('Vitesse propre (kt) : ');ReadLn(S);AjouterArguments(S);
   Write('Route suivie (degres) : ');ReadLn(S);AjouterArguments(S);
   Write('Vitesse sol (kt) : ');ReadLn(S);AjouterArguments(S);
  End;
  '4':Begin
   Arg[1]:='PISTE';
   NArg:=1;
   Write('Direction du vent (degres) : ');ReadLn(S);AjouterArguments(S);
   Write('Vitesse du vent (kt) : ');ReadLn(S);AjouterArguments(S);
   Write('Pistes (numeros ou caps, separes par des espaces) : ');ReadLn(S);AjouterArguments(S);
  End;
  Else Erreur('Choix invalide');
 End;
 WriteLn;
End;

Var
 Vt:TVent;
 Pistes:TPisteList;
 NP,K:Integer;

BEGIN
 Option:=[];
 NArg:=0;
 HasVar:=False;
 HasDev:=False;
 HasDist:=False;
 HasRaf:=False;
 HasLim:=False;
 Variation:=0;
 Deviation:=0;
 Distance:=0;
 Rafales:=0;
 Limite:=0;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  AfficherAide;
  Halt(0);
 End;
 For I:=1 to ParamCount do Begin
  Param:=ParamStr(I);
  If(Length(Param)>0)and(Param[1]='/')Then LireOption(Param)
   Else Begin
    If NArg>=20 Then Erreur('Trop de parametres');
    Inc(NArg);
    Arg[NArg]:=Param;
   End;
 End;
 Rafales:=VitesseEnKt(Rafales);
 Limite:=VitesseEnKt(Limite);
 If NArg=0 Then Interactif;
 Cmd:=StrToUpper(Arg[1]);
 If Cmd='ROUTE'Then Begin
  If NArg<>5 Then Erreur('Syntaxe : VENT ROUTE route tas dir vit');
  Vt.Dir:=LireAngleArg(4,'La direction du vent');
  Vt.Vit:=LireVitesseArg(5,'La vitesse du vent');
  If LireVitesseArg(3,'La vitesse propre')<=0 Then Erreur('La vitesse propre doit etre positive');
  CmdRoute(LireAngleArg(2,'La route'),LireVitesseArg(3,'La vitesse propre'),Vt);
 End
  Else
 If Cmd='CAP'Then Begin
  If NArg<>5 Then Erreur('Syntaxe : VENT CAP cap tas dir vit');
  Vt.Dir:=LireAngleArg(4,'La direction du vent');
  Vt.Vit:=LireVitesseArg(5,'La vitesse du vent');
  If LireVitesseArg(3,'La vitesse propre')<=0 Then Erreur('La vitesse propre doit etre positive');
  CmdCap(LireAngleArg(2,'Le cap'),LireVitesseArg(3,'La vitesse propre'),Vt);
 End
  Else
 If Cmd='MESURE'Then Begin
  If NArg<>5 Then Erreur('Syntaxe : VENT MESURE cap tas route gs');
  If LireVitesseArg(3,'La vitesse propre')<=0 Then Erreur('La vitesse propre doit etre positive');
  CmdMesure(LireAngleArg(2,'Le cap'),LireVitesseArg(3,'La vitesse propre'),
            LireAngleArg(4,'La route'),LireVitesseArg(5,'La vitesse sol'));
 End
  Else
 If Cmd='PISTE'Then Begin
  If NArg<4 Then Erreur('Syntaxe : VENT PISTE dir vit piste1 [piste2 ...]');
  Vt.Dir:=LireAngleArg(2,'La direction du vent');
  Vt.Vit:=LireVitesseArg(3,'La vitesse du vent');
  NP:=0;
  For K:=4 to NArg do Begin
   If NP>=MaxPistes Then Erreur('Trop de pistes (maximum '+Fmt(MaxPistes,0)+')');
   Pistes[NP]:=Copy(Arg[K],1,12);
   Inc(NP);
  End;
  CmdPiste(Vt,Pistes,NP);
 End
  Else Erreur('Commande inconnue : '+Arg[1]+' (ROUTE, CAP, MESURE ou PISTE)');
END.
