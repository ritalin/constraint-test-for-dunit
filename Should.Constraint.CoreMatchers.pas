unit Should.Constraint.CoreMatchers;

interface

uses
  System.SysUtils,
  System.Rtti, System.TypInfo,
  System.Generics.Defaults,
  Should
;


function BeNil: TValueConstraintOp;
function BeTrue: TValueConstraintOp;
function BeEqualTo(expected: TValue): TValueConstraintOp;
function BeGraterThan(expected: TValue): TValueConstraintOp;
function BeGraterThanOrEqualTo(expected: TValue): TValueConstraintOp;
function BeLessThan(expected: TValue): TValueConstraintOp;
function BeLessThanOrEqualTo(expected: TValue): TValueConstraintOp;

type ExceptionClass = class of Exception;

function BeThrowenException(exType: ExceptionClass): TCallConstraintOp; overload;
function BeThrowenException(exType: ExceptionClass; const expectMsg: string): TCallConstraintOp; overload;

implementation

uses
  StructureEnumeration
;

function ValueToString(const value: TValue): string;
begin
  if value.Kind in [tkClass, tkRecord, tkInterface] then begin
    Result := StructureToJson(value).ToString;
  end
  else begin
    Result := value.ToString;
  end;
end;

function BeNil: TValueConstraintOp;
begin
	Result := TValueConstraintOp.Create(TDelegateValueConstraint.Create(
    TValue.Empty,
    procedure (actual, expected: TValue; negate: boolean; fieldName: string; var outEvalResult: TEvalResult)
    begin
      outEvalResult :=
        TMaybeEvalResult.Create(
          function: TEvalResult
          begin
            if (not (actual.Kind in [tkClass, tkInterface])) and (not actual.IsClass) then begin
              Result.Status := TEvalResult.TEvalStatus.Fatal;
              Result.Message := Format('A Pointer must be passed. [%s:%s]', [fieldName, 'actual']);
            end
            else begin
              Result.Status := TEvalResult.TEvalStatus.Pass;
            end;
          end
        )
        .Next(
          function: TEvalResult
          var
            n: string;
            msg: string;
          begin
            Result.Status := TEvalResult.TEvalStatus.Pass;

            if actual.IsEmpty = negate then begin
              if negate then n:= '' else n:='not';

              msg := Format('The actual value (%s) was %s nil.'#10#9'-actual: %s', [
                fieldName, n, actual.ToString, expected.ToString
              ]);

              Result.Status := TEvalResult.TEvalStatus.Falure;
              Result.Message := msg;
            end;
          end
        )
        .Result
      ;
    end
  ));
end;

function BeTrue: TValueConstraintOp;
begin
	Result := TValueConstraintOp.Create(TDelegateValueConstraint.Create(
    TValue.Empty,
    procedure (actual, expected: TValue; negate: boolean; fieldName: string; var outEvalResult: TEvalResult)
    begin
      outEvalResult :=
        TMaybeEvalResult.Create(
          function: TEvalResult
          begin
            if not actual.IsType<boolean> then begin
              Result.Status := TEvalResult.TEvalStatus.Fatal;
              Result.Message := Format('A boolean value must be passed. [%s:%s]', [fieldName, 'actual']);
            end
            else begin
              Result.Status := TEvalResult.TEvalStatus.Pass;
            end;
          end
        )
        .Next(
          function: TEvalResult
          var
            n: string;
            msg: string;
          begin
            Result.Status := TEvalResult.TEvalStatus.Pass;

            if actual.AsType<boolean> = negate then begin
              if negate then n:= '' else n:='not';

              msg := Format('The actual value (%s) was %s true.', [
                fieldName, n, actual.ToString, expected.ToString
              ]);

              Result.Status := TEvalResult.TEvalStatus.Falure;
              Result.Message := msg;
            end;
          end
        )
        .Result
      ;
    end
  ));
end;

function BeEqualToInternal(actual, expected: TValue): boolean;

  function CompareAsRecord(const actual, expected: TValue): boolean;
  var
    ctx: TRttiContext;
    t: TRttiType;
    fields: TArray<TRttiField>;
    f: TRttiField;
    same: boolean;
  begin
    if actual.TypeInfo <> expected.TypeInfo then Exit(false);

    ctx := TRttiContext.Create;
    try
      t := ctx.GetType(actual.TypeInfo);

      fields := t.AsRecord.GetDeclaredFields;

      for f in fields do begin
        same := BeEqualToInternal(
          f.GetValue(actual.GetReferenceToRawData),
          f.GetValue(expected.GetReferenceToRawData)
        );
        if not same then Exit(false);
      end;

      Result := true;
    finally
      ctx.Free;
    end;
  end;

  function CompareAsObject(const actual, expected: TObject): boolean;
  begin
    if (not Assigned(actual)) and (not Assigned((expected))) then Exit(true);

    if not Assigned(actual) then begin
      expected.Equals(actual);
    end
    else begin
      actual.Equals(expected);
    end;
  end;

  function CompareAsArray(const actual, expected: TValue): boolean;
  var
    i, len: integer;
  begin
    len := actual.GetArrayLength;
    if len <> expected.GetArrayLength then Exit(false);

    for i := 0 to len-1 do begin
      if not BeEqualToInternal(actual.GetArrayElement(i), expected.GetArrayElement(i)) then Exit(false);
    end;

    Result := true;
  end;

begin
  if actual.IsType<string> then begin
    Result := (TStringComparer.Ordinal as IComparer<string>).Compare(actual.ToString, expected.ToString) = 0;
  end
  else if actual.IsObject then begin
    Result := CompareAsObject(actual.AsObject, expected.AsObject);
  end
  else if actual.Kind = tkInterface then begin
    Result := CompareAsObject(TObject(actual.AsInterface), TObject(expected.AsInterface));
  end
  else if actual.Kind = tkRecord then begin
    Result := CompareAsRecord(actual, expected);
  end
  else if actual.Kind in [tkArray, tkDynArray] then begin
    Result := CompareAsArray(actual, expected);
  end
  else begin
    Result := TEqualityComparer<string>.Default.Equals(actual.ToString(), expected.ToString());
  end;
end;

function BeEqualTo(expected: TValue): TValueConstraintOp;
begin
	Result := TValueConstraintOp.Create(TDelegateValueConstraint.Create(
    expected,
    procedure (actual, expected: TValue; negate: boolean; fieldName: string; var outEvalResult: TEvalResult)
    var
      n: string;
      msg: string;
    begin
      if BeEqualToInternal(actual, expected) = negate then begin
        if negate then n:= '' else n:='not';

        msg := Format('The actual value (%s) was %s equal to a expected value.'#10#9'-actual: %s'#10#9'-expected: %s', [
          fieldName, n, ValueToString(actual), ValueToString(expected)
        ]);

        outEvalResult.Status := TEvalResult.TEvalStatus.Falure;
        outEvalResult.Message := msg;
      end;
    end
  ));
end;

function ValidateOrdinaryValue(val: TValue; comments: array of const): TEvalResult;
begin
  if ((val.Kind in [tkClass, tkInterface]) or val.IsClass or val.IsArray or val.IsEmpty) then begin
    Result.Status := TEvalResult.TEvalStatus.Fatal;
    Result.Message := Format('Ordinary value must be passed. [%s:%s]', comments);
  end
  else begin
    Result.Status := TEvalResult.TEvalStatus.Pass;
  end;
end;

type
  TEvaluateAsOrdinaryFunc = reference to function (compared: integer): TEvalResult;

function EvaluateAsOrdinary(actual, expected: TValue; fieldName: string; fn: TEvaluateAsOrdinaryFunc): TMaybeEvalResult;
begin
  Result := TMaybeEvalResult.Create(ValidateOrdinaryValue(actual, [fieldName, 'actual']))
    .Next(
      function: TEvalResult
      begin
        Result := ValidateOrdinaryValue(expected, [fieldName, 'expected']);
      end
    )
    .Next(
      function: TEvalResult
      var
        n: integer;
      begin
        if actual.IsType<string> then begin
          n := (TStringComparer.Ordinal as IComparer<string>).Compare(actual.AsType<string>, expected.AsType<string>);
        end
        else begin
          n := TComparer<string>.Default.Compare(actual.ToString, expected.ToString);
        end;

        Result := fn(n);
      end
    )
  ;
end;

function BeGraterThan(expected: TValue): TValueConstraintOp;
begin
	Result := TValueConstraintOp.Create(TDelegateValueConstraint.Create(
    expected,
    procedure (actual, expected: TValue; negate: boolean; fieldName: string; var outEvalResult: TEvalResult)
    begin
      outEvalResult :=
        EvaluateAsOrdinary(actual, expected, fieldName,
          function (compared: integer): TEvalResult
          var
            n: string;
            msg: string;
          begin
            Result.Status := TEvalResult.TEvalStatus.Pass;

            if (compared <= 0) or negate then begin
              if negate then n:= '' else n:='not';

              msg := Format('The actual value (%s) was %s grater than a expected value.'#10#9'-actual: %s'#10#9'-expected: %s', [
                fieldName, n, actual.ToString, expected.ToString
              ]);

              Result.Status := TEvalResult.TEvalStatus.Falure;
              Result.Message := msg;
            end;
          end
        )
        .Result
      ;
    end
  ));
end;

function BeGraterThanOrEqualTo(expected: TValue): TValueConstraintOp;
begin
	Result := TValueConstraintOp.Create(TDelegateValueConstraint.Create(
    expected,
    procedure (actual, expected: TValue; negate: boolean; fieldName: string; var outEvalResult: TEvalResult)
    begin
      outEvalResult :=
        EvaluateAsOrdinary(actual, expected, fieldName,
          function (compared: integer): TEvalResult
          var
            n: string;
            msg: string;
          begin
            Result.Status := TEvalResult.TEvalStatus.Pass;

            if (compared >= 0) = negate then begin
              if negate then n:= '' else n:='not';

              msg := Format('The actual value (%s) was %s greater than or %s equal to a expected value.'#10#9'-actual: %s'#10#9'-expected: %s', [
                fieldName, n, n, actual.ToString, expected.ToString
              ]);

              Result.Status := TEvalResult.TEvalStatus.Falure;
              Result.Message := msg;
            end;
          end
        )
        .Result
      ;
    end
  ));
end;

function BeLessThan(expected: TValue): TValueConstraintOp;
begin
	Result := TValueConstraintOp.Create(TDelegateValueConstraint.Create(
    expected,
    procedure (actual, expected: TValue; negate: boolean; fieldName: string; var outEvalResult: TEvalResult)
    begin
      outEvalResult :=
        EvaluateAsOrdinary(actual, expected, fieldName,
          function (compared: integer): TEvalResult
          var
            n: string;
            msg: string;
          begin
            Result.Status := TEvalResult.TEvalStatus.Pass;

            if (compared < 0) = negate then begin
              if negate then n:= '' else n:='not';

              msg := Format('The actual value (%s) was %s less than a expected value.'#10#9'-actual: %s'#10#9'-expected: %s', [
                fieldName, n, actual.ToString, expected.ToString
              ]);

              Result.Status := TEvalResult.TEvalStatus.Falure;
              Result.Message := msg;
            end;
          end
        )
        .Result
      ;
    end
  ));
end;

function BeLessThanOrEqualTo(expected: TValue): TValueConstraintOp;
begin
	Result := TValueConstraintOp.Create(TDelegateValueConstraint.Create(
    expected,
    procedure (actual, expected: TValue; negate: boolean; fieldName: string; var outEvalResult: TEvalResult)
    begin
      outEvalResult :=
        EvaluateAsOrdinary(actual, expected, fieldName,
          function (compared: integer): TEvalResult
          var
            n: string;
            msg: string;
          begin
            Result.Status := TEvalResult.TEvalStatus.Pass;

            if (compared >= 0) = negate then begin
              if negate then n:= '' else n:='not';

              msg := Format('The actual value (%s) was %s less than or %s equal to a expected value.'#10#9'-actual: %s'#10#9'-expected: %s', [
                fieldName, n, n, actual.ToString, expected.ToString
              ]);

              Result.Status := TEvalResult.TEvalStatus.Falure;
              Result.Message := msg;
            end;
          end
        )
        .Result
    end
  ));
end;

function BeThrowenException(exType: ExceptionClass): TCallConstraintOp;
var
  n: string;
  msg: string;
begin
  Result := TCallConstraintOp.Create(TDelegateCallConstraint.Create(
    procedure (actual: TProc; negate: boolean; fieldName: string; var outEvalResult: TEvalResult)
    var
      actualEx, expectedEx: string;
    begin
      try
        actual;

        if negate then begin
          outEvalResult.Status := TEvalResult.TEvalStatus.Pass;
          Exit;
        end;
        msg := Format('This call (%s) must be thrown exception.', [fieldName]);
      except
        on ex: Exception do begin
          if (ex is exType) = negate then begin
            if negate then n:= '' else n:='not';

            actualEx := TValue.From(ex).ToString;
            expectedEx := TValue.From(exType).ToString;

            msg := Format(
              'This call (%s) was %s thrown specified exception. '#10#9'-actual: %s'#10#9'-expected: %s', [
              fieldName, n, actualEx, expectedEx
            ]);
          end
          else begin
            outEvalResult.Status := TEvalResult.TEvalStatus.Pass;
            Exit;
          end;
        end;
      end;

      outEvalResult.Status := TEvalResult.TEvalStatus.Falure;
      outEvalResult.Message := msg;
    end
  ));
end;

function BeThrowenException(exType: ExceptionClass; const expectMsg: string): TCallConstraintOp;
var
  n: string;
  msg: string;
begin
  Result := TCallConstraintOp.Create(TDelegateCallConstraint.Create(
    procedure (actual: TProc; negate: boolean; fieldName: string; var outEvalResult: TEvalResult)
    begin
      try
        actual;

        if negate then begin
          outEvalResult.Status := TEvalResult.TEvalStatus.Pass;
          Exit;
        end;
        msg := Format('This call (%s) must be thrown exception.', [fieldName]);
      except
        on ex: Exception do begin
          if ((ex is exType) = negate) and (ex.Message = expectMsg) then begin
            if negate then n:= '' else n:='not';
            msg := Format('This call (%s) was %s thrown specified exception. '#10#9'-expected: %s', [fieldName, n, TValue.From(exType).ToString]);
          end
          else begin
            outEvalResult.Status := TEvalResult.TEvalStatus.Pass;
            Exit;
          end;
        end;
      end;

      outEvalResult.Status := TEvalResult.TEvalStatus.Falure;
      outEvalResult.Message := msg;
    end
  ));
end;

end.

