unit TestExceptionHandler;

interface

uses
  {$IFDEF USE_DUNIT} TestFramework, {$ENDIF}
  {$IFDEF USE_DUNITX} DUnitX.TestFramework, {$ENDIF}
  Should
;

implementation

initialization

Should.RegisterExceptionHandler(
  procedure (evalResult: TEvalResult)
  begin
{$IFDEF USE_DUNIT}
    case (evalResult.Status) of
      TEvalResult.TEvalStatus.Falure:
        raise TestFramework.ETestFailure.Create(evalResult.Message);

      TEvalResult.TEvalStatus.Fatal:
        raise TestFramework.EDunitException.Create(evalResult.Message);
    end;
{$ENDIF}
{$IFDEF USE_DUNITX}
    case (evalResult.Status) of
      TEvalResult.TEvalStatus.Falure:
        raise DUnitX.TestFramework.ETestFailure.Create(evalResult.Message);

      TEvalResult.TEvalStatus.Fatal:
        raise DUnitX.TestFramework.ETestFailure.Create(evalResult.Message);
    end;
{$ENDIF}
end);

end.
