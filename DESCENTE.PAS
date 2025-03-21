{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program DESCENTE;

Uses Crt;

Var
 H,ROD,t:Real;
 Err:Word;

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('DESCENTE : Cette commande permet d''effectuer la simulution ',
                    'de la descente d''un avion.');
  WriteLn;
  WriteLn('Syntaxe : DESCENTE [h rod t]');
  WriteLn;
  WriteLn(' h     Ce paramŠtre permet d''indiquer l''altitude initiale (m)');
  WriteLn(' rod   Ce paramŠtre permet d''indiquer le taux de descente (m/min)');
  WriteLn(' t     Ce paramŠtre permet d''indiquer le temps de descente (min)');
 End
  Else
 If ParamCount>0 Then Begin
  Val(ParamStr(1),h,Err);
  If Err>0 Then Begin
   WriteLn('L''altitude initiale n''est pas valide');
   Halt(1);
  End;
  Val(ParamStr(2),rod,Err);
  If Err>0 Then Begin
   WriteLn('Le taux de descente n''est pas valide');
   Halt(1);
  End;
  Val(ParamStr(3),t,Err);
  If Err>0 Then Begin
   WriteLn('Le temps de descente n''est pas valide');
   Halt(1);
  End;
  H:=H-(ROD*t);
  If H<0 then H:=0;
  WriteLn('Altitude aprŠs descente : ', H:0:2, ' m');
 End
  Else
 Begin
  ClrScr;
  WriteLn('Simulation de descente d''un avion');
  WriteLn('---------------------------------');
  Write('Altitude initiale (m) : ');
  ReadLn(H);
  write('Taux de descente (m/min) : ');
  ReadLn(ROD);
  Write('Temps de descente (min) : ');
  ReadLn(t);
  H:=H-(ROD*t);
  If H<0 then H:=0;
  WriteLn('Altitude aprŠs descente : ', H:0:2, ' m');
  ReadLn;
 End;
END.