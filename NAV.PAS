{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program NAV;

{ Navigation sur la sphere terrestre :
   - distance et caps du grand cercle (orthodromie) entre deux points, caps
     vrai et magnetique, point milieu, latitude maximale, points
     intermediaires, comparaison avec la route a cap constant (loxodromie) ;
   - route a plusieurs segments avec distance totale ;
   - point d'arrivee a partir d'un depart, d'un cap et d'une distance ;
   - correction de vent (cap a tenir, vitesse sol, duree) avec la vitesse
     propre de l'avion. }

Const
 MaxArg=40;
 NbAero=92;
 RayonNm=3440.065;     { Rayon moyen de la Terre en milles marins }
 NmKm=1.852;           { Kilometres par mille marin }
 MiKm=1.609344;        { Kilometres par mille terrestre }
 PiVal=3.14159265358979;
 Rad=PiVal/180.0;

Type
 TAero=Record
  Icao:String[4];
  Nom,Alt:String[16];
  Lat,Lon:Real;
 End;

 TPos=Record
  Nom:String[40];
  Lat,Lon:Real;                { degres decimaux, nord et est positifs }
 End;

 TPosList=Array[0..MaxArg]of TPos;

 TLeg=Record
  Dist:Real;                   { distance du grand cercle (NM) }
  CapIni,CapFin:Real;          { caps vrais initial et final (degres) }
  HasVertex:Boolean;           { le sommet du grand cercle est sur le segment }
  LatMax:Real;                 { latitude du sommet }
  RhumbDist,RhumbCap:Real;     { loxodromie }
 End;

 TVent=Record
  Tas:Real;                    { vitesse propre (kt), 0 = non donnee }
  Dir,Vit:Real;                { vent : provenance (degres) et vitesse (kt) }
  HasVent:Boolean;
 End;

 TVol=Record
  Cap:Real;                    { cap vrai a tenir }
  Derive:Real;                 { angle de correction de derive }
  Gs:Real;                     { vitesse sol }
  Ok:Boolean;
 End;

Const
 Aero:Array[1..NbAero]of TAero=(
  (Icao:'LFPG';Nom:'Paris';Alt:'Paris CDG';Lat:49.0097;Lon:2.5479),
  (Icao:'LFPO';Nom:'Orly';Alt:'Paris Orly';Lat:48.7233;Lon:2.3794),
  (Icao:'EGLL';Nom:'Londres';Alt:'London';Lat:51.4700;Lon:-0.4543),
  (Icao:'EDDF';Nom:'Francfort';Alt:'Frankfurt';Lat:50.0333;Lon:8.5706),
  (Icao:'EDDM';Nom:'Munich';Alt:'Munich';Lat:48.3538;Lon:11.7861),
  (Icao:'EDDB';Nom:'Berlin';Alt:'Berlin';Lat:52.3667;Lon:13.5033),
  (Icao:'EHAM';Nom:'Amsterdam';Alt:'Amsterdam';Lat:52.3086;Lon:4.7639),
  (Icao:'LEMD';Nom:'Madrid';Alt:'Madrid';Lat:40.4936;Lon:-3.5668),
  (Icao:'LEBL';Nom:'Barcelone';Alt:'Barcelona';Lat:41.2971;Lon:2.0785),
  (Icao:'LIRF';Nom:'Rome';Alt:'Rome';Lat:41.8003;Lon:12.2389),
  (Icao:'LIMC';Nom:'Milan';Alt:'Milan';Lat:45.6306;Lon:8.7281),
  (Icao:'LSZH';Nom:'Zurich';Alt:'Zurich';Lat:47.4647;Lon:8.5492),
  (Icao:'LSGG';Nom:'Geneve';Alt:'Geneva';Lat:46.2381;Lon:6.1089),
  (Icao:'LFLL';Nom:'Lyon';Alt:'Lyon';Lat:45.7256;Lon:5.0811),
  (Icao:'LFML';Nom:'Marseille';Alt:'Marseille';Lat:43.4393;Lon:5.2214),
  (Icao:'LFBO';Nom:'Toulouse';Alt:'Toulouse';Lat:43.6291;Lon:1.3638),
  (Icao:'LFMN';Nom:'Nice';Alt:'Nice';Lat:43.6584;Lon:7.2159),
  (Icao:'UUEE';Nom:'Moscou';Alt:'Moscow';Lat:55.9726;Lon:37.4146),
  (Icao:'LTFM';Nom:'Istanbul';Alt:'Istanbul';Lat:41.2753;Lon:28.7519),
  (Icao:'LGAV';Nom:'Athenes';Alt:'Athens';Lat:37.9364;Lon:23.9445),
  (Icao:'EKCH';Nom:'Copenhague';Alt:'Copenhagen';Lat:55.6180;Lon:12.6508),
  (Icao:'ESSA';Nom:'Stockholm';Alt:'Stockholm';Lat:59.6519;Lon:17.9186),
  (Icao:'ENGM';Nom:'Oslo';Alt:'Oslo';Lat:60.1939;Lon:11.1004),
  (Icao:'EFHK';Nom:'Helsinki';Alt:'Helsinki';Lat:60.3172;Lon:24.9633),
  (Icao:'EIDW';Nom:'Dublin';Alt:'Dublin';Lat:53.4213;Lon:-6.2701),
  (Icao:'LPPT';Nom:'Lisbonne';Alt:'Lisbon';Lat:38.7813;Lon:-9.1359),
  (Icao:'LOWW';Nom:'Vienne';Alt:'Vienna';Lat:48.1103;Lon:16.5697),
  (Icao:'EPWA';Nom:'Varsovie';Alt:'Warsaw';Lat:52.1657;Lon:20.9671),
  (Icao:'LKPR';Nom:'Prague';Alt:'Prague';Lat:50.1008;Lon:14.2600),
  (Icao:'BIKF';Nom:'Reykjavik';Alt:'Keflavik';Lat:63.9850;Lon:-22.6056),
  (Icao:'OMDB';Nom:'Dubai';Alt:'Dubai';Lat:25.2528;Lon:55.3644),
  (Icao:'OTHH';Nom:'Doha';Alt:'Doha';Lat:25.2731;Lon:51.6081),
  (Icao:'OEJN';Nom:'Djeddah';Alt:'Jeddah';Lat:21.6796;Lon:39.1565),
  (Icao:'OIIE';Nom:'Teheran';Alt:'Tehran';Lat:35.4161;Lon:51.1522),
  (Icao:'ORBI';Nom:'Bagdad';Alt:'Baghdad';Lat:33.2625;Lon:44.2346),
  (Icao:'VIDP';Nom:'Delhi';Alt:'Delhi';Lat:28.5562;Lon:77.1000),
  (Icao:'VABB';Nom:'Mumbai';Alt:'Bombay';Lat:19.0887;Lon:72.8679),
  (Icao:'VHHH';Nom:'Hong Kong';Alt:'Hong Kong';Lat:22.3089;Lon:113.9146),
  (Icao:'ZBAA';Nom:'Pekin';Alt:'Beijing';Lat:40.0801;Lon:116.5846),
  (Icao:'ZSPD';Nom:'Shanghai';Alt:'Shanghai';Lat:31.1434;Lon:121.8053),
  (Icao:'RJTT';Nom:'Tokyo';Alt:'Haneda';Lat:35.5533;Lon:139.7811),
  (Icao:'RJAA';Nom:'Narita';Alt:'Tokyo Narita';Lat:35.7647;Lon:140.3864),
  (Icao:'RKSI';Nom:'Seoul';Alt:'Seoul';Lat:37.4691;Lon:126.4505),
  (Icao:'WSSS';Nom:'Singapour';Alt:'Singapore';Lat:1.3502;Lon:103.9944),
  (Icao:'WIII';Nom:'Jakarta';Alt:'Jakarta';Lat:6.1256;Lon:106.6559),
  (Icao:'VTBS';Nom:'Bangkok';Alt:'Bangkok';Lat:13.6900;Lon:100.7501),
  (Icao:'RPLL';Nom:'Manille';Alt:'Manila';Lat:14.5086;Lon:121.0194),
  (Icao:'YSSY';Nom:'Sydney';Alt:'Sydney';Lat:-33.9461;Lon:151.1772),
  (Icao:'YMML';Nom:'Melbourne';Alt:'Melbourne';Lat:-37.6733;Lon:144.8433),
  (Icao:'NZAA';Nom:'Auckland';Alt:'Auckland';Lat:-37.0082;Lon:174.7850),
  (Icao:'PHNL';Nom:'Honolulu';Alt:'Honolulu';Lat:21.3187;Lon:-157.9225),
  (Icao:'PANC';Nom:'Anchorage';Alt:'Anchorage';Lat:61.1744;Lon:-149.9964),
  (Icao:'KJFK';Nom:'New York';Alt:'JFK';Lat:40.6398;Lon:-73.7789),
  (Icao:'KLAX';Nom:'Los Angeles';Alt:'Los Angeles';Lat:33.9425;Lon:-118.4081),
  (Icao:'KORD';Nom:'Chicago';Alt:'Chicago';Lat:41.9786;Lon:-87.9048),
  (Icao:'KATL';Nom:'Atlanta';Alt:'Atlanta';Lat:33.6367;Lon:-84.4281),
  (Icao:'KDFW';Nom:'Dallas';Alt:'Dallas';Lat:32.8998;Lon:-97.0403),
  (Icao:'KIAH';Nom:'Houston';Alt:'Houston';Lat:29.9844;Lon:-95.3414),
  (Icao:'KSFO';Nom:'San Francisco';Alt:'San Francisco';Lat:37.6190;Lon:-122.3750),
  (Icao:'KMIA';Nom:'Miami';Alt:'Miami';Lat:25.7932;Lon:-80.2906),
  (Icao:'KBOS';Nom:'Boston';Alt:'Boston';Lat:42.3643;Lon:-71.0052),
  (Icao:'KIAD';Nom:'Washington';Alt:'Washington';Lat:38.9445;Lon:-77.4558),
  (Icao:'KSEA';Nom:'Seattle';Alt:'Seattle';Lat:47.4502;Lon:-122.3088),
  (Icao:'KDEN';Nom:'Denver';Alt:'Denver';Lat:39.8561;Lon:-104.6737),
  (Icao:'KPHX';Nom:'Phoenix';Alt:'Phoenix';Lat:33.4343;Lon:-112.0116),
  (Icao:'KLAS';Nom:'Las Vegas';Alt:'Las Vegas';Lat:36.0840;Lon:-115.1537),
  (Icao:'CYUL';Nom:'Montreal';Alt:'Montreal';Lat:45.4706;Lon:-73.7408),
  (Icao:'CYMX';Nom:'Mirabel';Alt:'Mirabel';Lat:45.6795;Lon:-74.0387),
  (Icao:'CYYZ';Nom:'Toronto';Alt:'Toronto';Lat:43.6772;Lon:-79.6306),
  (Icao:'CYVR';Nom:'Vancouver';Alt:'Vancouver';Lat:49.1947;Lon:-123.1839),
  (Icao:'CYOW';Nom:'Ottawa';Alt:'Ottawa';Lat:45.3225;Lon:-75.6692),
  (Icao:'CYQB';Nom:'Quebec';Alt:'Quebec';Lat:46.7911;Lon:-71.3933),
  (Icao:'CYYC';Nom:'Calgary';Alt:'Calgary';Lat:51.1139;Lon:-114.0200),
  (Icao:'CYEG';Nom:'Edmonton';Alt:'Edmonton';Lat:53.3097;Lon:-113.5797),
  (Icao:'CYWG';Nom:'Winnipeg';Alt:'Winnipeg';Lat:49.9100;Lon:-97.2399),
  (Icao:'CYHZ';Nom:'Halifax';Alt:'Halifax';Lat:44.8808;Lon:-63.5086),
  (Icao:'CYQX';Nom:'Gander';Alt:'Gander';Lat:48.9369;Lon:-54.5681),
  (Icao:'CYYT';Nom:'Saint-Jean';Alt:'St. Johns';Lat:47.6186;Lon:-52.7519),
  (Icao:'CYGP';Nom:'Gaspe';Alt:'Gaspe';Lat:48.7753;Lon:-64.4786),
  (Icao:'CYBG';Nom:'Bagotville';Alt:'Saguenay';Lat:48.3306;Lon:-70.9964),
  (Icao:'CYSC';Nom:'Sherbrooke';Alt:'Sherbrooke';Lat:45.4386;Lon:-71.6914),
  (Icao:'MMMX';Nom:'Mexico';Alt:'Mexico City';Lat:19.4363;Lon:-99.0721),
  (Icao:'SKBO';Nom:'Bogota';Alt:'Bogota';Lat:4.7016;Lon:-74.1469),
  (Icao:'SBGR';Nom:'Sao Paulo';Alt:'Sao Paulo';Lat:-23.4356;Lon:-46.4731),
  (Icao:'SAEZ';Nom:'Buenos Aires';Alt:'Buenos Aires';Lat:-34.8222;Lon:-58.5358),
  (Icao:'SCEL';Nom:'Santiago';Alt:'Santiago';Lat:-33.3930;Lon:-70.7858),
  (Icao:'FAOR';Nom:'Johannesburg';Alt:'Johannesburg';Lat:-26.1392;Lon:28.2460),
  (Icao:'HECA';Nom:'Le Caire';Alt:'Cairo';Lat:30.1219;Lon:31.4056),
  (Icao:'DNMM';Nom:'Lagos';Alt:'Lagos';Lat:6.5774;Lon:3.3211),
  (Icao:'HKJK';Nom:'Nairobi';Alt:'Nairobi';Lat:-1.3192;Lon:36.9278),
  (Icao:'GMMN';Nom:'Casablanca';Alt:'Casablanca';Lat:33.3675;Lon:-7.5898),
  (Icao:'DAAG';Nom:'Alger';Alt:'Algiers';Lat:36.6910;Lon:3.2154)
 );

Var
 Arg:Array[1..MaxArg]of String[40];
 NArg:Integer;
 I:Integer;
 Param,Cmd:String;
 Vent:TVent;
 Variation:Real;
 HasVar,EnKm,EnMi:Boolean;
 NbPoints:Integer;

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

{ ---------------------------------------------------------------------
  Trigonometrie
  --------------------------------------------------------------------- }

Function Tan(X:Real):Real;Begin
 Tan:=Sin(X)/Cos(X);
End;

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

Function ArcCos(X:Real):Real;Begin
 ArcCos:=PiVal/2.0-ArcSin(X);
End;

Function Cap360(X:Real):Real;Begin
 While X<0 Do X:=X+360.0;
 While X>=360.0 Do X:=X-360.0;
 Cap360:=X;
End;

{ ---------------------------------------------------------------------
  Lecture des points
  --------------------------------------------------------------------- }

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

{ Angle en degres decimaux ou deg:min[:sec], avec lettre d'hemisphere
  facultative (N, S, E, W ou O). Retourne False si invalide. }
Function ParseAngle(S:String;Lat:Boolean;Var V:Real):Boolean;
Var
 Neg:Boolean;
 P,K:Integer;
 Part:Array[1..3]of Real;
 Nb:Integer;
 T:String;
 Lim:Real;
Begin
 ParseAngle:=False;
 S:=StrToUpper(Trim(S));
 Neg:=False;
 If S='' Then Exit;
 If S[Length(S)]in['N','S','E','W','O']Then Begin
  If Lat and Not(S[Length(S)]in['N','S'])Then Exit;
  If Not Lat and(S[Length(S)]in['N','S'])Then Exit;
  Neg:=S[Length(S)]in['S','W','O'];
  Delete(S,Length(S),1);
 End;
 If(Length(S)>0)and(S[1]in['-','+'])Then Begin
  If S[1]='-'Then Neg:=Not Neg;
  Delete(S,1,1);
 End;
 Nb:=0;
 T:='';
 For K:=1 to Length(S)+1 do Begin
  If(K>Length(S))or(S[K]=':')Then Begin
   If Nb>=3 Then Exit;
   Inc(Nb);
   If Not EstNombre(T,Part[Nb])Then Exit;
   If Part[Nb]<0 Then Exit;
   T:='';
  End
   Else T:=T+S[K];
 End;
 V:=Part[1];
 If Nb>=2 Then V:=V+Part[2]/60.0;
 If Nb>=3 Then V:=V+Part[3]/3600.0;
 If Neg Then V:=-V;
 If Lat Then Lim:=90.0 Else Lim:=180.0;
 If Abs(V)>Lim Then Exit;
 ParseAngle:=True;
End;

Function NomAero(Var A:TAero):String;Begin
 NomAero:=A.Nom+' ('+A.Icao+')';
End;

{ Recherche par code OACI ou par nom (exact, puis debut de nom unique). }
Function ChercherAero(Const S:String;Var P:TPos):Boolean;
Var
 K,N,Trouve:Integer;
 U:String;
Begin
 ChercherAero:=False;
 U:=StrToUpper(Trim(S));
 If U='' Then Exit;
 For K:=1 to NbAero do Begin
  If(U=Aero[K].Icao)or(U=StrToUpper(Aero[K].Nom))or(U=StrToUpper(Aero[K].Alt))Then Begin
   P.Nom:=NomAero(Aero[K]);
   P.Lat:=Aero[K].Lat;
   P.Lon:=Aero[K].Lon;
   ChercherAero:=True;
   Exit;
  End;
 End;
 If Length(U)<3 Then Exit;
 N:=0;
 Trouve:=0;
 For K:=1 to NbAero do Begin
  If(Copy(StrToUpper(Aero[K].Nom),1,Length(U))=U)or
    (Copy(StrToUpper(Aero[K].Alt),1,Length(U))=U)Then Begin
   Inc(N);
   Trouve:=K;
  End;
 End;
 If N=1 Then Begin
  P.Nom:=NomAero(Aero[Trouve]);
  P.Lat:=Aero[Trouve].Lat;
  P.Lon:=Aero[Trouve].Lon;
  ChercherAero:=True;
 End
  Else
 If N>1 Then Erreur('Nom ambigu : '+S+' (voir NAV LISTE)');
End;

Function CommenceParChiffre(Const S:String):Boolean;Begin
 CommenceParChiffre:=(Length(S)>0)and(S[1]in['0'..'9','-','+','.']);
End;

{ Lit un point a partir de Arg[Idx] : un nom d'aerodrome, un code OACI ou
  une latitude suivie d'une longitude (ou lat/lon dans un seul argument).
  Idx avance du nombre d'arguments consommes. }
Procedure LirePoint(Var Idx:Integer;Var P:TPos);
Var
 S,A,B:String;
 Q:Integer;
Begin
 If Idx>NArg Then Erreur('Point manquant');
 S:=Arg[Idx];
 If Not CommenceParChiffre(S)and ChercherAero(S,P)Then Begin
  Inc(Idx);
  Exit;
 End;
 Q:=Pos('/',S);
 If Q>0 Then Begin
  A:=Copy(S,1,Q-1);
  B:=Copy(S,Q+1,255);
  Inc(Idx);
 End
  Else
 Begin
  If Not CommenceParChiffre(S)Then Erreur('Point inconnu : '+S+' (nom, code OACI ou latitude longitude)');
  If Idx+1>NArg Then Erreur('Longitude manquante apres la latitude '+S);
  A:=S;
  B:=Arg[Idx+1];
  Inc(Idx,2);
 End;
 If Not ParseAngle(A,True,P.Lat)Then Erreur('Latitude invalide : '+A);
 If Not ParseAngle(B,False,P.Lon)Then Erreur('Longitude invalide : '+B);
 P.Nom:='';
End;

Function FmtLat(V:Real):String;
Var
 Mn:Real;
 D:Integer;
 H:String;
Begin
 If V<0 Then H:='S' Else H:='N';
 V:=Abs(V);
 D:=Trunc(V);
 Mn:=(V-D)*60.0;
 FmtLat:=Fmt(D,0)+' '+Fmt(Mn,2)+''''+H+' ('+Fmt(V,4)+')';
End;

Function FmtLon(V:Real):String;
Var
 Mn:Real;
 D:Integer;
 H:String;
Begin
 If V<0 Then H:='W' Else H:='E';
 V:=Abs(V);
 D:=Trunc(V);
 Mn:=(V-D)*60.0;
 FmtLon:=Fmt(D,0)+' '+Fmt(Mn,2)+''''+H+' ('+Fmt(V,4)+')';
End;

Function FmtPos(Var P:TPos):String;Begin
 FmtPos:=FmtLat(P.Lat)+'  '+FmtLon(P.Lon);
End;

Function FmtDist(Nm:Real):String;Begin
 FmtDist:=Fmt(Nm,1)+' NM ('+Fmt(Nm*NmKm,1)+' km, '+Fmt(Nm*NmKm/MiKm,1)+' mi)';
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

{ Distance, caps et loxodromie entre A et B }
Procedure CalculerSegment(Var A,B:TPos;Var Lg:TLeg);
Var
 P1,P2,L1,L2,DP,DL,H,Delta,X,Y,Dpsi,Q,Lim:Real;
 Ret:Real;
Begin
 P1:=A.Lat*Rad;
 P2:=B.Lat*Rad;
 L1:=A.Lon*Rad;
 L2:=B.Lon*Rad;
 DP:=P2-P1;
 DL:=L2-L1;
 H:=Sqr(Sin(DP/2.0))+Cos(P1)*Cos(P2)*Sqr(Sin(DL/2.0));
 If H>1.0 Then H:=1.0;
 Delta:=2.0*Atan2(Sqrt(H),Sqrt(1.0-H));
 Lg.Dist:=Delta*RayonNm;
 Y:=Sin(DL)*Cos(P2);
 X:=Cos(P1)*Sin(P2)-Sin(P1)*Cos(P2)*Cos(DL);
 Lg.CapIni:=Cap360(Atan2(Y,X)/Rad);
 Y:=Sin(-DL)*Cos(P1);
 X:=Cos(P2)*Sin(P1)-Sin(P2)*Cos(P1)*Cos(-DL);
 Lg.CapFin:=Cap360(Atan2(Y,X)/Rad+180.0);
 { Sommet du grand cercle }
 Lg.HasVertex:=False;
 Lg.LatMax:=0;
 If Cos(Lg.CapIni*Rad)*Cos(Lg.CapFin*Rad)<0 Then Begin
  Lg.HasVertex:=True;
  Lg.LatMax:=ArcCos(Abs(Sin(Lg.CapIni*Rad)*Cos(P1)))/Rad;
  If Cos(Lg.CapIni*Rad)<0 Then Lg.LatMax:=-Lg.LatMax;
 End;
 { Loxodromie }
 If DL>PiVal Then DL:=DL-2.0*PiVal Else If DL<-PiVal Then DL:=DL+2.0*PiVal;
 If(Abs(P1)>=PiVal/2.0-1E-9)or(Abs(P2)>=PiVal/2.0-1E-9)Then Begin
  Lg.RhumbDist:=Lg.Dist;
  Lg.RhumbCap:=Lg.CapIni;
 End
  Else
 Begin
  Dpsi:=Ln(Tan(PiVal/4.0+P2/2.0)/Tan(PiVal/4.0+P1/2.0));
  If Abs(Dpsi)>1E-12 Then Q:=DP/Dpsi Else Q:=Cos(P1);
  Lg.RhumbDist:=Sqrt(DP*DP+Q*Q*DL*DL)*RayonNm;
  Lg.RhumbCap:=Cap360(Atan2(DL,Dpsi)/Rad);
 End;
End;

{ Point du grand cercle a la fraction F de la distance }
Procedure PointIntermediaire(Var A,B:TPos;Delta,F:Real;Var R:TPos);
Var
 P1,P2,L1,L2,Ka,Kb,X,Y,Z:Real;
Begin
 P1:=A.Lat*Rad;
 P2:=B.Lat*Rad;
 L1:=A.Lon*Rad;
 L2:=B.Lon*Rad;
 If Delta<1E-9 Then Begin
  R:=A;
  Exit;
 End;
 Ka:=Sin((1.0-F)*Delta)/Sin(Delta);
 Kb:=Sin(F*Delta)/Sin(Delta);
 X:=Ka*Cos(P1)*Cos(L1)+Kb*Cos(P2)*Cos(L2);
 Y:=Ka*Cos(P1)*Sin(L1)+Kb*Cos(P2)*Sin(L2);
 Z:=Ka*Sin(P1)+Kb*Sin(P2);
 R.Lat:=Atan2(Z,Sqrt(X*X+Y*Y))/Rad;
 R.Lon:=Atan2(Y,X)/Rad;
 R.Nom:='';
End;

{ Point d'arrivee depuis A, avec un cap vrai et une distance (NM) }
Procedure PointDestination(Var A:TPos;Cap,DistNm:Real;Var R:TPos);
Var
 P1,L1,Th,Dl,P2,L2:Real;
Begin
 P1:=A.Lat*Rad;
 L1:=A.Lon*Rad;
 Th:=Cap*Rad;
 Dl:=DistNm/RayonNm;
 P2:=ArcSin(Sin(P1)*Cos(Dl)+Cos(P1)*Sin(Dl)*Cos(Th));
 L2:=L1+Atan2(Sin(Th)*Sin(Dl)*Cos(P1),Cos(Dl)-Sin(P1)*Sin(P2));
 R.Lat:=P2/Rad;
 R.Lon:=L2/Rad;
 While R.Lon>180.0 Do R.Lon:=R.Lon-360.0;
 While R.Lon<-180.0 Do R.Lon:=R.Lon+360.0;
 R.Nom:='';
End;

{ Triangle des vents : cap vrai a tenir, derive et vitesse sol pour suivre la
  route vraie Route avec la vitesse propre Tas. }
Procedure CorrigerVent(Var Vt:TVent;Route:Real;Var Vol:TVol);
Var
 S:Real;
Begin
 Vol.Ok:=False;
 If Vt.Tas<=0 Then Exit;
 If Not Vt.HasVent Then Begin
  Vol.Cap:=Route;
  Vol.Derive:=0;
  Vol.Gs:=Vt.Tas;
  Vol.Ok:=True;
  Exit;
 End;
 S:=Vt.Vit*Sin((Vt.Dir-Route)*Rad)/Vt.Tas;
 If Abs(S)>=1.0 Then Exit;
 Vol.Derive:=ArcSin(S)/Rad;
 Vol.Cap:=Cap360(Route+Vol.Derive);
 Vol.Gs:=Vt.Tas*Cos(Vol.Derive*Rad)-Vt.Vit*Cos((Vt.Dir-Route)*Rad);
 If Vol.Gs<=0 Then Exit;
 Vol.Ok:=True;
End;

Function FmtCap(C:Real):String;
Var
 R:Integer;
 S:String;
Begin
 R:=Round(C)mod 360;
 S:=Fmt(R,0);
 While Length(S)<3 Do S:='0'+S;
 FmtCap:=S+' deg';
End;

Function FmtCapMag(Vrai:Real):String;Begin
 If HasVar Then FmtCapMag:=FmtCap(Vrai)+' vrai, '+FmtCap(Cap360(Vrai-Variation))+' magnetique'
           Else FmtCapMag:=FmtCap(Vrai)+' vrai';
End;

{ ---------------------------------------------------------------------
  Commandes
  --------------------------------------------------------------------- }

Procedure AfficherVol(Var Lg:TLeg);
Var
 Vol:TVol;
Begin
 If Vent.Tas<=0 Then Exit;
 CorrigerVent(Vent,Lg.CapIni,Vol);
 WriteLn;
 If Vent.HasVent Then
  WriteLn('Avec un vent de ',Fmt(Vent.Dir,0),' deg a ',Fmt(Vent.Vit,0),' kt et une vitesse propre de ',
          Fmt(Vent.Tas,0),' kt')
 Else WriteLn('Sans vent, vitesse propre de ',Fmt(Vent.Tas,0),' kt');
 If Not Vol.Ok Then Begin
  WriteLn('  Route impossible : le vent est trop fort pour tenir cette route.');
  Exit;
 End;
 WriteLn('  Cap a tenir au depart      : ',FmtCapMag(Vol.Cap),' (derive ',
         Fmt(Vol.Derive,1),' deg)');
 WriteLn('  Vitesse sol                : ',Fmt(Vol.Gs,0),' kt (',Fmt(Vol.Gs*NmKm,0),' km/h)');
 WriteLn('  Duree estimee              : ',FmtDuree(Lg.Dist/Vol.Gs),
         ' (vent et cap supposes constants)');
End;

Procedure CmdItineraire(Var A,B:TPos);
Var
 Lg:TLeg;
 Mid,Pt:TPos;
 Delta:Real;
 K:Integer;
Begin
 CalculerSegment(A,B,Lg);
 WriteLn('Navigation : grand cercle');
 WriteLn('-------------------------');
 If A.Nom<>''Then WriteLn('Depart              : ',A.Nom);
 If A.Nom<>''Then WriteLn('                      ',FmtPos(A))
             Else WriteLn('Depart              : ',FmtPos(A));
 If B.Nom<>''Then WriteLn('Arrivee             : ',B.Nom);
 If B.Nom<>''Then WriteLn('                      ',FmtPos(B))
             Else WriteLn('Arrivee             : ',FmtPos(B));
 WriteLn;
 If Lg.Dist<0.001 Then Begin
  WriteLn('Les deux points sont identiques.');
  Exit;
 End;
 WriteLn('Distance            : ',FmtDist(Lg.Dist));
 WriteLn('Cap initial         : ',FmtCapMag(Lg.CapIni));
 WriteLn('Cap final           : ',FmtCapMag(Lg.CapFin));
 Delta:=Lg.Dist/RayonNm;
 PointIntermediaire(A,B,Delta,0.5,Mid);
 WriteLn('Point milieu        : ',FmtPos(Mid));
 If Lg.HasVertex Then Begin
  If Lg.LatMax>=0 Then WriteLn('Latitude maximale   : ',FmtLat(Lg.LatMax))
                  Else WriteLn('Latitude minimale   : ',FmtLat(Lg.LatMax));
 End;
 WriteLn;
 WriteLn('Route a cap constant (loxodromie)');
 WriteLn('  Distance          : ',FmtDist(Lg.RhumbDist),', ',
         Fmt(Lg.RhumbDist-Lg.Dist,1),' NM de plus');
 WriteLn('  Cap               : ',FmtCapMag(Lg.RhumbCap));
 AfficherVol(Lg);
 If NbPoints>0 Then Begin
  WriteLn;
  WriteLn('Points intermediaires');
  WriteLn(Pad('#',4),Pad('Latitude',24),Pad('Longitude',24),'Cap vers l''arrivee');
  For K:=1 to NbPoints do Begin
   PointIntermediaire(A,B,Delta,K/(NbPoints+1),Pt);
   CalculerSegment(Pt,B,Lg);
   WriteLn(Pad(Fmt(K,0),4),Pad(FmtLat(Pt.Lat),24),Pad(FmtLon(Pt.Lon),24),
           FmtCap(Lg.CapIni));
  End;
 End;
End;

Procedure CmdRoute(Var Pts:TPosList;N:Integer);
Var
 K:Integer;
 Lg:TLeg;
 Vol:TVol;
 Total,Duree:Real;
 AvecTemps:Boolean;
Begin
 WriteLn('Navigation : route');
 WriteLn('------------------');
 Total:=0;
 Duree:=0;
 AvecTemps:=Vent.Tas>0;
 Write(Pad('Segment',9),Pad('Depart / arrivee',36),PadGauche('Dist (NM)',10),
       PadGauche('Cap ini',9),PadGauche('Cap fin',9));
 If AvecTemps Then Write(PadGauche('Cap a tenir',13),PadGauche('GS (kt)',9),PadGauche('Duree',11));
 WriteLn;
 For K:=1 to N-1 do Begin
  CalculerSegment(Pts[K-1],Pts[K],Lg);
  Total:=Total+Lg.Dist;
  Write(Pad(Fmt(K,0),9));
  Write(Pad(Copy(Pts[K-1].Nom,1,16)+' > '+Copy(Pts[K].Nom,1,16),36));
  Write(PadGauche(Fmt(Lg.Dist,1),10),PadGauche(FmtCap(Lg.CapIni),9),
        PadGauche(FmtCap(Lg.CapFin),9));
  If AvecTemps Then Begin
   CorrigerVent(Vent,Lg.CapIni,Vol);
   If Vol.Ok Then Begin
    Duree:=Duree+Lg.Dist/Vol.Gs;
    Write(PadGauche(FmtCap(Vol.Cap),13),PadGauche(Fmt(Vol.Gs,0),9),
          PadGauche(FmtDuree(Lg.Dist/Vol.Gs),11));
   End
    Else Write(PadGauche('impossible',13));
  End;
  WriteLn;
 End;
 WriteLn;
 WriteLn('Distance totale     : ',FmtDist(Total));
 If AvecTemps Then WriteLn('Duree totale        : ',FmtDuree(Duree));
End;

Procedure CmdDest(Var A:TPos;Cap,Dist:Real);
Var
 R:TPos;
 Lg:TLeg;
Begin
 PointDestination(A,Cap,Dist,R);
 CalculerSegment(A,R,Lg);
 WriteLn('Point d''arrivee a partir d''un cap et d''une distance');
 WriteLn('--------------------------------------------------');
 If A.Nom<>''Then WriteLn('Depart     : ',A.Nom);
 WriteLn('Position   : ',FmtPos(A));
 WriteLn('Cap vrai   : ',FmtCap(Cap),' (au depart)');
 WriteLn('Distance   : ',FmtDist(Dist));
 WriteLn;
 WriteLn('Arrivee    : ',FmtPos(R));
 WriteLn('Cap final  : ',FmtCap(Lg.CapFin));
End;

Procedure CmdListe(Const Filtre:String);
Var
 K,N:Integer;
 F:String;
Begin
 F:=StrToUpper(Filtre);
 N:=0;
 WriteLn(Pad('OACI',6),Pad('Nom',18),Pad('Nom (alternatif)',18),PadGauche('Latitude',10),
         PadGauche('Longitude',11));
 For K:=1 to NbAero do Begin
  If(F='')or(Pos(F,StrToUpper(Aero[K].Icao))>0)or(Pos(F,StrToUpper(Aero[K].Nom))>0)or
    (Pos(F,StrToUpper(Aero[K].Alt))>0)Then Begin
   WriteLn(Pad(Aero[K].Icao,6),Pad(Aero[K].Nom,18),Pad(Aero[K].Alt,18),
           PadGauche(Fmt(Aero[K].Lat,4),10),PadGauche(Fmt(Aero[K].Lon,4),11));
   Inc(N);
  End;
 End;
 WriteLn;
 WriteLn(N,' aerodrome(s)');
End;

Procedure AfficherAide;Begin
 WriteLn('NAV : Cette commande permet de calculer la distance et les caps du grand ',
         'cercle entre');
 WriteLn('      deux points, une route a plusieurs segments ou un point d''arrivee.');
 WriteLn;
 WriteLn('Syntaxe : NAV depart arrivee [options]');
 WriteLn('          NAV ROUTE point1 point2 point3 ... [options]');
 WriteLn('          NAV DEST depart cap distance [options]');
 WriteLn('          NAV LISTE [filtre]');
 WriteLn;
 WriteLn(' point      Un nom d''aerodrome ou de ville, un code OACI (LFPG, CYUL...) ou');
 WriteLn('            une latitude suivie d''une longitude : 48.85 2.35, 48.85N 2.35E,');
 WriteLn('            48:51:00N 02:21:00E, 45.5 -73.6, ou lat/lon en un seul argument');
 WriteLn(' cap        Cap vrai de depart en degres (0 a 360)');
 WriteLn(' distance   Distance en milles marins (/KM ou /MI pour changer l''unite)');
 WriteLn;
 WriteLn('Options :');
 WriteLn(' /VAR:deg        Declinaison magnetique, est positive : /VAR:14W ou /VAR:-14');
 WriteLn(' /TAS:kt         Vitesse propre en noeuds (duree du vol)');
 WriteLn(' /VENT:dir/kt    Vent (provenance en degres / vitesse en noeuds), avec /TAS');
 WriteLn(' /POINTS:n       Affiche n points intermediaires du grand cercle');
 WriteLn(' /KM /MI         Distance de NAV DEST en kilometres ou en milles terrestres');
 WriteLn;
 WriteLn('Code de sortie : 0 = Ok, 1 = erreur');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn(' NAV Paris Montreal /VAR:15W /TAS:480 /VENT:270/40 /POINTS:3');
 WriteLn(' NAV CYUL LFPG');
 WriteLn(' NAV 48.85N 2.35E 40.64N 73.78W');
 WriteLn(' NAV ROUTE Montreal Gander Reykjavik Londres /TAS:450');
 WriteLn(' NAV DEST Paris 270 1000');
 WriteLn(' NAV LISTE can');
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
 If Nom='/KM'Then EnKm:=True Else
 If Nom='/MI'Then EnMi:=True Else
 If Nom='/VAR'Then Begin
  If Not ParseAngle(Valeur,False,Variation)Then Erreur('Declinaison invalide : '+Valeur);
  HasVar:=True;
 End
  Else
 If Nom='/TAS'Then Begin
  Vent.Tas:=ParseReal(Valeur,'la vitesse propre');
  If Vent.Tas<=0 Then Erreur('La vitesse propre doit etre positive');
 End
  Else
 If Nom='/VENT'Then Begin
  P:=Pos('/',Valeur);
  If P=0 Then Erreur('Syntaxe de l''option : /VENT:direction/vitesse');
  Vent.Dir:=ParseReal(Copy(Valeur,1,P-1),'la direction du vent');
  Vent.Vit:=ParseReal(Copy(Valeur,P+1,255),'la vitesse du vent');
  If(Vent.Dir<0)or(Vent.Dir>360)or(Vent.Vit<0)Then Erreur('Vent invalide : '+Valeur);
  Vent.HasVent:=True;
 End
  Else
 If Nom='/POINTS'Then Begin
  V:=ParseReal(Valeur,'le nombre de points');
  If(V<0)or(V>50)Then Erreur('Le nombre de points doit etre entre 0 et 50');
  NbPoints:=Trunc(V);
 End
  Else Erreur('Option inconnue : '+Param);
End;

Procedure AjouterArguments(S:String);
Var
 Mot:String;
 K:Integer;
Begin
 Mot:='';
 For K:=1 to Length(S)+1 do Begin
  If(K>Length(S))or(S[K]=' ')Then Begin
   If Mot<>''Then Begin
    If NArg>=MaxArg Then Erreur('Trop de parametres');
    Inc(NArg);
    Arg[NArg]:=Copy(Mot,1,40);
    Mot:='';
   End;
  End
   Else Mot:=Mot+S[K];
 End;
End;

Procedure AjouterReponse(S:String);
Var
 P:TPos;
Begin
 S:=Trim(S);
 If(S<>'')and Not CommenceParChiffre(S)and ChercherAero(S,P)Then Begin
  If NArg>=MaxArg Then Erreur('Trop de parametres');
  Inc(NArg);
  Arg[NArg]:=Copy(S,1,40);
 End
  Else AjouterArguments(S);
End;

Var
 A,B:TPos;
 Idx,NPts:Integer;
 Pts:TPosList;
 Cap,Dist:Real;
 S:String;

BEGIN
 NArg:=0;
 NbPoints:=0;
 HasVar:=False;
 Variation:=0;
 EnKm:=False;
 EnMi:=False;
 Vent.Tas:=0;
 Vent.Dir:=0;
 Vent.Vit:=0;
 Vent.HasVent:=False;
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
   If NArg>=MaxArg Then Erreur('Trop de parametres');
   Inc(NArg);
   Arg[NArg]:=Copy(Param,1,40);
  End;
 End;
 If NArg=0 Then Begin
  WriteLn('Navigation : grand cercle et cap');
  WriteLn('--------------------------------');
  WriteLn('Un point est un nom, un code OACI ou "latitude longitude".');
  Write('Depart : ');
  ReadLn(S);
  AjouterReponse(S);
  Write('Arrivee : ');
  ReadLn(S);
  AjouterReponse(S);
  WriteLn;
 End;
 Cmd:=StrToUpper(Arg[1]);
 If Cmd='LISTE'Then Begin
  If NArg>=2 Then CmdListe(Arg[2]) Else CmdListe('');
 End
  Else
 If Cmd='DEST'Then Begin
  If NArg<4 Then Erreur('Syntaxe : NAV DEST depart cap distance');
  Idx:=2;
  LirePoint(Idx,A);
  If Idx+1<>NArg Then Erreur('Syntaxe : NAV DEST depart cap distance');
  Cap:=ParseReal(Arg[Idx],'le cap');
  If(Cap<0)or(Cap>360)Then Erreur('Le cap doit etre entre 0 et 360');
  Dist:=ParseReal(Arg[Idx+1],'la distance');
  If Dist<0 Then Erreur('La distance doit etre positive');
  If EnKm Then Dist:=Dist/NmKm Else If EnMi Then Dist:=Dist*MiKm/NmKm;
  CmdDest(A,Cap,Dist);
 End
  Else
 If Cmd='ROUTE'Then Begin
  Idx:=2;
  NPts:=0;
  While Idx<=NArg do Begin
   LirePoint(Idx,Pts[NPts]);
   Inc(NPts);
  End;
  If NPts<2 Then Erreur('Une route demande au moins deux points');
  CmdRoute(Pts,NPts);
 End
  Else
 Begin
  Idx:=1;
  LirePoint(Idx,A);
  LirePoint(Idx,B);
  If Idx<=NArg Then Erreur('Trop de parametres : '+Arg[Idx]);
  CmdItineraire(A,B);
 End;
END.
