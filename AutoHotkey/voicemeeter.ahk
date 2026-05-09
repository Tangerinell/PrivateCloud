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
    if (InStr(err.File, "VMR.ahk") || InStr(err.Message, "-nan")) {
        global vm := "" 
        return 1 
    }
}

; ==============================================================================
; 基础配置区 (Voicemeeter 路径与窗口配置)
; ==============================================================================
global exeName := "voicemeeter8x64.exe"                                
global appPath := "C:\Program Files (x86)\VB\Voicemeeter\voicemeeter8x64.exe"  
global titleContains := "Voicemeeter Potato"                           
global lastHwnd := 0                                                   
global vm := ""                                                        

; ==============================================================================
; 灵活切换通道配置 (快捷键 Ctrl+F11 切换输出通道)
; 对应 Voicemeeter 总线序号: 1=A1, 2=A2, 3=A3, 4=A4, 5=A5, 6=B1, 7=B2, 8=B3
; ==============================================================================
global BusName1  := "A3"   ; 用于 OSD 显示的名字
global BusIndex1 := 3      ; 对应的 API 序号 (A3 = 3)

global BusName2  := "A4"   ; 用于 OSD 显示的名字
global BusIndex2 := 4      ; 对应的 API 序号 (A4 = 4)

; ==============================================================================
; OSD 独立配置区 (为不同功能分配不同位置，防止重合)
; ==============================================================================

; 1. 麦克风开关 OSD 配置 (位置稍高: 75%)
global Osd_Mic_Config := {
    PosX: "Center",
    PosY: Integer(A_ScreenHeight * 0.75), 
    FontSize: 20,
    FontWeight: 700,
    FontAlpha: 180,
    ColorOn: "00FF00",
    ColorOff: "FF3333",
    OutlineSize: 1,
    OutlineColor: "000000",
    DisplayTime: 1500
}

; 2. 通道切换 (A3/A4) OSD 配置 (位置居中: 82%)
global Osd_Bus_Config := {
    PosX: "Center",
    PosY: Integer(A_ScreenHeight * 0.82), 
    FontSize: 20,
    FontWeight: 700,
    FontAlpha: 180,
    ColorOn: "00FF00",
    ColorOff: "FF3333",
    OutlineSize: 1,
    OutlineColor: "000000",
    DisplayTime: 1500
}

; 3. 音频引擎重启 OSD 配置 (位置稍低: 89%)
global Osd_Engine_Config := {
    PosX: "Center",
    PosY: Integer(A_ScreenHeight * 0.89), 
    FontSize: 18,
    FontWeight: 700,
    FontAlpha: 180,
    ColorOn: "00FF00",
    ColorOff: "FF3333",
    OutlineSize: 1,
    OutlineColor: "000000",
    DisplayTime: 2000
}

; ==============================================================================
; OSD 屏幕提示类 (支持多实例独立定时器)
; ==============================================================================
class OSD {
    __New(cfg) {
        this.cfg := cfg
        this.OutlineCtrls := []
        
        this.Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")
        this.Gui.BackColor := "010101"
        WinSetTransColor("010101 " this.cfg.FontAlpha, this.Gui.Hwnd)
        this.Gui.SetFont("s" this.cfg.FontSize " w" this.cfg.FontWeight " q4", "Microsoft YaHei")
        
        if (this.cfg.OutlineSize > 0) {
            s := this.cfg.OutlineSize
            offsets := [[s,0], [-s,0], [0,s], [0,-s], [s,s], [-s,-s], [s,-s], [-s,s]]
            for offset in offsets {
                ctrlX := 20 + offset[1]
                ctrlY := 20 + offset[2]
                ctrl := this.Gui.Add("Text", "x" ctrlX " y" ctrlY " w600 Center c" this.cfg.OutlineColor " BackgroundTrans", "")
                this.OutlineCtrls.Push(ctrl)
            }
        }
        
        this.MainCtrl := this.Gui.Add("Text", "x20 y20 w600 Center c" this.cfg.ColorOn " BackgroundTrans", "")
        
        ; 绑定隐藏函数，用于独立定时器
        this.HideCallback := ObjBindMethod(this, "Hide")
    }
    
    Update(text, isMuted) {
        currentColor := isMuted ? this.cfg.ColorOff : this.cfg.ColorOn
        this.MainCtrl.SetFont("c" currentColor)
        this.MainCtrl.Value := text
        for ctrl in this.OutlineCtrls {
            ctrl.Value := text
        }
        
        this.Gui.Show("NoActivate x" this.cfg.PosX " y" this.cfg.PosY)
        WinSetAlwaysOnTop(1, this.Gui.Hwnd)
        
        ; 自动管理自身的隐藏定时器 (防止不同 OSD 互相干扰)
        if (this.cfg.DisplayTime > 0) {
            SetTimer(this.HideCallback, -this.cfg.DisplayTime)
        }
    }
    
    Hide() {
        this.Gui.Hide()
    }
}

; 实例化三个独立的全局 OSD 对象
global osdMic := OSD(Osd_Mic_Config)
global osdBus := OSD(Osd_Bus_Config)
global osdEngine := OSD(Osd_Engine_Config)

; ==============================================================================
; 初始化 Voicemeeter (静默模式)
; ==============================================================================
if ProcessExist(exeName) {
    try {
        SplitPath(appPath, , &vmDir)
        global vm := VMR(vmDir)
        vm.Login(false)
    } catch {
        global vm := "" 
    }
}

; ==============================================================================
; 快捷键功能区
; ==============================================================================

; 【快捷键：Ctrl + F10】 -> 切换麦克风状态并显示 OSD (默认注释，需要可解除)
; ^F10::ToggleMic()

; 【快捷键：Ctrl + F11】 -> 切换 任意两个通道的静音状态 (互斥切换)
^F11::ToggleAudioBus()

; 【快捷键：Alt + C (!c)】 -> 切换显示/隐藏 Voicemeeter 窗口
!v:: {
    global lastHwnd
    
    if (lastHwnd && WinExist("ahk_id " lastHwnd)) {
        if WinActive("ahk_id " lastHwnd) {
            WinMinimize
        } else {
            WinActivate "ahk_id " lastHwnd
        }
        return
    }
    
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
    
    Run appPath
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

; 【快捷键：Alt + R (!r)】 -> 重启 Voicemeeter 音频引擎并显示 OSD
!r:: {
    global vm, osdEngine
    
    if !ProcessExist(exeName) {
        return 
    }
    
    try {
        if (!IsObject(vm) || !vm.HasProp("Type") || !vm.Type) {
            SplitPath(appPath, , &vmDir)
            vm := VMR(vmDir)
            vm.Login(false)
        }
        
        vm.Command.Restart()
        osdEngine.Update("音频引擎已重启", false)
        
    } catch {
        vm := "" 
    }
}

; ==============================================================================
; 辅助函数区
; ==============================================================================
ToggleMic() {
    global vm, osdMic

    if !ProcessExist(exeName) {
        return 
    }

    if (!IsObject(vm) || !vm.HasProp("Type") || !vm.Type) {
        try {
            SplitPath(appPath, , &vmDir)
            vm := VMR(vmDir)
            vm.Login(false)
        } catch {
            return 
        }
    }

    try {
        currentState := vm.Strip[1].mute
        newState := !currentState
        
        vm.Strip[1].mute := newState

        if (newState) {
            osdMic.Update("MUTED", true)
        } else {
            osdMic.Update("UNMUTED", false)
        }
    } catch {
        vm := ""
    }
}

ToggleAudioBus() {
    global vm, osdBus
    global BusName1, BusIndex1, BusName2, BusIndex2

    if !ProcessExist(exeName) {
        return
    }

    if (!IsObject(vm) || !vm.HasProp("Type") || !vm.Type) {
        try {
            SplitPath(appPath, , &vmDir)
            vm := VMR(vmDir)
            vm.Login(false)
        } catch {
            return
        }
    }

    try {
        currentState1 := vm.Bus[BusIndex1].mute
        
        newState1 := !currentState1
        vm.Bus[BusIndex1].mute := newState1
        vm.Bus[BusIndex2].mute := currentState1

        if (newState1) {
            ; 当 Bus1 被静音时，说明切到了 Bus2 (A4)，这里传 true 应用 ColorOff
            osdBus.Update("SWITCH TO " BusName2 "", true)
        } else {
            ; 当 Bus1 发声时，说明切到了 Bus1 (A3)，这里传 false 应用 ColorOn
            osdBus.Update("SWITCH TO " BusName1 "", false)
        }
    } catch {
        vm := ""
    }
}