
fast_rotation :: (v: Vector2, unit: Vector2) -> Vector2 { 
    return .{
        x = v.x *  unit.x + v.y * unit.y,
        y = v.x * -unit.y + v.y * unit.x,
    };
};

// Some helper macros for unit conversions
// maybe more general versions of these would be useful as utils
// Why magic number 24 here? I think just because it was common factor of 120 and 144 or something?
compute_friction   :: (x: float) -> float { return pow(x, 24.0 / updates_per_second); };    

// computes force required to move a given distance against a constant acceleration (gravity)
compute_jump_force :: inline (height: float, gravity: float) -> float { return sqrt(2.0 * gravity * height); }; 

units_per_second :: inline (u: float) -> float { return u / updates_per_second; } 

units_per_second_squared :: inline (u: float) -> float { return u / (updates_per_second * updates_per_second); } 

acceleration_for_velocity_over_time :: inline (velocity: float, seconds: float) -> float { return velocity / (seconds * updates_per_second); } 

length_less_than :: (a: Vector2, f: float) -> bool {
    return a.x*a.x + a.y*a.y < f*f;
}

length_greater_than :: (a: Vector2, f: float) -> bool {
    return a.x*a.x + a.y*a.y > f*f;
}

// inverse :: (a: Matrix2, epsilon := 0.001) -> Matrix2 {
//     r: Matrix2 = ---;
    
//     // Determinant.
//     det := a._11*a._22-a._12*a._21;
    
//     if (det < epsilon) && (det > -epsilon)  return a;  // Failure... undefined!

//     idet := 1/det;
    
//     r._11 =  idet*a._22;
//     r._12 = -idet*a._21;
//     r._21 = -idet*a._12;
//     r._22 =  idet*a._11;
//     return r;
// }

// make_rotation_matrix2 :: (a: float) -> Matrix2 {
//     sina := sin(-a);
//     cosa := cos(-a);
//     return .{ _11 = cosa, _12 = sina, _21 = -sina, _22 = cosa };
// }


// assumes value is from 0 to 1
smooth_0_to_1 :: (value: float) -> float {
	if (value <= 0.5) {
		// (2x)^2 / 2
		value *= 2.0;
		value *= value;
		value *= 0.5;
		return value;
	}
	else {
		// -((2(x-1))^2 / 2) + 1
		value = (value - 1.0) * 2.0;
		value *= -value;
		value = (value * 0.5) + 1.0;
		return value;
	}
}

// assumes value is from 0 to 1
smooth_0_to_1_sine :: (value: float) -> float {
	return (cos(PI * (value + 1.0)) / 2.0) + 0.5;
}


// got this one online somewhere... 
// TODO: need to make a version that will actually work for any size/signedness of int
next_power_of_2 :: (num: u32) -> u32 {
    if num != 0 {
        num -= 1;
        num |= (num >> 1);  // OR first 2 bits
        num |= (num >> 2);  // OR next  2 bits
        num |= (num >> 4);  // OR next  4 bits
        num |= (num >> 8);  // OR next  8 bits
        num |= (num >> 16); // OR next 16 bits
        num += 1;
    }
    return num;
}

rotate2D :: (m: *Matrix4, a: float) {
    cosa := cos(a);
    sina := sin(a);
    rm := Matrix4.{
       cosa, sina, 0, 0,
      -sina, cosa, 0, 0,
          0,    0, 1, 0,
          0,    0, 0, 1
    };
    m.* *= rm;
}

skew2D :: (m: *Matrix4, a: Vector2) {
   tanx := tan(a.x);
   tany := tan(a.y);
   rm := Matrix4.{
        1, tanx, 0, 0,
     tany,    1, 0, 0,
        0,    0, 1, 0,
        0,    0, 0, 1
   };
   m.* *= rm;
}

// silly wrapper but we doin it
transform_point :: (m: $T/interface AnyMatrix4x3, v: Vector2) -> Vector2 {
    return transform_point(m, .{ v.x, v.y, 0 }).xy;
}

to_Rect :: frect_to_rect;
frect_to_rect :: (frect: Rectf) -> Rect {
	return Rect.{
		cast(s32) floor(frect.x),
		cast(s32) floor(frect.y),
		cast(s32) floor(frect.w),
		cast(s32) floor(frect.h),
	};
}

to_Rectf :: rect_to_frect;
rect_to_frect :: (rect: Rect) -> Rectf {
	return Rectf.{
		cast(float) rect.x,
		cast(float) rect.y,
		cast(float) rect.w,
		cast(float) rect.h,
	};
}

snap_to_nearest_unit :: (point: float, unit: float) -> float {
    point_in_units       := point / unit;
    point_in_units_floor := floor(point_in_units);
    if point_in_units - point_in_units_floor < 0.5 
        return point_in_units_floor * unit;
    else return (point_in_units_floor + 1) * unit;
}

snap_to_nearest_unit :: (point: Vector2, unit: float) -> Vector2 {
    return .{
        x = snap_to_nearest_unit(point.x, unit),
        y = snap_to_nearest_unit(point.y, unit)
    };
}

// includes min and max in range
within_range :: inline (value: $T, min: T, max: T) -> bool 
#modify { return is_numeric_type(T); } {
    return value >= min && value <= max;
}

// Weighted_Choice :: struct {
//     value  : int;
//     weight : int;
// }

// get_weighted_choice :: (choices: [] Weighted_Choice) -> int {
//     sum := 0;
//     for choice: choices {
//         sum += choice.weight;
//     }
//     num := int(rand.int63_max(i64(sum)));
//     for choice: choices {
//         if num < choice.weight
//             return choice.value;
//         num -= choice.weight;
//     }
//     return choices[len(choices)-1].value;
// }

pixel_to_internal_units :: (pixel_position: Vec2i, internal_unit: float, pixel_offset: Vec2i = .{}, internal_offset: Vector2 = .{}) -> Vector2 {
    return .{
        x = (pixel_position.x - pixel_offset.x).(float) / internal_unit + internal_offset.x,
        y = (pixel_position.y - pixel_offset.y).(float) / internal_unit + internal_offset.y,
    };
}

// returns -1 if index is not in valid range
get_grid_index_checked :: (
    position:   Vector2, 
    tile_size:  Vector2, 
    grid_size:  Vec2i, 
    offset:     Vector2 = .{}, 
    margin:     Vector2 = .{}
) -> int {
    pos := position - offset + (margin / 2);
    index_2D := Vec2i.{
        floor(pos.x / (tile_size.x + margin.x)).(s32),
        floor(pos.y / (tile_size.y + margin.y)).(s32),
    };
    if index_2D.x < 0 || index_2D.x >= grid_size.x ||
       index_2D.y < 0 || index_2D.y >= grid_size.y {
        return -1;
    }
    return (index_2D.y * grid_size.x + index_2D.x).(int);
}

// TODO: rename margin to padding
get_grid_tile_rect :: (
    index:            int, 
    tile_size:        Vector2, 
    grid_size:        Vec2i, 
    internal_offset:  Vector2 = .{}, 
    pixel_offset:     Vector2 = .{},
    margin:           Vector2 = .{}
) -> Rectf {
    index_2D: Vec2i = .{
        cast(s32)(index) % grid_size.x,
        cast(s32)(index) / grid_size.x,
    };
    rect: Rectf = .{
        position = (tile_size + margin) * (to_Vec2f(index_2D) + internal_offset) - margin/2 + pixel_offset,
        size = tile_size + margin
    };
    if index_2D.x < 0 || index_2D.x >= grid_size.x ||
       index_2D.y < 0 || index_2D.y >= grid_size.y {
        return .{};
    }
    return rect;
}


backup_gl_state :: () #expand {
    // Backup GL state
    last_active_texture: GLenum;        glGetIntegerv(GL_ACTIVE_TEXTURE, xx *last_active_texture);
    last_program: GLuint;               glGetIntegerv(GL_CURRENT_PROGRAM, xx *last_program);
    last_texture: GLuint;               glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    last_sampler: GLuint;               glGetIntegerv(GL_SAMPLER_BINDING, xx *last_sampler);
    last_array_buffer: GLuint;          glGetIntegerv(GL_ARRAY_BUFFER_BINDING, xx *last_array_buffer);
    last_element_array_buffer: GLuint;  glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, xx *last_element_array_buffer);
    last_vertex_array: GLuint;          glGetIntegerv(GL_VERTEX_ARRAY_BINDING, xx *last_vertex_array);
    last_polygon_mode: [2]GLuint;       glGetIntegerv(GL_POLYGON_MODE, xx last_polygon_mode.data);
    last_viewport: [4]GLint;            glGetIntegerv(GL_VIEWPORT, last_viewport.data);
    last_scissor_box : [4]GLint;        glGetIntegerv(GL_SCISSOR_BOX, last_scissor_box.data);
    last_blend_src_rgb: GLenum;         glGetIntegerv(GL_BLEND_SRC_RGB, xx *last_blend_src_rgb);
    last_blend_dst_rgb: GLenum;         glGetIntegerv(GL_BLEND_DST_RGB, xx *last_blend_dst_rgb);
    last_blend_src_alpha: GLenum;       glGetIntegerv(GL_BLEND_SRC_ALPHA, xx *last_blend_src_alpha);
    last_blend_dst_alpha: GLenum;       glGetIntegerv(GL_BLEND_DST_ALPHA, xx *last_blend_dst_alpha);
    last_blend_equation_rgb: GLenum;    glGetIntegerv(GL_BLEND_EQUATION_RGB, xx *last_blend_equation_rgb);
    last_blend_equation_alpha: GLenum;  glGetIntegerv(GL_BLEND_EQUATION_ALPHA, xx *last_blend_equation_alpha);
    last_enable_blend :=                glIsEnabled(GL_BLEND);
    last_enable_cull_face :=            glIsEnabled(GL_CULL_FACE);
    last_enable_depth_test :=           glIsEnabled(GL_DEPTH_TEST);
    last_enable_scissor_test :=         glIsEnabled(GL_SCISSOR_TEST);
    
    `defer {
        // Restore modified GL state
        glUseProgram(last_program);
        glBindTexture(GL_TEXTURE_2D, last_texture);
        glBindSampler(0, last_sampler);
        glActiveTexture(last_active_texture);
        glBindVertexArray(last_vertex_array);
        glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, last_element_array_buffer);
        glBlendEquationSeparate(last_blend_equation_rgb, last_blend_equation_alpha);
        glBlendFuncSeparate(last_blend_src_rgb, last_blend_dst_rgb, last_blend_src_alpha, last_blend_dst_alpha);
        if last_enable_blend        glEnable(GL_BLEND);         else glDisable(GL_BLEND);
        if last_enable_cull_face    glEnable(GL_CULL_FACE);     else glDisable(GL_CULL_FACE);
        if last_enable_depth_test   glEnable(GL_DEPTH_TEST);    else glDisable(GL_DEPTH_TEST);
        if last_enable_scissor_test glEnable(GL_SCISSOR_TEST);  else glDisable(GL_SCISSOR_TEST);
        glPolygonMode(GL_FRONT_AND_BACK, last_polygon_mode[0]);
        glViewport(last_viewport[0], last_viewport[1], xx last_viewport[2], xx last_viewport[3]);
        glScissor(last_scissor_box[0], last_scissor_box[1], xx last_scissor_box[2], xx last_scissor_box[3]);
    }
}


// TODO: move this import somewhere else! This is stupid and obscure!
#import "meow_hash";
hash :: (bytes: string) -> (low64: u64, high64: u64) {
    #asm { Hash: vec; }
    MeowHash(MeowDefaultSeed, xx bytes.count, xx bytes.data, Hash);
    return MeowU64From(Hash, 0), MeowU64From(Hash, 1);
}






// TODO: move to another file
Range :: struct(T: Type) { min, max: T; }

random_get_within_range :: (using range: Range($T)) -> T {
    return random_get_within_range(range.min, range.max);
}

random_get_within_range :: (min: Vector2, max: Vector2) -> Vector2 {
    return .{
        random_get_within_range(min.x, max.x),
        random_get_within_range(min.y, max.y),
    };
}

random_get_within_range :: (min: Color4, max: Color4) -> Color4 {
    return .{
        random_get_within_range(min.r, max.r),
        random_get_within_range(min.g, max.g),
        random_get_within_range(min.b, max.b),
        random_get_within_range(min.a, max.a),
    };
}





// ========== Flat Pool ==========

// Moved these helper procs out of Utils module, will just have to duplicate it into other modules when needed.

// is_this_yours for flat pool allocator
// is_this_yours :: (pool: *Flat_Pool, memory: *void) -> bool {
//     return flat_pool_allocator_proc(.IS_THIS_YOURS, 0, 0, memory, pool).(bool);
// }

// copy_to_pool_if_needed :: (pool: *Flat_Pool, any: Any) -> Any {
//     if is_this_yours(pool, any.value_pointer)  return any;
    
//     copy := New_Any(any.type, initialized = false,, get_pool_allocator(pool));
//     memcpy(copy.value_pointer, any.value_pointer, any.type.runtime_size);
//     return copy;
// }

// copy_to_pool_if_needed :: (pool: *Flat_Pool, value: *$T) -> *T {
//     if is_this_yours(pool, value)  return value;
    
//     copy := get(pool, size_of(T)).(*T);
//     copy.* = value.*;
//     return copy;
// }

get_pool_allocator :: (pool: *Flat_Pool) -> Allocator {
    return .{ flat_pool_allocator_proc, pool };
}




/*
    Intended to be a general-purpose handle which can accept various types.
    Program could use this to allow lookup of various types of entities in type-agnostic systems.
    
    NOTE: not sure we need this right now for ui actually, since we can just use a type + index for entities, actually
          And even worse for the Any_Handle, it's not serializable due to use of a Type tag, so it's basically cooked.
          We could make the type/tag an Any_Number or Number_Union so that it can just store enum types, but then we might as well just make a 'General_Handle' that is specific to our program and uses a specific enum for type/tag
          
    In any case, leaving this here for now until I decide what to do ultimately...
*/
// Any_Handle :: struct {
//     type:           Type;
//     union {
//         index:      int;
//         pointer:    *void;
//     }
//     generation:     int;
// }

// so we can just #type,distinct for specific handle types
Generic_Handle :: struct {
    index, generation: int;
}

General_Handle :: struct {
    kind: Kind;
    
    using generic:  Generic_Handle;
    
    #place generic;
        entity:     Entity_Handle;
    
    Kind :: enum {
        NONE;
        TILEMAP;
        ENTITY;
    }
}

