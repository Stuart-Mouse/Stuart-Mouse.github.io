// NOTE(Charles): As a quickstart, I wanted to just have a window proc that calls ImGui_ImplWin32_WndProcHandler,
// first, and then forwards to Input.MyWindowProc. This doesn't appear to be possible while using Window_Creation
// however, as importing Input will add the _windows_windowproc thing Window_Creation looks at?
//
// It would be pretty simple to get this to work if made changes to Window_Creation, or Input, but without doing so I don't
// see a way!
#add_context _windows_windowproc :: MyWindowProc;


// Win32 message handler copied from example_win32_opengl3.
// @TODO: Before worrying about how to use Input windows proc and imgui window proc like talking about above, need to 
// fix this, something is mega broken!
MyWindowProc :: (hwnd: HWND, message: u32, wParam: WPARAM, lParam: LPARAM) -> s64 #c_call {
    new_context: Context;
    push_context,defer_pop new_context; // Reuse runtime support context?

    if ImGui_ImplWin32_WndProcHandler(hwnd, message, wParam, lParam)  return 1;

    handled := false;
    if message == {
        case WM_SIZE;
        if wParam != SIZE_MINIMIZED
        {
            size := cast(u32) lParam;
            width  := size & 0xFFFF;
            height := size >> 16;
            handle_window_resize(hwnd, xx width, xx height);
        }
        handled = true;

        case WM_SYSCOMMAND;
        if (wParam & 0xfff0) == SC_KEYMENU {  // Disable ALT application menu
            handled = true;
        }

        case WM_DESTROY;
        PostQuitMessage(0);
        handled = true;
    }

    if !handled  return DefWindowProcW(hwnd, message, wParam, lParam);

    return 0;
}
