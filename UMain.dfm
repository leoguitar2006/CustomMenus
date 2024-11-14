object FrmMain: TFrmMain
  Left = 0
  Top = 0
  Caption = 'Main Test'
  ClientHeight = 441
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object MyFDQuery1: TMyFDQuery
    Active = True
    Connection = FDConnection1
    SQL.Strings = (
      'SELECT * FROM EMPLOYEE ORDER BY EMP_NO;')
    Left = 208
    Top = 48
  end
  object FDConnection1: TFDConnection
    Params.Strings = (
      
        'Database=C:\Program Files\Firebird\Firebird_5_0\examples\empbuil' +
        'd\EMPLOYEE.FDB'
      'User_Name=SYSDBA'
      'Password=masterkey'
      'Server=localhost'
      'Port=3050'
      'DriverID=FB')
    Connected = True
    LoginPrompt = False
    Left = 104
    Top = 48
  end
end
