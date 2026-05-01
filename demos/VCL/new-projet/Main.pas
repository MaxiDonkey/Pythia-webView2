unit Main;

interface

uses
  System.SysUtils,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ControlList, Vcl.Buttons,

  {--- Pythia-Webview }
  VCL.WVPythia.Chat, WVPythia.Types, WVPythia.Types.EnumWire,

  {--- Adapter }
  VCL.WVPythia.Services, System.Classes;

type
  TForm1 = class(TForm)
    Panel1: TPanel;
    procedure FormCreate(Sender: TObject);
  private
    procedure DoOnInitialized;
  public
    Pythia: TVCLPythia;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.DoOnInitialized;
begin
  AlphaBlend := False;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Width := 1350;
  Height := 770;

  AlphaBlendValue := 0;
  AlphaBlend := True;

  Pythia := TVCLPythia.Create(Panel1);
  Pythia.ServiceAdapter := TVCLChatManagedItemDialogService.Create;
  Pythia.OnInitialized := DoOnInitialized;
  Pythia.Update;
end;

end.
