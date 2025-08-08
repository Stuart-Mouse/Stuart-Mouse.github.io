
Direction :: enum u8 {
    U  :: 0;
    R  :: 1;
    D  :: 2;
    L  :: 3;
    UR :: 4;
    DR :: 5;
    DL :: 6;
    UL :: 7;
}

Direction_Set :: enum_flags u8 {
    U     :: 1 << Direction.U;
    R     :: 1 << Direction.R;
    D     :: 1 << Direction.D;
    L     :: 1 << Direction.L;
    UR    :: 1 << Direction.UR;
    DR    :: 1 << Direction.DR;
    DL    :: 1 << Direction.DL;
    UL    :: 1 << Direction.UL;
    
    USIDE :: U | UL | UR;
    DSIDE :: D | DL | DR;
    LSIDE :: L | UL | DL;
    RSIDE :: R | UR | DR;
    
    NONE  :: 0;
    ALL   :: 0b_1111_1111;
}

direction_set_from :: (directions: ..Direction) -> Direction_Set {
    ret: Direction_Set;
    for directions  ret |= xx 1 << it;
    return ret;
}

contains :: (set: Direction_Set, direction: Direction) -> bool {
    return (set & xx (1 << direction)) != 0;
}

contains :: (set: Direction_Set, other: Direction_Set) -> bool {
    return (set & other) == other;
}

direction_angles :: Enumerated_Array(Direction, float).{
    U  = 270,
    R  =   0,
    D  =  90,
    L  = 180,
    UR = 315,
    DR =  45,
    DL = 225,
    UL = 135,
};

direction_opposite :: Enumerated_Array(Direction, Direction).{  
    U  = .D,
    R  = .L,
    D  = .U,
    L  = .R,
    UR = .DL,
    DR = .UL,
    DL = .UR,
    UL = .DR,
};

// opposite :: (dir: Direction) -> Direction {
//     return ((dir.(u8) + 4) & 0b1111_1111).(Direction);
// }

direction_vectors :: Enumerated_Array(Direction, Vector2).{
    U  = .{  0, -1 },
    R  = .{  1,  0 },
    D  = .{  0,  1 },
    L  = .{ -1,  0 },
    UR = .{  1, -1 },
    DR = .{  1,  1 },
    DL = .{ -1,  1 },
    UL = .{ -1, -1 },
};


Direction_Flip :: enum_flags {
    NONE        :: 0;
    HORIZONTAL  :: 0b01;
    VERTICAL    :: 0b10;
}