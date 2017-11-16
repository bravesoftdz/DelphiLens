unit DelphiLensUI.DLLExports;

interface

uses
  DelphiLensUI.Error;

procedure DLUIInitialize;
procedure DLUIFinalize;

/// After DLUIOpenProject caller should next call DLUISetProjectConfig followed by DLUIRescanProject.

function  DLUIOpenProject(const projectName: PChar; var projectID: integer): integer; stdcall;
function  DLUISetProjectConfig(projectID: integer; platformName,
            conditionalDefines, searchPath: PChar): integer; stdcall;
function  DLUIRescanProject(projectID: integer): integer; stdcall;

function  DLUIProjectModified(projectID: integer): integer; stdcall;
function  DLUIFileModified(projectID: integer; fileName: PChar): integer; stdcall;

function  DLUICloseProject(projectID: integer): integer; stdcall;

function  DLUIGetLastError(projectID: integer; var errorMsg: PChar): integer; stdcall;

function  DLUIActivate(projectID: integer; fileName: PChar; line, column: integer;
  var navigateToFile: PChar; var navigateToLine, navigateToColumn: integer): integer; stdcall;

implementation

uses
  Winapi.Windows,
  System.SysUtils, System.Generics.Collections,
  GpConsole,
  OtlSync, OtlCommon,
  DelphiLensUI.Worker;

type
  TErrorInfo = TPair<integer,string>;

var
  GDLEngineWorkers: TObjectDictionary<integer, TDelphiLensUIProject>;
  GDLEngineErrors : TDictionary<integer, TErrorInfo>;
  GDLEngineID     : TOmniAlignedInt32;
  GDLWorkerLock   : TOmniCS;
  GDLErrorLock    : TOmniCS;

function SetError(projectID: integer; error: integer; const errorMsg: string): integer; overload;
begin
  GDLErrorLock.Acquire;
  try
    GDLEngineErrors.AddOrSetValue(projectID, TErrorInfo.Create(error, errorMsg));
  finally GDLErrorLock.Release; end;
  Result := error;
end; { SetError }

function SetError(projectID: integer; error: integer; const errorMsg: string;
  const params: array of const): integer; overload;
begin
  Result := SetError(projectID, error, Format(errorMsg, params));
end; { SetError }

function ClearError(projectID: integer): integer; inline;
begin
  Result := SetError(projectiD, NO_ERROR, '');
end; { ClearError }

function GetProject(projectID: integer; var project: TDelphiLensUIProject): boolean;
begin
  GDLWorkerLock.Acquire;
  try
    Result := GDLEngineWorkers.TryGetValue(projectID, project);
  finally GDLWorkerLock.Release; end;
end; { GetProject }

function DLUIGetLastError(projectID: integer; var errorMsg: PChar): integer; stdcall;
var
  errorInfo: TErrorInfo;
  chkpt: string;
begin
  Console.Writeln(['DLUGetLastError ', projectID]);
  Console.Writeln(['>', string(errorMsg), '<']);
  chkpt := '#1';
  try
    GDLErrorLock.Acquire;
    try
      chkpt := chkpt + ' #2';
      if not GDLEngineErrors.TryGetValue(projectID, errorInfo) then
        Result := NO_ERROR
      else begin
      chkpt := chkpt + ' #3';
        errorMsg := PChar(errorInfo.Value);
        Result := errorInfo.Key;
      chkpt := chkpt + ' #4';
      end;
    finally GDLErrorLock.Release; end;
  except
    on E: Exception do begin
      // Throwing memory away, but this should not happen anyway
      errorMsg := StrNew(PChar('Exception in DLUIGetLastError: ' + E.Message + ' ' + chkpt));
      Result := ERR_INTERNAL_ERROR;
    end;
  end;
end; { DLUIGetLastError }

function DLUIOpenProject(const projectName: PChar; var projectID: integer): integer;
var
  project: TDelphiLensUIProject;
begin
  Result := ClearError(projectID);
  try
    projectID := GDLEngineID.Increment;
    project := TDelphiLensUIProject.Create(projectName);
    GDLWorkerLock.Acquire;
    try
      GDLEngineWorkers.Add(projectID, project);
    finally GDLWorkerLock.Release; end;
  except
    on E: Exception do
      Result := SetError(projectID, ERR_EXCEPTION, E.Message);
  end;
end; { DLUIOpenProject }

function DLUICloseProject(projectID: integer): integer;
var
  project: TDelphiLensUIProject;
begin
  Result := ClearError(projectID);
  try
    if not GetProject(projectID, project) then
      Result := SetError(projectID, ERR_PROJECT_NOT_FOUND, 'Project %d is not open', [projectID])
    else begin
      GDLWorkerLock.Acquire;
      try
        GDLEngineWorkers.Remove(projectID);
      finally GDLWorkerLock.Release; end;
    end;
  except
    on E: Exception do
      Result := SetError(projectID, ERR_EXCEPTION, E.Message);
  end;
end; { DLUICloseProject }

function DLUIProjectModified(projectID: integer): integer;
var
  project: TDelphiLensUIProject;
begin
  Result := ClearError(projectID);
  try
    if not GetProject(projectID, project) then
      Result := SetError(projectID, ERR_PROJECT_NOT_FOUND, 'Project %d is not open', [projectID])
    else
      project.ProjectModified;
  except
    on E: Exception do
      Result := SetError(projectID, ERR_EXCEPTION, E.Message);
  end;
end; { DLUIProjectModified }

function DLUIFileModified(projectID: integer; fileName: PChar): integer;
var
  project: TDelphiLensUIProject;
begin
  Result := ClearError(projectID);
  try
    if not GetProject(projectID, project) then
      Result := SetError(projectID, ERR_PROJECT_NOT_FOUND, 'Project %d is not open', [projectID])
    else
      project.FileModified(fileName);
  except
    on E: Exception do
      Result := SetError(projectID, ERR_EXCEPTION, E.Message);
  end;
end; { DLUIFileModified }

function DLUIRescanProject(projectID: integer): integer;
var
  project: TDelphiLensUIProject;
begin
  Result := ClearError(projectID);
  try
    if not GetProject(projectID, project) then
      Result := SetError(projectID, ERR_PROJECT_NOT_FOUND, 'Project %d is not open', [projectID])
    else
      project.Rescan;
  except
    on E: Exception do
      Result := SetError(projectID, ERR_EXCEPTION, E.Message);
  end;
end; { DLUIRescanPRoject }

function DLUISetProjectConfig(projectID: integer; platformName, conditionalDefines,
  searchPath: PChar): integer;
var
  project: TDelphiLensUIProject;
begin
  Result := ClearError(projectID);
  try
    if not GetProject(projectID, project) then
      Result := SetError(projectID, ERR_PROJECT_NOT_FOUND, 'Project %d is not open', [projectID])
    else
      project.SetConfig(TDLUIProjectConfig.Create(platformName, conditionalDefines, searchPath));
  except
    on E: Exception do
      Result := SetError(projectID, ERR_EXCEPTION, E.Message);
  end;
end; { DLUISetProjectConfig }

function DLUIActivate(projectID: integer; fileName: PChar; line, column: integer;
  var navigateToFile: PChar; var navigateToLine, navigateToColumn: integer): integer;
var
  chkpt: string;
  project : TDelphiLensUIProject;
  navigate: boolean;
begin
chkpt := '#1';
  Result := ClearError(projectID);
  try
chkpt := chkpt + ' #2';
    if not GetProject(projectID, project) then begin
chkpt := chkpt + ' #3';
      Result := SetError(projectID, ERR_PROJECT_NOT_FOUND, 'Project %d is not open', [projectID]);
chkpt := chkpt + ' #4';
    end
    else begin
chkpt := chkpt + ' #5';
      project.Activate(fileName, line, column, navigate);
chkpt := chkpt + ' #6';
      if not navigate then
        navigateToFile := nil
      else begin
chkpt := chkpt + ' #7';
        navigateToFile := project.GetNavigationInfo.FileName;
        navigateToLine := project.GetNavigationInfo.Line;
        navigateToColumn := project.GetNavigationInfo.Column;
chkpt := chkpt + ' #8s';
      end;
    end;
  except
    on E: Exception do
      Result := SetError(projectID, ERR_EXCEPTION, E.Message + ' ' + chkpt);
  end;
end; { DLUIActivate }

procedure DLUIInitialize;
begin
  GDLEngineID.Value := 0;
  GDLEngineWorkers := TObjectDictionary<integer, TDelphiLensUIProject>.Create([doOwnsValues]);
  GDLEngineErrors := TDictionary<integer, TErrorInfo>.Create;
  GDLWorkerLock.Initialize;
  GDLErrorLock.Initialize;
end; { DLUIInitialize }

procedure DLUIFinalize;
begin
  FreeAndNil(GDLEngineWorkers);
  FreeAndNil(GDLEngineErrors);
end; { DLUIFinalize }

end.
