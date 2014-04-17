unit SampleSuite;

interface

type
	TSampleSuite = class
	published
		procedure SuccessTestA;
		procedure FailedTestA;
	end;

implementation

uses
	Should;

procedure TSampleSuite.SuccessTestA;
begin
	Its('integer value').Val(100).Should(EqualToValue(100));
end;

procedure TSampleSuite.FailedTestA;
begin
	Its('integer value').Val(100).Should(EqualToValue(10));
end;

end.

