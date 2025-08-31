
Vertex2D :: struct {
    position:       Vector3;
    color:          Color4;
    tex_coord:      Vector2;
    tex_index:      float;
    palette_index:  float;
}

Renderer : struct {
    // quadVA: GLuint;
    // quadVB: GLuint;
    // quadIB: GLuint;
    
    // MAX_QUADS           :: 1000;
    // MAX_VERTICES        :: MAX_QUADS * 4;
    // MAX_INDICES         :: MAX_QUADS * 6;
    // vertex_buffer        : [MAX_VERTICES] Vertex2D;
    // quad_count           : u32;
    
    // MAX_TEXTURES        :: 16;
    // texture_slots        : [MAX_TEXTURES] GLuint;
    // texture_slots_used   : u32;
    
    // Shader_Program_Enum :: enum {
    //     STANDARD;
    //     COLORMAP;
        
    //     _COUNT;
    // }
    
    // // TODO: improve how shader programs are loaded and swapped out
    // //       probably make it something like what we do for sounds or palettes?
    // shader_programs: [Shader_Program_Enum._COUNT] GLuint;
    // active_shader_program: Shader_Program_Enum;
    
    transform: Matrix4;
    
    // render to texture
    // target_texture_framebuffer: GLuint;
    // target_texture: Texture;
    
    clear_color := Color4.{ 0.45, 0.55, 0.60, 1.00 };
    viewport: Rect;
}

render_clear :: (color: *Color4 = null) {
    _color := ifx color else *Renderer.clear_color;
    Simp.clear_render_target(_color.r, _color.g, _color.b, _color.a);
}

render_set_viewport :: (rect: *Rect = null) {
    if !rect { 
        Simp.clear_scissor(); 
        w, h := Simp.get_render_dimensions(window);
        Renderer.viewport = .{ 0, 0, w, h };
        return; 
    }
    Simp.set_scissor(to_Vec2f(rect.position), to_Vec2f(rect.position + rect.size));
    Renderer.viewport = rect.*;
}


render_get_viewport :: () -> Rect {
    // TODO: we should also keep track of the current scissor area
    // w, h := Simp.get_render_dimensions(window);
    // return .{ 0, 0, w, h };
    return Renderer.viewport;
}

// render_target_texture :: (texture: *Texture) -> bool {
//     using Renderer;
    
//     if !texture.tex_id  return false;
//     target_texture = texture;
// }

render_init :: () {
    // using Renderer;
    
    // {
    //     shader_programs[Shader_Program_Enum.STANDARD] = create_shader(VERTEX_SHADER, FRAGMENT_SHADER);
    //     program := shader_programs[Shader_Program_Enum.STANDARD];
    //     glUseProgram(program);
        
    //     tex_uniform := glGetUniformLocation(program, "u_Textures"); 
    //     samplers: [MAX_TEXTURES] GLint;
    //     for *samplers  it.* = xx it_index;
    //     print("samplers: %\n", samplers);
    //     glUniform1iv(tex_uniform, MAX_TEXTURES, *samplers[0]);
        
    //     ortho_projection := orthographic_projection_matrix(0, xx WINDOW_WIDTH, xx WINDOW_HEIGHT, 0, 0, 1);
    //     ortho_projection = transpose(ortho_projection);
    //     print("ortho: %\n", ortho_projection.floats);
    //     proj_mat_uniform := glGetUniformLocation(program, "u_ViewProj");
    //     glUniformMatrix4fv(proj_mat_uniform, 1, GL_FALSE, xx *ortho_projection);
    // }
    
    // {
    //     shader_programs[Shader_Program_Enum.COLORMAP] = create_shader(COLORMAP_VERTEX_SHADER, COLORMAP_FRAGMENT_SHADER);
    //     program := shader_programs[Shader_Program_Enum.COLORMAP];
    //     glUseProgram(program);
        
    //     tex_uniform := glGetUniformLocation(program, "u_Textures"); 
    //     samplers: [MAX_TEXTURES] GLint;
    //     for *samplers  it.* = xx it_index;
    //     print("samplers: %\n", samplers);
    //     glUniform1iv(tex_uniform, MAX_TEXTURES, *samplers[0]);
        
    //     // master_palette_uniform := glGetUniformLocation(shader_program, "u_MasterPalette");
    //     // glUniform4fv(master_palette_uniform, MASTER_PALETTE_NUM_COLORS, xx *Master_Palette);
        
    //     // palettes_uniform := glGetUniformLocation(shader_program, "u_Palettes");
    //     // glUniform4fv(palettes_uniform, NUM_PALETTES * COLORS_PER_PALETTE, xx *color_palettes);
        
    //     ortho_projection := orthographic_projection_matrix(0, xx WINDOW_WIDTH, xx WINDOW_HEIGHT, 0, 0, 1);
    //     ortho_projection = transpose(ortho_projection);
    //     print("ortho: %\n", ortho_projection.floats);
    //     proj_mat_uniform := glGetUniformLocation(program, "u_ViewProj");
    //     glUniformMatrix4fv(proj_mat_uniform, 1, GL_FALSE, xx *ortho_projection);
    // }
    
    
    // // Set up VA
    // glCreateVertexArrays(1, *quadVA);
    // glBindVertexArray(quadVA);
    
    // // Set up VB
    // glCreateBuffers(1, *quadVB);
    // glBindBuffer(GL_ARRAY_BUFFER, quadVB);
    // glBufferData(GL_ARRAY_BUFFER, MAX_VERTICES * size_of(Vertex2D), null, GL_DYNAMIC_DRAW);

    // // Set up vertex attributes
    // glEnableVertexArrayAttrib(quadVA, 0);
    // glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex2D), cast(*void)offset_of(Vertex2D, "position"));

    // glEnableVertexArrayAttrib(quadVA, 1);
    // glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, size_of(Vertex2D), cast(*void)offset_of(Vertex2D, "color"));

    // glEnableVertexArrayAttrib(quadVA, 2);
    // glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, size_of(Vertex2D), cast(*void)offset_of(Vertex2D, "tex_coord"));

    // glEnableVertexArrayAttrib(quadVA, 3);
    // glVertexAttribPointer(3, 1, GL_FLOAT, GL_FALSE, size_of(Vertex2D), cast(*void)offset_of(Vertex2D, "tex_index"));
    
    // glEnableVertexArrayAttrib(quadVA, 4);
    // glVertexAttribPointer(4, 1, GL_FLOAT, GL_FALSE, size_of(Vertex2D), cast(*void)offset_of(Vertex2D, "palette_index"));

    // // Set up IB
    // indices: [MAX_INDICES] u32;
    // offset_vb: u32;
    // offset_ib: u32;
    // while offset_ib < MAX_INDICES {
    //     indices[offset_ib + 0] = 0 + offset_vb;
    //     indices[offset_ib + 1] = 1 + offset_vb;
    //     indices[offset_ib + 2] = 2 + offset_vb;

    //     indices[offset_ib + 3] = 2 + offset_vb;
    //     indices[offset_ib + 4] = 3 + offset_vb;
    //     indices[offset_ib + 5] = 0 + offset_vb;

    //     offset_vb += 4;
    //     offset_ib += 6;
    // }

    // glCreateBuffers(1, *quadIB);
    // glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, quadIB);
    // glBufferData(GL_ELEMENT_ARRAY_BUFFER, MAX_INDICES * size_of(u32), indices.data, GL_STATIC_DRAW);

    // for *texture_slots  it.* = 0;

    // // 1x1 white texture (alwyas occupies texture slot 0)
    // glCreateTextures(GL_TEXTURE_2D, 1, *texture_slots[0]);
    // glBindTexture(GL_TEXTURE_2D, texture_slots[0]);
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // // For colormapped shader, using 0x00000000 instead of 0xffffffff, so that we index lowest color in palette
    // color: u32 = 0xff00;
    // glTexImage2D(GL_TEXTURE_2D, 0, GL_RG, 1, 1, 0, GL_RG, GL_UNSIGNED_BYTE, xx *color);
    // texture_slots_used = 1;
    // glBindTexture(GL_TEXTURE_2D, 0);

    // texture_units: GLint;
    // glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, *texture_units);
    // print("max texture units: %\n", texture_units);

    // glGetIntegerv(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS, *texture_units);
    // print("max combined texture units: %\n", texture_units);
    
    // render_set_viewport();
    
    // // ifdef out for now, since we need to do more work on tilemaps/collisions before reintroducing the complex rendering jazz
    // #if false {
    
    // // create render target texture
    // glGenFramebuffers(1, *target_texture_framebuffer);
    // glBindFramebuffer(GL_FRAMEBUFFER, target_texture_framebuffer);
    
    // // The texture we're going to render to
    // glGenTextures(1, *target_texture.tex_id);
    
    // // "Bind" the newly created texture : all future texture functions will modify this texture
    // glBindTexture(GL_TEXTURE_2D, target_texture.tex_id);
    
    // // Give an empty image to OpenGL ( the last "0" )
    // target_texture.width, target_texture.img_w = 640;
    // target_texture.height, target_texture.img_h = 480;
    // glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, target_texture.width, target_texture.height, 0, GL_RGB, GL_UNSIGNED_BYTE, null);
    
    // // Poor filtering. Needed !
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    
    // // The depth buffer
    // // GLuint depthrenderbuffer;
    // // glGenRenderbuffers(1, &depthrenderbuffer);
    // // glBindRenderbuffer(GL_RENDERBUFFER, depthrenderbuffer);
    // // glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, 1024, 768);
    // // glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthrenderbuffer);
    
    // // Set "target_texture" as our colour attachement #0   ?? what does this mean
    // glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, target_texture.tex_id, 0);
    
    // // Set the list of draw buffers.
    // DrawBuffers: [1] GLenum = .[ GL_COLOR_ATTACHMENT0 ];
    // glDrawBuffers(1, *DrawBuffers[0]); // "1" is the size of DrawBuffers
    
    // // Always check that our framebuffer is ok
    // if glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE {
    //     print("failed to generate framebuffer or something!\n");
    // }
    
    // }
}

render_setup_ortho_projection :: (x: float, y: float) {
    // using Renderer;
    // ortho_projection := orthographic_projection_matrix(0, x, y, 0, 0, 1, true);
    // ortho_projection  = transpose(ortho_projection);
    // proj_mat_uniform := glGetUniformLocation(shader_programs[active_shader_program], "u_ViewProj");
    // glUniformMatrix4fv(proj_mat_uniform, 1, GL_FALSE, xx *ortho_projection);
}

render_deinit :: () {
    // print("render_deinit();\n");
    // using Renderer;
    // glDeleteVertexArrays(1, *quadVA );
    // glDeleteBuffers     (1, *quadVB );
    // glDeleteBuffers     (1, *quadIB );
    // glDeleteTextures    (1, *texture_slots[0]);
}

// TODO: maybe we want to only have transform, shader program, render target set when calling render_begin_batch
// funtionally not important, since we can just do that manually, but maybe its a good organizing principle?
render_begin_batch :: () {
    using Renderer;
    // Simp.immediate_begin();
    transform = Matrix4_Identity;
    translate(*transform, .{ xx viewport.x, xx viewport.y, 0 });
}

render_end_batch :: () { }

render_flush :: () {
    // Simp.immediate_flush();
}




// this is probably not great but it works for now
// may want to extend line by thickness / 2 on each side so that anchor points are evenly surrounded
render_draw_line :: (p1: Vector2, p2: Vector2, color: Color4 = .{1,1,1,1}, thickness: float = 1) {
    Simp.set_shader_for_color(true);
    vec := unit_vector_between_points(p1, p2) * (thickness / 2);
    
    color_as_vec4 := (*color).(*Vector4).*;
    
    // NOTE: there is a +0.5 pixel offset to all vertices so that lines are rendered wrt pixel centers
    Simp.immediate_quad(
        .{ p1.x - vec.y, p1.y + vec.x, 0 } + .{ 0.5, 0.5, 0 },
        .{ p2.x - vec.y, p2.y + vec.x, 0 } + .{ 0.5, 0.5, 0 },
        .{ p2.x + vec.y, p2.y - vec.x, 0 } + .{ 0.5, 0.5, 0 },
        .{ p1.x + vec.y, p1.y - vec.x, 0 } + .{ 0.5, 0.5, 0 },
        color_as_vec4
    );
}

// added the offset and scale parameters for the sake of rendering tilemap paths, since we need the conversion of world space to screen space done for every point, and I didnt want to just start a whole separate render batch for that
render_draw_lines :: (points: ..Vector2, color: Color4 = .{1,1,1,1}, thickness: float = 1, offset := Vector2.{}, scale := 1.0) {
    if points.count < 2  return;
    // TODO: in the future, we should connect the lines better so that the corners look OK at larger line sizes
    // for now, being lazy and just gonna call the same proc over and over
    for 0..points.count-2 {
        render_draw_line((points[it] + offset) * scale, (points[it+1] + offset) * scale, color, thickness);
    }
}



// todo: have separate params for border color and fill color
render_draw_rect :: (rect: Rectf, color: Color4 = .{1,1,1,1}, thickness: float = 1, rotation: float = 0, rotation_center: *Vector2 = null) {
    points: [5] Vector2 = .[
        .{rect.x         , rect.y         },
        .{rect.x + rect.w, rect.y         },
        .{rect.x + rect.w, rect.y + rect.h},
        .{rect.x         , rect.y + rect.h}, 
        .{rect.x         , rect.y         },
    ];
    
    if rotation {
        _rotation_center: Vector2;
        if rotation_center {
            _rotation_center = rotation_center.*;
        } else {
            _rotation_center = center(rect);
        }
        unit := unit_vector_given_angle(rotation);
        for *points {
            it.* -= _rotation_center;
            it.* = fast_rotation(it.*, unit);
            it.* += _rotation_center;
        }
    }
    
    render_draw_lines(..points, color, thickness);
}


render_draw_quad :: (
    position:       Vector2, 
    size:           Vector2, 
    color:          Color4             = .{ 1, 1, 1, 1 },
    texture:        *Texture           = null, 
    clip:           *Rectf             = null, 
    flip:           Direction_Flip     = .NONE,
    rotate:         float              = 0,
    rotate_around:  *Vector2           = null,
    palette:        int                = 0,
    depth:          float              = 0
) {
    using Renderer; // for transform
    
    tex_coords:  [4] Vector2;
    tex_coord_L: float = 0;
    tex_coord_R: float = 1;
    tex_coord_T: float = 0;
    tex_coord_B: float = 1;
    
    if texture == null {
        Simp.set_shader_for_color(true);
    } else {
        Simp.set_shader_for_images(texture);
        
        if clip {
            tex_coord_L = floor(clip.x         ) / texture.width.(float);
            tex_coord_R = floor(clip.x + clip.w) / texture.width.(float);
            tex_coord_T = floor(clip.y         ) / texture.height.(float);
            tex_coord_B = floor(clip.y + clip.h) / texture.height.(float);
        }
        else {
            // TODO: this may require fix depending on how simp handles uv coords
            tex_coord_L = 0;
            tex_coord_R = texture.width.(float) / texture.width.(float);
            tex_coord_T = 0;
            tex_coord_B = texture.height.(float) / texture.height.(float);
        }
        
        if flip & .HORIZONTAL {
            tex_coord_L, tex_coord_R = tex_coord_R, tex_coord_L;
        }
        if flip & .VERTICAL {
            tex_coord_T, tex_coord_B = tex_coord_B, tex_coord_T;
        }
    }
    
    tex_coords = .[
        .{ tex_coord_L, tex_coord_T },
        .{ tex_coord_R, tex_coord_T },
        .{ tex_coord_R, tex_coord_B },
        .{ tex_coord_L, tex_coord_B },
    ];
    
    _position: Vector3 = ---;
    _position.xy = floor(position);
    _position.z = depth;
    
    vertex_positions := Vec2f.[
        .{ _position.x,          _position.y,          /*_position.z*/ },
        .{ _position.x + size.x, _position.y,          /*_position.z*/ },
        .{ _position.x + size.x, _position.y + size.y, /*_position.z*/ },
        .{ _position.x,          _position.y + size.y, /*_position.z*/ },
    ];
    
    // rotate vertices manually in software
    {
        _rotate_around := ifx rotate_around 
            then rotate_around.*
            else position + size/2;
        
        sin_t := sin(rotate);
        cos_t := cos(rotate);
        
        if rotate != 0 {
            for *vertex_positions {
                it.* -= _rotate_around;
                it.* = .{
                    x = it.x * cos_t - it.y * sin_t,
                    y = it.y * cos_t + it.x * sin_t,
                };
                it.* += _rotate_around;
            }
        }
    }
    
    // also apply uniform vertex transformation here manually...
    // TODO: we really need to move this back into shader! This is horribly inefficient!
    for *vertex_positions {
        it.* = transform_point(transform, it.*);
    }
    
    // TODO: move logic for getting palette color out of this function. 
    //       we will want to have better high-level control over how colors get animated on a per-tile and per-vertex basis
    color_as_vec4 := (*(color * get_current_color(palette, get_active_level().time_since_start))).(*Vector4).*;
    
    Simp.immediate_quad(
        vertex_positions[0], vertex_positions[1], vertex_positions[2], vertex_positions[3], 
        color_as_vec4, color_as_vec4, color_as_vec4, color_as_vec4,
        tex_coords[0], tex_coords[1], tex_coords[2], tex_coords[3],
    );
}




// ============================
//      DEFERRED RENDERING
// ============================

// For the sake of deferred rendering (like what we do for editor UI handles) we have variants of all the main rendering procs which take a single struct as parameter

Render_Command :: struct {
    type: enum { LINE; RECT; QUAD; };
    union {
        line_params:  Render_Draw_Line_Params;
        rect_params:  Render_Draw_Rect_Params;
        quad_params:  Render_Draw_Quad_Params;
    };
}

exec_render_command :: (command: Render_Command) {
    if command.type == {
      case .LINE; render_draw_line(command.line_params);
      case .RECT; render_draw_rect(command.rect_params);
      case .QUAD; render_draw_quad(command.quad_params);
    }
}

// TODO: probably move this to utility or something
// using NAN32 to signify absence of an optional Vector2 parameter, instead of passing a pointer which could be invalidated.
NAN32     :: 0h7fbf_ffff;
NAN_POINT :: Vector2.{ NAN32, NAN32 };
NAN_RECT  :: Rectf.{ NAN32, NAN32, NAN32, NAN32 };

Render_Draw_Line_Params :: struct {
    p1:         Vector2; 
    p2:         Vector2; 
    color:      Color4 = .{1,1,1,1}; 
    thickness:  float  = 1;
}

render_draw_line :: (using params: Render_Draw_Line_Params) {
    render_draw_line(
        p1        = p1,
        p2        = p2,
        color     = color,
        thickness = thickness,
    );
}

Render_Draw_Rect_Params :: struct {
    rect:            Rectf;
    color:           Color4   = .{1,1,1,1};
    thickness:       float    = 1;
    rotation:        float    = 0;
    rotation_center: Vector2  = NAN_POINT;
}

render_draw_rect :: (using params: Render_Draw_Rect_Params) {
    render_draw_rect(
        rect            = rect,
        color           = color,
        thickness       = thickness,
        rotation        = rotation,
        rotation_center = ifx !isnan(rotation_center.x) then *rotation_center,
    );
}

Render_Draw_Quad_Params :: struct {
    position:       Vector2;
    size:           Vector2;
    color:          Color4             = .{ 1, 1, 1, 1 };
    texture:        *Texture           = null;
    clip:           Rectf              = NAN_RECT;
    flip:           Direction_Flip     = .NONE;
    rotate:         float              = 0;
    rotate_around:  Vector2            = NAN_POINT;
    palette:        int                = 0;
}

render_draw_quad :: (using params: Render_Draw_Quad_Params) {
    render_draw_quad(
        position      = position,
        size          = size,
        color         = color,
        texture       = texture,
        clip          = ifx !isnan(clip.x) then *clip,
        flip          = flip,
        rotate        = rotate,
        rotate_around = ifx !isnan(rotate_around.x) then *rotate_around,
        palette       = palette,
    );
}



// =================
//      SHADERS
// =================

// compile_shader :: (type: GLenum, source: string) -> GLuint {
//     id := glCreateShader(type);

//     glShaderSource(id, 1, *temp_c_string(source), null);
//     glCompileShader(id);

//     result: s32;
//     glGetShaderiv(id, GL_COMPILE_STATUS, *result);
//     if !result {
//         log_length  : GLsizei = 0;
//         message     : [1024] GLchar;
//         str_message : string;
//         str_message.data = *message[0];
//         glGetShaderInfoLog(id, 1024, *log_length, *message[0]);
//         str_message.count = xx log_length;

//         print("Failed to compile % shader.\n", ifx type == GL_VERTEX_SHADER then "vertex" else "fragment");
//         print(str_message);
//         print("failed to load shaders!\n");
//         glDeleteShader(id);
//         return 0;
//     }

//     return id;
// }

// create_shader :: (vertex_source: string, fragment_source: string) -> GLuint {
//     shader_program  := glCreateProgram();
//     vertex_shader   := compile_shader(GL_VERTEX_SHADER  , vertex_source  );
//     fragment_shader := compile_shader(GL_FRAGMENT_SHADER, fragment_source);

//     if !vertex_shader || !fragment_shader {
//         print("Error: unable to compile shader program!\n");
//     }

//     glAttachShader(shader_program, vertex_shader);
//     glAttachShader(shader_program, fragment_shader);
//     glLinkProgram(shader_program);
//     glValidateProgram(shader_program);

//     glDeleteShader(vertex_shader);
//     glDeleteShader(fragment_shader);

//     return shader_program;
// }

// FRAGMENT_SHADER := #string DONE
// #version 330

// out vec4 o_Color;

// in vec4  v_Color;
// in vec2  v_TexCoord;
// in float v_TexIndex;

// uniform sampler2D u_Textures[16];

// #define M_PI 3.1415926535897932384626433832795

// void main() {
//     int index = int(v_TexIndex);

//     vec2 tex_coord = v_TexCoord;

//     // modify texcoord so that it is wavy on y
//     // tex_coord.y += 0.1 * sin(tex_coord.x * 3 * M_PI);

//     o_Color = texture(u_Textures[index], tex_coord) * v_Color;
// }
// DONE;

// VERTEX_SHADER := #string DONE
// #version 330

// layout (location = 0) in vec2  a_Position;
// layout (location = 1) in vec4  a_Color;
// layout (location = 2) in vec2  a_TexCoord;
// layout (location = 3) in float a_TexIndex;

// uniform mat4 u_ViewProj;
// uniform mat4 u_Transform;

// out vec4  v_Color;
// out vec2  v_TexCoord;
// out float v_TexIndex;

// void main() {
//     v_Color     = a_Color;
//     v_TexCoord  = a_TexCoord;
//     v_TexIndex  = a_TexIndex;
//     gl_Position = u_ViewProj * u_Transform * vec4(a_Position.xy, 0, 1);
// }
// DONE;


// ==============================
//      SMALL TEXT RENDERING
// ==============================

small_text_texture: Texture;

render_small_text :: (format: string, args: ..Any, position: Vector2, size := Vector2.{8,8}, align: float = 0, color := Color4.{1,1,1,1}) {
    _position := position;

    str := tprint(format, ..args);

    _position.x -= str.count.(float) * size.x * align;

	clip: Rectf = .{ 0, 0, 8, 8 };

    for 0..str.count-1 {
		clip.x = ((str[it] % 16) * 8).(float);
		clip.y = ((str[it] / 16) * 8).(float);

		render_draw_quad(
            texture  = *small_text_texture,
            position = _position,
            size     = size,
            clip     = *clip,
            color    = color,
		);

		_position.x += size.x;
	}
}
