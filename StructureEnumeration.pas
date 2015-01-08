unit StructureEnumeration;

interface

uses
  SysUtils, Rtti, TypInfo, System.Generics.Collections, Data.DbxJson
;

type
  TStructureItem = TPair<string, TValue>;

  IArrayAccess = interface
    function GetLength: integer;
    function GetItemAt(const idx: integer): TStructureItem;
    function GetEnumerator: TEnumerator<TStructureItem>;

    property Length: integer read GetLength;
    property Item[const idx: integer]: TStructureItem read GetItemAt; default;
  end;

  TValueAsArray = class(TInterfacedObject, IArrayAccess)
  private
    FValue: TValue;
  protected
    { IArrayAccess }
    function GetLength: integer;
    function GetItemAt(const idx: integer): TStructureItem;
    function GetEnumerator: TEnumerator<TStructureItem>;
  public
    constructor Create(const value: TValue);
  end;

  TRawArray<T> = class(TInterfacedObject, IArrayAccess)
  private
    FValues: TArray<T>;
  private
    constructor Create(const values: TArray<T>);
  protected
    { IArrayAccess }
    function GetLength: integer;
    function GetItemAt(const idx: integer): TStructureItem;
    function GetEnumerator: TEnumerator<TStructureItem>;
  public
    class function From(const values: TArray<T>): TRawArray<T>; overload;
    class function From(const values: array of T): TRawArray<T>; overload;
  end;

  TArrayAccessEnumerator = class(TEnumerator<TStructureItem>)
  private
    FOwner: IArrayAccess;
    FIndex: integer;
  protected
    function DoGetCurrent: TStructureItem; override;
    function DoMoveNext: Boolean; override;
  public
    constructor Create(const owner: IArrayAccess);
  end;

function ParseStructure(const value: TValue): IArrayAccess;
function StructureToJson(const value: TValue): TJSONValue;
function ArrayToJson(const arr: IArrayAccess): TJSONValue;

implementation

type
  TStructureEnumerable = class(TInterfacedObject, IArrayAccess)
  private
    FValue: TValue;
    FFields: TArray<TRttiField>;
  protected
    { IArrayAccess }
    function GetLength: integer;
    function GetItemAt(const idx: integer): TStructureItem;
    function GetEnumerator: TEnumerator<TStructureItem>;
  public
    constructor Create(const value: TValue);
  end;

{ TStructureEnumerable }

constructor TStructureEnumerable.Create(const value: TValue);
var
  ctx: TRttiContext;
begin
  FValue := value;

  ctx := TRttiContext.Create;
  try
    FFields := ctx.GetType(FValue.TypeInfo).GetDeclaredFields;
  finally
    ctx.Free;
  end;
end;

function TStructureEnumerable.GetEnumerator: TEnumerator<TStructureItem>;
begin
  Result := TArrayAccessEnumerator.Create(Self);
end;

function TStructureEnumerable.GetItemAt(const idx: integer): TStructureItem;
begin
  Assert((idx >= Low(FFields)) and (idx <= High(FFields)));

  Result := TStructureItem.Create(
    FFields[idx].Name,
    FFields[idx].GetValue(FValue.GetReferenceToRawData)
  );
end;

function TStructureEnumerable.GetLength: integer;
begin
  Result := Length(FFields);
end;

{ TValueAsArray }

constructor TValueAsArray.Create(const value: TValue);
begin
  Assert(value.Kind in [tkDynArray]);

  FValue := value;
end;

function TValueAsArray.GetEnumerator: TEnumerator<TStructureItem>;
begin
  Result := TArrayAccessEnumerator.Create(Self);
end;

function TValueAsArray.GetItemAt(const idx: integer): TStructureItem;
begin
  Assert((idx >= 0) and (idx < Self.GetLength));

  Result := TStructureItem.Create(
    idx.ToString,
    FValue.GetArrayElement(idx)
  );
end;

function TValueAsArray.GetLength: integer;
begin
  Result := FValue.GetArrayLength;
end;

{ TRawArray<T> }

constructor TRawArray<T>.Create(const values: TArray<T>);
begin
  FValues := values;
end;

class function TRawArray<T>.From(const values: array of T): TRawArray<T>;
var
  i: integer;
  arr: TArray<T>;
begin
  SetLength(arr, Length(values));

  for i := Low(values) to High(values) do begin
    arr[i] := values[i];
  end;

  Result := TRawArray<T>.Create(arr);
end;

class function TRawArray<T>.From(const values: TArray<T>): TRawArray<T>;
begin
  Result := TRawArray<T>.Create(values);
end;

function TRawArray<T>.GetEnumerator: TEnumerator<TStructureItem>;
begin
  Result := TArrayAccessEnumerator.Create(Self);
end;

function TRawArray<T>.GetItemAt(const idx: integer): TStructureItem;
begin
  Assert((idx >= 0) and (idx < Self.GetLength));

  Result := TStructureItem.Create(
    idx.ToString,
    TValue.From<T>(FValues[idx])
  );
end;

function TRawArray<T>.GetLength: integer;
begin
  Result := Length(FValues);
end;

{ TStructureEnumerator }

constructor TArrayAccessEnumerator.Create(
  const owner: IArrayAccess);
begin
  FOwner := owner;
  FIndex := -1;
end;

function TArrayAccessEnumerator.DoGetCurrent: TStructureItem;
begin
  Result := FOwner[FIndex];
end;

function TArrayAccessEnumerator.DoMoveNext: Boolean;
begin
  Inc(FIndex);

  Result := FOwner.Length > FIndex;
end;

// -----

function ParseStructure(const value: TValue): IArrayAccess;
begin
  Result := TStructureEnumerable.Create(value);
end;

function StructureToJson(const value: TValue): TJSONValue;
var
  obj: TJSONObject;
  item: TStructureItem;
begin
  obj := TJSONObject.Create;

  for item in ParseStructure(value) do begin
    if item.Value.Kind in [tkClass, tkRecord, tkInterface] then begin
      obj.AddPair(item.Key, StructureToJson(item.Value));
    end
    else if item.Value.Kind in [tkDynArray] then begin
      obj.AddPair(item.Key, ArrayToJson(TValueAsArray.Create(item.Value)));
    end
    else begin
      obj.AddPair(item.Key, item.Value.ToString);
    end;
  end;

  Result := obj;
end;

function ArrayToJson(const arr: IArrayAccess): TJSONValue;
var
  obj: TJSONArray;
  item: TStructureItem;
begin
  obj := TJSONArray.Create;

  for item in arr do begin
    obj.Add(item.Value.ToString);
  end;

  Result := obj;
end;

end.
