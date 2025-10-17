unit VlcComponent;

interface

uses
  Windows, Messages, SysUtils, Classes, Vcl.StdCtrls;

type
  TVlcState = (vlcIdle, vlcLoading, vlcPlaying, vlcPaused, vlcStopped, vlcError);
  TVlcNotifyEvent = procedure(Sender: TObject) of object;

  TVlcPlayerEx = class(TComponent)
  private
    FLibPath: string;
    FLibHandle: THandle;
    FParams: TStringList;
    FState: TVlcState;
    FMediaURL: string;
    FVolume: Integer;
    FAutoPlay: Boolean;
    FVideoHandle: HWND;
    FUserAgent: string;

    FInstance: Pointer;
    FMedia: Pointer;
    FPlayer: Pointer;

    // libVLC функции
    T_libvlc_new: function(argc: Integer; argv: PPAnsiChar): Pointer; cdecl;
    T_libvlc_release: procedure(p_instance: Pointer); cdecl;
    T_libvlc_media_new_path: function(p_instance: Pointer; path: PAnsiChar): Pointer; cdecl;
    T_libvlc_media_new_location: function(p_instance: Pointer; psz_mrl: PAnsiChar): Pointer; cdecl;
    T_libvlc_media_release: procedure(p_media: Pointer); cdecl;
    T_libvlc_media_player_new_from_media: function(p_media: Pointer): Pointer; cdecl;
    T_libvlc_media_player_release: procedure(p_player: Pointer); cdecl;
    T_libvlc_media_player_play: function(p_player: Pointer): Integer; cdecl;
    T_libvlc_media_player_pause: procedure(p_player: Pointer); cdecl;
    T_libvlc_media_player_stop: procedure(p_player: Pointer); cdecl;
    T_libvlc_media_player_set_hwnd: procedure(p_player: Pointer; hwnd: Pointer); cdecl;
    T_libvlc_audio_set_volume: procedure(p_player: Pointer; volume: Integer); cdecl;

    // События
    FOnPlaying: TVlcNotifyEvent;
    FOnPaused: TVlcNotifyEvent;
    FOnStopped: TVlcNotifyEvent;
    FOnEndReached: TVlcNotifyEvent;
    FOnError: TVlcNotifyEvent;
    FOnLoading: TVlcNotifyEvent;

    FMemoLog: TMemo;

    procedure SetMediaURL(const Value: string);
    procedure SetVolume(Value: Integer);
    procedure SetParams(const Value: TStringList);
    procedure SetUserAgent(const Value: string);
    procedure InitVLC;
    procedure LoadFunctions;
    procedure FreeVLC;
    procedure SetState(Value: TVlcState);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Play;
    procedure Pause;
    procedure Stop;
    procedure LoadMedia(const APath: string);
    function IsInitialized: Boolean;

    property Handle: HWND read FVideoHandle write FVideoHandle;
    property MemoLog: TMemo read FMemoLog write FMemoLog;

  published
    property LibPath: string read FLibPath write FLibPath;
    property Params: TStringList read FParams write SetParams;
    property MediaURL: string read FMediaURL write SetMediaURL;
    property AutoPlay: Boolean read FAutoPlay write FAutoPlay default True;
    property Volume: Integer read FVolume write SetVolume;
    property UserAgent: string read FUserAgent write SetUserAgent;
    property State: TVlcState read FState;

    property OnLoading: TVlcNotifyEvent read FOnLoading write FOnLoading;
    property OnPlaying: TVlcNotifyEvent read FOnPlaying write FOnPlaying;
    property OnPaused: TVlcNotifyEvent read FOnPaused write FOnPaused;
    property OnStopped: TVlcNotifyEvent read FOnStopped write FOnStopped;
    property OnEndReached: TVlcNotifyEvent read FOnEndReached write FOnEndReached;
    property OnError: TVlcNotifyEvent read FOnError write FOnError;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Samples', [TVlcPlayerEx]);
end;

{ === Реализация TVlcPlayerEx === }

constructor TVlcPlayerEx.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLibPath := 'libvlc.dll';
  FParams := TStringList.Create;
  FAutoPlay := True;
  FVolume := 100;
  FState := vlcIdle;
  FUserAgent := '';
end;

destructor TVlcPlayerEx.Destroy;
begin
  FreeVLC;
  FParams.Free;
  inherited Destroy;
end;

procedure TVlcPlayerEx.InitVLC;
var
  Argv: array of PAnsiChar;
  I: Integer;
  UAParam: string;
begin
  if FInstance <> nil then Exit;

  if FLibHandle = 0 then
  begin
    FLibHandle := LoadLibrary(PChar(FLibPath));
    if FLibHandle = 0 then
      raise Exception.Create('Не удалось загрузить libvlc.dll');
  end;

  LoadFunctions;

  // Добавляем User-Agent
  if FUserAgent <> '' then
  begin
    UAParam := '--http-user-agent=' + FUserAgent;
    if FParams.IndexOf(UAParam) = -1 then
      FParams.Add(UAParam);
  end;

  SetLength(Argv, FParams.Count);
  for I := 0 to FParams.Count - 1 do
    Argv[I] := PAnsiChar(AnsiString(FParams[I]));

  FInstance := T_libvlc_new(FParams.Count, @Argv[0]);
  if FInstance = nil then
    raise Exception.Create('Ошибка инициализации VLC');
end;

procedure TVlcPlayerEx.LoadFunctions;
  function GetProc(const Name: string): Pointer;
  begin
    Result := GetProcAddress(FLibHandle, PChar(Name));
    if not Assigned(Result) then
      raise Exception.CreateFmt('Не найдена функция %s в libvlc.dll', [Name]);
  end;
begin
  @T_libvlc_new := GetProc('libvlc_new');
  @T_libvlc_release := GetProc('libvlc_release');
  @T_libvlc_media_new_path := GetProc('libvlc_media_new_path');
  @T_libvlc_media_new_location := GetProc('libvlc_media_new_location');
  @T_libvlc_media_release := GetProc('libvlc_media_release');
  @T_libvlc_media_player_new_from_media := GetProc('libvlc_media_player_new_from_media');
  @T_libvlc_media_player_release := GetProc('libvlc_media_player_release');
  @T_libvlc_media_player_play := GetProc('libvlc_media_player_play');
  @T_libvlc_media_player_pause := GetProc('libvlc_media_player_pause');
  @T_libvlc_media_player_stop := GetProc('libvlc_media_player_stop');
  @T_libvlc_media_player_set_hwnd := GetProc('libvlc_media_player_set_hwnd');
  @T_libvlc_audio_set_volume := GetProc('libvlc_audio_set_volume');
end;

procedure TVlcPlayerEx.FreeVLC;
begin
  if FPlayer <> nil then
  begin
    T_libvlc_media_player_stop(FPlayer);
    T_libvlc_media_player_release(FPlayer);
    FPlayer := nil;
  end;

  if FMedia <> nil then
  begin
    T_libvlc_media_release(FMedia);
    FMedia := nil;
  end;

  if FInstance <> nil then
  begin
    T_libvlc_release(FInstance);
    FInstance := nil;
  end;

  if FLibHandle <> 0 then
  begin
    FreeLibrary(FLibHandle);
    FLibHandle := 0;
  end;
end;

procedure TVlcPlayerEx.SetUserAgent(const Value: string);
begin
  if FUserAgent <> Value then
    FUserAgent := Value;
end;

procedure TVlcPlayerEx.SetVolume(Value: Integer);
begin
  FVolume := Value;
  if FPlayer <> nil then
    T_libvlc_audio_set_volume(FPlayer, FVolume);
end;

procedure TVlcPlayerEx.SetParams(const Value: TStringList);
begin
  FParams.Assign(Value);
end;

procedure TVlcPlayerEx.SetState(Value: TVlcState);
begin
  FState := Value;
end;

procedure TVlcPlayerEx.SetMediaURL(const Value: string);
begin
  if FMediaURL <> Value then
  begin
    FMediaURL := Value;
    if Value <> '' then LoadMedia(Value);
  end;
end;

function TVlcPlayerEx.IsInitialized: Boolean;
begin
  Result := FInstance <> nil;
end;

procedure TVlcPlayerEx.LoadMedia(const APath: string);
begin
  if Assigned(FMemoLog) then FMemoLog.Lines.Add('Загрузка: ' + APath);

  SetState(vlcLoading);
  if Assigned(FOnLoading) then FOnLoading(Self);

  InitVLC;

  if APath.StartsWith('http://') or APath.StartsWith('https://') then
    FMedia := T_libvlc_media_new_location(FInstance, PAnsiChar(AnsiString(APath)))
  else
    FMedia := T_libvlc_media_new_path(FInstance, PAnsiChar(AnsiString(APath)));

  if FMedia = nil then
  begin
    SetState(vlcError);
    if Assigned(FOnError) then FOnError(Self);
    Exit;
  end;

  FPlayer := T_libvlc_media_player_new_from_media(FMedia);
  if FVideoHandle <> 0 then
    T_libvlc_media_player_set_hwnd(FPlayer, Pointer(FVideoHandle));

  T_libvlc_audio_set_volume(FPlayer, FVolume);

  if FAutoPlay then Play;
end;

procedure TVlcPlayerEx.Play;
begin
  if FPlayer = nil then Exit;
  if Assigned(FMemoLog) then FMemoLog.Lines.Add('▶ Воспроизведение');
  T_libvlc_media_player_play(FPlayer);
  SetState(vlcPlaying);
  if Assigned(FOnPlaying) then FOnPlaying(Self);
end;

procedure TVlcPlayerEx.Pause;
begin
  if FPlayer = nil then Exit;
  if Assigned(FMemoLog) then FMemoLog.Lines.Add('⏸ Пауза');
  T_libvlc_media_player_pause(FPlayer);
  SetState(vlcPaused);
  if Assigned(FOnPaused) then FOnPaused(Self);
end;

procedure TVlcPlayerEx.Stop;
begin
  if FPlayer = nil then Exit;
  if Assigned(FMemoLog) then FMemoLog.Lines.Add('⏹ Остановка');
  T_libvlc_media_player_stop(FPlayer);
  SetState(vlcStopped);
  if Assigned(FOnStopped) then FOnStopped(Self);
end;

end.

