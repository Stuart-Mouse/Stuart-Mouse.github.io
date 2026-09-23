OUT_IN vec2 texture_coords;
OUT_IN vec4 iterated_color;
// OUT_IN vec2 pixel_position;


#ifdef VERTEX_SHADER
in vec4 vert_position;
in vec4 vert_color;
in vec2 vert_uv0;

uniform mat4 projection;
uniform mat4 transform;

void main() {
    texture_coords = vert_uv0.xy;
    gl_Position = projection * transform * vec4(vert_position.xy, 0.0, 1.0);
    iterated_color = vert_color;
    
    // pixel_position = vert_position.xy;
}
#endif // VERTEX_SHADER



#ifdef FRAGMENT_SHADER
out vec4 color;

uniform sampler2D diffuse_texture;
uniform float time;

#define emulated_crt_resolution (vec2(320.0, 240.0))


#define AA 1

// smoothfloor ref: https://www.shadertoy.com/view/tsyXzV
#if AA
    #  define sfloor(x) ( floor(x-pix/2.) + max( 0., 1.-fract(-x+pix/2.) / pix ) ) 
    #  define sfloor2(x) ( floor(x-vec2(pix/2.)) + max( vec2(0.), vec2(1.)-fract(-x+vec2(pix/2.)) / vec2(pix) ) ) 
    #  define sfloor3(x) ( floor(x-vec3(pix/2.)) + max( vec3(0.), vec3(1.)-fract(-x+vec3(pix/2.)) / vec3(pix) ) ) 
#else
    #  define sfloor(x) floor(x)
    #  define sfloor2(x) floor(x)
    #  define sfloor3(x) floor(x)
#endif


// TODO: instead of using normalized uv, just use pixel coordinates and take checkerboard tile size as a parameter here.
//       also make the timescale a paramter, and expose both tile size and timescale as uniforms
float checkerboard(vec2 uv)
{
    float time_factor = time;// / 10.0;
    
    uv *= (emulated_crt_resolution.x / 8.0);
    uv.x += time_factor;
    uv.y += time_factor;
    
    vec2 id = floor(uv);
    
    float factor = mod(id.x+id.y, 2.0);
    
    return factor;
}

void main() {
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = gl_FragCoord.xy/emulated_crt_resolution.x;
    float factor = checkerboard(uv, pix);
    
    vec3 col = vec3(0.8 + factor * 0.2);
    color = vec4(col,1.0);
}

#endif
