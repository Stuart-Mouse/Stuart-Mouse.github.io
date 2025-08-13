
// in order to prevent duplication of Sound_Data structures, we just store all loaded sounds in a global array and refer to the sounds by index
loaded_sounds: [..] Sound_Player.Sound_Data;

free_sound_data :: (data: *Sound_Player.Sound_Data) {
    Sound_Player.stop_stream_abruptly(data);
    free(data.name);
    free(data.buffer);
}

free_loaded_sounds :: () {
    Sound_Player.stop_all_sounds_abruptly(0);
    for *loaded_sounds {    
        free_sound_data(it);
    }
    array_reset(*loaded_sounds);
}

find_loaded_sound_index :: (path: string) -> int {
    for loaded_sounds  if it.full_path == path  return it_index;
    return -1;
}

// TODO: put music and sfx into a common 'audio' folder
// then probably get rid of the separate loading functions, since this just complicates things

// uses absolute path
load_sound :: (path: string) -> int {
            log("loading audio file '%'...", path);

    // we must stop all sounds before trying to load new sound data, 
    // since this may cause the loaded_sounds array to realloc, which holds sound data by value, which sound streams point at...
    Sound_Player.stop_all_sounds_abruptly(0);
    
    log("asf");
    index := find_loaded_sound_index(path);
    if index == -1 {
        data := Sound_Player.load_audio_file(path);
        if data.loaded {
            array_add(*loaded_sounds, data);
            index = loaded_sounds.count-1;
            log("Loaded audio file '%'", path);
        }
    }
    return index;
}

// uses relative path from data/sfx
load_sfx :: (filename: string) -> int {
    path := join(executable_path, "data/sfx/", filename,, temp);
    return load_sound(path);
}

// // thin wrapper around sound data for sound effects that entities player
// // add some paramters for randomization of the sound
// // idk about the name...
Noise :: struct {
    index: int;
    volume_scale_range: [2] float;
    rate\ _scale_range: [2] float;
}

play :: (noise: Noise) {
    if noise.index < 0 || noise.index >= loaded_sounds.count  return;
    stream := Sound_Player.make_stream(*loaded_sounds[noise.index], .GENERAL_SFX);
    stream.user_volume_scale = random_get_within_range(noise.volume_scale_range[0], noise.volume_scale_range[1]);
    stream.rate_scale        = random_get_within_range(noise.rate\ _scale_range[0], noise.rate\ _scale_range[1]);
    Sound_Player.start_playing(stream);
}

/*
    Music is all globally managed, since we will only ever want to play one track of music at the same time.
    Currently, the only functionality is to start and stop the music, 
        but we should later add the option to fade the music in and out.
*/

load_and_play_music :: (filename: string) {
    if load_music(filename)  play_music();
}

// uses relative path from data/music
load_music :: (filename: string) -> bool {
    path  := join(executable_path, "/data/music/", filename,, temp);
    index := load_sound(path);
    if index == -1  return false;
    
    active_music.index  = index;
    active_music.stream = null;
    // log("Loaded audio file '%'", path);
    return true;
}

play_music :: () {
    if active_music.index == -1  return;
    
    data := *loaded_sounds[active_music.index];
    if !data.loaded  return;
    
    if !active_music.stream {
        active_music.stream = Sound_Player.make_stream(data, .MUSIC);
        
        // TODO: make this configurable when we figure out how we want to load music for levels
        active_music.stream.user_volume_scale = 0.75;
        Sound_Player.set_repeating(active_music.stream, true);
    }
    
    if active_music.stream.user_flags & .PAUSED_DUE_TO_MENU {
        active_music.stream.user_flags &= ~.PAUSED_DUE_TO_MENU;
    }
    else if active_music.stream.samples_streamed_since_entity_update == 0 {
        // NOTE: the above condition may be totally inappropriate as a way 
        // to check if sound is currently playing, but it seems to work...
        Sound_Player.start_playing(active_music.stream);
    }
}

stop_music :: () {
    if active_music.index != -1 {
        data := *loaded_sounds[active_music.index];
        if data.loaded && active_music.stream {
            Sound_Player.stop_stream_abruptly(data);
        }
    }
}

pause_music :: () {
    if active_music.stream 
        active_music.stream.user_flags |= .PAUSED_DUE_TO_MENU;
}

active_music: struct {
    index:  int           = -1;
    stream: *Sound_Player.Sound_Stream = null;
};


