unit ExportToJSONAndClass;

interface

uses
  System.Classes,
  System.DateUtils,
  DesignIntf,
  DesignEditors,
  ToolsAPI,
  Vcl.Dialogs,
  System.SysUtils,
  System.JSON,
  FireDAC.Comp.Client,
  Data.DB,
  System.RegularExpressions,
  MyFDQuery;

type
  TFDQueryEditor = class(TComponentEditor)
  private
    FOldEditor: IComponentEditor;
    function FieldTypeToDelphiType(FieldType: TFieldType): String;
    procedure OpenUnit(const UnitCode: String);
    procedure ExportToJson;
    procedure GenerateClass;
  public
    constructor Create(AComponent: TComponent; ADesigner: IDesigner); override;
    destructor Destroy; override;
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
    procedure Edit; override;
    procedure Copy; override;

  end;

procedure Register;

implementation

var
  PrevEditorClass: TComponentEditorClass = nil;

procedure Register;
var
  Query: TMyFDQuery;
  Editor: IComponentEditor;
begin
  Query := TMyFDQuery.Create(nil);
  try
    Editor := GetComponentEditor(Query, nil);
    if Assigned(Editor) then
      PrevEditorClass := TComponentEditorClass((Editor as TObject).ClassType);
  finally
    Editor := nil;
    FreeAndNIL(Query);
  end;
  RegisterComponentEditor(TMyFDQuery, TFDQueryEditor);
end;

{ TFDQueryEditor }


procedure TFDQueryEditor.OpenUnit(const UnitCode: String);
var
  ActionServices: IOTAActionServices;
begin
  ActionServices := BorlandIDEServices as IOTAActionServices;
  if Assigned(ActionServices) then
  begin
    if not ActionServices.OpenFile(UnitCode) then
      ShowMessage('Cannot open: ' + UnitCode);
  end
end;

procedure TFDQueryEditor.ExportToJson;
var
  JSONArr: TJSONArray;
  JSONObject: TJSONObject;
  Field: TField;
  I: Integer;
  FDQuery: TFDQuery;
  SaveDialog: TSaveDialog;
  Writer: TStreamWriter;
  NameKey: String;
begin
  if not (Component is TMyFDQuery) then Exit;

  FDQuery := TMyFDQuery(Component);

  if not FDQuery.Active or FDQuery.IsEmpty then
  begin
    ShowMessage('Empty data!');
    Exit;
  end;

  JSONArr := TJSONArray.Create;
  try
    FDQuery.First;
    while not FDQuery.Eof do
    begin
      JSONObject := TJSONObject.Create;
      for i := 0 to FDQuery.FieldCount - 1 do
      begin
        Field := FDQuery.Fields[i];
        NameKey := AnsiLowerCase(Field.FieldName);

        if not Field.IsNull then
        begin
          case Field.DataType of
            ftString, ftWideString, ftMemo, ftWideMemo:
              JSONObject.AddPair(NameKey, Field.AsString);
            ftInteger, ftSmallint, ftWord, ftAutoInc, ftLargeint:
              JSONObject.AddPair(NameKey, TJSONNumber.Create(Field.AsInteger));
            ftFloat, ftCurrency, ftBCD, ftFMTBcd:
              JSONObject.AddPair(NameKey, TJSONNumber.Create(Field.AsFloat));
            ftDate, ftTime, ftDateTime, ftTimeStamp:
              JSONObject.AddPair(NameKey, DateToISO8601(Field.AsDateTime));
          else
            JSONObject.AddPair(NameKey, Field.AsString);
          end;
        end
        else
          JSONObject.AddPair(Field.FieldName, TJSONNull.Create);
      end;
      JSONArr.AddElement(JSONObject);
      FDQuery.Next;
    end;

    SaveDialog := TSaveDialog.Create(nil);
    try
      SaveDialog.Filter := 'JSON files (*.json)|*.json';
      SaveDialog.DefaultExt := 'json';
      SaveDialog.FileName := Concat(FDQuery.Name, '_data.json');
      if SaveDialog.Execute then
      begin
        Writer := TStreamWriter.Create(SaveDialog.FileName, False, TEncoding.UTF8);
        try
          Writer.Write(JSONArr.Format);
          ShowMessage('Data exported to ' + SaveDialog.FileName);
        finally
          Writer.Free;
        end;
      end;
    finally
      SaveDialog.Free;
    end;
  finally
    JSONArr.Free;
  end;
end;

procedure TFDQueryEditor.GenerateClass;
var
  SaveDialog: TSaveDialog;
  Field: TField;
  FDQuery: TFDQuery;
  UnitName, ClassName, SQLText, TableName, CurrentFieldName, FileName: string;
  i: Integer;
  Code: TStringList;
  Regex: TRegEx;
begin
  if not (Component is TMyFDQuery) then Exit;
  FDQuery := TMyFDQuery(Component);

  if not FDQuery.Active or FDQuery.IsEmpty then
  begin
    ShowMessage('Empty data!.');
    Exit;
  end;

  SQLText := FDQuery.SQL.Text;
  Regex := TRegEx.Create('FROM\s+([a-zA-Z0-9_]+)', [roIgnoreCase]);
  if Regex.IsMatch(SQLText) then
    TableName := Regex.Match(SQLText).Groups[1].Value
  else
  begin
    TableName := InputBox('Nome da Tabela', 'Digite o nome da tabela:', '');
    if TableName = '' then Exit;
  end;

  TableName := AnsiLowerCase(TableName);

  ClassName := 'T' + AnsiLowerCase(TableName);
  UnitName := 'U_' + TableName;

  Code := TStringList.Create;
  try
    // Unit header
    Code.Add('unit ' + UnitName + ';');
    Code.Add('');
    Code.Add('interface');
    Code.Add('');
    Code.Add('type');
    Code.Add('  ' + ClassName + ' = class');
    Code.Add('  private');

    // Private Fields
    for i := 0 to FDQuery.FieldCount - 1 do
    begin
      Field := FDQuery.Fields[i];
      CurrentFieldName := AnsiLowerCase(Field.FieldName);
      Code.Add('    F' + CurrentFieldName + ': ' + FieldTypeToDelphiType(Field.DataType) + ';');
    end;

    Code.Add('  public');

    // Public Properties
    for i := 0 to FDQuery.FieldCount - 1 do
    begin
      Field := FDQuery.Fields[i];
      CurrentFieldName := AnsiLowerCase(Field.FieldName);
      Code.Add('    property ' + CurrentFieldName + ': ' + FieldTypeToDelphiType(Field.DataType) +
               ' read F' + CurrentFieldName + ' write F' + CurrentFieldName + ';');
    end;

    Code.Add('  end;');
    Code.Add('');
    Code.Add('implementation');
    Code.Add('');
    Code.Add('end.');

    FileName := Concat('C:\Temp\MyUnits\', UnitName, '.pas');
    Code.SaveToFile(FileName);
    OpenUnit(FileName);
  finally
    Code.Free;
  end;

end;

constructor TFDQueryEditor.Create(AComponent: TComponent; ADesigner: IDesigner);
begin
  inherited Create(AComponent, ADesigner);

  if Assigned(PrevEditorClass) then
    FOldEditor := TComponentEditor(PrevEditorClass.Create(AComponent, ADesigner));
end;

destructor TFDQueryEditor.Destroy;
begin
  inherited;
end;

procedure TFDQueryEditor.Edit;
begin
  if Assigned(FOldEditor) then
  begin
    FOldEditor.Edit;
  end;
end;

procedure TFDQueryEditor.Copy;
begin
  if Assigned(FOldEditor) then
    FOldEditor.Copy;
end;

function TFDQueryEditor.GetVerb(Index: Integer): string;
var
  I: Integer;
begin
  I := Index - FOldEditor.GetVerbCount;
  case I of
    0: Result := 'Export To Json';
    1: Result := 'Generate Class';
  else
    if Assigned(FOldEditor) then
      Result := FOldEditor.GetVerb(Index)
  end;
end;

procedure TFDQueryEditor.ExecuteVerb(Index: Integer);
var
  I: Integer;
begin
  I := Index - FOldEditor.GetVerbCount;
  case i of
    0: ExportToJson;
    1: GenerateClass;
  else
    if Assigned(FOldEditor) then
      FOldEditor.ExecuteVerb(Index)
  end;
end;

function TFDQueryEditor.GetVerbCount: Integer;
begin
  Result := 2;
  if Assigned(FOldEditor) then
    Inc(Result, FOldEditor.GetVerbCount);
end;

function TFDQueryEditor.FieldTypeToDelphiType(FieldType: TFieldType): String;
begin
    case FieldType of
    ftString, ftWideString, ftMemo, ftWideMemo: Result := 'string';
    ftInteger, ftSmallint, ftWord, ftAutoInc, ftLargeint: Result := 'Integer';
    ftFloat, ftCurrency, ftBCD, ftFMTBcd: Result := 'Double';
    ftDate, ftTime, ftDateTime, ftTimeStamp: Result := 'TDateTime';
    ftBoolean: Result := 'Boolean';
  else
    Result := 'Variant';
  end;
end;

end.
