

// global textures. to be replaced later with dnamic texture loading as defined in GON

plumber_texture:  Texture;
entities_texture: Texture;

Texture :: Simp.Texture;

load_textures :: () {
    Simp.texture_load_from_file(*tiles_texture,         "data/gfx/tiles.png");
    Simp.texture_load_from_file(*plumber_texture,       "data/gfx/player.png");
    Simp.texture_load_from_file(*entities_texture,      "data/gfx/entities.png");
    Simp.texture_load_from_file(*particles_texture,     "data/gfx/particles.png");
    Simp.texture_load_from_file(*small_text_texture,    "data/gfx/8x8_text.png");
    Simp.texture_load_from_file(*ui_elements_texture,   "data/gfx/ui_elements.png");
}

free_textures :: () {
    Simp.texture_destroy(*tiles_texture);
    Simp.texture_destroy(*plumber_texture);
    Simp.texture_destroy(*entities_texture);
    Simp.texture_destroy(*particles_texture);
    Simp.texture_destroy(*small_text_texture);
    Simp.texture_destroy(*ui_elements_texture);
}



// Texture :: struct {
//     img_w, img_h : GLuint; // dimensions of image within allocated texture
//     tex_w, tex_h : GLuint; // full texture dimensions with padding
    
//     tex_id : GLuint;
//     // vbo_id : GLuint;
    
//     format: Texture_Format; // TODO
//     // flags  : Texture_Flags;
// }

// Texture_Format :: enum {
//     RGBA;
//     INDEXED; // 2 channels
// }

// texture_format_to_gl_enum :: (format: Texture_Format) -> GLenum {
//     if format == {
//         case .RGBA;    return GL_RGBA;
//         case .INDEXED; return GL_RG;
//     }
//     return 0;
// }

// texture_format_bytes_per_pixel :: (format: Texture_Format) -> int {
//     if format == {
//         case .RGBA;    return 4;
//         case .INDEXED; return 2;
//     }
//     return 0;
// }

// texture_from_pixels :: (
//     pixels: *u8, 
//     w: u32, h: u32, 
//     tex_format: Texture_Format = .RGBA,
//     mag_filter := GL_NEAREST,
//     min_filter := GL_NEAREST
// ) -> Texture, bool {
//     using texture: Texture;
//     texture.format = tex_format;
    
//     img_w = w;
//     img_h = h;
//     tex_w = next_power_of_2(w);
//     tex_h = next_power_of_2(h);

//     // pads a texture to power-of-two dimensions if not already
//     new_pixels : *u8 = null;
//     defer free(new_pixels);

//     while glGetError() != 0 {}
    
//     bytes_per_pixel := texture_format_bytes_per_pixel(tex_format);
    
//     if img_w != tex_w 
//     || img_h != tex_h {
//         new_pixels = cast(*u8) alloc(tex_w * tex_h * bytes_per_pixel);
//         src := pixels;
//         dst := new_pixels;
//         src_stride := img_w * bytes_per_pixel;
//         dst_stride := tex_w * bytes_per_pixel;
//         for 0..img_h-1 {
//             memcpy(dst, src, src_stride);
//             dst += dst_stride;
//             src += src_stride;
//         }
//         pixels = new_pixels;
//     }

//     gl_format := texture_format_to_gl_enum(tex_format);

//     glGenTextures(1, *tex_id);
//     glBindTexture(GL_TEXTURE_2D, tex_id);
//     defer glBindTexture(GL_TEXTURE_2D, 0);
//     glTexImage2D(GL_TEXTURE_2D, 0, xx gl_format, tex_w, tex_h, 0, gl_format, GL_UNSIGNED_BYTE, pixels);
//     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
//     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
//     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
//     error := glGetError();
//     if error != GL_NO_ERROR {
//         // TODO: Write a function or macro for getting gl errors nicely.
//         print("tex_id: %\n", tex_id);
//         print("Error % loading texture from pixels!\n", error);
//         return .{}, false;
//     }
    
//     return texture, true;
// }

// texture_from_file :: (
//     file_path: string,
//     mag_filter := GL_NEAREST,
//     min_filter := GL_NEAREST
// ) -> Texture, bool {
//     // print("loading file: %\n", file_path);
//     width, height : u32;
//     channels_in_file : s32;
//     pixels := stbi_load(temp_c_string(file_path), xx *width, xx *height, *channels_in_file, 4);
//     defer stbi_image_free(pixels);
//     if pixels == null {
//         print("Error: unable to load image %.\n", file_path);
//         return .{}, false;
//     }
//     // print("channels: %\n", channels_in_file);
//     // print("width:    %\n", width);
//     // print("height:   %\n", height);
//     // TODO: check that pixel format loaded matches expected pixel format of texture
//     texture, success := texture_from_pixels(pixels, width, height, .RGBA, min_filter, mag_filter);
//     return texture, success;
// }

// texture_from_file_colormapped :: (
//     file_path: string,
//     mag_filter := GL_NEAREST,
//     min_filter := GL_NEAREST
// ) -> Texture, bool {
//     // print("loading file: %\n", file_path);
    
//     width, height    : u32;
//     channels_in_file : s32;
//     pixels := stbi_load(temp_c_string(file_path), xx *width, xx *height, *channels_in_file, 4);
//     defer stbi_image_free(pixels);
//     if pixels == null {
//         print("Error: unable to load image: %\n", file_path);
//         return .{}, false;
//     }
    
//     // print("channels: %\n", channels_in_file);
//     // print("width:    %\n", width);
//     // print("height:   %\n", height);
    
//     new_pixels := colormap_image(pixels, width * height, 4);
//     if new_pixels == null {
//         print("Error; failed to colormap image: %\n", file_path);
//         return .{}, false;
//     }
//     defer free(new_pixels);
    
//     texture, success := texture_from_pixels(new_pixels, width, height, .INDEXED, min_filter, mag_filter);
//     return texture, success;
// }

// free_texture :: (using texture: *Texture) {
//     if tex_id != 0 then glDeleteTextures(1, *tex_id);
//     texture.* = .{};
// }



// // loaded_textures :: [..] struct { full_path: string; texture: Texture; };

// // free_loaded_textures :: () {
// //     for *loaded_textures  free_texture(it);
// // }

// // find_loaded_texture :: (path: string) -> int {
// //     for loaded_textures  if it.full_path == path  return it_index;
// //     return -1;
// // }

// // load_texture :: (filename: string) -> int {
// //     path := join(executable_path, "data/gfx/", filename,, temp);
// //     index := find_loaded_sound_index(path);
// //     if index == -1 {
// //         data := load_audio_file(path);
// //         if data.loaded {
// //             array_add(*loaded_sounds, data);
// //             index = loaded_sounds.count-1;
// //             log("Loaded texture '%'", path);
// //         }
// //     }
// //     return index;
// // }


