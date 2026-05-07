#Requires AutoHotkey v2.0

; ==============================================================================
; 【核心配置】Studio One 内部绝对宏快捷键映射
; ==============================================================================
global MacroKey_Mute   := "-"                ; 【需修改】例如你给“静音宏”绑定了 [ 键
global MacroKey_Unmute := "="                ; 【需修改】例如你给“取消静音宏”绑定了 ] 键

; ==============================================================================
; OSD 1 独立配置区 (例如：主屏幕下方) - 状态切换时短暂显示
; ==============================================================================
global Osd1_Config := {
    PosX: "Center",                      ; 水平位置: "Center" 居中，或填数字如 100, -1000(左副屏)
    PosY: Integer(A_ScreenHeight * 0.8), ; 垂直位置: 默认屏幕 80% 高度
    FontSize: 20,                        ; 字体大小
    FontWeight: 700,                     ; 字体粗细 (400正常, 700粗体)
    FontAlpha: 140,                      ; 字体透明度 (0-255)
    ColorOn: "00FF00",                   ; 开启时的颜色 (绿色)
    ColorOff: "FF3333",                  ; 静音时的颜色 (红色)
    OutlineSize: 1,                      ; 【新增】描边粗细 (数字越大越粗，0为关闭描边)
    OutlineColor: "000000",              ; 【新增】描边颜色 (黑色最佳)
    DisplayTime: 1000                    ; 显示时长(毫秒)，例如 1500 代表 1.5 秒后自动隐藏
}

; ==============================================================================
; OSD 2 独立配置区 (例如：副屏幕 / 或者直播画面专用) - 常驻显示
; ==============================================================================
global Osd2_Config := {
    PosX: Integer(A_ScreenWidth * 0.835), ; 水平位置: 比如改为 -1000 可以显示在左侧副屏
    PosY: Integer(A_ScreenHeight * 0.927), ; 垂直位置: 默认屏幕 86% 高度
    FontSize: 15,                        ; 可以设置跟 OSD1 完全不同的字体大小
    FontWeight: 900,                     ; 更粗的字体
    FontAlpha: 200,                      ; 字体透明度 (0-255)
    ColorOn: "00FF00",                   ; 开启时的颜色
    ColorOff: "FF3333",                  ; 静音时的颜色
    OutlineSize: 2,                      ; 【新增】描边粗细 (数字越大越粗，0为关闭描边)
    OutlineColor: "000000"               ; 【新增】描边颜色 (黑色最佳)
}

; ==============================================================================
; 创建 OSD 屏幕提示界面 (纯文字、无描边、基于类的独立配置实现)
; ==============================================================================
class OSD {
    __New(cfg) {
        this.cfg := cfg ; 保存独立配置
        this.OutlineCtrls := [] ; 用于存储描边文本控件的数组
        
        ; 创建 GUI
        this.Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")
        
        ; 【修复锯齿和黑边的核心优化 1】：
        ; 不要用绝对纯黑 "000000" 作为透明色，改用极其接近黑色的 "010101"。
        ; 这样边缘抗锯齿的过渡色会与 "010101" 融合，配合黑色描边能实现完美的边缘过渡，杜绝杂乱黑边。
        this.Gui.BackColor := "010101"
        WinSetTransColor("010101 " this.cfg.FontAlpha, this.Gui.Hwnd)
        
        ; 【修复锯齿和黑边的核心优化 2】：
        ; 在字体选项中加入 "q4"。q4 代表 ANTIALIASED_QUALITY（灰度抗锯齿）。
        ; 它会禁用 Windows 默认的 ClearType（亚像素抗锯齿），消除透明背景下的红蓝锯齿杂色。
        this.Gui.SetFont("s" this.cfg.FontSize " w" this.cfg.FontWeight " q4", "Microsoft YaHei")
        
        ; 【新增】生成描边：在主文字的周围8个方向绘制黑色底层文字
        if (this.cfg.OutlineSize > 0) {
            s := this.cfg.OutlineSize
            ; 8 个方向的 X 和 Y 偏移量
            offsets := [[s,0], [-s,0], [0,s], [0,-s], [s,s], [-s,-s], [s,-s], [-s,s]]
            
            for offset in offsets {
                ; 基础坐标 x20 y20 加上偏移量
                ctrlX := 20 + offset[1]
                ctrlY := 20 + offset[2]
                ctrl := this.Gui.Add("Text", "x" ctrlX " y" ctrlY " w600 Center c" this.cfg.OutlineColor " BackgroundTrans", "")
                this.OutlineCtrls.Push(ctrl)
            }
        }
        
        ; 添加主文字（最后添加，确保置于最顶层，覆盖在描边之上）
        this.MainCtrl := this.Gui.Add("Text", "x20 y20 w600 Center c" this.cfg.ColorOn " BackgroundTrans", "")
    }
    
    Update(text, isMuted) {
        ; 根据静音状态获取当前 OSD 配置的颜色
        currentColor := isMuted ? this.cfg.ColorOff : this.cfg.ColorOn
        
        ; 更新主文字和颜色
        this.MainCtrl.SetFont("c" currentColor)
        this.MainCtrl.Value := text
        
        ; 更新描边文字
        for ctrl in this.OutlineCtrls {
            ctrl.Value := text
        }
        
        ; 显示并更新位置
        this.Gui.Show("NoActivate x" this.cfg.PosX " y" this.cfg.PosY)
        WinSetAlwaysOnTop(1, this.Gui.Hwnd)
    }
    
    Hide() {
        this.Gui.Hide()
    }
}

; 实例化两个独立的 OSD 对象
global osd1 := OSD(Osd1_Config)
global osd2 := OSD(Osd2_Config)

; 记录 AHK 内部当前状态
global isMuted := false
global isOsd2Visible := true  ; 记录常驻 OSD2 的显示状态

; 脚本启动时，初始化常驻 OSD2 的默认显示
osd2.Update("UNMUTED", false)

; ==============================================================================
; 快捷键功能区
; ==============================================================================

; 【快捷键：Ctrl + F10】 -> 切换 Studio Pro 静音状态并触发 OSD 更新
^F10::ToggleStudioProMic()

; 【快捷键：Alt + 3】 -> 开启或关闭 OSD2 (常驻显示开关)
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
        
        ; 仅在 OSD2 处于开启状态时更新常驻显示
        if (isOsd2Visible) {
            osd2.Update("MUTED", true)
        }
    } else {
        SmartSendToS1(MacroKey_Unmute)
        osd1.Update("UNMUTED", false)
        
        ; 仅在 OSD2 处于开启状态时更新常驻显示
        if (isOsd2Visible) {
            osd2.Update("UNMUTED", false)
        }
    }
    
    ; 现在只控制 OSD1 的隐藏，且使用 Osd1_Config 的自定义时间
    SetTimer(HideOSD1, -Osd1_Config.DisplayTime)
}

; 关闭/显示 常驻 OSD2 的控制逻辑
ToggleOsd2Visibility() {
    global isOsd2Visible, isMuted
    
    isOsd2Visible := !isOsd2Visible ; 状态反转
    
    if (isOsd2Visible) {
        ; 如果重新开启显示，则获取当前真实的麦克风状态并渲染
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
        ControlSend("{Ctrl up}" . keyToSend, , "ahk_exe Studio Pro.exe")
        SetKeyDelay(-1, -1) 
    }
}