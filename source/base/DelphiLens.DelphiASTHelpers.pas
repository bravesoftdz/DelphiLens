unit DelphiLens.DelphiASTHelpers;

interface

uses
  System.Generics.Collections,
  Spring,
  DelphiAST.Consts, DelphiAST.Classes, DelphiAST.ProjectIndexer;

type
  TSyntaxNodeTypes = set of TSyntaxNodeType;

  TSyntaxTreeEnumerator = class(TManagedObject)
  strict private
    FCanGoDeeper : boolean;
    FChildrenOnly: boolean;
    FCurrentNode : TSyntaxNode;
    FExitOnFirst : boolean;
    FNodeTypes   : TSyntaxNodeTypes;
    [Managed] FUnVisited: TStack<TSyntaxNode>;
  strict protected
    procedure PushChildrenOnStack(node: TSyntaxNode);
  public
    constructor Create(parentNode: TSyntaxNode; childTypes: TSyntaxNodeTypes; childrenOnly: boolean); overload;
    constructor Create(parentNode: TSyntaxNode; childrenOnly: boolean); overload;
    function  GetEnumerator: TSyntaxTreeEnumerator;
    function  GetCurrent: TSyntaxNode; inline;
    function  MoveNext: boolean;
    property Current: TSyntaxNode read GetCurrent;
  end; { TSyntaxTreeEnumeratorIntf }

  TSyntaxNodeHelper = class helper for TSyntaxNode
  strict private
  class var
    FNodeTypeNames: array [TSyntaxNodeType] of string;
  strict protected
    function  GetTypeName: string;
  public
    class constructor Create;
    function  All(childrenOnly: boolean = false): TSyntaxTreeEnumerator;
    function  FindAll(nodeType: TSyntaxNodeType; childrenOnly: boolean = true): TSyntaxTreeEnumerator; overload;
    function  FindAll(nodeTypes: TSyntaxNodeTypes; childrenOnly: boolean = true): TSyntaxTreeEnumerator; overload;
    function  FindFirst(nodeType: TSyntaxNodeType): TSyntaxNode; overload;
    function  FindFirst(nodeType: TSyntaxNodeType; var childNode: TSyntaxNode): boolean; overload; inline;
    function  FindParentWithName: TSyntaxNode; overload;
    function  FindLocation(line, column: integer): TSyntaxNode;
    property TypeName: string read GetTypeName;
  end; { TSyntaxNodeHelper }

  TParsedUnitsHelper = class helper for TProjectIndexer.TParsedUnits
  public
    function  Find(const unitName: string; var unitInfo: TProjectIndexer.TUnitInfo): boolean;
    function  FindOrDefault(const unitName: string): TProjectIndexer.TUnitInfo;
  end; { TParsedUnitsHelper }

implementation

uses
  System.Rtti,
  System.SysUtils;

{ TSyntaxTreeEnumerator }

constructor TSyntaxTreeEnumerator.Create(parentNode: TSyntaxNode;
  childTypes: TSyntaxNodeTypes; childrenOnly: boolean);
begin
  inherited Create;
  FNodeTypes := childTypes;
  FChildrenOnly := childrenOnly;
  FCanGoDeeper := true;
  FExitOnFirst := true;
  FUnvisited.Push(parentNode);
end; { TSyntaxTreeEnumerator.Create }

constructor TSyntaxTreeEnumerator.Create(parentNode: TSyntaxNode;
  childrenOnly: boolean);
var
  nodeTypes: TSyntaxNodeTypes;
begin
  Create(parentNode, [Low(TSyntaxNodeType)..High(TSyntaxNodeType)], childrenOnly);
  FExitOnFirst := false;
end; { TSyntaxTreeEnumerator.Create }

function TSyntaxTreeEnumerator.GetCurrent: TSyntaxNode;
begin
  Result := FCurrentNode;
end; { TSyntaxTreeEnumerator.GetCurrent }

function TSyntaxTreeEnumerator.GetEnumerator: TSyntaxTreeEnumerator;
begin
  Result := Self;
end; { TSyntaxTreeEnumerator.GetEnumerator }

function TSyntaxTreeEnumerator.MoveNext: boolean;
begin
  Result := false;
  while FUnvisited.Count > 0 do begin
    FCurrentNode := FUnvisited.Pop;
    if FCurrentNode.Typ in FNodeTypes then
      Result := true;
    if Result and FExitOnFirst then
      Exit;
    PushChildrenOnStack(FCurrentNode);
    if Result then
      Exit;
  end;
end; { TSyntaxTreeEnumerator.MoveNext }

procedure TSyntaxTreeEnumerator.PushChildrenOnStack(node: TSyntaxNode);
var
  iChild: integer;
begin
  if not FCanGoDeeper then
    Exit;
  if FChildrenOnly then
    FCanGoDeeper := false;

  for iChild := High(node.ChildNodes) downto Low(node.ChildNodes) do
    FUnvisited.Push(node.ChildNodes[iChild]);
end; { TSyntaxTreeEnumerator.PushChildrenOnStack }

{ TSyntaxNodeHelper }

class constructor TSyntaxNodeHelper.Create;
var
  nodeType: TSyntaxNodeType;
begin
  for nodeType := Low(TSyntaxNodeType) to High(TSyntaxNodeType) do
    FNodeTypeNames[nodeType] := TRttiEnumerationType.GetName<TSyntaxNodeType>(nodeType);
end; { TSyntaxNodeHelper.Create }

function TSyntaxNodeHelper.All(childrenOnly: boolean): TSyntaxTreeEnumerator;
begin
  Result := TSyntaxTreeEnumerator.Create(Self, childrenOnly);
end; { TSyntaxNodeHelper.All }

function TSyntaxNodeHelper.FindAll(nodeType: TSyntaxNodeType; childrenOnly: boolean): TSyntaxTreeEnumerator;
begin
  Result := TSyntaxTreeEnumerator.Create(Self, [nodeType], childrenOnly);
end; { TSyntaxNodeHelper.FindAll }

function TSyntaxNodeHelper.FindAll(nodeTypes: TSyntaxNodeTypes; childrenOnly: boolean): TSyntaxTreeEnumerator;
begin
  Result := TSyntaxTreeEnumerator.Create(Self, nodeTypes, childrenOnly);
end; { TSyntaxNodeHelper.FindAll }

function TSyntaxNodeHelper.FindFirst(nodeType: TSyntaxNodeType): TSyntaxNode;
begin
  if Typ = nodeType then
    Exit(Self)
  else
    Result := FindNode(nodeType);
end; { TSyntaxNodeHelper.FindFirst }

function TSyntaxNodeHelper.FindFirst(nodeType: TSyntaxNodeType; var childNode:
  TSyntaxNode): boolean;
begin
  childNode := FindFirst(nodetype);
  Result := assigned(childNode);
end; { TSyntaxNodeHelper.FindFirst }

function TSyntaxNodeHelper.FindLocation(line, column: integer): TSyntaxNode;
var
  child: TSyntaxNode;
  nodeWidth: integer;
begin
  Result := nil;

  nodeWidth := Length(Self.GetAttribute(anName));

  if (Self.Line > line)
     or ((Self.Line = line) and (Self.Col > column))
  then
    // This node starts after the location
    Exit;

  if (Self is TCompoundSyntaxNode)
     and ((TCompoundSyntaxNode(Self).EndLine < line)
          or ((TCompoundSyntaxNode(Self).EndLine = line) and (TCompoundSyntaxNode(Self).EndCol <= column)))
  then
    // This node ends before the location
    Exit;

  for child in ChildNodes do begin
    Result := child.FindLocation(line, column);
    if assigned(Result) then
      Exit;
  end;

  if Self is TCompoundSyntaxNode then begin
    if ((Self.Line < line)
         or ((Self.Line = line) and (Self.Col <= column)))
       and
       ((TCompoundSyntaxNode(Self).EndLine > line)
         or ((TCompoundSyntaxNode(Self).EndLine = line) and ((TCompoundSyntaxNode(Self).EndCol) >= column)))
    then
      Result := Self;
  end
  else if (Self.Line = line) and (Self.Col <= column) and (Self.Col + nodeWidth >= column) then
    Result := Self;
end; { TSyntaxNodeHelper.FindLocation }

function TSyntaxNodeHelper.FindParentWithName: TSyntaxNode;
begin
  Result := Self;
  while assigned(Result) and (not Result.HasAttribute(anName)) do
    Result := Result.ParentNode;
end; { TSyntaxNodeHelper.FindParentWithName }

function TSyntaxNodeHelper.GetTypeName: string;
begin
  Result := FNodeTypeNames[Typ];
end; { TSyntaxNodeHelper.GetTypeName }

{ TParsedUnitsHelper }

function TParsedUnitsHelper.Find(const unitName: string;
  var unitInfo: TProjectIndexer.TUnitInfo): boolean;
var
  iUnit: integer;
begin
  Result := false;
  for iUnit := 0 to Count - 1 do
    if SameText(Items[iUnit].Name, unitName) then begin
      unitInfo := Items[iUnit];
      Exit(true);
    end;
end; { TParsedUnitsHelper.Find }

function TParsedUnitsHelper.FindOrDefault(const unitName: string): TProjectIndexer.TUnitInfo;
begin
  if not Find(unitName, Result) then
    Result := Default(TProjectIndexer.TUnitInfo);
end; { TParsedUnitsHelper.FindOrDefault }

end.
