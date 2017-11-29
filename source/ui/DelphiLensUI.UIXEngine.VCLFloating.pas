unit DelphiLensUI.UIXEngine.VCLFloating;

interface

uses
  DelphiLensUI.UIXEngine.Intf;

//TODO: Don't add to history if current location = new location
//TODO: Lists should change width according to the item
//TODO: Nicer buttons with icons ...

function CreateUIXEngine: IDLUIXEngine;

implementation

uses
  Winapi.Windows,
  System.Types, System.RTTI, System.SysUtils, System.StrUtils, System.Classes, System.Math,
  Vcl.StdCtrls, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Vcl.WinXCtrls,
  Spring, Spring.Collections, Spring.Reflection,
  GpStuff, GpEasing,
  DelphiLens.UnitInfo,
  DelphiLensUI.UIXAnalyzer.Intf, DelphiLensUI.UIXAnalyzer.Attributes,
  DelphiLensUI.UIXEngine.Actions;

type
  TVCLFloatingForm = class(TForm)
  strict private
    FOnBackSpace: TProc;
  protected
    procedure HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  public
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
    procedure UpdateMask;
    property OnBackSpace: TProc read FOnBackSpace write FOnBackSpace;
  end; { TVCLFloatingForm }

  IDLUIXVCLFloatingFrame = interface ['{43127F61-07EE-466F-BAB2-E39B811AFB2F}']
    function GetBounds_Screen(const action: IDLUIXAction): TRect;
  end; { IDLUIXVCLFloatingFrame }

  TDLUIXVCLFloatingFrame = class(TManagedInterfacedObject, IDLUIXFrame,
                                                           IDLUIXVCLFloatingFrame)
  strict private const
    CAlphaBlendActive         = 255;
    CAlphaBlendInactive       =  64;
    CButtonHeight             =  81;
    CButtonSpacing            =  15;
    CButtonWidth              = 201;
    CColumnSpacing            =  15;
    CFilteredListWidth        = 201;
    CFilteredListHeight       = 313;
    CFrameSpacing             =  21;
    CInactiveFrameOverlap     =  21;
    CListButtonHeight         =  25;
    CListButtonSpacing        =   3;
    CListButtonWidth          = 254;
    CSearchBoxHeight          =  21;
    CSearchToListBoxSeparator =   1;
  var
    [Managed(false)] FActionMap: IBidiDictionary<TObject, IDLUIXAction>;
    [Managed(false)] FForm     : TVCLFloatingForm;
  var
    FColumnTop     : integer;
    FColumnLeft    : integer;
    FEasing        : IEasing;
    FEasingPos     : IEasing;
    FForceNewColumn: boolean;
    FHistoryButton : TButton;
    FOnAction      : TDLUIXFrameAction;
    FOnShowProc    : IQueue<TProc>;
    FOriginalLeft  : Nullable<integer>;
    FParent        : IDLUIXFrame;
    FTargetLeft    : Nullable<integer>;
  strict protected
    procedure ApplyOptions(control: TControl; options: TDLUIXFrameActionOptions);
    function  BuildButton(const action: IDLUIXAction; options: TDLUIXFrameActionOptions): TRect;
    function  BuildFilteredList(const filteredList: IDLUIXFilteredListAction;
      options: TDLUIXFrameActionOptions): TRect;
    function  BuildList(const listNavigation: IDLUIXListNavigationAction;
      options: TDLUIXFrameActionOptions): TRect;
    procedure EaseAlphaBlend(start, stop: integer);
    procedure EaseLeft(start, stop: integer);
    procedure EnableActions(actions: TDLUIXActions; enabled: boolean);
    procedure FilterListBox(Sender: TObject);
    procedure ForwardAction(Sender: TObject);
    function  GetOnAction: TDLUIXFrameAction;
    function  GetParent: IDLUIXFrame;
    function  GetParentRect(const action: IDLUIXAction = nil): TRect;
    procedure HandleListBoxClick(Sender: TObject);
    procedure HandleListBoxKeyDown(Sender: TObject; var key: word;
      shift: TShiftState);
    procedure HandleSearchBoxKeyDown(Sender: TObject; var key: word;
      shift: TShiftState);
    procedure HandleSearchBoxTimer(Sender: TObject);
    function  IsHistoryAnalyzer(const analyzer: IDLUIXAnalyzer): boolean;
    procedure NewColumn;
    function  NumItems(listBox: TListBox): integer;
    procedure PrepareNewColumn;
    procedure QueueOnShow(proc: TProc);
    procedure SetLocationAndOpen(listBox: TListBox; doOpen: boolean);
    procedure SetOnAction(const value: TDLUIXFrameAction);
    procedure UpdateClientSize(const rect: TRect);
  public
    constructor Create(const parentFrame: IDLUIXFrame);
    // IDLUIXVCLFloatingFrame
    function  GetBounds_Screen(const action: IDLUIXAction): TRect;
    // IDLUIXFrame
    procedure Close;
    procedure CreateAction(const action: IDLUIXAction;
      options: TDLUIXFrameActionOptions = []);
    function  IsEmpty: boolean;
    procedure MarkActive(isActive: boolean);
    procedure Show(const parentAction: IDLUIXAction);
    property OnAction: TDLUIXFrameAction read GetOnAction write SetOnAction;
    property Parent: IDLUIXFrame read GetParent;
  end; { TDLUIXVCLFloatingFrame }

  TDLUIXVCLFloatingEngine = class(TInterfacedObject, IDLUIXEngine)
  public
    constructor Create;
    function  CreateFrame(const parentFrame: IDLUIXFrame): IDLUIXFrame;
    procedure DestroyFrame(var frame: IDLUIXFrame);
  end; { TDLUIXVCLFloatingEngine }

{ exports }

function CreateUIXEngine: IDLUIXEngine;
begin
  Result := TDLUIXVCLFloatingEngine.Create;
end; { CreateUIXEngine }

{ TVCLFloatingForm }

constructor TVCLFloatingForm.CreateNew(AOwner: TComponent; Dummy: Integer = 0);
begin
  inherited;
  OnKeyDown := HandleKeyDown;
end;

procedure TVCLFloatingForm.HandleKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    Close
  else if Key = VK_BACK then
    if assigned(OnBackSpace) then
      OnBackSpace();
end; { TVCLFloatingForm.HandleKeyDown }

procedure TVCLFloatingForm.UpdateMask;
var
  pnt: TPoint;
  rgn, rgnCtrl: HRGN;
  i: Integer;
begin
  pnt := ClientToScreen(Point(0, 0));
  rgn := 0;
  for i := 0 to ControlCount - 1 do begin
    if not (Controls[i] is TWinControl) then
      continue;
    with Controls[i] do
      rgnCtrl := CreateRectRgn(Left, Top, Left+Width, Top+Height);
    if rgn = 0 then
      rgn := rgnCtrl
    else begin
      CombineRgn(rgn, rgn, rgnCtrl, RGN_OR);
      DeleteObject(rgnCtrl);
    end;
  end;
  if rgn <> 0 then begin
    SetWindowRgn(Handle, rgn, true);
    DeleteObject(rgn);
  end;
end; { TVCLFloatingForm.UpdateMask }

{ TDLUIXVCLFloatingFrame }

constructor TDLUIXVCLFloatingFrame.Create(const parentFrame: IDLUIXFrame);
begin
  inherited Create;
  FActionMap := TCollections.CreateBidiDictionary<TObject, IDLUIXAction>;
  FOnShowProc := TCollections.CreateQueue<TProc>;
  FParent := parentFrame;
  FForm := TVCLFloatingForm.CreateNew(Application);
  FForm.BorderStyle := bsNone;
  FForm.ClientWidth := 0;
  FForm.ClientHeight := 0;
  FForm.AlphaBlend := true;
  FForm.KeyPreview := true;
  FForm.AlphaBlendValue := CAlphaBlendActive;
  FForm.OnBackSpace :=
    procedure
    begin
      if assigned(FHistoryButton) then
        FHistoryButton.OnClick(FHistoryButton);
    end;
end; { TDLUIXVCLFloatingFrame.Create }

procedure TDLUIXVCLFloatingFrame.ApplyOptions(control: TControl;
  options: TDLUIXFrameActionOptions);
begin
  control.Enabled := not (faoDisabled in options);
  if (control is TButton) and (faoDefault in options) then
    TButton(control).Default := true;
end; { TDLUIXVCLFloatingFrame.ApplyOptions }

function TDLUIXVCLFloatingFrame.BuildButton(const action: IDLUIXAction;
  options: TDLUIXFrameActionOptions): TRect;
var
  button      : TButton;
  openAnalyzer: IDLUIXOpenAnalyzerAction;
begin
  button := TButton.Create(FForm);
  button.Parent := FForm;
  button.Width := CButtonWidth;
  button.Height := CButtonHeight;
  button.Left := FColumnLeft;
  button.Top := FColumnTop + IFF(FColumnTop = 0, 0, CButtonSpacing);

  if Supports(action, IDLUIXOpenAnalyzerAction, openAnalyzer) then begin
    if not IsHistoryAnalyzer(openAnalyzer.Analyzer) then
      button.Caption := action.Name + ' >'
    else begin
      button.Caption := '< ' + action.Name;
      FHistoryButton := button;
    end;
  end
  else
    button.Caption := action.Name;
  button.OnClick := ForwardAction;

  ApplyOptions(button, options);
  FActionMap.Add(button, action);

  Result := button.BoundsRect;
end; { TDLUIXVCLFloatingFrame.BuildButton }

function TDLUIXVCLFloatingFrame.BuildFilteredList(
  const filteredList: IDLUIXFilteredListAction;
  options: TDLUIXFrameActionOptions): TRect;
var
  listBox    : TListBox;
  searchBox  : TSearchBox;
  searchTimer: TTimer;
begin
  searchBox := TSearchBox.Create(FForm);
  searchBox.Parent := FForm;
  searchBox.Width := CFilteredListWidth;
  searchBox.Height := CSearchBoxHeight;
  searchBox.Left := FColumnLeft;
  searchBox.Top := FColumnTop + 1;
  searchBox.OnKeyDown := HandleSearchBoxKeyDown;
  searchBox.OnInvokeSearch := FilterListBox;
  ApplyOptions(searchBox, options);

  listBox := TListBox.Create(FForm);
  listBox.Parent := FForm;
  listBox.Width := searchBox.Width;
  listBox.Height := CFilteredListHeight;
  listBox.Left := FColumnLeft;
  listBox.Top := searchBox.BoundsRect.Bottom + CSearchToListBoxSeparator;
  listBox.OnClick := HandleListBoxClick;
  listBox.OnKeyDown := HandleListBoxKeyDown;
  ApplyOptions(listBox, options);

  searchTimer := TTimer.Create(FForm);
  searchTimer.Enabled := false;
  searchTimer.Interval := 250;
  searchTimer.OnTimer := HandleSearchBoxTimer;

  searchBox.Tag := NativeInt(listBox);
  listBox.Tag := NativeInt(searchTimer);
  searchTimer.Tag := NativeInt(searchBox);

  FActionMap.Add(searchBox, filteredList);

  FilterListBox(searchBox);
  listBox.ItemIndex := listBox.Items.IndexOf(filteredList.Selected);

  Result.TopLeft := searchBox.BoundsRect.TopLeft;
  Result.BottomRight := listBox.BoundsRect.BottomRight;
  NewColumn;

  QueueOnShow(
    procedure
    begin
      SetLocationAndOpen(listBox, false);
      EnableActions(filteredList.ManagedActions, listBox.ItemIndex >= 0);
    end);
end; { TDLUIXVCLFloatingFrame.BuildFilteredList }

function TDLUIXVCLFloatingFrame.BuildList(
  const listNavigation: IDLUIXListNavigationAction;
  options: TDLUIXFrameActionOptions): TRect;
var
  button    : TButton;
  hotkey    : string;
  navigation: IDLUIXNavigationAction;
  nextTop   : integer;
begin
  Result.TopLeft := Point(FColumnLeft, FColumnTop);
  nextTop := FColumnTop;
  button := nil;

  hotkey := '1';
  for navigation in listNavigation.Locations do begin
    button := TButton.Create(FForm);
    button.Parent := FForm;
    button.Width := CListButtonWidth;
    button.Height := CListButtonHeight;
    button.Left := FColumnLeft;
    button.Top := nextTop;
    button.Caption := IFF(hotkey = '', '  ', '&' + hotkey + ' ') + navigation.Name;
    button.OnClick := ForwardAction;
    ApplyOptions(button, options);

    FActionMap.Add(button, navigation);

    nextTop := button.Top + button.Height + CListButtonSpacing;
    if hotkey = '9' then
      hotkey := ''
    else if hotkey <> '' then
      hotkey := Chr(Ord(hotkey[1]) + 1);
  end; //for namedLocation

  if assigned(button) then
    Result.BottomRight := button.BoundsRect.BottomRight
  else
    Result := TRect.Empty;
end; { TDLUIXVCLFloatingFrame.BuildList }

procedure TDLUIXVCLFloatingFrame.Close;
begin
  FForm.Close;
end; { TDLUIXVCLFloatingFrame.Close }

procedure TDLUIXVCLFloatingFrame.CreateAction(const action: IDLUIXAction;
  options: TDLUIXFrameActionOptions);
var
  filterList : IDLUIXFilteredListAction;
  historyList: IDLUIXListNavigationAction;
begin
  PrepareNewColumn;
  if Supports(action, IDLUIXListNavigationAction, historyList) then
    UpdateClientSize(BuildList(historyList, options))
  else if Supports(action, IDLUIXFilteredListAction, filterList) then
    UpdateClientSize(BuildFilteredList(filterList, options))
  else
    UpdateClientSize(BuildButton(action, options));
end; { TDLUIXVCLFloatingFrame.CreateAction }

procedure TDLUIXVCLFloatingFrame.EaseAlphaBlend(start, stop: integer);
begin
  FEasing := Easing.InOutCubic(start, stop, 500, 10,
    procedure (value: integer)
    begin
      if not (csDestroying in FForm.ComponentState) then
        FForm.AlphaBlendValue := value;
    end);
end; { TDLUIXVCLFloatingFrame.EaseAlphaBlend }

procedure TDLUIXVCLFloatingFrame.EaseLeft(start, stop: integer);
begin
  FTargetLeft := stop;
  FEasingPos := Easing.InOutCubic(start, stop, 500, 10,
    procedure (value: integer)
    begin
      if not (csDestroying in FForm.ComponentState) then
        FForm.Left := value;
    end);
end; { TDLUIXVCLFloatingFrame.EaseLeft }

procedure TDLUIXVCLFloatingFrame.EnableActions(actions: TDLUIXActions;
  enabled: boolean);
var
  action : IDLUIXAction;
  control: TObject;
begin
  for action in actions do
    if FActionMap.TryGetKey(action, control) then
      (control as TControl).Enabled := enabled;
end; { TDLUIXVCLFloatingFrame.EnableActions }

procedure TDLUIXVCLFloatingFrame.FilterListBox(Sender: TObject);
var
  filteredList : IDLUIXFilteredListAction;
  listBox      : TListBox;
  matchesSearch: TPredicate<string>;
  searchBox    : TSearchBox;
  searchFilter : string;
  selected     : string;
begin
  filteredList := FActionMap.Value[Sender] as IDLUIXFilteredListAction;
  searchBox := Sender as TSearchBox;
  searchFilter := searchBox.Text;
  listBox := TObject(searchBox.Tag) as TListBox;

  listBox.Items.BeginUpdate;
  try
    if listBox.ItemIndex < 0 then
      selected := ''
    else
      selected := listBox.Items[listBox.ItemIndex];

    listBox.Items.Clear;

    if searchFilter = '' then
      listBox.Items.AddStrings(filteredList.List.ToArray)
    else begin
      matchesSearch :=
        function (const s: string): boolean
        begin
          Result := ContainsText(s, searchFilter);
        end;
      listBox.Items.AddStrings(filteredList.List.Where(matchesSearch).ToArray);
    end;

    if selected <> '' then
      listBox.ItemIndex := listBox.Items.IndexOf(selected);
    if (listBox.ItemIndex < 0) and (listBox.Items.Count > 0) then
      listBox.ItemIndex := 0;

    //TODO: UIX behaviour, not UI behaviour; only enable Used in/Used by actions if we have syntax info for selected unit
    EnableActions(filteredList.ManagedActions, listBox.ItemIndex >= 0);

    listBox.OnClick(listBox);
  finally listBox.Items.EndUpdate; end;
end; { TDLUIXVCLFloatingFrame.FilterListBox }

procedure TDLUIXVCLFloatingFrame.ForwardAction(Sender: TObject);
begin
  if assigned(OnAction) then
    OnAction(Self, FActionMap.Value[Sender]);
end; { TDLUIXVCLFloatingFrame.ForwardAction }

function TDLUIXVCLFloatingFrame.GetBounds_Screen(const action: IDLUIXAction): TRect;
var
  control: TObject;
begin
  if action = nil then
    Exit(FForm.BoundsRect);

  control := FActionMap.Key[action];
  if not (control is TControl) then
    Exit(TRect.Empty);

  Result := TControl(control).BoundsRect;
  Result.TopLeft := FForm.ClientToScreen(Result.TopLeft);
  Result.BottomRight := FForm.ClientToScreen(Result.BottomRight);

  if FTargetLeft.HasValue then
    Result.Offset(FTargetLeft.Value - Result.Left, 0);
end; { TDLUIXVCLFloatingFrame.GetBounds_Screen }

function TDLUIXVCLFloatingFrame.GetOnAction: TDLUIXFrameAction;
begin
  Result := FOnAction;
end; { TDLUIXVCLFloatingFrame.GetOnAction }

function TDLUIXVCLFloatingFrame.GetParent: IDLUIXFrame;
begin
  Result := FParent;
end; { TDLUIXVCLFloatingFrame.GetParent }

function TDLUIXVCLFloatingFrame.GetParentRect(const action: IDLUIXAction): TRect;
begin
  Result := (FParent as IDLUIXVCLFloatingFrame).GetBounds_Screen(action);
end; { TDLUIXVCLFloatingFrame.GetParentRect }

procedure TDLUIXVCLFloatingFrame.HandleListBoxClick(Sender: TObject);
var
  filteredList: IDLUIXFilteredListAction;
  listBox     : TListBox;
  searchBox   : TSearchBox;
begin
  listBox := (Sender as TListBox);
  searchBox := TObject((TObject(listBox.Tag) as TTimer).Tag) as TSearchBox;
  filteredList := (FActionMap.Value[searchBox] as IDLUIXFilteredListAction);
  EnableActions(filteredList.ManagedActions, listBox.ItemIndex >= 0);
  SetLocationAndOpen(Sender as TListBox, false);
end; { TDLUIXVCLFloatingFrame.HandleListBoxClick }

procedure TDLUIXVCLFloatingFrame.HandleListBoxKeyDown(Sender: TObject;
  var key: word; shift: TShiftState);
begin
  if key = VK_RETURN then begin
    SetLocationAndOpen(Sender as TListBox, true);
    key := 0;
  end;
end; { TDLUIXVCLFloatingFrame.HandleListBoxKeyDown }

procedure TDLUIXVCLFloatingFrame.HandleSearchBoxKeyDown(Sender: TObject;
  var key: word; shift: TShiftState);
var
  listBox: TListBox;
  timer  : TTimer;
begin
  if (key = VK_UP) or (key = VK_DOWN)
     or (key = VK_HOME) or (key = VK_END)
     or (key = VK_PRIOR) or (key = VK_NEXT) then
  begin
    listBox := (TObject((Sender as TSearchBox).Tag) as TListBox);
    if key = VK_UP then
      listBox.ItemIndex := Max(listBox.ItemIndex - 1, 0)
    else if key = VK_DOWN then
      listBox.ItemIndex := Min(listBox.ItemIndex + 1, listBox.Items.Count - 1)
    else if key = VK_HOME then
      listBox.ItemIndex := 0
    else if key = VK_END then
      listBox.ItemIndex := listBox.Items.Count - 1
    else if key = VK_PRIOR then
      listBox.ItemIndex := Max(listBox.ItemIndex - NumItems(listBox), 0)
    else if key = VK_NEXT then
      listBox.ItemIndex := Min(listBox.ItemIndex + NumItems(listBox), listBox.Items.Count - 1);
    listBox.OnClick(listBox);
    key := 0;
  end
  else if key = VK_RETURN then begin
    SetLocationAndOpen(TObject((Sender as TSearchBox).Tag) as TListBox, true);
    key := 0;
  end
  else begin
    timer := (TObject((TObject((Sender as TSearchBox).Tag) as TListBox).Tag) as TTimer);
    timer.Enabled := false;
    timer.Enabled := true;
  end;
end; { TDLUIXVCLFloatingFrame.HandleSearchBoxKeyDown }

procedure TDLUIXVCLFloatingFrame.HandleSearchBoxTimer(Sender: TObject);
begin
  (Sender as TTimer).Enabled := false;
  FilterListBox(TObject(TTimer(Sender).Tag) as TSearchBox);
end; { TDLUIXVCLFloatingFrame.HandleSearchBoxTimer }

function TDLUIXVCLFloatingFrame.IsEmpty: boolean;
begin
  Result := (FForm.ClientHeight = 0);
end; { TDLUIXVCLFloatingFrame.IsEmpty }

function TDLUIXVCLFloatingFrame.IsHistoryAnalyzer(const analyzer: IDLUIXAnalyzer):
  boolean;
begin
  Result := TType.GetType((analyzer as TObject).ClassType).HasCustomAttribute<TBackNavigationAttribute>;
end; { TDLUIXVCLFloatingFrame.IsHistoryAnalyzer }

procedure TDLUIXVCLFloatingFrame.MarkActive(isActive: boolean);
begin
  EaseAlphaBlend(FForm.AlphaBlendValue, IFF(isActive, CAlphaBlendActive, CAlphaBlendInactive));

  if assigned(FParent) then begin
    if not isActive then begin
      FOriginalLeft := FForm.Left;
      EaseLeft(FForm.Left, GetParentRect.Left + CInactiveFrameOverlap);
    end
    else if FOriginalLeft.HasValue then begin
      EaseLeft(FForm.Left, FOriginalLeft);
      FOriginalLeft := nil;
    end;
  end;
end; { TDLUIXVCLFloatingFrame.MarkActive }

procedure TDLUIXVCLFloatingFrame.NewColumn;
begin
  FForceNewColumn := true;
end; { TDLUIXVCLFloatingFrame.NewColumn }

function TDLUIXVCLFloatingFrame.NumItems(listBox: TListBox): integer;
begin
  Result := Trunc(listBox.ClientHeight /  listBox.ItemHeight);
end; { TDLUIXVCLFloatingFrame.NumItems }

procedure TDLUIXVCLFloatingFrame.PrepareNewColumn;
begin
  if not FForceNewColumn then
    Exit;

  FColumnLeft := FForm.ClientWidth + CColumnSpacing;
  FColumnTop := 0;
  FForceNewColumn := false;
end; { TDLUIXVCLFloatingFrame.PrepareNewColumn }

procedure TDLUIXVCLFloatingFrame.QueueOnShow(proc: TProc);
begin
  FOnShowProc.Enqueue(proc);
end; { TDLUIXVCLFloatingFrame.QueueOnShow }

procedure TDLUIXVCLFloatingFrame.SetLocationAndOpen(listBox: TListBox; doOpen: boolean);
var
  action           : IDLUIXAction;
  filterAction     : IDLUIXFilteredListAction;
  navigationAction : IDLUIXNavigationAction;
  searchBox        : TSearchBox;
  unitBrowserAction: IDLUIXOpenUnitBrowserAction;
  unitName         : string;
begin
  //TODO: ** This does not belong into UI implementation; it is a global UIX behaviour

  if listBox.ItemIndex < 0 then
    unitName := ''
  else
    unitName := listBox.Items[listBox.ItemIndex];

  searchBox := (TObject((TObject(listBox.Tag) as TTimer).Tag) as TSearchBox);
  filterAction := FActionMap.Value[searchBox] as IDLUIXFilteredListAction;

  for action in filterAction.ManagedActions do
    if Supports(action, IDLUIXOpenUnitBrowserAction, unitBrowserAction) then
      unitBrowserAction.InitialUnit := unitName;

  if assigned(filterAction.DefaultAction)
     and Supports(filterAction.DefaultAction, IDLUIXNavigationAction, navigationAction)
  then begin
    navigationAction.Location := TDLUIXLocation.Create('', unitName, TDLCoordinate.Invalid);

    if doOpen then
      OnAction(Self, navigationAction);
  end;
end; { TDLUIXVCLFloatingFrame.SetLocationAndOpen }

procedure TDLUIXVCLFloatingFrame.SetOnAction(const value: TDLUIXFrameAction);
begin
  FOnAction := value;
end; { TDLUIXVCLFloatingFrame.SetOnAction }

procedure TDLUIXVCLFloatingFrame.Show(const parentAction: IDLUIXAction);
var
  analyzerAction: IDLUIXOpenAnalyzerAction;
  isBack        : boolean;
  proc          : TProc;
  rect          : TRect;
begin
  if not assigned(FParent) then
    FForm.Position := poScreenCenter
  else begin
    FForm.Position := poDesigned;
    rect := (FParent as IDLUIXVCLFloatingFrame).GetBounds_Screen(parentAction);
    isBack := false;
    if Supports(parentAction, IDLUIXOpenAnalyzerAction, analyzerAction) then
      isBack := TType.GetType((analyzerAction.Analyzer as TObject).ClassType).HasCustomAttribute<TBackNavigationAttribute>;

    if isBack then
      FForm.Left := rect.Left - CFrameSpacing - FForm.Width
    else
      FForm.Left := rect.Left + CFrameSpacing;
    FForm.Top := rect.Top + (rect.Height - FForm.Height) div 2;
  end;
  for proc in FOnShowProc do
    proc();
  FForm.UpdateMask;
  FForm.ShowModal;
end; { TDLUIXVCLFloatingFrame.Show }

procedure TDLUIXVCLFloatingFrame.UpdateClientSize(const rect: TRect);
begin
  FForm.ClientWidth  := Max(FForm.ClientWidth,  rect.Right);
  FForm.ClientHeight := Max(FForm.ClientHeight, rect.Bottom);
  FColumnTop := Max(FColumnTop, rect.Bottom);
end; { TDLUIXVCLFloatingFrame.UpdateClientSize }

{ TDLUIXVCLFloatingEngine }

constructor TDLUIXVCLFloatingEngine.Create;
begin
  inherited;
  Application.Title := 'DelphiLens';
  Application.MainFormOnTaskBar := false;
end; { TDLUIXVCLFloatingEngine.Create }

function TDLUIXVCLFloatingEngine.CreateFrame(const parentFrame: IDLUIXFrame): IDLUIXFrame;
begin
  Result := TDLUIXVCLFloatingFrame.Create(parentFrame);
end; { TDLUIXVCLFloatingEngine.CreateFrame }

procedure TDLUIXVCLFloatingEngine.DestroyFrame(var frame: IDLUIXFrame);
begin
  frame := nil;
end; { TDLUIXVCLFloatingEngine.DestroyFrame }

end.
