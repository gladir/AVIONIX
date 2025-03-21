{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program MACH;

Uses Crt;

Const
 VitesseSon=340.29; { Vitesse du son … 15øC au niveau de la mer (m/s) }

Var
 IsKmh:Boolean;
 I:Integer;
 V,_Mach:Real;
 Err:Word;

Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('MACH : Cette commande permet de calculer la vitesse d''un avion.');
  WriteLn;
  WriteLn('Syntaxe : MACH [v]');
  WriteLn;
  WriteLn(' v     Ce paramŠtre permet d''indiquer la vitesse de l''avion en m/s');
  WriteLn(' /KMH  Ce paramŠtre permet d''indiquer que la vitesse est en km/h');
 End
  Else
 If ParamCount>0 Then Begin
  IsKmh:=False;
  For I:=1 to ParamCount do Begin
   If StrToUpper(ParamStr(I))='/KMH'Then IsKmh:=True
    Else
   Begin
    Val(ParamStr(I),V,Err);
    If Err>0 Then Begin
     WriteLn('La vitesse de l''avion n''est pas valide');
     Halt(1);
    End;
   End;
  End;
  If(IsKmh)Then V:=V/3.6;
  _Mach:=V/VitesseSon;
  Writeln('Nombre de Mach : ',_Mach:0:2);
 End
  Else
 Begin
  ClrScr;
  Writeln('Calcul du nombre de Mach');
  Writeln('-----------------------');
  Write('Entrez la vitesse de l''avion en m/s : ');
  ReadLn(V);
  _Mach:=V/VitesseSon;
  Writeln('Nombre de Mach : ',_Mach:0:2);
  ReadLn;
 End;
END.