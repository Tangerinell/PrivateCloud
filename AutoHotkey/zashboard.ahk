#Requires AutoHotkey v2.0

; ===== 请修改下面这几行 =====
browserEXE := "msedge.exe"  ;   浏览器程序
pwaTitleContains := "zashboard"                     ; ← 你的 PWA 标题独特部分
launchCommand := '"C:\Program Files (x86)\Microsoft\Edge\Application\msedge_proxy.exe"  --profile-directory=Default --app-id=pkaedgiedammpkafalfojdfkiclcnbke --app-url=http://127.0.0.1:7891/ui/ --app-launch-source=4'  ; ← 粘贴你快捷方式“目标”里的完整命令（去掉外层引号如果有）
; ==============================

Persistent
global lastHwnd := 0

!c:: {  ; ← Alt + V，可改
    global lastHwnd
    
    ; 优先用上次窗口 ID（最小化后超稳）
    if (lastHwnd && WinExist("ahk_id " lastHwnd)) {
        if WinActive("ahk_id " lastHwnd) {
            WinMinimize
        } else {
            WinActivate "ahk_id " lastHwnd
        }
        return
    }
    
    ; 遍历查找已打开的窗口
    foundHwnd := 0
    for hwnd in WinGetList("ahk_exe " browserEXE)
    {
        title := WinGetTitle(hwnd)
        if InStr(title, pwaTitleContains) {
            foundHwnd := hwnd
            break
        }
    }
    
    if (foundHwnd) {
        lastHwnd := foundHwnd
        if WinActive("ahk_id " foundHwnd) {
            WinMinimize
        } else {
            WinActivate "ahk_id " foundHwnd
        }
        return
    }
    
    ; 完全没开 → 用系统原生命令启动（和手动点开一模一样）
    Run launchCommand
    
    ; 等待窗口出现并记录
    WinWait "ahk_exe " browserEXE, , 10
    Sleep 800
    for hwnd in WinGetList("ahk_exe " browserEXE)
    {
        if InStr(WinGetTitle(hwnd), pwaTitleContains) {
            lastHwnd := hwnd
            WinActivate "ahk_id " hwnd
            break
        }
    }
}