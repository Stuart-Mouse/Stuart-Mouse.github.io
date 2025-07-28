
typedef struct Texture {
	SDL_Texture* id;
	int width;
	int height;
} Texture;

bool load_texture(SDL_Renderer* renderer, Texture* texture, const char* filename) {
	SDL_DestroyTexture(texture->id);
	if (!(texture->id = IMG_LoadTexture(renderer, filename))) {
		printf("Unable to load texture from file \"%s\"! SDL Error: %s\n", filename, SDL_GetError());
		return false;
	}
	SDL_QueryTexture(texture->id, NULL, NULL, &texture->width, &texture->height);
	return true;
}

uint32_t get_surface_pixel(SDL_Surface *surface, int x, int y) {
    int bpp = surface->format->BytesPerPixel;
    /* Here p is the address to the pixel we want to retrieve */
    uint8_t *p = (uint8_t *)surface->pixels + y * surface->pitch + x * bpp;

    switch (bpp) {
      case 1:
        return *p;
    
      case 2:
        return *(uint16_t *)p;
    
      case 3:
        if (SDL_BYTEORDER == SDL_BIG_ENDIAN)
            return p[0] << 16 | p[1] << 8 | p[2];
        else return p[0] | p[1] << 8 | p[2] << 16;

      case 4:
        return *(uint32_t *)p;
    }
    
    return 0;
}

void get_surface_pixel_rgba(SDL_Surface *surface, int x, int y, uint8_t *r, uint8_t *g, uint8_t *b, uint8_t *a) {
    uint32_t pixel = get_surface_pixel(surface, x, y);
    SDL_GetRGBA(pixel, surface->format, r, g, b, a);
}

bool check_pixel_alpha_in_range(SDL_Surface *surface, int x, int y, uint8_t min, uint8_t max) {
    if (!surface || x < 0 || x > surface->w || y < 0 || y > surface->h) return false;
    SDL_Color color;
    get_surface_pixel_rgba(surface, x, y, &color.r, &color.g, &color.b, &color.a);
    return color.a >= min && color.a <= max;
}

bool load_texture_keeping_surface(SDL_Renderer* renderer, Texture* texture, SDL_Surface** surface, const char* filename) {
    *surface = IMG_Load(filename); 
    if (*surface) {
        texture->id = SDL_CreateTextureFromSurface(renderer, *surface);
    	SDL_QueryTexture(texture->id, NULL, NULL, &texture->width, &texture->height);
    	SDL_SetTextureBlendMode(texture->id, SDL_BLENDMODE_BLEND);
    } else {
        printf("unable to load image %s", filename);
        return false;
    }
    return true;
}


