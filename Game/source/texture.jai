
Texture :: Simp.Texture;

load_textures :: () {
    for *textures {
        path := textures_file_paths[it_index];
        Simp.texture_load_from_file(it, path);
    }
}

free_textures :: () {
    for *textures {
        Simp.texture_destroy(it);
    }
}


// For now, all textures are just stored in one global enumerated array.
textures: Enumerated_Array(Texture_ID, Texture);

Texture_ID :: enum {
    TILES;
    PLAYER;
    ENTITIES;       // includes other dynamic elements such as movement visualizers
    PARTICLES;
    SMALL_TEXT;
    UI_ELEMENTS;
}

textures_file_paths: Enumerated_Array(Texture_ID, string);
