unit VlcComponent;

interface

uses
  Windows, Messages, SysUtils, Classes, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs;

type
  TVlcState = (vlcIdle, vlcLoading, vlcPlaying, vlcPaused, vlcStopped, vlcError);
  TVlcNotifyEvent = procedure(Sender: TObject) of object;
  TVlcLogEvent = procedure(Sender: TObject; const Msg: string) of object;

  TVlcPlayerEx = class(TComponent)
  private
    FLibPath: string;
    FLibHandle: THandle;
    FState: TVlcState;
    FMediaURL: string;
    FVolume: Integer;
    FAutoPlay: Boolean;
    FVideoHandle: HWND;
    FUserAgent: string;
    FReferer: string;
    FHttpHeaders: TStringList;

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
    T_libvlc_media_add_option: procedure(p_media: Pointer; psz_options: PAnsiChar); cdecl;
    T_libvlc_media_new_location_with_options: function(p_instance: Pointer; psz_mrl: PAnsiChar; options: Integer; ppsz_options: PPAnsiChar): Pointer; cdecl;

    // События
    FOnPlaying: TVlcNotifyEvent;
    FOnPaused: TVlcNotifyEvent;
    FOnStopped: TVlcNotifyEvent;
    FOnEndReached: TVlcNotifyEvent;
    FOnError: TVlcNotifyEvent;
    FOnLoading: TVlcNotifyEvent;
    FOnLog: TVlcLogEvent;

    procedure SetMediaURL(const Value: string);
    procedure SetVolume(Value: Integer);
    procedure SetUserAgent(const Value: string);
    procedure SetReferer(const Value: string);
    procedure SetHttpHeaders(const Value: TStringList);

    procedure InitVLC;
    procedure LoadFunctions;
    procedure FreeVLC;
    procedure SetState(Value: TVlcState);
    function GetLastErrorText: string;
    procedure Log(const Msg: string);
    function BuildVlcOptions: TStringList;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Play;
    procedure Pause;
    procedure Stop;
    procedure LoadMedia(const APath: string);
    function IsInitialized: Boolean;
    function IsPlaying: Boolean;

    procedure AddHttpHeader(const AName, AValue: string);
    procedure ClearHttpHeaders;
    procedure SetWinkHeaders;

    property Handle: HWND read FVideoHandle write FVideoHandle;

  published
    property LibPath: string read FLibPath write FLibPath;
    property MediaURL: string read FMediaURL write SetMediaURL;
    property AutoPlay: Boolean read FAutoPlay write FAutoPlay default True;
    property Volume: Integer read FVolume write SetVolume default 100;
    property UserAgent: string read FUserAgent write SetUserAgent;
    property Referer: string read FReferer write SetReferer;
    property HttpHeaders: TStringList read FHttpHeaders write SetHttpHeaders;
    property State: TVlcState read FState;

    property OnLoading: TVlcNotifyEvent read FOnLoading write FOnLoading;
    property OnPlaying: TVlcNotifyEvent read FOnPlaying write FOnPlaying;
    property OnPaused: TVlcNotifyEvent read FOnPaused write FOnPaused;
    property OnStopped: TVlcNotifyEvent read FOnStopped write FOnStopped;
    property OnEndReached: TVlcNotifyEvent read FOnEndReached write FOnEndReached;
    property OnError: TVlcNotifyEvent read FOnError write FOnError;
    property OnLog: TVlcLogEvent read FOnLog write FOnLog;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Samples', [TVlcPlayerEx]);
end;

{ TVlcPlayerEx }

constructor TVlcPlayerEx.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLibPath := 'libvlc.dll';
  FHttpHeaders := TStringList.Create;
  FAutoPlay := True;
  FVolume := 100;
  FState := vlcIdle;
end;

destructor TVlcPlayerEx.Destroy;
begin
  FOnLog := nil;
  FreeVLC;
  FHttpHeaders.Free;
  inherited Destroy;
end;

procedure TVlcPlayerEx.Log(const Msg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, Msg);
end;

function TVlcPlayerEx.GetLastErrorText: string;
var
  ErrorCode: Integer;
begin
  ErrorCode := GetLastError;
  if ErrorCode <> 0 then
    Result := SysErrorMessage(ErrorCode)
  else
    Result := 'Неизвестная ошибка';
end;

function TVlcPlayerEx.BuildVlcOptions: TStringList;
begin
  Result := TStringList.Create;
  try
    // Базовые опции
    Result.Add(':no-video-title-show');
    Result.Add(':network-caching=3000');

    // HTTP опции
    if FUserAgent <> '' then
      Result.Add(':http-user-agent=' + FUserAgent);

    if FReferer <> '' then
      Result.Add(':http-referer=' + FReferer);

    // Добавляем кастомные заголовки
    for var I := 0 to FHttpHeaders.Count - 1 do
    begin
      if FHttpHeaders.Names[I] <> '' then
        Result.Add(':http-extra-header=' + FHttpHeaders.Names[I] + ': ' + FHttpHeaders.ValueFromIndex[I]);
    end;

    // HLS опции
    Result.Add(':hls-prefer-native');
    Result.Add(':hls-preferred-resolution=720');

    // Логируем опции
    Log('Опции VLC:');
    for var I := 0 to Result.Count - 1 do
      Log('  ' + Result[I]);

  except
    Result.Free;
    raise;
  end;
end;

procedure TVlcPlayerEx.SetWinkHeaders;
begin
  FHttpHeaders.Clear;

  FHttpHeaders.Values['Accept'] := '*/*';
  FHttpHeaders.Values['Accept-Language'] := 'ru-RU,ru;q=0.9,en;q=0.8';
  FHttpHeaders.Values['Accept-Encoding'] := 'gzip, deflate, br';
  FHttpHeaders.Values['Cache-Control'] := 'no-cache';
  FHttpHeaders.Values['Connection'] := 'keep-alive';
  FHttpHeaders.Values['Pragma'] := 'no-cache';
  FHttpHeaders.Values['Origin'] := 'https://wink.ru';

  FHttpHeaders.Values['Sec-Fetch-Dest'] := 'empty';
  FHttpHeaders.Values['Sec-Fetch-Mode'] := 'cors';
  FHttpHeaders.Values['Sec-Fetch-Site'] := 'cross-site';
  FHttpHeaders.Values['Sec-Ch-Ua'] := '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"';
  FHttpHeaders.Values['Sec-Ch-Ua-Mobile'] := '?0';
  FHttpHeaders.Values['Sec-Ch-Ua-Platform'] := '"Windows"';

  FHttpHeaders.Values['DNT'] := '1';
  FHttpHeaders.Values['Upgrade-Insecure-Requests'] := '1';

  FUserAgent := 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
  FReferer := 'https://wink.ru/';

  Log('✅ Установлены заголовки Wink');
  Log('User-Agent: ' + FUserAgent);
  Log('Referer: ' + FReferer);
end;

procedure TVlcPlayerEx.SetHttpHeaders(const Value: TStringList);
begin
  FHttpHeaders.Assign(Value);
end;

procedure TVlcPlayerEx.SetUserAgent(const Value: string);
begin
  if FUserAgent <> Value then
    FUserAgent := Value;
end;

procedure TVlcPlayerEx.SetReferer(const Value: string);
begin
  if FReferer <> Value then
    FReferer := Value;
end;

procedure TVlcPlayerEx.SetVolume(Value: Integer);
begin
  if Value < 0 then Value := 0;
  if Value > 200 then Value := 200;

  FVolume := Value;
  if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_volume) then
    T_libvlc_audio_set_volume(FPlayer, FVolume);
end;

procedure TVlcPlayerEx.SetState(Value: TVlcState);
const
  StateNames: array[TVlcState] of string = (
    'Idle', 'Loading', 'Playing', 'Paused', 'Stopped', 'Error'
  );
begin
  if FState <> Value then
  begin
    FState := Value;
    Log('Состояние: ' + StateNames[Value]);
  end;
end;

procedure TVlcPlayerEx.InitVLC;
var
  Args: array of PAnsiChar;
  I, ArgCount: Integer;
  LibDir: string;
  OldDir: string;
begin
  if FInstance <> nil then
    FreeVLC;

  if not FileExists(FLibPath) then
    raise Exception.Create('Файл libvlc.dll не найден: ' + FLibPath);

  Log('Загрузка VLC из: ' + FLibPath);

  // Сохраняем текущую директорию
  OldDir := GetCurrentDir;
  try
    LibDir := ExtractFilePath(FLibPath);
    if LibDir <> '' then
      SetCurrentDir(LibDir);

    FLibHandle := LoadLibrary(PChar(FLibPath));
    if FLibHandle = 0 then
      raise Exception.Create('Ошибка загрузки библиотеки VLC: ' + GetLastErrorText);

    Log('Библиотека VLC загружена, загрузка функций...');
    LoadFunctions;

    // Создаем параметры для VLC
    var VlcParams := TStringList.Create;
    try
      VlcParams.Add('--no-video-title-show');
      VlcParams.Add('--intf=dummy');
      VlcParams.Add('--quiet');

      // Добавляем HTTP параметры в параметры экземпляра
      if FUserAgent <> '' then
        VlcParams.Add('--http-user-agent=' + FUserAgent);

      Log('Инициализация VLC с параметрами:');
      for I := 0 to VlcParams.Count - 1 do
        Log('  ' + VlcParams[I]);

      ArgCount := VlcParams.Count;
      SetLength(Args, ArgCount);
      for I := 0 to ArgCount - 1 do
        Args[I] := PAnsiChar(AnsiString(VlcParams[I]));

      FInstance := T_libvlc_new(ArgCount, @Args[0]);

    finally
      VlcParams.Free;
      SetLength(Args, 0);
    end;

    if FInstance = nil then
      raise Exception.Create('VLC не смог создать экземпляр');

    Log('✅ VLC успешно инициализирован');

  finally
    SetCurrentDir(OldDir);
  end;
end;

procedure TVlcPlayerEx.LoadFunctions;
  function GetProc(const Name: string): Pointer;
  begin
    Result := GetProcAddress(FLibHandle, PChar(Name));
    if not Assigned(Result) then
    begin
      Log('⚠️ Функция не найдена: ' + Name);
      Result := nil;
    end;
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
  @T_libvlc_media_add_option := GetProc('libvlc_media_add_option');
  @T_libvlc_media_new_location_with_options := GetProc('libvlc_media_new_location_with_options');
end;

procedure TVlcPlayerEx.FreeVLC;
begin
  if FPlayer <> nil then
  begin
    Log('Освобождение медиаплеера...');
    T_libvlc_media_player_stop(FPlayer);
    T_libvlc_media_player_release(FPlayer);
    FPlayer := nil;
  end;

  if FMedia <> nil then
  begin
    Log('Освобождение медиа...');
    T_libvlc_media_release(FMedia);
    FMedia := nil;
  end;

  if FInstance <> nil then
  begin
    Log('Освобождение экземпляра VLC...');
    T_libvlc_release(FInstance);
    FInstance := nil;
  end;

  if FLibHandle <> 0 then
  begin
    Log('Выгрузка библиотеки VLC...');
    FreeLibrary(FLibHandle);
    FLibHandle := 0;
  end;

  SetState(vlcStopped);
end;

procedure TVlcPlayerEx.SetMediaURL(const Value: string);
begin
  if FMediaURL <> Value then
  begin
    FMediaURL := Value;
    if (Value <> '') and not (csLoading in ComponentState) then
      LoadMedia(Value);
  end;
end;

function TVlcPlayerEx.IsInitialized: Boolean;
begin
  Result := (FInstance <> nil) and (FLibHandle <> 0);
end;

function TVlcPlayerEx.IsPlaying: Boolean;
begin
  Result := (FPlayer <> nil) and (FState = vlcPlaying);
end;

procedure TVlcPlayerEx.AddHttpHeader(const AName, AValue: string);
begin
  FHttpHeaders.Values[AName] := AValue;
end;

procedure TVlcPlayerEx.ClearHttpHeaders;
begin
  FHttpHeaders.Clear;
end;

procedure TVlcPlayerEx.LoadMedia(const APath: string);
var
  MediaType: string;
  Options: TStringList;
  I: Integer;
begin
  Log('=== ЗАГРУЗКА МЕДИА ===');
  Log('URL: ' + APath);

  if APath = '' then
  begin
    Log('❌ Ошибка: Пустой URL медиа');
    Exit;
  end;

  SetState(vlcLoading);
  if Assigned(FOnLoading) then
    FOnLoading(Self);

  try
    // Проверяем handle окна
    if FVideoHandle = 0 then
    begin
      Log('⚠️ Внимание: Handle окна не установлен!');
    end
    else if not IsWindow(FVideoHandle) then
    begin
      Log('❌ Ошибка: Неверный handle окна!');
      FVideoHandle := 0;
    end;

    // Останавливаем предыдущее воспроизведение
    if IsPlaying then
      Stop;

    // Освобождаем предыдущие ресурсы
    if FPlayer <> nil then
    begin
      T_libvlc_media_player_release(FPlayer);
      FPlayer := nil;
    end;

    if FMedia <> nil then
    begin
      T_libvlc_media_release(FMedia);
      FMedia := nil;
    end;

    // Инициализируем VLC если нужно
    if not IsInitialized then
      InitVLC;

    // Создаем медиа
    if (Pos('http://', LowerCase(APath)) = 1) or (Pos('https://', LowerCase(APath)) = 1) then
    begin
      MediaType := 'HTTP/HTTPS поток';
      FMedia := T_libvlc_media_new_location(FInstance, PAnsiChar(UTF8Encode(APath)));

      // ДОБАВЛЯЕМ ОПЦИИ ПОСЛЕ СОЗДАНИЯ МЕДИА
      if Assigned(T_libvlc_media_add_option) then
      begin
        Options := BuildVlcOptions;
        try
          for I := 0 to Options.Count - 1 do
          begin
            T_libvlc_media_add_option(FMedia, PAnsiChar(UTF8Encode(Options[I])));
            Log('Добавлена опция: ' + Options[I]);
          end;
        finally
          Options.Free;
        end;
      end;
    end
    else
    begin
      MediaType := 'Локальный файл';
      FMedia := T_libvlc_media_new_path(FInstance, PAnsiChar(UTF8Encode(APath)));
    end;

    Log('Тип медиа: ' + MediaType);

    if FMedia = nil then
      raise Exception.Create('Не удалось создать медиа объект');

    FPlayer := T_libvlc_media_player_new_from_media(FMedia);
    if FPlayer = nil then
      raise Exception.Create('Не удалось создать медиаплеер');

    // Устанавливаем окно вывода
    if FVideoHandle <> 0 then
    begin
      T_libvlc_media_player_set_hwnd(FPlayer, Pointer(FVideoHandle));
      Log('✅ Handle окна установлен: ' + IntToStr(FVideoHandle));
    end;

    // Устанавливаем громкость
    if Assigned(T_libvlc_audio_set_volume) then
      T_libvlc_audio_set_volume(FPlayer, FVolume);

    Log('✅ Медиа успешно загружено');

    if FAutoPlay then
      Play
    else
      SetState(vlcPaused);

  except
    on E: Exception do
    begin
      SetState(vlcError);
      Log('❌ Ошибка загрузки медиа: ' + E.Message);
      if Assigned(FOnError) then
        FOnError(Self);
    end;
  end;
end;

procedure TVlcPlayerEx.Play;
var
  ResultCode: Integer;
begin
  if FPlayer = nil then
  begin
    Log('❌ Ошибка: Плеер не инициализирован');
    Exit;
  end;

  Log('Запуск воспроизведения...');
  ResultCode := T_libvlc_media_player_play(FPlayer);

  if ResultCode = 0 then
  begin
    SetState(vlcPlaying);
    Log('▶️ Воспроизведение начато успешно');
    if Assigned(FOnPlaying) then
      FOnPlaying(Self);
  end
  else
  begin
    SetState(vlcError);
    Log('❌ Ошибка воспроизведения, код: ' + IntToStr(ResultCode));
    if Assigned(FOnError) then
      FOnError(Self);
  end;
end;

procedure TVlcPlayerEx.Pause;
begin
  if FPlayer = nil then Exit;

  T_libvlc_media_player_pause(FPlayer);
  SetState(vlcPaused);
  Log('⏸️ Воспроизведение приостановлено');
  if Assigned(FOnPaused) then
    FOnPaused(Self);
end;

procedure TVlcPlayerEx.Stop;
begin
  if FPlayer = nil then Exit;

  T_libvlc_media_player_stop(FPlayer);
  SetState(vlcStopped);
  Log('⏹️ Воспроизведение остановлено');
  if Assigned(FOnStopped) then
    FOnStopped(Self);
end;

end.
