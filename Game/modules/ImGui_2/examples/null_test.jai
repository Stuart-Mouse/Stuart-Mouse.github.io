// Port of imgui/examples/example_null to test building with imgui module without worrying about graphics or input.
//
// To compile on android use jai null_test.jai -plug Toolchains/Android [-arm64]
// 

using ImGui :: #import "ImGui";

main :: () {
    print("----- Starting imgui null test -----\n");

    IMGUI_CHECKVERSION();

    ImGui.CreateContext();
    io := ImGui.GetIO();

    // Build atlas
    tex_pixels: *u8;
    tex_w, tex_h: s32;
    io.Fonts.GetTexDataAsRGBA32(io.Fonts, *tex_pixels, *tex_w, *tex_h);

    for 0..20 {
        print("NewFrame() %\n", it);
        io.DisplaySize = ImVec2.{1920, 1080};
        io.DeltaTime = 1. / 60.;
        ImGui.NewFrame();

        ImGui.Text("Hello, world!");
        ImGui.SliderFloat("float", *slider_value, 0., 1.);
        ImGui.Text("Application average % ms/frame (% FPS)", formatFloat(1000. / io.Framerate, trailing_width=3), formatFloat(io.Framerate, trailing_width=1));
        ImGui.ShowDemoWindow();

        ImGui.Render();
    }

    print("DestroyContext()\n");
    ImGui.DestroyContext();

    print("\n----- Finishing imgui null test -----\n");
}

slider_value := 0.;

#import "Basic";

#if OS == .ANDROID  #import "Android"()(main);
