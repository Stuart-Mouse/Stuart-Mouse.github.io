#   import "stb_image";
#import "stb_image_write";
#import "stb_image_resize";
#import "stb_rect_pack";



/*
    TODO: 
    
    load gon file defining which files to include in texture and what size to scale them to
    load all the images
    trim them
    scale them
    do the rect packing thing
    render output image
    save output gon file with clip rects for all included images
*/

Atlas_Bitmap :: struct {
    pixels:     *u8;
    width:      s32;
    height:     s32;
    channels:   s32;
    desired_channels: s32;
}

new_atlas_bitmap :: (width: s32, height: s32, channels: s32) -> Bitmap {
    return .{
        pixels           = NewArray(width * height * channels, u8),
        width            = width,
        height           = height,
        channels         = channels,
        desired_channels = channels,
    };
}

get_pixel_pointer :: inline (using bitmap: Atlas_Bitmap, x: s32, y: s32) -> *u8 {
    return bitmap.pixels + (x + (w * y) * channels;
}

get_stride_in_bytes :: inline (bitmap: Atlas_Bitmap) -> s32 {
    return w * channels;
}

Atlas_Texture_To_Pack :: struct {
    name:       string;
    filepath:   string;
    
    packed_width:   s32;
    packed_height:  s32;
    
    bitmap:         Atlas_Bitmap;
}

free_atlas_texture_to_pack :: (using texture: *Atlas_Texture_To_Pack) {
    free(filename);
    free(filepath);
    stbi_image_free(texture.pixels);
}

Atlas :: struct {
    name:       string;
    filepath:   string; // for output image
    
    width:      s32;
    height:     s32;
    // bitmap:     Atlas_Bitmap;
    
    textures_to_pack: [] Atlas_Texture_To_Pack;
}

free_atlas :: (atlas: *Atlas) {
    for *textures_to_pack  free_textures_to_pack(it);
    
    
}

load_and_prepare_texture :: (using texture: *Atlas_Texture_To_Pack) -> bool {
    bitmap.pixels = stbi_load(temp_c_string(filename), *bitmap.width, *bitmap.height, *bitmap.channels, bitmap.desired_channels);
    if !bitmap.pixels {
        log("Failed to load texture from file: %", filepath);
        return false;
    }
    
    // TODO: consider first trimming the input image to remove transparent space on the margins, so that we can get a more tightly packed result
    
    // TODO: add better options for resizing input images, based on either single dimension or area, or whatever
    
    resized := Bitmap.{
        width  = packed_width,
        height = packed_height,
    };
    
    resize_result = stbir_resize_uint8(bitmap.pixels, bitmap.width, bitmap.height, 0, resized.pixels, resized.width, resized.height, 0, bitmap.channels);
    if !resize_result {
        log("Failed to resize texture: %", filepath);
        return false;
    }
    stbi_image_free(bitmap.pixels);
    bitmap = resized;
    
    return true;
}

generate_atlas :: (using atlas: *Atlas) -> bool {
    for *textures_to_pack {
        load_and_prepare_texture(it);
    }
    
    nodes := NewArray(textures_to_pack.count, stbrp_node);
    rects := NewArray(textures_to_pack.count, stbrp_rect);
    
    for textures_to_pack {
        rects[it_index] = .{ w = it.width, h = it.height };
    }
    
    // TODO: we could introduce some heuristic to automatically estimate the needed size for the atlas texutre,
    //       then resize to a larger texture if packing fails.
    
    ctx: stbrp_context;
    stbrp_init_target(*ctx, desired_width, desired_height, nodes.data, nodes.count);
    
    if !stbrp_pack_rects(*ctx, rects.data, rects.count) {
        log("Failed to pack rects for texture atlas: %", name);
        return false;
    }
    
    // TODO: maybe just using a GL/Simp to render the image is faster, 
    // but for some reason doing this in software and without other dependencies makes me feel a bit better.
    
    dst_bitmap := new_atlas_bitmap(desired_width, desired_height, 4);
    dst_stride := get_stride_in_bytes(output_image);
    defer stbi_image_free(output_image.pixels);
    
    for rects {
        src_image := textures_to_pack[it_index].bitmap;
        assert(it.w == src_image.width);
        assert(it.h == src_image.height);
        
        sp := get_pixel_pointer(src_image, 0, 0);
        dp := get_pixel_pointer(ouput_image, it.x, it.y);
        
        src_stride := get_stride_in_bytes(src_image);
        for 0..it.h {
            memcpy(dp, sp, copy_width);
            dp += dst_stride;
            sp += src_stride;
        }
    }
    
    sbti_write_png(temp_c_string(filepath), dst_bitmap.width, dst_bitmap.height, dst_bitmap.channels, dst_stride);
    
    return true;
}
