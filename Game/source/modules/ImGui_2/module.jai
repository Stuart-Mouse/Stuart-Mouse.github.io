//
// Bindings for Dear ImGui. And an optional jai "backend"
//

// @TODO(Charles): Add support for docking branch (with module/program param), seems useful enough to have bindings by default.

// nocheckin Sort out the backend situation
#module_parameters()(USE_JAI_BACKEND := false); // Program paramater atm due to the @Hacks with existing backends being importable and loadable. @TODO: Fix that junk!

#if USE_JAI_BACKEND {
    #load "backend.jai";
}

ImVec2      :: Vector2;
ImVec4      :: Vector4;
ImColor     :: Vector4;

ImVector :: struct (T: Type) {
    Size: s32;
    Capacity: s32;
    Data: *T;
}

ImDrawCallback :: #type (parent_list: *ImDrawList, cmd: *ImDrawCmd) #c_call;

IMGUI_CHECKVERSION :: () #expand {
    DebugCheckVersionAndDataLayout(IMGUI_VERSION, size_of(IO), size_of(Style), size_of(ImVec2), size_of(ImVec4), size_of(ImDrawVert), size_of(ImDrawIdx));
}

#scope_module

#import "Basic";
#import "Math";

#if OS == .WINDOWS {
    #load "windows.jai";
    
    #scope_file
    user32 :: #system_library,link_always "user32"; // Needed by imgui unless ImGui is compiled it with "IMGUI_DISABLE_WIN32_DEFAULT_CLIPBOARD_FUNCS"
} else {
    #load "unix.jai";
}

// We get unresolved symbol errors without this. Not tested on mac, maybe it is needed there too?
#if OS == .ANDROID || OS == .LINUX {
    #library,system,link_always "libm";
}

