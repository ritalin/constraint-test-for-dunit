unit Should.Constraint.CoreMatchers;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Defaults,
  Should
;


function BeNil: TConstraintOp;
function BeTrue: TConstraintOp;
function EqualTo(expected: TValue): TConstraintOp;
function GraterThan(expected: TValue): TConstraintOp;
function GraterThanOrEqualTo(expected: TValue): TConstraintOp;
function LessThan(expected: TValue): TConstraintOp;
function LessThanOrEqualTo(expected: TValue): TConstraintOp;

implementation

function BeNil: TConstraintOp;
begin
	Result := TConstraintOp.Create(TDelegateConstraint.Create(
    TValue.Empty,
    procedure (actual, expected: TValue; negate: boolean; fieldName: string; var outEvalResult: TEvalResult)
    begin
      outEvalResult :=
        TMaybeEvalResult.Create(
          function: TEvalResult
          begin
            if not (actual.IsObject or actual.IsClass) then begin
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

            if (not actual.IsEmpty) and (not negate) then begin
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

function BeTrue: TConstraintOp;
begin
	Result := TConstraintOp.Create(TDelegateConstraint.Create(
    TValue.Empty,
    procedure (actual, expected: TValue; negate: boolean; fieldName: string; var outEvalResult: TEvalResult)
    begin
      outEvalResult :=
        TMaybeEvalResult.Create(
          function: TEvalResult
          begin
            if not actual.IsType<boolean> then begin
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

            if (not actual.AsType<boolean>) and (not negate) then begin
              if negate then n:= '' else n:='not';

              msg := Format('The actual value (%s) was %s true.'#10#9'-actual: %s', [
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

function EqualTo(expected: TValue): TConstraintOp;
var
  same: boolean;
begin
	Result := TConstraintOp.Create(TDelegateConstraint.Create(
    expected,
    procedure (actual, expected: TValue; negate: boolean; fieldName: string; var outEvalResult: TEvalResult)
    var
      n: string;
      msg: string;
    begin
      if actual.IsType<string> then begin
        same := (TStringComparer.Ordinal as IComparer<string>).Compare(actual.AsType<string>, expected.AsType<string>) = 0;
      end
      else if actual.IsObject then begin
        same := TEqualityComparer<TValue>.Default.Equals(actual.AsObject, expected.AsObject);
      end
      else begin
        same := TEqualityComparer<TValue>.Default.Equals(actual, expected);
      end;

      if (not same) and (not negate) then begin
        if negate then n:= '' else n:='not';

        msg := Format('The actual value (%s) was %s equal to a expected value.'#10#9'-actual: %s'#10#9'-expected: %s', [
          fieldName, n, actual.ToString, expected.ToString
        ]);

        outEvalResult.Status := TEvalResult.TEvalStatus.Falure;
        outEvalResult.Message := msg;
      end;
    end
  ));
end;

function ValidateOrdinaryValue(val: TValue; comments: array of const): TEvalResult;
begin
  if (val.IsObject or val.IsClass or val.IsArray or val.IsEmpty) then begin
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
          n := TComparer<TValue>.Default.Compare(actual, expected);
        end;

        Result := fn(n);
      end
    )
  ;
end;

function GraterThan(expected: TValue): TConstraintOp;
begin
	Result := TConstraintOp.Create(TDelegateConstraint.Create(
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

            if (compared <= 0) and (not negate) then begin
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

function GraterThanOrEqualTo(expected: TValue): TConstraintOp;
begin
	Result := TConstraintOp.Create(TDelegateConstraint.Create(
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

            if (compared < 0) and (not negate) then begin
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

function LessThan(expected: TValue): TConstraintOp;
begin
	Result := TConstraintOp.Create(TDelegateConstraint.Create(
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

            if (compared >= 0) and (not negate) then begin
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

function LessThanOrEqualTo(expected: TValue): TConstraintOp;
begin
	Result := TConstraintOp.Create(TDelegateConstraint.Create(
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

            if (compared > 0) and (not negate) then begin
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

end.

