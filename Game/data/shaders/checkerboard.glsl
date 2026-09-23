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

// #define emulated_crt_resolution (vec2(320.0, 240.0))

void main() {
    vec2 uv = gl_FragCoord.xy / 8.0;
    uv.x += time;
    uv.y += time;
    
    vec2 id = floor(uv);
    
    float factor = mod(id.x+id.y, 2.0);
    
    vec3 col = vec3(0.8 + factor * 0.2);
    color = vec4(col,1.0);
}

#endif
