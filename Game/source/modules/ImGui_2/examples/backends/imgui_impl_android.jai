imgui_want_text_input_last := false;

// @Cleanup: App param is not used
ImGui_ImplAndroid_Init :: (app: *Android_App) -> bool {
    assert(android_app != null);

    g_Window = android_app.window;
    g_Time = 0.;

    io := ImGui.GetIO();

    // Setup backend capabilities flags
    io.BackendPlatformName = "imgui_impl_android";

    ini_filepath := sprint("%/imgui.ini\0", to_string(app.activity.internalDataPath));
    io.IniFilename = ini_filepath.data;
    
    return true;
}

ImGui_ImplAndroid_Shutdown :: () {
    io := ImGui.GetIO();
    io.BackendPlatformName = null;

    free(io.IniFilename);
}

ImGui_ImplAndroid_NewFrame :: () {
    io := ImGui.GetIO();

    // Setup display size (every frame to accommodate for window resizing)
    // Q: window_width/height are updated during Input.get_window_resizes, is that supported on Android?
    window_width  := ANativeWindow_getWidth(g_Window);
    window_height := ANativeWindow_getHeight(g_Window);
    // If there was downscaling, display_width/height would be different. Eg with software rendering?
    display_width  := window_width;
    display_height := window_height;

    io.DisplaySize = ImVec2.{cast(float)window_width, cast(float)window_height};
    if window_width > 0 && window_height > 0 {
        io.DisplayFramebufferScale = ImVec2.{cast(float)display_width / window_width, cast(float)display_height / window_height};
    }

    // Setup time step
    current_time := seconds_since_init();
    if g_Time > 0. {
        io.DeltaTime = cast(float)(current_time - g_Time);

    } else {
        io.DeltaTime = cast(float)(1.0 / 60.0);
    }
    g_Time = current_time;
}

ImGui_ImplAndroid_HandleInputEvent :: (input_event: *AInputEvent) -> bool {
    io := ImGui.GetIO();
    event_type := AInputEvent_getType(input_event);
    if event_type == {
        case .KEY;
        event_key_code   := AKeyEvent_getKeyCode(input_event);
        event_scan_code  := AKeyEvent_getScanCode(input_event);
        event_action     := AKeyEvent_getAction(input_event);
        event_meta_state := AKeyEvent_getMetaState(input_event);

        io.AddKeyEvent(io, ImGui.Key.Mod_Ctrl,  (event_meta_state & xx AMETA.CTRL_ON)  != 0);
        io.AddKeyEvent(io, ImGui.Key.Mod_Shift, (event_meta_state & xx AMETA.SHIFT_ON) != 0);
        io.AddKeyEvent(io, ImGui.Key.Mod_Alt,   (event_meta_state & xx AMETA.ALT_ON)   != 0);
        io.AddKeyEvent(io, ImGui.Key.Mod_Super, (event_meta_state & xx AMETA.META_ON)  != 0);

        if event_action == {
            // NOTE(Charles): With a software keyboard the DOWN and UP action occur on the same frame as
            // you release. I didn't realise till I tested here, but this is how all android apps with 
            // software keyboards behave. I guess it's to allow you to press and hold to do things.
            case .DOWN; #through;
            case .UP;
            key := ImGui_ImplAndroid_KeyCodeToImGuiKey(event_key_code);
            if key != ImGui.Key.None {
                io.AddKeyEvent(io, key, event_action == .DOWN);
                io.SetKeyEventNativeData(io, key, xx event_key_code, event_scan_code);

                if event_action == .DOWN {
                    unicode := to_unicode_character(event_key_code, event_meta_state);
                    io.AddInputCharacter(io, unicode);
                }
            }
        }

        case .MOTION;
        event_action := AMotionEvent_getAction(input_event);
        event_pointer_index := (cast(u64)event_action & AMOTION_EVENT_ACTION.POINTER_INDEX_MASK) >> AMOTION_EVENT_ACTION_POINTER_INDEX_SHIFT;
        event_action &= AMOTION_EVENT_ACTION.MASK;

        tool_type := AMotionEvent_getToolType(input_event, event_pointer_index);
        if tool_type == {
            case .MOUSE;
            io.AddMouseSourceEvent(io, .Mouse);

            case .STYLUS; #through;
            case .ERASER;
            io.AddMouseSourceEvent(io, .Pen);

            case .FINGER; #through;
            case;
            io.AddMouseSourceEvent(io, .TouchScreen);
        }

        if event_action == {
            case AMOTION_EVENT_ACTION.DOWN; #through;
            case AMOTION_EVENT_ACTION.UP;
            // Physical mouse buttons (and probably other physical devices) also invoke the actions AMOTION_EVENT_ACTION.DOWN/_UP,
            // but we have to process them separately to identify the actual button pressed. This is done below via
            // AMOTION_EVENT_ACTION.BUTTON_PRESS/_RELEASE. Here, we only process "FINGER" input (and "UNKNOWN", as a fallback).
            if tool_type == .FINGER || tool_type == .UNKNOWN {
                x := AMotionEvent_getX(input_event, event_pointer_index);
                y := AMotionEvent_getY(input_event, event_pointer_index);
                io.AddMousePosEvent(io, x, y);
                io.AddMouseButtonEvent(io, 0, event_action == .DOWN);

                if event_action == .UP  io.AddMousePosEvent(io, -FLOAT32_MAX, -FLOAT32_MAX);
            }

            case AMOTION_EVENT_ACTION.BUTTON_PRESS; #through;
            case AMOTION_EVENT_ACTION.BUTTON_RELEASE;
            button_state := AMotionEvent_getButtonState(input_event);
            io.AddMouseButtonEvent(io, 0, (button_state & xx AMOTION_EVENT_BUTTON.PRIMARY) != 0);
            io.AddMouseButtonEvent(io, 1, (button_state & xx AMOTION_EVENT_BUTTON.SECONDARY) != 0);
            io.AddMouseButtonEvent(io, 2, (button_state & xx AMOTION_EVENT_BUTTON.TERTIARY) != 0);

            case AMOTION_EVENT_ACTION.HOVER_MOVE; #through; // Hovering: Tool moves while NOT pressed (such as a physical mouse)
            case AMOTION_EVENT_ACTION.MOVE;                 // Touch pointer moves while DOWN
            x := AMotionEvent_getX(input_event, event_pointer_index);
            y := AMotionEvent_getY(input_event, event_pointer_index);
            io.AddMousePosEvent(io, x, y);

            case AMOTION_EVENT_ACTION.SCROLL;
            x := AMotionEvent_getAxisValue(input_event, xx AMOTION_EVENT_AXIS.HSCROLL, event_pointer_index);
            y := AMotionEvent_getAxisValue(input_event, xx AMOTION_EVENT_AXIS.VSCROLL, event_pointer_index);
            io.AddMouseWheelEvent(io, x, y);
        }
    }

    return true;
}


//
// Some stuff that ain't exposed to ndk, using JNI to call android apis. You could implement this in java and just
// expose some simpler wrappers.
//

#scope_file 

// :ImGuiBackends

// NOTE(Charles): Commenting this out to fix circular import when #loading this file and passing main to android module.
// This probably breaks any programs importing this backend as a module. But that was a bad idea anyway. What should 
// happen is: ImGui provides module code for a "jai backend", and these platform specific backend files can be provided
// in examples if people want to copy and use, but shoudlnt be importable.
// #import "Android";
#import "Basic";
using ImGui :: #import "ImGui";

g_Window: *ANativeWindow;
g_Time: float64;

// @Incomplete Hmm, this doesn't seem to work on all special characters? Maybe I'm missing something?
// nocheckin - I think this is just because the input code above doesnt call us if key code returns none!
to_unicode_character :: (key_code: AKEYCODE, meta_state: AMETA) -> u32 {
    // @Incomplete Reduce copy pasta beween here and android_show_software_keyboard, and cache any jni stuff we can.
    // This is probably woefully slow atm!

    assert(android_app != null && android_app.activity != null);
    app := android_app;

    // Get the JNIEnv associated with the thread we are being called on, creating one if necessary.
    env: *JNIEnv;
    vm := app.activity.vm;
    vm.*.AttachCurrentThread(vm, *env, null);

    KeyEvent := env.*.FindClass(env, "android/view/KeyEvent");
    check(KeyEvent, env);

    KeyEvent_Constructor := env.*.GetMethodID(env, KeyEvent, "<init>", "(II)V");
    check(KeyEvent_Constructor, env);

    getUnicodeChar := env.*.GetMethodID(env, KeyEvent, "getUnicodeChar", "(I)I");

    dummy_key_event := env.*.NewObject(env, KeyEvent, KeyEvent_Constructor, cast(s32) AKEY_EVENT_ACTION.DOWN, key_code);
    check(dummy_key_event, env);

    unicode_char := env.*.CallIntMethod(env, dummy_key_event, getUnicodeChar, meta_state);
    return cast(u32) unicode_char;
}

#import "Android/Jni";

ImGui_ImplAndroid_KeyCodeToImGuiKey :: (key_code: AKEYCODE) -> ImGui.Key {
    if key_code == {
        case .TAB;                  return ImGui.Key.Tab;
        case .DPAD_LEFT;            return ImGui.Key.LeftArrow;
        case .DPAD_RIGHT;           return ImGui.Key.RightArrow;
        case .DPAD_UP;              return ImGui.Key.UpArrow;
        case .DPAD_DOWN;            return ImGui.Key.DownArrow;
        case .PAGE_UP;              return ImGui.Key.PageUp;
        case .PAGE_DOWN;            return ImGui.Key.PageDown;
        case .MOVE_HOME;            return ImGui.Key.Home;
        case .MOVE_END;             return ImGui.Key.End;
        case .INSERT;               return ImGui.Key.Insert;
        case .FORWARD_DEL;          return ImGui.Key.Delete;
        case .DEL;                  return ImGui.Key.Backspace;
        case .SPACE;                return ImGui.Key.Space;
        case .ENTER;                return ImGui.Key.Enter;
        case .ESCAPE;               return ImGui.Key.Escape;
        case .APOSTROPHE;           return ImGui.Key.Apostrophe;
        case .COMMA;                return ImGui.Key.Comma;
        case .MINUS;                return ImGui.Key.Minus;
        case .PERIOD;               return ImGui.Key.Period;
        case .SLASH;                return ImGui.Key.Slash;
        case .SEMICOLON;            return ImGui.Key.Semicolon;
        case .EQUALS;               return ImGui.Key.Equal;
        case .LEFT_BRACKET;         return ImGui.Key.LeftBracket;
        case .BACKSLASH;            return ImGui.Key.Backslash;
        case .RIGHT_BRACKET;        return ImGui.Key.RightBracket;
        case .GRAVE;                return ImGui.Key.GraveAccent;
        case .CAPS_LOCK;            return ImGui.Key.CapsLock;
        case .SCROLL_LOCK;          return ImGui.Key.ScrollLock;
        case .NUM_LOCK;             return ImGui.Key.NumLock;
        case .SYSRQ;                return ImGui.Key.PrintScreen;
        case .BREAK;                return ImGui.Key.Pause;
        case .NUMPAD_0;             return ImGui.Key.Keypad0;
        case .NUMPAD_1;             return ImGui.Key.Keypad1;
        case .NUMPAD_2;             return ImGui.Key.Keypad2;
        case .NUMPAD_3;             return ImGui.Key.Keypad3;
        case .NUMPAD_4;             return ImGui.Key.Keypad4;
        case .NUMPAD_5;             return ImGui.Key.Keypad5;
        case .NUMPAD_6;             return ImGui.Key.Keypad6;
        case .NUMPAD_7;             return ImGui.Key.Keypad7;
        case .NUMPAD_8;             return ImGui.Key.Keypad8;
        case .NUMPAD_9;             return ImGui.Key.Keypad9;
        case .NUMPAD_DOT;           return ImGui.Key.KeypadDecimal;
        case .NUMPAD_DIVIDE;        return ImGui.Key.KeypadDivide;
        case .NUMPAD_MULTIPLY;      return ImGui.Key.KeypadMultiply;
        case .NUMPAD_SUBTRACT;      return ImGui.Key.KeypadSubtract;
        case .NUMPAD_ADD;           return ImGui.Key.KeypadAdd;
        case .NUMPAD_ENTER;         return ImGui.Key.KeypadEnter;
        case .NUMPAD_EQUALS;        return ImGui.Key.KeypadEqual;
        case .CTRL_LEFT;            return ImGui.Key.LeftCtrl;
        case .SHIFT_LEFT;           return ImGui.Key.LeftShift;
        case .ALT_LEFT;             return ImGui.Key.LeftAlt;
        case .META_LEFT;            return ImGui.Key.LeftSuper;
        case .CTRL_RIGHT;           return ImGui.Key.RightCtrl;
        case .SHIFT_RIGHT;          return ImGui.Key.RightShift;
        case .ALT_RIGHT;            return ImGui.Key.RightAlt;
        case .META_RIGHT;           return ImGui.Key.RightSuper;
        case .MENU;                 return ImGui.Key.Menu;
        case ._0;                   return ImGui.Key._0;
        case ._1;                   return ImGui.Key._1;
        case ._2;                   return ImGui.Key._2;
        case ._3;                   return ImGui.Key._3;
        case ._4;                   return ImGui.Key._4;
        case ._5;                   return ImGui.Key._5;
        case ._6;                   return ImGui.Key._6;
        case ._7;                   return ImGui.Key._7;
        case ._8;                   return ImGui.Key._8;
        case ._9;                   return ImGui.Key._9;
        case .A;                    return ImGui.Key.A;
        case .B;                    return ImGui.Key.B;
        case .C;                    return ImGui.Key.C;
        case .D;                    return ImGui.Key.D;
        case .E;                    return ImGui.Key.E;
        case .F;                    return ImGui.Key.F;
        case .G;                    return ImGui.Key.G;
        case .H;                    return ImGui.Key.H;
        case .I;                    return ImGui.Key.I;
        case .J;                    return ImGui.Key.J;
        case .K;                    return ImGui.Key.K;
        case .L;                    return ImGui.Key.L;
        case .M;                    return ImGui.Key.M;
        case .N;                    return ImGui.Key.N;
        case .O;                    return ImGui.Key.O;
        case .P;                    return ImGui.Key.P;
        case .Q;                    return ImGui.Key.Q;
        case .R;                    return ImGui.Key.R;
        case .S;                    return ImGui.Key.S;
        case .T;                    return ImGui.Key.T;
        case .U;                    return ImGui.Key.U;
        case .V;                    return ImGui.Key.V;
        case .W;                    return ImGui.Key.W;
        case .X;                    return ImGui.Key.X;
        case .Y;                    return ImGui.Key.Y;
        case .Z;                    return ImGui.Key.Z;
        case .F1;                   return ImGui.Key.F1;
        case .F2;                   return ImGui.Key.F2;
        case .F3;                   return ImGui.Key.F3;
        case .F4;                   return ImGui.Key.F4;
        case .F5;                   return ImGui.Key.F5;
        case .F6;                   return ImGui.Key.F6;
        case .F7;                   return ImGui.Key.F7;
        case .F8;                   return ImGui.Key.F8;
        case .F9;                   return ImGui.Key.F9;
        case .F10;                  return ImGui.Key.F10;
        case .F11;                  return ImGui.Key.F11;
        case .F12;                  return ImGui.Key.F12;
        case;                       return ImGui.Key.None;
    }

    return ImGui.Key.None;
}