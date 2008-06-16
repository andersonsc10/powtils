unit SessionManagerUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, CollectionUnit;

type

  { EVariableNotFoundInSession }

  EVariableNotFoundInSession= class (Exception)
  public
    constructor Create;
    
  end;
  
  { ESessionNotFound }

  ESessionNotFound= class (Exception)
  public
    constructor Create;
    
  end;
  
  { TVariable }

  TVariable= class (TNameValue)
  private
    procedure UpdateValue (NewVal: String);
    
  public
    constructor _Create (VarName, VarValue: String);

  end;

  TSessionID= String;
  
  { TSession }

  TSession= class (TBaseCollection)
  private
    FSessionID: TSessionID;
    
    function GetVariable (Index: Integer): TVariable;
    function GetVariableByName (VarName: String): TVariable;
    function FindVariableIndex (VarName: String): Integer;
    
  public
    property SessionID: TSessionID read FSessionID;
    property Variable [Index: Integer]: TVariable read GetVariable;
    property VariableByName [VarName: String]: TVariable read GetVariableByName;

    constructor Create (ThisSessionID: TSessionID);
    
    procedure AddVariable (NewVar: TVariable);
    procedure AddVariable (Name, Value: String);
    procedure UpdateValue (Name, Value: String);
    procedure DeleteVariable (Name, Value: String);
    
    function VariableExists (VarName: String): TVariable;

  end;
  
  { TAbstractSessionManager }

  TAbstractSessionManager= class (TBaseCollection)
  private
    FSessionIDLen: Integer;
    
    function GetSession (Index: Integer): TSession; virtual;
    function GetSessionBySessionID (SessionID: TSessionID): TSession; virtual;
    
    function FindSessionIndex (SessionID: TSessionID): Integer;

  public
    property Session [Index: Integer]: TSession read GetSession;
    property SessionBySessionID [SessionID: TSessionID]: TSession read GetSessionBySessionID;

    constructor Create (SessionIDLen: Integer);
    destructor Destroy; override;

    procedure AddSession (NewSession: TSession);
    procedure DeleteSession (SessionID: TSessionID);

    function GetNewSessionID: TSessionID; virtual;
    function CreateEmptySession: TSession;
    
    procedure Load; virtual; abstract;
    procedure Save; virtual; abstract;
    
  end;
  
  { TBasicSessionManager }

  TBasicSessionManager= class (TAbstractSessionManager)
  private
  public
    
    procedure Load; override;
    procedure Save; override;

  end;
  
  
implementation
uses
  MyTypes;
  
{ TAbstractSessionManager }

function TAbstractSessionManager.GetSession(Index: Integer): TSession;
begin
  Result:= Member [Index] as TSession;
  
end;

function TAbstractSessionManager.GetSessionBySessionID(SessionID: TSessionID
  ): TSession;
var
  Ptr: PObject;
  i: Integer;
  
begin

  Ptr:= GetPointerToFirst;
  for i:= 1 to FSize do
  begin
    if (TSession (Ptr^)).SessionID= SessionID then
    begin
      Result:= TSession (Ptr^);
      Exit;

    end;

    Inc (Ptr);

  end;

  raise ESessionNotFound.Create;

end;

function TAbstractSessionManager.FindSessionIndex (SessionID: TSessionID): Integer;
var
  i: Integer;
  Ptr: PObject;
  
begin
  Ptr:= GetPointerToFirst;
  for i:= 1 to FSize do
  begin
    if (TSession (Ptr^)).SessionID= SessionID then
    begin
      Result:= i- 1;
      Exit;
      
    end;
    
    Inc (Ptr);
    
  end;
  
  Result:= -1;

end;

constructor TAbstractSessionManager.Create (SessionIDLen: Integer);
begin
  inherited Create;
  
  Load;
  
end;

destructor TAbstractSessionManager.Destroy;
begin
  Save;

  inherited;
  
end;

procedure TAbstractSessionManager.AddSession (NewSession: TSession);
begin
  Add (NewSession);
  
end;

procedure TAbstractSessionManager.DeleteSession (SessionID: TSessionID);
var
  Index: Integer;
  
begin
  Index:= FindSessionIndex (SessionID);
  if Index< 0 then
    raise ESessionNotFound.Create
  else
    Delete (Index);
    
end;

function TAbstractSessionManager.GetNewSessionID: TSessionID;

  function GenerateSessionID: String;
  var
    i: Integer;
    CharPtr: PChar;
    
  begin
    Result:= Space (FSessionIDLen);
    
    for i:= 1 to FSessionIDLen do
      Result:= Result ;
  end;
  
begin

end;

function TAbstractSessionManager.CreateEmptySession: TSession;
begin
  Result:= TSession.Create (GetNewSessionID);
  
end;


{ TVariable }

procedure TVariable.UpdateValue (NewVal: String);
begin
  FValue:= TObject (NewVal);
  
end;

constructor TVariable._Create (VarName, VarValue: String);
begin
  inherited Create (VarName, TObject (VarValue));
  
end;

{ TSession }

function TSession.GetVariable (Index: Integer): TVariable;
begin
  Result:= GetMember (Index) as TVariable;
  
end;

function TSession.GetVariableByName (VarName: String): TVariable;
var
  i: Integer;
  
begin
  for i:= 0 to FSize- 1 do
    if Variable [i].Name= VarName then
    begin
      Result:= Variable [i];
      Exit;
    end;

  raise EVariableNotFoundInSession.Create;
    
end;

function TSession.FindVariableIndex (VarName: String): Integer;
var
  i: Integer;
  
begin
  VarName:= UpperCase (VarName);
  
  for i:= 0 to FSize- 1 do
    if Variable [i].Name= VarName then
    begin
      Result:= i;
      Exit;
      
    end;

  Result:= -1;
  
end;

constructor TSession.Create (ThisSessionID: TSessionID);
begin

end;

procedure TSession.AddVariable (NewVar: TVariable);
var
  CopyVar: TVariable;
  
begin
  CopyVar:= TVariable.Create (UpperCase (NewVar.Name), NewVar.Value);
  Add (CopyVar);
  
end;

procedure TSession.AddVariable (Name, Value: String);
begin
  Add (TVariable._Create (UpperCase (Name), Value));
  
end;

procedure TSession.UpdateValue (Name, Value: String);
var
  TempVar: TVariable;
  
begin
  TempVar:= VariableExists (Name);
  if TempVar= nil then
    raise EVariableNotFoundInSession.Create
  else
    TempVar.UpdateValue (Value);
  
end;

procedure TSession.DeleteVariable (Name, Value: String);
var
  Index: Integer;
  
begin
  Index:= FindVariableIndex (Name);
  if Index<> -1 then
    Delete (Index);
    
end;

function TSession.VariableExists (VarName: String): TVariable;
var
  VarIndex: Integer;
  
begin
  VarIndex:= FindVariableIndex (VarName);
  if VarIndex<> -1 then
    Result:= Variable [VarIndex]
  else
    Result:= nil;
    
end;

{ EVariableNotFoundInSession }

constructor EVariableNotFoundInSession.Create;
begin
  inherited Create ('Variable Not Found In Session');
  
end;

{ ESessionNotFound }

constructor ESessionNotFound.Create;
begin
  inherited Create ('Session Not Found!');

end;

{ TBasicSessionManager }

procedure TBasicSessionManager.Load;
begin
  
end;

procedure TBasicSessionManager.Save;
begin
  
end;

end.
