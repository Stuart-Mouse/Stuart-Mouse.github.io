
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

load_sound :: (path: string) -> int {
    // we must stop all sounds before trying to load new sound data, 
    // since this may cause the loaded_sounds array to realloc, which holds sound data by value, which sound streams point at...
    Sound_Player.stop_all_sounds_abruptly(0);
    
    index := find_loaded_sound_index(path);
    if index == -1 {
        data := Sound_Player.load_audio_file(path);
        if data.loaded {
            array_add(*loaded_sounds, data);
            index = loaded_sounds.count-1;
        }
    }
    return index;
}

// uses relative path from data/sfx
load_sfx :: (filename: string) -> int {
    path := join("data/sfx/", filename,, temp);
    return load_sound(path);
}

// thin wrapper around sound data for sound effects that entities player
// add some paramters for randomization of the sound
// idk about the name...
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
    index := load_music(filename);
    if index != -1  play_music(index);
}

// uses relative path from data/music
load_music :: (filename: string) -> int {
    path  := join("data/music/", filename,, temp);
    return load_sound(path);
}

play_music :: (index: int = -1) {
    if index == -1 && active_music.index == -1  return;
    
    if index == -1 || index == active_music.index {
        assert(active_music.stream != null);
        
        if active_music.stream.user_flags & .PAUSED_DUE_TO_MENU {
            active_music.stream.user_flags &= ~.PAUSED_DUE_TO_MENU;
        }
        else if active_music.stream.samples_streamed_since_entity_update == 0 {
            // NOTE: the above condition may be totally inappropriate as a way 
            // to check if sound is currently playing, but it seems to work...
            Sound_Player.start_playing(active_music.stream);
        }
        return;
    }
    
    stop_music();
    
    data := *loaded_sounds[index];
    if !data.loaded  return;
    
    active_music.index  = index;
    active_music.stream = Sound_Player.make_stream(data, .MUSIC);
    
    // TODO: make this configurable when we figure out how we want to load music for levels
    active_music.stream.user_volume_scale = 0.75;
    Sound_Player.set_repeating(active_music.stream, true);
    Sound_Player.start_playing(active_music.stream);
}

stop_music :: () {
    if active_music.index != -1 {
        data := *loaded_sounds[active_music.index];
        if data.loaded && active_music.stream {
            Sound_Player.stop_stream_abruptly(data);
            active_music = .{};
        }
    }
}

pause_music :: () {
    if active_music.stream {
        active_music.stream.user_flags |= .PAUSED_DUE_TO_MENU;
    }
}

active_music: struct {
    index: int = -1;
    stream: *Sound_Player.Sound_Stream = null;
};


