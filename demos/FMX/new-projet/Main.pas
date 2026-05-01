unit Main;

interface

uses
  System.SysUtils, System.Types, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Layouts,

  {--- Pythia-Webview }
  FMX.WVPythia.Chat, WVPythia.Types,

  {--- Adapter }
  FMX.WVPythia.Services;

type
  TForm1 = class(TForm)
    Layout1: TLayout;
    procedure FormCreate(Sender: TObject);
  private
    procedure DoOnInitialized;
  public
    Pythia: TFMXPythia;
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

{ TForm1 }

procedure TForm1.DoOnInitialized;
begin
  TFMXAlphaBlend.ShowWindow(Self);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Width := 1350;
  Height := 770;

  TFMXAlphaBlend.HideWindow(Self);

  Pythia := TFMXPythia.Create(Layout1);
  Pythia.AttachHost(Self);
  Pythia.ServiceAdapter := TFMXChatManagedItemDialogService.Create;
  Pythia.OnInitialized := DoOnInitialized;
  Pythia.Update;
end;

end.
