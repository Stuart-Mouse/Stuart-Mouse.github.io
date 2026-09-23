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


float CheckBoard(vec2 uv, float pix)
{
    uv *= (emulated_crt_resolution.x / 8.0);
    uv.x += time;
    uv.y += time;
    
    vec2 id = floor(uv);
    
    float factor = mod(id.x+id.y, 2.0);
    
    return factor;
}

float Vertical(vec2 uv, float pix)
{
    uv *= (emulated_crt_resolution.x / 8.0);
    uv.x += time / 2.0;
    uv.y += time / 2.0;
    
    vec2 id = floor(uv);
    
    float factor = mod(id.x, 2.0);
    
    return factor;
}

float Diamond(vec2 uv, float pix)
{
    uv *= (emulated_crt_resolution.x / 16.0);
    uv.x += time / 2.0;
    uv.y += time / 2.0;
    
    pix *= 10.0;
    
    vec2 newuv = vec2(0.0);
    newuv.x = uv.x - uv.y;
    newuv.y = uv.x + uv.y;
    
    vec2 id = sfloor2(newuv);
    
    float factor = mod(id.x+id.y, 2.0);
    
    return factor;
}

float Slash(vec2 uv, float pix)
{
    uv *= (emulated_crt_resolution.x / 8.0);
    uv.x += time / 2.0;
    uv.y += time / 2.0;
    
    pix *= 10.0;
    vec2 newuv = vec2(0.0);
    newuv.x = uv.x - uv.y;
    newuv.y = uv.x + uv.y;
    
    vec2 id = sfloor2(newuv);
    
    float factor = mod(id.x, 2.0);
    
    return factor;
}

// ref https://www.shadertoy.com/view/4dKXR3
float Triangle(vec2 uv, float pix)
{
    uv *= (emulated_crt_resolution.x / 16.0);
    uv.x += time / 2.0;
    uv.y += time / 2.0;
    
    pix *= 10.0;
    vec2 U = uv;               // centered coords
    
    U *= mat2(1,-1./1.73, 0,2./1.73);      // conversion to
    vec3 g = vec3(U,1.-U.x-U.y);          // hexagonal coordinates
    vec3 id = sfloor3(g);                         // cell id
    
    float factor = id.x + id.y + id.z+1.0;
    
    return factor;
}

// ref https://www.shadertoy.com/view/4dKXR3
float Hexagon1(vec2 uv, float pix)
{
    uv *= (emulated_crt_resolution.x / 24.0);
    uv.x += time / 2.0;
    uv.y += time / 2.0;
    
    pix *= 10.0;
    vec2 U = uv;               // centered coords
    
    U *= mat2(1,-1./1.73, 0,2./1.73);      // conversion to
    vec3 g = vec3(U,1.-U.x-U.y);           // hexagonal coordinates
    
    g = fract(g);                              // diamond coords
    if (length(g)>1.) g = 1.-g;                // barycentric coords
    vec3 g2 = abs(2.*fract(g)-1.);                  // distance to borders
    g -= 0.5;
    
    #if AA
        float threshold = pix/1.73;
        float factor = smoothstep(0.0, 1.5,g.x/min(threshold, fwidth(g.x)))
            + smoothstep(0.0, 1.5, g.y/min(threshold, fwidth(g.y)))
            + smoothstep(0.0, 1.5, g.z/min(threshold, fwidth(g.z)));
    #else
        float factor = step(0.0,g.x)+step(0.0,g.y)+step(0.0,g.z);
    #endif
    
    return factor;
}

float Hexagon2(vec2 uv, float pix)
{
    float factor = 1.0 - Hexagon1(uv, pix);
    
    return factor;
}

float Circle(vec2 uv, float pix)
{
    uv *= (emulated_crt_resolution.x / 32.0);
    uv.x += time / 2.0;
    uv.y += time / 2.0;
    
    vec2 id = floor(uv);
    uv = fract(uv)*2.0-1.0;
    
    float len = length(uv)-0.9;
    
    #if AA
        float factor = smoothstep(0.0, 1.5, len/fwidth(len)); // aa
    #else
        float factor = step(0.0, len);
    #endif
    
    factor = mod(id.x+id.y, 2.0)>0.5 ? factor : 1.0-factor;
    return factor;
}
	
float Pattern(vec2 uv, float pix)
{
    float patternNumber = 6.0;
    
    float time = fract(time / patternNumber) * patternNumber;
    
    if (time < 1.0)
        return CheckBoard(uv, pix);
        
    if (time < 2.0)
        return Vertical(uv, pix);
        
    if (time < 3.0)
        return Diamond(uv, pix);
        
    if (time < 4.0)
        return Slash(uv, pix);
        
    if (time < 5.0)
        return Triangle(uv, pix);
        
    if (time < 6.0)
        return Hexagon1(uv, pix);
        
    // if (time < 7.0)
    //     return Hexagon2(uv, pix);
        
    // if (time < patternNumber)
    //     return Circle(uv, pix);
        
    return 0.0;
}


void main() {
    vec2  uv     = gl_FragCoord.xy / emulated_crt_resolution.x;
    float pix    = 1.0 / emulated_crt_resolution.x;
    float factor = Pattern(uv, pix);
    
    float range = 0.3;
    color = vec4(vec3((1.0 - range) + factor * range), 1.0);
}

#endif
