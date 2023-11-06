{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2022
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program KM2Miles;

Var
 Km:Real;
 Err:Word;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('KM2MILES : Cette commande permet de convertir des Km en miles.');
  WriteLn;
  WriteLn('Syntaxe : KM2MILES [km]');
 End
  Else
 If ParamCount=1Then Begin
  Val(ParamStr(1),Km,Err);
  If Err>0Then Begin
   WriteLn('Valeur Km invalide');
   Halt;
  End;
  WriteLn(Km*0.6213711922:1:4);
 End
  Else
 WriteLn('Nombre de paramätres invalide');
END.