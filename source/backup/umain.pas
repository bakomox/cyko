unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  Menus, StdCtrls, ComCtrls, ExtCtrls, Process, Windows;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    btnEnqueue: TButton;
    btnEncode: TButton;
    btnAdd: TButton;
    btnAbort: TButton;
    btnOutput: TButton;
    cboMode: TComboBox;
    cboEncoder: TComboBox;
    chkShutdown: TCheckBox;
    chkShowConsole: TCheckBox;
    chkHardSubs: TCheckBox;
    cboPresets: TComboBox;
    cboTunes: TComboBox;
    cboProfiles: TComboBox;
    grpProfiles: TGroupBox;
    grpTunes: TGroupBox;
    grpPresets: TGroupBox;
    lblEncoder: TLabel;
    SelectDirectoryDialog1: TSelectDirectoryDialog;
    tglResolution: TToggleBox;
    txtOutput: TEdit;
    txtScanStatus: TEdit;
    Label3: TLabel;
    Label6: TLabel;
    mnu2ClearSelected: TMenuItem;
    prgEncode: TProgressBar;
    prgScan: TProgressBar;
    tbsAbout: TTabSheet;
    tmrScan: TTimer;
    tmrEncode: TTimer;
    txtOut: TEdit;
    lblAudioValue: TLabel;
    lblResolution: TLabel;
    mnu2FullCmd: TMenuItem;
    txtAudioValue: TEdit;
    txtResolution: TEdit;
    txtVideoValue: TEdit;
    grpSettings: TGroupBox;
    lblMode: TLabel;
    lstOut: TListBox;
    mnuFullPath: TMenuItem;
    mnu2Clear: TMenuItem;
    mnuClearSelected: TMenuItem;
    PopupMenu2: TPopupMenu;
    tbsOptions: TTabSheet;
    tbsInput: TTabSheet;
    tbsOutput: TTabSheet;
    lstAdd: TListBox;
    mnuClear: TMenuItem;
    OpenDialog1: TOpenDialog;
    pgcMain: TPageControl;
    PopupMenu1: TPopupMenu;
    procedure btnAbortClick(Sender: TObject);
    procedure btnAddClick(Sender: TObject);
    procedure btnEncodeClick(Sender: TObject);
    procedure btnEnqueueClick(Sender: TObject);
    procedure btnOutputClick(Sender: TObject);
    procedure cboEncoderChange(Sender: TObject);
    procedure cboModeChange(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of string);
    procedure lstOutClick(Sender: TObject);
    procedure mnu2ClearClick(Sender: TObject);
    procedure mnu2ClearSelectedClick(Sender: TObject);
    procedure mnu2FullCmdClick(Sender: TObject);
    procedure mnuClearClick(Sender: TObject);
    procedure mnuClearSelectedClick(Sender: TObject);
    procedure mnuFullPathClick(Sender: TObject);
    procedure pgcMainMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: integer);
    procedure tglResolutionChange(Sender: TObject);
    procedure tmrEncodeTimer(Sender: TObject);
    procedure tmrScanTimer(Sender: TObject);
    procedure txtAudioValueKeyPress(Sender: TObject; var Key: char);
    procedure txtResolutionKeyPress(Sender: TObject; var Key: char);
    procedure txtVideoValueChange(Sender: TObject);
    procedure txtVideoValueKeyPress(Sender: TObject; var Key: char);
  private
    { private declarations }
  public
    { public declarations }
    Hbk: Tprocess;
    HbkStr: TStringList;
    i: integer;
    ii: integer;
    encoded: boolean;
    EncoderString: string;
    resolutionString: string;
  end;

const
  SE_CREATE_TOKEN_NAME = 'SeCreateTokenPrivilege';
  SE_ASSIGNPRIMARYTOKEN_NAME = 'SeAssignPrimaryTokenPrivilege';
  SE_LOCK_MEMORY_NAME = 'SeLockMemoryPrivilege';
  SE_INCREASE_QUOTA_NAME = 'SeIncreaseQuotaPrivilege';
  SE_UNSOLICITED_INPUT_NAME = 'SeUnsolicitedInputPrivilege';
  SE_MACHINE_ACCOUNT_NAME = 'SeMachineAccountPrivilege';
  SE_TCB_NAME = 'SeTcbPrivilege';
  SE_SECURITY_NAME = 'SeSecurityPrivilege';
  SE_TAKE_OWNERSHIP_NAME = 'SeTakeOwnershipPrivilege';
  SE_LOAD_DRIVER_NAME = 'SeLoadDriverPrivilege';
  SE_SYSTEM_PROFILE_NAME = 'SeSystemProfilePrivilege';
  SE_SYSTEMTIME_NAME = 'SeSystemtimePrivilege';
  SE_PROF_SINGLE_PROCESS_NAME = 'SeProfileSingleProcessPrivilege';
  SE_INC_BASE_PRIORITY_NAME = 'SeIncreaseBasePriorityPrivilege';
  SE_CREATE_PAGEFILE_NAME = 'SeCreatePagefilePrivilege';
  SE_CREATE_PERMANENT_NAME = 'SeCreatePermanentPrivilege';
  SE_BACKUP_NAME = 'SeBackupPrivilege';
  SE_RESTORE_NAME = 'SeRestorePrivilege';
  SE_SHUTDOWN_NAME = 'SeShutdownPrivilege';
  SE_DEBUG_NAME = 'SeDebugPrivilege';
  SE_AUDIT_NAME = 'SeAuditPrivilege';
  SE_SYSTEM_ENVIRONMENT_NAME = 'SeSystemEnvironmentPrivilege';
  SE_CHANGE_NOTIFY_NAME = 'SeChangeNotifyPrivilege';
  SE_REMOTE_SHUTDOWN_NAME = 'SeRemoteShutdownPrivilege';
  SE_UNDOCK_NAME = 'SeUndockPrivilege';
  SE_SYNC_AGENT_NAME = 'SeSyncAgentPrivilege';
  SE_ENABLE_DELEGATION_NAME = 'SeEnableDelegationPrivilege';
  SE_MANAGE_VOLUME_NAME = 'SeManageVolumePrivilege';

function SetSuspendState(hibernate, forcecritical, disablewakeevent: Boolean): Boolean; stdcall; external 'powrprof.dll' name 'SetSuspendState';

function IsHibernateAllowed: Boolean; stdcall; external 'powrprof.dll' name 'IsPwrHibernateAllowed';

function IsPwrSuspendAllowed: Boolean; stdcall; external 'powrprof.dll' name 'IsPwrSuspendAllowed';

function IsPwrShutdownAllowed: Boolean; stdcall; external 'powrprof.dll' name 'IsPwrShutdownAllowed';

function LockWorkStation: Boolean; stdcall; external 'user32.dll' name 'LockWorkStation';



function GetConsoleWindow(): HWND; stdcall; external 'kernel32.dll';

var
  frmMain: TfrmMain;
  h: HWND;

implementation

function NTSetPrivilege(sPrivilege: string; bEnabled: Boolean): Boolean;
var
  hToken: THandle;
  TokenPriv: TOKEN_PRIVILEGES;
  PrevTokenPriv: TOKEN_PRIVILEGES;
  ReturnLength: Cardinal;
begin
  Result := True;
  // Only for Windows NT/2000/XP and later.
  if not (Win32Platform = VER_PLATFORM_WIN32_NT) then Exit;
  Result := False;

  // obtain the processes token
  if OpenProcessToken(GetCurrentProcess(),
    TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, hToken) then
  begin
    try
      // Get the locally unique identifier (LUID) .
      if LookupPrivilegeValue(nil, PChar(sPrivilege),
        TokenPriv.Privileges[0].Luid) then
      begin
        TokenPriv.PrivilegeCount := 1; // one privilege to set

        case bEnabled of
          True: TokenPriv.Privileges[0].Attributes  := SE_PRIVILEGE_ENABLED;
          False: TokenPriv.Privileges[0].Attributes := 0;
        end;

        ReturnLength := 0; // replaces a var parameter
        PrevTokenPriv := TokenPriv;

        // enable or disable the privilege

        AdjustTokenPrivileges(hToken, False, TokenPriv, SizeOf(PrevTokenPriv),
          PrevTokenPriv, ReturnLength);
      end;
    finally
      CloseHandle(hToken);
    end;
  end;
  // test the return value of AdjustTokenPrivileges.
  Result := GetLastError = ERROR_SUCCESS;
  if not Result then
    raise Exception.Create(SysErrorMessage(GetLastError));
end;

{ TfrmMain }

procedure TfrmMain.mnuClearClick(Sender: TObject);
begin
  lstadd.Clear;
end;

procedure TfrmMain.mnuClearSelectedClick(Sender: TObject);
begin
  lstAdd.Items.Delete(lstAdd.ItemIndex);
end;

procedure TfrmMain.mnuFullPathClick(Sender: TObject);
begin
  if lstAdd.getselectedtext <> '' then
    ShowMessage(lstAdd.GetSelectedText);
end;

procedure TfrmMain.pgcMainMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: integer);
begin
  if pgcMain.ActivePage = tbsOptions then
    txtVideoValue.SetFocus;
end;

procedure TfrmMain.tglResolutionChange(Sender: TObject);
begin
  if tglResolution.Caption = 'Height' then
  begin
    tglResolution.Caption := 'Width';
    txtResolution.SetFocus;
  end
  else
  begin
    tglResolution.Caption := 'Height';
    txtResolution.SetFocus;
  end;
end;

procedure TfrmMain.tmrEncodeTimer(Sender: TObject);
var
  hMenuHandle: HMENU;
begin
  prgEncode.StepIt;
  if prgEncode.Position = prgEncode.Max then
    prgEncode.Position := prgEncode.min;

  txtOut.Text := 'Encoding: ' + IntToStr(i + 1) + ' of ' +
    IntToStr(lstOut.Items.Count) + '; Press ' + '"' + 'Abort Encoding' +
    '"' + ' if you want to stop encoding';

  if (encoded = False) and (i <= lstOut.Items.Count - 1) then
  begin

    //Hbk.CommandLine := lstOut.Items[i];
    Hbk.Executable := 'HandbrakeCLI';
    Hbk.Parameters.Delimiter := '^';
    Hbk.Parameters.DelimitedText := lstOut.Items[i];
    Hbk.Options := [];
    if chkShowConsole.Checked = False then
    begin
      Hbk.ShowWindow := swoHIDE;
    end
    else if chkShowConsole.Checked = True then
    begin
      Hbk.ShowWindow := swoShow;
      AllocConsole();
    end;
    Hbk.Execute;
    encoded := True;

    hMenuHandle := GetSystemMenu(GetConsoleWindow(), False);
    DeleteMenu(hMenuHandle, SC_CLOSE, MF_BYCOMMAND);
    SetConsoleTitle('Cyko is powered by Handbrake CLI');
    DrawMenuBar(GetConsoleWindow());

  end;

  if (encoded = True) and (i <= lstOut.Items.Count - 1) and (Hbk.Running = False) then
  begin
    i := i + 1;
    encoded := False;
    FreeConsole();
  end;

  if (encoded = False) and (i = lstOut.items.Count) then
  begin
    chkShowConsole.Enabled := True;
    chkShutdown.Enabled := True;
    lstOut.Clear;
    tmrEncode.Enabled := False;
    if chkShutdown.Checked = True then
      begin
        NTSetPrivilege(SE_SHUTDOWN_NAME, True);
        ExitWindowsEx(EWX_SHUTDOWN or EWX_FORCE, 0);
      end;
    //ShowMessage('Encoding Done' + slinebreak + 'Output Location of file(s) is thesame as Input Location' + slinebreak + 'the Output filename have thesame name as Input filename just with added ' + '"' + '-OUT' + '"');
    ShowMessage('Encoding Done');
    prgEncode.Position := prgEncode.Min;
    btnEncode.Enabled := True;
    encoded := True;
    mnu2Clear.Enabled := True;
    mnu2ClearSelected.Enabled := True;
    btnEnqueue.Enabled := True;
    tbsInput.Show;
  end;

end;

procedure TfrmMain.tmrScanTimer(Sender: TObject);
begin
  prgScan.StepIt;
  if prgScan.Position = prgScan.Max then
    prgScan.Position := prgScan.Min;

  frmMain.txtScanStatus.Text :=
    'Scanning: ' + IntToStr(frmMain.ii + 1) + ' of ' + IntToStr(frmMain.lstAdd.Items.Count) +
    '; FileName: ' + ExtractFileName(frmMain.lstAdd.Items[frmMain.ii]);

  if frmMain.chkHardSubs.Checked = True then
  begin
    frmMain.lstOut.Items.add('-i ' + '"' +
      trim(frmMain.lstAdd.Items[frmMain.ii]) + '" ' + ' -f mp4 -o ' + '"' +
      trim(frmMain.txtOutput.Text) + '\' +
      stringReplace(ExtractFilename(frmMain.lstAdd.Items[frmMain.ii]),
      ExtractFileExt(frmMain.lstAdd.Items[frmMain.ii]), '-OUT.mp4', [rfReplaceAll, rfIgnoreCase]) +
      '" ' + frmMain.EncoderString + ' -m -E av_aac --mixdown stereo -B ' + trim(frmMain.txtAudioValue.Text) +
      frmMain.resolutionString + ' --non-anamorphic --keep-display-aspect -s 1 --subtitle-burned' + ' --all-audio');
  end
  else if frmMain.chkHardSubs.Checked = False then
  begin
    frmMain.lstOut.Items.add('-i ' + '"' +
      trim(frmMain.lstAdd.Items[frmMain.ii]) + '" ' + ' -f mkv -o ' + '"' +
      trim(frmMain.txtOutput.Text) + '\' +
      stringReplace(ExtractFilename(frmMain.lstAdd.Items[frmMain.ii]),
      ExtractFileExt(frmMain.lstAdd.Items[frmMain.ii]), '-OUT.mkv', [rfReplaceAll, rfIgnoreCase]) +
      '" ' + frmMain.EncoderString + ' -m -E opus --mixdown stereo -B ' + trim(frmMain.txtAudioValue.Text) +
      frmMain.resolutionString + ' --non-anamorphic --keep-display-aspect --subtitle-lang-list all --all-subtitles --subtitle-default' + ' --all-audio');
  end;

  frmMain.ii := frmMain.ii + 1;

  if frmMain.ii = frmMain.lstAdd.Items.Count then
  begin
     tmrScan.Enabled := False;
     ShowMessage('Scanning Done');
     btnEncode.Enabled := True;
     prgScan.Position := prgScan.Min;
     lstAdd.Clear;
     tbsOutput.Show;
     btnEnqueue.Enabled := True;
     btnAdd.Enabled := True;
     mnuClearSelected.Enabled := True;
     mnuClear.Enabled := True;
  end;

end;

procedure TfrmMain.txtAudioValueKeyPress(Sender: TObject; var Key: char);
begin
  //google ascii codes
  if not (Key in ['0'..'9', #8..#13]) then
    Key := #0;
end;

procedure TfrmMain.txtResolutionKeyPress(Sender: TObject; var Key: char);
begin
  if not (Key in ['0'..'9', #8..#13]) then
    Key := #0;
end;

procedure TfrmMain.txtVideoValueChange(Sender: TObject);
begin
  if cboMode.Text = trim('Target Quality') then
    txtVideoValue.MaxLength := 2;
  if cboMode.Text = trim('Target Bitrate') then
    txtVideoValue.MaxLength := 3;
end;

procedure TfrmMain.txtVideoValueKeyPress(Sender: TObject; var Key: char);
begin
  //google ascii codes
  if not (Key in ['0'..'9', #8..#13]) then
    Key := #0;
end;

procedure TfrmMain.btnEnqueueClick(Sender: TObject);
begin
  if (cboEncoder.ItemIndex = 0) then
  begin
    EncoderString := '-e x264_10bit';
  end

  else if (cboEncoder.ItemIndex = 1) then
  begin
    EncoderString := '-e x265_10bit';
  end;

  try
    if ((StrToInt(txtVideoValue.Text) < 20) or (StrToInt(txtVideoValue.Text) > 50)) and (cboMode.Text = 'Target Quality') then
    begin
      ShowMessage('Target Quality value must be >= 20 or <= 50');
      txtVideoValue.Text := '';
      txtVideoValue.SetFocus;
    end;
  except
    Exit;
  end;

  try
    if (StrToInt(txtVideoValue.Text) < 100) and (cboMode.Text = 'Target Bitrate') then
    begin
      ShowMessage('Target Bitrate value must be >= 100');
      txtVideoValue.Text := '';
      txtVideoValue.SetFocus;
    end;
  except
    Exit;
  end;

  try
    if (StrToInt(txtAudioValue.Text) < 40) then
    begin
      ShowMessage('Audio bitrate must not be less than 40');
      txtAudioValue.Text := '';
      txtAudioValue.SetFocus;
    end;
  except
    Exit;
  end;

  if tglResolution.Checked = False then
  begin
    resolutionString := ' -l ' + trim(txtResolution.Text);
  end
  else if tglResolution.Checked = True then
  begin
    resolutionString := ' -w ' + trim(txtResolution.Text);
  end;

  if cboEncoder.ItemIndex = 0 then //x264 presets, tunes, profiles
  begin
       if (cboMode.ItemIndex = 0) and (txtVideoValue.Text <> '') then
       begin
            EncoderString := EncoderString + ' ' + '-q ' + Trim(txtVideoValue.Text);
       end
       else if (cboMode.ItemIndex = 1) and (txtVideoValue.Text <> '') then
       begin
            EncoderString := EncoderString + ' ' + '-2 -T -b ' + Trim(txtVideoValue.Text);
       end;

       if cboPresets.ItemIndex = 0 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset ultrafast';
       end
       else if cboPresets.ItemIndex = 1 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset superfast';
       end
       else if cboPresets.ItemIndex = 2 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset veryfast';
       end
       else if cboPresets.ItemIndex = 3 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset faster';
       end
       else if cboPresets.ItemIndex = 4 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset fast';
       end
       else if cboPresets.ItemIndex = 5 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset medium';
       end
       else if cboPresets.ItemIndex = 6 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset slow';
       end
       else if cboPresets.ItemIndex = 7 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset slower';
       end
       else if cboPresets.ItemIndex = 8 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset veryslow';
       end
       else if cboPresets.ItemIndex = 9 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset placebo';
       end;

       if cboTunes.ItemIndex = 0 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune film';
       end
       else if cboTunes.ItemIndex = 1 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune animation';
       end
       else if cboTunes.ItemIndex = 2 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune grain';
       end
       else if cboTunes.ItemIndex = 3 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune stillimage';
       end
       else if cboTunes.ItemIndex = 4 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune psnr';
       end
       else if cboTunes.ItemIndex = 5 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune ssim';
       end
       else if cboTunes.ItemIndex = 6 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune fastdecode';
       end
       else if cboTunes.ItemIndex = 7 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune zerolatency';
       end;

       if cboProfiles.ItemIndex = 0 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-profile auto';
       end
       else if cboProfiles.ItemIndex = 1 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-profile high10';
       end;

  end
  else if cboEncoder.ItemIndex = 1 then //x265 presets, tunes, profiles
  begin
       if (cboMode.ItemIndex = 0) and (txtVideoValue.Text <> '') then
       begin
            EncoderString := EncoderString + ' ' + '-q ' + Trim(txtVideoValue.Text);
       end
       else if (cboMode.ItemIndex = 1) and (txtVideoValue.Text <> '') then
       begin
            EncoderString := EncoderString + ' ' + '-2 -T -b ' + Trim(txtVideoValue.Text);
       end;

       if cboPresets.ItemIndex = 0 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset ultrafast';
       end
       else if cboPresets.ItemIndex = 1 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset superfast';
       end
       else if cboPresets.ItemIndex = 2 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset veryfast';
       end
       else if cboPresets.ItemIndex = 3 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset faster';
       end
       else if cboPresets.ItemIndex = 4 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset fast';
       end
       else if cboPresets.ItemIndex = 5 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset medium';
       end
       else if cboPresets.ItemIndex = 6 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset slow';
       end
       else if cboPresets.ItemIndex = 7 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset slower';
       end
       else if cboPresets.ItemIndex = 8 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset veryslow';
       end
       else if cboPresets.ItemIndex = 9 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-preset placebo';
       end;

       if cboTunes.ItemIndex = 0 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune psnr';
       end
       else if cboTunes.ItemIndex = 1 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune ssim';
       end
       else if cboTunes.ItemIndex = 2 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune grain';
       end
       else if cboTunes.ItemIndex = 3 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune zerolatency';
       end
       else if cboTunes.ItemIndex = 4 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune fastdecode';
       end
       else if cboTunes.ItemIndex = 5 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-tune animation';
       end;

       if cboProfiles.ItemIndex = 0 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-profile auto';
       end
       else if cboProfiles.ItemIndex = 1 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-profile main10';
       end
       else if cboProfiles.ItemIndex = 2 then
       begin
            EncoderString := EncoderString + ' ' + '--encoder-profile main10-intra';
       end;

  end;

  if lstAdd.items.Count = 0 then
  begin
    exit;
  end;

  if fileExists(GetCurrentDir + '\HandbrakeCLI.exe') = False then
  begin
    ShowMessage('HandbrakeCLI.exe not found on thesame location as Cyko.exe');
    exit;
  end;

  if (txtVideoValue.Text <> '') and (txtAudioValue.Text <> '') and
    (txtResolution.Text <> '') then
  begin
    tmrScan.Enabled := True;
    btnEncode.Enabled := False;
    btnEnqueue.Enabled := False;
    btnAdd.Enabled := False;
    mnuClearSelected.Enabled := False;
    mnuClear.Enabled := False;

    frmMain.i := 0;
    frmMain.ii := 0;
  end;

end;

procedure TfrmMain.btnOutputClick(Sender: TObject);
begin
  if SelectDirectoryDialog1.Execute then
  begin
    txtOutput.Text := SelectDirectoryDialog1.FileName;
  end;
end;

procedure TfrmMain.cboEncoderChange(Sender: TObject);
begin
  if cboEncoder.ItemIndex = 0 then //x264 encoder
  begin
     cboPresets.Items.Clear;
     cboPresets.Items.Add('Ultra Fast');
     cboPresets.Items.Add('Super Fast');
     cboPresets.Items.Add('Very Fast');
     cboPresets.Items.Add('Faster');
     cboPresets.Items.Add('Fast');
     cboPresets.Items.Add('Medium');
     cboPresets.Items.Add('Slow');
     cboPresets.Items.Add('Slower');
     cboPresets.Items.Add('Very Slow');
     cboPresets.Items.Add('Placebo');
     cboPresets.ItemIndex := 6;

     cboTunes.Items.Clear;
     cboTunes.Items.Add('Film');
     cboTunes.Items.Add('Animation');
     cboTunes.Items.Add('Grain');
     cboTunes.Items.Add('Still Image');
     cboTunes.Items.Add('PSNR');
     cboTunes.Items.Add('SSIM');
     cboTunes.Items.Add('Fast Decode');
     cboTunes.Items.Add('Zero Latency');
     cboTunes.ItemIndex := 1;

     cboProfiles.Items.Clear;
     cboProfiles.Items.Add('Auto');
     cboProfiles.Items.Add('High');
     cboProfiles.ItemIndex := 0;
  end
  else if cboEncoder.ItemIndex = 1 then //x265 encoder
  begin
     cboPresets.Items.Clear;
     cboPresets.Items.Add('Ultra Fast');
     cboPresets.Items.Add('Super Fast');
     cboPresets.Items.Add('Very Fast');
     cboPresets.Items.Add('Faster');
     cboPresets.Items.Add('Fast');
     cboPresets.Items.Add('Medium');
     cboPresets.Items.Add('Slow');
     cboPresets.Items.Add('Slower');
     cboPresets.Items.Add('Very Slow');
     cboPresets.Items.Add('Placebo');
     cboPresets.ItemIndex := 5;

     cboTunes.Items.Clear;
     cboTunes.Items.Add('PSNR');
     cboTunes.Items.Add('SSIM');
     cboTunes.Items.Add('Grain');
     cboTunes.Items.Add('Zero Latency');
     cboTunes.Items.Add('Fast Decode');
     cboTunes.Items.Add('Animation');
     cboTunes.ItemIndex := 5;

     cboProfiles.Items.Clear;
     cboProfiles.Items.Add('Auto');
     cboProfiles.Items.Add('Main');
     cboProfiles.Items.Add('Main Still Picture');
     cboProfiles.ItemIndex := 0;
  end;
end;

procedure TfrmMain.btnEncodeClick(Sender: TObject);
begin
  if lstOut.Count = 0 then
    exit;
  if fileExists(GetCurrentDir + '\HandbrakeCLI.exe') = False then
  begin
    ShowMessage('HandbrakeCLI.exe not found on thesame location as Cyko.exe');
    exit;
  end;

  chkShowConsole.Enabled := False;
  chkShutdown.Enabled := False;
  mnu2Clear.Enabled := False;
  mnu2ClearSelected.Enabled := False;
  btnEnqueue.Enabled := False;
  i := 0;
  encoded := False;
  tmrEncode.Enabled := True;
  btnEncode.Enabled := False;
end;

procedure TfrmMain.btnAddClick(Sender: TObject);
var
  x: integer;
begin
  OpenDialog1.Filter :=
    'All Files (make sure you select videos only)|*.*|Matroska (.mkv)|*.mkv|MPEG-4 Part 14 (.mp4)|*.mp4|MPEG-4 Part 14 (.m4v)|*.m4v|Audio Video Interleave (.avi)|*.avi|OGM (.ogm)|*.ogm';
  if OpenDialog1.Execute then
  begin
    for x := 0 to OpenDialog1.Files.Count - 1 do
      lstAdd.items.Add(OpenDialog1.Files.Strings[x]);
  end;
end;

procedure TfrmMain.btnAbortClick(Sender: TObject);
begin

  if fileExists(GetCurrentDir + '\HandbrakeCLI.exe') = False then
  begin
    ShowMessage('HandbrakeCLI.exe not found on thesame location as Cyko.exe');
    exit;
  end;

  if (lstOut.Count = 0) or (Hbk.Running = False) then
    exit;
  FreeConsole();
  Hbk.Terminate(1);
  tmrEncode.Enabled := False;
  ShowMessage('Encoding Aborted');
  encoded := True;
  btnEncode.Enabled := True;
  chkShowConsole.Enabled := True;
  lstOut.Clear;
  prgEncode.Position := prgEncode.Min;
  mnu2Clear.Enabled := True;
  mnu2ClearSelected.Enabled := True;
  btnEnqueue.Enabled := True;
end;

procedure TfrmMain.cboModeChange(Sender: TObject);
begin
  txtVideoValue.Text := '';
  txtVideoValue.SetFocus;
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if (Hbk.Running = True) or (tmrEncode.Enabled = True) or (tmrScan.Enabled = True) then
  begin
    CanClose := False;
    ShowMessage('You can not close the program while processing');
  end;

end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Hbk := TProcess.Create(nil);
  HbkStr := TStringList.Create;
  txtOutput.Text := GetCurrentDir;
  (* if fileExists(GetCurrentDir + '\HandbrakeCLI.exe') = false then
  begin
       ShowMessage('HandbrakeCLI.exe not found on thesame location as Cyko.exe' + sLineBreak + 'Program will Terminate now');
       Hbk.Free;
       HbkStr.Free;
       Application.Terminate;
  end; *)

end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  Hbk.Terminate(1);
  Hbk.Free;
  HbkStr.Free;
end;

procedure TfrmMain.FormDropFiles(Sender: TObject; const FileNames: array of string);
var
  x: integer;
begin
  if pgcMain.ActivePage <> tbsInput then
    exit;

  for x := 0 to High(FileNames) do
    lstAdd.Items.Add(FileNames[x]);
end;

procedure TfrmMain.lstOutClick(Sender: TObject);
begin
  txtout.Text := lstout.GetSelectedText;
  txtout.SelectAll;
  txtout.CopyToClipboard;
end;

procedure TfrmMain.mnu2ClearClick(Sender: TObject);
begin
  lstOut.Clear;
end;

procedure TfrmMain.mnu2ClearSelectedClick(Sender: TObject);
begin
  lstOut.Items.Delete(lstOut.ItemIndex);
end;

procedure TfrmMain.mnu2FullCmdClick(Sender: TObject);
begin
  if lstOut.getselectedtext <> '' then
    ShowMessage(lstOut.GetSelectedText);
end;

initialization
  {$I umain.lrs}

end.

