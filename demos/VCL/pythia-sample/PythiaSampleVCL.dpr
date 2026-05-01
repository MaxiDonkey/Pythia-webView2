program PythiaSampleVCL;

uses
  Vcl.Forms,
  Main in 'Main.pas' {Form1},
  Vcl.Themes,
  Vcl.Styles,
  Pythia.Webview2 in '..\..\..\source\Pythia.Webview2.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
