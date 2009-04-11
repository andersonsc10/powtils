unit RequestsQueue;
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, CollectionUnit;
  
type
{
  This class is going to save a request parameters.
  It read the parameters from the Mainpipehandle which is passed to it.
}
  { TRequest }

  TRequest= class (TObject)
  private
    FParameters: String;
    FCookieStr: String;
    
  public
    {Parameters is a string which contains all the GET/POST variables
      and some of environment variables which are seprated by & from each other.
    }
    property Parameters: String read FParameters;
    
    {CookiStr is a string which contains all Cookie values
      which are seprated by & from each other.
    }
    property CookieStr: String read FCookieStr;
    
    constructor Create (const ParamsAndCookies: String);
    
  end;
  
  { EQueueIsFull }

  EQueueIsFull= class (Exception)
    constructor Create;

  end;

  { EQueueIsEmpty }

  EQueueIsEmpty= class (Exception)
    constructor Create;

  end;

  { TSuspendedThreads }

  TSuspendedThreads= class (TBaseCollection)
  private
    Top, Bot: Integer;
    CS: TRTLCriticalSection;

  protected
    function IsEmpty: Boolean; inline;
    function IsFull: Boolean; inline;

  public
    constructor Create (_Size: Integer);
    destructor Destroy; override;

    function Delete: Boolean;
    procedure Insert (NewThread: TThread);

  end;


  { TCircularRequestsQueue }

  TCircularRequestsQueue= class (TBaseCollection)
  private
    FSuspendedThreads: TSuspendedThreads;
    SoQ, EoQ: Integer;
    CS: TRTLCriticalSection;
    FActiveMemberCount: Integer;

  public
    property ActiveMemberCount: Integer read FActiveMemberCount;

    constructor Create (QueueSize, MaxThreadCount: Integer);
    destructor Destroy; override;

    procedure Insert (Request: TRequest);
    function Delete: TRequest;

    function IsEmpty: Boolean;
    function IsFull: Boolean;

    procedure AddToSuspendedThreads (AThread: TThread);
    procedure TryToMakeItEmpty;

  end;

implementation
uses
  URLEnc, MyTypes;
  
{ TRequest }
{
  Loads the Parameters and Cookies from MainPipe.
  A #255#255 used as disjointer between parameters and cookies which are
  written in a line by RequestCollector.
}
{
constructor TRequest.Create (var MainPipeHanlde: TextFile);
const
  ParametersCookiesSeprator: String= #$FE#$FE;
var
  ParamsAndCookies: String;
  Position: Integer;
  
begin
  inherited Create;
  
  ReadLn (MainPipeHanlde, ParamsAndCookies);
  Position:= Pos (ParametersCookiesSeprator, ParamsAndCookies);
  
  FParameters:= Copy (ParamsAndCookies, 1, Position- 1);
  Delete (ParamsAndCookies, 1, Position+ 1);
  FCookieStr:= URLDecode (ParamsAndCookies);

  
(*$IFDEF DEBUG_MODE*)
  WriteLn ('FParameters=', FParameters);
  WriteLn ('FCookieStr=', FCookieStr);
(*$ENDIF*)

end;
}

{
  Loads the Parameters and Cookies from an string (ParamsAndCookies).
  A #255 used as disjointer between parameters and cookies which are
  written in a line by RequestCollector.
}
constructor TRequest.Create (const ParamsAndCookies: String);
const
  ParametersCookiesSeprator: String= #$FE;
  
var
  Position: Integer;

begin
  inherited Create;

  Position:= Pos (ParametersCookiesSeprator, ParamsAndCookies);

  FParameters:= Copy (ParamsAndCookies, 1, Position- 1);
  FCookieStr:= URLDecode (Copy (ParamsAndCookies, Position+ 1,
          Length (ParamsAndCookies)- Position));

(*$IFDEF DEBUG_MODE*)
  WriteLn ('FParameters=', FParameters);
  WriteLn ('FCookieStr=', FCookieStr);
  
(*$ENDIF*)

end;

{ EQueueIsFull }

constructor EQueueIsFull.Create;
begin
  inherited Create ('Queue Is Full!');
  
end;

{ EQueueIsEmpty }

constructor EQueueIsEmpty.Create;
begin
  inherited Create ('Queue Is Empty!');
  
end;


{ TCircularRequestsQueue }

constructor TCircularRequestsQueue.Create (QueueSize, MaxThreadCount: Integer);
begin
  inherited Create;

  InitCriticalSection (CS);

  Allocate (QueueSize);
  SoQ:= 0;
  EoQ:= 0;
  FSize:= QueueSize;
  FActiveMemberCount:= 0;

  FSuspendedThreads:= TSuspendedThreads.Create (MaxThreadCount);
  
end;

destructor TCircularRequestsQueue.Destroy;
var
  i: Integer;

begin
  DoneCriticalsection (CS);
  
  FSuspendedThreads.Free;
  
  inherited;

end;

procedure TCircularRequestsQueue.Insert (Request: TRequest);
var
  SuspendedThread: TThread;

begin
  EnterCriticalsection (CS);

  if FSize<= ActiveMemberCount then
  begin
    LeaveCriticalsection (CS);
    raise EQueueIsFull.Create;

  end;

  FMembers [EoQ]:= Request;
  if EoQ= FSize- 1 then
    EOq:= FSize- 1;

  EoQ:= (EoQ+ 1) mod FSize;
  Inc (ActiveMemberCount);
  
  if FSuspendedThreads.Size<> 0 then
  begin
    WriteLn ('TCircularRequestsQueue.Insert FSuspendedThreads.Size=',
       FSuspendedThreads.Size);
    FSuspendedThreads.Delete;

  end;

  LeaveCriticalsection (CS);

end;

function TCircularRequestsQueue.Delete: TRequest;
begin
  EnterCriticalsection (CS);
  
  if ActiveMemberCount= 0 then
  begin
    WriteLn ('TCircularRequestsQueue.Delete: ActiveMemberCount= 0');
    LeaveCriticalsection (CS);
    raise EQueueIsEmpty.Create;
    
  end;

  WriteLn ('TCircularRequestsQueue.Delete Successfully!');
  Result:= FMembers [SoQ] as TRequest;
  SoQ:= (SoQ+ 1) mod FSize;
  Dec (ActiveMemberCount);
  
  LeaveCriticalsection (CS);

end;

function TCircularRequestsQueue.IsEmpty: Boolean;
begin
  Result:= ActiveMemberCount= 0;

end;

function TCircularRequestsQueue.IsFull: Boolean;
begin
  Result:= ActiveMemberCount= Size;

end;

procedure TCircularRequestsQueue.AddToSuspendedThreads(AThread: TThread);
begin
  WriteLn ('TCircularRequestsQueue.AddToSuspendedThreads:', AThread.ThreadID, ' added to Suspeded Thread');

  FSuspendedThreads.Insert (AThread);

end;

procedure TCircularRequestsQueue.TryToMakeItEmpty;
begin
  WriteLn ('TCircularRequestsQueue.TryToMakeItEmpty:');

  FSuspendedThreads.Delete;

end;

{ TSuspendedThreads }

constructor TSuspendedThreads.Create (_Size: Integer);
var
  i: Integer;
  Ptr: PObject;

begin
  inherited Create;

  Allocate (_Size+ 1);

  Top:= 0;
  Bot:= 0;

  InitCriticalSection (CS);

end;

destructor TSuspendedThreads.Destroy;
begin
  DoneCriticalsection (CS);
  Clear;

  inherited Destroy;

end;

function TSuspendedThreads.Delete: Boolean;
begin
  EnterCriticalsection (CS);
  Result:= IsEmpty;

  if not Result then
  begin
    WriteLn ('TSuspendedThreads.Delete: Not Empty');

    ((FMembers [Bot]) as TThread).Resume;
    Bot:= (Bot+ 1) mod FSize;

  end
  else
  begin
    WriteLn ('TSuspendedThreads.Delete: Is Empty');

  end;

  LeaveCriticalsection (CS);

end;

procedure TSuspendedThreads.Insert (NewThread: TThread);
begin
  EnterCriticalsection (CS);

  WriteLn ('TSuspendedThreads.Insert: ', NewThread.ThreadID, ':', Top, ' ', Bot);

  if not IsFull then
  begin
    FMembers [Top]:= NewThread;
    Top:= (Top+ 1) mod FSize;

  end
  else
  begin
    WriteLn ('TSuspendedThreads.Insert: SuspendThread Queue is full!');

  end;

  LeaveCriticalsection (CS);

end;

function TSuspendedThreads.IsEmpty: Boolean; inline;
begin
  Result:= Top= Bot;

end;

function TSuspendedThreads.IsFull: Boolean; inline;
begin
  Result:= ((Top+ 1) mod FSize= Bot);

end;

end.
