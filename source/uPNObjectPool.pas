{******************************************************************************}
{                                                                              }
{       Delphi PnHttpSysServer                                                 }
{                                                                              }
{       Copyright (c) 2018 pony,����(7180001@qq.com)                           }
{                                                                              }
{       Homepage: https://github.com/pony5551/PnHttpSysServer                  }
{                                                                              }
{******************************************************************************}
unit uPNObjectPool;

interface

uses
  System.SysUtils,
  uPNObject,
  uPNObjectMgr,
  uPNObjectRes;

//{$I PNIOCP.inc}

type
  { PN����� }
  TPNObjectPool = class
  private
    m_OnCreateObject:   TOnCreateObject;
    m_ObjectMgr:        TPNObjectMgr;     { �������            }
    m_ObjectRes:        TPNObjectRes;     { �������            }
  published
    property FOnCreateObject: TOnCreateObject read m_OnCreateObject write m_OnCreateObject;
    property FObjectMgr: TPNObjectMgr read m_ObjectMgr write m_ObjectMgr;
    property FObjectRes: TPNObjectRes read m_ObjectRes write m_ObjectRes;
  public
    { ��ʼ�������             }
    procedure InitObjectPool(m_nFreeObjects: Cardinal);
    { ����Object               }
    function AllocateObject: TPNObject;
    { ����Object               }
    function ReleaseObject(FObject: TPNObject): Boolean;
    { ����Object               }
    function FindPNObject(m_nIndex: Cardinal): TPNObject;
    { �ͷ�Object               }
    procedure FreeAllObjects;
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

//uses
//  uWinSocket, uGlobalResStr, uGlobalLogger;

{ TPNObjectPool }
constructor TPNObjectPool.Create;
begin
  inherited Create;
  m_ObjectRes := TPNObjectRes.Create;
//  m_ObjectRes.FObjectResLock.SetLockName('m_ObjectRes');
  m_ObjectMgr := TPNObjectMgr.Create;
//  m_ObjectMgr.FObjectMgrLock.SetLockName('m_ObjectMgr');
end;

destructor TPNObjectPool.Destroy;
begin
  FreeAndNil(m_ObjectMgr);
  FreeAndNil(m_ObjectRes);
  inherited Destroy;
end;

procedure TPNObjectPool.InitObjectPool(m_nFreeObjects: Cardinal);
var
  I: Integer;
  FFreeObject: TPNObject;
begin
  if not Assigned(m_OnCreateObject) then
  begin
    raise Exception.Create('TPNObjectPool.m_OnCreateObject IS NULL.');
    Exit;
  end;
  FObjectRes.FOnCreateObject := m_OnCreateObject;
  FObjectRes.SetMaxFreeObject(m_nFreeObjects);
  for I := 1 to m_nFreeObjects do
  begin
    FFreeObject := m_OnCreateObject;
    m_ObjectRes.ReleaseObjectToPool(FFreeObject);
  end;
end;

function TPNObjectPool.AllocateObject: TPNObject;
begin
  Result := m_ObjectRes.AllocateFreeObjectFromPool;
  if not m_ObjectMgr.AddPNObject(Result) then
  begin
    m_ObjectRes.ReleaseObjectToPool(Result);
//    {$IFDEF _ICOP_DEBUGERR}
//        _GlobalLogger.AppendErrorLogMessage('TPNObjectPool.AllocateObject AddPNObject ʧ��', []);
//    {$ENDIF}
  end;
end;

function TPNObjectPool.ReleaseObject(FObject: TPNObject): Boolean;
begin
  if not Assigned(FObject) then
  begin
    Result := False;
    Exit;
  end;

  Result := m_ObjectMgr.RemovePNObject(FObject);
  m_ObjectRes.ReleaseObjectToPool(FObject);
end;

function TPNObjectPool.FindPNObject(m_nIndex: Cardinal): TPNObject;
begin
  Result := nil;
  if ( (m_nIndex < 0 ) or
       (m_nIndex > FObjectMgr.GetObjectCount-1) ) then
       Exit;

  if (PTPNObjectNode(FObjectMgr.FBuckets[m_nIndex])^.m_IsUsed) then
    Result := PTPNObjectNode(FObjectMgr.FBuckets[m_nIndex])^.m_pPNObject;
end;

procedure TPNObjectPool.FreeAllObjects;
begin
  m_ObjectMgr.FreeObjects;
  m_ObjectRes.FreeObjects;
end;

end.


