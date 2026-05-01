object Form1: TForm1
  Left = 0
  Top = 0
  AlphaBlend = True
  AlphaBlendValue = 0
  Caption = 'Demo - Interface discovery v0.9.0.0'
  ClientHeight = 877
  ClientWidth = 1087
  Color = clWindow
  Ctl3D = False
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  TextHeight = 15
  object Panel1: TPanel
    Left = 856
    Top = 0
    Width = 231
    Height = 877
    Align = alRight
    BevelOuter = bvNone
    Caption = 'Panel1'
    Color = 15658218
    DoubleBuffered = True
    FullRepaint = False
    ParentBackground = False
    ParentDoubleBuffered = False
    ShowCaption = False
    TabOrder = 0
    StyleElements = []
    object ScrollBox1: TScrollBox
      Left = 0
      Top = 0
      Width = 231
      Height = 877
      Align = alClient
      BorderStyle = bsNone
      TabOrder = 0
      object ControlListCheckBox1: TControlListCheckBox
        Left = 16
        Top = 8
        Width = 18
        Height = 18
        StyleName = 'Windows'
      end
      object Label1: TLabel
        Left = 40
        Top = 10
        Width = 142
        Height = 15
        Hint = 'Now click on the "Settings" button'
        Caption = 'Custom "Settings" enabled'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        ParentShowHint = False
        ShowHint = False
        StyleElements = [seClient, seBorder]
      end
      object ControlListCheckBox2: TControlListCheckBox
        Left = 16
        Top = 28
        Width = 18
        Height = 18
        StyleName = 'Windows'
      end
      object Label2: TLabel
        Left = 40
        Top = 30
        Width = 134
        Height = 15
        Caption = 'Custom "Model" enabled'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = [seClient, seBorder]
      end
      object ControlListCheckBox3: TControlListCheckBox
        Left = 16
        Top = 49
        Width = 18
        Height = 18
        StyleName = 'Windows'
      end
      object Label3: TLabel
        Left = 40
        Top = 50
        Width = 118
        Height = 15
        Caption = 'Custom cards enabled'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = [seClient, seBorder]
      end
      object ControlListCheckBox4: TControlListCheckBox
        Left = 16
        Top = 80
        Width = 18
        Height = 18
        StyleName = 'Windows'
        Checked = True
        CheckState = cbChecked
      end
      object Label4: TLabel
        Left = 40
        Top = 82
        Width = 151
        Height = 15
        Caption = '"Function" (+) button visible'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = [seClient, seBorder]
      end
      object ControlListCheckBox5: TControlListCheckBox
        Left = 16
        Top = 100
        Width = 18
        Height = 18
        StyleName = 'Windows'
      end
      object Label5: TLabel
        Left = 40
        Top = 102
        Width = 140
        Height = 15
        Caption = 'Microphone button visible'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = [seClient, seBorder]
      end
      object ControlListCheckBox6: TControlListCheckBox
        Left = 16
        Top = 121
        Width = 18
        Height = 18
        StyleName = 'Windows'
        Checked = True
        CheckState = cbChecked
      end
      object Label6: TLabel
        Left = 40
        Top = 122
        Width = 127
        Height = 15
        Caption = '"Settings" button visible'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = [seClient, seBorder]
      end
      object ControlListCheckBox7: TControlListCheckBox
        Left = 16
        Top = 142
        Width = 18
        Height = 18
        StyleName = 'Windows'
        Checked = True
        CheckState = cbChecked
      end
      object Label7: TLabel
        Left = 40
        Top = 143
        Width = 119
        Height = 15
        Caption = '"Model" button visible'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = [seClient, seBorder]
      end
      object SpeedButton1: TSpeedButton
        Left = 35
        Top = 391
        Width = 23
        Height = 22
        Caption = #58962
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe Fluent Icons'
        Font.Style = []
        ParentFont = False
      end
      object SpeedButton2: TSpeedButton
        Left = 175
        Top = 394
        Width = 23
        Height = 22
        Caption = #58961
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe Fluent Icons'
        Font.Style = []
        ParentFont = False
      end
      object Label24: TLabel
        Left = 64
        Top = 394
        Width = 105
        Height = 15
        Alignment = taCenter
        AutoSize = False
        Caption = 'sub menus'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        StyleElements = [seClient, seBorder]
      end
      object SpeedButton3: TSpeedButton
        Left = 35
        Top = 548
        Width = 23
        Height = 22
        Caption = #58962
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe Fluent Icons'
        Font.Style = []
        ParentFont = False
      end
      object Label37: TLabel
        Left = 64
        Top = 551
        Width = 105
        Height = 15
        Alignment = taCenter
        AutoSize = False
        Caption = 'Discovery'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        StyleElements = [seClient, seBorder]
      end
      object SpeedButton4: TSpeedButton
        Left = 175
        Top = 551
        Width = 23
        Height = 22
        Caption = #58961
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe Fluent Icons'
        Font.Style = []
        ParentFont = False
      end
      object SpeedButton5: TSpeedButton
        Left = 16
        Top = 703
        Width = 185
        Height = 25
        Caption = 'Dialog service warning'
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = [seClient, seBorder]
      end
      object SpeedButton6: TSpeedButton
        Left = 16
        Top = 734
        Width = 185
        Height = 25
        Caption = 'Default model error'
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = [seClient, seBorder]
      end
      object SpeedButton7: TSpeedButton
        Left = 16
        Top = 765
        Width = 185
        Height = 25
        Caption = 'Create a new project'
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8355711
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = [seClient, seBorder]
      end
      object ScrollBox2: TScrollBox
        Left = 3
        Top = 174
        Width = 198
        Height = 211
        BorderStyle = bsNone
        TabOrder = 0
        object Label8: TLabel
          Left = 36
          Top = 3
          Width = 84
          Height = 15
          Caption = 'Endpoint visible'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 8355711
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          StyleElements = [seClient, seBorder]
        end
        object ControlListCheckBox8: TControlListCheckBox
          Left = 12
          Top = 1
          Width = 18
          Height = 18
          StyleName = 'Windows'
          Checked = True
          CheckState = cbChecked
        end
        object ControlListCheckBox9: TControlListCheckBox
          Left = 12
          Top = 21
          Width = 18
          Height = 18
          StyleName = 'Windows'
          Checked = True
          CheckState = cbChecked
        end
        object Label9: TLabel
          Left = 36
          Top = 23
          Width = 107
          Height = 15
          Caption = 'Web research visible'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 8355711
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          StyleElements = [seClient, seBorder]
        end
        object ControlListCheckBox10: TControlListCheckBox
          Left = 12
          Top = 42
          Width = 18
          Height = 18
          StyleName = 'Windows'
          Checked = True
          CheckState = cbChecked
        end
        object Label10: TLabel
          Left = 36
          Top = 43
          Width = 91
          Height = 15
          Caption = 'Reasoning visible'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 8355711
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          StyleElements = [seClient, seBorder]
        end
        object ControlListCheckBox11: TControlListCheckBox
          Left = 12
          Top = 64
          Width = 18
          Height = 18
          StyleName = 'Windows'
          Checked = True
          CheckState = cbChecked
        end
        object Label11: TLabel
          Left = 36
          Top = 66
          Width = 95
          Height = 15
          Caption = 'Attach files visible'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 8355711
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          StyleElements = [seClient, seBorder]
        end
        object ControlListCheckBox12: TControlListCheckBox
          Left = 12
          Top = 84
          Width = 18
          Height = 18
          StyleName = 'Windows'
          Checked = True
          CheckState = cbChecked
        end
        object Label12: TLabel
          Left = 36
          Top = 86
          Width = 132
          Height = 15
          Caption = 'Knowledge search visible'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 8355711
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          StyleElements = [seClient, seBorder]
        end
        object ControlListCheckBox13: TControlListCheckBox
          Left = 12
          Top = 105
          Width = 18
          Height = 18
          StyleName = 'Windows'
          Checked = True
          CheckState = cbChecked
        end
        object Label13: TLabel
          Left = 36
          Top = 106
          Width = 68
          Height = 15
          Caption = 'Vision visible'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 8355711
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          StyleElements = [seClient, seBorder]
        end
        object ControlListCheckBox14: TControlListCheckBox
          Left = 12
          Top = 126
          Width = 18
          Height = 18
          StyleName = 'Windows'
          Checked = True
          CheckState = cbChecked
        end
        object Label14: TLabel
          Left = 36
          Top = 127
          Width = 106
          Height = 15
          Caption = 'Deep reseach visible'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 8355711
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          StyleElements = [seClient, seBorder]
        end
        object ControlListCheckBox15: TControlListCheckBox
          Left = 12
          Top = 146
          Width = 18
          Height = 18
          StyleName = 'Windows'
          Checked = True
          CheckState = cbChecked
        end
        object Label15: TLabel
          Left = 36
          Top = 147
          Width = 94
          Height = 15
          Caption = 'Integration visible'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 8355711
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          StyleElements = [seClient, seBorder]
        end
        object ControlListCheckBox16: TControlListCheckBox
          Left = 12
          Top = 167
          Width = 18
          Height = 18
          StyleName = 'Windows'
          Checked = True
          CheckState = cbChecked
        end
        object Label16: TLabel
          Left = 36
          Top = 168
          Width = 69
          Height = 15
          Caption = 'Media visible'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 8355711
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          StyleElements = [seClient, seBorder]
        end
        object ControlListCheckBox17: TControlListCheckBox
          Left = 12
          Top = 188
          Width = 18
          Height = 18
          StyleName = 'Windows'
          Checked = True
          CheckState = cbChecked
        end
        object Label17: TLabel
          Left = 36
          Top = 189
          Width = 78
          Height = 15
          Caption = 'Custom visible'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 8355711
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          StyleElements = [seClient, seBorder]
        end
      end
      object ScrollBox4: TScrollBox
        Left = 3
        Top = 568
        Width = 198
        Height = 129
        BorderStyle = bsNone
        TabOrder = 2
        object Panel7: TPanel
          Left = 0
          Top = 0
          Width = 198
          Height = 129
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 3
          object Label38: TLabel
            Left = 24
            Top = 25
            Width = 130
            Height = 15
            Cursor = crHandPoint
            Caption = 'Display generated image'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label39: TLabel
            Left = 16
            Top = 4
            Width = 73
            Height = 15
            Caption = 'UI capabilities'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
          object Label40: TLabel
            Left = 24
            Top = 46
            Width = 127
            Height = 15
            Cursor = crHandPoint
            Caption = 'Display generated audio'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label41: TLabel
            Left = 24
            Top = 67
            Width = 126
            Height = 15
            Cursor = crHandPoint
            Caption = 'Display generated video'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label42: TLabel
            Left = 24
            Top = 88
            Width = 118
            Height = 15
            Cursor = crHandPoint
            Caption = 'Display generated files'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
        end
        object Panel8: TPanel
          Left = 0
          Top = 0
          Width = 198
          Height = 129
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 0
          object Label43: TLabel
            Left = 16
            Top = 4
            Width = 116
            Height = 15
            Caption = 'UI prompt capabilities'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
          object Label44: TLabel
            Left = 24
            Top = 25
            Width = 159
            Height = 15
            Cursor = crHandPoint
            Caption = 'Image attached to the prompt'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label45: TLabel
            Left = 24
            Top = 46
            Width = 149
            Height = 15
            Cursor = crHandPoint
            Caption = 'Files attached to the prompt'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label46: TLabel
            Left = 24
            Top = 67
            Width = 126
            Height = 15
            Cursor = crHandPoint
            Caption = 'Images && Files attached'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label47: TLabel
            Left = 24
            Top = 88
            Width = 97
            Height = 15
            Cursor = crHandPoint
            Caption = 'Prompts very long'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
        end
        object Panel9: TPanel
          Left = 0
          Top = 0
          Width = 198
          Height = 129
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 1
          object Label48: TLabel
            Left = 16
            Top = 4
            Width = 113
            Height = 15
            Caption = 'UI display capabilities'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
          object Label49: TLabel
            Left = 24
            Top = 25
            Width = 103
            Height = 15
            Cursor = crHandPoint
            Caption = 'Using LaTeX format'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label50: TLabel
            Left = 24
            Top = 46
            Width = 116
            Height = 15
            Cursor = crHandPoint
            Caption = 'Using code and arrays'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
        end
        object Panel10: TPanel
          Left = 0
          Top = 0
          Width = 198
          Height = 129
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 2
          object Label51: TLabel
            Left = 16
            Top = 4
            Width = 118
            Height = 15
            Caption = 'Sessions management'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
          object Label52: TLabel
            Left = 24
            Top = 25
            Width = 120
            Height = 15
            Cursor = crHandPoint
            Caption = 'Create session by code'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label53: TLabel
            Left = 24
            Top = 46
            Width = 158
            Height = 15
            Cursor = crHandPoint
            Caption = 'Create session about README'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
        end
        object Panel11: TPanel
          Left = 0
          Top = 0
          Width = 198
          Height = 129
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 4
          object Label54: TLabel
            Left = 16
            Top = 4
            Width = 100
            Height = 15
            Caption = 'Configurable JSON'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
          object Label55: TLabel
            Left = 24
            Top = 25
            Width = 54
            Height = 15
            Cursor = crHandPoint
            Caption = 'model-list'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label56: TLabel
            Left = 24
            Top = 67
            Width = 59
            Height = 15
            Cursor = crHandPoint
            Caption = 'capabilities'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label64: TLabel
            Left = 23
            Top = 46
            Width = 154
            Height = 19
            Cursor = crHandPoint
            AutoSize = False
            Caption = 'model-get-replace-version'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label57: TLabel
            Left = 24
            Top = 88
            Width = 92
            Height = 15
            Cursor = crHandPoint
            Caption = 'custom-template'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
        end
        object Panel12: TPanel
          Left = 0
          Top = 0
          Width = 198
          Height = 129
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 5
          object Label58: TLabel
            Left = 16
            Top = 4
            Width = 133
            Height = 15
            Caption = 'Configurable JSON Cards'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
          object Label59: TLabel
            Left = 24
            Top = 25
            Width = 78
            Height = 15
            Cursor = crHandPoint
            Caption = 'function-cards'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label60: TLabel
            Left = 25
            Top = 46
            Width = 57
            Height = 15
            Cursor = crHandPoint
            Caption = 'mcp-cards'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label61: TLabel
            Left = 25
            Top = 67
            Width = 53
            Height = 15
            Cursor = crHandPoint
            Caption = 'skill-cards'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label62: TLabel
            Left = 25
            Top = 88
            Width = 63
            Height = 15
            Cursor = crHandPoint
            Caption = 'agent-cards'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label63: TLabel
            Left = 25
            Top = 109
            Width = 73
            Height = 15
            Cursor = crHandPoint
            Caption = 'custom-cards'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 16744448
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsUnderline]
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
        end
      end
      object ScrollBox3: TScrollBox
        Left = 3
        Top = 414
        Width = 198
        Height = 131
        BorderStyle = bsNone
        TabOrder = 1
        object Panel4: TPanel
          Left = 0
          Top = 0
          Width = 198
          Height = 131
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 1
          object ControlListCheckBox24: TControlListCheckBox
            Left = 12
            Top = -2
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label25: TLabel
            Left = 36
            Top = 0
            Width = 58
            Height = 15
            Caption = 'Low visible'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object ControlListCheckBox25: TControlListCheckBox
            Left = 12
            Top = 18
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label26: TLabel
            Left = 36
            Top = 20
            Width = 81
            Height = 15
            Caption = 'Medium visible'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object ControlListCheckBox26: TControlListCheckBox
            Left = 12
            Top = 39
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label27: TLabel
            Left = 36
            Top = 40
            Width = 62
            Height = 15
            Caption = 'High visible'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
        end
        object Panel6: TPanel
          Left = 0
          Top = 0
          Width = 198
          Height = 131
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 3
          object ControlListCheckBox31: TControlListCheckBox
            Left = 12
            Top = -2
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label32: TLabel
            Left = 36
            Top = 0
            Width = 122
            Height = 15
            Caption = 'Create an image visible'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object ControlListCheckBox32: TControlListCheckBox
            Left = 12
            Top = 18
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label33: TLabel
            Left = 36
            Top = 20
            Width = 111
            Height = 15
            Caption = 'Create a video visible'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object ControlListCheckBox33: TControlListCheckBox
            Left = 12
            Top = 39
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label34: TLabel
            Left = 36
            Top = 40
            Width = 103
            Height = 15
            Caption = 'Create audio visible'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object ControlListCheckBox34: TControlListCheckBox
            Left = 12
            Top = 61
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label35: TLabel
            Left = 36
            Top = 63
            Width = 110
            Height = 15
            Caption = 'Speech to text visible'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object ControlListCheckBox35: TControlListCheckBox
            Left = 12
            Top = 81
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label36: TLabel
            Left = 36
            Top = 83
            Width = 111
            Height = 15
            Caption = 'Text to speech visible'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
        end
        object Panel5: TPanel
          Left = 0
          Top = 0
          Width = 198
          Height = 131
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 2
          object ControlListCheckBox27: TControlListCheckBox
            Left = 12
            Top = -2
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label28: TLabel
            Left = 36
            Top = 0
            Width = 83
            Height = 15
            Caption = 'Function visible'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object ControlListCheckBox28: TControlListCheckBox
            Left = 12
            Top = 18
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label29: TLabel
            Left = 36
            Top = 20
            Width = 62
            Height = 15
            Caption = 'MCP visible'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object ControlListCheckBox29: TControlListCheckBox
            Left = 12
            Top = 39
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label30: TLabel
            Left = 36
            Top = 40
            Width = 62
            Height = 15
            Caption = 'Skills visible'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object ControlListCheckBox30: TControlListCheckBox
            Left = 12
            Top = 61
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label31: TLabel
            Left = 36
            Top = 63
            Width = 73
            Height = 15
            Caption = 'Agents visible'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
        end
        object Panel3: TPanel
          Left = 0
          Top = 0
          Width = 198
          Height = 131
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 0
          object ControlListCheckBox18: TControlListCheckBox
            Left = 12
            Top = -2
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label18: TLabel
            Left = 36
            Top = 0
            Width = 106
            Height = 15
            Caption = 'v1/chat/completion'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object ControlListCheckBox19: TControlListCheckBox
            Left = 12
            Top = 18
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object ControlListCheckBox20: TControlListCheckBox
            Left = 12
            Top = 39
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label20: TLabel
            Left = 36
            Top = 41
            Width = 63
            Height = 15
            Caption = 'v1/message'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object ControlListCheckBox21: TControlListCheckBox
            Left = 12
            Top = 61
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label21: TLabel
            Left = 36
            Top = 62
            Width = 92
            Height = 15
            Caption = ':generateContent'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object ControlListCheckBox22: TControlListCheckBox
            Left = 12
            Top = 81
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label22: TLabel
            Left = 36
            Top = 83
            Width = 79
            Height = 15
            Caption = 'v1/interactions'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object ControlListCheckBox23: TControlListCheckBox
            Left = 12
            Top = 102
            Width = 18
            Height = 18
            StyleName = 'Windows'
            Checked = True
            CheckState = cbChecked
          end
          object Label23: TLabel
            Left = 36
            Top = 103
            Width = 85
            Height = 15
            Caption = 'v1/conversation'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
          object Label19: TLabel
            Left = 36
            Top = 20
            Width = 92
            Height = 15
            Caption = 'v1/chat/response'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8355711
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            StyleElements = [seClient, seBorder]
          end
        end
      end
    end
  end
  object Panel2: TPanel
    Left = 0
    Top = 0
    Width = 856
    Height = 877
    Align = alClient
    BevelOuter = bvNone
    Caption = 'Panel2'
    ParentBackground = False
    ShowCaption = False
    TabOrder = 1
  end
end
