object frmDLUITestMain: TfrmDLUITestMain
  Left = 0
  Top = 0
  Caption = 'DelphiLens UI tester'
  ClientHeight = 497
  ClientWidth = 764
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    764
    497)
  PixelsPerInch = 96
  TextHeight = 13
  object lblProject: TLabel
    Left = 16
    Top = 19
    Width = 38
    Height = 13
    Caption = 'Project:'
    FocusControl = inpProject
  end
  object lblSearchPath: TLabel
    Left = 16
    Top = 50
    Width = 58
    Height = 13
    Caption = 'Search path'
    FocusControl = inpSearchPath
  end
  object lblDefines: TLabel
    Left = 16
    Top = 81
    Width = 95
    Height = 13
    Caption = 'Conditional defines:'
    FocusControl = inpDefines
  end
  object inpProject: TEdit
    Left = 117
    Top = 16
    Width = 551
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    ReadOnly = True
    TabOrder = 0
    OnChange = inpProjectChange
  end
  object btnSelect: TButton
    Left = 674
    Top = 14
    Width = 75
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'Select'
    TabOrder = 1
    OnClick = btnSelectClick
  end
  object inpSearchPath: TEdit
    Left = 117
    Top = 47
    Width = 632
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 2
    OnExit = SettingExit
  end
  object inpDefines: TEdit
    Left = 117
    Top = 78
    Width = 632
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 3
    OnExit = SettingExit
  end
  object btnRescan: TButton
    Left = 16
    Top = 113
    Width = 105
    Height = 25
    Caption = 'Rescan'
    TabOrder = 4
    OnClick = btnRescanClick
  end
  object outSource: TMemo
    Left = 160
    Top = 144
    Width = 589
    Height = 257
    Anchors = [akLeft, akTop, akRight, akBottom]
    ScrollBars = ssBoth
    TabOrder = 7
  end
  object lbFiles: TListBox
    Left = 16
    Top = 144
    Width = 138
    Height = 257
    Anchors = [akLeft, akTop, akBottom]
    ItemHeight = 13
    TabOrder = 5
    OnClick = lbFilesClick
  end
  object btnShowUI: TButton
    Left = 192
    Top = 113
    Width = 557
    Height = 25
    Anchors = [akLeft, akTop, akRight]
    Caption = 'Show UI'
    TabOrder = 6
    OnClick = btnShowUIClick
  end
  object lbLog: TListBox
    Left = 16
    Top = 407
    Width = 733
    Height = 74
    Anchors = [akLeft, akRight, akBottom]
    ItemHeight = 13
    TabOrder = 8
  end
  object Button1: TButton
    Left = 127
    Top = 113
    Width = 27
    Height = 25
    Caption = 'R'
    TabOrder = 9
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 160
    Top = 113
    Width = 26
    Height = 25
    Caption = 'S'
    TabOrder = 10
    OnClick = Button2Click
  end
  object dlgOpenProject: TFileOpenDialog
    DefaultExtension = '.dpr'
    FavoriteLinks = <>
    FileTypes = <
      item
        DisplayName = 'Delphi project'
        FileMask = '*.dpr'
      end
      item
        DisplayName = 'Delphi file'
        FileMask = '*.pas'
      end
      item
        DisplayName = 'DelphiLens cache'
        FileMask = '*.dlens'
      end
      item
        DisplayName = 'Any file'
        FileMask = '*.*'
      end>
    Options = []
    Left = 680
    Top = 160
  end
end
