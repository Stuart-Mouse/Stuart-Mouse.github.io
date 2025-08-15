
Fixed_Array :: struct(capacity: int, T: Type) {
    count:  int;
    data:   [capacity] T;
}

to_view :: (array: *Fixed_Array) -> array.T {
    return .{ array.count, *array.data };
}

copy_from_view :: (array: *Fixed_Array, view: [] array.T) -> bool {
    if view.count > array.capacity  return false;
    
    array.count = view.count;
    memcpy(*array.data, view.data, view.count);
}

operator *[] :: inline (array: *Fixed_Array, index: int) -> *array.T { return *array.data[index]; }
operator  [] :: inline (array:  Fixed_Array, index: int) ->  array.T { return  array.data[index]; }

