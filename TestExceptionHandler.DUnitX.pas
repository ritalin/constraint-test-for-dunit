unit TestExceptionHandler.DUnitX;

interface

implementation

uses
  Should, DUnitX.TestFramework;

initialization

Should.RegisterExceptionHandler(
  procedure (evalResult: TEvalResult)
  begin
    case (evalResult.Status) of
      TEvalResult.TEvalStatus.Falure:
        raise DUnitX.TestFramework.ETestFailure.Create(evalResult.Message);

      TEvalResult.TEvalStatus.Fatal:
        raise DUnitX.TestFramework.ETestFailure.Create(evalResult.Message);
    end;
  end);

end.
