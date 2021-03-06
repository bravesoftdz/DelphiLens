unit ProjectNotifierInterface;

interface

uses
  ToolsApi,
  System.SysUtils,
  Vcl.ExtCtrls;

type
  TProjectNotifier = class(TModuleNotifierObject, IOTAModuleNotifier,
                                                  IOTAModuleNotifier80,
                                                  IOTAModuleNotifier90,
                                                  IOTAProjectNotifier)
  strict private const
    CPathCheckInterval_sec = 5;
  var
    FProject: IOTAProject;
    FSearchPath: string;
    FCleanupProc: TProc;
    FConditionals: string;
    FPlatform: string;
    FLibPath: string;
    FTimer: TTimer;
  strict protected
    procedure CheckPaths(Sender: TObject);
  public
    constructor Create(const project: IOTAProject; cleanupProc: TProc);
    destructor  Destroy; override;
    procedure Destroyed;

    { IOTAModuleNotifier }

    { User has renamed the module }
    procedure ModuleRenamed(const NewName: string); overload;

    { IOTAModuleNotifier90 }

    procedure BeforeRename(const OldFileName, NewFileName: string);
    procedure AfterRename(const OldFileName, NewFileName: string);

    { IOTAProjectNotifier }

    { This notifier will be called when a file/module is added to the project }
    procedure ModuleAdded(const AFileName: string);

    { This notifier will be called when a file/module is removed from the project }
    procedure ModuleRemoved(const AFileName: string);

    { This notifier will be called when a file/module is renamed in the project }
    procedure ModuleRenamed(const AOldFileName, ANewFileName: string); overload;
  end;

implementation

uses
  Vcl.Forms,
  UtilityFunctions,
  DelphiLens.OTAUtils, DelphiLensProxy;

{ TProjectNotifier }

constructor TProjectNotifier.Create(const project: IOTAProject; cleanupProc: TProc);
begin
  inherited Create;
  FCleanupProc := cleanupProc;
  FProject := project;
  CheckPaths(nil);
  FTimer := TTimer.Create(nil);
  FTimer.OnTimer := CheckPaths;
  FTimer.Interval := CPathCheckInterval_sec * 1000;
  FTimer.Enabled := true;
end;

destructor TProjectNotifier.Destroy;
begin
  try
    if assigned(FTimer) then
      Destroyed;
  except
    on E: Exception do
      Log(lcError, 'TProjectNotifier.Destroy', E);
  end;
  inherited;
end;

procedure TProjectNotifier.AfterRename(const OldFileName, NewFileName: string);
begin
//
end;

procedure TProjectNotifier.BeforeRename(const OldFileName, NewFileName: string);
begin
//
end;

procedure TProjectNotifier.CheckPaths(Sender: TObject);
var
  searchPath: string;
  sPlatform: string;
  libPath: string;
  condDefs: string;
begin
  try
    searchPath := GetSearchPath(FProject, True);
    sPlatform := GetActivePlatform(FProject);
    libPath := GetLibraryPath(sPlatform, True);
    condDefs := GetConditionalDefines(FProject);
    if not (SameText(searchPath, FSearchPath)
            and SameText(sPlatform, FPlatform)
            and SameText(condDefs, FConditionals)
            and SameText(libPath, FLibPath)) then
    begin
      FSearchPath := searchPath;
      FPlatform := sPlatform;
      FConditionals := condDefs;
      FLibPath := libPath;
      if assigned(DLProxy) then
        DLProxy.SetProjectConfig(FPlatform, FConditionals, FSearchPath, FLibPath);
    end;
  except
    on E: Exception do
      Log(lcError, 'TProjectNotifier.CheckPaths', E);
  end;
end;

procedure TProjectNotifier.Destroyed;
begin
  try
    if assigned(FCleanupProc) then begin
      FCleanupProc();
      FCleanupProc := nil;
    end;

    FreeAndNil(FTimer);
  except
    on E: Exception do
      Log(lcError, 'TProjectNotifier.Destroyed', E);
  end;
end;

procedure TProjectNotifier.ModuleAdded(const AFileName: string);
begin
  try
    if assigned(DLProxy) then
      DLProxy.ProjectModified;
  except
    on E: Exception do
      Log(lcError, 'TProjectNotifier.ModuleAdded', E);
  end;
end;

procedure TProjectNotifier.ModuleRemoved(const AFileName: string);
begin
  try
    if assigned(DLProxy) then
      DLProxy.ProjectModified;
  except
    on E: Exception do
      Log(lcError, 'TProjectNotifier.ModuleRemoved', E);
  end;
end;

procedure TProjectNotifier.ModuleRenamed(const NewName: string);
begin
  try
    if assigned(DLProxy) then
      DLProxy.ProjectModified;
  except
    on E: Exception do
      Log(lcError, 'TProjectNotifier.ModuleRenamed', E);
  end;
end;

procedure TProjectNotifier.ModuleRenamed(const AOldFileName,
  ANewFileName: string);
begin
  try
    if assigned(DLProxy) then
      DLProxy.ProjectModified;
  except
    on E: Exception do
      Log(lcError, 'TProjectNotifier.ModuleRenamed', E);
  end;
end;

end.
