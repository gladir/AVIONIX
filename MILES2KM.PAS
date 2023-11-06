{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2022
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program Miles2KM;

Var
 Miles:Real;
 Err:Word;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('MILES2KM : Cette commande permet de convertir des miles en Km.');
  WriteLn;
  WriteLn('Syntaxe : MILES2KM [km]');
 End
  Else
 If ParamCount=1Then Begin
  Val(ParamStr(1),Miles,Err);
  If Err>0Then Begin
   WriteLn('Valeur Miles invalide');
   Halt;
  End;
  WriteLn(Miles*1.609344:1:4);
 End
  Else
 WriteLn('Nombre de paramätres invalide');
END.
