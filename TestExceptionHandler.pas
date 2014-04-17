unit TestExceptionHandler;

interface

uses
  TestFramework,
  Should
;

implementation

initialization

Should.RegisterExceptionHandler(
  procedure (evalResult: TEvalResult)
  begin
    case (evalResult.Status) of
      TEvalResult.TEvalStatus.Falure:
        raise TestFramework.ETestFailure.Create(evalResult.Message);

      TEvalResult.TEvalStatus.Fatal:
        raise TestFramework.EDunitException.Create(evalResult.Message);
    end;
  end);

end.
