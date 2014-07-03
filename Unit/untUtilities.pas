unit untUtilities;

interface
uses
  Windows,
  Forms,
  SysUtils,
  Registry,
  Classes,
  HotLog,
  ShlObj,
  ActiveX,
  ShellAPI,
  ComObj;

procedure SplitString(str: string; Delimiter: string; var strList: TStringList);
procedure PostKeyEx32(key: Word; const shift: TShiftState; specialkey: Boolean);
function IsRunningInstance(const MutexName: string): Boolean;
function SetAutoRun(ApplicationName: string; ExecutablePath: string; AutoRun: Boolean = True): Boolean;
function GetAutoRunItemPath(ApplicationName: string): string;
function GetFileModifyTime(const FileName: string): string;
function ReduceWorkingSize: Boolean;
function WriteLineToFile(FileName, Line: string): Boolean;
function AddMeToShortCutMenu(IsAdd: Boolean): Boolean;
function AddMeToSendTo(Name: string; IsAdd: Boolean): Boolean;
function SendKeys(SendKeysString: PChar; Translate, Wait: Boolean): Boolean;
function GetSendToDir: string;
function CreateLink(FileName, Arg, LinkPath, LinkName, Description: string): Boolean;
function ResolveLink(ALinkFile: string): string;
function IsNumericStr(const str: string): Boolean;
function GetFileListInDir(var List: TStringList; const Dir: string;
  Ext: string = '*'; IsPlusDir: Boolean = True): Boolean;
function ExtractRes(ResType, ResName, ResNewName: string): Boolean;

//��������
procedure QuickSort(var SortNum: array of integer; p, r: integer);

//�Ϸ�֧��
const
  SC_DRAGMOVE: LongInt = $F012;
function GetDragFileCount(hDrop: Cardinal): Integer;
function GetDragFileName(hDrop: Cardinal; FileIndex: Integer = 1): string;

//�����ʽת��
function Utf8Encode(const WS: WideString): UTF8String;
function Big52Gb(Str: string): string;
function Gb2Big5(Str: string): string;
function UnicodeDecode(Str: WideString; CodePage: integer): string;
function UnicodeEncode(Str: string; CodePage: integer): WideString;

//��������������
function GetUTF8QueryString(Keyword: string): string;
function GetURLQueryString(Keyword: string): string;

//Trace
procedure InitLogger;
procedure TraceErr(const Msg: string); overload;
procedure TraceMsg(const Msg: string); overload;
procedure TraceMsg(const AFormat: string; Args: array of const); overload;

function SetLayeredWindowAttributes(hwnd: HWND; crKey: Longint; bAlpha: byte; dwFlags: longint): longint;
stdcall; external user32;

var
  MutexHandle: THandle;

implementation
uses
  untALTRunOption;

function IsRunningInstance(const MutexName: string): Boolean;
begin
  MutexHandle := CreateMutex(nil, True, PChar(MutexName));
  Result := (MutexHandle = 0) or (GetLastError = ERROR_ALREADY_EXISTS);

  if Result = False then
    MutexHandle := OpenMutex(MUTEX_ALL_ACCESS, False, PChar(MutexName));
end;

function ReduceWorkingSize: Boolean;
begin
  if Win32Platform = VER_PLATFORM_WIN32_NT then
  begin
    SetProcessWorkingSetSize(GetCurrentProcess, $FFFFFFFF, $FFFFFFFF);
    Application.ProcessMessages;
    Result := True;
  end
  else
    Result := False;
end;

function SetAutoRun(ApplicationName: string; ExecutablePath: string; AutoRun: Boolean = True): Boolean;
var
  Reg: TRegistry;
begin
  Result := False;

  Reg := TRegistry.Create;
  try
    try
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      Reg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', False);
      //HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList
      //AllUsersProfile=All Users
      if AutoRun then
        Reg.WriteString(ApplicationName, ExecutablePath)
      else
        Reg.DeleteValue(ApplicationName);

      Reg.CloseKey;
      Result := True;
    except
      Exit;
    end;
  finally
    Reg.Free;
  end;
end;

function GetAutoRunItemPath(ApplicationName: string): string;
var
  Reg: TRegistry;
begin
  Result := '';

  Reg := TRegistry.Create;
  try
    try
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      Reg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', False);

      Result := Reg.ReadString(ApplicationName);

      Reg.CloseKey;
    except
      Exit;
    end;
  finally
    Reg.Free;
  end;
end;

function GetFileModifyTime(const FileName: string): string;
var
  f: file of Byte;
begin
  //Win2003��XP�����ڸ�ʽ��ͬ,�� 2007-11-14 ���� 09:40:02
  //Result := DateTimeToStr(FileDateToDateTime(FileAge(FileName)));
  DateTimeToString(Result, 'yyyy-mm-dd hh:mm:ss', FileDateToDateTime(FileAge(FileName)));
end;

procedure SplitString(str: string; Delimiter: string; var strList: TStringList);
var
  DelimiterPos: Integer;
begin
  //Count := ExtractStrings([Delimiter], [' '], PChar(str), strList);

  strList.Clear;
  if str = '' then Exit;

  DelimiterPos := pos(Delimiter, str);
  while DelimiterPos > 0 do
  begin
    strList.Add(Copy(str, 1, DelimiterPos - 1));
    Delete(str, 1, DelimiterPos + Length(Delimiter) - 1);
    DelimiterPos := Pos(Delimiter, str);
  end;
  strList.Add(str);
end;

function WriteLineToFile(FileName, Line: string): Boolean;
var
  MyFile: TextFile;
begin
  Result := False;

  try
    try
      AssignFile(MyFile, FileName);
      ReWrite(MyFile);
      WriteLn(MyFile, Line);
      Result := True;
    except
      Exit;
    end;
  finally
    CloseFile(MyFile);
  end;
end;

function AddMeToShortCutMenu(IsAdd: Boolean): Boolean;
const
  APP_KEY = 'Add To ALTRun';
var
  Reg: TRegistry;
begin
  Result := False;

  Reg := TRegistry.Create;
  try
    try
      //HKEY_CLASSES_ROOT\*\shell
      Reg.RootKey := HKEY_CLASSES_ROOT;
      Reg.OpenKey('*\shell', False);
      if IsAdd then
      begin
        Reg.CreateKey(APP_KEY);
        Reg.OpenKey(APP_KEY, True);
        Reg.CreateKey('command');
        Reg.OpenKey('command', True);
        Reg.WriteString('', Format('"%s" "%%1"', [Application.ExeName]));
      end
      else
        Reg.DeleteKey(APP_KEY);

      Reg.CloseKey;
      Result := True;
    except
      Exit;
    end;
  finally
    Reg.Free;
  end;
end;

function AddMeToSendTo(Name: string; IsAdd: Boolean): Boolean;
begin
  Result := False;

  if IsAdd then
    Result := CreateLink(Application.ExeName, '', GetSendToDir, Name, '')
  else
    Result := DeleteFile(GetSendToDir + '\' + Name + '.lnk');
end;

procedure PostKeyEx32(key: Word; const shift: TShiftState; specialkey: Boolean);
{************************************************************
* Procedure PostKeyEx32
*
* Parameters:
* key : virtual keycode of the key to send. For printable
* keys this is simply the ANSI code (Ord(character)).
* shift : state of the modifier keys. This is a set, so you
* can set several of these keys (shift, control, alt,
* mouse buttons) in tandem. The TShiftState type is
* declared in the Classes Unit.
* specialkey: normally this should be False. Set it to True to
* specify a key on the numeric keypad, for example.
* Description:
* Uses keybd_event to manufacture a series of key events matching
* the passed parameters. The events go to the control with focus.
* Note that for characters key is always the upper-case version of
* the character. Sending without any modifier keys will result in
* a lower-case character, sending it with [ssShift] will result
* in an upper-case character!
*Created: 17.7.98 by P. Below
************************************************************}

type
  TShiftKeyInfo = record
    shift: Byte;
    vkey: Byte;
  end;
  byteset = set of 0..7;
const
  shiftkeys: array[1..3] of TShiftKeyInfo =
  ((shift: Ord(ssCtrl); vkey: VK_CONTROL),
    (shift: Ord(ssShift); vkey: VK_SHIFT),
    (shift: Ord(ssAlt); vkey: VK_MENU));
var
  flag: DWORD;
  bShift: ByteSet absolute shift;
  i: Integer;
begin
  for i := 1 to 3 do
  begin
    if shiftkeys[i].shift in bShift then
      keybd_event(shiftkeys[i].vkey, MapVirtualKey(shiftkeys[i].vkey, 0), 0, 0);
  end;                                                 { For }
  if specialkey then
    flag := KEYEVENTF_EXTENDEDKEY
  else
    flag := 0;

  keybd_event(key, MapvirtualKey(key, 0), flag, 0);
  flag := flag or KEYEVENTF_KEYUP;
  keybd_event(key, MapvirtualKey(key, 0), flag, 0);

  for i := 3 downto 1 do
  begin
    if shiftkeys[i].shift in bShift then
      keybd_event(shiftkeys[i].vkey, MapVirtualKey(shiftkeys[i].vkey, 0), KEYEVENTF_KEYUP, 0);
  end;                                                 { For }
end;                                                   { PostKeyEx32 }

(*
 Converts   a   string   of   characters   and   key   names   to   keyboard   events   and
 passes   them   to   Windows.

 Example   syntax:

 SendKeys('abc123{left}{left}{left}def{end}456{left   6}ghi{end}789',   True);
 *)

function SendKeys(SendKeysString: PChar; Translate, Wait: Boolean): Boolean;
type
  WBytes = array[0..pred(SizeOf(Word))] of Byte;

  TSendKey = record
    Name: ShortString;
    VKey: Byte;
  end;

const
  {Array   of   keys   that   SendKeys   recognizes.

  If   you   add   to   this   list,   you   must   be   sure   to   keep   it   sorted   alphabetically
  by   Name   because   a   binary   search   routine   is   used   to   scan   it.}

  MaxSendKeyRecs = 41;
  SendKeyRecs: array[1..MaxSendKeyRecs] of TSendKey =
  (
    (Name: 'BKSP'; VKey: VK_BACK),
    (Name: 'BS'; VKey: VK_BACK),
    (Name: 'BACKSPACE'; VKey: VK_BACK),
    (Name: 'BREAK'; VKey: VK_CANCEL),
    (Name: 'CAPSLOCK'; VKey: VK_CAPITAL),
    (Name: 'CLEAR'; VKey: VK_CLEAR),
    (Name: 'DEL'; VKey: VK_DELETE),
    (Name: 'DELETE'; VKey: VK_DELETE),
    (Name: 'DOWN'; VKey: VK_DOWN),
    (Name: 'END'; VKey: VK_END),
    (Name: 'ENTER'; VKey: VK_RETURN),
    (Name: 'ESC'; VKey: VK_ESCAPE),
    (Name: 'ESCAPE'; VKey: VK_ESCAPE),
    (Name: 'F1'; VKey: VK_F1),
    (Name: 'F10'; VKey: VK_F10),
    (Name: 'F11'; VKey: VK_F11),
    (Name: 'F12'; VKey: VK_F12),
    (Name: 'F13'; VKey: VK_F13),
    (Name: 'F14'; VKey: VK_F14),
    (Name: 'F15'; VKey: VK_F15),
    (Name: 'F16'; VKey: VK_F16),
    (Name: 'F2'; VKey: VK_F2),
    (Name: 'F3'; VKey: VK_F3),
    (Name: 'F4'; VKey: VK_F4),
    (Name: 'F5'; VKey: VK_F5),
    (Name: 'F6'; VKey: VK_F6),
    (Name: 'F7'; VKey: VK_F7),
    (Name: 'F8'; VKey: VK_F8),
    (Name: 'F9'; VKey: VK_F9),
    (Name: 'HELP'; VKey: VK_HELP),
    (Name: 'HOME'; VKey: VK_HOME),
    (Name: 'INS'; VKey: VK_INSERT),
    (Name: 'LEFT'; VKey: VK_LEFT),
    (Name: 'NUMLOCK'; VKey: VK_NUMLOCK),
    (Name: 'PGDN'; VKey: VK_NEXT),
    (Name: 'PGUP'; VKey: VK_PRIOR),
    (Name: 'PRTSC'; VKey: VK_PRINT),
    (Name: 'RIGHT'; VKey: VK_RIGHT),
    (Name: 'SCROLLLOCK'; VKey: VK_SCROLL),
    (Name: 'TAB'; VKey: VK_TAB),
    (Name: 'UP'; VKey: VK_UP)
    );

  {Extra   VK   constants   missing   from   Delphi's   Windows   API   interface}
  VK_NULL = 0;
  VK_SemiColon = 186;
  VK_Equal = 187;
  VK_Comma = 188;
  VK_Minus = 189;
  VK_Period = 190;
  VK_Slash = 191;
  VK_BackQuote = 192;
  VK_LeftBracket = 219;
  VK_BackSlash = 220;
  VK_RightBracket = 221;
  VK_Quote = 222;
  VK_Last = VK_Quote;

  ExtendedVKeys: set of byte =
  [VK_Up,
    VK_Down,
    VK_Left,
    VK_Right,
    VK_Home,
    VK_End,
    VK_Prior,                                          {PgUp}
  VK_Next,                                             {PgDn}
  VK_Insert,
    VK_Delete];

const
  INVALIDKEY = $FFFF {Unsigned   -1};
  VKKEYSCANSHIFTON = $01;
  VKKEYSCANCTRLON = $02;
  VKKEYSCANALTON = $04;
  UNITNAME = 'SendKeys';
  WM_KEYFIRST = $0100;
  WM_KEYLAST = $0108;
var
  UsingParens, ShiftDown, ControlDown, AltDown, FoundClose: Boolean;
  PosSpace: Byte;
  I, L: Integer;
  NumTimes, MKey: Word;
  KeyString: string[20];
  AllocationSize: Integer;

  procedure DisplayMessage(Message: PChar);
  begin
    MessageBox(0, Message, UNITNAME, 0);
  end;

  function BitSet(BitTable, BitMask: Byte): Boolean;
  begin
    Result := ByteBool(BitTable and BitMask);
  end;

  procedure SetBit(var BitTable: Byte; BitMask: Byte);
  begin
    BitTable := BitTable or Bitmask;
  end;

  procedure KeyboardEvent(VKey, ScanCode: Byte; Flags: Longint);
  var
    KeyboardMsg: TMsg;
  begin
    keybd_event(VKey, ScanCode, Flags, 0);
    if (Wait) then while (PeekMessage(KeyboardMsg, 0, WM_KEYFIRST, WM_KEYLAST, PM_REMOVE)) do
      begin
        TranslateMessage(KeyboardMsg);
        DispatchMessage(KeyboardMsg);
      end;
  end;

  procedure SendKeyDown(VKey: Byte; NumTimes: Word; GenUpMsg: Boolean);
  var
    Cnt: Word;
    ScanCode: Byte;
    NumState: Boolean;
    KeyBoardState: TKeyboardState;
  begin
    if (VKey = VK_NUMLOCK) then
    begin
      NumState := ByteBool(GetKeyState(VK_NUMLOCK) and 1);
      GetKeyBoardState(KeyBoardState);
      if NumState then KeyBoardState[VK_NUMLOCK] := (KeyBoardState[VK_NUMLOCK] and not 1)
      else KeyBoardState[VK_NUMLOCK] := (KeyBoardState[VK_NUMLOCK] or 1);
      SetKeyBoardState(KeyBoardState);
      exit;
    end;

    ScanCode := Lo(MapVirtualKey(VKey, 0));
    for Cnt := 1 to NumTimes do
      if (VKey in ExtendedVKeys) then
      begin
        KeyboardEvent(VKey, ScanCode, KEYEVENTF_EXTENDEDKEY);
        if (GenUpMsg) then
          KeyboardEvent(VKey, ScanCode, KEYEVENTF_EXTENDEDKEY or KEYEVENTF_KEYUP)
      end else
      begin
        KeyboardEvent(VKey, ScanCode, 0);
        if (GenUpMsg) then KeyboardEvent(VKey, ScanCode, KEYEVENTF_KEYUP);
      end;
  end;

  procedure SendKeyUp(VKey: Byte);
  var
    ScanCode: Byte;
  begin
    ScanCode := Lo(MapVirtualKey(VKey, 0));
    if (VKey in ExtendedVKeys) then
      KeyboardEvent(VKey, ScanCode, KEYEVENTF_EXTENDEDKEY and KEYEVENTF_KEYUP)
    else KeyboardEvent(VKey, ScanCode, KEYEVENTF_KEYUP);
  end;

  procedure SendKey(MKey: Word; NumTimes: Word; GenDownMsg: Boolean);
  begin
    if (BitSet(Hi(MKey), VKKEYSCANSHIFTON)) then SendKeyDown(VK_SHIFT, 1, False);
    if (BitSet(Hi(MKey), VKKEYSCANCTRLON)) then SendKeyDown(VK_CONTROL, 1, False);
    if (BitSet(Hi(MKey), VKKEYSCANALTON)) then SendKeyDown(VK_MENU, 1, False);
    SendKeyDown(Lo(MKey), NumTimes, GenDownMsg);
    if (BitSet(Hi(MKey), VKKEYSCANSHIFTON)) then SendKeyUp(VK_SHIFT);
    if (BitSet(Hi(MKey), VKKEYSCANCTRLON)) then SendKeyUp(VK_CONTROL);
    if (BitSet(Hi(MKey), VKKEYSCANALTON)) then SendKeyUp(VK_MENU);
  end;

  {Implements   a   simple   binary   search   to   locate   special   key   name   strings}

  function StringToVKey(KeyString: ShortString): Word;
  var
    Found, Collided: Boolean;
    Bottom, Top, Middle: Byte;
  begin
    Result := INVALIDKEY;
    Bottom := 1;
    Top := MaxSendKeyRecs;
    Found := false;
    Middle := (Bottom + Top) div 2;
    repeat
      Collided := ((Bottom = Middle) or (Top = Middle));
      if (KeyString = SendKeyRecs[Middle].Name) then
      begin
        Found := True;
        Result := SendKeyRecs[Middle].VKey;
      end else
      begin
        if (KeyString > SendKeyRecs[Middle].Name) then Bottom := Middle
        else Top := Middle;
        Middle := (Succ(Bottom + Top)) div 2;
      end;
    until (Found or Collided);
    if (Result = INVALIDKEY) then DisplayMessage('Invalid   Key   Name');
  end;
  procedure PopUpShiftKeys;
  begin
    if (not UsingParens) then
    begin
      if ShiftDown then SendKeyUp(VK_SHIFT);
      if ControlDown then SendKeyUp(VK_CONTROL);
      if AltDown then SendKeyUp(VK_MENU);
      ShiftDown := false;
      ControlDown := false;
      AltDown := false;
    end;
  end;

begin
  AllocationSize := MaxInt;
  Result := false;
  UsingParens := false;
  ShiftDown := false;
  ControlDown := false;
  AltDown := false;
  I := 0;
  L := StrLen(SendKeysString);
  if (L > AllocationSize) then L := AllocationSize;
  if (L = 0) then Exit;

  while (I < L) do
  begin
    if Translate then
    begin
      case SendKeysString[I] of
        '(':
          begin
            UsingParens := True;
            Inc(I);
          end;
        ')':
          begin
            UsingParens := False;
            PopUpShiftKeys;
            Inc(I);
          end;
        '%':
          begin
            AltDown := True;
            SendKeyDown(VK_MENU, 1, False);
            Inc(I);
          end;
        '+':
          begin
            ShiftDown := True;
            SendKeyDown(VK_SHIFT, 1, False);
            Inc(I);
          end;
        '^':
          begin
            ControlDown := True;
            SendKeyDown(VK_CONTROL, 1, False);
            Inc(I);
          end;
        '{':
          begin
            NumTimes := 1;
            if (SendKeysString[Succ(I)] = '{') then
            begin
              MKey := VK_LEFTBRACKET;
              SetBit(Wbytes(MKey)[1], VKKEYSCANSHIFTON);
              SendKey(MKey, 1, True);
              PopUpShiftKeys;
              Inc(I, 3);
              Continue;
            end;
            KeyString := '';
            FoundClose := False;
            while (I <= L) do
            begin
              Inc(I);
              if (SendKeysString[I] = '}') then
              begin
                FoundClose := True;
                Inc(I);
                Break;
              end;
              KeyString := KeyString + Upcase(SendKeysString[I]);
            end;
            if (not FoundClose) then
            begin
              DisplayMessage('No   Close');
              Exit;
            end;
            if (SendKeysString[I] = '}') then
            begin
              MKey := VK_RIGHTBRACKET;
              SetBit(Wbytes(MKey)[1], VKKEYSCANSHIFTON);
              SendKey(MKey, 1, True);
              PopUpShiftKeys;
              Inc(I);
              Continue;
            end;
            PosSpace := Pos('   ', KeyString);
            if (PosSpace <> 0) then
            begin
              NumTimes := StrToInt(Copy(KeyString, Succ(PosSpace), Length(KeyString) - PosSpace));
              KeyString := Copy(KeyString, 1, Pred(PosSpace));
            end;
            if (Length(KeyString) = 1) then MKey := vkKeyScan(KeyString[1])
            else MKey := StringToVKey(KeyString);
            if (MKey <> INVALIDKEY) then
            begin
              SendKey(MKey, NumTimes, True);
              PopUpShiftKeys;
              Continue;
            end;
          end;
        '~':
          begin
            SendKeyDown(VK_RETURN, 1, True);
            PopUpShiftKeys;
            Inc(I);
          end;
      else
        begin
          MKey := vkKeyScan(SendKeysString[I]);
          if (MKey <> INVALIDKEY) then
          begin
            SendKey(MKey, 1, True);
            PopUpShiftKeys;
          end else DisplayMessage('Invalid   KeyName');
          Inc(I);
        end;
      end;
    end
    else
    begin
      MKey := vkKeyScan(SendKeysString[I]);
      if (MKey <> INVALIDKEY) then
      begin
        SendKey(MKey, 1, True);
        PopUpShiftKeys;
      end else DisplayMessage('Invalid   KeyName');
      Inc(I);
    end;

  end;

  Result := true;
  PopUpShiftKeys;
end;

function GetSendToDir: string;
var
  Reg: TRegistry;
begin
  Result := '';

  Reg := TRegistry.Create;
  Reg.RootKey := HKEY_CURRENT_USER;
  try
    if Reg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders', false) then
      Result := Reg.ReadString('SendTo');
  finally
    Reg.Free;
  end;
end;

function CreateLink(FileName, Arg, LinkPath, LinkName, Description: string): Boolean;
var
  AnObj: IUnknown;
  ShellLink: IShellLink;
  AFile: IPersistFile;
  LinkFileName: WideString;
begin
  //�ο� http://school.cfan.com.cn/pro/delphi/2007-09-05/1188964507d102660.shtml

  Result := False;

  try
    //��ʼ��OLE�⣬��ʹ��OLE����ǰ������ó�ʼ��
    OleInitialize(nil);

    //���ݸ�����ClassID����һ��COM���󣬴˴��ǿ�ݷ�ʽ
    AnObj := CreateComObject(CLSID_ShellLink);

    //ǿ��ת��Ϊ��ݷ�ʽ�ӿ�
    ShellLink := AnObj as IShellLink;

    //ǿ��ת��Ϊ�ļ��ӿ�
    AFile := AnObj as IPersistFile;

    //���ÿ�ݷ�ʽ���ԣ��˴�ֻ�����˼������õ�����

    // ��ݷ�ʽ��Ŀ���ļ���һ��Ϊ��ִ���ļ�
    ShellLink.SetPath(PChar(FileName));

    // Ŀ���ļ�����
    ShellLink.SetArguments(PChar(Arg));

    //Ŀ���ļ��Ĺ���Ŀ¼
    ShellLink.SetWorkingDirectory(PChar(ExtractFilePath(FileName)));

    // ��Ŀ���ļ�������
    ShellLink.SetDescription(PChar(Description));

    //���ļ���ת��ΪWideString����
    LinkFileName := Format('%s\%s.lnk', [LinkPath, LinkName]);

    //�����ݷ�ʽ
    if AFile.Save(PWChar(LinkFileName), False) <> S_OK then Exit;

    Result := True;
  finally
    //�ر�OLE�⣬�˺���������OleInitialize�ɶԵ���
    OleUninitialize;
  end;
end;

function ResolveLink(ALinkFile: string): string;
var
  link: IShellLink;
  storage: IPersistFile;
  filedata: TWin32FindData;
  buf: array[0..MAX_PATH] of Char;
  widepath: WideString;
begin
  //�������ο���http://blog.csdn.net/sailxia/archive/2004/10/25/151386.aspx

  Result := '';

  OleCheck(CoCreateInstance(CLSID_ShellLink, nil, CLSCTX_INPROC_SERVER, IShellLink, link));
  OleCheck(link.QueryInterface(IPersistFile, storage));
  widepath := ALinkFile;

  if Succeeded(storage.Load(@widepath[1], STGM_READ)) then
    if Succeeded(link.Resolve(GetActiveWindow, SLR_NOUPDATE)) then
      if Succeeded(link.GetPath(buf, sizeof(buf), filedata, SLGP_UNCPRIORITY)) then
        Result := buf;

  storage := nil;
  link := nil;
end;

function IsNumericStr(const str: string): Boolean;
var
  i: Cardinal;
begin
  Result := False;

  if str = '' then Exit;

  for i := 1 to Length(str) do
  begin
    if not (str[i] in ['0'..'9']) then Exit;
  end;

  Result := True;
end;

function GetFileListInDir(var List: TStringList; const Dir: string;
  Ext: string = '*'; IsPlusDir: Boolean = True): Boolean;
var
  fd: TSearchRec;
  i: Cardinal;
begin
  Result := False;

  List.Clear;

  if not DirectoryExists(Dir) then exit;

  if FindFirst(Dir + '\*.*', faAnyFile, fd) = 0 then
  begin
    while FindNext(fd) = 0 do
      if (fd.Name <> '.') and (fd.Name <> '..')
        and (Pos(LowerCase(Ext), LowerCase(fd.Name)) > 0) then
        if IsPlusDir then
          List.Add(Dir + '\' + fd.Name)
        else
          List.Add(fd.Name);

    FindClose(fd);

    Result := True;
  end;
end;

procedure QuickSort(var SortNum: array of integer; p, r: integer);
  procedure swap(var a, b: integer);
  var
    tmp: integer;
  begin
    tmp := a;
    a := b;
    b := tmp;
  end;
  function partition(var SortNum: array of integer; p, r: integer): integer; //����
  var
    i, j, x: integer;
  begin
    i := p;
    j := r + 1;
    x := SortNum[p];
    while true do
    begin
      repeat inc(i)
      until SortNum[i] < x;
      repeat inc(j, -1)
      until SortNum[j] > x;
      if i >= j then break;
      swap(SortNum[i], SortNum[j]);
    end;
    SortNum[p] := SortNum[j];
    SortNum[j] := x;
    result := j;
  end;
var
  q: integer;
begin
  if p < r then
  begin
    q := partition(SortNum, p, r);
    QuickSort(SortNum, p, q - 1);
    QuickSort(SortNum, q + 1, r);
  end;
end;

function ExtractRes(ResType, ResName, ResNewName: string): Boolean;
var
  Res: TResourceStream;
begin
  try
    Res := TResourceStream.Create(Hinstance, Resname, Pchar(ResType));
    try
      Res.SavetoFile(ResNewName);
      Result := true;
    finally
      Res.Free;
    end;
  except
    Result := false;
  end;
end;

function GetDragFileCount(hDrop: Cardinal): Integer;
const
  DragFileCount = High(Cardinal);
begin
  Result := DragQueryFile(hDrop, DragFileCount, nil, 0);
end;

function GetDragFileName(hDrop: Cardinal; FileIndex: Integer = 1): string;
const
  Size = 255;
var
  Len: Integer;
  FileName: string;
begin
  SetLength(FileName, Size);
  Len := DragQueryFile(hDrop, FileIndex - 1, PChar(FileName), Size);
  SetLength(FileName, Len);
  Result := FileName;
end;

function UnicodeEncode(Str: string; CodePage: integer): WideString;
var
  Len: integer;
begin
  Len := Length(Str) + 1;
  SetLength(Result, Len);
  Len := MultiByteToWideChar(CodePage, 0, PChar(Str), -1, PWideChar(Result), Len);
  SetLength(Result, Len - 1);                          //end is #0
end;

function UnicodeDecode(Str: WideString; CodePage: integer): string;
var
  Len: integer;
begin
  Len := Length(Str) * 2 + 1;                          //one for #0
  SetLength(Result, Len);
  Len := WideCharToMultiByte(CodePage, 0, PWideChar(Str), -1, PChar(Result), Len, nil, nil);
  SetLength(Result, Len - 1);
end;

function Gb2Big5(Str: string): string;
begin
  SetLength(Result, Length(Str));
  LCMapString(GetUserDefaultLCID, LCMAP_TRADITIONAL_CHINESE,
    PChar(Str), Length(Str),
    PChar(Result), Length(Result));
  Result := UnicodeDecode(UnicodeEncode(Result, 936), 950);
end;

function Big52Gb(Str: string): string;
begin
  Str := UnicodeDecode(UnicodeEncode(Str, 950), 936);
  SetLength(Result, Length(Str));
  LCMapString(GetUserDefaultLCID, LCMAP_SIMPLIFIED_CHINESE,
    PChar(Str), Length(Str),
    PChar(Result), Length(Result));
end;

function Utf8Encode(const WS: WideString): UTF8String;
var
  L: Integer;
  Temp: UTF8String;
begin
  Result := '';
  if WS = '' then Exit;
  SetLength(Temp, Length(WS) * 3);

  // SetLength includes space for null terminator
  L := UnicodeToUtf8(PChar(Temp), Length(Temp) + 1, PWideChar(WS), Length(WS));
  if L > 0 then
    SetLength(Temp, L - 1)
  else
    Temp := '';

  Result := Temp;
end;

function GetUTF8QueryString(Keyword: string): string;
const
  NoConversion = ['A'..'Z', 'a'..'z', '*', '@', '.', '_', '-'];
var
  str, QueryStr: string;
  i: Cardinal;
begin
  Result := '';
  Keyword := Utf8Encode(Keyword);
  for i := 1 to Length(Keyword) do
    if Keyword[i] in NoConversion then
      Result := Result + Keyword[i]
    else
      if Keyword[i] = ' ' then
        Result := Result + '+'
      else
        Result := Result + '%' + IntToHex(Ord(Keyword[i]), 2);
end;

function GetURLQueryString(Keyword: string): string;
const
  NoConversion = ['A'..'Z', 'a'..'z', '*', '@', '.', '_', '-'];
var
  str, QueryStr: string;
  i: Cardinal;
begin
  Result := '';
  for i := 1 to Length(Keyword) do
    if Keyword[i] in NoConversion then
      Result := Result + Keyword[i]
    else
      if Keyword[i] = ' ' then
        Result := Result + '+'
      else
        Result := Result + '%' + IntToHex(Ord(Keyword[i]), 2);
end;

procedure InitLogger;
begin
  if TraceEnable then
    hLog.StartLogging;
end;

procedure TraceErr(const Msg: string);
begin
  if TraceEnable then
    hLog.Add(Format('[%s] ERROR: %s', [DateTimeToStr(Now), Msg]));
end;

procedure TraceMsg(const Msg: string);
begin
  if TraceEnable then
    hLog.Add(Format('[%s] ', [DateTimeToStr(Now)]) + Msg);
end;

procedure TraceMsg(const AFormat: string; Args: array of const);
begin
  if TraceEnable then
    hLog.Add(Format('[%s] ', [DateTimeToStr(Now)]) + Format(AFormat, Args));
end;
end.

