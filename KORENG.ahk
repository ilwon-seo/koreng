#Requires AutoHotkey v2.0
#SingleInstance Force

; ==========================================================
; 1. 기본 설정
; ==========================================================
;if not A_IsAdmin {
;    try {
;        Run '*RunAs "' A_ScriptFullPath '"'
;    }
;    ExitApp
;}

DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
CoordMode "Caret", "Screen"
CoordMode "Mouse", "Screen"

; ==========================================================
; GUI 위치 설정
; ==========================================================
; 아래 4가지 중 하나를 골라 GUI_OFFSET_X 값에 넣으면 됨.
; 현재의 우측:      GUI_OFFSET_X := 45
; 더 먼 우측:       GUI_OFFSET_X := 80
; 좌측:             GUI_OFFSET_X := -35
; 더 먼 좌측:       GUI_OFFSET_X := -70
;
; 세로 위치는 필요하면 GUI_OFFSET_Y 값만 조정하면 됨.
GUI_OFFSET_X := -200
GUI_OFFSET_Y := 25

; ==========================================================
; GUI 크기 / 글자 설정
; ==========================================================
; 표시 문자가 잘리면 GUI_BOX_W, GUI_BOX_H 값을 키우면 됨.
; 글자가 작으면 GUI_FONT_SIZE 값을 키우면 됨.
GUI_FONT_SIZE := 11
GUI_BOX_W := 36
GUI_BOX_H := 26

; ==========================================================
; 2. 쌍둥이 GUI 생성 (2개 만듦)
; ==========================================================
; [1호기] 마우스 따라다니는 녀석
GuiMouse := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner +LastFound +E0x20")
GuiMouse.BackColor := "E0E0E0"
GuiMouse.SetFont("s" GUI_FONT_SIZE " w600", "맑은 고딕")
TxtMouse := GuiMouse.Add("Text", "w" GUI_BOX_W " h" GUI_BOX_H " Center cBlack", "A")
WinSetTransparent(220, GuiMouse.Hwnd)

; [2호기] 텍스트 커서(캐럿) 따라다니는 녀석
GuiCaret := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner +LastFound +E0x20")
GuiCaret.BackColor := "E0E0E0"
GuiCaret.SetFont("s" GUI_FONT_SIZE " w600", "맑은 고딕")
TxtCaret := GuiCaret.Add("Text", "w" GUI_BOX_W " h" GUI_BOX_H " Center cBlack", "A")
WinSetTransparent(220, GuiCaret.Hwnd)

; 타이머 실행 (0.05초)
SetTimer CheckIME, 50
return

; ==========================================================
; 3. 메인 로직 (상태 체크 및 표시)
; ==========================================================
CheckIME()
{
    global GUI_OFFSET_X, GUI_OFFSET_Y
    global GuiMouse, TxtMouse, GuiCaret, TxtCaret

    ; (1) IME 상태 확인
    isHangul := IsHangulMode()

    ; (2) 두 GUI의 색상과 텍스트를 모두 업데이트
    UpdateGuiStyle(GuiMouse, TxtMouse, isHangul)
    UpdateGuiStyle(GuiCaret, TxtCaret, isHangul)

    ; (3) [1호기 위치] 마우스 옆으로 이동
    MouseGetPos(&mX, &mY)
    GuiMouse.Show("NoActivate x" (mX + GUI_OFFSET_X) " y" (mY + GUI_OFFSET_Y))

    ; (4) [2호기 위치] 텍스트 커서 옆으로 이동
    if CaretGetPos(&cX, &cY) {
        ; 커서를 찾았을 때만 표시
        GuiCaret.Show("NoActivate x" (cX + GUI_OFFSET_X) " y" (cY + GUI_OFFSET_Y))
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
            GuiObj.BackColor := "4488FF"
            TextObj.Value := "한"
            TextObj.SetFont("cWhite")
        }
    } else {
        if (GuiObj.BackColor != "FFB27D") {
            GuiObj.BackColor := "FFB27D"
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
