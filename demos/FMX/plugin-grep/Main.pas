unit Main;

interface

uses
  System.SysUtils, System.Types, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Layouts,

  {--- Pythia-Webview }
  FMX.WVPythia.Chat, WVPythia.Types,

  {--- Adapter }
  FMX.WVPythia.Services,

  {--- Grep plugin integration }
  Demo.Grep.Plugin.Intf, Demo.Grep.Plugin.Service, Demo.Grep.Plugin;

type
  TForm1 = class(TForm)
    Layout1: TLayout;
    procedure FormCreate(Sender: TObject);
  private
    procedure DoOnInitialized;
    procedure DisplayDocumentation;
  public
    Pythia: TFMXPythia;
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

uses
  WVPythia.TextFile.Helper;

{ TForm1 }

procedure TForm1.DisplayDocumentation;
begin
  var Filename := '..\docs\grep-command-documentation.md';
  if not FileExists(Filename) then
    begin
      Pythia.DisplayWarning(Format('Documentation file not found: `%s`', [Filename]));
      Exit;
    end;

  var Documentation := TFileIoHelper.LoadFromFile(Filename);
  Pythia.Display(Documentation, False);
  Pythia.DisplaySpacer();
  Pythia.ScrollToTop();
end;

procedure TForm1.DoOnInitialized;
begin
  TFMXAlphaBlend.ShowWindow(Self);
  DisplayDocumentation;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Width := 1350;
  Height := 870;

  Caption := Format(
    'Plugin Demo - The grep command (Pythia-webview2 version: %s)',
    [TFMXPythia.Version]
  );
  TFMXAlphaBlend.HideWindow(Self);

  Pythia := TFMXPythia.Create(Layout1);
  Pythia.AttachHost(Self);
  Pythia.ServiceAdapter := TFMXChatManagedItemDialogService.Create;

  {--- Host-side plugin wiring }
  Pythia.OnRegisterCommandPlugins :=
    procedure
    begin
        {--- If the executable is in one of the two bin directories, then taking ..\
             will include all the .pas and .js code in the repository }
        GrepService := TGrepService.Create('..\');
        GrepService.Browser := Pythia;
        Pythia.CommandLine.RegisterPlugin(TGrepPlugin.Create(GrepService));
    end;

  Pythia.OnInitialized := DoOnInitialized;
  Pythia.Update;
end;

end.
