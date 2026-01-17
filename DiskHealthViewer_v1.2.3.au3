#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=DiskHealthViewer.ico
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Comment=Portable disk SMART viewer (smartctl + python)
#AutoIt3Wrapper_Res_Description=Disk Health Viewer
#AutoIt3Wrapper_Res_Fileversion=1.2.3.0
#AutoIt3Wrapper_Res_ProductName=Disk Health Viewer
#AutoIt3Wrapper_Res_ProductVersion=1.2.3.0
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****


#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <GuiListView.au3>
#include <ListViewConstants.au3>
#include <StaticConstants.au3>
#include <ButtonConstants.au3>
#include <MsgBoxConstants.au3>
#include <FileConstants.au3>
#include <EditConstants.au3>
#include <WinAPI.au3>

Global Const $APP_TITLE = "Disk Health Viewer"
Global Const $APP_VERSION = "1.2.3"
Global Const $TOOLS_DIR = @ScriptDir & "\tools"
Global Const $SMARTCTL  = $TOOLS_DIR & "\smartctl.exe"
Global Const $PY_HELPER = $TOOLS_DIR & "\smartread.py"
Global Const $PY_EMBED  = $TOOLS_DIR & "\python\python.exe"
Global Const $HELPER_EXE = $TOOLS_DIR & "\smartread.exe"

; ----- Controls (we store IDs so we can reposition them) -----
Global $hGUI
Global $lblDisksTitle, $lvDisks, $hLVDisks
Global $btnRefresh, $btnLoad, $btnCopy, $btnExportTxt, $btnExportHtml, $btnAbout

Global $grpOverview, $lblModelCap, $lblSerialCap, $lblDeviceCap, $lblSmartCap, $lblTempCap, $lblPOHCap, $lblProtoCap, $lblSmartctlCap
Global $lblModel, $lblSerial, $lblDevice, $lblHealth, $lblTemp, $lblPOH, $lblProto, $lblSmartctl

Global $grpSummary, $lblOverallCap, $lblOverall, $lblWarningsCap, $editWarnings

Global $lblItemsTitle, $lvItems, $hLVItems

; ----- State -----
Global $gLastRaw = ""
Global $gSelectedIndex = -1

Global $gOvModel = "-", $gOvSerial = "-", $gOvDevice = "-", $gOvHealth = "-", $gOvTemp = "-", $gOvPOH = "-", $gOvProto = "-", $gOvSmartctl = "-"
Global $gOverall = "UNKNOWN"
Global $gWarnings = ""
Global $gItems[1][7]

_Main()

Func _Main()
    $hGUI = GUICreate($APP_TITLE, 1020, 720, -1, -1, BitOR($WS_MINIMIZEBOX, $WS_MAXIMIZEBOX, $WS_SYSMENU, $WS_CAPTION, $WS_SIZEBOX))

    ; Left: disks
    $lblDisksTitle = GUICtrlCreateLabel("Disks (click to select, double-click to load)", 10, 10, 420, 20)
    $lvDisks = GUICtrlCreateListView("Index|Model|Size (GB)|Interface|Device", 10, 35, 550, 250, BitOR($LVS_REPORT, $LVS_SINGLESEL, $LVS_SHOWSELALWAYS))
    $hLVDisks = GUICtrlGetHandle($lvDisks)
    _GUICtrlListView_SetExtendedListViewStyle($hLVDisks, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_DOUBLEBUFFER))

    ; Buttons row (will be laid out)
    $btnRefresh    = GUICtrlCreateButton("Refresh", 10, 295, 110, 32)
    $btnLoad       = GUICtrlCreateButton("Load SMART", 130, 295, 120, 32)
    $btnCopy       = GUICtrlCreateButton("Copy Report", 260, 295, 120, 32)
    $btnExportTxt  = GUICtrlCreateButton("Export TXT", 390, 295, 110, 32)
    $btnExportHtml = GUICtrlCreateButton("Export HTML", 510, 295, 110, 32)
    $btnAbout      = GUICtrlCreateButton("About", 630, 295, 90, 32)

    ; Right: Overview group
    $grpOverview = GUICtrlCreateGroup("Overview", 575, 10, 430, 220)

    $lblModelCap   = GUICtrlCreateLabel("Model:", 590, 35, 70, 18)
    $lblModel      = GUICtrlCreateLabel("-", 665, 35, 330, 18)

    $lblSerialCap  = GUICtrlCreateLabel("Serial:", 590, 60, 70, 18)
    $lblSerial     = GUICtrlCreateLabel("-", 665, 60, 330, 18)

    $lblDeviceCap  = GUICtrlCreateLabel("Device:", 590, 85, 70, 18)
    $lblDevice     = GUICtrlCreateLabel("-", 665, 85, 330, 18)

    $lblSmartCap   = GUICtrlCreateLabel("SMART:", 590, 110, 70, 18)
    $lblHealth     = GUICtrlCreateLabel("-", 665, 110, 330, 18)

    $lblTempCap    = GUICtrlCreateLabel("Temp:", 590, 135, 70, 18)
    $lblTemp       = GUICtrlCreateLabel("-", 665, 135, 330, 18)

    $lblPOHCap     = GUICtrlCreateLabel("POH:", 590, 160, 70, 18)
    $lblPOH        = GUICtrlCreateLabel("-", 665, 160, 330, 18)

    $lblProtoCap   = GUICtrlCreateLabel("Protocol:", 590, 185, 70, 18)
    $lblProto      = GUICtrlCreateLabel("-", 665, 185, 330, 18)

    $lblSmartctlCap = GUICtrlCreateLabel("smartctl:", 590, 205, 70, 18)
    $lblSmartctl    = GUICtrlCreateLabel("-", 665, 205, 330, 18)

    GUICtrlCreateGroup("", -99, -99, 1, 1)

    ; Right: Summary group
    $grpSummary = GUICtrlCreateGroup("Health Summary", 575, 240, 430, 210)
    $lblOverallCap = GUICtrlCreateLabel("Overall:", 590, 265, 70, 18)
    $lblOverall    = GUICtrlCreateLabel("UNKNOWN", 665, 265, 330, 18)

    $lblWarningsCap = GUICtrlCreateLabel("Warnings:", 590, 292, 70, 18)
    $editWarnings   = GUICtrlCreateEdit("", 590, 315, 405, 120, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL))
    GUICtrlSetData($editWarnings, "Load a disk to see warnings.")
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    ; Items
    $lblItemsTitle = GUICtrlCreateLabel("SMART Items (auto-sorted: BAD → WARNING → OK → UNKNOWN)", 10, 345, 650, 18)
    $lvItems = GUICtrlCreateListView("ID|Name|Value|Worst|Thresh|Severity|Raw", 10, 370, 995, 320, BitOR($LVS_REPORT, $LVS_SHOWSELALWAYS))
    $hLVItems = GUICtrlGetHandle($lvItems)
    _GUICtrlListView_SetExtendedListViewStyle($hLVItems, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_DOUBLEBUFFER))

    GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")
    GUIRegisterMsg($WM_SIZE, "WM_SIZE")

    GUISetState(@SW_SHOWMAXIMIZED)

    _Layout()
    _InitListColumns()
    _RefreshDiskList()

    While 1
        Switch GUIGetMsg()
            Case $GUI_EVENT_CLOSE
                Exit
            Case $btnRefresh
                _RefreshDiskList()
            Case $btnLoad
                _LoadByRememberedIndex()
            Case $btnCopy
                _CopyReportToClipboard()
            Case $btnExportTxt
                _ExportRawTxt()
            Case $btnExportHtml
                _ExportHtml()
            Case $btnAbout
                _ShowAbout()
        EndSwitch
    WEnd
EndFunc

Func _InitListColumns()
    _GUICtrlListView_SetColumnWidth($hLVDisks, 0, 50)
    _GUICtrlListView_SetColumnWidth($hLVDisks, 1, 270)
    _GUICtrlListView_SetColumnWidth($hLVDisks, 2, 80)
    _GUICtrlListView_SetColumnWidth($hLVDisks, 3, 80)
    _GUICtrlListView_SetColumnWidth($hLVDisks, 4, 160)

    _GUICtrlListView_SetColumnWidth($hLVItems, 0, 55)
    _GUICtrlListView_SetColumnWidth($hLVItems, 1, 300)
    _GUICtrlListView_SetColumnWidth($hLVItems, 2, 120)
    _GUICtrlListView_SetColumnWidth($hLVItems, 3, 70)
    _GUICtrlListView_SetColumnWidth($hLVItems, 4, 70)
    _GUICtrlListView_SetColumnWidth($hLVItems, 5, 90)
    _GUICtrlListView_SetColumnWidth($hLVItems, 6, 270)
EndFunc

Func WM_SIZE($hWnd, $iMsg, $wParam, $lParam)
    _Layout()
    Return $GUI_RUNDEFMSG
EndFunc

Func _Layout()
    Local $cs = WinGetClientSize($hGUI)
    If Not IsArray($cs) Then Return

    Local $w = $cs[0]
    Local $h = $cs[1]

    Local Const $m = 10
    Local Const $gap = 10
    Local Const $titleH = 20
    Local Const $btnH = 32

    ; --- right/left widths ---
    Local $rightW = 430
    If $w < 1200 Then $rightW = 400
    If $w < 1100 Then $rightW = 380
    If $w < 1000 Then $rightW = 360
    If $w < 900 Then $rightW = 340

    Local $leftW = $w - ($m * 3) - $rightW
    If $leftW < 520 Then
        $leftW = 520
        $rightW = $w - ($m * 3) - $leftW
        If $rightW < 320 Then $rightW = 320
    EndIf

    ; --- top area height ---
    ; Give more room on short screens (e.g. 720p) so Overview doesn't get squashed.
    Local $topH = Int($h * 0.46)
    If $topH < 260 Then $topH = 260
    If $topH > 360 Then $topH = 360

    Local $leftX = $m
    Local $rightX = $leftX + $leftW + $gap
    Local $topY = $m

    ; Disks title + list
    GUICtrlSetPos($lblDisksTitle, $leftX, $topY, $leftW, $titleH)
    GUICtrlSetPos($lvDisks, $leftX, $topY + $titleH + 5, $leftW, $topH - ($titleH + 5))

    ; Split top-right into Overview + Summary
    Local $ovH = Int($topH * 0.62)
    If $ovH < 220 Then $ovH = 220
    If $ovH > ($topH - 140) Then $ovH = $topH - 140 ; ensure Summary has at least 140px
    Local $sumH = $topH - $ovH - $gap
    If $sumH < 140 Then
        $sumH = 140
        $ovH = $topH - $sumH - $gap
        If $ovH < 200 Then $ovH = 200
    EndIf

    ; Overview group
    GUICtrlSetPos($grpOverview, $rightX, $topY, $rightW, $ovH)

    ; Layout overview lines dynamically so they never spill out
    Local $capX = $rightX + 15
    Local $valX = $rightX + 90
    Local $valW = $rightW - 105
    Local $baseY = $topY + 25

    ; We have 8 lines: model/serial/device/smart/temp/poh/proto/smartctl
    Local $lines = 8
    Local $usable = $ovH - 55 ; keep some bottom padding
    Local $lineGap = Int($usable / $lines)
    If $lineGap < 18 Then $lineGap = 18
    If $lineGap > 26 Then $lineGap = 26

    _SetPosPair($lblModelCap, $lblModel, $capX, $valX, $baseY + ($lineGap * 0), $valW)
    _SetPosPair($lblSerialCap, $lblSerial, $capX, $valX, $baseY + ($lineGap * 1), $valW)
    _SetPosPair($lblDeviceCap, $lblDevice, $capX, $valX, $baseY + ($lineGap * 2), $valW)
    _SetPosPair($lblSmartCap, $lblHealth, $capX, $valX, $baseY + ($lineGap * 3), $valW)
    _SetPosPair($lblTempCap, $lblTemp, $capX, $valX, $baseY + ($lineGap * 4), $valW)
    _SetPosPair($lblPOHCap, $lblPOH, $capX, $valX, $baseY + ($lineGap * 5), $valW)
    _SetPosPair($lblProtoCap, $lblProto, $capX, $valX, $baseY + ($lineGap * 6), $valW)
    _SetPosPair($lblSmartctlCap, $lblSmartctl, $capX, $valX, $baseY + ($lineGap * 7), $valW)

    ; Summary group
    Local $sumY = $topY + $ovH + $gap
    GUICtrlSetPos($grpSummary, $rightX, $sumY, $rightW, $sumH)

    GUICtrlSetPos($lblOverallCap, $capX, $sumY + 25, 70, 18)
    GUICtrlSetPos($lblOverall, $valX, $sumY + 25, $valW, 18)
    GUICtrlSetPos($lblWarningsCap, $capX, $sumY + 50, 70, 18)

    Local $editY = $sumY + 72
    Local $editH = $sumH - 85
    If $editH < 60 Then $editH = 60
    GUICtrlSetPos($editWarnings, $capX, $editY, $rightW - 30, $editH)

    ; Buttons row
    Local $btnY = $topY + $topH + $gap
    GUICtrlSetPos($btnRefresh, $leftX, $btnY, 110, $btnH)
    GUICtrlSetPos($btnLoad, $leftX + 120, $btnY, 120, $btnH)
    GUICtrlSetPos($btnCopy, $leftX + 250, $btnY, 120, $btnH)
    GUICtrlSetPos($btnExportTxt, $leftX + 380, $btnY, 110, $btnH)
    GUICtrlSetPos($btnExportHtml, $leftX + 500, $btnY, 110, $btnH)
    GUICtrlSetPos($btnAbout, $leftX + 620, $btnY, 90, $btnH)

    ; Items title + list
    Local $itemsY = $btnY + $btnH + $gap
    GUICtrlSetPos($lblItemsTitle, $leftX, $itemsY, $w - 2*$m, $titleH)

    Local $lvY = $itemsY + $titleH + 5
    Local $lvH = $h - $lvY - $m
    If $lvH < 140 Then $lvH = 140

    GUICtrlSetPos($lvItems, $leftX, $lvY, $w - 2*$m, $lvH)

    _AdjustItemsColumns($w - 2*$m)
EndFunc

Func _SetPosPair($capId, $valId, $capX, $valX, $y, $valW)
    GUICtrlSetPos($capId, $capX, $y, 70, 18)
    GUICtrlSetPos($valId, $valX, $y, $valW, 18)
EndFunc

Func _AdjustItemsColumns($listW)
    Local $fixed = 55 + 300 + 120 + 70 + 70 + 90
    Local $rawW = $listW - $fixed - 35
    If $rawW < 180 Then $rawW = 180
    _GUICtrlListView_SetColumnWidth($hLVItems, 6, $rawW)
EndFunc

Func WM_NOTIFY($hWnd, $iMsg, $wParam, $lParam)
    Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
    Local $hFrom = DllStructGetData($tNMHDR, "hWndFrom")
    Local $code = DllStructGetData($tNMHDR, "Code")

    If $hFrom = $hLVDisks Then
        Switch $code
            Case $NM_CLICK
                Local $tAct = DllStructCreate($tagNMITEMACTIVATE, $lParam)
                Local $iItem = DllStructGetData($tAct, "Index")
                If $iItem >= 0 Then _SelectDiskRow($iItem)
                Return 0
            Case $NM_DBLCLK
                Local $tAct2 = DllStructCreate($tagNMITEMACTIVATE, $lParam)
                Local $iItem2 = DllStructGetData($tAct2, "Index")
                If $iItem2 >= 0 Then
                    _SelectDiskRow($iItem2)
                    _LoadDiskSmartByIndex($iItem2)
                EndIf
                Return 0
        EndSwitch
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

Func _SelectDiskRow($iItem)
    $gSelectedIndex = $iItem
    Local $count = _GUICtrlListView_GetItemCount($hLVDisks)
    For $i = 0 To $count - 1
        _GUICtrlListView_SetItemSelected($hLVDisks, $i, False)
    Next
    _GUICtrlListView_SetItemSelected($hLVDisks, $iItem, True, True)
    _GUICtrlListView_SetSelectionMark($hLVDisks, $iItem)
EndFunc

Func _LoadByRememberedIndex()
    If $gSelectedIndex < 0 Then
        MsgBox($MB_ICONINFORMATION, $APP_TITLE, "No disk selected. Click a disk row first (or double-click it).")
        Return
    EndIf
    _LoadDiskSmartByIndex($gSelectedIndex)
EndFunc

Func _RefreshDiskList()
    _GUICtrlListView_DeleteAllItems($hLVDisks)
    _GUICtrlListView_DeleteAllItems($hLVItems)
    _ResetUI()

    Local $oWMI = ObjGet("winmgmts:\\.\root\cimv2")
    If @error Or Not IsObj($oWMI) Then
        MsgBox($MB_ICONERROR, $APP_TITLE, "Failed to access WMI.")
        Return
    EndIf

    Local $col = $oWMI.ExecQuery("SELECT Index, Model, Size, InterfaceType, DeviceID FROM Win32_DiskDrive")
    If Not IsObj($col) Then Return

    For $d In $col
        Local $idx = $d.Index
        Local $model = _SafeStr($d.Model)
        Local $iface = _SafeStr($d.InterfaceType)
        Local $dev = _SafeStr($d.DeviceID)

        Local $sizeGB = "-"
        If $d.Size <> "" Then
            $sizeGB = Round(Number($d.Size) / 1024 / 1024 / 1024, 1)
        EndIf

        GUICtrlCreateListViewItem($idx & "|" & $model & "|" & $sizeGB & "|" & $iface & "|" & $dev, $lvDisks)
    Next
EndFunc

Func _ResetUI()
    $gLastRaw = ""
    $gSelectedIndex = -1
    $gOverall = "UNKNOWN"
    $gWarnings = ""
    Dim $gItems[1][7]
    _SetOverview("-", "-", "-", "-", "-", "-", "-", "-")
    _SetSummary("UNKNOWN", "Load a disk to see warnings.")
EndFunc

Func _LoadDiskSmartByIndex($iIndex)
    Local $dev = _GUICtrlListView_GetItemText($hLVDisks, $iIndex, 4)
    If $dev = "" Then
        MsgBox($MB_ICONWARNING, $APP_TITLE, "Could not read device path from the list.")
        Return
    EndIf

    _GUICtrlListView_DeleteAllItems($hLVItems)
    _ResetUI()
    _SetOverview("-", "-", $dev, "-", "-", "-", "-", "-")

    Local $cmd = _BuildHelperCommand($dev)
    If $cmd = "" Then Return

    Local $out = _RunCapture($cmd, $TOOLS_DIR)
    $gLastRaw = $out

    If StringStripWS($out, 8) = "" Then
        MsgBox($MB_ICONWARNING, $APP_TITLE, "No output. Check tools\smartctl.exe and helper files.")
        Return
    EndIf

    _ParseAndDisplay($out)
EndFunc

Func _BuildHelperCommand($deviceId)
    If Not FileExists($SMARTCTL) Then
        MsgBox($MB_ICONERROR, $APP_TITLE, "Missing: " & $SMARTCTL)
        Return ""
    EndIf

    If FileExists($HELPER_EXE) Then
        Return '"' & $HELPER_EXE & '"' & " --device " & '"' & $deviceId & '"' & " --smartctl " & '"' & $SMARTCTL & '"'
    EndIf

    If Not FileExists($PY_HELPER) Then
        MsgBox($MB_ICONERROR, $APP_TITLE, "Missing: " & $PY_HELPER)
        Return ""
    EndIf

    Local $python = ""
    If FileExists($PY_EMBED) Then
        $python = '"' & $PY_EMBED & '"'
    Else
        $python = "python"
    EndIf

    Return $python & " " & '"' & $PY_HELPER & '"' & " --device " & '"' & $deviceId & '"' & " --smartctl " & '"' & $SMARTCTL & '"'
EndFunc

Func _RunCapture($cmd, $workdir)
    Local $pid = Run($cmd, $workdir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
    If $pid = 0 Then Return ""

    Local $buf = ""
    Local $t0 = TimerInit()

    While 1
        $buf &= StdoutRead($pid)
        $buf &= StderrRead($pid)
        If Not ProcessExists($pid) Then ExitLoop
        If TimerDiff($t0) > 25000 Then
            ProcessClose($pid)
            ExitLoop
        EndIf
        Sleep(40)
    WEnd

    Return $buf
EndFunc

Func _ParseAndDisplay($text)
    Local $lines = StringSplit(StringReplace($text, @CRLF, @LF), @LF, 1)
    If $lines[0] = 0 Then Return

    Local $section = ""
    Local $model = "-", $serial = "-", $device = "-", $health = "-", $temp = "-", $poh = "-", $proto = "-", $smartctl = "-"
    Local $overall = "UNKNOWN"
    Local $warnings = ""

    Dim $items[1][7]
    Local $n = 0

    For $i = 1 To $lines[0]
        Local $ln = StringStripWS($lines[$i], 3)
        If $ln = "" Then ContinueLoop
        If StringLeft($ln, 1) = "#" Then ContinueLoop

        If $ln = "OVERVIEW" Or $ln = "SUMMARY" Or $ln = "ITEMS" Then
            $section = $ln
            ContinueLoop
        EndIf

        Switch $section
            Case "OVERVIEW"
                Local $eq = StringInStr($ln, "=")
                If $eq > 1 Then
                    Local $k = StringLower(StringLeft($ln, $eq - 1))
                    Local $v = StringMid($ln, $eq + 1)
                    Switch $k
                        Case "model"
                            $model = $v
                        Case "serial"
                            $serial = $v
                        Case "device"
                            $device = $v
                        Case "health"
                            $health = $v
                        Case "temperature_c"
                            $temp = $v
                        Case "power_on_hours"
                            $poh = $v
                        Case "protocol"
                            $proto = $v
                        Case "smartctl_dev"
                            $smartctl = "dev=" & $v
                        Case "smartctl_devtype"
                            If $smartctl = "-" Then
                                $smartctl = "type=" & $v
                            Else
                                $smartctl &= "  type=" & $v
                            EndIf
                    EndSwitch
                EndIf

            Case "SUMMARY"
                Local $eq2 = StringInStr($ln, "=")
                If $eq2 > 1 Then
                    Local $k2 = StringLower(StringLeft($ln, $eq2 - 1))
                    Local $v2 = StringMid($ln, $eq2 + 1)
                    Switch $k2
                        Case "overall"
                            $overall = $v2
                        Case "warnings"
                            $warnings = $v2
                    EndSwitch
                EndIf

            Case "ITEMS"
                If StringLeft($ln, 2) = "id" Then ContinueLoop
                If Not StringInStr($ln, "|") Then ContinueLoop
                Local $p = StringSplit($ln, "|", 1)
                If $p[0] < 7 Then ContinueLoop

                $n += 1
                ReDim $items[$n + 1][7]
                For $c = 0 To 6
                    $items[$n][$c] = $p[$c + 1]
                Next
        EndSwitch
    Next

    $gOvModel = $model
    $gOvSerial = $serial
    $gOvDevice = $device
    $gOvHealth = $health
    $gOvTemp = $temp
    $gOvPOH = $poh
    $gOvProto = $proto
    $gOvSmartctl = $smartctl
    $gOverall = $overall
    $gWarnings = $warnings
    $gItems = $items

    _SetOverview($model, $serial, $device, $health, $temp, $poh, $proto, $smartctl)
    _SetSummary($overall, _WarningsToMultiline($warnings))
    _ColorOverall($overall)

    _GUICtrlListView_DeleteAllItems($hLVItems)
    For $r = 1 To $n
        GUICtrlCreateListViewItem($items[$r][0] & "|" & $items[$r][1] & "|" & $items[$r][2] & "|" & $items[$r][3] & "|" & $items[$r][4] & "|" & $items[$r][5] & "|" & $items[$r][6], $lvItems)
    Next
EndFunc

Func _WarningsToMultiline($w)
    If StringStripWS($w, 8) = "" Then Return "No warnings."
    Return StringReplace($w, "; ", @CRLF)
EndFunc

Func _ColorOverall($overall)
    Local $o = StringUpper(StringStripWS($overall, 3))
    Switch $o
        Case "OK"
            GUICtrlSetColor($lblOverall, 0x006400)
        Case "WARNING"
            GUICtrlSetColor($lblOverall, 0xB36B00)
        Case "BAD"
            GUICtrlSetColor($lblOverall, 0x8B0000)
        Case Else
            GUICtrlSetColor($lblOverall, 0x000000)
    EndSwitch
EndFunc

Func _SetOverview($model, $serial, $device, $health, $temp, $poh, $proto, $smartctl)
    GUICtrlSetData($lblModel, $model)
    GUICtrlSetData($lblSerial, $serial)
    GUICtrlSetData($lblDevice, $device)
    GUICtrlSetData($lblHealth, $health)
    GUICtrlSetData($lblTemp, $temp)
    GUICtrlSetData($lblPOH, $poh)
    GUICtrlSetData($lblProto, $proto)
    GUICtrlSetData($lblSmartctl, $smartctl)
EndFunc

Func _SetSummary($overall, $warningsText)
    GUICtrlSetData($lblOverall, $overall)
    GUICtrlSetData($editWarnings, $warningsText)
EndFunc

Func _CopyReportToClipboard()
    If StringStripWS($gLastRaw, 8) = "" Then
        MsgBox($MB_ICONINFORMATION, $APP_TITLE, "Nothing to copy yet. Load SMART first.")
        Return
    EndIf

    Local $txt = ""
    $txt &= "Disk SMART Report" & @CRLF
    $txt &= "Generated: " & @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & " " & StringFormat("%02d", @HOUR) & ":" & StringFormat("%02d", @MIN) & @CRLF & @CRLF

    $txt &= "Overview" & @CRLF
    $txt &= "Model: " & $gOvModel & @CRLF
    $txt &= "Serial: " & $gOvSerial & @CRLF
    $txt &= "Device: " & $gOvDevice & @CRLF
    $txt &= "SMART: " & $gOvHealth & @CRLF
    $txt &= "Temp: " & $gOvTemp & @CRLF
    $txt &= "Power-on Hours: " & $gOvPOH & @CRLF
    $txt &= "Protocol: " & $gOvProto & @CRLF
    $txt &= "smartctl: " & $gOvSmartctl & @CRLF & @CRLF

    $txt &= "Health Summary" & @CRLF
    $txt &= "Overall: " & $gOverall & @CRLF
    If StringStripWS($gWarnings, 8) = "" Then
        $txt &= "Warnings: (none)" & @CRLF
    Else
        $txt &= "Warnings:" & @CRLF & " - " & StringReplace($gWarnings, "; ", @CRLF & " - ") & @CRLF
    EndIf
    $txt &= @CRLF

    $txt &= "Items" & @CRLF
    $txt &= "ID" & @TAB & "Name" & @TAB & "Value" & @TAB & "Worst" & @TAB & "Thresh" & @TAB & "Severity" & @TAB & "Raw" & @CRLF

    Local $rmax = UBound($gItems) - 1
    For $i = 1 To $rmax
        $txt &= $gItems[$i][0] & @TAB & $gItems[$i][1] & @TAB & $gItems[$i][2] & @TAB & $gItems[$i][3] & @TAB & $gItems[$i][4] & @TAB & $gItems[$i][5] & @TAB & $gItems[$i][6] & @CRLF
    Next

    ClipPut($txt)
    MsgBox($MB_ICONINFORMATION, $APP_TITLE, "Copied report to clipboard.")
EndFunc

Func _ExportRawTxt()
    If StringStripWS($gLastRaw, 8) = "" Then
        MsgBox($MB_ICONINFORMATION, $APP_TITLE, "Nothing to export yet. Load SMART first.")
        Return
    EndIf

    Local $path = FileSaveDialog("Save TXT report as", @ScriptDir, "Text (*.txt)", 2, "disk_smart_report.txt")
    If @error Then Return
    If FileExists($path) Then
        If MsgBox(BitOR($MB_ICONQUESTION, $MB_YESNO), $APP_TITLE, "File exists. Overwrite?") <> $IDYES Then Return
    EndIf

    Local $h = FileOpen($path, $FO_OVERWRITE + $FO_CREATEPATH)
    If $h = -1 Then
        MsgBox($MB_ICONERROR, $APP_TITLE, "Failed to write file.")
        Return
    EndIf
    FileWrite($h, $gLastRaw)
    FileClose($h)
    MsgBox($MB_ICONINFORMATION, $APP_TITLE, "Saved: " & $path)
EndFunc

Func _ExportHtml()
    If StringStripWS($gLastRaw, 8) = "" Then
        MsgBox($MB_ICONINFORMATION, $APP_TITLE, "Nothing to export yet. Load SMART first.")
        Return
    EndIf

    Local $path = FileSaveDialog("Save HTML report as", @ScriptDir, "HTML (*.html)", 2, "disk_smart_report.html")
    If @error Then Return
    If FileExists($path) Then
        If MsgBox(BitOR($MB_ICONQUESTION, $MB_YESNO), $APP_TITLE, "File exists. Overwrite?") <> $IDYES Then Return
    EndIf

    Local $html = _BuildHtmlReport()
    Local $h = FileOpen($path, $FO_OVERWRITE + $FO_CREATEPATH)
    If $h = -1 Then
        MsgBox($MB_ICONERROR, $APP_TITLE, "Failed to write file.")
        Return
    EndIf
    FileWrite($h, $html)
    FileClose($h)
    MsgBox($MB_ICONINFORMATION, $APP_TITLE, "Saved: " & $path)
EndFunc

Func _HtmlEscape($s)
    $s = StringReplace($s, "&", "&amp;")
    $s = StringReplace($s, "<", "&lt;")
    $s = StringReplace($s, ">", "&gt;")
    $s = StringReplace($s, '"', "&quot;")
    Return $s
EndFunc

Func _BuildHtmlReport()
    Local $title = "Disk SMART Report"
    Local $now = @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & " " & StringFormat("%02d", @HOUR) & ":" & StringFormat("%02d", @MIN)

    Local $ov = "<table class='kv'>" & _
        "<tr><th>Model</th><td>" & _HtmlEscape($gOvModel) & "</td></tr>" & _
        "<tr><th>Serial</th><td>" & _HtmlEscape($gOvSerial) & "</td></tr>" & _
        "<tr><th>Device</th><td>" & _HtmlEscape($gOvDevice) & "</td></tr>" & _
        "<tr><th>SMART</th><td>" & _HtmlEscape($gOvHealth) & "</td></tr>" & _
        "<tr><th>Temp</th><td>" & _HtmlEscape($gOvTemp) & "</td></tr>" & _
        "<tr><th>Power-on Hours</th><td>" & _HtmlEscape($gOvPOH) & "</td></tr>" & _
        "<tr><th>Protocol</th><td>" & _HtmlEscape($gOvProto) & "</td></tr>" & _
        "<tr><th>smartctl</th><td>" & _HtmlEscape($gOvSmartctl) & "</td></tr>" & _
        "</table>"

    Local $badgeClass = StringLower(StringStripWS($gOverall, 3))
    If $badgeClass <> "ok" And $badgeClass <> "warning" And $badgeClass <> "bad" Then $badgeClass = "unknown"

    Local $warnBlock = ""
    If StringStripWS($gWarnings, 8) = "" Then
        $warnBlock = "<div class='warn none'>No warnings.</div>"
    Else
        Local $w = _HtmlEscape(StringReplace($gWarnings, "; ", "<br>"))
        $warnBlock = "<div class='warn'>" & $w & "</div>"
    EndIf

    Local $rows = ""
    Local $rmax = UBound($gItems) - 1
    For $i = 1 To $rmax
        Local $id = _HtmlEscape($gItems[$i][0])
        Local $name = _HtmlEscape($gItems[$i][1])
        Local $val = _HtmlEscape($gItems[$i][2])
        Local $worst = _HtmlEscape($gItems[$i][3])
        Local $th = _HtmlEscape($gItems[$i][4])
        Local $sev = _HtmlEscape($gItems[$i][5])
        Local $raw = _HtmlEscape($gItems[$i][6])
        Local $sevClass = StringLower(StringStripWS($gItems[$i][5], 3))
        $rows &= "<tr class='sev-" & $sevClass & "'><td>" & $id & "</td><td>" & $name & "</td><td>" & $val & "</td><td>" & $worst & "</td><td>" & $th & "</td><td>" & $sev & "</td><td class='raw'>" & $raw & "</td></tr>"
    Next

    Local $tbl = "<table class='items'><thead><tr><th>ID</th><th>Name</th><th>Value</th><th>Worst</th><th>Thresh</th><th>Severity</th><th>Raw</th></tr></thead><tbody>" & $rows & "</tbody></table>"

    Local $css = "<style>" & _
        "body{font-family:Segoe UI,Arial,sans-serif;background:#0b0f14;color:#e6edf3;margin:20px;}" & _
        "h1{margin:0 0 8px 0;font-size:20px;}" & _
        ".meta{color:#9aa7b2;margin-bottom:16px;}" & _
        ".grid{display:grid;grid-template-columns:1fr 1fr;gap:16px;}" & _
        ".card{background:#111826;border:1px solid #1f2a3a;border-radius:10px;padding:14px;}" & _
        ".kv{width:100%;border-collapse:collapse;}" & _
        ".kv th{color:#9aa7b2;text-align:left;width:140px;padding:6px 8px;border-bottom:1px solid #1f2a3a;}" & _
        ".kv td{padding:6px 8px;border-bottom:1px solid #1f2a3a;}" & _
        ".badge{display:inline-block;padding:4px 10px;border-radius:999px;font-weight:700;}" & _
        ".badge.ok{background:#123a1d;color:#b8f7c3;}" & _
        ".badge.warning{background:#3a2a12;color:#ffd08a;}" & _
        ".badge.bad{background:#3a1212;color:#ff9c9c;}" & _
        ".badge.unknown{background:#1b2432;color:#cbd5e1;}" & _
        ".warn{margin-top:10px;line-height:1.4;color:#ffd08a;}" & _
        ".warn.none{color:#b8f7c3;}" & _
        ".items{width:100%;border-collapse:collapse;margin-top:14px;font-size:13px;}" & _
        ".items th,.items td{border-bottom:1px solid #1f2a3a;padding:8px;vertical-align:top;}" & _
        ".items th{color:#9aa7b2;text-align:left;}" & _
        ".sev-bad td{background:rgba(255,0,0,0.06);}" & _
        ".sev-warning td{background:rgba(255,165,0,0.06);}" & _
        ".sev-ok td{background:rgba(0,255,0,0.04);}" & _
        ".raw{word-break:break-word;}" & _
        "</style>"

    Return "<!doctype html><html><head><meta charset='utf-8'><title>" & $title & "</title>" & $css & "</head><body>" & _
        "<h1>" & $title & "</h1><div class='meta'>Generated: " & $now & "</div>" & _
        "<div class='grid'><div class='card'><h2 style='margin:0 0 10px 0;font-size:16px;'>Overview</h2>" & $ov & "</div>" & _
        "<div class='card'><h2 style='margin:0 0 10px 0;font-size:16px;'>Health Summary</h2><div class='badge " & $badgeClass & "'>" & _HtmlEscape($gOverall) & "</div>" & $warnBlock & "</div></div>" & _
        "<div class='card' style='margin-top:16px;'><h2 style='margin:0 0 10px 0;font-size:16px;'>SMART Items</h2>" & $tbl & "</div>" & _
        "</body></html>"
EndFunc



Func _ShowAbout()
    Local Const $GITHUB_URL = "https://github.com/Gexos"
    Local Const $BLOG_URL = "https://gexos.org"

    Local $hAbout = GUICreate("About - Disk Health Viewer", 460, 290, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU), -1, $hGUI)

    GUICtrlCreateLabel("Disk Health Viewer", 18, 16, 420, 22)
    GUICtrlSetFont(-1, 12, 800)

    GUICtrlCreateLabel("Version: " & $APP_VERSION, 18, 46, 420, 18)

    GUICtrlCreateLabel("Open-source utility built by Giorgos Xanthopoulos", 18, 74, 420, 18)
    GUICtrlCreateLabel("(aka gexos).", 18, 94, 420, 18)

    GUICtrlCreateLabel("Links:", 18, 126, 60, 18)

    Local $btnGitHub = GUICtrlCreateButton("GitHub", 78, 121, 90, 28)
    Local $btnBlog   = GUICtrlCreateButton("Blog (gexos.org)", 178, 121, 120, 28)
    Local $btnOK     = GUICtrlCreateButton("OK", 350, 250, 90, 32)

    GUICtrlCreateEdit("GitHub: " & $GITHUB_URL & @CRLF & "Blog:   " & $BLOG_URL, 18, 156, 422, 86, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL))

    GUISetState(@SW_SHOW, $hAbout)

    While 1
        Switch GUIGetMsg()
            Case $GUI_EVENT_CLOSE, $btnOK
                ExitLoop
            Case $btnGitHub
                ShellExecute($GITHUB_URL)
            Case $btnBlog
                ShellExecute($BLOG_URL)
        EndSwitch
        Sleep(10)
    WEnd

    GUIDelete($hAbout)
EndFunc

Func _SafeStr($v)
    If $v = "" Then Return "-"
    Return StringStripWS($v, 3)
EndFunc
