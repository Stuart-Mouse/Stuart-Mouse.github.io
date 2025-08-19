// Ports of stuff from imgui_imgl_win32.cpp
// 
// Q: Does this require putting the ImGui license in here?
//

IMGUI_IMPL_WIN32_DISABLE_GAMEPAD :: true;
#assert IMGUI_IMPL_WIN32_DISABLE_GAMEPAD "Xinput stuff not implemented"; // @Incomplete

ImGui_ImplWin32_Data :: struct {
    hWnd: HWND;
    MouseHwnd: HWND;
    MouseTrackedArea: s32;   // 0: not tracked, 1: client are, 2: non-client area
    MouseButtonsDown: s32;
    Time: s64;
    TicksPerSecond: s64;
    LastMouseCursor: ImGui.MouseCursor;

    #if IMGUI_IMPL_WIN32_DISABLE_GAMEPAD {
        HasGamepad: bool;
        WantUpdateHasGamepad: bool;
        XInputDLL: HMODULE;
        // XInputGetCapabilities: PFN_XInputGetCapabilities;
        // XInputGetState: PFN_XInputGetState;
    }
};

bd: ImGui_ImplWin32_Data;

ImGui_ImplWin32_Init :: (hwnd: *void) -> bool {
    io := ImGui.GetIO();
    assert(io.BackendPlatformUserData == null, "Already initialized a platform backend!");

    perf_frequency, perf_counter: s64;
    if (!QueryPerformanceFrequency(*perf_frequency))  return false;
    if (!QueryPerformanceCounter(*perf_counter))      return false;

    // Setup backend capabilities flags
    io.BackendPlatformUserData = cast(*void)*bd;
    io.BackendPlatformName = "imgui_impl_win32";
    io.BackendFlags_ |= .HasMouseCursors;  // We can honor GetMouseCursor() values (optional)
    io.BackendFlags_ |= .HasSetMousePos;   // We can honor io.WantSetMousePos requests (optional, rarely used)

    bd.hWnd = cast(HWND)hwnd;
    bd.TicksPerSecond = perf_frequency;
    bd.Time = perf_counter;
    bd.LastMouseCursor = xx ImGui.MouseCursor.COUNT;

    // Set platform dependent data in viewport
    ImGui.GetMainViewport().PlatformHandleRaw = hwnd;

    // Dynamically load XInput library
    #if !IMGUI_IMPL_WIN32_DISABLE_GAMEPAD {
        // Using XInput for gamepad (will load DLL dynamically)
        bd.WantUpdateHasGamepad = true;

        #import "Gamepad/XInput";

        success := init_xinput();
        if success {
            // bd.XInputDLL = dll;
            // bd.XInputGetCapabilities = cast(PFN_XInputGetCapabilities)GetProcAddress(dll, "XInputGetCapabilities");
            // bd.XInputGetState        = cast(PFN_XInputGetState)GetProcAddress(dll, "XInputGetState");
        }
    }

    return true;
}

ImGui_ImplWin32_NewFrame :: () {
    io := ImGui.GetIO();
    assert(*bd == io.BackendPlatformUserData, "Did you call ImGui_ImplWin32_Init()?");

    // Setup display size (every frame to accommodate for window resizing)
    rect: RECT;
    GetClientRect(bd.hWnd, *rect);
    io.DisplaySize = ImGui.ImVec2.{cast(float)(rect.right - rect.left), cast(float)(rect.bottom - rect.top)};

    // Setup time step
    current_time: s64;
    QueryPerformanceCounter(*current_time);
    io.DeltaTime = cast(float)(current_time - bd.Time) / bd.TicksPerSecond;
    bd.Time = current_time;

    // Update OS mouse position ImGui_ImplWin32_UpdateMouseData()
    {
        assert(bd.hWnd != null);
        io := ImGui.GetIO();

        focused_window := GetForegroundWindow();
        is_app_focused := focused_window == bd.hWnd;
        if is_app_focused {
            // (Optional) Set OS mouse position from Dear ImGui if requested (rarely used, only when ImGuiConfigFlags_NavEnableSetMousePos is enabled by user)
            if io.WantSetMousePos {
                pos := POINT.{ cast(s32)io.MousePos.x, cast(s32)io.MousePos.y };
                if ClientToScreen(bd.hWnd, *pos)  SetCursorPos(pos.x, pos.y);
            }

            // (Optional) Fallback to provide mouse position when focused (WM_MOUSEMOVE already provides this when hovered or captured)
            // This also fills a short gap when clicking non-client area: WM_NCMOUSELEAVE -> modal OS move -> gap -> WM_NCMOUSEMOVE
            if !io.WantSetMousePos && bd.MouseTrackedArea == 0 {
                pos: POINT;
                if GetCursorPos(*pos) && ScreenToClient(bd.hWnd, *pos) {
                    io.AddMousePosEvent(io, cast(float)pos.x, cast(float)pos.y);
                }
            }
        }
    }

    // Process workarounds for known Windows key handling issues ImGui_ImplWin32_ProcessKeyEventsWorkarounds
    {
        // Left & right Shift keys: when both are pressed together, Windows tend to not generate the WM_KEYUP event for the first released one.
        if ImGui.IsKeyDown(.LeftShift) && !IsVkDown(VK_LSHIFT) {
            ImGui_ImplWin32_AddKeyEvent(.LeftShift, false, VK_LSHIFT);
        }
        if ImGui.IsKeyDown(.RightShift) && !IsVkDown(VK_RSHIFT) {
            ImGui_ImplWin32_AddKeyEvent(.RightShift, false, VK_RSHIFT);
        }

        // Sometimes WM_KEYUP for Win key is not passed down to the app (e.g. for Win+V on some setups, according to GLFW).
        if ImGui.IsKeyDown(.LeftSuper) && !IsVkDown(VK_LWIN) {
            ImGui_ImplWin32_AddKeyEvent(.LeftSuper, false, VK_LWIN);
        }
        if ImGui.IsKeyDown(.RightSuper) && !IsVkDown(VK_RWIN) {
            ImGui_ImplWin32_AddKeyEvent(.RightSuper, false, VK_RWIN);
        }
    }

    // Update OS mouse cursor with the cursor requested by imgui
    mouse_cursor := ifx io.MouseDrawCursor ImGui.MouseCursor.None else ImGui.GetMouseCursor();
    if bd.LastMouseCursor != mouse_cursor {
        bd.LastMouseCursor = mouse_cursor;
        ImGui_ImplWin32_UpdateMouseCursor();
    }

    // Update game controllers (if enabled and available)
    #if !IMGUI_IMPL_WIN32_DISABLE_GAMEPAD ImGui_ImplWin32_UpdateGamepads();
}

GetMouseSourceFromMessageExtraInfo :: () -> ImGui.MouseSource {
    extra_info := GetMessageExtraInfo();
    
    if (extra_info & 0xFFFFFF80) == 0xFF515700  return .Pen;
    if (extra_info & 0xFFFFFF80) == 0xFF515780  return .TouchScreen;

    return .Mouse;
}

// NOTE(Charles): This was ported from cpp, it is compiling but not actually functioning atm. The version that drives
// imgui from modules/Input is working instead.
ImGui_ImplWin32_WndProcHandler :: (hwnd: HWND, msg: u32, wParam: WPARAM, lParam: LPARAM) -> s64 {
    if ImGui.GetCurrentContext() == null  return 0;

    io := ImGui.GetIO();

    if msg == {
        case WM_MOUSEMOVE; #through;
        case WM_NCMOUSEMOVE; {
            // We need to call TrackMouseEvent in order to receive WM_MOUSELEAVE events
            mouse_source := GetMouseSourceFromMessageExtraInfo();
            
            /*
            area := ifx msg == WM_MOUSEMOVE 1 else 2;
            bd.MouseHwnd = hwnd;
            if bd.MouseTrackedArea != area {
                TRACKMOUSEEVENT tme_cancel = { sizeof(tme_cancel), TME_CANCEL, hwnd, 0 };
                TRACKMOUSEEVENT tme_track = { sizeof(tme_track), (DWORD)((area == 2) ? (TME_LEAVE | TME_NONCLIENT) : TME_LEAVE), hwnd, 0 };
                if (bd.MouseTrackedArea != 0)
                    ::TrackMouseEvent(&tme_cancel);
                ::TrackMouseEvent(&tme_track);
                bd.MouseTrackedArea = area;
            }
            */

            coords := cast(u32) lParam;
            x := cast(s32) (coords & 0xFFFF); // GET_X_PARAM(lParam)
            y := cast(s32) (coords >> 16);    // GET_Y_PARAM(lParam)
            mouse_pos := POINT.{ x, y };
            // WM_NCMOUSEMOVE are provided in absolute coordinates.
            if msg != WM_NCMOUSEMOVE || ScreenToClient(hwnd, *mouse_pos) == xx BOOL.FALSE {
                io.AddMouseSourceEvent(io, mouse_source);
                io.AddMousePosEvent(io, cast(float) mouse_pos.x,  cast(float) mouse_pos.y);
            }
        }

        case WM_MOUSELEAVE; #through;
        case WM_NCMOUSELEAVE; {
            area := ifx msg == WM_MOUSELEAVE 1 else 2;
            if bd.MouseTrackedArea == area {
                if bd.MouseHwnd == hwnd  bd.MouseHwnd = null;

                bd.MouseTrackedArea = 0;
                FLOAT32_MAX :: 0h7F7FFFFF;
                FLT_MAX :: FLOAT32_MAX; // Is this the same?
                io.AddMousePosEvent(io, -FLT_MAX, -FLT_MAX);
            }
        }

        case WM_LBUTTONDOWN; #through; case WM_LBUTTONDBLCLK; #through;
        case WM_RBUTTONDOWN; #through; case WM_RBUTTONDBLCLK; #through;
        case WM_MBUTTONDOWN; #through; case WM_MBUTTONDBLCLK; #through;
        case WM_XBUTTONDOWN; #through; case WM_XBUTTONDBLCLK; {
            mouse_source := GetMouseSourceFromMessageExtraInfo();

            button := 0;
            if msg == WM_LBUTTONDOWN || msg == WM_LBUTTONDBLCLK  button = 0;
            if msg == WM_RBUTTONDOWN || msg == WM_RBUTTONDBLCLK  button = 1;
            if msg == WM_MBUTTONDOWN || msg == WM_MBUTTONDBLCLK  button = 2;

            if msg == WM_XBUTTONDOWN || msg == WM_XBUTTONDBLCLK {
                XBUTTON1 :: 0x0001;
                XBUTTON2 :: 0x0002;
                button_info := cast(u32) wParam;
                x_button := button_info >> 16;
                button = ifx x_button == XBUTTON1  3 else 4;
            }

            if bd.MouseButtonsDown == 0 && GetCapture() == null {
                SetCapture(hwnd);
            }

            bd.MouseButtonsDown |= cast(s32) 1 << button;
            io.AddMouseSourceEvent(io, mouse_source);
            io.AddMouseButtonEvent(io, xx button, true);
        }

        case WM_LBUTTONUP; #through;
        case WM_RBUTTONUP; #through;
        case WM_MBUTTONUP; #through;
        case WM_XBUTTONUP; {
            mouse_source := GetMouseSourceFromMessageExtraInfo();
            button := 0;

            if msg == WM_LBUTTONUP  button = 0;
            if msg == WM_RBUTTONUP  button = 1;
            if msg == WM_MBUTTONUP  button = 2;
            if msg == WM_XBUTTONUP {
                XBUTTON1 :: 0x0001;
                XBUTTON2 :: 0x0002;
                button_info := cast(u32) wParam;
                x_button := button_info >> 16;
                button = ifx x_button == XBUTTON1  3 else 4;
            }
            
            bd.MouseButtonsDown &= ~(cast(s32)1 << button);
            if bd.MouseButtonsDown == 0 && GetCapture() == hwnd {
                ReleaseCapture();
            }

            io.AddMouseSourceEvent(io, mouse_source);
            io.AddMouseButtonEvent(io, xx button, false);
        }

        case WM_MOUSEWHEEL;
            distance := cast,trunc(s16)(wParam >> 16);
            io.AddMouseWheelEvent(io, 0., cast(float)distance / WHEEL_DELTA);
        case WM_MOUSEHWHEEL;
            distance := cast,trunc(s16)(wParam >> 16);
            io.AddMouseWheelEvent(io, -cast(float) distance / WHEEL_DELTA, 0.0);

        case WM_KEYDOWN; #through;
        case WM_KEYUP; #through;
        case WM_SYSKEYDOWN; #through;
        case WM_SYSKEYUP; {
            is_key_down := msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN;

            if (wParam < 256) {
                ImGui_ImplWin32_UpdateKeyModifiers :: () {
                    io := ImGui.GetIO();
                    io.AddKeyEvent(io, ImGui.Key.Mod_Ctrl , IsVkDown(VK_CONTROL));
                    io.AddKeyEvent(io, ImGui.Key.Mod_Shift, IsVkDown(VK_SHIFT));
                    io.AddKeyEvent(io, ImGui.Key.Mod_Alt  , IsVkDown(VK_MENU));
                    io.AddKeyEvent(io, ImGui.Key.Mod_Super, IsVkDown(VK_APPS));
                }
                // Submit modifiers
                ImGui_ImplWin32_UpdateKeyModifiers();

                // Obtain virtual key code
                // (keypad enter doesn't have its own... VK_RETURN with KF_EXTENDED flag means keypad enter, see IM_VK_KEYPAD_ENTER definition for details, it is mapped to ImGui.Key.KeyPadEnter.)
                vk := cast(s32)wParam;
                hi_word := (cast(u32) lParam) >> 16;
                if (wParam == VK_RETURN) && (hi_word & KF_EXTENDED) {
                    vk = IM_VK_KEYPAD_ENTER;
                }

                // Submit key event
                key      := ImGui_ImplWin32_VirtualKeyToImGuiKey(vk);
                scancode := cast(s32) (hi_word & 0xFF);
                if key != ImGui.Key.None {
                    ImGui_ImplWin32_AddKeyEvent(key, is_key_down, vk, scancode);
                }

                // Submit individual left/right modifier events
                if vk == VK_SHIFT {
                    // Important: Shift keys tend to get stuck when pressed together, missing key-up events are corrected in ImGui_ImplWin32_ProcessKeyEventsWorkarounds()
                    if IsVkDown(VK_LSHIFT) == is_key_down { ImGui_ImplWin32_AddKeyEvent(ImGui.Key.LeftShift, is_key_down, VK_LSHIFT, scancode); }
                    if IsVkDown(VK_RSHIFT) == is_key_down { ImGui_ImplWin32_AddKeyEvent(ImGui.Key.RightShift, is_key_down, VK_RSHIFT, scancode); }
                
                } else if vk == VK_CONTROL {
                    if IsVkDown(VK_LCONTROL) == is_key_down { ImGui_ImplWin32_AddKeyEvent(ImGui.Key.LeftCtrl, is_key_down, VK_LCONTROL, scancode); }
                    if IsVkDown(VK_RCONTROL) == is_key_down { ImGui_ImplWin32_AddKeyEvent(ImGui.Key.RightCtrl, is_key_down, VK_RCONTROL, scancode); }
                
                } else if vk == VK_MENU {
                    if IsVkDown(VK_LMENU) == is_key_down { ImGui_ImplWin32_AddKeyEvent(ImGui.Key.LeftAlt, is_key_down, VK_LMENU, scancode); }
                    if IsVkDown(VK_RMENU) == is_key_down { ImGui_ImplWin32_AddKeyEvent(ImGui.Key.RightAlt, is_key_down, VK_RMENU, scancode); }
                }
            }
        }

        case WM_SETFOCUS; #through;
        case WM_KILLFOCUS;
            io.AddFocusEvent(io, msg == WM_SETFOCUS);

        case WM_CHAR;
            assert(IsWindowUnicode(hwnd) == .TRUE);

            // You can also use ToAscii()+GetKeyboardState() to retrieve characters.
            if wParam > 0 && wParam < 0x10000 {
                io.AddInputCharacterUTF16(io, cast(u16) wParam);
            }
            
            // Non unicode window handling
            /*                
            {
                wchar_t wch = 0;
                ::MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, (char*)&wParam, 1, &wch, 1);
                io.AddInputCharacter(wch);
            }
            */

        case WM_SETCURSOR;
            // This is required to restore cursor when transitioning from e.g resize borders to client area.
            HTCLIENT :: 1;
            if LOWORD(lParam) == HTCLIENT && ImGui_ImplWin32_UpdateMouseCursor() {
                return 1;
            }

        // Can't find the value of WM_DEVICECHANGE...
        /*
        case WM_DEVICECHANGE;
            #if !IMGUI_IMPL_WIN32_DISABLE_GAMEPAD {
                if cast(u32)wParam == DBT_DEVNODES_CHANGED  bd.WantUpdateHasGamepad = true;
            }
        */
    }

    return 0;
}

IsVkDown :: (vk: s32) -> bool {
    return (GetKeyState(vk) & 0x8000) != 0;
}

// There is no distinct VK_xxx for keypad enter, instead it is VK_RETURN + KF_EXTENDED, we assign it an arbitrary value to make code more readable (VK_ codes go up to 255)
IM_VK_KEYPAD_ENTER :: (VK_RETURN + 256);

// Map VK_xxx to ImGui.Key.xxx.
ImGui_ImplWin32_VirtualKeyToImGuiKey :: (wParam: s32) -> ImGui.Key
{
    if wParam == {
        case VK_TAB; return ImGui.Key.Tab;
        case VK_LEFT; return ImGui.Key.LeftArrow;
        case VK_RIGHT; return ImGui.Key.RightArrow;
        case VK_UP; return ImGui.Key.UpArrow;
        case VK_DOWN; return ImGui.Key.DownArrow;
        case VK_PRIOR; return ImGui.Key.PageUp;
        case VK_NEXT; return ImGui.Key.PageDown;
        case VK_HOME; return ImGui.Key.Home;
        case VK_END; return ImGui.Key.End;
        case VK_INSERT; return ImGui.Key.Insert;
        case VK_DELETE; return ImGui.Key.Delete;
        case VK_BACK; return ImGui.Key.Backspace;
        case VK_SPACE; return ImGui.Key.Space;
        case VK_RETURN; return ImGui.Key.Enter;
        case VK_ESCAPE; return ImGui.Key.Escape;
        case VK_OEM_7; return ImGui.Key.Apostrophe;
        case VK_OEM_COMMA; return ImGui.Key.Comma;
        case VK_OEM_MINUS; return ImGui.Key.Minus;
        case VK_OEM_PERIOD; return ImGui.Key.Period;
        case VK_OEM_2; return ImGui.Key.Slash;
        case VK_OEM_1; return ImGui.Key.Semicolon;
        case VK_OEM_PLUS; return ImGui.Key.Equal;
        case VK_OEM_4; return ImGui.Key.LeftBracket;
        case VK_OEM_5; return ImGui.Key.Backslash;
        case VK_OEM_6; return ImGui.Key.RightBracket;
        case VK_OEM_3; return ImGui.Key.GraveAccent;
        case VK_CAPITAL; return ImGui.Key.CapsLock;
        case VK_SCROLL; return ImGui.Key.ScrollLock;
        case VK_NUMLOCK; return ImGui.Key.NumLock;
        case VK_SNAPSHOT; return ImGui.Key.PrintScreen;
        case VK_PAUSE; return ImGui.Key.Pause;
        case VK_NUMPAD0; return ImGui.Key.Keypad0;
        case VK_NUMPAD1; return ImGui.Key.Keypad1;
        case VK_NUMPAD2; return ImGui.Key.Keypad2;
        case VK_NUMPAD3; return ImGui.Key.Keypad3;
        case VK_NUMPAD4; return ImGui.Key.Keypad4;
        case VK_NUMPAD5; return ImGui.Key.Keypad5;
        case VK_NUMPAD6; return ImGui.Key.Keypad6;
        case VK_NUMPAD7; return ImGui.Key.Keypad7;
        case VK_NUMPAD8; return ImGui.Key.Keypad8;
        case VK_NUMPAD9; return ImGui.Key.Keypad9;
        case VK_DECIMAL; return ImGui.Key.KeypadDecimal;
        case VK_DIVIDE; return ImGui.Key.KeypadDivide;
        case VK_MULTIPLY; return ImGui.Key.KeypadMultiply;
        case VK_SUBTRACT; return ImGui.Key.KeypadSubtract;
        case VK_ADD; return ImGui.Key.KeypadAdd;
        case IM_VK_KEYPAD_ENTER; return ImGui.Key.KeypadEnter;
        case VK_LSHIFT; return ImGui.Key.LeftShift;
        case VK_LCONTROL; return ImGui.Key.LeftCtrl;
        case VK_LMENU; return ImGui.Key.LeftAlt;
        case VK_LWIN; return ImGui.Key.LeftSuper;
        case VK_RSHIFT; return ImGui.Key.RightShift;
        case VK_RCONTROL; return ImGui.Key.RightCtrl;
        case VK_RMENU; return ImGui.Key.RightAlt;
        case VK_RWIN; return ImGui.Key.RightSuper;
        case VK_APPS; return ImGui.Key.Menu;
        case #char "0"; return ImGui.Key._0;
        case #char "1"; return ImGui.Key._1;
        case #char "2"; return ImGui.Key._2;
        case #char "3"; return ImGui.Key._3;
        case #char "4"; return ImGui.Key._4;
        case #char "5"; return ImGui.Key._5;
        case #char "6"; return ImGui.Key._6;
        case #char "7"; return ImGui.Key._7;
        case #char "8"; return ImGui.Key._8;
        case #char "9"; return ImGui.Key._9;
        case #char "A"; return ImGui.Key.A;
        case #char "B"; return ImGui.Key.B;
        case #char "C"; return ImGui.Key.C;
        case #char "D"; return ImGui.Key.D;
        case #char "E"; return ImGui.Key.E;
        case #char "F"; return ImGui.Key.F;
        case #char "G"; return ImGui.Key.G;
        case #char "H"; return ImGui.Key.H;
        case #char "I"; return ImGui.Key.I;
        case #char "J"; return ImGui.Key.J;
        case #char "K"; return ImGui.Key.K;
        case #char "L"; return ImGui.Key.L;
        case #char "M"; return ImGui.Key.M;
        case #char "N"; return ImGui.Key.N;
        case #char "O"; return ImGui.Key.O;
        case #char "P"; return ImGui.Key.P;
        case #char "Q"; return ImGui.Key.Q;
        case #char "R"; return ImGui.Key.R;
        case #char "S"; return ImGui.Key.S;
        case #char "T"; return ImGui.Key.T;
        case #char "U"; return ImGui.Key.U;
        case #char "V"; return ImGui.Key.V;
        case #char "W"; return ImGui.Key.W;
        case #char "X"; return ImGui.Key.X;
        case #char "Y"; return ImGui.Key.Y;
        case #char "Z"; return ImGui.Key.Z;
        case VK_F1; return ImGui.Key.F1;
        case VK_F2; return ImGui.Key.F2;
        case VK_F3; return ImGui.Key.F3;
        case VK_F4; return ImGui.Key.F4;
        case VK_F5; return ImGui.Key.F5;
        case VK_F6; return ImGui.Key.F6;
        case VK_F7; return ImGui.Key.F7;
        case VK_F8; return ImGui.Key.F8;
        case VK_F9; return ImGui.Key.F9;
        case VK_F10; return ImGui.Key.F10;
        case VK_F11; return ImGui.Key.F11;
        case VK_F12; return ImGui.Key.F12;

        case; return ImGui.Key.None;
    }
}

ImGui_ImplWin32_AddKeyEvent :: (key: ImGui.Key, down: bool, native_keycode: s32, native_scancode : s32 = -1) {
    io := ImGui.GetIO();
    io.AddKeyEvent(io, key, down);
    io.SetKeyEventNativeData(io, key, native_keycode, native_scancode); // To support legacy indexing (<1.87 user code)
}

ImGui_ImplWin32_UpdateMouseCursor :: () -> bool {
    io := ImGui.GetIO();

    if io.ConfigFlags_ & ImGui.ConfigFlags.NoMouseCursorChange  return false;

    imgui_cursor := ImGui.GetMouseCursor();

    if imgui_cursor == .None || io.MouseDrawCursor {
        // Hide OS mouse cursor if imgui is drawing it or if it wants no cursor
        SetCursor(null);

    } else {
        // Show OS mouse cursor
        win32_cursor := IDC_ARROW;
        if imgui_cursor == {
            case .Arrow;        win32_cursor = IDC_ARROW;
            case .TextInput;    win32_cursor = IDC_IBEAM;
            case .ResizeAll;    win32_cursor = IDC_SIZEALL;
            case .ResizeEW;     win32_cursor = IDC_SIZEWE;
            case .ResizeNS;     win32_cursor = IDC_SIZENS;
            case .ResizeNESW;   win32_cursor = IDC_SIZENESW;
            case .ResizeNWSE;   win32_cursor = IDC_SIZENWSE;
            case .Hand;         win32_cursor = IDC_HAND;
            case .NotAllowed;   win32_cursor = IDC_NO;
        }

        SetCursor(LoadCursorW(null, win32_cursor));
    }
    
    return true;
}

// Windows platform stuff

// NOTE(Charles): I only decided I might as well implement this _after_ I had converted most uses to not use it,
// smart...
LOWORD :: (lParam: LPARAM) -> u32 #expand {
    low_dword := cast(u32) lParam;
    return low_dword & 0xFFFF;
}

KF_EXTENDED :: 0x0100;

WHEEL_DELTA :: 120;

WM_MOUSELEAVE   :: 0x02A3;
WM_NCMOUSELEAVE :: 0x02A2;


#scope_file

// :ImGuiBackends

#import "Basic";
#import "Windows";
ImGui :: #import "ImGui";

user32   :: #system_library "user32";
GetCapture :: () -> HWND #foreign user32;
IsWindowUnicode :: (hWnd: HWND) -> BOOL #foreign user32;
SetCursorPos :: (X: s32, Y: s32) -> BOOL #foreign user32;
