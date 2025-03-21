{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program TRAJECT;

Uses Crt;

Var
 x,y,vx,vy,t,dt:Real;
 i,n:Integer;
 Err:Word;

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('TRAJECT : Cette commande permet de simulation de la ',
                    'trajectoire d''un avion.');
  WriteLn;
  WriteLn('Syntaxe : TRAJECT [x y vx vy t dt]');
  WriteLn;
  WriteLn(' x     Ce paramŠtre permet d''indiquer la position initiale x (m)');
  WriteLn(' y     Ce paramŠtre permet d''indiquer la position initiale y (m)');
  WriteLn(' vx    Ce paramŠtre permet d''indiquer la vitesse en X (m/s)');
  WriteLn(' vy    Ce paramŠtre permet d''indiquer la vitesse en Y (m/s)');
  WriteLn(' t     Ce paramŠtre permet d''indiquer la dur‚e totale de simulation');
  WriteLn(' dt    Ce paramŠtre permet d''indiquer l''intervalle de temps (s)');
 End
  Else
 If ParamCount>0 Then Begin
  Val(ParamStr(1),x,Err);
  If Err>0 Then Begin
   WriteLn('La position initiale x n''est pas valide');
   Halt(1);
  End;
  Val(ParamStr(2),y,Err);
  If Err>0 Then Begin
   WriteLn('La position initiale y n''est pas valide');
   Halt(1);
  End;
  Val(ParamStr(3),vx,Err);
  If Err>0 Then Begin
   WriteLn('La vitesse en X n''est pas valide');
   Halt(1);
  End;
  Val(ParamStr(4),vy,Err);
  If Err>0 Then Begin
   WriteLn('La vitesse en Y n''est pas valide');
   Halt(1);
  End;
  Val(ParamStr(5),t,Err);
  If Err>0 Then Begin
   WriteLn('La dur‚e totale de simulation n''est pas valide');
   Halt(1);
  End;
  Val(ParamStr(6),dt,Err);
  If Err>0 Then Begin
   WriteLn('L''intervalle de temps n''est pas valide');
   Halt(1);
  End;
  n:=Round(t/dt);
  Writeln('Temps (s)   Position X (m)   Position Y (m)');
  Writeln('-------------------------------------------');
  For i:=0 to n do Begin
   WriteLn(i*dt:5:1, '        ', x:8:2, '        ', y:8:2);
   x:=x+vx*dt;
   y:=y+vy*dt;
  End;
 End
  Else
 Begin
  ClrScr;
  WriteLn('Simulation de la trajectoire d''un avion');
  WriteLn('--------------------------------------');

  Write('Position initiale X (m) : ');
  ReadLn(x);
  Write('Position initiale Y (m) : ');
  ReadLn(y);
  Write('Vitesse en X (m/s) : ');
  ReadLn(vx);
  Write('Vitesse en Y (m/s) : ');
  ReadLn(vy);
  Write('Dur‚e totale de simulation (s) : ');
  ReadLn(t);
  Write('Intervalle de temps (s) : ');
  ReadLn(dt);
  n:=Round(t/dt);
  Writeln('Temps (s)   Position X (m)   Position Y (m)');
  Writeln('-------------------------------------------');
  For i:=0 to n do Begin
   WriteLn(i*dt:5:1, '        ', x:8:2, '        ', y:8:2);
   x:=x+vx*dt;
   y:=y+vy*dt;
  End;
  ReadLn;
 End;
END.