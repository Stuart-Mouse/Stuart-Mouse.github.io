

/*
    default text render color is white because we can always colormod it before rendering to whatever other color we want that way
*/

bool render_font_to_texture_keeping_surface(Texture *texture, SDL_Surface** surface, TTF_Font *font, const char *text, Color4 color = { 1, 1, 1, 1 }, uint32_t wrap_width = 0) {
    if (texture->id) SDL_DestroyTexture(texture->id);
    if (*surface) SDL_FreeSurface(*surface);
    
    *surface = TTF_RenderUTF8_Blended_Wrapped(font, text, SDL_Color {
        .r = (uint8_t)(color.r * 255.0),
        .g = (uint8_t)(color.g * 255.0),
        .b = (uint8_t)(color.b * 255.0),
        .a = (uint8_t)(color.a * 255.0)
    }, wrap_width);
    if (*surface) {
        texture->id = SDL_CreateTextureFromSurface(renderer, *surface);
    	SDL_QueryTexture(texture->id, NULL, NULL, &texture->width, &texture->height);
    	SDL_SetTextureBlendMode(texture->id, SDL_BLENDMODE_BLEND);
    } else {
        return false;
    }
    return true;
}

bool render_font_to_texture(Texture *texture, TTF_Font *font, const char *text, Color4 color = { 1, 1, 1, 1 }, uint32_t wrap_width = 0) {
    SDL_Surface *surface = NULL;
    bool ret = render_font_to_texture_keeping_surface(texture, &surface, font, text, color, wrap_width);
    SDL_FreeSurface(surface);
    return ret;
}




Texture small_text_texture;

// if max_len is nonzero, will only print up to the specified number of characters from the passed string
int render_small_text(const char* text, int x, int y, int max_len, float text_align, float scale) {
    int str_len = strlen(text);
    
    bool do_ellipsis = false;
    if (max_len > 0 && max_len < str_len) {
        str_len = max_len - 2;
        do_ellipsis = true;
    }
    
    int char_width  = 8.0 * scale;
    int char_height = 8.0 * scale;
    
    x -= (float)str_len * char_width;
    
    Rect dst_rect = { x, y, char_width, char_height };
    Rect clip     = { 0, 0, char_width, char_height };
    
    for (int i = 0; i < str_len; i++) {
        char c = text[i];
        clip.x = (c % 16) * char_width;
        clip.y = (c / 16) * char_height;
        SDL_RenderCopy(renderer, small_text_texture.id, &clip.sdl, &dst_rect.sdl);
        dst_rect.x += char_width;
    }
    if (do_ellipsis) {
        char c = '.';
        clip.x = (c % 16) * char_width;
        clip.y = (c / 16) * char_height;
        SDL_RenderCopy(renderer, small_text_texture.id, &clip.sdl, &dst_rect.sdl);
        dst_rect.x += char_width;
        SDL_RenderCopy(renderer, small_text_texture.id, &clip.sdl, &dst_rect.sdl);
        dst_rect.x += char_width;
    }
    
    return dst_rect.x - x;
}

void render_small_text_int(int num, int radix, int x, int y, int max_len, float text_align, float scale) {
    char buffer[32];
    // itoa(num, buffer, radix);
    sprintf(buffer, "%d", num);
    render_small_text(buffer, x, y, max_len, text_align, scale);
}

// void render_small_text_float(int num, int x, int y, int max_len, float text_align, float scale) {
//   char buffer[32];
//   sprintf(buffer, "%f", num)
//   render_small_text(text, x, y, max_len, text_align, scale)
// }

