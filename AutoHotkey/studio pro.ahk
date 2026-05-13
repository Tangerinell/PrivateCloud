#Requires AutoHotkey v2.0
#MaxThreadsPerHotkey 2  ; 【优化】允许快捷键同时最多运行2个线程，防止手速过快导致按键被忽略

; ==============================================================================
; 【核心配置】Studio One 内部绝对宏快捷键映射
; ==============================================================================
global MacroKey_Mute   := "-"                ; 【需修改】例如你给“静音宏”绑定了 [ 键
global MacroKey_Unmute := "="                ; 【需修改】例如你给“取消静音宏”绑定了 ] 键
global StartMuted      := true               ; 脚本启动时默认状态：true 为闭麦(静音)，false 为开麦

; ==============================================================================
; OSD 1 独立配置区 (例如：主屏幕下方) - 状态切换时短暂显示
; ==============================================================================
global Osd1_Config := {
    PosX: "Center",                      
    PosY: Integer(A_ScreenHeight * 0.8), 
    FontSize: 20,                        
    FontWeight: 700,                     
    FontAlpha: 140,                      
    ColorOn: "00FF00",                   
    ColorOff: "FF3333",                  
    OutlineSize: 1,                      
    OutlineColor: "000000",              
    DisplayTime: 1000                    
}

; ==============================================================================
; OSD 2 独立配置区 (例如：副屏幕 / 或者直播画面专用) - 常驻显示
; ==============================================================================
global Osd2_Config := {
    VisibleOnStart: true,                
    PosX: Integer(A_ScreenWidth * 0.835), 
    PosY: Integer(A_ScreenHeight * 0.92), 
    FontSize: 15,                        
    FontWeight: 900,                     
    FontAlpha: 200,                      
    ColorOn: "00FF00",                   
    ColorOff: "FF3333",                  
    OutlineSize: 2,                      
    OutlineColor: "000000"               
}

; ==============================================================================
; 创建 OSD 屏幕提示界面
; ==============================================================================
class OSD {
    __New(cfg) {
        this.cfg := cfg 
        this.OutlineCtrls := [] 
        
        ; 创建 GUI
        this.Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")
        
        ; 透明色与抗锯齿
        this.Gui.BackColor := "010101"
        WinSetTransColor("010101 " this.cfg.FontAlpha, this.Gui.Hwnd)
        this.Gui.SetFont("s" this.cfg.FontSize " w" this.cfg.FontWeight " q4", "Microsoft YaHei")
        
        ; 生成描边
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
        
        ; 添加主文字
        this.MainCtrl := this.Gui.Add("Text", "x20 y20 w600 Center c" this.cfg.ColorOn " BackgroundTrans", "")
    }
    
    Update(text, isMuted) {
        currentColor := isMuted ? this.cfg.ColorOff : this.cfg.ColorOn
        
        this.MainCtrl.SetFont("c" currentColor)
        this.MainCtrl.Value := text
        
        for ctrl in this.OutlineCtrls {
            ctrl.Value := text
        }
        
        ; 无焦点显示
        this.Gui.Show("NA x" this.cfg.PosX " y" this.cfg.PosY)

        ; 【核心优化】：针对窗口化全屏游戏的终极置顶 API
        ; HWND_TOPMOST = -1, SWP_NOMOVE(0x02) | SWP_NOSIZE(0x01) | SWP_NOACTIVATE(0x10) = 0x13
        ; 这能强行把 OSD 插入到游戏渲染管线之上，且不会引发焦点丢失或闪烁
        try DllCall("SetWindowPos", "Ptr", this.Gui.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
    }
    
    Hide() {
        this.Gui.Hide()
    }
}

; 实例化对象
global osd1 := OSD(Osd1_Config)
global osd2 := OSD(Osd2_Config)

global isMuted := StartMuted
global isOsd2Visible := Osd2_Config.VisibleOnStart  

; 启动初始化同步
if WinExist("ahk_exe Studio Pro.exe") {
    if (isMuted) {
        SmartSendToS1(MacroKey_Mute)
        osd1.Update("MUTED", true)
    } else {
        SmartSendToS1(MacroKey_Unmute)
        osd1.Update("UNMUTED", false)
    }
    SetTimer(HideOSD1, -Osd1_Config.DisplayTime)
}

if (isOsd2Visible) {
    if (isMuted) {
        osd2.Update("MUTED", true)
    } else {
        osd2.Update("UNMUTED", false)
    }
}

; ==============================================================================
; 快捷键功能区
; ==============================================================================

^F10::ToggleStudioProMic()
!3::ToggleOsd2Visibility()

; ==============================================================================
; 辅助函数区
; ==============================================================================
ToggleStudioProMic() {
    global isMuted, isOsd2Visible
    
    if !WinExist("ahk_exe Studio Pro.exe") {
        return 
    }

    isMuted := !isMuted

    if (isMuted) {
        SmartSendToS1(MacroKey_Mute)
        osd1.Update("MUTED", true)
        if (isOsd2Visible) {
            osd2.Update("MUTED", true)
        }
    } else {
        SmartSendToS1(MacroKey_Unmute)
        osd1.Update("UNMUTED", false)
        if (isOsd2Visible) {
            osd2.Update("UNMUTED", false)
        }
    }
    
    SetTimer(HideOSD1, -Osd1_Config.DisplayTime)
}

ToggleOsd2Visibility() {
    global isOsd2Visible, isMuted
    
    isOsd2Visible := !isOsd2Visible 
    
    if (isOsd2Visible) {
        if (isMuted) {
            osd2.Update("MUTED", true)
        } else {
            osd2.Update("UNMUTED", false)
        }
    } else {
        osd2.Hide()
    }
}

HideOSD1() {
    osd1.Hide()
}

SmartSendToS1(keyToSend) {
    if WinActive("ahk_exe Studio Pro.exe") {
        Send(keyToSend) 
    } else {
        SetKeyDelay(10, 30) 
        ; 【优化】加入 {Alt up}{Shift up}，防止玩游戏时按着跑/蹲键导致向后台发送了带修饰键的指令而失效
        ControlSend("{Ctrl up}{Alt up}{Shift up}" . keyToSend, , "ahk_exe Studio Pro.exe")
        SetKeyDelay(-1, -1) 
    }
}