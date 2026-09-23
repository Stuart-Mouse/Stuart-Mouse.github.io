OUT_IN vec2 texture_coords;
OUT_IN vec4 iterated_color;


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


float Vertical(vec2 uv, float pix)
{
    uv *= (emulated_crt_resolution.x / 8.0);
    uv.x += time / 2.0;
    uv.y += time / 2.0;
    
    vec2 id = floor(uv);
    
    float factor = mod(id.x, 2.0);
    
    return factor;
}


void main() {
    vec2  uv     = gl_FragCoord.xy / emulated_crt_resolution.x;
    float pix    = 1.0 / emulated_crt_resolution.x;
    float factor = Vertical(uv, pix);
    
    float range = 0.3;
    color = vec4(vec3((1.0 - range) + factor * range), 1.0);
}

#endif
