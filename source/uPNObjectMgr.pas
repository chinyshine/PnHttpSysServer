{******************************************************************************}
{                                                                              }
{       Delphi PnHttpSysServer                                                 }
{                                                                              }
{       Copyright (c) 2018 pony,����(7180001@qq.com)                           }
{                                                                              }
{       Homepage: https://github.com/pony5551/PnHttpSysServer                  }
{                                                                              }
{******************************************************************************}
unit uPNObjectMgr;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  uPNObject,
  uPNCriticalSection;

//{$I PNIOCP.inc}
  
type
  // TPNObjectNode�ڵ�
  PTPNObjectNode = ^TPNObjectNode;
  TPNObjectNode = record
    m_MapID:      Integer;                                // MapID
    m_IsUsed:     Boolean;                                // �Ƿ�Ϊ��Ч�ڵ�
    m_pPNObject:  TPNObject;                              // TPNObject
  end;

  TPNObjectMgr = Class
  private
    m_Buckets:                TList;                      // ����������
    m_FreeBuckets:            TQueue<PTPNObjectNode>;     // ���нڵ�
    m_nActiveCount:           Integer;                    // Map�л�ڵ���
    m_nObjectCount:           Integer;                    // Map��������
    m_ObjectMgrLock:          TPNCriticalSection;         // ��
  public
    function AddPNObject(FObject: TPNObject): Boolean;    // ����PNObject���б�
    function RemovePNObject(FObject: TPNObject): Boolean; // ��PNObject���б���ɾ��
    procedure FreeObjects;                                // �ͷ�����PNObject
    function GetActiveObjectCount: Integer;               // �õ��PNObject������
    function GetObjectCount: Integer;                     // �õ�����PNObject������

  published
    property FObjectMgrLock: TPNCriticalSection read m_ObjectMgrLock write m_ObjectMgrLock;
    property FBuckets: TList read m_Buckets write m_Buckets;

  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

constructor TPNObjectMgr.Create;
begin
  inherited Create;
  m_nActiveCount := 0;
  m_nObjectCount := 0;
  m_FreeBuckets := TQueue<PTPNObjectNode>.Create;
  m_Buckets := TList.Create;
  m_ObjectMgrLock := TPNCriticalSection.Create;
  m_ObjectMgrLock.SetLockName('TPNObjectMgr');
end;

destructor TPNObjectMgr.Destroy;
var
  I: Integer;
begin
  FreeObjects;
  m_ObjectMgrLock.Lock;
  for I := m_Buckets.Count - 1 downto 0 do
    Dispose(m_Buckets[I]);
  m_ObjectMgrLock.UnLock;

  FreeAndNil(m_Buckets);
  FreeAndNil(m_FreeBuckets);
  FreeAndNil(m_ObjectMgrLock);
  inherited Destroy;
end;

function TPNObjectMgr.GetActiveObjectCount: Integer;
begin
  Result := m_nActiveCount;
end;

function TPNObjectMgr.GetObjectCount: Integer;
begin
  Result := m_nObjectCount;
end;

function TPNObjectMgr.AddPNObject(FObject: TPNObject): Boolean;
var
  pNode: PTPNObjectNode;
begin
  Result := FALSE;
  if not Assigned(FObject) then
    Exit;

  m_ObjectMgrLock.Lock;
  try
    if m_FreeBuckets.Count>0 then
    begin
      //����
      pNode := m_FreeBuckets.Dequeue;
      pNode^.m_IsUsed := TRUE;
      pNode^.m_pPNObject := FObject;
      FObject.m_MapID := pNode^.m_MapID;
      Inc(m_nActiveCount);
    end
    else
    begin
      New(pNode);
      pNode^.m_pPNObject := FObject;
      pNode^.m_IsUsed := TRUE;
      pNode^.m_MapID := m_nObjectCount;
      FObject.m_MapID := m_nObjectCount;
      Inc(m_nActiveCount);
      Inc(m_nObjectCount);
      m_Buckets.Add(pNode);
    end;
    Result := TRUE;
  finally
    m_ObjectMgrLock.UnLock;
  end;
//  {$IFDEF _ICOP_DEBUG}
//      _GlobalLogger.AppendErrorLogMessage('TPNObjectMgr.AddPNObject, MapID: %d, Count: %d.',
//                                          [FObject.m_MapID, m_nObjectCount]);
//  {$ENDIF}
end;

function TPNObjectMgr.RemovePNObject(FObject: TPNObject): Boolean;
begin
  Result := FALSE;
  if not Assigned(FObject) then
    Exit;

  m_ObjectMgrLock.Lock;
  try
    if not (FObject.m_MapID >= m_nObjectCount) then
    begin
      if PTPNObjectNode(m_Buckets[FObject.m_MapID])^.m_IsUsed then
      begin
        PTPNObjectNode(m_Buckets[FObject.m_MapID])^.m_pPNObject := nil;
        PTPNObjectNode(m_Buckets[FObject.m_MapID])^.m_IsUsed := FALSE;
        //���
        m_FreeBuckets.Enqueue(PTPNObjectNode(m_Buckets[FObject.m_MapID]));
        Dec(m_nActiveCount);
        Result := TRUE;

//        {$IFDEF _ICOP_DEBUG}
//           _GlobalLogger.AppendErrorLogMessage('RemovePNObject�ɹ�, MapID: %d, �Count: %d.',
//                                              [ FObject.m_MapID, m_nActiveCount]);
//        {$ENDIF}
      end
      else
      begin
//        {$IFDEF _ICOP_DEBUGERR}
//           _GlobalLogger.AppendErrorLogMessage('RemovePNObjectʧ��, MapID: %d, �Count: %d.',
//                                              [ FObject.m_MapID, m_nActiveCount]);
//        {$ENDIF}
      end;
    end
    else
    begin
//      {$IFDEF _ICOP_DEBUGERR}
//          _GlobalLogger.AppendErrorLogMessage('RemovePNObject����, MapID: %d, Count: %d.',
//                                              [FObject.m_MapID, m_nObjectCount]);
//      {$ENDIF}
    end;

  finally
    m_ObjectMgrLock.UnLock;
  end;
end;

procedure TPNObjectMgr.FreeObjects;
var
  I: Integer;
begin
  m_ObjectMgrLock.Lock;
  try
    for I := 0 to m_Buckets.Count-1 do
    begin
      if ( (PTPNObjectNode(m_Buckets[I])^.m_IsUsed) and
           (PTPNObjectNode(m_Buckets[I])^.m_pPNObject<>nil) ) then
      begin
        FreeAndNil(PTPNObjectNode(m_Buckets[I])^.m_pPNObject);
        PTPNObjectNode(m_Buckets[I])^.m_IsUsed := FALSE;
        PTPNObjectNode(m_Buckets[I])^.m_pPNObject := nil;
        Dec(m_nActiveCount);
      end;
    end;
  finally
    m_ObjectMgrLock.UnLock;
  end;
end;

end.


