unit Should;

interface

uses
//	Variants,
  SysUtils, System.Rtti;

type
	TActualValue = class;
  TActualCall = class;
  IConstraint<T> = interface;

  TValueConstraintOp = record
  private
    FConstraint: IConstraint<TActualValue>;
  public
    class operator LogicalNot(c: TValueConstraintOp): TValueConstraintOp;
    class operator LogicalOr(c1, c2: TValueConstraintOp): TValueConstraintOp;
    class operator LogicalAnd(c1, c2: TValueConstraintOp): TValueConstraintOp;

    constructor Create(c: IConstraint<TActualValue>);

    procedure Evaluate(actual: TActualValue; negate: boolean);
  end;

  TCallConstraintOp = record
  private
    FConstraint: IConstraint<TActualCall>;
  public
    class operator LogicalNot(c: TCallConstraintOp): TCallConstraintOp;
    class operator LogicalOr(c1, c2: TCallConstraintOp): TCallConstraintOp;
    class operator LogicalAnd(c1, c2: TCallConstraintOp): TCallConstraintOp;

    constructor Create(c: IConstraint<TActualCall>);

    procedure Evaluate(actual: TActualCall; negate: boolean);
  end;

	TActualValue = class
  type
    TEvaluator = record
    private
      FActual: TActualValue;
    public
      procedure Should(constraint: TValueConstraintOp);
    end;
	private
    FFieldName: string;
		FData: TValue;
	end;

	TActualCall = class
  type
    TEvaluator = record
    private
      FActual: TActualCall;
    public
      procedure Should(constraint: TCallConstraintOp);
    end;
	private
    FFieldName: string;
		FCall: TProc;
	end;

	TActualValueProvider = record
  private
    FFieldName: string;
	public
		function Val<T>(value: T): TActualValue.TEvaluator;
    function Call(supplier: TProc): TActualCall.TEvaluator;
  end;

  TEvalResult = record
  type
    TEvalStatus = (Pass, Falure, Fatal);
  public
    Status: TEvalStatus;
    Message: string;
  end;

	IConstraint<T> = interface
		function Evaluate(actual: T; negate: boolean): TEvalResult;
	end;

	TValueConstraint = class(TInterfacedObject, IConstraint<TActualValue>)
	public
		function Evaluate(actual: TActualValue; negate: boolean): TEvalResult; virtual; abstract;
	end;

	TCallConstraint = class(TInterfacedObject, IConstraint<TActualCall>)
	public
		function Evaluate(actual: TActualCall; negate: boolean): TEvalResult; virtual; abstract;
	end;

	TBaseValueConstraint = class(TValueConstraint)
	protected
		FExpected: TValue;
  protected
		procedure EvaluateInternal(actual: TValue; negate: boolean; fieldName: string; out EvalResult: TEvalResult); virtual; abstract;
	public
		constructor Create(expected: TValue);
    destructor Destroy; override;

		function Evaluate(actual: TActualValue; negate: boolean): TEvalResult; override;
	end;

  TDelegateValueConstraint = class(TBaseValueConstraint)
  type
    TDelegate = reference to procedure (actual, expected: TValue; negate: boolean; fieldName: string; var outEvalResult: TEvalResult);
  private
    FDelegate: TDelegate;
  protected
		procedure EvaluateInternal(actual: TValue; negate: boolean; fieldName: string; out EvalResult: TEvalResult); override;
  public
    constructor Create(expected: TValue; callback: TDelegate);
  end;

  TDelegateCallConstraint = class(TCallConstraint)
  type
    TDelegate = reference to procedure (actual: TProc; negate: boolean; fieldName: string; var outEvalResult: TEvalResult);
  private
    FDelegate: TDelegate;
  public
    constructor Create(callback: TDelegate);

		function Evaluate(actual: TActualCall; negate: boolean): TEvalResult; override;
  end;

  TNotConstraint<T> = class(TInterfacedObject, IConstraint<T>)
  private
    FConstraint: IConstraint<T>;
  public
    constructor Create(constraint: IConstraint<T>);
    destructor Destroy; override;

    function Evaluate(actual: T; negate: boolean): TEvalResult;
  end;

  TAndOrConstraint<T> = class(TInterfacedObject, IConstraint<T>)
  private
    FConstraints: TArray<IConstraint<T>>;
    FIsAnd: boolean;

    function EvaluateAsAnd(actual: T; negate: boolean): TEvalResult;
    function EvaluateAsOr(actual: T; negate: boolean): TEvalResult;
  public
    constructor Create(c1, c2: IConstraint<T>; isAnd: boolean);
    destructor Destroy; override;

    function Evaluate(actual: T; negate: boolean): TEvalResult;
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
  procedure RaiseTestError(evalResult: TEvalResult);


{ Assertion Entry Point }

function Its(comment: string): TActualValueProvider;

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

function Its(comment: string): TActualValueProvider;
begin
	Result.FFieldName := comment;
end;

function TBaseValueConstraint.Evaluate(actual: TActualValue; negate: boolean): TEvalResult;
begin
  Result.Status := TEvalResult.TEvalStatus.Pass;
  Result.Message := '';

  Self.EvaluateInternal(actual.FData, negate, actual.FFieldName, Result);
end;

constructor TBaseValueConstraint.Create(expected: TValue);
begin
	FExpected := expected;
end;

destructor TBaseValueConstraint.Destroy;
begin
  inherited;
end;

{ TDelegateConstraint }

constructor TDelegateValueConstraint.Create(expected: TValue; callback: TDelegate);
begin
  inherited Create(expected);

  System.Assert(Assigned(callback));

  FDelegate := callback;
end;

procedure TDelegateValueConstraint.EvaluateInternal(actual: TValue; negate: boolean; fieldName: string; out EvalResult: TEvalResult);
begin
  FDelegate(actual, FExpected, negate, fieldName, EvalResult);
end;

{ TDelegateCallConstraint }

constructor TDelegateCallConstraint.Create(callback: TDelegate);
begin
  System.Assert(Assigned(callback));

  FDelegate := callback;
end;

function TDelegateCallConstraint.Evaluate(actual: TActualCall; negate: boolean): TEvalResult;
begin
   FDelegate(actual.FCall, negate, actual.FFieldName, Result);
end;

  constructor TNotConstraint<T>.Create(constraint: IConstraint<T>);
  begin
    System.Assert(Assigned(constraint));

    FConstraint := constraint;
  end;

  destructor TNotConstraint<T>.Destroy;
  begin
    FConstraint := nil;
  end;

  function TNotConstraint<T>.Evaluate(actual: T; negate: boolean): TEvalResult;
  begin
    Result := FConstraint.Evaluate(actual, not negate);
  end;

  constructor TAndOrConstraint<T>.Create(c1, c2: IConstraint<T>; isAnd: boolean);
  begin
    FConstraints := TArray<IConstraint<T>>.Create(c1, c2);
    FIsAnd := isAnd;
  end;

  destructor TAndOrConstraint<T>.Destroy;
  var
    c: IConstraint<T>;
  begin
//    for c in FConstraints do begin
//      c := nil;
//    end;
  end;

  function TAndOrConstraint<T>.Evaluate(actual: T; negate: boolean): TEvalResult;
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

  function TAndOrConstraint<T>.EvaluateAsAnd(actual: T; negate: boolean): TEvalResult;
  var
    c: IConstraint<T>;
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

  function TAndOrConstraint<T>.EvaluateAsOr(actual: T; negate: boolean): TEvalResult;
  var
    c: IConstraint<T>;
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

constructor TValueConstraintOp.Create(c: IConstraint<TActualValue>);
begin
  FConstraint := c;
end;

procedure TValueConstraintOp.Evaluate(actual: TActualValue; negate: boolean);
begin
  RaiseTestError(FConstraint.Evaluate(actual, negate));
end;

class operator TValueConstraintOp.LogicalNot(c: TValueConstraintOp): TValueConstraintOp;
begin
  Result.FConstraint := TNotConstraint<TActualValue>.Create(c.FConstraint);
end;

class operator TValueConstraintOp.LogicalOr(c1, c2: TValueConstraintOp): TValueConstraintOp;
begin
  Result.FConstraint := TAndOrConstraint<TActualValue>.Create(c1.FConstraint, c2.FConstraint, false);
end;

class operator TValueConstraintOp.LogicalAnd(c1, c2: TValueConstraintOp): TValueConstraintOp;
begin
  Result.FConstraint := TAndOrConstraint<TActualValue>.Create(c1.FConstraint, c2.FConstraint, true);
end;

{ TCallConstraintOp }

constructor TCallConstraintOp.Create(c: IConstraint<TActualCall>);
begin
  FConstraint := c;
end;

procedure TCallConstraintOp.Evaluate(actual: TActualCall; negate: boolean);
begin
  RaiseTestError(FConstraint.Evaluate(actual, negate));
end;

class operator TCallConstraintOp.LogicalNot(c: TCallConstraintOp): TCallConstraintOp;
begin
  Result.FConstraint := TNotConstraint<TActualCall>.Create(c.FConstraint);
end;

class operator TCallConstraintOp.LogicalOr(c1, c2: TCallConstraintOp): TCallConstraintOp;
begin
  Result.FConstraint := TAndOrConstraint<TActualCall>.Create(c1.FConstraint, c2.FConstraint, false);
end;

class operator TCallConstraintOp.LogicalAnd(c1,c2: TCallConstraintOp): TCallConstraintOp;
begin
  Result.FConstraint := TAndOrConstraint<TActualCall>.Create(c1.FConstraint, c2.FConstraint, true);
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

{ TActualValueProvider }

function TActualValueProvider.Call(supplier: TProc): TActualCall.TEvaluator;
begin
	Result.FActual := TActualCall.Create;
  Result.FActual.FFieldName := FFieldName;
  Result.FActual.FCall := supplier;
end;

function TActualValueProvider.Val<T>(value: T): TActualValue.TEvaluator;
begin
	Result.FActual := TActualValue.Create;
  Result.FActual.FFieldName := FFieldName;
  Result.FActual.FData := TValue.From(value);
end;

procedure TActualValue.TEvaluator.Should(constraint: TValueConstraintOp);
begin
	try
		constraint.Evaluate(FActual, false);
	finally
		constraint.FConstraint := nil;
		FActual.Free;
	end;
end;

{ TActualCall.TEvaluator }

procedure TActualCall.TEvaluator.Should(constraint: TCallConstraintOp);
begin
	try
		constraint.Evaluate(FActual, false);
	finally
		constraint.FConstraint := nil;
		FActual.Free;
	end;
end;

end.
