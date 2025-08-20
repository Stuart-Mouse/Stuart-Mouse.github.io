// OpenGL Data
ImGui_ImplOpenGL3_Data :: struct {
    GlVersion: GLuint;          // Extracted at runtime using GL_MAJOR_VERSION, GL_MINOR_VERSION queries (e.g. 320 for GL 3.2)
    GlslVersionString: string;  // Specified by user or detected based on compile time GL settings.
    GlProfileIsES2: bool;
    GlProfileIsES3: bool;
    GlProfileIsCompat: bool;
    GlProfileMask: GLint;
    FontTexture: GLuint;
    ShaderHandle: GLuint;
    AttribLocationTex: GLint;       // Uniforms location
    AttribLocationProjMtx: GLint;
    AttribLocationVtxPos: GLuint;    // Vertex attributes location
    AttribLocationVtxUV: GLuint;
    AttribLocationVtxColor: GLuint;
    VboHandle, ElementsHandle: u32;
    VertexBufferSize: GLsizeiptr;
    IndexBufferSize: GLsizeiptr;
    HasClipOrigin: bool;
    UseBufferSubData: bool;
};

IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY :: true;
IMGUI_IMPL_HAS_POLYGON_MODE                  :: !GLES;
IMGUI_IMPL_OPENGL_MAY_HAVE_VTX_OFFSET        :: !GLES;
IMGUI_IMPL_OPENGL_MAY_HAVE_EXTENSIONS        :: !GLES;
IMGUI_IMPL_OPENGL_MAY_HAVE_BIND_SAMPLER      :: !GLES; // glBindSampler also not available on desktop < 3.3. But simp has 3.3 as minimum so should be good!
IMGUI_IMPL_OPENGL_MAY_HAVE_PRIMITIVE_RESTART :: !GLES;

ImGui_ImplOpenGL3_Init :: (glsl_version := "") -> bool
{
    io := ImGui.GetIO();
    assert(io.BackendRendererUserData == null , "Already initialized a renderer backend!");

    // Setup backend capabilities flags
    io.BackendRendererUserData = cast(*void)*bd_gl3;
    io.BackendRendererName = "imgui_impl_opengl3";

    // Query for GL version (e.g. 320 for GL 3.2)
    major, minor: GLint;
    glGetIntegerv(GL_MAJOR_VERSION, *major);
    glGetIntegerv(GL_MINOR_VERSION, *minor);
    #if GLES {
        // bd_gl3.GlVersion = 200; // GLES 2
        // bd_gl3.GlProfileIsES2 = true;

        // NOTE(Charles): No idea why the GLES path doesn't use the queried for versions?
        bd_gl3.GlVersion = 200; // Don't raise version as it is intended as a desktop version check for now.
        bd_gl3.GlProfileIsES3 = true;

    } else {
        assert(!(major == 0 && minor == 0));
        bd_gl3.GlVersion = cast(GLuint)(major * 100 + minor * 10);

        glGetIntegerv(GL_CONTEXT_PROFILE_MASK, *bd_gl3.GlProfileMask);
        bd_gl3.GlProfileIsCompat = (bd_gl3.GlProfileMask & GL_CONTEXT_COMPATIBILITY_PROFILE_BIT) != 0;
    }

    // NOTE: Simp requests min version of 3.3. See MINIMUM_GL_MAJOR_VERSION
    print("[ImGui] GL_MAJOR_VERSION = %\nGL_MINOR_VERSION = %\nGL_VENDOR = '%'\nGL_RENDERER = '%'\n", major, minor, to_string(glGetString(GL_VENDOR)), to_string(glGetString(GL_RENDERER)));

    #if IMGUI_IMPL_OPENGL_MAY_HAVE_VTX_OFFSET {
        if bd_gl3.GlVersion >= 320  io.BackendFlags_ |= .RendererHasVtxOffset;  // We can honor the ImDrawCmd::VtxOffset field, allowing for large meshes.
    }

    // Store GLSL version string so we can refer to it later in case we recreate shaders.
    // Note: GLSL version is NOT the same as GL version. Leave this to null if unsure.
    if glsl_version {
        bd_gl3.GlslVersionString = glsl_version;
    } else {
        #if GLES {
            // bd_gl3.GlslVersionString = "#version 100\n"; // GLES 2
            bd_gl3.GlslVersionString = "#version 300 es\n";

        } else {
            #if OS == .MACOS {
                bd_gl3.GlslVersionString = "#version 150\n"; // @Untested
            } else {
                bd_gl3.GlslVersionString = "#version 130\n";
            }
        }
    }

    // Make an arbitrary GL call (we don't actually need the result)
    // IF YOU GET A CRASH HERE: it probably means the OpenGL function loader didn't do its job. Let us know!
    current_texture: GLint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, *current_texture);

    // Detect extensions we support
    bd_gl3.HasClipOrigin = bd_gl3.GlVersion >= 450;

    #if IMGUI_IMPL_OPENGL_MAY_HAVE_EXTENSIONS {
        num_extensions: GLint;
        glGetIntegerv(GL_NUM_EXTENSIONS, *num_extensions);
        for 0..num_extensions-1 {
            extension := to_string(glGetStringi(GL_EXTENSIONS, xx it));
            if extension == "GL_ARB_clip_control" {
                bd_gl3.HasClipOrigin = true;
            }
        }
    }

    return true;

    // return ImGui_ImplOpenGL3_CreateDeviceObjects();
}

ImGui_ImplOpenGL3_NewFrame :: () {
    // bd := ImGui_ImplOpenGL3_GetBackendData().(*ImGui_ImplOpenGL3_Data);
    // assert(bd != null && "Did you call ImGui_ImplOpenGL3_Init()?");
    io := ImGui.GetIO();
    io.DisplaySize.x = xx WINDOW_WIDTH;
    io.DisplaySize.y = xx WINDOW_HEIGHT;
    
    if !bd_gl3.ShaderHandle {
        ImGui_ImplOpenGL3_CreateDeviceObjects();
    }
}

#if GLES {
    // vertex_shader_glsl_300_es
    VERTEX_SHADER :: #string GLSL
    precision highp float;
    layout (location = 0) in vec2 Position;
    layout (location = 1) in vec2 UV;
    layout (location = 2) in vec4 Color;
    uniform mat4 ProjMtx;
    out vec2 Frag_UV;
    out vec4 Frag_Color;
    void main()
    {
        Frag_UV = UV;
        Frag_Color = Color;
        gl_Position = ProjMtx * vec4(Position.xy,0,1);
    }
    GLSL

    // fragment_shader_glsl_300_es
    FRAGMENT_SHADER :: #string GLSL
    precision mediump float;
    uniform sampler2D Texture;
    in vec2 Frag_UV;
    in vec4 Frag_Color;
    layout (location = 0) out vec4 Out_Color;
    void main()
    {
        Out_Color = Frag_Color * texture(Texture, Frag_UV.st);
    }
    GLSL

} else {
    // vertex_shader_glsl_130
    VERTEX_SHADER :: #string GLSL
    uniform mat4 ProjMtx;
    in vec2 Position;
    in vec2 UV;
    in vec4 Color;
    out vec2 Frag_UV;
    out vec4 Frag_Color;
    void main()
    {
        Frag_UV = UV;
        Frag_Color = Color;
        gl_Position = ProjMtx * vec4(Position.xy,0,1);
    }
    GLSL

    // fragment_shader_glsl_130
    FRAGMENT_SHADER :: #string GLSL
    uniform sampler2D Texture;
    in vec2 Frag_UV;
    in vec4 Frag_Color;
    out vec4 Out_Color;
    void main()
    {
        Out_Color = Frag_Color * texture(Texture, Frag_UV.st);
    }
    GLSL
}

ImGui_ImplOpenGL3_CreateDeviceObjects :: () -> bool
{
    // Cpp reference uses ImGui_ImplOpenGL3_GetBackendData to get the pointer from the IO thing so that it
    // is possible to have multiple ImGui contexts. I am just using the one global.
    io := ImGui.GetIO();
    assert(io.BackendRendererUserData == xx *bd_gl3);

    // Backup GL state
    last_texture, last_array_buffer: GLint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, *last_texture);
    glGetIntegerv(GL_ARRAY_BUFFER_BINDING, *last_array_buffer);
    #if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
        last_vertex_array:  GLint;
        glGetIntegerv(GL_VERTEX_ARRAY_BINDING, *last_vertex_array);
    }

    // Restore modified GL state
    defer {
        glBindTexture(GL_TEXTURE_2D,  cast(GLuint) last_texture);
        glBindBuffer(GL_ARRAY_BUFFER, cast(GLuint) last_array_buffer);
        #if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
            glBindVertexArray(cast(GLuint) last_vertex_array);
        }
    }

    // Cpp reference supports a bunch of older gl versions and dynamically selects one. I am not.

    // @CopyPasta from Simp. A lot of the below is basically the same as Simp and could be simplified.
    // Leaving as is for now as just getting ImGui stuff working!

    LOG_BUFFER_SIZE :: 512;
    CheckShader :: (shader_object: GLuint) -> bool {
        success: GLint;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);

        if !success {
            log_data: [LOG_BUFFER_SIZE] u8;
            glGetShaderInfoLog(shader_object, log_data.count, null, log_data.data);
            log_error("%", to_string(log_data.data), flags=.ERROR);

            return false;
        }

        return true;
    }

    CheckProgram :: (shader_object: GLuint) -> bool {
        success: GLint;
        glGetProgramiv(shader_object, GL_LINK_STATUS, *success);

        if !success {
            log_data: [LOG_BUFFER_SIZE] u8;
            glGetProgramInfoLog(shader_object, log_data.count, null, log_data.data);
            log_error("%", to_string(log_data.data));

            return false;
        }

        return true;
    }

    vertex_shader_with_version         := *u8.[bd_gl3.GlslVersionString.data, VERTEX_SHADER.data];
    vertex_shader_with_version_lengths := s32.[xx bd_gl3.GlslVersionString.count, xx VERTEX_SHADER.count];
    vert_handle := glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vert_handle, 2, vertex_shader_with_version.data, vertex_shader_with_version_lengths.data);
    glCompileShader(vert_handle);
    vert_shader_success := CheckShader(vert_handle);

    fragment_shader_with_version         := *u8.[bd_gl3.GlslVersionString.data, FRAGMENT_SHADER.data];
    fragment_shader_with_version_lengths := s32.[xx bd_gl3.GlslVersionString.count, xx FRAGMENT_SHADER.count];
    frag_handle := glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(frag_handle, 2, fragment_shader_with_version.data, fragment_shader_with_version_lengths.data);
    glCompileShader(frag_handle);
    frag_shader_success := CheckShader(frag_handle);

    // Link
    bd_gl3.ShaderHandle = glCreateProgram();
    glAttachShader(bd_gl3.ShaderHandle, vert_handle);
    glAttachShader(bd_gl3.ShaderHandle, frag_handle);
    glLinkProgram(bd_gl3.ShaderHandle);
    check_program_success := CheckProgram(bd_gl3.ShaderHandle);

    glDetachShader(bd_gl3.ShaderHandle, vert_handle);
    glDetachShader(bd_gl3.ShaderHandle, frag_handle);
    glDeleteShader(vert_handle);
    glDeleteShader(frag_handle);

    if check_program_success {
        bd_gl3.AttribLocationTex      = glGetUniformLocation(bd_gl3.ShaderHandle, "Texture");
        bd_gl3.AttribLocationProjMtx  = glGetUniformLocation(bd_gl3.ShaderHandle, "ProjMtx");
        // These casts will fail abc if the shaders fail to compile
        bd_gl3.AttribLocationVtxPos   = cast(GLuint) glGetAttribLocation(bd_gl3.ShaderHandle, "Position");
        bd_gl3.AttribLocationVtxUV    = cast(GLuint) glGetAttribLocation(bd_gl3.ShaderHandle, "UV");
        bd_gl3.AttribLocationVtxColor = cast(GLuint) glGetAttribLocation(bd_gl3.ShaderHandle, "Color");
    } else {
        log_error("ImGui shader program error. See above logs.");        
    }

    // Create buffers
    glGenBuffers(1, *bd_gl3.VboHandle);
    glGenBuffers(1, *bd_gl3.ElementsHandle);

    // ImGui_ImplOpenGL3_CreateFontsTexture();
    {
        // Build texture atlas
        pixels: *u8;
        width, height: s32;
        io.Fonts.GetTexDataAsRGBA32(io.Fonts, *pixels, *width, *height);    // Load as RGBA 32-bit (75% of the memory is wasted, but default font is so small) because it is more likely to be compatible with user's existing shaders. If your ImTextureId represent a higher-level concept than just a GL texture id, consider calling GetTexDataAsAlpha8() instead to save on GPU memory.

        // Cpp reference wraps calls in macro to report errors on site. I have skipped that.
        
        // Upload texture to graphics system
        // (Bilinear sampling is required by default. Set 'io.Fonts->Flags |= ImFontAtlasFlags_NoBakedLines' or 'style.AntiAliasedLinesUseTex = false' to allow point/nearest sampling)

        // Preserve current state
        last_texture: GLint;
        GL_CALL(glGetIntegerv(GL_TEXTURE_BINDING_2D, *last_texture));
        defer GL_CALL(glBindTexture(GL_TEXTURE_2D, cast(GLuint) last_texture));

        GL_CALL(glGenTextures(1, *bd_gl3.FontTexture));
        GL_CALL(glBindTexture(GL_TEXTURE_2D, bd_gl3.FontTexture));
        GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR));
        GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR));
        // Cpp reference claims this isn't on WebGl/ES but looks like it is to me?
        // #if !GLES
        {
            GL_CALL(glPixelStorei(GL_UNPACK_ROW_LENGTH, 0));
        }
        GL_CALL(glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx width, xx height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels));

        // Store our identifier
        io.Fonts.TexID = cast(u64)bd_gl3.FontTexture;
    }

    return true;
}

// OpenGL3 Render function.
// Note that this implementation is little overcomplicated because we are saving/setting up/restoring every OpenGL state explicitly.
// This is in order to be able to run within an OpenGL engine that doesn't do so.
// NOTE(Charles): As indicated by above comment, there is almost certainly a log of redundancy in here. For a simp app,
// which is what I am working with atm, probably all that is necessary is to make sure we flush simp before doing
// imgui gl calls.
ImGui_ImplOpenGL3_RenderDrawData :: (draw_data: *ImDrawData) {

    // Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
    fb_width  := cast(s32)(draw_data.DisplaySize.x * draw_data.FramebufferScale.x);
    fb_height := cast(s32)(draw_data.DisplaySize.y * draw_data.FramebufferScale.y);
    if fb_width <= 0 || fb_height <= 0  return;

    // Backup and restore GL state
    last_active_texture: GLenum; glGetIntegerv(GL_ACTIVE_TEXTURE, cast(*GLint)*last_active_texture);
    glActiveTexture(GL_TEXTURE0);
    last_program: GLuint; glGetIntegerv(GL_CURRENT_PROGRAM, cast(*GLint)*last_program);
    last_texture: GLuint; glGetIntegerv(GL_TEXTURE_BINDING_2D, cast(*GLint)*last_texture);
    #if IMGUI_IMPL_OPENGL_MAY_HAVE_BIND_SAMPLER {
        last_sampler: GLuint;
        if bd_gl3.GlVersion >= 330 || bd_gl3.GlProfileIsES3 {
            glGetIntegerv(GL_SAMPLER_BINDING, cast(*GLint)*last_sampler);
        }
    }
    last_array_buffer: GLuint; glGetIntegerv(GL_ARRAY_BUFFER_BINDING, cast(*GLint)*last_array_buffer);

    #if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
        last_vertex_array_object: GLuint; glGetIntegerv(GL_VERTEX_ARRAY_BINDING, cast(*GLint)*last_vertex_array_object);

    } else {
        #assert false "If want to support GLES 2, or Web GL need to do something here";
        // // This is part of VAO on OpenGL 3.0+ and OpenGL ES 3.0+.
        // GLint last_element_array_buffer; glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, *last_element_array_buffer);
        // ImGui_ImplOpenGL3_VtxAttribState last_vtx_attrib_state_pos; last_vtx_attrib_state_pos.GetState(bd_gl3.AttribLocationVtxPos);
        // ImGui_ImplOpenGL3_VtxAttribState last_vtx_attrib_state_uv; last_vtx_attrib_state_uv.GetState(bd_gl3.AttribLocationVtxUV);
        // ImGui_ImplOpenGL3_VtxAttribState last_vtx_attrib_state_color; last_vtx_attrib_state_color.GetState(bd_gl3.AttribLocationVtxColor);
    }

    #if IMGUI_IMPL_HAS_POLYGON_MODE {
        last_polygon_mode: [2] GLint; glGetIntegerv(GL_POLYGON_MODE, last_polygon_mode.data);
    }

    last_viewport: [4] GLint;    glGetIntegerv(GL_VIEWPORT   , last_viewport.data);
    last_scissor_box: [4] GLint; glGetIntegerv(GL_SCISSOR_BOX, last_scissor_box.data);
    last_blend_src_rgb: GLenum; glGetIntegerv(GL_BLEND_SRC_RGB, cast(*GLint)*last_blend_src_rgb);
    last_blend_dst_rgb: GLenum; glGetIntegerv(GL_BLEND_DST_RGB, cast(*GLint)*last_blend_dst_rgb);
    last_blend_src_alpha: GLenum; glGetIntegerv(GL_BLEND_SRC_ALPHA, cast(*GLint)*last_blend_src_alpha);
    last_blend_dst_alpha: GLenum; glGetIntegerv(GL_BLEND_DST_ALPHA, cast(*GLint)*last_blend_dst_alpha);
    last_blend_equation_rgb: GLenum; glGetIntegerv(GL_BLEND_EQUATION_RGB, cast(*GLint)*last_blend_equation_rgb);
    last_blend_equation_alpha: GLenum; glGetIntegerv(GL_BLEND_EQUATION_ALPHA, cast(*GLint)*last_blend_equation_alpha);
    last_enable_blend        := glIsEnabled(GL_BLEND);
    last_enable_cull_face    := glIsEnabled(GL_CULL_FACE);
    last_enable_depth_test   := glIsEnabled(GL_DEPTH_TEST);
    last_enable_stencil_test := glIsEnabled(GL_STENCIL_TEST);
    last_enable_scissor_test := glIsEnabled(GL_SCISSOR_TEST);

    #if IMGUI_IMPL_OPENGL_MAY_HAVE_PRIMITIVE_RESTART {
        last_enable_primitive_restart := GL_FALSE;
        if bd_gl3.GlVersion >= 310 {
            last_enable_primitive_restart = glIsEnabled(GL_PRIMITIVE_RESTART);
        }
    }

    defer {
        // Restore modified GL state
        // This "glIsProgram()" check is required because if the program is "pending deletion" at the time of binding backup, it will have been deleted by now and will cause an OpenGL error. See #6220.
        if last_program == 0 || glIsProgram(last_program) glUseProgram(last_program);
        glBindTexture(GL_TEXTURE_2D, last_texture);
        #if IMGUI_IMPL_OPENGL_MAY_HAVE_BIND_SAMPLER {
            if bd_gl3.GlVersion >= 330 || bd_gl3.GlProfileIsES3  glBindSampler(0, last_sampler);
        }
        glActiveTexture(last_active_texture);
        #if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
            glBindVertexArray(last_vertex_array_object);

        } else {
            #assert false "If want to support GLES 2, or Web GL need to do something here";
            // glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, last_element_array_buffer);
            // last_vtx_attrib_state_pos.SetState(bd_gl3.AttribLocationVtxPos);
            // last_vtx_attrib_state_uv.SetState(bd_gl3.AttribLocationVtxUV);
            // last_vtx_attrib_state_color.SetState(bd_gl3.AttribLocationVtxColor);
        }
        glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
        glBlendEquationSeparate(last_blend_equation_rgb, last_blend_equation_alpha);
        glBlendFuncSeparate(last_blend_src_rgb, last_blend_dst_rgb, last_blend_src_alpha, last_blend_dst_alpha);
        if last_enable_blend        glEnable(GL_BLEND);        else glDisable(GL_BLEND);
        if last_enable_cull_face    glEnable(GL_CULL_FACE);    else glDisable(GL_CULL_FACE);
        if last_enable_depth_test   glEnable(GL_DEPTH_TEST);   else glDisable(GL_DEPTH_TEST);
        if last_enable_stencil_test glEnable(GL_STENCIL_TEST); else glDisable(GL_STENCIL_TEST);
        if last_enable_scissor_test glEnable(GL_SCISSOR_TEST); else glDisable(GL_SCISSOR_TEST);
        #if IMGUI_IMPL_OPENGL_MAY_HAVE_PRIMITIVE_RESTART {
            if bd_gl3.GlVersion >= 310 {
                if last_enable_primitive_restart glEnable(GL_PRIMITIVE_RESTART); else glDisable(GL_PRIMITIVE_RESTART);
            }
        }

        #if IMGUI_IMPL_HAS_POLYGON_MODE {
            // Desktop OpenGL 3.0 and OpenGL 3.1 had separate polygon draw modes for front-facing and back-facing faces of polygons
            if bd_gl3.GlVersion <= 310 || bd_gl3.GlProfileIsCompat {
                glPolygonMode(GL_FRONT, cast(GLenum)last_polygon_mode[0]);
                glPolygonMode(GL_BACK , cast(GLenum)last_polygon_mode[1]);

            } else {
                glPolygonMode(GL_FRONT_AND_BACK, cast(GLenum)last_polygon_mode[0]);
            }
        }

        glViewport(last_viewport[0], last_viewport[1], cast(GLsizei)last_viewport[2], cast(GLsizei)last_viewport[3]);
        glScissor(last_scissor_box[0], last_scissor_box[1], cast(GLsizei)last_scissor_box[2], cast(GLsizei)last_scissor_box[3]);
    }

    // Setup desired GL state
    // Recreate the VAO every time (this is to easily allow multiple GL contexts to be rendered to. VAO are not shared among GL contexts)
    // The renderer would actually work without any VAO bound, but then our VertexAttrib calls would overwrite the default one currently bound.
    vertex_array_object: GLuint;
    #if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
        GL_CALL(glGenVertexArrays(1, *vertex_array_object));
        defer GL_CALL(glDeleteVertexArrays(1, *vertex_array_object));
    }
    ImGui_ImplOpenGL3_SetupRenderState(draw_data, fb_width, fb_height, vertex_array_object);

    // Will project scissor/clipping rectangles into framebuffer space
    clip_off   := draw_data.DisplayPos;       // (0,0) unless using multi-viewports
    clip_scale := draw_data.FramebufferScale; // (1,1) unless using retina display which are often (2,2)

    // Render command lists
    for n: 0..draw_data.CmdListsCount-1 {
        cmd_list := draw_data.CmdLists.Data[n];

        // Upload vertex/index buffers
        // - OpenGL drivers are in a very sorry state nowadays....
        //   During 2021 we attempted to switch from glBufferData() to orphaning+glBufferSubData() following reports
        //   of leaks on Intel GPU when using multi-viewports on Windows.
        // - After this we kept hearing of various display corruptions issues. We started disabling on non-Intel GPU, but issues still got reported on Intel.
        // - We are now back to using exclusively glBufferData(). So bd_gl3.UseBufferSubData IS ALWAYS FALSE in this code.
        //   We are keeping the old code path for a while in case people finding new issues may want to test the bd_gl3.UseBufferSubData path.
        // - See https://github.com/ocornut/imgui/issues/4468 and please report any corruption issues.
        vtx_buffer_size := cast(GLsizeiptr)cmd_list.VtxBuffer.Size * size_of(ImDrawVert);
        idx_buffer_size := cast(GLsizeiptr)cmd_list.IdxBuffer.Size * size_of(ImDrawIdx);
        if bd_gl3.UseBufferSubData {
            if bd_gl3.VertexBufferSize < vtx_buffer_size {
                bd_gl3.VertexBufferSize = vtx_buffer_size;
                GL_CALL(glBufferData(GL_ARRAY_BUFFER, bd_gl3.VertexBufferSize, null, GL_STREAM_DRAW));
            }

            if bd_gl3.IndexBufferSize < idx_buffer_size {
                bd_gl3.IndexBufferSize = idx_buffer_size;
                GL_CALL(glBufferData(GL_ELEMENT_ARRAY_BUFFER, bd_gl3.IndexBufferSize, null, GL_STREAM_DRAW));
            }

            GL_CALL(glBufferSubData(GL_ARRAY_BUFFER, 0, vtx_buffer_size, cast(*void)cmd_list.VtxBuffer.Data));
            GL_CALL(glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, 0, idx_buffer_size, cast(*void)cmd_list.IdxBuffer.Data));
        }
        else
        {
            GL_CALL(glBufferData(GL_ARRAY_BUFFER, vtx_buffer_size, cast(*void)cmd_list.VtxBuffer.Data, GL_STREAM_DRAW));
            GL_CALL(glBufferData(GL_ELEMENT_ARRAY_BUFFER, idx_buffer_size, cast(*void)cmd_list.IdxBuffer.Data, GL_STREAM_DRAW));
        }

        for cmd_i: 0..cmd_list.CmdBuffer.Size-1 {
            pcmd := *cmd_list.CmdBuffer.Data[cmd_i]; // ImVector::operator[] has bounds checking in c++

            if pcmd.UserCallback {
                // User callback, registered via ImDrawList::AddCallback()
                // (ImDrawCallback_ResetRenderState is a special callback value used by the user to request the renderer to reset render state.)
                // if pcmd.UserCallback == xx -8 {
                //     ImGui_ImplOpenGL3_SetupRenderState(draw_data, fb_width, fb_height, vertex_array_object);
                // } else {
                    pcmd.UserCallback(cmd_list, pcmd);
                // }
            } else {
                // Project scissor/clipping rectangles into framebuffer space
                clip_min := ImVec2.{(pcmd.ClipRect.x - clip_off.x) * clip_scale.x, (pcmd.ClipRect.y - clip_off.y) * clip_scale.y};
                clip_max := ImVec2.{(pcmd.ClipRect.z - clip_off.x) * clip_scale.x, (pcmd.ClipRect.w - clip_off.y) * clip_scale.y};
                if clip_max.x <= clip_min.x || clip_max.y <= clip_min.y   continue;

                // Apply scissor/clipping rectangle (Y is inverted in OpenGL)
                GL_CALL(glScissor(cast(s32)clip_min.x, cast(s32)(fb_height - clip_max.y), cast(u32)(clip_max.x - clip_min.x), cast(u32)(clip_max.y - clip_min.y)));

                // Bind texture, Draw
                GL_CALL(glBindTexture(GL_TEXTURE_2D, cast(GLuint) pcmd.TextureId));

                type    := cast(GLenum)(ifx size_of(ImDrawIdx) == 2 then GL_UNSIGNED_SHORT else GL_UNSIGNED_INT);
                indices := cast(*void)(pcmd.IdxOffset * size_of(ImDrawIdx));
                if IMGUI_IMPL_OPENGL_MAY_HAVE_VTX_OFFSET && bd_gl3.GlVersion >= 320 {
                    GL_CALL(glDrawElementsBaseVertex(GL_TRIANGLES, cast(GLsizei)pcmd.ElemCount, type, indices, cast(GLint)pcmd.VtxOffset));

                } else {
                    GL_CALL(glDrawElements(GL_TRIANGLES, cast(GLsizei)pcmd.ElemCount, type, indices));
                }
            }
        }
    }
}

ImGui_ImplOpenGL3_SetupRenderState :: (draw_data: *ImDrawData, fb_width: int, fb_height: int, vertex_array_object: GLuint)
{
    // Setup render state: alpha-blending enabled, no face culling, no depth testing, scissor enabled, polygon fill
    glEnable(GL_BLEND);
    glBlendEquation(GL_FUNC_ADD);
    glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_STENCIL_TEST);
    glEnable(GL_SCISSOR_TEST);

    #if IMGUI_IMPL_OPENGL_MAY_HAVE_PRIMITIVE_RESTART {
        if bd_gl3.GlVersion >= 310  glDisable(GL_PRIMITIVE_RESTART);
    }

    #if IMGUI_IMPL_HAS_POLYGON_MODE {
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    }

    // Support for GL 4.5 rarely used glClipControl(GL_UPPER_LEFT)
    #if !GLES {
        clip_origin_lower_left := true;
        if bd_gl3.HasClipOrigin {
            current_clip_origin: GLenum;
            glGetIntegerv(GL_CLIP_ORIGIN, cast(*GLint)*current_clip_origin);
            if current_clip_origin == GL_UPPER_LEFT  clip_origin_lower_left = false;
        }
    }

    // Setup viewport, orthographic projection matrix
    // Our visible imgui space lies from draw_data.DisplayPos (top left) to draw_data.DisplayPos+data_data->DisplaySize (bottom right). DisplayPos is (0,0) for single viewport apps.
    GL_CALL(glViewport(0, 0, cast(GLsizei)fb_width, cast(GLsizei)fb_height));
    L := draw_data.DisplayPos.x;
    R := draw_data.DisplayPos.x + draw_data.DisplaySize.x;
    T := draw_data.DisplayPos.y;
    B := draw_data.DisplayPos.y + draw_data.DisplaySize.y;
    #if !GLES {
        if !clip_origin_lower_left {
            // Swap top and bottom if origin is upper left
            tmp := T;
            T = B;
            B = tmp;
        }
    }

    ortho_projection : [4][4] float = .[
        .[ 2.0/(R-L),    0.0,          0.0,   0.0 ],
        .[ 0.0,          2.0/(T-B),    0.0,   0.0 ],
        .[ 0.0,          0.0,         -1.0,   0.0 ],
        .[ (R+L)/(L-R),  (T+B)/(B-T),  0.0,   1.0 ],
    ];
    glUseProgram(bd_gl3.ShaderHandle);
    glUniform1i(bd_gl3.AttribLocationTex, 0);
    glUniformMatrix4fv(bd_gl3.AttribLocationProjMtx, 1, GL_FALSE, *ortho_projection[0][0]);

    #if IMGUI_IMPL_OPENGL_MAY_HAVE_BIND_SAMPLER {
        if bd_gl3.GlVersion >= 330 || bd_gl3.GlProfileIsES3 {
            // We use combined texture/sampler state. Applications using GL 3.3 and GL ES 3.0 may set that otherwise.
            glBindSampler(0, 0);
        }
    }

    #if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
        glBindVertexArray(vertex_array_object);
    }

    // Bind vertex/index buffers and setup attributes for ImDrawVert
    GL_CALL(glBindBuffer(GL_ARRAY_BUFFER, bd_gl3.VboHandle));
    GL_CALL(glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bd_gl3.ElementsHandle));
    GL_CALL(glEnableVertexAttribArray(bd_gl3.AttribLocationVtxPos));
    GL_CALL(glEnableVertexAttribArray(bd_gl3.AttribLocationVtxUV));
    GL_CALL(glEnableVertexAttribArray(bd_gl3.AttribLocationVtxColor));

    stride := cast(u32) size_of(ImDrawVert);
    offset :: cast(*ImDrawVert)null;
    GL_CALL(glVertexAttribPointer(bd_gl3.AttribLocationVtxPos,   2, GL_FLOAT,         GL_FALSE, stride, cast(*void)*offset.pos));
    GL_CALL(glVertexAttribPointer(bd_gl3.AttribLocationVtxUV,    2, GL_FLOAT,         GL_FALSE, stride, cast(*void)*offset.uv ));
    GL_CALL(glVertexAttribPointer(bd_gl3.AttribLocationVtxColor, 4, GL_UNSIGNED_BYTE, GL_TRUE , stride, cast(*void)*offset.col));

    // Test GL_CALL macro.
    // GL_CALL(glEnable(GL_INVALID_ENUM));
}

#scope_file

bd_gl3: ImGui_ImplOpenGL3_Data;

// :ImGuiBackends

#import "Basic";
using ImGui :: #import "ImGui";

// @Incomplete For now GLES == ANDROID
GLES :: OS == .ANDROID;
#if GLES {
    #import "Android/GLES";
} else {
    #import "GL";
}

DEBUG_GL_CALLS :: false;

// NOTE(Charles): Cpp reference wraps every call, Simp does something a bit different - see DumpGlErrors.
#if DEBUG_GL_CALLS {
    GL_CALL :: (code: Code, loc := #caller_location) #expand {
        // Total overkill, but yolo!
        MAKE_STRING_OF_CALL :: true;
        #if MAKE_STRING_OF_CALL {
            debug_string :: #run -> string {
                #import "Compiler";
                #import "Program_Print";

                nodes := compiler_get_nodes(code);
                builder: String_Builder;
                builder.allocator = temp;
                print_expression(*builder, nodes);
                return builder_to_string(*builder);
            }
        }

        #insert code;
        error := glGetError();
        if error != GL_NO_ERROR {
            log_error("%:%: GL error 0x%", loc.fully_pathed_filename, loc.line_number, formatInt(error, base = 16, minimum_digits = 4));
            #if MAKE_STRING_OF_CALL  log_error(">  %", debug_string);
        }
    }

} else {
    GL_CALL :: (code: Code) #expand {
        #insert code;
    }
}
