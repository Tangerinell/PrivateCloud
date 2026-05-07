#Requires AutoHotkey v2.0
#Include VMR.ahk

; ==============================================================================
; 权限请求区 (确保在具有防作弊或高权限的游戏中也能显示 OSD)
; ==============================================================================
if not A_IsAdmin {
    Run "*RunAs " A_ScriptFullPath
    ExitApp
}

Persistent ; 保持脚本运行

; ==============================================================================
; 全局错误拦截 (防止 VMR.ahk 内部异步回调报错)
; ==============================================================================
OnError(CatchVmrErrors)
CatchVmrErrors(err, mode) {
    ; 只要错误是由 VMR.ahk 抛出的，或者是 -nan 导致的数学运算错误，直接静默吃掉
    if (InStr(err.File, "VMR.ahk") || InStr(err.Message, "-nan")) {
        global vm := "" ; 发生错误说明连接异常，重置实例以便后续静默重连
        return 1 ; 返回 1，彻底阻止系统弹窗报错
    }
}

; ==============================================================================
; 基础配置区 (Voicemeeter 路径与窗口配置)
; ==============================================================================
global exeName := "voicemeeter8x64.exe"                                ; 主进程名
global appPath := "C:\Program Files (x86)\VB\Voicemeeter\voicemeeter8x64.exe"  ; 安装路径
global titleContains := "Voicemeeter Potato"                           ; 窗口标题包含的关键字
global lastHwnd := 0                                                   ; 记录上次窗口句柄
global vm := ""                                                        ; 存储 VMR 实例对象

; ==============================================================================
; OSD 配置区 (纯净文字版)
; ==============================================================================
global PosX := "Center"                      ; 水平位置
global PosY := Integer(A_ScreenHeight * 0.8) ; 垂直位置: 默认在屏幕 80% 高度
global FontSize     := 18                    ; 字体大小
global FontWeight   := 700                   ; 字体粗细
global FontAlpha    := 180                   ; 字体透明度
global FontColorOn  := "00FF00"              ; 麦克风开启时的颜色
global FontColorOff := "FF3333"              ; 麦克风静音时的颜色

; ==============================================================================
; 初始化 Voicemeeter (已修改为静默模式)
; ==============================================================================
if ProcessExist(exeName) {
    try {
        SplitPath(appPath, , &vmDir)
        global vm := VMR(vmDir)
        vm.Login(false) ; 传入 false 避免 VMR 库内部的弹窗
    } catch {
        ; 失败时不弹窗、不退出，保持脚本静默运行，等待按下快捷键时自动重试
        global vm := "" 
    }
}

; ==============================================================================
; 创建 OSD 屏幕提示界面 (纯净文字版)
; ==============================================================================
global textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")

; 将背景设为纯黑，然后抠除黑色，剩余文字应用 FontAlpha 透明度
transColor := "000000"
textGui.BackColor := transColor
WinSetTransColor(transColor " " FontAlpha, textGui.Hwnd)

; 设置内边距和字体属性
textGui.MarginX := 30
textGui.MarginY := 15
textGui.SetFont("s" FontSize " w" FontWeight, "Microsoft YaHei")

; 添加文本控件
global osdText := textGui.Add("Text", "w400 Center c" FontColorOn, "麦克风已开启")

; ==============================================================================
; 快捷键功能区
; ==============================================================================

; 【快捷键：Ctrl + F10】 -> 切换麦克风状态并显示 OSD
; 这里应您的要求注释掉，不再触发 Voicemeeter 的静音
; ^F10::ToggleMic()

; 【快捷键：Alt + C (!c)】 -> 切换显示/隐藏 Voicemeeter 窗口
!v:: {
    global lastHwnd
    
    ; 优先使用上次记录的窗口句柄（最小化后最可靠）
    if (lastHwnd && WinExist("ahk_id " lastHwnd)) {
        if WinActive("ahk_id " lastHwnd) {
            WinMinimize
        } else {
            WinActivate "ahk_id " lastHwnd
        }
        return
    }
    
    ; 遍历查找已打开的 Voicemeeter 窗口
    foundHwnd := 0
    for hwnd in WinGetList("ahk_exe " exeName) {
        title := WinGetTitle(hwnd)
        if InStr(title, titleContains) {
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
    
    ; 完全没打开 → 启动程序
    Run appPath
    
    ; 等待窗口出现并记录句柄
    WinWait "ahk_exe " exeName, , 10
    Sleep 800
    for hwnd in WinGetList("ahk_exe " exeName) {
        title := WinGetTitle(hwnd)
        if InStr(title, titleContains) {
            lastHwnd := hwnd
            WinActivate "ahk_id " hwnd
            break
        }
    }
}

; 【快捷键：Alt + R (!r)】 -> 重启 Voicemeeter 音频引擎
!r:: {
    global vm
    
    if !ProcessExist(exeName) {
        return ; 如果主程序没运行，直接静默跳过
    }
    
    try {
        ; 如果尚未初始化或连接丢失，静默重新初始化 VMR
        if (!IsObject(vm) || !vm.HasProp("Type") || !vm.Type) {
            SplitPath(appPath, , &vmDir)
            vm := VMR(vmDir)
            vm.Login(false)
        }
        
        ; 执行重启指令 (已移除 ToolTip 提示，实现完全静默)
        vm.Command.Restart()
        
    } catch {
        vm := "" ; 连接出错时清空实例静默失败，确保下次重试
    }
}

; ==============================================================================
; 辅助函数区
; ==============================================================================
ToggleMic() {
    global vm

    if !ProcessExist(exeName) {
        return ; 如果主程序没运行，直接静默跳过
    }

    ; 每次调用前检查状态，如果未连接则尝试静默重连
    if (!IsObject(vm) || !vm.HasProp("Type") || !vm.Type) {
        try {
            SplitPath(appPath, , &vmDir)
            vm := VMR(vmDir)
            vm.Login(false)
        } catch {
            return ; 如果还是连不上，直接静默中断操作
        }
    }

    try {
        ; 读取 in1 的静音状态作为基准
        currentState := vm.Strip[1].mute
        newState := !currentState
        
        ; 同时设置 in1 (Strip 1) 和 虚拟in3 (Strip 8) 的静音状态
        vm.Strip[1].mute := newState

        ; 更改 OSD 的文本和颜色
        if (newState) {
            osdText.SetFont("c" FontColorOff)
            osdText.Value := "MUTED"
        } else {
            osdText.SetFont("c" FontColorOn)
            osdText.Value := "UNMUTED"
        }
        
        ; 显示界面，根据配置区设定的坐标显示
        textGui.Show("NoActivate x" PosX " y" PosY)
        
        ; 【核心修改】：强制将窗口置于最顶层，防止被全屏化/无边框游戏遮挡
        WinSetAlwaysOnTop(1, textGui.Hwnd)
        
        ; 重新设置定时器，1秒（-1000毫秒）后执行隐藏
        SetTimer(HideOSD, -1000)
    } catch {
        ; 如果通信过程出错（例如VM突然关闭），清除连接实例，等待下次重试
        vm := ""
    }
}

HideOSD() {
    textGui.Hide()
}