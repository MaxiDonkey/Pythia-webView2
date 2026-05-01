unit Main;

(*
    Preparing a small demo repository
    The /git sample is easier to test with a small repository whose state is known in advance.

    # Open a Windows cmd.exe prompt and run:

    mkdir demo-git && cd demo-git
    git init
    git config user.email "test@example.com"
    git config user.name "Demo"

    echo "# Demo" > README.md
    git add README.md
    git commit -m "initial"

    echo "Hello" > a.txt
    git add a.txt
    git commit -m "add a.txt"

    echo "World" >> a.txt
    git add a.txt
    git commit -m "extend a.txt"

    echo "Unstaged change" >> a.txt
    echo "Staged change" > b.txt
    git add b.txt

    # Create the .git directory in the folder upstream of bin64.

    Then configure the host application with this repository root as the Git working directory:
     - FGitService := TGitService.Create(FRunner, '..\');
*)

interface

uses
  System.SysUtils, System.Types, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Layouts,

  {--- Pythia-Webview }
  FMX.WVPythia.Chat, WVPythia.Types,

  {--- Adapter }
  FMX.WVPythia.Services,

  {--- Git plugin integration }
  Demo.Git.Plugin.Intf, Demo.Git.Plugin.Service, Demo.Git.Plugin, Demo.Shell.Runner;

type
  TForm1 = class(TForm)
    Layout1: TLayout;
    procedure FormCreate(Sender: TObject);
  private
    FGitService: TGitService;
    FRunner: TShellRunner;
    procedure DoOnInitialized;
    procedure DisplayDocumentation;
  public
    Pythia: TFMXPythia;
  end;

var
  Form1: TForm1;

implementation

uses
  WVPythia.TextFile.Helper;

{$R *.fmx}

{ TForm1 }

procedure TForm1.DisplayDocumentation;
begin
  var Filename := '..\docs\git-command-documentation.md';
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
    'Plugin Demo - The git command (Pythia-webview2 version: %s)',
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
      FRunner := TShellRunner.Create;
      FGitService := TGitService.Create(FRunner, '..\');
      FGitService.Browser := Pythia;
      Pythia.CommandLine.RegisterPlugin(TGitPlugin.Create(FGitService));
    end;

  Pythia.OnInitialized := DoOnInitialized;
  Pythia.Update;
end;

end.
