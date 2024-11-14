unit GenerateClass;

interface

uses
  System.SysUtils,
  System.Classes,
  DesignIntf,
  DesignEditors,
  ToolsAPI,
  Data.DB,
  FireDAC.Comp.Client,
  Vcl.Dialogs,
  System.RegularExpressions;

type
  TFDQueryClassMapper = class(TComponentEditor)
  public
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

  function FieldTypeToDelphiType(FieldType: TFieldType): string;
  procedure Register;

implementation

procedure Register;
begin
  RegisterComponentEditor(TFDQuery, TFDQueryClassMapper);
end;

{ TFDQueryClassMapper }

function TFDQueryClassMapper.GetVerbCount: Integer;
begin
  Result := 1;
end;

function TFDQueryClassMapper.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := 'Generate Class';
  else
    Result := '';
  end;
end;

procedure TFDQueryClassMapper.ExecuteVerb(Index: Integer);
var
  SaveDialog: TSaveDialog;
  Field: TField;
  FDQuery: TFDQuery;
  UnitName, ClassName, FileName, SQLText, TableName: string;
  i: Integer;
  Code: TStringList;
  Regex: TRegEx;
begin
  if not (Component is TFDQuery) then Exit;
  FDQuery := TFDQuery(Component);

  if not FDQuery.Active or FDQuery.IsEmpty then
  begin
    ShowMessage('Nenhum dado disponível para mapear.');
    Exit;
  end;

  // Extrair o nome da tabela da consulta SQL
  SQLText := FDQuery.SQL.Text;
  Regex := TRegEx.Create('FROM\s+([a-zA-Z0-9_]+)', [roIgnoreCase]);
  if Regex.IsMatch(SQLText) then
    TableName := Regex.Match(SQLText).Groups[1].Value
  else
  begin
    // Se não encontrar, pedir ao usuário para fornecer o nome da tabela
    TableName := InputBox('Nome da Tabela', 'Digite o nome da tabela:', '');
    if TableName = '' then Exit; // Se o nome da tabela não for fornecido, cancelar
  end;

  // Definir o nome da classe com base no nome da tabela
  ClassName := 'T' + TableName;
  UnitName := 'u' + TableName;

  // Solicitar ao usuário onde salvar o arquivo .pas
  SaveDialog := TSaveDialog.Create(nil);
  try
    SaveDialog.Filter := 'Delphi Unit (*.pas)|*.pas';
    SaveDialog.DefaultExt := 'pas';
    SaveDialog.FileName := UnitName + '.pas';

    if SaveDialog.Execute then
    begin
      FileName := SaveDialog.FileName;

      Code := TStringList.Create;
      try
        // Gerar a unit Delphi
        Code.Add('unit ' + UnitName + ';');
        Code.Add('');
        Code.Add('interface');
        Code.Add('');
        Code.Add('type');
        Code.Add('  ' + ClassName + ' = class');
        Code.Add('  private');

        // Gerar os campos privados
        for i := 0 to FDQuery.FieldCount - 1 do
        begin
          Field := FDQuery.Fields[i];
          Code.Add('    F' + Field.FieldName + ': ' + FieldTypeToDelphiType(Field.DataType) + ';');
        end;

        Code.Add('  public');

        // Gerar as propriedades públicas
        for i := 0 to FDQuery.FieldCount - 1 do
        begin
          Field := FDQuery.Fields[i];
          Code.Add('    property ' + Field.FieldName + ': ' + FieldTypeToDelphiType(Field.DataType) +
            ' read F' + Field.FieldName + ' write F' + Field.FieldName + ';');
        end;

        Code.Add('  end;');
        Code.Add('');
        Code.Add('implementation');
        Code.Add('');
        Code.Add('end.');

        // Salvar a unit .pas no arquivo especificado
        Code.SaveToFile(FileName);
        ShowMessage('Classe mapeada com sucesso para ' + FileName);
      finally
        Code.Free;
      end;
    end;
  finally
    SaveDialog.Free;
  end;
end;

// Função auxiliar para mapear tipos de dados do Delphi
function FieldTypeToDelphiType(FieldType: TFieldType): string;
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
