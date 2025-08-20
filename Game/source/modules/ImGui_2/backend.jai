//
// A "backend" using jai module code.
//

ImGui_ImplJai_Init :: (window: Window_Type) -> bool {
    io := GetIO();
    assert(io.BackendPlatformUserData == null, "Already initialized a platform backend!");

    // Setup backend capabilities flags
    io.BackendPlatformUserData = cast(*void)*bd;
    io.BackendPlatformName = "imgui_impl_jai";

    bd.window = window;
    bd.time = seconds_since_init();

    // Set platform dependent data in viewport
    GetMainViewport().PlatformHandleRaw = xx window;

    return true;
}

ImGui_ImplJai_NewFrame :: () {
    io := GetIO();
    assert(*bd == io.BackendPlatformUserData, "Did you call ImGui_ImplJai_Init()?");
    
    right_handed := false;
    
    // Setup display size (every frame to accommodate for window resizing)
    _, _, width, height := get_dimensions(bd.window, right_handed);
    io.DisplaySize = ImVec2.{cast(float) width, cast(float) height};

    // Update time step
    current_time := seconds_since_init();
    io.DeltaTime = cast(float)(current_time - bd.time);
    bd.time = current_time;
    
    // Provide mouse position. modules/Input only gives us delta so this isn't done with other input code.
    {
        x, y, success := get_mouse_pointer_position(bd.window, right_handed);
        if success {
            io.AddMousePosEvent(io, cast(float) x, cast(float) y);
        }
    }
}


#scope_file

ImplJai_Data :: struct {
    window: Window_Type;
    time: float64;
};
bd: ImplJai_Data;

#import "Basic";
#import "Window_Creation";
// #import "Window_Type";
