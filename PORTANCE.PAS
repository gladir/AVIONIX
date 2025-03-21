{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program PORTANCE;

Uses Crt;

Var
 rho,V,S,CL,L:Real;
 Err:Word;

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('PORTANCE : Cette commande permet de calculer la portance ',
                    'des ailes d''un avion.');
  WriteLn;
  WriteLn('Syntaxe : PORTANCE [rho V S CL]');
  WriteLn;
  WriteLn(' rho   Ce paramŠtre permet d''indiquer la densit‚ de l''air');
  WriteLn(' V     Ce paramŠtre permet d''indiquer la vitesse de l''air');
  WriteLn(' S     Ce paramŠtre permet d''indiquer la surface de l''aile');
  WriteLn(' CL    Ce paramŠtre permet d''indiquer la coefficient de portance');
 End
  Else
 If ParamCount>0 Then Begin
  Val(ParamStr(1),rho,Err);
  If Err>0 Then Begin
   WriteLn('La densit‚ de l''air n''est pas valide');
   Halt(1);
  End;
  Val(ParamStr(2),V,Err);
  If Err>0 Then Begin
   WriteLn('La vitesse de l''air n''est pas valide');
   Halt(1);
  End;
  Val(ParamStr(3),S,Err);
  If Err>0 Then Begin
   WriteLn('La surface l''aile n''est pas valide');
   Halt(1);
  End;
  Val(ParamStr(4),CL,Err);
  If Err>0 Then Begin
   WriteLn('Le coefficient de portance n''est pas valide');
   Halt(1);
  End;
  L:=0.5 * rho * V * V * S * CL;
  Writeln('Portance g‚n‚r‚e : ', L:0:2, ' Newtons');
 End
  Else
 Begin
  ClrScr;
  Writeln('Calcul de la portance d''une aile');
  Writeln('--------------------------------');
  Write('Densit‚ de l''air (kg/m3, ex: 1.225) : ');
  ReadLn(rho);
  Write('Vitesse de l''air (m/s) : ');
  ReadLn(V);
  Write('Surface de l''aile (mý) : ');
  ReadLn(S);
  Write('Coefficient de portance : ');
  ReadLn(CL);
  L:=0.5 * rho * V * V * S * CL;
  Writeln('Portance g‚n‚r‚e : ', L:0:2, ' Newtons');
  ReadLn;
 End;
END.