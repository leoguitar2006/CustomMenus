unit MyFDQuery;

interface

uses
  System.SysUtils, System.Classes, Data.DB, FireDAC.Comp.Client;

type
  TMyFDQuery = class(TFDQuery)
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MyComponents', [TMyFDQuery]);
end;

end.
