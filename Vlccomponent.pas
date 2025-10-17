unit VlcComponent;

interface

uses
  Windows, Messages, SysUtils, Classes, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs, TypInfo;

type
  // Состояния плеера
  TVlcState = (vlcIdle, vlcLoading, vlcPlaying, vlcPaused, vlcStopped, vlcError);

  // Режимы качества
  TVlcQualityMode = (qmAuto, qmBest, qmWorst, qmCustom);

  // Типы событий
  TVlcNotifyEvent = procedure(Sender: TObject) of object;
  TVlcLogEvent = procedure(Sender: TObject; const Msg: string) of object;
  TVlcProgressEvent = procedure(Sender: TObject; Progress: Integer) of object;

  TVlcPlayerEx = class(TComponent)
  private
    FLibPath: string;              // Путь к библиотеке VLC
    FLibHandle: THandle;           // Хэндл загруженной библиотеки
    FState: TVlcState;             // Текущее состояние плеера
    FMediaURL: string;             // URL медиа-потока
    FVolume: Integer;              // Громкость (0-100)
    FAutoPlay: Boolean;            // Автоматическое воспроизведение
    FVideoHandle: HWND;            // Хэндл окна для вывода видео
    FUserAgent: string;            // User-Agent для HTTP-запросов
    FReferer: string;              // Referer для HTTP-запросов
    FHttpHeaders: TStringList;     // Дополнительные HTTP-заголовки
    FAutoDetectProtectedStreams: Boolean; // Автоопределение защищенных потоков
    FForceWinkHeaders: Boolean;    // Принудительное использование Wink заголовков
    FIsLoading: Boolean;           // Флаг загрузки
    FLoadingProgress: Integer;     // Прогресс загрузки
    FQualityMode: TVlcQualityMode; // Режим качества
    FForcedBitrate: Integer;       // Принудительный битрейт
    FForcedResolution: string;     // Принудительное разрешение

    // Указатели на объекты VLC
    FInstance: Pointer;      // Экземпляр VLC
    FMedia: Pointer;         // Медиа-объект
    FPlayer: Pointer;        // Плеер
    FEventManager: Pointer;  // Менеджер событий

    // Объявления функций библиотеки VLC
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
    T_libvlc_media_player_get_length: function(p_player: Pointer): Int64; cdecl;
    T_libvlc_media_player_get_time: function(p_player: Pointer): Int64; cdecl;
    T_libvlc_media_player_get_position: function(p_player: Pointer): Single; cdecl;
    T_libvlc_event_attach: procedure(p_event_manager: Pointer; event_type: Integer; callback: Pointer; user_data: Pointer); cdecl;
    T_libvlc_media_player_event_manager: function(p_player: Pointer): Pointer; cdecl;

    // События компонента
    FOnPlaying: TVlcNotifyEvent;
    FOnPaused: TVlcNotifyEvent;
    FOnStopped: TVlcNotifyEvent;
    FOnEndReached: TVlcNotifyEvent;
    FOnError: TVlcNotifyEvent;
    FOnLoading: TVlcNotifyEvent;
    FOnLog: TVlcLogEvent;
    FOnLoadingProgress: TVlcProgressEvent;
    FOnBuffering: TVlcProgressEvent;
    FOnQualityChanged: TVlcNotifyEvent;

    // Приватные методы
    procedure SetMediaURL(const Value: string);
    procedure SetVolume(Value: Integer);
    procedure SetUserAgent(const Value: string);
    procedure SetReferer(const Value: string);
    procedure SetHttpHeaders(const Value: TStringList);
    procedure SetQualityMode(const Value: TVlcQualityMode);
    procedure SetForcedBitrate(const Value: Integer);
    procedure SetForcedResolution(const Value: string);

    procedure InitVLC;
    procedure LoadFunctions;
    procedure FreeVLC;
    procedure SetState(Value: TVlcState);
    function GetLastErrorText: string;
    procedure Log(const Msg: string);
    function BuildVlcOptions: TStringList;
    function IsProtectedStream(const AUrl: string): Boolean;
    function TestStreamProtection(const AUrl: string): Boolean;
    procedure ApplyAppropriateHeaders(const AUrl: string);
    procedure StopCurrentStream;
    procedure SetupEventHandlers;
    procedure UpdateLoadingProgress;
    procedure ApplyQualitySettings;
    function GetQualityOptions: TStringList;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Основные методы управления
    procedure Play;
    procedure Pause;
    procedure Stop;
    procedure LoadMedia(const APath: string);

    // Методы получения состояния
    function IsInitialized: Boolean;
    function IsPlaying: Boolean;
    function GetDuration: Int64;
    function GetPosition: Int64;
    function GetPlaybackPosition: Single;

    // Методы управления качеством
    procedure ForceBestQuality;
    procedure ForceWorstQuality;
    procedure ForceAutoQuality;
    procedure ForceCustomQuality(Bitrate: Integer; const Resolution: string);

    // Методы работы с HTTP-заголовками
    procedure AddHttpHeader(const AName, AValue: string);
    procedure ClearHttpHeaders;
    procedure SetWinkHeaders;
    procedure SetBasicHeaders;

    // Публичные свойства
    property Handle: HWND read FVideoHandle write FVideoHandle;
    property AutoDetectProtectedStreams: Boolean read FAutoDetectProtectedStreams write FAutoDetectProtectedStreams default True;
    property ForceWinkHeaders: Boolean read FForceWinkHeaders write FForceWinkHeaders default False;
    property LoadingProgress: Integer read FLoadingProgress;
    property IsLoading: Boolean read FIsLoading;
    property QualityMode: TVlcQualityMode read FQualityMode write SetQualityMode;
    property ForcedBitrate: Integer read FForcedBitrate write SetForcedBitrate;
    property ForcedResolution: string read FForcedResolution write SetForcedResolution;

  published
    // Опубликованные свойства
    property LibPath: string read FLibPath write FLibPath;
    property MediaURL: string read FMediaURL write SetMediaURL;
    property AutoPlay: Boolean read FAutoPlay write FAutoPlay default True;
    property Volume: Integer read FVolume write SetVolume default 100;
    property UserAgent: string read FUserAgent write SetUserAgent;
    property Referer: string read FReferer write SetReferer;
    property HttpHeaders: TStringList read FHttpHeaders write SetHttpHeaders;
    property State: TVlcState read FState;

    // События
    property OnLoading: TVlcNotifyEvent read FOnLoading write FOnLoading;
    property OnPlaying: TVlcNotifyEvent read FOnPlaying write FOnPlaying;
    property OnPaused: TVlcNotifyEvent read FOnPaused write FOnPaused;
    property OnStopped: TVlcNotifyEvent read FOnStopped write FOnStopped;
    property OnEndReached: TVlcNotifyEvent read FOnEndReached write FOnEndReached;
    property OnError: TVlcNotifyEvent read FOnError write FOnError;
    property OnLog: TVlcLogEvent read FOnLog write FOnLog;
    property OnLoadingProgress: TVlcProgressEvent read FOnLoadingProgress write FOnLoadingProgress;
    property OnBuffering: TVlcProgressEvent read FOnBuffering write FOnBuffering;
    property OnQualityChanged: TVlcNotifyEvent read FOnQualityChanged write FOnQualityChanged;
  end;

// Константы событий VLC
const
  libvlc_MediaPlayerBuffering = 3;
  libvlc_MediaPlayerPlaying = 4;
  libvlc_MediaPlayerPaused = 5;
  libvlc_MediaPlayerStopped = 6;
  libvlc_MediaPlayerEndReached = 7;
  libvlc_MediaPlayerEncounteredError = 8;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Samples', [TVlcPlayerEx]);
end;

// Callback функция для обработки событий VLC
procedure VlcEventCallback(p_event: Pointer; user_data: Pointer); cdecl;
var
  Player: TVlcPlayerEx;
  EventType: Integer;
begin
  Player := TVlcPlayerEx(user_data);
  if not Assigned(Player) then Exit;

  // Получаем тип события
  EventType := PInteger(p_event)^;

  case EventType of
    libvlc_MediaPlayerBuffering:
      begin
        Player.Log('🔄 Буферизация...');
        if Assigned(Player.FOnBuffering) then
          Player.FOnBuffering(Player, 50);
      end;

    libvlc_MediaPlayerPlaying:
      begin
        Player.SetState(vlcPlaying);
        Player.FIsLoading := False;
        Player.FLoadingProgress := 100;
        if Assigned(Player.FOnLoadingProgress) then
          Player.FOnLoadingProgress(Player, 100);
      end;

    libvlc_MediaPlayerPaused:
      begin
        Player.SetState(vlcPaused);
      end;

    libvlc_MediaPlayerStopped:
      begin
        Player.SetState(vlcStopped);
        Player.FIsLoading := False;
        Player.FLoadingProgress := 0;
      end;

    libvlc_MediaPlayerEndReached:
      begin
        Player.Log('🏁 Воспроизведение завершено');
        if Assigned(Player.FOnEndReached) then
          Player.FOnEndReached(Player);
      end;

    libvlc_MediaPlayerEncounteredError:
      begin
        Player.SetState(vlcError);
        Player.Log('❌ Ошибка воспроизведения');
        Player.FIsLoading := False;
        Player.FLoadingProgress := 0;
      end;
  end;
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
  FAutoDetectProtectedStreams := True;
  FForceWinkHeaders := False;
  FIsLoading := False;
  FLoadingProgress := 0;
  FQualityMode := qmAuto;
  FForcedBitrate := 0;
  FForcedResolution := '';

  // Устанавливаем базовые заголовки по умолчанию
  SetBasicHeaders;
end;

destructor TVlcPlayerEx.Destroy;
begin
  // Обнуляем события для избежания access violation
  FOnLog := nil;
  FOnLoadingProgress := nil;
  FOnBuffering := nil;
  FOnQualityChanged := nil;

  // Освобождаем ресурсы VLC
  FreeVLC;

  // Освобождаем объекты
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

procedure TVlcPlayerEx.SetQualityMode(const Value: TVlcQualityMode);
begin
  if FQualityMode <> Value then
  begin
    FQualityMode := Value;
    Log('✅ Режим качества установлен: ' + GetEnumName(TypeInfo(TVlcQualityMode), Ord(Value)));

    // Применяем настройки качества если плеер активен
    if IsPlaying or FIsLoading then
      ApplyQualitySettings;

    if Assigned(FOnQualityChanged) then
      FOnQualityChanged(Self);
  end;
end;

procedure TVlcPlayerEx.SetForcedBitrate(const Value: Integer);
begin
  if FForcedBitrate <> Value then
  begin
    FForcedBitrate := Value;
    if FQualityMode = qmCustom then
    begin
      Log('✅ Установлена битрейт: ' + IntToStr(Value) + ' kbps');
      ApplyQualitySettings;
    end;
  end;
end;

procedure TVlcPlayerEx.SetForcedResolution(const Value: string);
begin
  if FForcedResolution <> Value then
  begin
    FForcedResolution := Value;
    if FQualityMode = qmCustom then
    begin
      Log('✅ Установлено разрешение: ' + Value);
      ApplyQualitySettings;
    end;
  end;
end;

procedure TVlcPlayerEx.StopCurrentStream;
begin
  if FIsLoading then
  begin
    Log('⏹️ Прерывание загрузки текущего потока...');
  end;

  if FPlayer <> nil then
  begin
    T_libvlc_media_player_stop(FPlayer);
  end;

  FIsLoading := False;
  FLoadingProgress := 0;
  SetState(vlcStopped);
end;

procedure TVlcPlayerEx.SetupEventHandlers;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_event_manager) then
  begin
    FEventManager := T_libvlc_media_player_event_manager(FPlayer);
    if FEventManager <> nil then
    begin
      // Регистрируем обработчики событий VLC
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerPlaying, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerPaused, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerStopped, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerEndReached, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerEncounteredError, @VlcEventCallback, Self);
      T_libvlc_event_attach(FEventManager, libvlc_MediaPlayerBuffering, @VlcEventCallback, Self);
    end;
  end;
end;

procedure TVlcPlayerEx.UpdateLoadingProgress;
begin
  if not FIsLoading then Exit;

  // Имитация прогресса загрузки
  if FLoadingProgress < 90 then
    FLoadingProgress := FLoadingProgress + 10
  else if FLoadingProgress < 100 then
    FLoadingProgress := FLoadingProgress + 1;

  if Assigned(FOnLoadingProgress) then
    FOnLoadingProgress(Self, FLoadingProgress);

  Log('📥 Загрузка: ' + IntToStr(FLoadingProgress) + '%');

  if (FLoadingProgress >= 100) and (FState <> vlcPlaying) then
  begin
    FIsLoading := False;
    Log('✅ Загрузка завершена, ожидание воспроизведения...');
  end;
end;

function TVlcPlayerEx.GetQualityOptions: TStringList;
begin
  Result := TStringList.Create;
  try
    case FQualityMode of
      qmAuto:
        begin
          // Автоматический выбор качества
          Result.Add(':network-caching=3000');
          Result.Add(':live-caching=3000');
          Log('🎯 Режим качества: Автоматический');
        end;

      qmBest:
        begin
          // Лучшее качество - максимальные настройки
          Result.Add(':network-caching=5000');
          Result.Add(':live-caching=5000');
          Result.Add(':sout-x264-preset=slow');
          Result.Add(':sout-x264-tune=film');
          Result.Add(':crf=18'); // Высокое качество
          Result.Add(':prefer-hw-decoder=1');
          Log('🎯 Режим качества: Лучшее (максимальное)');
        end;

      qmWorst:
        begin
          // Худшее качество - минимальные настройки для слабых соединений
          Result.Add(':network-caching=1000');
          Result.Add(':live-caching=1000');
          Result.Add(':sout-x264-preset=ultrafast');
          Result.Add(':crf=28'); // Низкое качество
          Result.Add(':drop-late-frames');
          Result.Add(':skip-frames');
          Log('🎯 Режим качества: Худшее (экономное)');
        end;

      qmCustom:
        begin
          // Пользовательские настройки
          Result.Add(':network-caching=3000');
          Result.Add(':live-caching=3000');

          if FForcedBitrate > 0 then
          begin
            Result.Add(':sout-x264-bitrate=' + IntToStr(FForcedBitrate));
            Log('🎯 Режим качества: Пользовательский (битрейт: ' + IntToStr(FForcedBitrate) + 'kbps)');
          end;

          if FForcedResolution <> '' then
          begin
            Result.Add(':sout-x264-resolution=' + FForcedResolution);
            Log('🎯 Режим качества: Пользовательский (разрешение: ' + FForcedResolution + ')');
          end;
        end;
    end;

    // Общие настройки для HLS потоков
    Result.Add(':hls-prefer-native');

    case FQualityMode of
      qmBest:
        begin
          Result.Add(':hls-preferred-resolution=1080');
          Result.Add(':hls-bitrate=5000000'); // 5 Mbps
        end;
      qmWorst:
        begin
          Result.Add(':hls-preferred-resolution=360');
          Result.Add(':hls-bitrate=500000'); // 500 kbps
        end;
      else
        begin
          Result.Add(':hls-preferred-resolution=720');
          Result.Add(':hls-bitrate=2000000'); // 2 Mbps
        end;
    end;

  except
    Result.Free;
    raise;
  end;
end;

procedure TVlcPlayerEx.ApplyQualitySettings;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_add_option) and (FMedia <> nil) then
  begin
    var QualityOptions := GetQualityOptions;
    try
      for var I := 0 to QualityOptions.Count - 1 do
      begin
        T_libvlc_media_add_option(FMedia, PAnsiChar(UTF8Encode(QualityOptions[I])));
        Log('Добавлена опция качества: ' + QualityOptions[I]);
      end;
    finally
      QualityOptions.Free;
    end;
  end;
end;

procedure TVlcPlayerEx.ForceBestQuality;
begin
  QualityMode := qmBest;
end;

procedure TVlcPlayerEx.ForceWorstQuality;
begin
  QualityMode := qmWorst;
end;

procedure TVlcPlayerEx.ForceAutoQuality;
begin
  QualityMode := qmAuto;
end;

procedure TVlcPlayerEx.ForceCustomQuality(Bitrate: Integer; const Resolution: string);
begin
  FForcedBitrate := Bitrate;
  FForcedResolution := Resolution;
  QualityMode := qmCustom;
end;

// Реализация недостающих методов

procedure TVlcPlayerEx.SetMediaURL(const Value: string);
begin
  if FMediaURL <> Value then
  begin
    FMediaURL := Value;
    if Value <> '' then
      LoadMedia(Value);
  end;
end;

procedure TVlcPlayerEx.SetVolume(Value: Integer);
begin
  if Value < 0 then Value := 0;
  if Value > 100 then Value := 100;

  if FVolume <> Value then
  begin
    FVolume := Value;
    if (FPlayer <> nil) and Assigned(T_libvlc_audio_set_volume) then
    begin
      T_libvlc_audio_set_volume(FPlayer, Value);
      Log('🔊 Громкость установлена: ' + IntToStr(Value));
    end;
  end;
end;

procedure TVlcPlayerEx.SetUserAgent(const Value: string);
begin
  if FUserAgent <> Value then
  begin
    FUserAgent := Value;
    Log('🌐 User-Agent установлен: ' + Value);
  end;
end;

procedure TVlcPlayerEx.SetReferer(const Value: string);
begin
  if FReferer <> Value then
  begin
    FReferer := Value;
    Log('🔗 Referer установлен: ' + Value);
  end;
end;

procedure TVlcPlayerEx.SetHttpHeaders(const Value: TStringList);
begin
  FHttpHeaders.Assign(Value);
end;

procedure TVlcPlayerEx.SetState(Value: TVlcState);
begin
  if FState <> Value then
  begin
    FState := Value;
    Log('📊 Состояние изменено: ' + GetEnumName(TypeInfo(TVlcState), Ord(Value)));

    // Вызываем соответствующие события
    case Value of
      vlcPlaying:
        if Assigned(FOnPlaying) then FOnPlaying(Self);
      vlcPaused:
        if Assigned(FOnPaused) then FOnPaused(Self);
      vlcStopped:
        if Assigned(FOnStopped) then FOnStopped(Self);
      vlcError:
        if Assigned(FOnError) then FOnError(Self);
    end;
  end;
end;

function TVlcPlayerEx.BuildVlcOptions: TStringList;
begin
  Result := TStringList.Create;
  try
    // Базовые опции для сетевых потоков
    Result.Add(':network-caching=3000');
    Result.Add(':live-caching=3000');

    // HTTP заголовки
    if FUserAgent <> '' then
      Result.Add(':http-user-agent=' + FUserAgent);

    if FReferer <> '' then
      Result.Add(':http-referrer=' + FReferer);

    // Дополнительные заголовки
    for var I := 0 to FHttpHeaders.Count - 1 do
    begin
      if FHttpHeaders.Names[I] <> '' then
        Result.Add(':http-extra-header=' + FHttpHeaders.Names[I] + ': ' + FHttpHeaders.ValueFromIndex[I]);
    end;

  except
    Result.Free;
    raise;
  end;
end;

function TVlcPlayerEx.IsProtectedStream(const AUrl: string): Boolean;
begin
  // Простая эвристика для определения защищенных потоков
  Result := (Pos('wink.', AUrl) > 0) or
            (Pos('protected.', AUrl) > 0) or
            (Pos('secure.', AUrl) > 0) or
            (Pos('premium.', AUrl) > 0);
end;

function TVlcPlayerEx.TestStreamProtection(const AUrl: string): Boolean;
begin
  // Здесь можно реализовать более сложную логику проверки
  // Пока возвращаем результат простой эвристики
  Result := IsProtectedStream(AUrl);
end;

procedure TVlcPlayerEx.ApplyAppropriateHeaders(const AUrl: string);
begin
  if FAutoDetectProtectedStreams and TestStreamProtection(AUrl) then
  begin
    Log('🛡️ Обнаружен защищенный поток, применяем специальные заголовки');
    SetWinkHeaders;
  end
  else if FForceWinkHeaders then
  begin
    Log('🛡️ Принудительно применяем Wink заголовки');
    SetWinkHeaders;
  end
  else
  begin
    Log('🌐 Применяем стандартные заголовки');
    SetBasicHeaders;
  end;
end;

procedure TVlcPlayerEx.SetBasicHeaders;
begin
  FUserAgent := 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  FReferer := '';
  ClearHttpHeaders;
  AddHttpHeader('Accept', '*/*');
  AddHttpHeader('Accept-Language', 'en-US,en;q=0.9');
  AddHttpHeader('Accept-Encoding', 'gzip, deflate, br');
end;

procedure TVlcPlayerEx.SetWinkHeaders;
begin
  FUserAgent := 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  FReferer := 'https://wink.ru/';
  ClearHttpHeaders;
  AddHttpHeader('Accept', '*/*');
  AddHttpHeader('Accept-Language', 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7');
  AddHttpHeader('Accept-Encoding', 'gzip, deflate, br');
  AddHttpHeader('Origin', 'https://wink.ru');
  AddHttpHeader('Sec-Fetch-Dest', 'empty');
  AddHttpHeader('Sec-Fetch-Mode', 'cors');
  AddHttpHeader('Sec-Fetch-Site', 'cross-site');
end;

procedure TVlcPlayerEx.AddHttpHeader(const AName, AValue: string);
begin
  FHttpHeaders.Values[AName] := AValue;
end;

procedure TVlcPlayerEx.ClearHttpHeaders;
begin
  FHttpHeaders.Clear;
end;

procedure TVlcPlayerEx.InitVLC;
var
  Args: array of PAnsiChar;
  I: Integer;
  LibName: string;
begin
  if IsInitialized then Exit;

  // Определяем путь к библиотеке
  if FLibPath = '' then
    LibName := 'libvlc.dll'
  else
    LibName := FLibPath;

  // Загружаем библиотеку
  FLibHandle := LoadLibrary(PChar(LibName));
  if FLibHandle = 0 then
    raise Exception.Create('Не удалось загрузить библиотеку VLC: ' + LibName + '. Ошибка: ' + GetLastErrorText);

  // Загружаем функции
  LoadFunctions;

  // Подготавливаем аргументы для инициализации VLC
  SetLength(Args, 2);
  Args[0] := PAnsiChar(UTF8Encode('--intf=dummy')); // Отключаем интерфейс
  Args[1] := nil;

  // Создаем экземпляр VLC
  FInstance := T_libvlc_new(1, @Args[0]);
  if FInstance = nil then
    raise Exception.Create('Не удалось создать экземпляр VLC');

  Log('✅ VLC инициализирован успешно');
end;

procedure TVlcPlayerEx.LoadFunctions;
begin
  // Загружаем указатели на функции из библиотеки VLC
  @T_libvlc_new := GetProcAddress(FLibHandle, 'libvlc_new');
  @T_libvlc_release := GetProcAddress(FLibHandle, 'libvlc_release');
  @T_libvlc_media_new_path := GetProcAddress(FLibHandle, 'libvlc_media_new_path');
  @T_libvlc_media_new_location := GetProcAddress(FLibHandle, 'libvlc_media_new_location');
  @T_libvlc_media_release := GetProcAddress(FLibHandle, 'libvlc_media_release');
  @T_libvlc_media_player_new_from_media := GetProcAddress(FLibHandle, 'libvlc_media_player_new_from_media');
  @T_libvlc_media_player_release := GetProcAddress(FLibHandle, 'libvlc_media_player_release');
  @T_libvlc_media_player_play := GetProcAddress(FLibHandle, 'libvlc_media_player_play');
  @T_libvlc_media_player_pause := GetProcAddress(FLibHandle, 'libvlc_media_player_pause');
  @T_libvlc_media_player_stop := GetProcAddress(FLibHandle, 'libvlc_media_player_stop');
  @T_libvlc_media_player_set_hwnd := GetProcAddress(FLibHandle, 'libvlc_media_player_set_hwnd');
  @T_libvlc_audio_set_volume := GetProcAddress(FLibHandle, 'libvlc_audio_set_volume');
  @T_libvlc_media_add_option := GetProcAddress(FLibHandle, 'libvlc_media_add_option');
  @T_libvlc_media_player_get_length := GetProcAddress(FLibHandle, 'libvlc_media_player_get_length');
  @T_libvlc_media_player_get_time := GetProcAddress(FLibHandle, 'libvlc_media_player_get_time');
  @T_libvlc_media_player_get_position := GetProcAddress(FLibHandle, 'libvlc_media_player_get_position');
  @T_libvlc_event_attach := GetProcAddress(FLibHandle, 'libvlc_event_attach');
  @T_libvlc_media_player_event_manager := GetProcAddress(FLibHandle, 'libvlc_media_player_event_manager');

  // Проверяем что основные функции загружены
  if not Assigned(T_libvlc_new) or not Assigned(T_libvlc_media_new_location) then
    raise Exception.Create('Не удалось загрузить основные функции VLC');
end;

procedure TVlcPlayerEx.FreeVLC;
begin
  // Останавливаем и освобождаем плеер
  if FPlayer <> nil then
  begin
    T_libvlc_media_player_stop(FPlayer);
    T_libvlc_media_player_release(FPlayer);
    FPlayer := nil;
  end;

  // Освобождаем медиа-объект
  if FMedia <> nil then
  begin
    T_libvlc_media_release(FMedia);
    FMedia := nil;
  end;

  // Освобождаем экземпляр VLC
  if FInstance <> nil then
  begin
    T_libvlc_release(FInstance);
    FInstance := nil;
  end;

  // Выгружаем библиотеку
  if FLibHandle <> 0 then
  begin
    FreeLibrary(FLibHandle);
    FLibHandle := 0;
  end;

  // Сбрасываем состояние
  FState := vlcIdle;
  FIsLoading := False;
  FLoadingProgress := 0;
end;

function TVlcPlayerEx.IsInitialized: Boolean;
begin
  Result := (FInstance <> nil) and (FLibHandle <> 0);
end;

function TVlcPlayerEx.IsPlaying: Boolean;
begin
  Result := FState = vlcPlaying;
end;

function TVlcPlayerEx.GetDuration: Int64;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_get_length) then
    Result := T_libvlc_media_player_get_length(FPlayer)
  else
    Result := 0;
end;

function TVlcPlayerEx.GetPosition: Int64;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_get_time) then
    Result := T_libvlc_media_player_get_time(FPlayer)
  else
    Result := 0;
end;

function TVlcPlayerEx.GetPlaybackPosition: Single;
begin
  if (FPlayer <> nil) and Assigned(T_libvlc_media_player_get_position) then
    Result := T_libvlc_media_player_get_position(FPlayer)
  else
    Result := 0;
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

  // ПРЕРЫВАЕМ ТЕКУЩИЙ ПОТОК ПЕРЕД ЗАГРУЗКОЙ НОВОГО
  StopCurrentStream;

  // АВТОМАТИЧЕСКИ ПРИМЕНЯЕМ ПРАВИЛЬНЫЕ ЗАГОЛОВКИ ДЛЯ ТИПА ПОТОКА
  ApplyAppropriateHeaders(APath);

  SetState(vlcLoading);
  FIsLoading := True;
  FLoadingProgress := 0;

  if Assigned(FOnLoading) then
    FOnLoading(Self);

  if Assigned(FOnLoadingProgress) then
    FOnLoadingProgress(Self, 0);

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

    // Создаем медиа-объект в зависимости от типа URL
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

        // ПРИМЕНЯЕМ НАСТРОЙКИ КАЧЕСТВА
        ApplyQualitySettings;
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

    // Создаем плеер из медиа-объекта
    FPlayer := T_libvlc_media_player_new_from_media(FMedia);
    if FPlayer = nil then
      raise Exception.Create('Не удалось создать медиаплеер');

    // Настраиваем обработчики событий
    SetupEventHandlers;

    // Устанавливаем окно вывода
    if FVideoHandle <> 0 then
    begin
      T_libvlc_media_player_set_hwnd(FPlayer, Pointer(FVideoHandle));
      Log('✅ Handle окна установлен: ' + IntToStr(FVideoHandle));
    end;

    // Устанавливаем громкость
    if Assigned(T_libvlc_audio_set_volume) then
      T_libvlc_audio_set_volume(FPlayer, FVolume);

    UpdateLoadingProgress;

    Log('✅ Медиа успешно загружено');

    // Автовоспроизведение если включено
    if FAutoPlay then
      Play
    else
      SetState(vlcPaused);

  except
    on E: Exception do
    begin
      SetState(vlcError);
      FIsLoading := False;
      FLoadingProgress := 0;
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
    Log('▶️ Команда воспроизведения отправлена');
  end
  else
  begin
    SetState(vlcError);
    FIsLoading := False;
    FLoadingProgress := 0;
    Log('❌ Ошибка воспроизведения, код: ' + IntToStr(ResultCode));
    if Assigned(FOnError) then
      FOnError(Self);
  end;
end;

procedure TVlcPlayerEx.Pause;
begin
  if FPlayer = nil then Exit;

  T_libvlc_media_player_pause(FPlayer);
  Log('⏸️ Команда паузы отправлена');
end;

procedure TVlcPlayerEx.Stop;
begin
  StopCurrentStream;
  Log('⏹️ Воспроизведение остановлено');
  if Assigned(FOnStopped) then
    FOnStopped(Self);
end;

end.
