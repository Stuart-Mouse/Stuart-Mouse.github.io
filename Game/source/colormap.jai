/*
    All of the palettes that are currently in use are stored in global state, since there are only a fixed number of palettes in use at any given time.
    These palettes are resent to the GPU every frame as a matter of course, so any changes you make to their values will be reflected in the subsequent frame.
*/

MASTER_PALETTE_NUM_COLORS :: 256;
Master_Palette: [MASTER_PALETTE_NUM_COLORS] Color4;

#if !#exists(GLint) {
    GLint :: int;
}

NUM_PALETTES       :: 32;
COLORS_PER_PALETTE :: 4;
Color_Palette      :: [COLORS_PER_PALETTE] GLint;

Animated_Color_Palette :: struct {
    name:   string;
    
    current:    s32;
    clock:      float; 
    frames: [] struct { 
        palette:    Color_Palette; 
        duration:   float; 
    };
}

loaded_colors:   [NUM_PALETTES] Color_Palette;
loaded_palettes: [..] Animated_Color_Palette;

get_palette :: (index: int) -> *Animated_Color_Palette {
    if index < 0 || index >= loaded_palettes.count  
        return *loaded_palettes[0];
    return *loaded_palettes[index];
}

get_current_palette :: (index: int) -> *Color_Palette {
    if index < 0 || index >= loaded_palettes.count  
        return *loaded_palettes[0].frames[0].palette;
    acp := loaded_palettes[index];
    return *acp.frames[acp.current].palette;
}

get_palette :: (name: string) -> *Animated_Color_Palette {
    for *loaded_palettes  if it.name == name  return it;
    return null;
}

// if we can't find the palette, we default to 0.  
// is this bad? we dont' want to crash here since we may call this from data file, but maybe we should at least print some log...
get_palette_index :: (name: string) -> int {
    for loaded_palettes  if it.name == name  return it_index;
    log("Error: No palette found with name '%'.", name);
    return 0;
}

get_current_palette :: (name: string) -> *Color_Palette {
    acp := get_palette(name);
    if !acp  return *loaded_palettes[0].frames[0].palette;
    return *acp.frames[acp.current].palette;
}



/*
    Master palette organization
    
    colors go 0-255 or 0x00 - 0xff
    so the palette will be organized in 16 rows x 16 grid
    
    for my purposes, 0x00 will always be pure black and 0xff will always be pure white
    in general each row should be a common color/hue
        though obviously we can have some hue/contrast shift across the row, but it should be a relatively contiguous region
        then we can easily 
        
    overall, left side of image should be these basic colors that we use, set up the color scheme
    that way we can change the master palette between levels and not have to adjust individual palettes for enemies and such, they'll still reference the same underlying indices
    
    if we have animated colors, those should go towards the bottom rows, or on right side of rows with which the color matchs (just do what's logical)
*/

Color_Palette_Animation :: struct {
    palette_index: int;
    
    current:    s32;
    clock:      float; 
    frames: [] struct { 
        palette:    Color_Palette;
        duration:   float;
    };
}

Color_Palette_Animations: [..] Color_Palette_Animation;

// TODO: remove default value for step, add timstep tracking in editor
update_color_palette_animations :: (step: float = TIMESTEP) {
    for *loaded_palettes {
        it.clock += step;
        while it.clock >= it.frames[it.current].duration {
            if it.frames[it.current].duration < 0.001  continue it;
            it.clock -= it.frames[it.current].duration;
            it.current += 1;
            if it.current >= it.frames.count {
                it.current = 0;
            }
        }
    }
}

free_loaded_palettes :: () {
    // skip index 0 because that is always the all-white palette
    for 1..loaded_palettes.count-1 {
        palette := *loaded_palettes[it];
        free(palette.name);
        array_free(palette.frames);
    }
}

init_color_palettes :: () -> bool {
    free_loaded_palettes();
    array_reset_keeping_memory(*loaded_palettes);
    
    // full white palette, so that we can render solid color quads of any color
    array_add(*loaded_palettes, .{ 
        name = "white", 
        frames = .[ .{ palette = .[ 0xff, 0xff, 0xff, 0xff ] } ],
    });
    
    ok := LSD.load_and_parse_file("data/palettes.gon", #code {
        LSD.add_data_binding_to_dom(*parser, loaded_palettes, "palettes");
    });
    if !ok  return false;
    
    // print("loaded_palettes: %\n", loaded_palettes);
    
    return true;
}

update_color_palettes_on_gpu :: () {
    // TODO: fix this, this is horribly inefficient
    // for 0..min(loaded_palettes.count, NUM_PALETTES)-1 {
    //     loaded_colors[it] = get_current_palette(it).*;
    // }
    
    // colormap_program := Renderer.shader_programs[Renderer.Shader_Program_Enum.COLORMAP];

    // palettes_uniform := glGetUniformLocation(colormap_program, "u_Palettes");
    // glUniform1iv(palettes_uniform, NUM_PALETTES * COLORS_PER_PALETTE, xx *loaded_colors);
    
    // master_palette_uniform := glGetUniformLocation(colormap_program, "u_MasterPalette");
    // glUniform4fv(master_palette_uniform, MASTER_PALETTE_NUM_COLORS, xx *Master_Palette);
}

load_master_palette :: () {
    // file_path := "data/gfx/palette.png";
    // width, height : u32;
    // channels_in_file : s32;
    // pixels := stbi_load(temp_c_string(file_path), xx *width, xx *height, *channels_in_file, 4);
    // defer stbi_image_free(pixels);
    // if pixels == null {
    //     print("Error: unable to load image %.\n", file_path);
    //     return;
    // }

    // colors_loaded, ok := load_color_palette_from_image(Master_Palette, pixels, width * height * 4, 4);
    // if !ok  return;
    // print("colors loaded: %\n", colors_loaded);
}

load_color_palette_from_image :: (
    palette:    [] Color4,
    pixels:     *u8, 
    count:      int, 
    channels:   int = 4
) -> (
    num_colors: int, 
    success:    bool
) {
    if (channels < 1 || channels > 4)  return 0, false;
    
    num_colors := 0;
    
    pixel := *pixels[0];
    end   := pixel + count;
    
    while pixel < end {
        defer pixel += channels;
        
        color: Color4;
        if channels == {
            case 1; color = color4_from_bytes(pixel[0],     0x00,     0x00,     0xff);
            case 2; color = color4_from_bytes(pixel[0], pixel[1],     0x00,     0xff);
            case 3; color = color4_from_bytes(pixel[0], pixel[1], pixel[2],     0xff);
            case 4; color = color4_from_bytes(pixel[0], pixel[1], pixel[2], pixel[3]);
        }
        
        if num_colors == palette.count {
            log("Failed to create color palette from image, too many colors in image.");
            return 0, false;
        }
        
        palette[num_colors] = color;
        num_colors += 1;
    }
    
    return num_colors, true;
}


// the output image wil have only 2 channels
// returns null if failed
colormap_image :: (
    pixels:     *u8, 
    count:      int, 
    channels:   int = 4
) -> (
    new_pixels: *u8
) {
    // right now the lookup table for colors to unmap is hard coded
    // these are the color values we use in the raw images
    unmap_color: [8] Color4 = .[
        #run color4_from_bytes(0x44, 0x00, 0x00, 0xff),
        #run color4_from_bytes(0x88, 0x44, 0x44, 0xff),
        #run color4_from_bytes(0xcc, 0x88, 0x88, 0xff),
        #run color4_from_bytes(0xff, 0xaa, 0xaa, 0xff),
        
        #run color4_from_bytes(0x00, 0x00, 0x44, 0xff),
        #run color4_from_bytes(0x44, 0x44, 0x88, 0xff),
        #run color4_from_bytes(0x88, 0x88, 0xcc, 0xff),
        #run color4_from_bytes(0xaa, 0xaa, 0xff, 0xff),
    ];
    
    if !(channels == 3 || channels == 4) {
        log("error: invalid number of channels: %\n", channels);
        return null;  // only supporting rgb and rgba atm
    }
    
    success := false;
    new_pixels := cast(*u8) alloc(2 * count);
    defer { if !success  free(new_pixels); };
    
    pixel      := *pixels[0];
    end        := pixel + count * channels;
    new_pixel  := *new_pixels[0];
    
    while pixel < end {
        defer {
            pixel     += channels;
            new_pixel += 2;
        }
        
        color: Color4;
        if channels == {
            case 3; color = color4_from_bytes(pixel[0], pixel[1], pixel[2], 1);
            case 4; color = color4_from_bytes(pixel[0], pixel[1], pixel[2], pixel[3]);
        }
        
        index := -1;
        for unmap_color {
            if it == color {
                index = it_index;
                break;
            }
        }
        if index == -1  continue;
        new_pixel[0] = xx index;
        new_pixel[1] = pixel[3];
    }
    
    success = true;
    return new_pixels;
}

/*
    the colormapped textures only have two channels:
        the color index info is encoded in the r channel
        the alpha channel is on g
    
    the color palette index is on v_Color.r
        so when we render a colormapped quad, the color_mod.r should be the index of the palette we want to use.
        I considered just using the vertex colors as the 4 colors in a palette but that feels too hacky even for me and hard limits us to only 4 colors
*/
// COLORMAP_FRAGMENT_SHADER := #run -> string { return sprint(#string DONE
// #version 330

// layout(location = 0) out vec4 o_Color;

// in vec4  v_Color;
// in vec2  v_TexCoord;
// in float v_TexIndex;
// in float v_PaletteIndex;

// uniform sampler2D u_Textures[16];
// uniform vec4      u_MasterPalette[%3];
// uniform int       u_Palettes[%1 * %2];
// // uniform vec4       u_Palettes[%1 * %2];

// void main() {
//     int  tex_index     = int(v_TexIndex);
//     vec4 pixel         = texture(u_Textures[tex_index], v_TexCoord);
//     int  color_index   = int(pixel.r * 255);
//     int  palette_index = int(v_PaletteIndex);
    
//     int  master_color_index = u_Palettes[palette_index * %2 + color_index];
//     o_Color = vec4(u_MasterPalette[master_color_index].rgb, pixel.g) * v_Color;
    
//     // o_Color = vec4(u_Palettes[palette_index * %2 + color_index].rgb, pixel.g);
// }
// DONE, NUM_PALETTES, COLORS_PER_PALETTE, MASTER_PALETTE_NUM_COLORS);};

// COLORMAP_VERTEX_SHADER := #string DONE
// #version 330

// layout (location = 0) in vec3  a_Position;
// layout (location = 1) in vec4  a_Color;
// layout (location = 2) in vec2  a_TexCoord;
// layout (location = 3) in float a_TexIndex;
// layout (location = 4) in float a_PaletteIndex;

// uniform mat4 u_ViewProj;
// uniform mat4 u_Transform;

// out vec4  v_Color;
// out vec2  v_TexCoord;
// out float v_TexIndex;
// out float v_PaletteIndex;

// void main() {
//     v_Color        = a_Color;
//     v_TexCoord     = a_TexCoord;
//     v_TexIndex     = a_TexIndex;
//     v_PaletteIndex = a_PaletteIndex;
//     gl_Position = u_ViewProj * u_Transform * vec4(a_Position.xyz, 1);
// }
// DONE;


