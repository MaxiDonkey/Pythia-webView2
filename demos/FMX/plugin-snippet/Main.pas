unit Main;

interface

uses
  System.SysUtils, System.Types, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Layouts,

  {--- Pythia-Webview }
  FMX.WVPythia.Chat, WVPythia.Types,

  {--- Adapter }
  FMX.WVPythia.Services,

  {--- Snippet plugin integration }
  Demo.Snippet.Plugin.Intf, Demo.Snippet.Plugin, Demo.Snippet.Plugin.Service;

type
  TForm1 = class(TForm)
    Layout1: TLayout;
    procedure FormCreate(Sender: TObject);
  private
    FSnippetService: TSnippetService;
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
  var Filename := '..\demos\FMX\plugin-snippet\README.md';
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
    'Plugin Demo - The snippet command (Pythia-webview2 version: %s)',
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
      FSnippetService := TSnippetService.Create;
      FSnippetService.Browser := Pythia;
      Pythia.CommandLine.RegisterPlugin(TSnippetPlugin.Create(FSnippetService));
    end;

  Pythia.OnInitialized := DoOnInitialized;
  Pythia.Update;
end;

end.
