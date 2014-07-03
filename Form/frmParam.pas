//TComboBox�ؼ���Bug��������֧�ֲ���
//TComboBoxEx�ؼ����������õ��������
unit frmParam;

interface

uses
  Windows,
  Messages,
  SysUtils,
  Variants,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  StdCtrls,
  Buttons,
  untALTRunOption,
  untUtilities,
  ExtCtrls,
  ComCtrls;

const
  PARAM_HISTORY_FILE = 'ParamHistory.txt';

type
  TParamForm = class(TForm)
    btnOK: TBitBtn;
    tmrHide: TTimer;
    cbbParam: TComboBoxEx;

    procedure cbbPKeyPress(Sender: TObject; var Key: Char);
    procedure btnOKClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tmrHideTimer(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormActivate(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure cbbParamKeyPress(Sender: TObject; var Key: Char);
    procedure FormHide(Sender: TObject);
    procedure cbbParamChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    m_ParamHistoryFileName: string;
    m_FileModifyTime: string;

    procedure Createparams(var params: TCreateParams); override;

    procedure RestartTimer;
    procedure StopTimer;
  public
    function LoadParamHistory: Boolean;
    function SaveParamHistory: Boolean;
  end;

var
  ParamForm: TParamForm;

implementation

{$R *.dfm}

procedure TParamForm.btnOKClick(Sender: TObject);
var
  i, Index: Integer;
  RankMin, IndexMin: Integer;
  TempKeyword: string;
begin
  StopTimer;

  //��ɾ��combobox��ĳһ��ʱ��text����Ҳ����Ÿı䣬������Ҫ�ݴ�֮
  TempKeyword := cbbParam.Text;
  Index := cbbParam.Items.IndexOf(TempKeyword);

  //����б��в����ڣ���������һ�����ͽ�����+1
  if TempKeyword <> '' then
    if Index < 0 then
    begin
      //����б�δ�������������������������ɾ��һ��̫�����������
      if cbbParam.Items.Count >= ParamHistoryLimit then
      begin
        RankMin := MaxInt;
        IndexMin := 0;

        //�Ӻ���ǰ���ҵ�һ���õ����ٵ�
        for i := cbbParam.Items.Count - 1 downto 0 do
          if Integer(Pointer(cbbParam.Items.Objects[i])) < RankMin then
          begin
            IndexMin := i;
            RankMin := Integer(Pointer(cbbParam.Items.Objects[i]));
          end;

        //ɾ��֮
        cbbParam.Items.Delete(IndexMin);
      end;

      //���ڵ�һ��
      cbbParam.Items.InsertObject(0, TempKeyword, Pointer(0));
    end
    else
    begin
      cbbParam.Items.Objects[Index] := Pointer(Integer(cbbParam.Items.Objects[Index]) + 1);
    end;

  cbbParam.Text := TempKeyword;
  ModalResult := mrOk;
end;

procedure TParamForm.cbbPKeyPress(Sender: TObject; var Key: Char);
var
  strLeft, strRight: string;
begin
  //����س����͵��ڰ���ȷ��
  if Key = #13 then btnOKClick(Sender);

  //������˸��
//  if Key = #8 then
//  begin
//    key := #0;
//
//    //��ΪDelphi�Դ���TComboBox��Bug�������AutoCompleteѡ��˸���ͻ�ɾ������
//    Self.Caption := Format('%d, %d', [cbbParam.SelStart, cbbParam.SelLength]);
//
//    strLeft := '';
//    if cbbParam.SelStart > 1 then
//      strLeft := Copy(cbbParam.Text, 1, cbbParam.SelStart - 1);
//
//    strRight := Copy(cbbParam.Text, cbbParam.SelStart + cbbParam.SelLength+1,
//      Length(cbbParam.Text) - cbbParam.SelStart - cbbParam.SelLength + 1);
//
//    cbbParam.Text := strLeft + strRight;
//    cbbParam.SelStart := Length(strLeft);
//    cbbParam.SelLength := 0;
//  end;
end;

procedure TParamForm.cbbParamChange(Sender: TObject);
var
  ParamList: TStringList;
begin
  try
    ParamList := TStringList.Create;

    //����Text��������б�����
    //FilterKeyWord(cbbParam.Text, ParamList);
    //cbbParam.Items.Assign(ParamList);
  finally
    ParamList.Free;
  end;
end;

procedure TParamForm.cbbParamKeyPress(Sender: TObject; var Key: Char);
var
  strLeft, strRight, str: WideString;                  //�����WideString����Bug
begin
  //����س����͵��ڰ���ȷ��
  if Key = #13 then btnOKClick(Sender);

  //  if Key = #8 then
  //  begin
  //    key := #0;
  //
  //    //��ΪDelphi�Դ���TComboBox��Bug�������AutoCompleteѡ��˸���ͻ�ɾ������
  //    //ԭ����ComboBox��Text��˫�ֽڵı��룬�����˸�ʱֻ����1���ֽڣ���������
  //    //�������������WideString��Textȡ����������������д��Text
  //
  //    str := cbbParam.Text;
  //
  //    strLeft := '';
  //    if cbbParam.SelStart >= 1 then
  //      if cbbParam.SelLength = 0 then
  //        strLeft := Copy(str, 1, cbbParam.SelStart - 1)
  //      else
  //        strLeft := Copy(str, 1, cbbParam.SelStart);
  //
  //    strRight := Copy(str, cbbParam.SelStart + cbbParam.SelLength + 1,
  //      Length(str) - cbbParam.SelStart - cbbParam.SelLength + 1);
  //
  //    cbbParam.Text := strLeft + strRight;
  //    cbbParam.SelStart := Length(strLeft);
  //    cbbParam.SelLength := 0;
  //  end;
end;

procedure TParamForm.Createparams(var params: TCreateParams);
begin
  inherited;

  with params do
  begin
    params.Style := params.Style or WS_POPUP { or WS_BORDER};
    params.ExStyle := params.ExStyle or WS_EX_TOPMOST {or WS_EX_NOACTIVATE or WS_EX_WINDOWEDGE};
    params.WndParent := GetDesktopWindow;
  end;
end;

procedure TParamForm.FormActivate(Sender: TObject);
begin
  RestartTimer;
end;

procedure TParamForm.FormCreate(Sender: TObject);
begin
  btnOK.Caption := resBtnOK;

  m_ParamHistoryFileName := ExtractFilePath(Application.ExeName) + PARAM_HISTORY_FILE;
  LoadParamHistory;
end;

procedure TParamForm.FormDestroy(Sender: TObject);
begin
  SaveParamHistory;
end;

procedure TParamForm.FormHide(Sender: TObject);
begin
  StopTimer;
end;

procedure TParamForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  RestartTimer;

  case Key of
    VK_ESCAPE:
      begin
        Key := VK_NONAME;

        //�����Ϊ�գ�����գ���������
        if cbbParam.Text = '' then
          ModalResult := mrCancel
        else
        begin
          cbbParam.Text := '';
          cbbParam.SetFocus;
        end;
      end;
  end;

end;

procedure TParamForm.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  RestartTimer;
end;

procedure TParamForm.FormShow(Sender: TObject);
begin
  cbbParam.SetFocus;
end;

function TParamForm.LoadParamHistory: Boolean;
var
  MyFile: TextFile;
  strLine: string;
  NewFileModifyTime: string;
  ParamItem: TStringList;
  cnt: Integer;
  Param: string;
begin
  Result := False;

  //���ļ������ڣ���д��ȱʡ����
  if not FileExists(m_ParamHistoryFileName) then
  begin
    try
      try
        AssignFile(MyFile, m_ParamHistoryFileName);
        ReWrite(MyFile);
      except
        Exit;
      end;
    finally
      CloseFile(MyFile);
    end;
  end;

  //ȡ���ļ��޸�ʱ��
  NewFileModifyTime := GetFileModifyTime(m_ParamHistoryFileName);

  //����ļ��޸�ʱ��û�иı䣬�Ͳ���ˢ����
  if m_FileModifyTime = NewFileModifyTime then
    Exit
  else
    m_FileModifyTime := NewFileModifyTime;

  //��ȡ������б��ļ�
  try
    try
      AssignFile(MyFile, m_ParamHistoryFileName);
      Reset(MyFile);
      ParamItem := TStringList.Create;

      //�����ʷ�б�
      cbbParam.Items.Clear;

      while not Eof(MyFile) do
      begin
        Readln(MyFile, strLine);
        strLine := Trim(strLine);

        SplitString(Trim(strLine), '|', ParamItem);

        //���Ѿ����ˣ��Ͳ�����
        if cbbParam.Items.Count >= ParamHistoryLimit then Exit;

        //ȡ��Rank
        cnt := StrToInt(Trim(ParamItem[0]));

        //ȡ�ò���
        Param := Trim(ParamItem[1]);

        //������������ڣ������
        if cbbParam.Items.IndexOf(Param) < 0 then
          cbbParam.Items.AddObject(Param, Pointer(cnt));
      end;
    except
      Exit;
    end;
  finally
    ParamItem.Free;
    CloseFile(MyFile);
  end;

  Result := True;
end;

procedure TParamForm.RestartTimer;
begin
  if DEBUG_MODE then Exit;

  if Visible then
  begin
    tmrHide.Enabled := False;
    tmrHide.Interval := HideDelay * 1000;
    tmrHide.Enabled := True;
  end;
end;

function TParamForm.SaveParamHistory: Boolean;
var
  i: Cardinal;
  MyFile: TextFile;
  strLine: string;
  ParamItem: TStringList;
  MaxCnt: Integer;
  Param: string;
begin
  Result := False;

  //���ļ������ڣ���д��ȱʡ����
  try
    try
      AssignFile(MyFile, m_ParamHistoryFileName);
      ReWrite(MyFile);

      if cbbParam.Items.Count > 0 then
      begin
        if cbbParam.Items.Count > ParamHistoryLimit then
          MaxCnt := ParamHistoryLimit
        else
          MaxCnt := cbbParam.Items.Count;

        for i := 0 to MaxCnt - 1 do
        begin
          WriteLn(MyFile, Format('%-10d|%-30s%',
            [Integer(Pointer(cbbParam.Items.Objects[i])), cbbParam.Items.Strings[i]]));
        end;
      end;

    except
      Exit;
    end;
  finally
    CloseFile(MyFile);
  end;
end;

procedure TParamForm.StopTimer;
begin
  tmrHide.Enabled := False;
end;

procedure TParamForm.tmrHideTimer(Sender: TObject);
begin
  StopTimer;
  ModalResult := mrCancel;
end;

end.

