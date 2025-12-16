
get_clip_by_name :: (atlas_info: Atlas_Info, name: string) -> Rectf {
    for atlas_info.clips {
        if it.name == name {
            return it.rect;
        }
    }
    log("Warning: unable to to get atlas clip by name: %", name);
    return .{};
}

Atlas_Info :: struct {
    clips: [] Clip;
    
    Clip :: struct {
        rect:   Rectf;
        name:   string;
    }
}

free_atlas_info :: (atlas_info: *Atlas_Info) {
    array_free(atlas_info.clips);
}

#if OS != .WASM {

#import "stb_image";
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
    
    
    would probably be nice to move bitmap handling stuff to its own little module so I can collect all useful bitmap operations there
    
    
    NOTE: when freeing bitmaps, we don't free with stbi_image_free, since we will have necessarily copied the image during the potential resize after intitially loading with stb_image.
          In the future, it would probably be better if we could modify the stb image bindings so that it allocates with context.allocator.
*/

Atlas_Bitmap :: struct {
    pixels:     *u8;
    width:      s32;
    height:     s32;
    channels:   s32;
    desired_channels: s32;
}

new_atlas_bitmap :: (width: s32, height: s32, channels: s32) -> Atlas_Bitmap {
    return .{
        pixels           = alloc(width * height * channels),
        width            = width,
        height           = height,
        channels         = channels,
        desired_channels = channels,
    };
}

get_pixel_pointer :: inline (using bitmap: Atlas_Bitmap, x: s32, y: s32) -> *u8 {
    return bitmap.pixels + ((x + (width * y)) * channels);
}

get_stride_in_bytes :: inline (bitmap: Atlas_Bitmap) -> s32 {
    return bitmap.width * bitmap.channels;
}

Atlas_Texture_To_Pack :: struct {
    name:       string;
    filepath:   string;
    sizing:     Sizing_Policy;
    bitmap:     Atlas_Bitmap;
}

free_atlas_texture_to_pack :: (using texture: *Atlas_Texture_To_Pack) {
    free(name);  
    free(filepath);
    free(texture.bitmap.pixels);
}

Atlas :: struct {
    name:               string;
    image_filepath:     string; 
    info\_filepath:     string; 
    
    width:      s32;
    height:     s32;
    
    textures_to_pack: [] Atlas_Texture_To_Pack;
    nodes:            [] stbrp_node;
    rects:            [] stbrp_rect;
    
    bitmap:  Atlas_Bitmap;
}

free_atlas :: (using atlas: *Atlas) {
    free(name);  
    free(image_filepath); 
    free(info_filepath); 
    for *textures_to_pack  free_atlas_texture_to_pack(it); 
    array_free(nodes); 
    array_free(rects); 
    free(bitmap.pixels); 
}

load_and_prepare_texture :: (using texture: *Atlas_Texture_To_Pack) -> bool {
    bitmap.pixels = stbi_load(temp_c_string(filepath), *bitmap.width, *bitmap.height, *bitmap.channels, bitmap.desired_channels);
    if !bitmap.pixels {
        log("Failed to load texture from file: %", filepath);
        return false;
    }
    
    // TODO: consider first trimming the input image to remove transparent space on the margins, so that we can get a more tightly packed result
    
    dimensions := Vector2.{ xx bitmap.width, xx bitmap.height };
    dimensions *= get_scalar(dimensions, sizing);
    
    packed_width  := dimensions.x.(s32);
    packed_height := dimensions.y.(s32);
    
    resized := new_atlas_bitmap(packed_width, packed_height, 4);
    
    resize_result := stbir_resize_uint8(bitmap.pixels, bitmap.width, bitmap.height, 0, resized.pixels, resized.width, resized.height, 0, bitmap.channels);
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
    
    nodes = NewArray(textures_to_pack.count, stbrp_node);
    rects = NewArray(textures_to_pack.count, stbrp_rect);
    
    for textures_to_pack {
        rects[it_index] = .{ w = it.bitmap.width, h = it.bitmap.height };
    }
    
    // TODO: we could introduce some heuristic to automatically estimate the needed size for the atlas texutre,
    //       then resize to a larger texture if packing fails.
    //       maybe calculate total area required, then divide by 0.8 (assuming a modest 80% space utilization)
    
    ctx: stbrp_context;
    stbrp_init_target(*ctx, width, height, nodes.data, xx nodes.count);
    
    if !stbrp_pack_rects(*ctx, rects.data, xx rects.count) {
        log("Failed to pack rects for texture atlas: %", name);
        return false;
    }

    bitmap = new_atlas_bitmap(width, height, 4);
    dst_stride := get_stride_in_bytes(bitmap);
    
    bitmap_first_pixel := bitmap.pixels;
    bitmap_last_pixel  := bitmap.pixels + bitmap.width * bitmap.height * bitmap.channels;
    
    // print_vars(bitmap_first_pixel, bitmap_last_pixel);
    
    
    for rects {
        texture := *textures_to_pack[it_index];
        log("writing texture % to atlas", ifx texture.name else texture.filepath);
        
        src_image := texture.bitmap;
        assert(it.w == src_image.width);
        assert(it.h == src_image.height);
        
        
        src_first_pixel := src_image.pixels;
        src_last_pixel  := src_image.pixels + src_image.width * src_image.height * src_image.channels;
        
        // print_vars(src_first_pixel, src_last_pixel);
        
        sp := get_pixel_pointer(src_image, 0, 0);
        dp := get_pixel_pointer(bitmap, it.x, it.y);
        
        src_stride := get_stride_in_bytes(src_image);
        for 0..it.h-1 {
            memcpy(dp, sp, src_stride);
            dp += dst_stride;
            sp += src_stride;
        }
    }
    
    if !stbi_write_png(
        temp_c_string(image_filepath), 
        bitmap.width, 
        bitmap.height, 
        bitmap.channels, 
        bitmap.pixels, 
        dst_stride
    ) {
        log("Error: Failed to write atlas png file: %", image_filepath);
        return false;
    }
    
    info_builder: String_Builder;
    append(*info_builder, "clips: [\n");
    for rects {
        texture := *textures_to_pack[it_index];
        print(*info_builder, "{ name: \"%\", rect: [%,%,%,%] }\n", ifx texture.name else texture.filepath, it.x, it.y, it.w, it.h);
    }
    append(*info_builder, "]\n");
    if !write_entire_file(info_filepath, builder_to_string(*info_builder)) {
        log("Error: failed to write atlas info file: %", info_filepath);
        return false;
    }
    
    return true;
}

}   // end #if OS != .WASM