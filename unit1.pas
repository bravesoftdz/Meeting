unit Unit1;

{$mode objfpc}{$H+}

interface


uses
  Classes, Controls, Dialogs, ExtCtrls, ExtDlgs, Forms,
  Graphics, Grids, Registry, sqldb, sqlite3conn, StdCtrls, Sysutils,
  Windows;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1:   TButton;
    Button2:   TButton;
    Button3:   TButton;
    Button4:   TButton;
    CalendarDialog1: TCalendarDialog;
    ComboBox1: TComboBox;
    ComboBox3: TComboBox;
    Edit1:     TEdit;
    Edit2:     TEdit;
    Edit3:     TEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    GroupBox4: TGroupBox;
    SQLite3Connection1: TSQLite3Connection;
    StringGrid1: TStringGrid;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure ComboBox1Select(Sender: TObject);
    procedure ComboBox3Change(Sender: TObject);
    procedure Edit1Click(Sender: TObject);
    procedure Edit1KeyPress(Sender: TObject; var Key: char);
    procedure Edit2DblClick(Sender: TObject);
    procedure Edit3DblClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDblClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure GetEmploee;
    procedure StringGrid1DblClick(Sender: TObject);
    procedure StringGrid1DrawCell(Sender: TObject; aCol, aRow: integer;
      aRect: TRect; aState: TGridDrawState);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;

  ODBCServerConnect: TSQLite3Connection;
  SQLMainQuery: TSQLQuery;
  SQLTrans: TSQLTransaction;
  EmpIndx:  string;

  S: TResourceStream;
  F: TFileStream;

implementation

{$R *.lfm}
{$R mydata.rc}

{ TForm1 }

procedure TForm1.GetEmploee;
  var
    i: integer = 1;
  begin
    ODBCServerConnect.Connected := True;
    //Получаем Индекс пользователя
    SQLMainQuery.Close;
    SQLMainQuery.SQL.Clear;
    SQLMainQuery.SQL.Text := ('SELECT Indx FROM "Emploee" WHERE Last=''' +
      Trim(Copy(ComboBox3.Text, 1, pos(',', ComboBox3.Text) - 1)) + '''');
    SQLMainQuery.Open;
    SQLMainQuery.First;
    EmpIndx := (UTF8Encode(SQLMainQuery.Fields[0].AsString));
    SQLMainQuery.Close;

    //получаем его инфу
    SQLMainQuery.SQL.Clear;
    StringGrid1.Clean;
    SQLMainQuery.SQL.Text :=
      ('SELECT Last,First,Date,Client FROM "Main" m INNER JOIN Emploee ON Emploee.Indx = m.Employee WHERE m.Employee='''
      + EmpIndx + '''ORDER BY "Date" DESC');
    SQLMainQuery.Open;
    SQLMainQuery.First;
    StringGrid1.ColCount    := SQLMainQuery.Fields.Count;
    StringGrid1.RowCount    := SQLMainQuery.RecordCount + 1;
    StringGrid1.Cells[0, 0] := 'Last';
    StringGrid1.Cells[1, 0] := 'First';
    StringGrid1.Cells[2, 0] := 'Date';
    StringGrid1.Cells[3, 0] := 'Client';
    while not SQLMainQuery.EOF do
      begin
      StringGrid1.Cells[0, i] := SQLMainQuery.Fields[0].AsString;
      StringGrid1.Cells[1, i] := SQLMainQuery.Fields[1].AsString;
      StringGrid1.Cells[2, i] := SQLMainQuery.Fields[2].AsString;
      StringGrid1.Cells[3, i] := SQLMainQuery.Fields[3].AsString;
      SQLMainQuery.Next;
      i := i + 1;
      end;
    SQLMainQuery.Close;
    ODBCServerConnect.Connected := False;
  end;

procedure TForm1.StringGrid1DblClick(Sender: TObject);
  begin
    if (StringGrid1.Selection.top > 0) and (StringGrid1.ColCount >= 3) then
      begin
      Edit2.Text := StringGrid1.Cells[2, StringGrid1.Selection.top];
      Edit3.Text := StringGrid1.Cells[2, StringGrid1.Selection.top];
      end;
  end;

procedure TForm1.StringGrid1DrawCell(Sender: TObject; aCol, aRow: integer;
  aRect: TRect; aState: TGridDrawState);
  var
    W: string;
  begin
    if (aRow > 0) and (StringGrid1.Cells[0, 0] <> 'Месяц') then
      begin
      w := Trim(StringGrid1.Cells[3, aRow]);
      if W = 'REST DAY' then
        StringGrid1.Canvas.Brush.Color := $009FA5FF         //светло красный
      else
        if W = 'VACATION' then
          StringGrid1.Canvas.Brush.Color := $0040FF70    //зелёный
        else
          if w <> 'OFFICE' then
            StringGrid1.Canvas.Brush.Color := $00FFFF80;

      StringGrid1.Canvas.FillRect(aRect);
      StringGrid1.Canvas.TextOut(aRect.Left + 2, aRect.Top + 2,
        StringGrid1.Cells[aCol, aRow]);
      end;
  end;

procedure GetUserNameEx(NameFormat: DWORD; lpNameBuffer: LPSTR; nSize: PULONG); stdcall;
  external 'secur32.dll' Name 'GetUserNameExA';


function LoggedOnUserNameEx(fFormat: DWORD): string;
  var
    UserName: array[0..250] of ansichar;
    Size:     DWORD;
  begin
    Size := 250;
    GetUserNameEx(fFormat, @UserName, @Size);
    Result := UserName;
  end;

procedure TForm1.FormCreate(Sender: TObject);
  begin
    //Выгружаем библеотеку SQLite
    S := TResourceStream.Create(HInstance, 'MYDATA', RT_PLUGPLAY);
      try
      F := TFileStream.Create(ExtractFilePath(ParamStr(0)) + 'sqlite3.dll', fmCreate);
        try
        F.CopyFrom(S, S.Size);
        finally
        F.Free;
        end;
      finally
      S.Free;
      end;
    //Выгрузили библеотеку SQLite

    ODBCServerConnect := TSQLite3Connection.Create(nil);
   { with ODBCServerConnect do
      begin
      Params.Add('Driver=SQL Server');
      Params.Add('Server=127.0.0.1\SQLEXPRESS');
      Params.Add('Trusted_Connection=Yes');
      Params.Add('Database=Meetings');
      Params.Add('Integrated Security=SSPI');
      Open;
      end;  }
    ///Начали читать параметры
    with TRegistry.Create do
        try
        RootKey := HKEY_CURRENT_USER;
        if OpenKey('\SOFTWARE\MeetingProg', False) then
          begin
          ODBCServerConnect.DatabaseName := ReadString('DBFile');
          if Trim(ODBCServerConnect.DatabaseName) = '' then
            WriteString('DBFile', '\\EUWINKIEFSV001\RetailerServices\Meetings.sqlite');
          end
        else
          if OpenKey('\SOFTWARE\MeetingProg', True) then
            WriteString('DBFile', '\\EUWINKIEFSV001\RetailerServices\Meetings.sqlite');
        finally
        ODBCServerConnect.DatabaseName := ReadString('DBFile');
        CloseKey;
        Free;
        end;
    ///Закончили читать параметры
    ODBCServerConnect.Connected := True;

    SQLTrans     := TSQLTransaction.Create(nil);
    SQLTrans.DataBase := ODBCServerConnect;
    SQLMainQuery := TSQLQuery.Create(nil);
    SQLMainQuery.PacketRecords := -1;
    SQLMainQuery.DataBase := ODBCServerConnect;
    SQLMainQuery.Transaction := SQLTrans;
    SQLMainQuery.SQL.Clear;
    SQLMainQuery.SQL.Text := ('SELECT Last,First FROM "Emploee"');
    SQLMainQuery.Open;
    SQLMainQuery.First;
    ComboBox3.Clear;
    while not SQLMainQuery.EOF do
      begin
      ComboBox3.Items.Add(UTF8Encode(SQLMainQuery.Fields[0].AsString) +
        ', ' + UTF8Encode(SQLMainQuery.Fields[1].AsString));
      SQLMainQuery.Next;
      end;
    SQLMainQuery.Close;
    ODBCServerConnect.Connected := False;
    ComboBox3.ItemIndex := ComboBox3.Items.IndexOf(LoggedOnUserNameEx(3));

    Form1.Caption := 'Meetings by Lenivets' + '   ' + 'LogedInUser:' + LoggedOnUserNameEx(3);

    Edit2.Text := DateToStr(Date);
    Edit3.Text := DateToStr(Date);
    Edit1.Text := '';
    if (Pos('Bryk', ComboBox3.Text) > 0) or (Pos('Pogorelov', ComboBox3.Text) > 0) or
      (Pos('Drobit', ComboBox3.Text) > 0) then
      begin
      ComboBox3.Enabled := True;
      Button2.Enabled   := True;
      end;
    GetEmploee;
  end;

procedure TForm1.FormDblClick(Sender: TObject);
  var
    S: string = '';
  begin
    if InputQuery('Измненения расположения БД',
      'Введите, пожалуйста, новый адрес расположения файла БД:' +
      #13#10 + 'Пример: ' + '\\EUWINKIEFSV001\RetailerServices\Meetings.sqlite', s) then
      begin
      ODBCServerConnect.Connected    := False;
      ODBCServerConnect.DatabaseName := S;
      ODBCServerConnect.Connected    := True;
      end;
    GetEmploee;
  end;

procedure TForm1.FormDestroy(Sender: TObject);
  begin
    with TRegistry.Create do
        try
        RootKey := HKEY_CURRENT_USER;
        if OpenKey('\SOFTWARE\MeetingProg', True) then
          begin
          WriteString('DBFile', ODBCServerConnect.DatabaseName);
          CloseKey;
          end;
        finally
        Free;
        end;
    SQLMainQuery.Free;
    ODBCServerConnect.Free;
    DeleteFile(PChar(ExtractFilePath(ParamStr(0)) + 'sqlite3.dll'));
  end;

procedure TForm1.FormResize(Sender: TObject);
  begin
    StringGrid1.Height := Form1.Height - StringGrid1.Top - 3;
    StringGrid1.Width := Form1.Width - 98;
    Button4.Left := StringGrid1.Width + 10;
    Button2.Left := StringGrid1.Width + 10;
    Button3.Left := StringGrid1.Width + 10;
    StringGrid1.Refresh;
  end;

procedure TForm1.ComboBox3Change(Sender: TObject);
  begin
    if pos(LoggedOnUserNameEx(3), ComboBox3.Text) <= 0 then
      ShowMessage('Убедитесь, что Вы выбрали себя !');
    GetEmploee;
  end;

procedure TForm1.Edit1Click(Sender: TObject);
  begin
    Edit1.Clear;
  end;

procedure TForm1.Edit1KeyPress(Sender: TObject; var Key: char);
  begin
    if length(Edit1.Text) + 1 > 2 then
      Button1.Enabled := True;
    if (key = #13) and (trim(Edit1.Text) <> '') then
      Button1.Enabled := True;
    if (Button1.Enabled = True) and (key = #13) then
      Button1.Click;
  end;

procedure TForm1.Edit2DblClick(Sender: TObject);
  begin
    if CalendarDialog1.Execute then
      Edit2.Text := DateToStr(CalendarDialog1.Date);
  end;

procedure TForm1.Edit3DblClick(Sender: TObject);
  begin
    if CalendarDialog1.Execute then
      Edit3.Text := DateToStr(CalendarDialog1.Date);
  end;

procedure TForm1.Button3Click(Sender: TObject);
  var
    i:    integer = 1;
    tind: integer;
    year:string;
  begin
    year:= FormatDateTime('yyyy', Now); //текущий год
    ODBCServerConnect.Connected := True;
    SQLMainQuery.Close;
    SQLMainQuery.SQL.Clear;
    StringGrid1.Clean;
    SQLMainQuery.SQL.Text :=
      ('SELECT strftime(''%m'',Date),COUNT(*) FROM "Main" Where Employee=''' +
      EmpIndx +
      ''' and Client<>''REST DAY'' and Client<>''OFFICE'' and strftime(''%Y'',Date)='''+year+''' GROUP BY strftime(''%m'',Date)');
    SQLMainQuery.Open;
    SQLMainQuery.First;
    StringGrid1.ColCount    := SQLMainQuery.Fields.Count + 2;
    StringGrid1.RowCount    := SQLMainQuery.RecordCount + 1;
    StringGrid1.Cells[0, 0] := 'Месяц';
    StringGrid1.Cells[1, 0] := 'Всего';
    StringGrid1.Cells[2, 0] := 'Отпуск';
    StringGrid1.Cells[3, 0] := 'У клиента';
    while not SQLMainQuery.EOF do
      begin
      StringGrid1.Cells[0, i] :=
        Utf8Encode(LongMonthNames[SQLMainQuery.Fields[0].AsInteger]);
      StringGrid1.Cells[1, i] := SQLMainQuery.Fields[1].AsString;
      SQLMainQuery.Next;
      i := i + 1;
      end;
    SQLMainQuery.Close;
    SQLMainQuery.SQL.Text :=
      ('SELECT strftime(''%m'',Date),COUNT(*) FROM "Main" Where Employee=''' +
      EmpIndx + ''' and Client=''VACATION'' and strftime(''%Y'',Date)='''+year+''' GROUP BY strftime(''%m'',Date)');
    SQLMainQuery.Open;
    SQLMainQuery.First;
    while not SQLMainQuery.EOF do
      begin
      if SQLMainQuery.Fields[1].AsInteger > 0 then
        begin
        tind := StringGrid1.Cols[0].IndexOf(
          Utf8Encode(LongMonthNames[SQLMainQuery.Fields[0].AsInteger]));
        if tind > 0 then
          StringGrid1.Cells[2, tind] :=
            SQLMainQuery.Fields[1].AsString;
        end;
      SQLMainQuery.Next;
      end;
    SQLMainQuery.Close;
    SQLMainQuery.SQL.Text :=
      ('SELECT strftime(''%m'',Date),COUNT(*) FROM "Main" Where Employee=''' +
      EmpIndx +
      ''' and Client<>''VACATION'' and Client<>''REST DAY'' and Client<>''OFFICE'' and strftime(''%Y'',Date)='''+year+''' GROUP BY strftime(''%m'',Date)');
    SQLMainQuery.Open;
    SQLMainQuery.First;
    while not SQLMainQuery.EOF do
      begin
      if SQLMainQuery.Fields[1].AsInteger > 0 then
        begin
        tind := StringGrid1.Cols[0].IndexOf(
          Utf8Encode(LongMonthNames[SQLMainQuery.Fields[0].AsInteger]));
        if tind > 0 then
          StringGrid1.Cells[3, tind] :=
            SQLMainQuery.Fields[1].AsString;
        end;
      SQLMainQuery.Next;
      end;
    SQLMainQuery.Close;
    ODBCServerConnect.Connected := False;
  end;

procedure TForm1.Button4Click(Sender: TObject);
  begin
    GetEmploee;
  end;

procedure TForm1.ComboBox1Select(Sender: TObject);
  begin
    if (ComboBox1.Text = 'REST DAY') or (ComboBox1.Text = 'Vacation') then
      begin
      Edit1.Visible := False;
      Edit1.Text    := ComboBox1.Text;
      end
    else
      if (ComboBox1.Text = 'Work at home') then
        begin
        Edit1.Visible := False;
        Edit1.Text    := ComboBox1.Text;
        end
      else
        if (ComboBox1.Text = 'Sick') then
          begin
          Edit1.Visible := False;
          Edit1.Text    := ComboBox1.Text;
          end
        else
          if (ComboBox1.Text = 'OFFICE') then
            begin
            Edit1.Visible := False;
            Edit1.Text    := ComboBox1.Text;
            end
          else
            if (ComboBox1.Text = 'Встреча') or (ComboBox1.Text = 'Коммандировка') then
              begin
              Edit1.Visible := True;
              Edit1.Clear;
              Edit1.Text      := 'Куда ?';
              Button1.Enabled := False;
              end;

    if length(Edit1.Text) + 1 > 2 then
      Button1.Enabled := True;
  end;

procedure TForm1.Button2Click(Sender: TObject);
  var
    i: integer = 1;
  begin
    ODBCServerConnect.Connected := True;
    SQLMainQuery.Close;
    SQLMainQuery.SQL.Clear;
    StringGrid1.Clean;
    SQLMainQuery.SQL.Text :=
      ('SELECT Last,First,Date,Client,CMeet FROM "Main" m INNER JOIN "Emploee" ON Emploee.Indx = m.Employee WHERE Client<>''OFFICE'' and Client<>''REST DAY'' ORDER BY "Date" DESC,"Client"');
    SQLMainQuery.Open;
    SQLMainQuery.First;
    StringGrid1.ColCount    := SQLMainQuery.Fields.Count;
    StringGrid1.RowCount    := SQLMainQuery.RecordCount + 1;
    StringGrid1.Cells[0, 0] := 'Last';
    StringGrid1.Cells[1, 0] := 'First';
    StringGrid1.Cells[2, 0] := 'Date';
    StringGrid1.Cells[3, 0] := 'Client';
    StringGrid1.Cells[4, 0] := 'Meets count';
    while not SQLMainQuery.EOF do
      begin
      StringGrid1.Cells[0, i] := SQLMainQuery.Fields[0].AsString;
      StringGrid1.Cells[1, i] := SQLMainQuery.Fields[1].AsString;
      StringGrid1.Cells[2, i] := SQLMainQuery.Fields[2].AsString;
      StringGrid1.Cells[3, i] := SQLMainQuery.Fields[3].AsString;
      StringGrid1.Cells[4, i] := SQLMainQuery.Fields[4].AsString;
      SQLMainQuery.Next;
      i := i + 1;
      end;
    SQLMainQuery.Close;
    ODBCServerConnect.Connected := False;
  end;

procedure TForm1.Button1Click(Sender: TObject);
  var
    rwaf:   integer = 0;
    Dt, Dt2, Date: TDate;
    CouDat: integer = 0;
    Exs:    boolean = False;
    TmpM:   string;
    CMeet:  integer = 1;

  begin
    ODBCServerConnect.Connected := True;
    if (Trim(Edit1.Text) <> '') and (strtodate(Edit3.Text) >= strtodate(Edit2.Text)) then
      begin
      Dt  := StrToDate(Edit2.Text);
      Dt2 := StrToDate(Edit3.Text);
      ////////////   Проверяем существование Дня в БД
      SQLMainQuery.Close;
      SQLMainQuery.SQL.Clear;
      SQLMainQuery.SQL.Text :=
        ('SELECT Client FROM "Main" WHERE Date=''' +
        formatdatetime('yyyy"-"mm"-"dd', Dt) + '''and Employee = ''' + EmpIndx + '''');
      SQLMainQuery.Open;
      if Trim(SQLMainQuery.Fields[0].AsString) <> '' then
        EXS := True;

      ////////////////////////////// Считаем встречи//////////////////////////////////////////
      if Pos('(', Edit1.Text) > 0 then
        begin
        TMPm := Edit1.Text;
        Delete(TMPm, 1, Pos('(', TMPm));
        while pos(',', TMPm) > 0 do
          begin
          CMeet := CMeet + 1;
          Delete(TMPm, 1, Pos(',', TMPm));
          end;
        end
      else
        CMeet := 0;
      //////////////////////////////// Закончили считать //////////////////////////////////////

      //////////// ------------------------------------------------------
      SQLMainQuery.Close;
      SQLMainQuery.SQL.Clear;
      if Edit2.Text <> Edit3.Text then
        while Dt <= Dt2 do
          begin
          if (UTF8Encode(LongDayNames[DayOfWeek(dt)]) <> 'суббота') and
            (UTF8Encode(LongDayNames[DayOfWeek(dt)]) <> 'воскресенье') then
            begin
            ///////////////////////////////////Проверяем существование Дня в БД (Цыкл ОТ даты ДО даты)
            SQLMainQuery.Close;
            SQLMainQuery.SQL.Clear;
            SQLMainQuery.SQL.Text :=
              ('SELECT Client FROM "Main" WHERE Date=''' +
              formatdatetime('yyyy"-"mm"-"dd', Dt) + '''and Employee = ''' +
              EmpIndx + '''');
            SQLMainQuery.Open;
            if Trim(SQLMainQuery.Fields[0].AsString) <> '' then
              EXS := True
            else
              EXS := False;
            SQLMainQuery.Close;
            SQLMainQuery.SQL.Clear;
            /////////////////////////////////////////////////----------------------------------------
            if EXS <> True then
              SQLMainQuery.SQL.Text :=
                ('INSERT INTO "Main" (Date,Employee,Client,CMeet) VALUES(''' +
                formatdatetime('yyyy"-"mm"-"dd', Dt) + ''',''' +
                EmpIndx + ''',''' + UpperCase(Edit1.Text) + ''',''' +
                IntToStr(CMeet) + ''')')
            else
              SQLMainQuery.SQL.Text :=
                ('UPDATE "Main" SET Client = ''' + UpperCase(Edit1.Text) +
                ''',' + 'Cmeet =''' + IntToStr(CMeet) + ''' WHERE Employee = ''' +
                EmpIndx + ''' and Date = ''' + formatdatetime(
                'yyyy"-"mm"-"dd', Dt) + '''');

            SQLMainQuery.ExecSQL;
            SQLTrans.Commit;
            CouDat := CouDat + 1;
            rwaf   := rwaf + SQLMainQuery.rowsaffected;
            end;
          Dt := Dt + 1;
          end
      else
        begin
        if (UTF8Encode(LongDayNames[DayOfWeek(dt)]) <> 'суббота') and
          (UTF8Encode(LongDayNames[DayOfWeek(dt)]) <> 'воскресенье') then
          begin
          SQLMainQuery.Close;
          SQLMainQuery.SQL.Clear;
          Date := StrToDate(Edit2.Text);
          if EXS <> True then
            SQLMainQuery.SQL.Text :=
              ('INSERT INTO "Main" (Date,Employee,Client,CMeet) VALUES(''' +
              formatdatetime('yyyy"-"mm"-"dd', Dt) + ''',''' +
              EmpIndx + ''',''' + UpperCase(Edit1.Text) + ''',''' +
              IntToStr(CMeet) + ''')')
          else
            SQLMainQuery.SQL.Text :=
              ('UPDATE "Main" SET Client = ''' + UpperCase(Edit1.Text) +
              ''',' + 'CMeet = ''' + IntToStr(Cmeet) + ''' WHERE Employee = ''' +
              EmpIndx + ''' and Date = ''' + formatdatetime('yyyy"-"mm"-"dd',
              Date) + '''');
          SQLMainQuery.ExecSQL;
          SQLTrans.Commit;
          rwaf := SQLMainQuery.rowsaffected;
          end;
        end;
      if rwaf > 0 then
        if rwaf = 1 then
          ShowMessage('Обновленно: ' + IntToStr(rwaf) + ' поле')
        else
          if CouDat = rwaf then
            ShowMessage('Обновленно: ' + IntToStr(rwaf) + ' полей')
          else
            ShowMessage('Внимание! Не ВСЕ поля были обновленны' +
              #13#10 + #13#10 + 'Обновленно: ' + IntToStr(rwaf) +
              ' из ' + IntToStr(CouDat) + ' полей')
      else
        ShowMessage('Нечего не было Обновленно !');
      GetEmploee;
      end
    else
      ShowMessage('Поле Клиент НЕ должен быть Пустым' + #13#10 +
        'Конечная дата должна быть больше первичной');
    ODBCServerConnect.Connected := False;
  end;


end.
