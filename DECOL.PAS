{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program DECOL;

Uses Crt;

Var
 Vr,a,d:Real;
 Err:Word;

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('DECOL : Cette commande permet d''effectuer l''estimation de ',
                  'la distance de d‚collage.');
  WriteLn;
  WriteLn('Syntaxe : DECOL [Vr a]');
  WriteLn;
  WriteLn(' Vr    Ce paramŠtre permet d''indiquer la vitesse de rotation (m/s)');
  WriteLn(' y     Ce paramŠtre permet d''indiquer l''acc‚l‚ration (m/s)ý');
 End
  Else
 If ParamCount>0 Then Begin
  Val(ParamStr(1),Vr,Err);
  If Err>0 Then Begin
   WriteLn('La vitesse de rotation n''est pas valide');
   Halt(1);
  End;
  Val(ParamStr(2),a,Err);
  If Err>0 Then Begin
   WriteLn('L''acc‚l‚ration n''est pas valide');
   Halt(1);
  End;
  d:=(Vr*Vr)/(2*a);
  Writeln('Distance estim‚e pour le d‚collage : ', d:0:2, ' m');
 End
  Else
 Begin
  ClrScr;
  Writeln('Estimation de la distance de d‚collage');
  Writeln('-------------------------------------');
  Write('Vitesse de rotation (m/s) : ');
  ReadLn(Vr);
  Write('Acc‚l‚ration (m/sý) : ');
  ReadLn(a);
  d:=(Vr*Vr)/(2*a);
  Writeln('Distance estim‚e pour le d‚collage : ', d:0:2, ' m');
  ReadLn;
 End;
END.