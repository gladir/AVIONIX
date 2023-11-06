{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2022
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program FindPln;

Uses Strings;

Const
 PlaneList:Array[0..26]of PChar=(
  'Airbus A380','Boeing 247','Boeing 307','Boeing 707','Boeing 717',
  'Boeing 727','Boeing 737','Boeing 737 MAX','Boeing 747',
  'Boeing 757','Boeing 767','CRJ-100ER','CRJ-100LR','CRJ-200ER',
  'CRJ-200LR','CRJ-700','CRJ-900','CRJ-1000','Concorde','DH.83',
  'DH.84','DH.86','F-18','Falcon 2000','Falcon 5X','Falcon 7X',
  'Falcon 8X'
 );

Var
 LineNumber:LongInt;
 Option:Set of (_Lines);
 BeginWord,I,J:Integer;
 FoundMultiWord:Boolean;
 SourceFile:Text;
 FileName,CurrLine,CurrWord:String;

Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Function IsLetter(Chr:Char):Boolean;Begin
 IsLetter:=Chr in ['A'..'Z','a'..'z','‚','ˆ','Š','…','ƒ','“','‡'];
End;

Procedure CompileWord;
Var
 I:Integer;
Begin
 For I:=Low(PlaneList) to High(PlaneList) do Begin
  If StrToUpper(StrPas(PlaneList[I]))=StrToUpper(CurrWord)Then Begin
   If FileName<>''Then Begin
    If(_Lines in Option)Then Begin
     WriteLn('Avion trouve dans la ligne numero ',LineNumber,' :');
    End;
   End;
   WriteLn(StrPas(PlaneList[I]));
   Exit;
  End;
 End;
End;

Procedure ParseLineDetectPlane;
Var
 J:Integer;
Begin
 CurrWord:='';
 BeginWord:=1;
 For I:=1 to Length(CurrLine)do Begin
  If(IsLetter(CurrLine[I]))Then CurrWord:=CurrWord+CurrLine[I]
   Else
  Begin
   FoundMultiWord:=False;
   For J:=Low(PlaneList) to High(PlaneList) do Begin
    If(StrLen(PlaneList[J])>Length(CurrWord))and
      (StrToUpper(StrPas(PlaneList[J]))=
      StrToUpper(Copy(CurrLine,BeginWord,StrLen(PlaneList[J]))))Then Begin
     FoundMultiWord:=True;
     Break;
    End;
   End;
   If(FoundMultiWord)Then Begin
    CurrWord:=CurrWord+CurrLine[I]
   End
    Else
   Begin
    CompileWord;
    CurrWord:='';
    BeginWord:=I+1;
   End;
  End;
 End;
 CompileWord;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('FINDPLN : Cette commande permet de detecter les avions ',
                      'mentionne dans un texte.');
  WriteLn;
  WriteLn('Syntaxe : FINDPLN "message"');
  WriteLn('          FINDPLN /FILE:fichier [/LINES]');
  WriteLn;
  WriteLn(' /FILE:  Ce parametre permet d''indiquer le fichier a analyser');
  WriteLn(' /LINES  Ce parametre permet d''afficher le numero de ligne');
 End
  Else
 Begin
  Option:=[];
  LineNumber:=0;
  FileName:='';
  CurrLine:='';
  For I:=1 to ParamCount do Begin
   If StrToUpper(ParamStr(I))='/LINES'Then Include(Option,_Lines);
   If StrToUpper(Copy(ParamStr(I),1,6))='/FILE:'Then Begin
    FileName:=Copy(ParamStr(I),7,255);
   End
    Else
   Begin
    If CurrLine=''Then CurrLine:=ParamStr(I)
                  Else CurrLine:=CurrLine+' '+ParamStr(I);
   End;
  End;
  If FileName<>''Then Begin
    Assign(SourceFile,FileName);
    Reset(SourceFile);
    While Not EOF(SourceFile)do Begin
     Inc(LineNumber);
     ReadLn(SourceFile,CurrLine);
     ParseLineDetectPlane;
    End;
    Close(SourceFile);
   End
    Else
   ParseLineDetectPlane;
 End;
END.

