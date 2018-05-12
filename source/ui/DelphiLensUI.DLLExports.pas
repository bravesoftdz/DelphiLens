unit DelphiLensUI.DLLExports;

interface

uses
  DelphiLensUI.Error;

type
  TDLLogger = procedure (projectID: integer; const msg: PChar); stdcall;

procedure DLUIInitialize;
procedure DLUIFinalize;

procedure DLUISetLogHook(const hook: TDLLogger); stdcall;

/// After DLUIOpenProject caller should next call DLUISetProjectConfig followed by DLUIRescanProject.

function  DLUIOpenProject(const projectName: PChar; var projectID: integer): integer; stdcall;
function  DLUISetProjectConfig(projectID: integer; platformName,
            conditionalDefines, searchPath: PChar): integer; stdcall;
function  DLUIRescanProject(projectID: integer): integer; stdcall;

function  DLUIProjectModified(projectID: integer): integer; stdcall;
function  DLUIFileModified(projectID: integer; fileName: PChar): integer; stdcall;

function  DLUICloseProject(projectID: integer): integer; stdcall;

function  DLUIGetLastError(projectID: integer; var errorMsg: PChar): integer; stdcall;

function  DLUIActivate(monitorNum, projectID: integer; fileName: PChar;
  line, column: integer; tabNames: PChar; var navigateToFile: PChar;
  var navigateToLine, navigateToColumn: integer): integer; stdcall;

implementation

uses
  Vcl.Dialogs,
  Winapi.Windows,
  System.SysUtils, System.Generics.Collections,
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

function DLUIGetLastError(projectID: integer; var errorMsg: PChar): integer;
var
  errorInfo: TErrorInfo;
begin
  try
    GDLErrorLock.Acquire;
    try
      if not GDLEngineErrors.TryGetValue(projectID, errorInfo) then
        Result := NO_ERROR
      else begin
        errorMsg := PChar(errorInfo.Value);
        Result := errorInfo.Key;
      end;
    finally GDLErrorLock.Release; end;
  except
    on E: Exception do begin
      // Throwing memory away, but this should not happen anyway
      errorMsg := StrNew(PChar('Exception in DLUIGetLastError: ' + E.Message + ' '));
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
    project := TDelphiLensUIProject.Create(projectName, projectID);
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

function DLUIActivate(monitorNum, projectID: integer; fileName: PChar; line, column: integer;
  tabNames: PChar; var navigateToFile: PChar; var navigateToLine,
  navigateToColumn: integer): integer;
var
  project : TDelphiLensUIProject;
  navigate: boolean;
begin
  Result := ClearError(projectID);
  try
    if not GetProject(projectID, project) then begin
      Result := SetError(projectID, ERR_PROJECT_NOT_FOUND, 'Project %d is not open', [projectID]);
    end
    else begin
      project.Activate(monitorNum, fileName, line, column, tabNames, navigate);
      if not navigate then
        navigateToFile := nil
      else begin
        navigateToFile := project.GetNavigationInfo.FileName;
        navigateToLine := project.GetNavigationInfo.Line;
        navigateToColumn := project.GetNavigationInfo.Column;
      end;
    end;
  except
    on E: Exception do
      Result := SetError(projectID, ERR_EXCEPTION, E.Message );
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

procedure DLUISetLogHook(const hook:  TDLLogger);
begin
  GLogHook := hook;
end; { DLUISetLogHook }

end.
