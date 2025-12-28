#Requires AutoHotkey v2.0
#SingleInstance Force

; ==========================================================
; 1. 기본 설정
; ==========================================================
if not A_IsAdmin {
    try {
        Run '*RunAs "' A_ScriptFullPath '"'
    }
    ExitApp
}

DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
CoordMode "Caret", "Screen"
CoordMode "Mouse", "Screen"

; ==========================================================
; 2. 쌍둥이 GUI 생성 (2개 만듦)
; ==========================================================
; [1호기] 마우스 따라다니는 녀석
GuiMouse := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner +LastFound +E0x20")
GuiMouse.BackColor := "E0E0E0"
GuiMouse.SetFont("s9 w600", "맑은 고딕")
TxtMouse := GuiMouse.Add("Text", "w24 h18 Center cBlack", "A")
WinSetTransparent(220, GuiMouse.Hwnd)

; [2호기] 텍스트 커서(캐럿) 따라다니는 녀석
GuiCaret := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner +LastFound +E0x20")
GuiCaret.BackColor := "E0E0E0"
GuiCaret.SetFont("s9 w600", "맑은 고딕")
TxtCaret := GuiCaret.Add("Text", "w24 h18 Center cBlack", "A")
WinSetTransparent(220, GuiCaret.Hwnd)

; 타이머 실행 (0.05초)
SetTimer CheckIME, 50
return

; ==========================================================
; 3. 메인 로직 (상태 체크 및 표시)
; ==========================================================
CheckIME()
{
    ; (1) IME 상태 확인
    isHangul := IsHangulMode()

    ; (2) 두 GUI의 색상과 텍스트를 모두 업데이트
    UpdateGuiStyle(GuiMouse, TxtMouse, isHangul)
    UpdateGuiStyle(GuiCaret, TxtCaret, isHangul)

    ; (3) [1호기 위치] 마우스 옆으로 이동
    MouseGetPos(&mX, &mY)
    ; [cite_start]사용자 선호 위치: X+45, Y+5 [cite: 10]
    GuiMouse.Show("NoActivate x" (mX + 45) " y" (mY + 5))

    ; (4) [2호기 위치] 텍스트 커서 옆으로 이동
    if CaretGetPos(&cX, &cY) {
        ; 커서를 찾았을 때만 표시
        GuiCaret.Show("NoActivate x" (cX + 45) " y" (cY + 5))
    } else {
        ; 커서 없으면(마우스만 쓰고 있으면) 숨김
        GuiCaret.Hide()
    }
}

; GUI 스타일(색상/글자)을 변경해주는 도우미 함수
UpdateGuiStyle(GuiObj, TextObj, isHangul)
{
    if (isHangul) {
        if (GuiObj.BackColor != "4488FF") {
            GuiObj.BackColor := "4488FF" ; [cite_start]파란색 [cite: 8]
            TextObj.Value := "한"
            TextObj.SetFont("cWhite")
        }
    } else {
        if (GuiObj.BackColor != "FFB27D") {
            GuiObj.BackColor := "FFB27D" ; [cite_start]주황색 [cite: 9]
            TextObj.Value := "A"
            TextObj.SetFont("cBlack")
        }
    }
}

; ==========================================================
; 4. 핵심 함수: 한글 모드인지 비트 검사 (Conversion Mode)
; ==========================================================
IsHangulMode()
{
    hWnd := GetFocusedHandle()
    if !hWnd
        hWnd := WinExist("A")

    if !hWnd
        return 0

    ; 방법 A: ImmGetConversionStatus
    hIMC := DllCall("imm32\ImmGetContext", "Ptr", hWnd, "Ptr")
    if (hIMC)
    {
        ConvMode := 0, SentMode := 0
        DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "UInt*", &ConvMode, "UInt*", &SentMode)
        DllCall("imm32\ImmReleaseContext", "Ptr", hWnd, "Ptr", hIMC)
        return (ConvMode & 0x1)
    }

    ; 방법 B: SendMessage (백업)
    DetectHiddenWindows True
    hDefaultIME := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hWnd, "Ptr")
    if (hDefaultIME)
    {
        ConvMode := SendMessage(0x283, 0x001, 0, , "ahk_id " hDefaultIME)
        DetectHiddenWindows False
        if (ConvMode != "")
            return (ConvMode & 0x1)
    }
    DetectHiddenWindows False

    return 0
}

GetFocusedHandle()
{
    hwndActive := WinExist("A")
    if !hwndActive
        return 0

    threadId := DllCall("GetWindowThreadProcessId", "Ptr", hwndActive, "Ptr", 0, "UInt")
    cbSize := A_PtrSize == 8 ? 72 : 48
    guiThreadInfo := Buffer(cbSize, 0)
    NumPut("UInt", cbSize, guiThreadInfo)

    if DllCall("GetGUIThreadInfo", "UInt", threadId, "Ptr", guiThreadInfo)
    {
        offset := A_PtrSize == 8 ? 16 : 12
        return NumGet(guiThreadInfo, offset, "Ptr")
    }
    return 0
}

+Esc::ExitApp