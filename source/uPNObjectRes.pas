{******************************************************************************}
{                                                                              }
{       Delphi PnHttpSysServer                                                 }
{                                                                              }
{       Copyright (c) 2018 pony,����(7180001@qq.com)                           }
{                                                                              }
{       Homepage: https://github.com/pony5551/PnHttpSysServer                  }
{                                                                              }
{******************************************************************************}
unit uPNObjectRes;

interface

uses
  SysUtils,
  uPNObject,
  uPNCriticalSection;

//{$I PNIOCP.inc}

type
  // ���������¼�
  TOnCreateObject  = function: TPNObject of object;

  TPNObjectRes = class
  private
    m_OnCreateObject:         TOnCreateObject;
    m_ObjectResLock:          TPNCriticalSection;         // ��
    m_pFreeObjectList:        TPNObject;                  // ָ��
    m_nObjectResCount:        Integer;                    // ��������
    m_iMaxNumberOfFreeObject: Integer;                    // ������������������ͷ�
    m_nNewObjectCount:        Int64;                      // ���������ڴ���
    m_nFreeObjectCount:       Int64;                      // �����ͷ��ڴ���
  published
    property FOnCreateObject: TOnCreateObject read m_OnCreateObject write m_OnCreateObject;
    property FObjectResLock: TPNCriticalSection read m_ObjectResLock write m_ObjectResLock;
    property FNewObjectCount: Int64 read m_nNewObjectCount;
    property FFreeObjectCount: Int64 read m_nFreeObjectCount;
  public
    function AllocateFreeObjectFromPool: TPNObject;       // �������PNObject
    procedure ReleaseObjectToPool(FObject: TPNObject);    // ���տ���PNObject
    procedure FreeObjects;                                // �ͷ�����PNObject
    function GetObjectCount: Integer;                     // �õ�����PNObject������
    procedure SetMaxFreeObject(m_MaxNumber: Integer);     // ���ó��������������
  published
    property FMaxNumberOfFreeObject: Integer read m_iMaxNumberOfFreeObject write SetMaxFreeObject;
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

constructor TPNObjectRes.Create;
begin
  inherited Create;
  m_nNewObjectCount := 0;
  m_nFreeObjectCount := 0;
  m_nObjectResCount := 0;
  m_iMaxNumberOfFreeObject := 10;
  m_pFreeObjectList := nil;
  m_ObjectResLock := TPNCriticalSection.Create;
  m_ObjectResLock.SetLockName('m_ObjectResLock');
end;
   
destructor TPNObjectRes.Destroy;
begin
  FreeObjects;
  FreeAndNil(m_ObjectResLock);
  inherited Destroy;
end;

function TPNObjectRes.GetObjectCount: Integer;
begin
  Result := m_nObjectResCount;
end;

procedure TPNObjectRes.SetMaxFreeObject(m_MaxNumber: Integer);
begin
  if m_MaxNumber>=0 then
    m_iMaxNumberOfFreeObject := m_MaxNumber;
end;

function TPNObjectRes.AllocateFreeObjectFromPool: TPNObject;
var
  m_pPNObject: TPNObject;
begin
  if not Assigned(m_OnCreateObject) then
  begin
    Result := nil;
    raise Exception.Create('m_OnCreateObject IS NULL.');
    Exit;
  end;


  m_ObjectResLock.Lock;
  if ( m_pFreeObjectList = nil ) then
  begin
    m_nNewObjectCount := m_nNewObjectCount + 1;
    m_ObjectResLock.UnLock;
    m_pPNObject := m_OnCreateObject;
  end
  else
  begin
    m_pPNObject := m_pFreeObjectList;
    m_pFreeObjectList := m_pFreeObjectList.m_pNext;
    Dec(m_nObjectResCount);
    m_ObjectResLock.UnLock;
  end;

  if m_pPNObject <> nil then
    m_pPNObject.InitObject;
  Result := m_pPNObject;
end;

procedure TPNObjectRes.ReleaseObjectToPool(FObject: TPNObject);
begin
  if not Assigned(FObject) then
    Exit;

  m_ObjectResLock.Lock;
  try
    if ( m_nObjectResCount < m_iMaxNumberOfFreeObject) then
    begin
      FObject.m_pNext := m_pFreeObjectList;
      m_pFreeObjectList := FObject;
      Inc(m_nObjectResCount);
    end
    else
    begin
      m_nFreeObjectCount := m_nFreeObjectCount + 1;
      FreeAndNil(FObject);
    end;
  finally
    m_ObjectResLock.UnLock;
  end;
end;

procedure TPNObjectRes.FreeObjects;
var
  m_pDIFreeObject: TPNObject;
  m_pDINextObject: TPNObject;
begin
  m_pDIFreeObject := nil;

  m_ObjectResLock.Lock;
  try
    m_pDIFreeObject := m_pFreeObjectList;
    while (m_pDIFreeObject<> nil) do
    begin
      m_pDINextObject := m_pDIFreeObject.m_pNext;
      if Assigned(m_pDIFreeObject) then
        FreeAndNil(m_pDIFreeObject);
      Dec(m_nObjectResCount);
      m_pDIFreeObject := m_pDINextObject;
    end;
    m_pFreeObjectList := nil;
    m_nObjectResCount := 0;
  finally
    m_ObjectResLock.UnLock;
  end;
end;

end.



