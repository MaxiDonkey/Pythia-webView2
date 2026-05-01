unit Main;

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,

  {--- Pythia-Webview }
  VCL.WVPythia.Chat, WVPythia.Types, WVPythia.Types.EnumWire, WVPythia.Strs,

  {--- Adpter }
  VCL.WVPythia.Services,

  {--- Anthropic SDK }
  Anthropic, Anthropic.Browser.Services;

const
  STILL_IN_PROGRESS_ERROR =
    'Requests are still in progress. #10Please wait for them to complete before closing the application.';

type
  TForm1 = class(TForm)
    Panel2: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    procedure DoOnInitialized;
    procedure UpdateApiKey(KeyName: string);
  public
    Pythia: TVCLPythia;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.DoOnInitialized;
begin
  AnthropicVendor := TAnthropicServices.Create(Pythia);
  AlphaBlend := False;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not HttpMonitoring.IsBusy;
  if not CanClose then
    Pythia.DisplayError(STILL_IN_PROGRESS_ERROR);
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

  Pythia := TVCLPythia.Create(Panel2);
  Pythia.EnabledButtons := Pythia.EnabledButtons + [ebSettings];
  Pythia.OnApiKeyChanged := UpdateApiKey;
  Pythia.ServiceAdapter := TVCLChatManagedItemDialogService.Create;
  Pythia.OnInitialized := DoOnInitialized;
  Pythia.Update;
end;

procedure TForm1.UpdateApiKey(KeyName: string);
begin
  if SameText(KeyName, TAnthropicServices.API_KEY_NAME) then
    AnthropicVendor.UpdateApiKey;
end;

end.


