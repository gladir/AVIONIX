{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program METAR;

{ Decodage des messages meteorologiques aeronautiques METAR, SPECI et TAF :
   - vent, visibilite, portee visuelle de piste (RVR), temps present, nuages,
     temperature, point de rosee, pression (QNH), tendance et remarques ;
   - resume : categorie de vol (VFR, MVFR, IFR, LIFR), plafond, humidite
     relative, altitude-pression et altitude-densite, composantes du vent
     par rapport a la piste. }

Const
 MaxTok=240;
 T0=288.15;            { Temperature ISA au niveau de la mer (K) }
 P0=1013.25;           { Pression ISA au niveau de la mer (hPa) }
 Rho0=1.225;           { Densite ISA au niveau de la mer (kg/m3) }
 RGaz=287.05287;       { Constante specifique de l'air (J/kg/K) }
 FtM=0.3048;           { Metres par pied }
 KtKmh=1.852;          { Kilometres par heure par noeud }
 InHgHpa=33.8639;      { Hectopascals par pouce de mercure }
 SmM=1609.344;         { Metres par mille terrestre }
 PiVal=3.14159265358979;
 NbVent=16;
 Rose:Array[0..15]of String[3]=('N','NNE','NE','ENE','E','ESE','SE','SSE',
                                'S','SSO','SO','OSO','O','ONO','NO','NNO');
 NbDesc=8;
 DescCode:Array[1..NbDesc]of String[2]=('MI','BC','PR','DR','BL','SH','TS','FZ');
 DescTexte:Array[1..NbDesc]of String[28]=('mince','bancs de','partiel',
  'chasse basse de','chasse haute de','averses de','orage avec','givrant');
 NbPhen=22;
 PhenCode:Array[1..NbPhen]of String[2]=('DZ','RA','SN','SG','IC','PL','GR','GS',
  'UP','BR','FG','FU','VA','DU','SA','HZ','PY','PO','SQ','FC','SS','DS');
 PhenTexte:Array[1..NbPhen]of String[40]=('bruine','pluie','neige',
  'neige en grains','cristaux de glace','granules de glace','grele',
  'gresil ou petite grele','precipitations inconnues','brume','brouillard',
  'fumee','cendres volcaniques','poussiere etendue','sable','brume seche',
  'embruns','tourbillons de sable ou de poussiere','grains',
  'tornade ou trombe','tempete de sable','tempete de poussiere');

Type
 TMeteo=Record
  Station:String[8];
  HasTemp:Boolean;
  Temp,Dew:Real;               { Celsius }
  HasQNH:Boolean;
  QNH:Real;                    { hPa }
  HasWind:Boolean;
  WDir:Integer;                { degres, -1 = variable }
  WSpd,WGust:Real;             { noeuds }
  HasVis:Boolean;
  VisM:Real;                   { metres }
  Ceiling:Real;                { pieds, -1 = pas de plafond }
 End;

Var
 Tok:Array[1..MaxTok]of String[40];
 NTok:Integer;
 M:TMeteo;
 Retrait:String;
 Zone:Integer;                 { 0 = base, 1 = tendance ou changement }
 EstTAF,HasElev,HasPiste:Boolean;
 Elevation,PisteCap:Real;
 FichierMsg:String;
 I,Debut:Integer;
 Param:String;

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

Function Chiffres(Const S:String;P,N:Integer):Boolean;
Var
 K:Integer;
Begin
 Chiffres:=False;
 If(P<1)or(P+N-1>Length(S))Then Exit;
 For K:=P to P+N-1 do If Not(S[K]in['0'..'9'])Then Exit;
 Chiffres:=True;
End;

Function Nombre(Const S:String;P,N:Integer):Integer;
Var
 V,Code:Integer;
Begin
 Val(Copy(S,P,N),V,Code);
 If Code<>0 Then V:=0;
 Nombre:=V;
End;

Function ToutChiffres(Const S:String):Boolean;Begin
 ToutChiffres:=(Length(S)>0)and Chiffres(S,1,Length(S));
End;

Function Fin(Const S,Suffixe:String):Boolean;Begin
 Fin:=(Length(S)>=Length(Suffixe))and
      (Copy(S,Length(S)-Length(Suffixe)+1,Length(Suffixe))=Suffixe);
End;

Procedure Ligne(Titre,Texte:String);Begin
 WriteLn(Retrait,Pad(Titre,22),': ',Texte);
End;

Function FmtPieds(Ft:Real):String;Begin
 FmtPieds:=Fmt(Ft,0)+' ft ('+Fmt(Ft*FtM,0)+' m)';
End;

Function NomDirection(Deg:Integer):String;Begin
 NomDirection:=Rose[(Round(Deg/22.5))mod 16];
End;

Function Puissance(X,Y:Real):Real;Begin
 Puissance:=Exp(Y*Ln(X));
End;

{ ---------------------------------------------------------------------
  Decodeurs de groupes
  --------------------------------------------------------------------- }

Function TexteHeure(S:String):String;
Var
 J,H,Mn:Integer;
Begin
 J:=Nombre(S,1,2);
 H:=Nombre(S,3,2);
 Mn:=Nombre(S,5,2);
 TexteHeure:='jour '+Fmt(J,0)+' du mois a '+Fmt(H,0)+':'+
             Copy('0'+Fmt(Mn,0),Length(Fmt(Mn,0)),2)+' UTC';
End;

Function GroupeHeure(S:String):Boolean;Begin
 GroupeHeure:=(Length(S)=7)and(S[7]='Z')and Chiffres(S,1,6)and
              (Nombre(S,1,2)>=1)and(Nombre(S,1,2)<=31)and(Nombre(S,3,2)<24)and
              (Nombre(S,5,2)<60);
End;

{ Vent : dddff[Gfff]KT|MPS|KMH }
Function DecoderVent(S:String):Boolean;
Var
 Unite:Integer;
 Corps,Dir,Vit,Raf:String;
 Fact,Spd,Gst:Real;
 Deg,P:Integer;
 Variable,Calme:Boolean;
Begin
 DecoderVent:=False;
 If Fin(S,'KMH')Then Begin Unite:=3;Corps:=Copy(S,1,Length(S)-3);End Else
 If Fin(S,'MPS')Then Begin Unite:=2;Corps:=Copy(S,1,Length(S)-3);End Else
 If Fin(S,'KT')Then Begin Unite:=1;Corps:=Copy(S,1,Length(S)-2);End
  Else Exit;
 If Length(Corps)<5 Then Exit;
 Dir:=Copy(Corps,1,3);
 Variable:=Dir='VRB';
 If Not(Variable or(Dir='///')or Chiffres(Dir,1,3))Then Exit;
 Vit:=Copy(Corps,4,255);
 Raf:='';
 P:=Pos('G',Vit);
 If P>0 Then Begin
  Raf:=Copy(Vit,P+1,255);
  Vit:=Copy(Vit,1,P-1);
 End;
 If Not(ToutChiffres(Vit)and(Length(Vit)>=2)and(Length(Vit)<=3))Then Exit;
 If(Raf<>'')and Not(ToutChiffres(Raf)and(Length(Raf)>=2)and(Length(Raf)<=3))Then Exit;
 If Unite=1 Then Fact:=1.0 Else If Unite=2 Then Fact:=1.943844 Else Fact:=0.539957;
 Spd:=Nombre(Vit,1,Length(Vit))*Fact;
 Gst:=0;
 If Raf<>''Then Gst:=Nombre(Raf,1,Length(Raf))*Fact;
 Calme:=(Spd=0)and(Dir<>'VRB');
 DecoderVent:=True;
 If Zone=0 Then Begin
  M.HasWind:=True;
  M.WSpd:=Spd;
  M.WGust:=Gst;
  If Variable Then M.WDir:=-1 Else If Dir='///'Then M.WDir:=-2 Else M.WDir:=Nombre(Dir,1,3);
 End;
 If Calme Then Ligne('Vent','calme')
  Else
 Begin
  If Variable Then Dir:='direction variable'
   Else If Dir='///'Then Dir:='direction inconnue'
   Else Begin
    Deg:=Nombre(Dir,1,3);
    Dir:='du '+Fmt(Deg,0)+' degres ('+NomDirection(Deg)+')';
   End;
  Dir:=Dir+', '+Fmt(Spd,0)+' kt ('+Fmt(Spd*KtKmh,0)+' km/h)';
  If Gst>0 Then Dir:=Dir+', rafales a '+Fmt(Gst,0)+' kt ('+Fmt(Gst*KtKmh,0)+' km/h)';
  Ligne('Vent',Dir);
 End;
End;

Function DecoderVariationVent(S:String):Boolean;Begin
 DecoderVariationVent:=(Length(S)=7)and Chiffres(S,1,3)and(S[4]='V')and
                       Chiffres(S,5,3);
 If DecoderVariationVent Then
  Ligne('Direction variable','de '+Fmt(Nombre(S,1,3),0)+' a '+
        Fmt(Nombre(S,5,3),0)+' degres');
End;

Procedure NoterVisibilite(Metres:Real);Begin
 If Zone=0 Then Begin
  M.HasVis:=True;
  M.VisM:=Metres;
 End;
End;

Function DecoderVisibiliteM(S:String):Boolean;
Var
 V:Integer;
 Suite,Txt:String;
Begin
 DecoderVisibiliteM:=False;
 If Not Chiffres(S,1,4)Then Exit;
 Suite:=Copy(S,5,255);
 If(Suite<>'')and(Suite<>'N')and(Suite<>'NE')and(Suite<>'E')and(Suite<>'SE')and
   (Suite<>'S')and(Suite<>'SW')and(Suite<>'W')and(Suite<>'NW')and(Suite<>'NDV')Then
  Exit;
 DecoderVisibiliteM:=True;
 V:=Nombre(S,1,4);
 If V>=9999 Then Txt:='10 km ou plus'
  Else If V=0 Then Txt:='moins de 50 m'
  Else If V>=1000 Then Txt:=Fmt(V/1000.0,1)+' km'
  Else Txt:=Fmt(V,0)+' m';
 If(Suite<>'')and(Suite<>'NDV')Then Txt:=Txt+' en direction '+Suite
 Else If Suite='NDV'Then Txt:=Txt+' (sans direction dominante)';
 If Suite='' Then NoterVisibilite(V);
 If Suite=''Then Ligne('Visibilite',Txt) Else Ligne('Visibilite directionnelle',Txt);
End;

{ Visibilite en milles terrestres : [M|P]nn[/nn]SM, avec Entier = partie
  entiere donnee dans le groupe precedent. }
Function DecoderVisibiliteSM(S:String;Entier:Real):Boolean;
Var
 Corps,Pref,Txt:String;
 P:Integer;
 V:Real;
Begin
 DecoderVisibiliteSM:=False;
 If Not Fin(S,'SM')Then Exit;
 Corps:=Copy(S,1,Length(S)-2);
 Pref:='';
 If(Length(Corps)>0)and(Corps[1]in['M','P'])Then Begin
  Pref:=Corps[1];
  Corps:=Copy(Corps,2,255);
 End;
 P:=Pos('/',Corps);
 If P>0 Then Begin
  If Not(Chiffres(Corps,1,P-1)and Chiffres(Corps,P+1,Length(Corps)-P))Then Exit;
  If Nombre(Corps,P+1,Length(Corps)-P)=0 Then Exit;
  V:=Nombre(Corps,1,P-1)/Nombre(Corps,P+1,Length(Corps)-P);
 End
  Else
 Begin
  If Not ToutChiffres(Corps)Then Exit;
  V:=Nombre(Corps,1,Length(Corps));
 End;
 V:=V+Entier;
 DecoderVisibiliteSM:=True;
 Txt:=Fmt(V,2)+' SM ('+Fmt(V*SmM,0)+' m)';
 If Pref='M'Then Txt:='moins de '+Txt Else If Pref='P'Then Txt:='plus de '+Txt;
 NoterVisibilite(V*SmM);
 Ligne('Visibilite',Txt);
End;

{ RVR : Rpp[L|C|R]/[M|P]vvvv[V[M|P]vvvv][FT][U|D|N] }
Function DecoderRVR(S:String):Boolean;
Var
 P,Q:Integer;
 Piste,Reste,Txt,Tend,Unite:String;
 Pre1,Pre2:String;
 V1,V2:Integer;
 Variable:Boolean;
Begin
 DecoderRVR:=False;
 If(Length(S)<8)or(S[1]<>'R')Then Exit;
 P:=Pos('/',S);
 If P<4 Then Exit;
 Piste:=Copy(S,2,P-2);
 If Not Chiffres(Piste,1,2)Then Exit;
 Reste:=Copy(S,P+1,255);
 Tend:='';
 If(Length(Reste)>0)and(Reste[Length(Reste)]in['U','D','N'])Then Begin
  Tend:=Reste[Length(Reste)];
  Reste:=Copy(Reste,1,Length(Reste)-1);
 End;
 Unite:='m';
 If Fin(Reste,'FT')Then Begin
  Unite:='ft';
  Reste:=Copy(Reste,1,Length(Reste)-2);
 End;
 Pre1:='';
 If(Length(Reste)>0)and(Reste[1]in['M','P'])Then Begin
  Pre1:=Reste[1];
  Reste:=Copy(Reste,2,255);
 End;
 If Not Chiffres(Reste,1,4)Then Exit;
 V1:=Nombre(Reste,1,4);
 Reste:=Copy(Reste,5,255);
 Variable:=False;
 V2:=0;
 Pre2:='';
 If Reste<>''Then Begin
  If Reste[1]<>'V'Then Exit;
  Reste:=Copy(Reste,2,255);
  If(Length(Reste)>0)and(Reste[1]in['M','P'])Then Begin
   Pre2:=Reste[1];
   Reste:=Copy(Reste,2,255);
  End;
  If(Length(Reste)<>4)or Not Chiffres(Reste,1,4)Then Exit;
  V2:=Nombre(Reste,1,4);
  Variable:=True;
 End;
 DecoderRVR:=True;
 Txt:=Fmt(V1,0)+' '+Unite;
 If Pre1='M'Then Txt:='moins de '+Txt Else If Pre1='P'Then Txt:='plus de '+Txt;
 If Variable Then Begin
  Txt:='de '+Txt+' a ';
  If Pre2='M'Then Txt:=Txt+'moins de ' Else If Pre2='P'Then Txt:=Txt+'plus de ';
  Txt:=Txt+Fmt(V2,0)+' '+Unite;
 End;
 If Tend='U'Then Txt:=Txt+', en augmentation' Else
 If Tend='D'Then Txt:=Txt+', en diminution' Else
 If Tend='N'Then Txt:=Txt+', sans changement';
 Ligne('RVR piste '+Piste,Txt);
End;

{ Temps present : [-|+|VC][descripteur][phenomene...] }
Function DecoderTemps(S:String):Boolean;
Var
 P,K:Integer;
 Pref,Txt,Code,Mot:String;
 Trouve,Recent,Voisin:Boolean;
Begin
 DecoderTemps:=False;
 If S='NSW'Then Begin
  DecoderTemps:=True;
  Ligne('Temps present','aucun phenomene significatif');
  Exit;
 End;
 Recent:=False;
 Voisin:=False;
 Pref:='';
 P:=1;
 If Copy(S,1,2)='RE'Then Begin
  Recent:=True;
  P:=3;
 End;
 If S[P]='-'Then Begin Pref:='faible ';Inc(P);End Else
 If S[P]='+'Then Begin Pref:='fort ';Inc(P);End Else
 If Copy(S,P,2)='VC'Then Begin Voisin:=True;Inc(P,2);End;
 If P>Length(S)Then Exit;
 Txt:='';
 While P<=Length(S)do Begin
  Code:=Copy(S,P,2);
  If Length(Code)<2 Then Exit;
  Trouve:=False;
  For K:=1 to NbDesc do If DescCode[K]=Code Then Begin
   Txt:=Txt+DescTexte[K]+' ';
   Trouve:=True;
  End;
  If Not Trouve Then
   For K:=1 to NbPhen do If PhenCode[K]=Code Then Begin
    Mot:=PhenTexte[K];
    If Mot<>''Then Txt:=Txt+Mot+' ';
    Trouve:=True;
   End;
  If Not Trouve Then Exit;
  Inc(P,2);
 End;
 DecoderTemps:=True;
 Txt:=Trim(Txt);
 If Fin(Txt,' avec')Then Delete(Txt,Length(Txt)-4,5);
 If Fin(Txt,' de')Then Delete(Txt,Length(Txt)-2,3);
 Txt:=Pref+Txt;
 If Voisin Then Txt:='au voisinage : '+Txt;
 If Recent Then Ligne('Temps recent',Trim(Txt)) Else Ligne('Temps present',Trim(Txt));
End;

Function NomNuage(Code:String):String;Begin
 If Code='FEW'Then NomNuage:='quelques nuages (1 a 2 octas)' Else
 If Code='SCT'Then NomNuage:='nuages epars (3 a 4 octas)' Else
 If Code='BKN'Then NomNuage:='nuages fragmentes (5 a 7 octas)' Else
 If Code='OVC'Then NomNuage:='ciel couvert (8 octas)'
  Else NomNuage:=Code;
End;

{ Nuages : FEW|SCT|BKN|OVC hhh [CB|TCU], VVhhh, SKC, CLR, NSC, NCD }
Function DecoderNuages(S:String):Boolean;
Var
 Code,Suite,Txt:String;
 H:Real;
Begin
 DecoderNuages:=False;
 If S='SKC'Then Begin DecoderNuages:=True;Ligne('Nuages','ciel degage');Exit;End;
 If S='CLR'Then Begin DecoderNuages:=True;
  Ligne('Nuages','aucun nuage detecte sous 12 000 ft (station automatique)');Exit;End;
 If S='NSC'Then Begin DecoderNuages:=True;
  Ligne('Nuages','aucun nuage significatif');Exit;End;
 If S='NCD'Then Begin DecoderNuages:=True;
  Ligne('Nuages','aucun nuage detecte (station automatique)');Exit;End;
 If(Copy(S,1,2)='VV')and(Length(S)=5)Then Begin
  If Chiffres(S,3,3)Then Begin
   H:=Nombre(S,3,3)*100.0;
   If Zone=0 Then If(M.Ceiling<0)or(H<M.Ceiling)Then M.Ceiling:=H;
   Ligne('Visibilite verticale',FmtPieds(H)+' (ciel obscurci)');
  End
   Else Ligne('Visibilite verticale','inconnue (ciel obscurci)');
  DecoderNuages:=True;
  Exit;
 End;
 Code:=Copy(S,1,3);
 If(Code<>'FEW')and(Code<>'SCT')and(Code<>'BKN')and(Code<>'OVC')Then Exit;
 If Length(S)<6 Then Exit;
 Suite:=Copy(S,7,255);
 If(Suite<>'')and(Suite<>'CB')and(Suite<>'TCU')and(Suite<>'///')Then Exit;
 If Chiffres(S,4,3)Then Begin
  H:=Nombre(S,4,3)*100.0;
  Txt:=NomNuage(Code)+' a '+FmtPieds(H);
  If Zone=0 Then
   If((Code='BKN')or(Code='OVC'))and((M.Ceiling<0)or(H<M.Ceiling))Then M.Ceiling:=H;
 End
  Else If Copy(S,4,3)='///'Then Txt:=NomNuage(Code)+' a hauteur inconnue'
  Else Exit;
 If Suite='CB'Then Txt:=Txt+', cumulonimbus' Else
 If Suite='TCU'Then Txt:=Txt+', cumulus bourgeonnant';
 DecoderNuages:=True;
 Ligne('Nuages',Txt);
End;

{ Temperature et point de rosee : [M]TT/[M]DD }
Function DecoderTemperature(S:String):Boolean;
Var
 P:Integer;
 T,D:Real;
 A,B,Txt:String;
 Neg:Boolean;
Begin
 DecoderTemperature:=False;
 P:=Pos('/',S);
 If(P<2)or(Length(S)>7)Then Exit;
 A:=Copy(S,1,P-1);
 B:=Copy(S,P+1,255);
 Neg:=(Length(A)>0)and(A[1]='M');
 If Neg Then A:=Copy(A,2,255);
 If Not(Chiffres(A,1,2)and(Length(A)=2))Then Exit;
 T:=Nombre(A,1,2);
 If Neg Then T:=-T;
 If B<>''Then Begin
  Neg:=B[1]='M';
  If Neg Then B:=Copy(B,2,255);
  If Not(Chiffres(B,1,2)and(Length(B)=2))Then Exit;
  D:=Nombre(B,1,2);
  If Neg Then D:=-D;
 End
  Else D:=0;
 DecoderTemperature:=True;
 If Zone=0 Then Begin
  M.HasTemp:=B<>'';
  M.Temp:=T;
  M.Dew:=D;
 End;
 Txt:=Fmt(T,0)+' C';
 If B<>''Then Txt:=Txt+', point de rosee '+Fmt(D,0)+' C'
         Else Txt:=Txt+', point de rosee non rapporte';
 Ligne('Temperature',Txt);
End;

{ Pression : Qhhhh (hPa) ou Ahhhh (centiemes de pouce de mercure) }
Function DecoderPression(S:String):Boolean;
Var
 V:Real;
Begin
 DecoderPression:=False;
 If(Length(S)<>5)Or Not Chiffres(S,2,4)Then Exit;
 If S[1]='Q'Then Begin
  V:=Nombre(S,2,4);
  If Zone=0 Then Begin M.HasQNH:=True;M.QNH:=V;End;
  Ligne('Pression (QNH)',Fmt(V,0)+' hPa ('+Fmt(V/InHgHpa,2)+' inHg)');
 End
  Else
 If S[1]='A'Then Begin
  V:=Nombre(S,2,4)/100.0;
  If Zone=0 Then Begin M.HasQNH:=True;M.QNH:=V*InHgHpa;End;
  Ligne('Pression (calage)',Fmt(V,2)+' inHg ('+Fmt(V*InHgHpa,0)+' hPa)');
 End
  Else Exit;
 DecoderPression:=True;
End;

Function DecoderPeriode(S:String;Var Txt:String):Boolean;Begin
 DecoderPeriode:=False;
 If(Length(S)=9)and(S[5]='/')and Chiffres(S,1,4)and Chiffres(S,6,4)Then Begin
  Txt:='du jour '+Fmt(Nombre(S,1,2),0)+' a '+Fmt(Nombre(S,3,2),0)+' h UTC au jour '+
       Fmt(Nombre(S,6,2),0)+' a '+Fmt(Nombre(S,8,2),0)+' h UTC';
  DecoderPeriode:=True;
 End;
End;

{ ---------------------------------------------------------------------
  Resume
  --------------------------------------------------------------------- }

Function Categorie(Var Me:TMeteo):String;
Var
 Cat:Integer;
 C:Integer;
Begin
 { 0 = VFR, 1 = MVFR, 2 = IFR, 3 = LIFR }
 Cat:=0;
 If Me.HasVis Then Begin
  If Me.VisM<1609.344 Then C:=3 Else If Me.VisM<4828.0 Then C:=2
   Else If Me.VisM<=8047.0 Then C:=1 Else C:=0;
  If C>Cat Then Cat:=C;
 End;
 If Me.Ceiling>=0 Then Begin
  If Me.Ceiling<500.0 Then C:=3 Else If Me.Ceiling<1000.0 Then C:=2
   Else If Me.Ceiling<=3000.0 Then C:=1 Else C:=0;
  If C>Cat Then Cat:=C;
 End;
 Case Cat of
  0:Categorie:='VFR (vol a vue)';
  1:Categorie:='MVFR (vol a vue marginal)';
  2:Categorie:='IFR (vol aux instruments)';
  Else Categorie:='LIFR (vol aux instruments en conditions faibles)';
 End;
End;

Function PressionSat(T:Real):Real;Begin
 PressionSat:=6.1094*Exp(17.625*T/(T+243.04));
End;

Procedure AfficherResume(Var Me:TMeteo);
Var
 Rh,Pst,Pa,Rho,Da,Ang,Head,Cross,Ratio:Real;
 Cote,CoteX:String;
Begin
 WriteLn;
 WriteLn('Resume');
 WriteLn('------');
 If Me.HasVis or(Me.Ceiling>=0)Then Ligne('Categorie de vol',Categorie(Me));
 If Me.Ceiling>=0 Then Ligne('Plafond',FmtPieds(Me.Ceiling))
  Else If Me.HasVis Then Ligne('Plafond','aucun (pas de couche fragmentee ou couverte)');
 If Me.HasTemp Then Begin
  Rh:=100.0*PressionSat(Me.Dew)/PressionSat(Me.Temp);
  If Rh>100.0 Then Rh:=100.0;
  Ligne('Humidite relative',Fmt(Rh,0)+' %');
  Ligne('Ecart temp.-rosee',Fmt(Me.Temp-Me.Dew,0)+' C');
 End;
 If Me.HasQNH and HasElev Then Begin
  Ratio:=Puissance(1.0-0.0065*Elevation*FtM/T0,5.255876);
  Pst:=Me.QNH*Ratio;
  Pa:=T0/0.0065*(1.0-Puissance(Pst/P0,1.0/5.255876));
  Ligne('Altitude-pression',FmtPieds(Pa/FtM));
  If Me.HasTemp Then Begin
   Rho:=Pst*100.0/(RGaz*(Me.Temp+273.15));
   Da:=T0/0.0065*(1.0-Puissance(Rho/Rho0,1.0/4.255876));
   Ligne('Altitude-densite',FmtPieds(Da/FtM));
  End;
 End;
 If Me.HasWind and HasPiste and(Me.WDir>=0)Then Begin
  Ang:=(Me.WDir-PisteCap)*PiVal/180.0;
  Head:=Me.WSpd*Cos(Ang);
  Cross:=Me.WSpd*Sin(Ang);
  If Head>=0 Then Cote:='de face' Else Cote:='arriere';
  If Cross>=0 Then CoteX:='droite' Else CoteX:='gauche';
  Ligne('Vent / piste '+Fmt(PisteCap,0),Fmt(Abs(Head),0)+' kt '+Cote+', travers '+
        Fmt(Abs(Cross),0)+' kt venant de la '+
        CoteX);
  If Me.WGust>0 Then Begin
   Head:=Me.WGust*Cos(Ang);
   Cross:=Me.WGust*Sin(Ang);
   Ligne('  en rafales',Fmt(Abs(Head),0)+' kt composante longitudinale, travers '+
         Fmt(Abs(Cross),0)+' kt');
  End;
 End;
End;

{ ---------------------------------------------------------------------
  Messages
  --------------------------------------------------------------------- }

Procedure Initialiser;Begin
 M.Station:='';
 M.HasTemp:=False;
 M.HasQNH:=False;
 M.HasWind:=False;
 M.HasVis:=False;
 M.Ceiling:=-1;
 M.WDir:=-1;
 Zone:=0;
 Retrait:='';
End;

Procedure Remarques(Var I:Integer;Fin_:Integer);
Var
 Txt:String;
Begin
 Txt:='';
 Inc(I);
 While I<=Fin_ do Begin
  If Length(Txt)+Length(Tok[I])<240 Then Txt:=Txt+Tok[I]+' ';
  Inc(I);
 End;
 If Txt<>''Then Ligne('Remarques (RMK)',Trim(Txt));
End;

{ Decode un message de Debut a Fin }
Procedure DecoderMessage(Debut_,Fin_:Integer);
Var
 I:Integer;
 S,Txt,Heure:String;
 Entier:Real;
 Reconnu:Boolean;
Begin
 Initialiser;
 I:=Debut_;
 EstTAF:=False;
 If Tok[I]='TAF'Then Begin
  EstTAF:=True;
  WriteLn('Prevision d''aerodrome (TAF)');
  WriteLn('----------------------------');
  Inc(I);
 End
  Else
 If(Tok[I]='METAR')or(Tok[I]='SPECI')Then Begin
  If Tok[I]='METAR'Then Begin
   WriteLn('Observation d''aerodrome (METAR)');
   WriteLn('--------------------------------');
  End
   Else
  Begin
   WriteLn('Observation speciale (SPECI)');
   WriteLn('----------------------------');
  End;
  Inc(I);
 End
  Else
 Begin
  WriteLn('Observation d''aerodrome (METAR)');
  WriteLn('--------------------------------');
 End;
 Entier:=0;
 While I<=Fin_ do Begin
  S:=Tok[I];
  Reconnu:=True;
  If(S='COR')or(S='CCA')or(S='CCB')Then Ligne('Message','corrige') Else
  If S='AMD'Then Ligne('Message','TAF amende') Else
  If S='AUTO'Then Ligne('Message','observation automatique (sans observateur)') Else
  If S='NIL'Then Ligne('Message','aucune donnee (NIL)') Else
  If S='CAVOK'Then Begin
   Ligne('CAVOK','visibilite 10 km ou plus, pas de nuage sous 5 000 ft, pas de CB ni de temps significatif');
   If Zone=0 Then Begin M.HasVis:=True;M.VisM:=10000;End;
  End
   Else
  If(M.Station='')and(Zone=0)and(Length(S)=4)and(S[1]in['A'..'Z'])and
    (S[2]in['A'..'Z'])and(S[3]in['A'..'Z'])and(S[4]in['A'..'Z','0'..'9'])Then Begin
   M.Station:=S;
   Ligne('Station',S+' (code OACI)');
  End
   Else
  If GroupeHeure(S)Then Begin
   If EstTAF Then Ligne('Emis le',TexteHeure(S)) Else Ligne('Observation du',TexteHeure(S));
  End
   Else
  If EstTAF and DecoderPeriode(S,Txt)Then Begin
   Ligne('Periode',Txt);
  End
   Else
  If S='NOSIG'Then Ligne('Tendance','aucun changement significatif prevu') Else
  If S='BECMG'Then Begin
   Zone:=1;
   Retrait:='  ';
   If EstTAF and(I<Fin_)and DecoderPeriode(Tok[I+1],Txt)Then Begin
    WriteLn('Changement progressif (BECMG) ',Txt);
    Inc(I);
   End
    Else WriteLn('Changement progressif (BECMG)');
  End
   Else
  If S='TEMPO'Then Begin
   Zone:=1;
   Retrait:='  ';
   If EstTAF and(I<Fin_)and DecoderPeriode(Tok[I+1],Txt)Then Begin
    WriteLn('Temporairement (TEMPO) ',Txt);
    Inc(I);
   End
    Else WriteLn('Temporairement (TEMPO)');
  End
   Else
  If(Copy(S,1,4)='PROB')and(Length(S)=6)and Chiffres(S,5,2)Then Begin
   Zone:=1;
   Retrait:='  ';
   WriteLn('Probabilite de ',Copy(S,5,2),' %');
  End
   Else
  If EstTAF and(Copy(S,1,2)='FM')and(Length(S)=8)and Chiffres(S,3,6)Then Begin
   Zone:=1;
   Retrait:='  ';
   WriteLn('A partir du ',TexteHeure(Copy(S,3,6)+'Z'))
  End
   Else
  If(Not EstTAF)and(Length(S)=6)and((Copy(S,1,2)='FM')or(Copy(S,1,2)='TL')or(Copy(S,1,2)='AT'))and
    Chiffres(S,3,4)Then Begin
   Ligne('Tendance',Copy(S,1,2)+' '+Copy(S,3,2)+':'+Copy(S,5,2)+' UTC')
  End
   Else
  If EstTAF and(Length(S)>=8)and(S[1]='T')and(S[2]in['X','N'])Then Begin
   Txt:=Copy(S,3,255);
   If Pos('/',Txt)>0 Then Begin
    Heure:=Copy(Txt,Pos('/',Txt)+1,255);
    If(Length(Heure)=5)and Chiffres(Heure,1,4)Then
     Heure:='le jour '+Fmt(Nombre(Heure,1,2),0)+' a '+Fmt(Nombre(Heure,3,2),0)+' h UTC';
    Txt:=Copy(Txt,1,Pos('/',Txt)-1);
    If Copy(Txt,1,1)='M'Then Txt:='-'+Copy(Txt,2,255);
    If S[2]='X'Then Ligne('Temperature maximale',Txt+' C, '+Heure)
     Else Ligne('Temperature minimale',Txt+' C, '+Heure);
   End
    Else Reconnu:=False;
  End
   Else
  If S='RMK'Then Begin
   Remarques(I,Fin_);
   Dec(I);
  End
   Else
  If DecoderVent(S)Then Else
  If DecoderVariationVent(S)Then Else
  If(Length(S)<=2)and ToutChiffres(S)and(I<Fin_)and Fin(Tok[I+1],'SM')and
    (Pos('/',Tok[I+1])>0)Then Entier:=Nombre(S,1,Length(S))
  Else
  If DecoderVisibiliteM(S)Then Else
  If DecoderVisibiliteSM(S,Entier)Then Entier:=0 Else
  If DecoderRVR(S)Then Else
  If DecoderNuages(S)Then Else
  If DecoderTemperature(S)Then Else
  If DecoderPression(S)Then Else
  If DecoderTemps(S)Then Else
  If S='WS'Then Begin
   If(I+2<=Fin_)and(Tok[I+1]='ALL')Then Begin
    Ligne('Cisaillement de vent','toutes les pistes');
    Inc(I,2);
   End
    Else
   If I+1<=Fin_ Then Begin
    Ligne('Cisaillement de vent',Tok[I+1]);
    Inc(I);
   End
    Else Ligne('Cisaillement de vent','signale');
  End
   Else
  If(Length(S)=8)and ToutChiffres(S)Then
   Ligne('Etat des pistes','groupe '+S+' (non detaille)')
  Else Reconnu:=False;
  If Not Reconnu Then Ligne('Groupe non reconnu',S);
  Inc(I);
 End;
 Retrait:='';
 If Not EstTAF Then AfficherResume(M);
End;

Procedure AfficherAide;Begin
 WriteLn('METAR : Cette commande permet de decoder un message meteorologique ',
         'aeronautique');
 WriteLn('        (METAR, SPECI ou TAF).');
 WriteLn;
 WriteLn('Syntaxe : METAR message [options]');
 WriteLn('          METAR /FICHIER:message.txt [options]');
 WriteLn;
 WriteLn(' message    Le message complet, entre guillemets ou en plusieurs mots');
 WriteLn;
 WriteLn('Options :');
 WriteLn(' /FICHIER:nom   Lit les messages dans un fichier texte');
 WriteLn(' /ELEV:ft       Altitude du terrain en pieds, pour l''altitude-pression et');
 WriteLn('                l''altitude-densite');
 WriteLn(' /ELEVM:m       Altitude du terrain en metres');
 WriteLn(' /PISTE:n       Piste (numero 1 a 36 ou cap en degres), pour les composantes');
 WriteLn('                du vent');
 WriteLn;
 WriteLn('Le programme reconnait : station, date et heure, vent (KT, MPS, KMH), visibilite');
 WriteLn('(metres ou SM), CAVOK, RVR, temps present, nuages, temperature, point de rosee,');
 WriteLn('QNH (Q ou A), tendance (NOSIG, BECMG, TEMPO), remarques et les groupes TAF');
 WriteLn('(periodes, BECMG, TEMPO, FM, PROB, TX, TN).');
 WriteLn;
 WriteLn('Code de sortie : 0 = Ok, 1 = erreur');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn(' METAR "LFPG 041030Z 24012G25KT 200V280 9999 FEW030 BKN045 15/09 Q1018 NOSIG"');
 WriteLn(' METAR "KJFK 041251Z 28016G24KT 10SM FEW250 06/M04 A3012" /ELEV:13 /PISTE:31');
 WriteLn(' METAR "LFPG 041100Z 0412/0518 24010KT 9999 SCT030 BECMG 0414/0416 BKN012"');
End;

Procedure LireOption(Param:String);
Var
 U,Nom,Valeur:String;
 P:Integer;
 V:Real;
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
 If Nom='/FICHIER'Then FichierMsg:=Valeur Else
 If Nom='/ELEV'Then Begin
  Elevation:=ParseReal(Valeur,'l''altitude du terrain');
  HasElev:=True;
 End
  Else
 If Nom='/ELEVM'Then Begin
  Elevation:=ParseReal(Valeur,'l''altitude du terrain')/FtM;
  HasElev:=True;
 End
  Else
 If Nom='/PISTE'Then Begin
  V:=ParseReal(Valeur,'la piste');
  If(V>=1)and(V<=36)Then V:=V*10.0;
  If(V<0)or(V>360)Then Erreur('La piste doit etre un numero de 1 a 36 ou un cap de 0 a 360');
  PisteCap:=V;
  HasPiste:=True;
 End
  Else Erreur('Option inconnue : '+Param);
End;

{ Ajoute les mots de la chaine S comme jetons (le signe = termine un message) }
Procedure AjouterJetons(S:String);
Var
 Mot:String;
 K:Integer;
 Egal:Boolean;

 Procedure Vider;Begin
  If Mot<>''Then Begin
   Egal:=False;
   If Mot[Length(Mot)]='='Then Begin
    Egal:=True;
    Delete(Mot,Length(Mot),1);
   End;
   If Mot<>''Then Begin
    If NTok>=MaxTok Then Erreur('Message trop long');
    Inc(NTok);
    Tok[NTok]:=StrToUpper(Copy(Mot,1,40));
   End;
   If Egal Then Begin
    If NTok>=MaxTok Then Erreur('Message trop long');
    Inc(NTok);
    Tok[NTok]:='=';
   End;
   Mot:='';
  End;
 End;

Begin
 Mot:='';
 For K:=1 to Length(S)+1 do Begin
  If(K>Length(S))or(S[K]in[' ',#9,#13,#10])Then Vider
   Else Mot:=Mot+S[K];
 End;
End;

Procedure LireFichier(Const Nom:String);
Var
 F:Text;
 L:String;
Begin
 Assign(F,Nom);
 {$I-}Reset(F);{$I+}
 If IOResult<>0 Then Erreur('Impossible de lire le fichier : '+Nom);
 While Not EOF(F)do Begin
  ReadLn(F,L);
  L:=Trim(L);
  If(L<>'')and(L[1]<>'#')Then AjouterJetons(L);
 End;
 Close(F);
End;

Function TousSlash(Const S:String):Boolean;
Var
 K:Integer;
Begin
 TousSlash:=Length(S)>0;
 For K:=1 to Length(S)do If S[K]<>'/'Then TousSlash:=False;
End;

BEGIN
 NTok:=0;
 HasElev:=False;
 HasPiste:=False;
 Elevation:=0;
 PisteCap:=0;
 FichierMsg:='';
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  AfficherAide;
  Halt(0);
 End;
 For I:=1 to ParamCount do Begin
  Param:=ParamStr(I);
  If(Length(Param)>0)and(Param[1]='/')and Not TousSlash(Param)Then LireOption(Param)
   Else AjouterJetons(Param);
 End;
 If FichierMsg<>''Then LireFichier(FichierMsg);
 If NTok=0 Then Begin
  WriteLn('Decodage d''un message METAR, SPECI ou TAF');
  WriteLn('------------------------------------------');
  WriteLn('Entrez le message (ligne vide pour terminer) :');
  Repeat
   Write('> ');
   Param:='';
   If Not EOF Then ReadLn(Param);
   AjouterJetons(Param);
  Until Trim(Param)='';
  WriteLn;
 End;
 If NTok=0 Then Erreur('Aucun message a decoder');
 { Decoupe en messages : debut sur METAR, SPECI ou TAF, fin sur = }
 Debut:=1;
 I:=1;
 While I<=NTok do Begin
  If Tok[I]='='Then Begin
   If I>Debut Then Begin
    DecoderMessage(Debut,I-1);
    WriteLn;
   End;
   Debut:=I+1;
  End
   Else
  If(I>Debut)and((Tok[I]='METAR')or(Tok[I]='SPECI')or(Tok[I]='TAF'))Then Begin
   DecoderMessage(Debut,I-1);
   WriteLn;
   Debut:=I;
  End;
  Inc(I);
 End;
 If Debut<=NTok Then DecoderMessage(Debut,NTok);
END.
