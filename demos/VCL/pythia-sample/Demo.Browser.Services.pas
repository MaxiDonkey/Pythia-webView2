unit Demo.Browser.Services;

interface

uses
  System.SysUtils,
  WVPythia.Chat.Interfaces, WVPythia.Chat.ManagedFlow, WVPythia.TextFile.Helper,
  WVPythia.Strs, WVPythia.JSON.SafeReader, WVPythia.Strings.Escape, WVPythia.Types,
  WVPythia.Vendors.Services, WVPythia.Chat.Consts;

type
  TVendorTest = class
  private
    FBrowser: IPythiaBrowser;
  public
    constructor Create(const ABrowser: IPythiaBrowser);
    procedure Validation(const AState: TInputPromptState;
      const AOnFinalize: TManagedItemFinalizeProc);
    procedure ChatSessionAutoRename(ID, Content: string);
  end;

var
  VendorTest: TVendorTest;

implementation

{ TVendorTest }

procedure TVendorTest.ChatSessionAutoRename(ID, Content: string);
begin
  FBrowser.SessionAutoRename(ID, Content.Split([#10])[0]);
end;

constructor TVendorTest.Create(const ABrowser: IPythiaBrowser);
begin
  inherited Create;
  FBrowser := ABrowser;
  FBrowser.OnChatSessionAutoRename := ChatSessionAutoRename;
end;

procedure TVendorTest.Validation(const AState: TInputPromptState;
  const AOnFinalize: TManagedItemFinalizeProc);
begin
  var Reader := TJsonReader.Parse(AState.Source);
  var S := TEscapeHelper.ToPreformattedHTML(Reader.Format);
  var Model := Reader.AsString('models.categories[1].model');

  var ResponseFlow := TManagedItemLLMResult.New;
  try
    FBrowser.Display(S);
    if FBrowser.PromptCount = 1 then
      FBrowser.ScrollToTop();

    ResponseFlow
      .UsedModel('model-used-' + Model)
      .Response(S)
      .Error(False)
      .ErrorMessage('no error');

    AOnFinalize(ResponseFlow);
  finally
    ResponseFlow.Free;
  end;

end;

end.
