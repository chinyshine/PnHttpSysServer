{******************************************************************************}
{                                                                              }
{       Delphi PnHttpSysServer                                                 }
{                                                                              }
{       Copyright (c) 2018 pony,����(7180001@qq.com)                           }
{                                                                              }
{       Homepage: https://github.com/pony5551/PnHttpSysServer                  }
{                                                                              }
{******************************************************************************}
unit uPNCriticalSection;

interface

uses
  System.SysUtils,
  System.SyncObjs;
  
type
  TPNCriticalSection = class
  protected
//  {$IFDEF _YCPROJECT_LOCK_MONITOR}
//    m_dBegin: Integer;
//  {$ENDIF}
    m_LockName: string;
    m_CriticalSection: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetLockName(m_sLockName: String);
    procedure Lock;
    procedure UnLock;
  end;

var
  G_LockCount: Integer;


implementation

constructor TPNCriticalSection.Create;
begin
  inherited Create;
  m_CriticalSection := TCriticalSection.Create;
end;

destructor TPNCriticalSection.Destroy;
begin
  FreeAndNil(m_CriticalSection);
  inherited Destroy;
end;

procedure TPNCriticalSection.SetLockName(m_sLockName: String);
begin
  m_LockName := m_sLockName;
end;
     
procedure TPNCriticalSection.Lock;
begin
//  {$IFDEF _YCPROJECT_LOCK_MONITOR}
//    G_LockCount := G_LockCount + 1;
//    m_dBegin := GetTickCount;
//    OutputDebugString(PChar(Format('��: %s, ����ʱ�ȴ�����: %d.', [m_LockName, G_LockCount])));
//  {$ENDIF}

  m_CriticalSection.Enter;

//  {$IFDEF _YCPROJECT_LOCK_MONITOR}
//    OutputDebugString(PChar(Format('��: %s, �ȴ�����: %d, Lockǰ�ȴ�ʱ��: %d.', [m_LockName, G_LockCount, GetTickCount-m_dBegin])));
//  {$ENDIF}
end;

procedure TPNCriticalSection.UnLock;
begin
  m_CriticalSection.Leave;

//  {$IFDEF _YCPROJECT_LOCK_MONITOR}
//    G_LockCount := G_LockCount - 1;
//    OutputDebugString(PChar(Format('��: %s,                   ����ʱ��: %d.',
//                                       [m_LockName, GetTickCount-m_dBegin])));
//    OutputDebugString(PChar(Format('��: %s�˳�, �ȴ�����: %d.', [m_LockName, G_LockCount])));
//  {$ENDIF}
end;


initialization
  G_LockCount := 0;
  
finalization

end.







