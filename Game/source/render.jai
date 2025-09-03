

/*
    RENDERING REFACTORING NOTES:
    
    Added uniform transform to the basic Simp shaders
        Should add some mechanism to automatically flush if we push some change to the current transform?
    
    
    Fact-Finding:
        how often are we swapping shaders / flushing verted buffer?

*/

// TODO: figure out what to do with these globals:
render_clear_color: Color4;
render_viewport:    Rect;

render_clear :: (color: *Color4 = null) {
    _color := ifx color else *render_clear_color;
    Simp.clear_render_target(_color.r, _color.g, _color.b, _color.a);
}

render_set_viewport :: (rect: *Rect = null) {
    if !rect { 
        Simp.clear_scissor(); 
        w, h := Simp.get_render_dimensions(window);
        render_viewport = .{ 0, 0, w, h };
        return; 
    }
    Simp.set_scissor(to_Vec2f(rect.position), to_Vec2f(rect.position + rect.size));
    render_viewport = rect.*;
}

render_get_viewport :: () -> Rect {
    return render_viewport;
}

// TODO: reimplement
// render_target_texture :: (texture: *Texture) -> bool {
//     using Renderer;
    
//     if !texture.tex_id  return false;
//     target_texture = texture;
// }



// TODO: maybe we want to only have transform, shader program, render target set when calling render_begin_batch
// funtionally not important, since we can just do that manually, but maybe its a good organizing principle?
render_begin_batch :: () {
    Simp.immediate_begin();
    
    transform := *context.simp.current_transform;
    transform.* = Matrix4_Identity;
    translate(transform, .{ xx render_viewport.x, xx render_viewport.y, 0 });
}

render_end_batch :: () {
    
}

render_flush :: () {
    Simp.immediate_flush();
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
    position:           Vector2, 
    size:               Vector2, 
    color:              Color4             = .{ 1, 1, 1, 1 },
    texture:            *Texture           = null, 
    clip:               Rectf              = NAN_RECT, 
    flip:               Direction_Flip     = .NONE,
    rotation:           float              = 0,
    rotation_center:    Vector2            = NAN_POINT,
    palette:            Palette_ID         = 0,
    depth:              float              = 0
) {
    tex_coords:  [4] Vector2;
    tex_coord_L: float = 0;
    tex_coord_R: float = 1;
    tex_coord_T: float = 0;
    tex_coord_B: float = 1;
    
    if texture == null {
        Simp.set_shader_for_color(true);
    } else {
        Simp.set_shader_for_images(texture);
        
        if !isnan(clip.x) {
            tex_coord_L = floor(clip.x         ) / texture.width.(float);
            tex_coord_R = floor(clip.x + clip.w) / texture.width.(float);
            tex_coord_T = floor(clip.y         ) / texture.height.(float);
            tex_coord_B = floor(clip.y + clip.h) / texture.height.(float);
        } else {
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
    if rotation != 0 {
        _rotate_around := ifx !isnan(rotation_center.x) then rotation_center else position + size/2;
        
        sin_t := sin(rotation);
        cos_t := cos(rotation);
        
        for *vertex_positions {
            it.* -= _rotate_around;
            it.* = .{
                x = it.x * cos_t - it.y * sin_t,
                y = it.y * cos_t + it.x * sin_t,
            };
            it.* += _rotate_around;
        }
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
    position:           Vector2;
    size:               Vector2;
    color:              Color4             = .{ 1, 1, 1, 1 };
    texture:            *Texture           = null;
    clip:               Rectf              = NAN_RECT;
    flip:               Direction_Flip     = .NONE;
    rotation:           float              = 0;
    rotation_center:    Vector2            = NAN_POINT;
    palette:            Palette_ID         = 0;
}

render_draw_quad :: (using params: Render_Draw_Quad_Params) {
    render_draw_quad(
        position        = position,
        size            = size,
        color           = color,
        texture         = texture,
        clip            = clip,
        flip            = flip,
        rotation        = rotation,
        rotation_center = rotation_center,
        palette         = palette,
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

render_small_text :: (format: string, args: ..Any, position: Vector2, size := Vector2.{8,8}, align: float = 0, color := Color4.{1,1,1,1}) {
    _position := position;

    str := tprint(format, ..args);

    _position.x -= str.count.(float) * size.x * align;

	clip: Rectf = .{ 0, 0, 8, 8 };

    for 0..str.count-1 {
		clip.x = ((str[it] % 16) * 8).(float);
		clip.y = ((str[it] / 16) * 8).(float);

		render_draw_quad(
            texture  = *textures.SMALL_TEXT,
            position = _position,
            size     = size,
            clip     = *clip,
            color    = color,
		);

		_position.x += size.x;
	}
}
