unit Main;

interface

uses
  System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ControlList, Vcl.Buttons,

  {--- Pythia-Webview }
  VCL.WVPythia.Chat, WVPythia.Types, WVPythia.Types.EnumWire,

  {--- Adpater }
  VCL.WVPythia.Services,

  {--- Required for the demo }
  Demo.Browser.Services;

type
  TForm1 = class(TForm)
    Panel1: TPanel;
    Panel2: TPanel;
    ScrollBox1: TScrollBox;
    ControlListCheckBox1: TControlListCheckBox;
    Label1: TLabel;
    ControlListCheckBox2: TControlListCheckBox;
    Label2: TLabel;
    ControlListCheckBox3: TControlListCheckBox;
    Label3: TLabel;
    ControlListCheckBox4: TControlListCheckBox;
    Label4: TLabel;
    ControlListCheckBox5: TControlListCheckBox;
    Label5: TLabel;
    ControlListCheckBox6: TControlListCheckBox;
    Label6: TLabel;
    ControlListCheckBox7: TControlListCheckBox;
    Label7: TLabel;
    ScrollBox2: TScrollBox;
    Label8: TLabel;
    ControlListCheckBox8: TControlListCheckBox;
    ControlListCheckBox9: TControlListCheckBox;
    Label9: TLabel;
    ControlListCheckBox10: TControlListCheckBox;
    Label10: TLabel;
    ControlListCheckBox11: TControlListCheckBox;
    Label11: TLabel;
    ControlListCheckBox12: TControlListCheckBox;
    Label12: TLabel;
    ControlListCheckBox13: TControlListCheckBox;
    Label13: TLabel;
    ControlListCheckBox14: TControlListCheckBox;
    Label14: TLabel;
    ControlListCheckBox15: TControlListCheckBox;
    Label15: TLabel;
    ControlListCheckBox16: TControlListCheckBox;
    Label16: TLabel;
    ControlListCheckBox17: TControlListCheckBox;
    Label17: TLabel;
    ScrollBox3: TScrollBox;
    Panel3: TPanel;
    Panel4: TPanel;
    Panel5: TPanel;
    Panel6: TPanel;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    ControlListCheckBox18: TControlListCheckBox;
    Label18: TLabel;
    ControlListCheckBox19: TControlListCheckBox;
    Label19: TLabel;
    ControlListCheckBox20: TControlListCheckBox;
    Label20: TLabel;
    ControlListCheckBox21: TControlListCheckBox;
    Label21: TLabel;
    ControlListCheckBox22: TControlListCheckBox;
    Label22: TLabel;
    ControlListCheckBox23: TControlListCheckBox;
    Label23: TLabel;
    Label24: TLabel;
    ControlListCheckBox24: TControlListCheckBox;
    Label25: TLabel;
    ControlListCheckBox25: TControlListCheckBox;
    Label26: TLabel;
    ControlListCheckBox26: TControlListCheckBox;
    Label27: TLabel;
    ControlListCheckBox27: TControlListCheckBox;
    Label28: TLabel;
    ControlListCheckBox28: TControlListCheckBox;
    Label29: TLabel;
    ControlListCheckBox29: TControlListCheckBox;
    Label30: TLabel;
    ControlListCheckBox30: TControlListCheckBox;
    Label31: TLabel;
    ControlListCheckBox31: TControlListCheckBox;
    Label32: TLabel;
    ControlListCheckBox32: TControlListCheckBox;
    Label33: TLabel;
    ControlListCheckBox33: TControlListCheckBox;
    Label34: TLabel;
    ControlListCheckBox34: TControlListCheckBox;
    Label35: TLabel;
    ControlListCheckBox35: TControlListCheckBox;
    Label36: TLabel;
    ScrollBox4: TScrollBox;
    SpeedButton3: TSpeedButton;
    Label37: TLabel;
    SpeedButton4: TSpeedButton;
    Panel7: TPanel;
    Panel8: TPanel;
    Panel9: TPanel;
    Panel10: TPanel;
    Label38: TLabel;
    Label39: TLabel;
    Label40: TLabel;
    Label41: TLabel;
    Label42: TLabel;
    Label43: TLabel;
    Label44: TLabel;
    Label45: TLabel;
    Label46: TLabel;
    Label47: TLabel;
    Label48: TLabel;
    Label49: TLabel;
    Label50: TLabel;
    Label51: TLabel;
    Label52: TLabel;
    Label53: TLabel;
    Panel11: TPanel;
    Label54: TLabel;
    Label55: TLabel;
    Label56: TLabel;
    Label57: TLabel;
    Panel12: TPanel;
    Label58: TLabel;
    Label59: TLabel;
    Label60: TLabel;
    Label61: TLabel;
    Label62: TLabel;
    Label63: TLabel;
    Label64: TLabel;
    SpeedButton5: TSpeedButton;
    SpeedButton6: TSpeedButton;
    SpeedButton7: TSpeedButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    procedure DoOnInitialized;
    procedure UpdateTheme;
  public
    Pythia: TVCLPythia;
  end;

var
  Form1: TForm1;

implementation

uses
  Demo.Support, Demo.ContentComposer;

{$R *.dfm}

procedure TForm1.DoOnInitialized;
begin
  CheckComponent := TCheckComponent.Create;
  VendorTest := TVendorTest.Create(Pythia);
  AlphaBlend := False;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Width := 1550;
  Height := 870;

  Caption := Format(
    'Demo - Discovering the interface (Pythia-webview2 version: %s)',
    [TVCLPythia.Version]
  );
  AlphaBlendValue := 0;
  AlphaBlend := True;

  Pythia := TVCLPythia.Create(Panel2);
  Pythia.ServiceAdapter := TVCLChatManagedItemDialogService.Create;
  Pythia.OnThemeChanged := UpdateTheme;
  Pythia.OnRenderChatContent := TDidacticCustomProc.MyChatContentBuilder;
  Pythia.OnInitialized := DoOnInitialized;
  Pythia.Update;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FreeAndNil(VendorTest);
  FreeAndNil(CheckComponent);
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  Panel3.BringToFront;
  Panel7.BringToFront;
end;

procedure TForm1.UpdateTheme;
begin
  if TLookAndFeel.Parse(Pythia.Theme) = TLookAndFeel.light then
    begin
      Panel1.Color := $00EEECEA;
      Panel1.StyleElements := Panel1.StyleElements - [seClient];
    end
  else
    begin
      Panel1.Color := $00242424;
      Panel1.StyleElements := Panel1.StyleElements - [seClient];
    end;
end;

end.
