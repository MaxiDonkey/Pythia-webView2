program VCL_Anthropic;

uses
  Vcl.Forms,
  Main in 'Main.pas' {Form1},
  Vcl.Themes,
  Vcl.Styles,
  Demo.Anthropic.AsyncUtils in 'Demo.Anthropic.AsyncUtils.pas',
  Demo.Anthropic.JsonResponse.Helper in 'Demo.Anthropic.JsonResponse.Helper.pas',
  Demo.Anthropic.Upload in 'Demo.Anthropic.Upload.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
