unit Should;

interface

uses
//	Variants,
  SysUtils, System.Rtti;

type
	TTestEvaluator = class;
	TActualValue = class(TObject)
	private
    FFieldName: string;
		FData: TValue;
	public
		function Val(value: TValue): TTestEvaluator;
	end;

  TEvalResult = record
  type
    TEvalStatus = (Pass, Falure, Fatal);
  public
    Status: TEvalStatus;
    Message: string;
  end;

	TConstraint = class;
  TConstraintOp = record
  private
    FConstraint: TConstraint;

  public
    class operator LogicalNot(c: TConstraintOp): TConstraintOp;
    class operator LogicalOr(c1, c2: TConstraintOp): TConstraintOp;
    class operator LogicalAnd(c1, c2: TConstraintOp): TConstraintOp;

    constructor Create(c: TConstraint);

    procedure Evaluate(actual: TActualValue; negate: boolean);
  end;

	TTestEvaluator = class
	private
		FActual: TActualValue;

	public
		procedure Should(constraint: TConstraintOp);
	end;

	TConstraint = class abstract
	public
		function Evaluate(actual: TActualValue; negate: boolean): TEvalResult; virtual; abstract;
	end;

	TBaseConstraint = class(TConstraint)
	protected
		FExpected: TValue;

  protected
		procedure EvaluateInternal(actual: TValue; negate: boolean; fieldName: string; out EvalResult: TEvalResult); virtual; abstract;
	public
		constructor Create(expected: TValue);

		function Evaluate(actual: TActualValue; negate: boolean): TEvalResult; override;
	end;

  TDelegateConstraint = class(TBaseConstraint)
  type
    TDelegate = reference to procedure (actual, expected: TValue; negate: boolean; fieldName: string; var outEvalResult: TEvalResult);
  private
    FDelegate: TDelegate;
  protected
		procedure EvaluateInternal(actual: TValue; negate: boolean; fieldName: string; out EvalResult: TEvalResult); override;
  public
    constructor Create(expected: TValue; callback: TDelegate);
  end;

{ Eval Result Helper }

  TMaybeEvalResult = record
  type
    TMaybeSelector = reference to function: TEvalResult;
  public
      Result: TEvalResult;

      constructor Create(EvalResult: TEvalResult); overload;
      constructor Create(fn: TMaybeSelector); overload;

      function Next(fn: TMaybeSelector): TMaybeEvalResult;
  end;

  { Test Exception Handler }
  type TestExceptionHandlerproc = reference to procedure (evalResult: TEvalResult);

  procedure RegisterExceptionHandler(handler: TestExceptionHandlerproc);


{ Assertion Entry Point }

function Its(comment: string): TActualValue;

implementation

var
  gExceptionHandler: TestExceptionHandlerproc;

procedure RegisterExceptionHandler(handler: TestExceptionHandlerproc);
begin
  gExceptionHandler := handler;
end;

procedure RaiseTestError(evalResult: TEvalResult);
begin
  System.Assert(Assigned(gExceptionHandler));

  gExceptionHandler(evalResult);
end;

function Its(comment: string): TActualValue;
begin
	Result := TActualValue.Create;
	Result.FFieldName := comment;
end;

function TActualValue.Val(value: TValue): TTestEvaluator;
begin
	FData := value;

	Result := TTestEvaluator.Create;
	Result.FActual := Self;
end;

procedure TTestEvaluator.Should(constraint: TConstraintOp);
begin
	try
		constraint.Evaluate(FActual, false);
	finally
		constraint.FConstraint.Free;
		FActual.Free;
		Self.Free;
	end;
end;

function TBaseConstraint.Evaluate(actual: TActualValue; negate: boolean): TEvalResult;
begin
  Result.Status := TEvalResult.TEvalStatus.Pass;
  Result.Message := '';

  Self.EvaluateInternal(actual.FData, negate, actual.FFieldName, Result);
end;

constructor TBaseConstraint.Create(expected: TValue);
begin
	FExpected := expected;
end;

{ TDelegateConstraint }

constructor TDelegateConstraint.Create(expected: TValue; callback: TDelegate);
begin
  inherited Create(expected);

  System.Assert(Assigned(callback));

  FDelegate := callback;
end;

procedure TDelegateConstraint.EvaluateInternal(actual: TValue; negate: boolean; fieldName: string; out EvalResult: TEvalResult);
begin
  FDelegate(actual, FExpected, negate, fieldName, EvalResult);
end;

type
  TNotConstraint = class(TConstraint)
  private
    FConstraint: TConstraint;

  public
    constructor Create(constraint: TConstraint);
    destructor Destroy; override;

    function Evaluate(actual: TActualValue; negate: boolean): TEvalResult; override;
  end;

  constructor TNotConstraint.Create(constraint: TConstraint);
  begin
    System.Assert(Assigned(constraint));

    FConstraint := constraint;
  end;

  destructor TNotConstraint.Destroy;
  begin
    FConstraint.Free;
  end;

  function TNotConstraint.Evaluate(actual: TActualValue; negate: boolean): TEvalResult;
  begin
    Result := FConstraint.Evaluate(actual, not negate);
  end;

type
  TAndOrConstraint = class(TConstraint)
  private
    FConstraints: TArray<TConstraint>;
    FIsAnd: boolean;

    function EvaluateAsAnd(actual: TActualValue; negate: boolean): TEvalResult;
    function EvaluateAsOr(actual: TActualValue; negate: boolean): TEvalResult;
  public
    constructor Create(c1, c2: TConstraint; isAnd: boolean);
    destructor Destroy; override;

    function Evaluate(actual: TActualValue; negate: boolean): TEvalResult; override;

  end;

  constructor TAndOrConstraint.Create(c1, c2: TConstraint; isAnd: boolean);
  begin
    FConstraints := TArray<TConstraint>.Create(c1, c2);
    FIsAnd := isAnd;
  end;

  destructor TAndOrConstraint.Destroy;
  var
    c: TConstraint;
  begin
    for c in FConstraints do begin
      c.Free;
    end;
  end;

  function TAndOrConstraint.Evaluate(actual: TActualValue; negate: boolean): TEvalResult;
  var
    isAnd: boolean;
  begin
    if negate then isAnd := not FIsAnd else isAnd := FIsAnd;

    if isAnd then begin
      Result := Self.EvaluateAsAnd(actual, negate);
    end
    else begin
      Result := Self.EvaluateAsOr(actual, negate);
    end;
  end;

  function TAndOrConstraint.EvaluateAsAnd(actual: TActualValue; negate: boolean): TEvalResult;
  var
    c: TConstraint;
    evalResult : TEvalResult;
  begin
    for c in FConstraints do begin
      evalResult := c.Evaluate(actual, negate);
      if evalResult.Status <> TEvalResult.TEvalStatus.Pass then begin
        Result := evalResult;
        Exit;
      end;
    end;
  end;

  function TAndOrConstraint.EvaluateAsOr(actual: TActualValue; negate: boolean): TEvalResult;
  var
    c: TConstraint;
    evalResult : TEvalResult;
  begin
    for c in FConstraints do begin
      evalResult := c.Evaluate(actual, negate);
      if evalResult.Status = TEvalResult.TEvalStatus.Pass then begin
        Exit;
      end;
    end;

    Result := evalResult;
  end;

{ TConstraint }

constructor TConstraintOp.Create(c: TConstraint);
begin
  FConstraint := c;
end;

procedure TConstraintOp.Evaluate(actual: TActualValue; negate: boolean);
begin
  RaiseTestError(FConstraint.Evaluate(actual, negate));
end;

class operator TConstraintOp.LogicalNot(c: TConstraintOp): TConstraintOp;
begin
  Result.FConstraint := TNotConstraint.Create(c.FConstraint);
end;

class operator TConstraintOp.LogicalOr(c1, c2: TConstraintOp): TConstraintOp;
begin
  Result.FConstraint := TAndOrConstraint.Create(c1.FConstraint, c2.FConstraint, false);
end;

class operator TConstraintOp.LogicalAnd(c1, c2: TConstraintOp): TConstraintOp;
begin
  Result.FConstraint := TAndOrConstraint.Create(c1.FConstraint, c2.FConstraint, true);
end;


{ TMaybeEvalResult }

constructor TMaybeEvalResult.Create(EvalResult: TEvalResult);
begin
  Self.Result := EvalResult;
end;

constructor TMaybeEvalResult.Create(fn: TMaybeSelector);
begin
  System.Assert(Assigned(fn));

  Self.Result := fn;
end;

function TMaybeEvalResult.Next(fn: TMaybeSelector): TMaybeEvalResult;
begin
  if Self.Result.Status = TEvalResult.TEvalStatus.Pass then begin
    Result.Result := fn;
  end
  else begin
    Result := Self;
  end;
end;

end.
