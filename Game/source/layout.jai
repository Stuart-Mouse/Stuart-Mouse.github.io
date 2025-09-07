
#add_context layout_context: Layout_Context;
Layout_Context :: struct {
    base_unit:      float = 1;  // base unit for all absolute unit types
    tile_unit:      float;
    viewport:       Rectf;
    window_size:    Vector2;
}

/*
    set_window_dimensions(x, y)
    set_viewport(x, y, w, h)
    
    
*/

NULL_LAYOUT :: Layout.{};

Layout :: struct {
    position:   Position;
    offset:     Position;
    size:       Size;
}

Unit :: enum {
    // absolute units
    BASE;
    TILE;
    CLIP;
    
    // relative units
    VIEWPORT;
    WINDOW;
    SELF;
    PARENT;
}

Size :: struct {
    units:          Unit;
    value:          Vector2;
    scale_axis:     Axis;
}

Position :: struct {
    units:          Unit;
    value:          Vector2;
    mode:           Mode;
    
    Mode :: enum {
        ABSOLUTE;
        PARENT;
        VIEWPORT;
    }
}

get_rect :: (layout: Layout, clip := Rectf.{}, parent := Rectf.{}) -> Rectf {
    using context.layout_context;
    using rect: Rectf;
    
    if layout.size.units == {
      case .BASE;
        size = layout.size.value * base_unit;
        
      case .TILE;
        size = layout.size.value * tile_unit * base_unit;
        
      case .VIEWPORT;
        size = layout.size.value * viewport.size;
        
      case .WINDOW;
        size = layout.size.value * window_size;
        
      case .CLIP;
        size = layout.size.value * clip.size * base_unit;
        
      case .PARENT;
        size = layout.size.value * parent.size;
    }
    
    // get base position from positioning mode
    if layout.position.mode == {
      case .ABSOLUTE;   // no offset
      case .PARENT;     position = parent.position;
      case .VIEWPORT;   position = viewport.position;
    }
    
    if layout.position.units == {
      case .BASE;
        position += layout.position.value * base_unit;
        
      case .TILE;
        position += layout.position.value * tile_unit * base_unit;
        
      case .VIEWPORT;
        position += layout.position.value * viewport.size;
        
      case .WINDOW;
        position += layout.position.value * window_size;
        
      case .CLIP;
        log("Error: cannot position in terms of clip units!");
        
      case .SELF;
        log("Error: cannot position in terms of self units!");
        
      case .PARENT;
        position += layout.position.value * parent.size;
    }
    
    if layout.offset.units == {
      case .BASE;
        position += layout.offset.value * base_unit;
        
      case .TILE;
        position += layout.offset.value * tile_unit * base_unit;
        
      case .VIEWPORT;
        position += layout.offset.value * viewport.size;
        
      case .WINDOW;
        position += layout.offset.value * window_size;
        
      case .CLIP;
        position += layout.offset.value * clip.size * base_unit;
        
      case .SELF;
        position += layout.offset.value * size;
        
      case .PARENT;
        position += layout.offset.value * parent.size;
    }
    
    return rect;
}

