// Backend to use modules/Input for input handling with ImGui.
//

// NOTE(Charles): Stuff missing from win32 example impl:
// - A bunch of stuff that don't look necessary/important :Win32InputMissing
// - Gamepad support

// This takes all the events, so mouse input can be updated before checking events. It might make more
// sense that this takes one event, and returns some result so the other program input handling can
// skip stuff that is "consumed"? (ImGui has flags for when it should be capturing mouse/keyboard input).
imgui_handle_input_events :: (events: [] Input.Event) {
    if ImGui.GetCurrentContext() == null  return; // ?

    // print("Event: %\n", event);
    io := ImGui.GetIO();

    // @Hack Input module for android treats touch inputs as mouse button left, but you need to set the "mouse"
    // position to something valid before triggering the click so update it here.
    // @TODO(Charles): This can now be updated as modules/Input has touch!
    #if OS == .ANDROID {
        WC :: #import "Window_Creation";
        Math :: #import "Math";
        touch_x, touch_y, success := WC.get_mouse_pointer_position(true);
        touch_x_f := cast(float) touch_x;
        touch_y_f := cast(float) touch_y;
        if !success {
            // ImGui wants -FLT_MAX, -FLT_MAX to indicate no mouse.
            FLT_MAX :: Math.FLOAT32_MAX;
            touch_x_f = -FLT_MAX;
            touch_y_f = -FLT_MAX;
        }

        // @Hack when releasing screen, need to have the mouse position set to where we released.
        touch_on_release := ImGui.GetMousePos();

        // io.AddMouseSourceEvent(io, .TouchScreen);
        io.AddMousePosEvent(io, touch_x_f, touch_y_f);
    }

    // NOTE(Charles): On windows mouse position is handled in ImGui_ImplWin32_NewFrame with GetCusorPos on tick. The 
    // Imgui examples  also respond to WM_MOUSEMOVE, but it's not clear why?
    // modules/Input "doesn't have mouse move events yet", it only gives us the delta.

    for event: events {
        // :Win32InputMissing AddFocusEvent, could be done by checking Input.input_application_has_focus for change.
        if event.type == {
            case .KEYBOARD;
            if event.key_code ==  {
                // :Win32InputMissing  mouse extra buttons, SetCapturing?, Mouse source
                // case .MOUSE_BUTTON_LEFT;   io.AddMouseButtonEvent(io, xx ImGui.MouseButton.Left  , xx event.key_pressed);
                case .MOUSE_BUTTON_LEFT;
                // @Hack
                #if OS == .ANDROID {
                    if !event.key_pressed {
                        io.AddMousePosEvent(io, touch_on_release.x, touch_on_release.y);
                    }
                }
                io.AddMouseButtonEvent(io, xx ImGui.MouseButton.Left  , xx event.key_pressed);
                case .MOUSE_BUTTON_RIGHT;  io.AddMouseButtonEvent(io, xx ImGui.MouseButton.Right , xx event.key_pressed);
                case .MOUSE_BUTTON_MIDDLE; io.AddMouseButtonEvent(io, xx ImGui.MouseButton.Middle, xx event.key_pressed);

                case;
                imgui_key := to_imgui_key(event.key_code);
                // :Win32InputMissing Input only gives us single ctrl, shift, alt, not left/right. ImGui example sends
                // one event for either, then an extra for left right.
                if imgui_key != .None {
                    // :Win32InputMissing SetKeyEventNativeData gets called for some legacy reason?
                    io.AddKeyEvent(io, imgui_key, xx event.key_pressed);
                }
            }

            case .MOUSE_WHEEL;
            io.AddMouseWheelEvent(io, 0., cast(float)event.wheel_delta / event.typical_wheel_delta); // GetRect just looks at mouse_delta_z?

            case .TEXT_INPUT;
            io.AddInputCharacter(io, event.utf32);
        }
    }
    
    {   // set mouse position
        x, y, ok := get_mouse_pointer_position(window, false);
        io.AddMousePosEvent(io, xx x, xx y);
    }
}

#scope_file

// :ImGuiBackends

#import "Basic";
using Input :: #import "Input";
using ImGui :: #import "ImGui";

to_imgui_key :: (key_code: Input.Key_Code) -> ImGui.Key {
    result := ImGui.Key.None;
    if key_code == {
        // NOTE(Charles): Quite a few keys are UNKNOWN to input module, eg CapsLock, all numpad keys.
        case .UNKNOWN; result = .None;

        case .BACKSPACE;   result = .Backspace;
        case .TAB;         result = .Tab;
        // case .LINEFEED; result = . ?
        case .ENTER;       result = .Enter;
        case .ESCAPE;      result = .Escape;
        case .SPACEBAR;    result = .Space;

        case #char "0"; result = ._0;
        case #char "1"; result = ._1;
        case #char "2"; result = ._2;
        case #char "3"; result = ._3;
        case #char "4"; result = ._4;
        case #char "5"; result = ._5;
        case #char "6"; result = ._6;
        case #char "7"; result = ._7;
        case #char "8"; result = ._8;
        case #char "9"; result = ._9;
        case #char "A"; result = .A;
        case #char "B"; result = .B;
        case #char "C"; result = .C;
        case #char "D"; result = .D;
        case #char "E"; result = .E;
        case #char "F"; result = .F;
        case #char "G"; result = .G;
        case #char "H"; result = .H;
        case #char "I"; result = .I;
        case #char "J"; result = .J;
        case #char "K"; result = .K;
        case #char "L"; result = .L;
        case #char "M"; result = .M;
        case #char "N"; result = .N;
        case #char "O"; result = .O;
        case #char "P"; result = .P;
        case #char "Q"; result = .Q;
        case #char "R"; result = .R;
        case #char "S"; result = .S;
        case #char "T"; result = .T;
        case #char "U"; result = .U;
        case #char "V"; result = .V;
        case #char "W"; result = .W;
        case #char "X"; result = .X;
        case #char "Y"; result = .Y;
        case #char "Z"; result = .Z;

        case #char "'";  result = .Apostrophe;
        case #char ",";  result = .Comma;
        case #char "-";  result = .Minus;
        case #char ".";  result = .Period;
        case #char "/";  result = .Slash;
        case #char ";";  result = .Semicolon;
        case #char "=";  result = .Equal;
        case #char "[";  result = .LeftBracket;
        case #char "\\"; result = .Backslash;
        case #char "]";  result = .RightBracket;
        case #char "`";  result = .GraveAccent;

        case .DELETE; result = .Delete;

        case .ARROW_UP;    result = .UpArrow;
        case .ARROW_DOWN;  result = .DownArrow;
        case .ARROW_LEFT;  result = .LeftArrow;
        case .ARROW_RIGHT; result = .RightArrow;

        case .PAGE_UP;   result = .PageUp;
        case .PAGE_DOWN; result = .PageDown;

        case .HOME; result = .Home;
        case .END;  result = .End;

        case .INSERT; result = .Insert;

        case .PAUSE;       result = .Pause;
        case .SCROLL_LOCK; result = .ScrollLock;

        case .ALT;   result = .Mod_Alt;
        case .CTRL;  result = .Mod_Ctrl;
        case .SHIFT; result = .Mod_Shift;
        case .CMD;   result = .Mod_Super; // Q: Is this right?

        case .F1;  result = .F1;
        case .F2;  result = .F2;
        case .F3;  result = .F3;
        case .F4;  result = .F4;
        case .F5;  result = .F5;
        case .F6;  result = .F6;
        case .F7;  result = .F7;
        case .F8;  result = .F8;
        case .F9;  result = .F9;
        case .F10; result = .F10;
        case .F11; result = .F11;
        case .F12; result = .F12;
        // case .F13; result = .F13; // ImGui only gets up to F12, Input goes up to F24?
        // case .F14; result = .F14;
        // case .F15; result = .F15;
        // case .F16; result = .F16;
        // case .F17; result = .F17;
        // case .F18; result = .F18;
        // case .F19; result = .F19;
        // case .F20; result = .F20;
        // case .F21; result = .F21;
        // case .F22; result = .F22;
        // case .F23; result = .F23;
        // case .F24; result = .F24;

        case .PRINT_SCREEN; result = .PrintScreen;
        case;
        log_error("to_imgui_key: Unhandled key_code: %", key_code);
    }

    return result;
}
