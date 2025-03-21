{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program ISA;

Uses Crt;

Const
 P0=1013.25; { Pression au niveau de la mer (hPa) }
 H0=44330.0; { Facteur de conversion }

Var
 P,H:Real;
 Err:Word;

Function Power(Base,Exponent:Real):Real;Begin
 Power:=Exp(Exponent*Ln(Base));
End;

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('ISA : Cette commande permet de calculer l''altitude de pression (ISA).');
  WriteLn;
  WriteLn('Syntaxe : ISA [p]');
  WriteLn;
  WriteLn(' p    Ce paramŠtre permet d''indiquer la pression atmosph‚rique (hPa)');
 End
  Else
 If ParamCount>0 Then Begin
  Val(ParamStr(1),P,Err);
  If Err>0 Then Begin
   WriteLn('La pression atmosph‚rique n''est pas valide');
   Halt(1);
  End;
  H:=H0*(1 - Power(P / P0, 0.1903));
  Writeln('Altitude de pression estim‚e : ', H:0:2, ' m');
 End
  Else
 Begin
  Clrscr;
  WriteLn('Calcul de l''altitude de pression (ISA)');
  writeLn('-------------------------------------');
  Write('Entrez la pression atmosph‚rique (hPa) : ');
  ReadLn(P);
  H:=H0*(1 - Power(P / P0, 0.1903));
  Writeln('Altitude de pression estim‚e : ', H:0:2, ' m');
  ReadLn;
 End;
END.
