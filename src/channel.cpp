

// the area within foreground image that tv screen occupies
// normalized 0-1 along image axes so that we can just clip with respect to tv foreground image rect
FRect channel_viewport_clip = { 116.0/1000.0, 289.0/898.0, 615.0/1000.0, 436.0/898.0 };


// typedef void (*Channel_Proc)(void*);

// very general since channels may want to do anything
// update and render are function pointers, will just be cast to proper type
struct Channel {
    // int             number;
    void*           data;
    void (*init  )(void*);
    void (*update)(void*);
    void (*render)(void*);
};

// really no reason to even separate update and render, but its better for organization and slightly more future proof
// anything other than data pointer provided, renderer state, etc is just global data
// data specific to individual channels is still better passed explicitly so that struct for screen can use short names for variables and such


// channel index is not channel number, its an index to the valid channels array
int vhf_channel_index = 0;
// int current_uhf_channel_index = 0; // skip doing uhf for proof of concept (14 - 83)

Channel vhf_channels[13];
// Channel uhf_channels[13];

Channel* get_current_channel() {
    vhf_channel_index = clampi(vhf_channel_index, 0, 12);
    printf("channel is %f\n", vhf_channel_index);
    return &vhf_channels[vhf_channel_index];
}



/* 
    TV GUIDE
    
    channel  4: pong
    channel  7: TMH logo with static
    channel 11: fish tank
    channel 13: static-y face
    
*/


#include "breakout.cpp"
