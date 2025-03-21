{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program CAS;

Uses Crt;

Const
 P0=1013.25; { Pression standard en hPa }

Var
 IAS,P,_CAS:Real;
 Err:Word;

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('CAS : Cette commande permet de calculer la vitesse ',
                 'an‚mom‚trique corrig‚e (Calibrate Airspeed).');
  WriteLn;
  WriteLn('Syntaxe : CAS [ias p]');
  WriteLn;
  WriteLn(' ias   Ce paramŠtre permet d''indiquer la vitesse indiqu‚es (IAS) en noeuds');
  WriteLn(' p     Ce paramŠtre permet d''indiquer la pression atmosph‚rique (hPa)');
 End
  Else
 If ParamCount>0 Then Begin
  Val(ParamStr(1),IAS,Err);
  If Err>0 Then Begin
   WriteLn('La vitesse indiqu‚e en noeuds n''est pas valide');
   Halt(1);
  End;
  Val(ParamStr(2),P,Err);
  If Err>0 Then Begin
   WriteLn('La pression atmosph‚rique n''est pas valide');
   Halt(1);
  End;
  _CAS:=IAS*Sqrt(P/P0);
  WriteLn('Vitesse corrig‚e (CAS) : ', _CAS:0:2, ' kt');
 End
  Else
 Begin
  ClrScr;
  Writeln('Calcul de la vitesse an‚mom‚trique corrig‚e (CAS)');
  Writeln('------------------------------------------------');
  Write('Entrez la vitesse indiqu‚e (IAS) en noeuds : ');
  Readln(IAS);
  Write('Entrez la pression atmosph‚rique (hPa) : ');
  Readln(P);
  _CAS:=IAS*Sqrt(P/P0);
  WriteLn('Vitesse corrig‚e (CAS) : ', _CAS:0:2, ' kt');
  ReadLn;
 End;
END.