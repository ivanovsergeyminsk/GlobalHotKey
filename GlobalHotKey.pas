unit GlobalHotKey;

interface

uses
  WinApi.Windows, System.Generics.Collections, System.SysUtils;

type
  TTypeHookMessage = (hmUNKNOWN,
                      hmKEYDOWN,
                      hmKEYUP,
                      hmSYSKEYDOWN,
                      hmSYSKEYUP);

  THookMessage = record
    VkCode:       cardinal;
    ScanCode:     cardinal;
    TypeMessage:  TTypeHookMessage;
  end;

  TDelegateHotKey = reference to procedure();
  TGHotKey = class
  private
    FKeys: TList<word>;
    FDelegate: TDelegateHotKey;
    function GetKeys: TArray<word>;
  public
    constructor Create(AKeys: TArray<word>; ADelegate: TDelegateHotKey);
    destructor Destroy; override;

    property Keys: TArray<word> read GetKeys;

    function GetHashCode: integer; overload; override;
    class function GetHashCodeHotKey(AKeys: TArray<word>): integer; overload; static;
  end;

  TGlobalHotKey = class
  private
    class var Hook: HHOOK;
    class var FMaxQueue: byte;
    class var HookQueue: TQueue<THookMessage>;
    class var FHotKeys: TObjectDictionary<integer, TGHotKey>;

    class constructor Create;
    class destructor Destroy;
  protected
    constructor Create;
    destructor Destroy; reintroduce; override;
  private
    class procedure RegisterHookMessage(AHookMessage: THookMessage); static;
    class procedure SetMaxQueue(const Value: byte); static;

    class procedure DoHotKey;
    class function GetHotKeysVarinats(AQueueArray:TArray<THookMessage>): TArray<integer>;
  public
    class property MaxQueue: byte read FMaxQueue write SetMaxQueue;
    Class procedure AddHotKey(AHotKey: TGHotKey);
  end;

implementation
uses
  Winapi.Messages;

function HookProc(nCode, wParam, lParam: Integer): LRESULT; stdcall;
  type
    PKBDLLHookStruct = ^TKBDLLHookStruct;
    TKBDLLHookStruct = packed record
      vkCode, scanCode, flags, time: Cardinal;
      dwExtraInfo: PCardinal;
    end;
var
  VHookMessage: THookMessage;
begin
  if nCode = HC_ACTION then begin
    case WParam of
      WM_KEYDOWN:     VHookMessage.TypeMessage := TTypeHookMessage(1);
      WM_KEYUP:       VHookMessage.TypeMessage := TTypeHookMessage(2);
      WM_SYSKEYDOWN:  VHookMessage.TypeMessage := TTypeHookMessage(3);
      WM_SYSKEYUP:    VHookMessage.TypeMessage := TTypeHookMessage(4);
   else
     VHookMessage.TypeMessage := TTypeHookMessage(0);
   end;

   with PKBDLLHookStruct(lParam)^ do begin
    VHookMessage.VkCode    := vkCode;
    VHookMessage.ScanCode  := scanCode;
   end;
   if VHookMessage.TypeMessage = hmKEYDOWN then
    TGlobalHotKey.RegisterHookMessage(VHookMessage);
  end;

  Result := CallNextHookEx(0, nCode, wParam, lParam);
end;

{ TGlobalHotKey }

class procedure TGlobalHotKey.AddHotKey(AHotKey: TGHotKey);
begin
  if AHotKey = nil then
    raise EArgumentNilException.Create('AHotKey');

  FHotKeys.Add(AHotKey.GetHashCode, AHotKey);
end;

class constructor TGlobalHotKey.Create;
const
  WH_KEYBOARD_LL = 13;
  DEFAULT_MAX_QUEUE = 5;
begin
  FMaxQueue := DEFAULT_MAX_QUEUE;

  FHotKeys := TObjectDictionary<integer, TGHotKey>.Create([doOwnsValues]);

  HookQueue := TQueue<THookMessage>.Create;
  Hook := SetWindowsHookEx(WH_KEYBOARD_LL, @HookProc, HInstance, 0);
end;

class destructor TGlobalHotKey.Destroy;
begin
  UnhookWindowsHookEx(Hook);
  FreeAndNil(FHotKeys);
  FreeAndNil(HookQueue);
end;

destructor TGlobalHotKey.Destroy;
begin
  inherited Destroy;
end;

class procedure TGlobalHotKey.DoHotKey;
var
  vHotKeys: TArray<integer>;
  vHotKeyHash: integer;
  VGHotKey: TGHotKey;
begin
  vHotKeys := GetHotKeysVarinats(HookQueue.ToArray);
  for vHotKeyHash in vHotKeys do
  begin
    if FHotKeys.TryGetValue(vHotKeyHash, VGHotKey) then begin
       HookQueue.Clear;
       VGHotKey.FDelegate();
      break;
    end;
  end;
end;

class function TGlobalHotKey.GetHotKeysVarinats(AQueueArray: TArray<THookMessage>): TArray<integer>;
var
  VHookMessage: THookMessage;
  vKeys: TArray<word>;
  I, J: integer;
begin
   for I := 0 to Length(AQueueArray)-1 do begin
    vKeys := [];
    for j := I to Length(AQueueArray)-1 do begin
      VHookMessage := AQueueArray[j];
      setLength(vKeys, length(vKeys)+1);
      vKeys[high(vKeys)] := VHookMessage.VkCode;
      setLength(result, length(result)+1);
      result[high(result)] := TGHotKey.GetHashCodeHotKey(vKeys);
    end;
   end;
end;

class procedure TGlobalHotKey.RegisterHookMessage(AHookMessage: THookMessage);
begin
  if HookQueue.Count = FMaxQueue then
    HookQueue.Dequeue;

  HookQueue.Enqueue(AHookMessage);

  DoHotKey;
end;

class procedure TGlobalHotKey.SetMaxQueue(const Value: byte);
begin
  FMaxQueue := Value;
end;

constructor TGlobalHotKey.Create;
begin
  inherited Create;
end;

{ TGHotKey }

constructor TGHotKey.Create(AKeys: TArray<word>; ADelegate: TDelegateHotKey);
begin
  if length(AKeys) = 0 then
    raise EArgumentNilException.Create('AKeys');

  if not assigned(ADelegate) then
    raise EArgumentNilException.Create('ADelegate');

  FDelegate := ADelegate;
  FKeys := TList<word>.Create;
  FKeys.AddRange(AKeys);
end;

destructor TGHotKey.Destroy;
begin
  FreeAndNil(FKeys);
end;

function TGHotKey.GetHashCode: integer;
begin
  result := TGHotKey.GetHashCodeHotKey(FKeys.ToArray)
end;

class function TGHotKey.GetHashCodeHotKey(AKeys: TArray<word>): integer;
var
  vStr: string;
  vWord: word;
begin
  for vWord in AKeys do
    vStr := vStr+vWord.ToHexString+' ';

  result := vStr.GetHashCode;
end;

function TGHotKey.GetKeys: TArray<word>;
begin
  result := FKeys.ToArray;
end;

end.
