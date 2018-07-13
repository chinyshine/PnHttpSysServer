program HttpSysServerDemo;

{$APPTYPE CONSOLE}

{$R *.res}

//ʹ��Synopse�Ż��ַ�copy
{$I Synopse.inc}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  SynCommons,
  SynZip,
  uPNCriticalSection,
  uPnHttpSys.Comm,
  uPnHttpSys.Api,
  uPNHttpSysServer,
  uPNSysThreadPool,
  uPNDebug,
  qjson,
  uUpload in 'uUpload.pas';


type
  TTestServer = class
  protected
    fWinThPool: TWinThreadPool;
    fUpProcessLock: TPNCriticalSection;
    fUpProcessList: TObjectDictionary<string,PUploadProcessInfo>;
    fPath: TFileName;
    fServer: TPnHttpSysServer;
    procedure WorkItemCallBack(Sender: TObject);
    procedure CallWorkItem(Ctxt: TPnHttpServerContext; AFileUpload: Boolean;
      AReadBuf: PAnsiChar; AReadBufLen: Cardinal);
    function Process(Ctxt: TPnHttpServerContext; AFileUpload: Boolean;
      AReadBuf: PAnsiChar; AReadBufLen: Cardinal): Cardinal;
  public
    constructor Create(const Path: TFileName);
    destructor Destroy; override;
  end;


{ TTestServer }
constructor TTestServer.Create(const Path: TFileName);
var
  aFilePath: string;
begin
  fWinThPool := TWinThreadPool.Create;
  fWinThPool.Start;
  fUpProcessLock := TPNCriticalSection.Create;
  fUpProcessList := TObjectDictionary<string,PUploadProcessInfo>.Create();
  fPath := IncludeTrailingPathDelimiter(Path);
  fServer := TPnHttpSysServer.Create(1,1000);
  fServer.AddUrl('/','8080',false,'+',true);
  fServer.RegisterCompress(CompressDeflate);
//  fServer.OnCallWorkItemEvent := CallWorkItem;
  fServer.OnRequest := Process;
  fServer.HTTPQueueLength := 100000;
//  fServer.MaxConnections := 0;
//  fServer.MaxBandwidth := 0;
  aFilePath := Format('%sw3log',[ExeVersion.ProgramFilePath]);
  fServer.LogStart(aFilePath);
  fServer.Start;
end;

destructor TTestServer.Destroy;
begin
  fServer.LogStop;
  fServer.Free;
  fUpProcessList.Free;
  fUpProcessLock.Free;
  fWinThPool.Free;
  inherited;
end;

procedure TTestServer.WorkItemCallBack(Sender: TObject);
var
  Ctxt: TPnHttpServerContext;
begin
  Ctxt := TPnHttpServerContext(Sender);

  //Ctxt.OutContent := Format('hello call %d', [GetCurrentThreadId]);
  Ctxt.OutContent := 'hello call';
  Ctxt.OutContentType := HTML_CONTENT_TYPE;
  Ctxt.OutStatusCode := 200;
  //ʹ��CallWorkItem�¼��������SendResponse
  Ctxt.SendResponse;
end;


procedure TTestServer.CallWorkItem(Ctxt: TPnHttpServerContext; AFileUpload: Boolean; AReadBuf: PAnsiChar; AReadBufLen: Cardinal);
begin
  //���̴߳���������Io�̣߳���һ���̶Ƚ�������Ч��
  //�����������Ҫ�������㷨����ļ����������ʱ��Ƚϳ�ʱ����ʹ��
  fWinThPool.QueueUserWorkItem(WorkItemCallBack, Ctxt);
end;


function TTestServer.Process(Ctxt: TPnHttpServerContext; AFileUpload: Boolean;
      AReadBuf: PAnsiChar; AReadBufLen: Cardinal): Cardinal;

const
  sBoundary: SockString = 'boundary=';

var
  W: TTextWriter;
  FileName: TFileName;
  FN, SRName, href: RawUTF8;
  i: integer;
  SR: TSearchRec;
  json,
  desjson: TQJson;
  sUrls: TArray<string>;
  sUrlsList: TStringList;
  up_processid: string;
  pUpInfo: PUploadProcessInfo;
  bufsCount,
  bufsCountStart: Integer;

  Bufpar: array of AnsiChar;
  BufparLen: Integer;

  nPos1: Integer;


  //�����ϴ�����δ���
  procedure RecvUpBufs;
  var
    I: Integer;
    nPosChar: PAnsiChar;
  begin
    if pUpInfo=nil then
      Exit;

    bufsCount := Length(pUpInfo^.bufs);
    SetLength(pUpInfo^.bufs, bufsCount+1);
    pUpInfo^.bufs[bufsCount].buflen := AReadBufLen;
    SetLength(pUpInfo^.bufs[bufsCount].buf, AReadBufLen);
    Move(AReadBuf^, PAnsiChar(@pUpInfo^.bufs[bufsCount].buf[0])^, AReadBufLen);


    debugEx('bufsCount: %d', [Length(pUpInfo^.bufs)]);
    bufsCountStart := Length(pUpInfo^.bufs)-2;
    if bufsCountStart>=0 then
    begin

      for I := bufsCountStart to bufsCountStart+1 do
      begin
        debugEx('I:%d', [I]);
        BufparLen := Length(Bufpar);
        SetLength(Bufpar, BufparLen+pUpInfo^.bufs[I].buflen);
        Move(PAnsiChar(@pUpInfo^.bufs[I].buf[0])^, PAnsiChar(@Bufpar[BufparLen])^, pUpInfo^.bufs[I].buflen);
      end;

      nPosChar := StrPos(PAnsiChar(@Bufpar[0]),PAnsiChar(pUpInfo^.boundaryStr));
      debugEx('nPosChar: %s', [nPosChar]);

    end;

  end;


  procedure upload_asp;
  begin
      sUrlsList := TStringList.Create;
      try
          sUrls := string(Ctxt.URL).Split(['?']);
          if Length(sUrls)>=2 then begin
            sUrlsList.NameValueSeparator := '=';
            sUrlsList.Text := sUrls[1].Replace('&', #13#10, [rfReplaceAll, rfIgnoreCase]);
          end;

          //=====�ϴ�����ʼ=====
          if AFileUpload then begin
            up_processid := sUrlsList.Values['processid'];


            if Ctxt.InContentLengthRead>=Ctxt.InContentLength then begin

              //���½���
              fUpProcessLock.Lock;
              try
                if fUpProcessList.ContainsKey(up_processid) then
                begin
                  pUpInfo := fUpProcessList.Items[up_processid];
                  if pUpInfo<>nil then
                  begin
                    pUpInfo^.TotalBytes := Ctxt.InContentLength;
                    pUpInfo^.UploadedBytes := Ctxt.InContentLengthRead;
                    pUpInfo^.LastActivity := GetTickCount64;
                    pUpInfo^.ReadyState := 'complete';


                    //�����ϴ��ֽ�3
                    RecvUpBufs;

                  end;
                end
                else begin
                  //�µ��ϴ�
                  new(pUpInfo);
                  pUpInfo^.InitObj;
                  pUpInfo^.TotalBytes := Ctxt.InContentLength;
                  pUpInfo^.UploadedBytes := Ctxt.InContentLengthRead;
                  pUpInfo^.LastActivity := GetTickCount64;
                  pUpInfo^.ReadyState := 'complete';

                  //�����ϴ��ֽ�3?
                  RecvUpBufs;

                  fUpProcessList.Add(up_processid, pUpInfo);
                end;
              finally
                fUpProcessLock.UnLock;
              end;


//              //�����ϴ�����
//              for I := 0 to Length(pUpInfo^.bufs)-1 do
//              begin
//
//
//              end;

              //�ϴ����
              Ctxt.OutContent := StringToUTF8(Format('�ϴ����: %d/%d', [Ctxt.InContentLength, Ctxt.InContentLengthRead]));
              Ctxt.OutContentType := HTML_CONTENT_TYPE;
              result := 200;
            end
            else begin
              //�ϴ���
              //debugEx('�ϴ���: %d/%d/%d', [AReadBufLen, Ctxt.InContentLength, Ctxt.InContentLengthRead]);

              fUpProcessLock.Lock;
              try
                if fUpProcessList.ContainsKey(up_processid) then
                begin
                  pUpInfo := fUpProcessList.Items[up_processid];
                  pUpInfo^.TotalBytes := Ctxt.InContentLength;
                  pUpInfo^.UploadedBytes := Ctxt.InContentLengthRead;
                  pUpInfo^.LastActivity := GetTickCount64;
                  pUpInfo^.ReadyState := 'loading';

                  //�����ϴ��ֽ�2
                  RecvUpBufs;

                end
                else begin
                  //�µ��ϴ�
                  new(pUpInfo);
                  pUpInfo^.InitObj;
                  pUpInfo^.TotalBytes := Ctxt.InContentLength;
                  pUpInfo^.UploadedBytes := Ctxt.InContentLengthRead;
                  pUpInfo^.LastActivity := GetTickCount64;
                  pUpInfo^.ReadyState := 'loading';

                  //boundary=
                  //boundaryStr
                  nPos1 := SynCommons.Pos(sBoundary, Ctxt.InContentType);
                  if nPos1>0 then
                  begin
                    nPos1 := (nPos1-1) + Length(sBoundary);
                    SetLength(pUpInfo^.boundaryStr, Length(Ctxt.InContentType)-nPos1+2); //+2ǰ����ַ���--
                    Move(PAnsiChar(PAnsiChar(Ctxt.InContentType)+nPos1)^, PAnsiChar(PAnsiChar(pUpInfo^.boundaryStr)+2)^, Length(Ctxt.InContentType)-nPos1);
                    //ǰ����ַ���--
                    PAnsiChar(pUpInfo^.boundaryStr)^ := '-';
                    PAnsiChar(PAnsiChar(pUpInfo^.boundaryStr)+1)^ := '-';
                  end;

                  //�����ϴ��ֽ�1
                  RecvUpBufs;

                  fUpProcessList.Add(up_processid, pUpInfo);
                end;
              finally
                fUpProcessLock.UnLock;
              end;

            end;
          end
          else begin
            Ctxt.OutContent := 'No FileUpload';
            Ctxt.OutContentType := HTML_CONTENT_TYPE;
            result := 200;
          end;
          //=====�ϴ��������=====

      finally
        sUrlsList.Free;
      end;
  end;


  procedure getprocess_asp;
  begin
      sUrlsList := TStringList.Create;
      try
          sUrls := string(Ctxt.URL).Split(['?']);
          if Length(sUrls)>=2 then begin
            sUrlsList.NameValueSeparator := '=';
            sUrlsList.Text := sUrls[1].Replace('&', #13#10, [rfReplaceAll, rfIgnoreCase]);
          end;
          up_processid := sUrlsList.Values['processid'];

          //ȡ�ý�����Ϣ
          fUpProcessLock.Lock;
          try
            if fUpProcessList.ContainsKey(up_processid) then
            begin
              pUpInfo := fUpProcessList.Items[up_processid];
              if pUpInfo<>nil then
              begin

                json := TQJson.Create;
                try
                  json.ForcePath('TotalBytes').AsInt64 := pUpInfo^.TotalBytes;
                  json.ForcePath('UploadedBytes').AsInt64 := pUpInfo^.UploadedBytes;
                  json.ForcePath('StartTime').AsInt64 := pUpInfo^.StartTime;
                  json.ForcePath('LastActivity').AsInt64 := pUpInfo^.LastActivity;
                  json.ForcePath('ReadyState').AsString := pUpInfo^.ReadyState;
                  json.ForcePath('ElapsedTime').AsString := pUpInfo^.GetElapsedTime;
                  json.ForcePath('TransferRate').AsString := pUpInfo^.GetTransferRate;
                  json.ForcePath('Percentage').AsString := pUpInfo^.GetPercentage;
                  json.ForcePath('TimeLeft').AsString := pUpInfo^.TimeLeft;

                  Ctxt.OutContent := StringToUTF8(json.Encode(False));

                  if pUpInfo^.ReadyState='complete' then
                  begin
                    fUpProcessList.Remove(up_processid);
                    Dispose(pUpInfo);
                  end;


                finally
                  json.Free;
                end;

              end;
            end;
          finally
            fUpProcessLock.UnLock;
          end;

          Ctxt.OutContentType := HTML_CONTENT_TYPE;
          result := 200;

      finally
        sUrlsList.Free;
      end;
  end;


  procedure hrefCompute;
  begin
    SRName := StringToUTF8(SR.Name);
    href := FN+StringReplaceChars(SRName,'\','/');
  end;

begin
  //writeln(Ctxt.Method,' ',Ctxt.URL);
  if IdemPChar(pointer(Ctxt.URL),'/hello') then begin
    Ctxt.OutContent := 'hello world';
    Ctxt.OutContentType := HTML_CONTENT_TYPE;
    result := 200;
    Exit;
  end
  //�ϴ��ļ�
  else if IdemPChar(pointer(Ctxt.URL),'/fileupload/upload.asp') then begin

    upload_asp;

    Exit;
  end
  //�ϴ�����
  else if IdemPChar(pointer(Ctxt.URL),'/fileupload/getprocess.asp') then begin

    getprocess_asp;

    Exit;
  end;

  //�ļ���Ŀ¼����
  FN := StringReplaceChars(UrlDecode(copy(Ctxt.URL,1,maxInt)),'/','\');
  if PosEx('..',FN)>0 then begin
    result := 404; // circumvent obvious potential security leak
    exit;
  end;
  while (FN<>'') and (FN[1]='\') do
    delete(FN,1,1);
  while (FN<>'') and (FN[length(FN)]='\') do
    delete(FN,length(FN),1);
  FileName := fPath+UTF8ToString(FN);
  if DirectoryExists(FileName) then begin
    // reply directory listing as html
    W := TTextWriter.CreateOwnedStream;
    try
      W.Add('<html><body style="font-family: Arial">'+
        '<h3>%</h3><p><table>',[FN]);
      FN := StringReplaceChars(FN,'\','/');
      if FN<>'' then
        FN := FN+'/';
      if FindFirst(FileName+'\*.*',faDirectory,SR)=0 then begin
        repeat
          if (SR.Attr and faDirectory<>0) and (SR.Name<>'.') then begin
            hrefCompute;
            if SRName='..' then
            begin
              i := length(FN);
              while (i>0) and (FN[i]='/') do dec(i);
              while (i>0) and (FN[i]<>'/') do dec(i);
              href := copy(FN,1,i);
            end;
            W.Add('<tr><td><b><a href="/%">[%]</a></b></td></tr>',[href,SRName]);
          end;
        until FindNext(SR)<>0;
        FindClose(SR);
      end;
      if FindFirst(FileName+'\*.*',faAnyFile-faDirectory-faHidden,SR)=0 then begin
        repeat
          hrefCompute;
          if SR.Attr and faDirectory=0 then
            W.Add('<tr><td><b><a href="/%">%</a></b></td><td>%</td><td>%</td></td></tr>',
              [href,SRName,KB(SR.Size),DateTimeToStr(
                {$ifdef ISDELPHIXE2}SR.TimeStamp{$else}FileDateToDateTime(SR.Time){$endif})]);
        until FindNext(SR)<>0;
        FindClose(SR);
      end;
      W.AddShort('</table></p><p><i>Powered by httpapi <strong>');
      W.AddClassName(Ctxt.Server.ClassType);
      W.AddShort('</strong></i></p></body></html>');
      Ctxt.OutContent := W.Text;
      Ctxt.OutContentType := HTML_CONTENT_TYPE;
      result := 200;
    finally
      W.Free;
    end;
  end
  else begin
    // http.sys will send the specified file from kernel mode
    Ctxt.OutContent := StringToUTF8(FileName);
    Ctxt.OutContentType := HTTP_RESP_STATICFILE;
    result := 200; // THttpApiServer.Execute will return 404 if not found
  end;
end;



begin
  ReportMemoryLeaksOnShutDown := True;

  with TTestServer.Create(Format('%swww', [ExeVersion.ProgramFilePath])) do
  try
    write('Server is now running on http://localhost:8080/'#13#10#13#10+
      'Press [Enter] to quit');
    writeln('');
    readln;
  finally
    Free;
  end;
end.
