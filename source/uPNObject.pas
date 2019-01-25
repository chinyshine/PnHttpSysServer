{******************************************************************************}
{                                                                              }
{       Delphi PnHttpSysServer                                                 }
{                                                                              }
{       Copyright (c) 2018 pony,����(7180001@qq.com)                           }
{                                                                              }
{       Homepage: https://github.com/pony5551/PnHttpSysServer                  }
{                                                                              }
{******************************************************************************}
unit uPNObject;

interface


type
  TPNObject = class
  public
    m_pNext:            TPNObject;
    m_MapID:            Cardinal;

  public
    procedure InitObject; virtual;

  public
    constructor Create;
    destructor Destroy; override;

  end;

implementation

constructor TPNObject.Create;
begin
  inherited Create;
  InitObject;
end;

destructor TPNObject.Destroy;
begin
  inherited Destroy;
end;

procedure TPNObject.InitObject;
begin
  m_pNext := nil;
  m_MapID := 0;
end;

end.
