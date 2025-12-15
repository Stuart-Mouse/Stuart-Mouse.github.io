"use strict";

// These are all the functions that we declared as "#foreign" in our Jai code.
// They let you interact with the JS and DOM world from within Jai.
const jai_imports = {};

const entry_point = () => {
    while (true) {
        try {
            jai_exports.__program_main(jai_context);
        } catch (e) {
            create_fullscreen_canvas("Program exited due to an exception.\nSee console for details.");
            console.error(e);
            return;
        }
        
        // The exit from main was the application actually exitting
        if (active_jmp_buf === 0n) {
            jai_imports.js_exit(0);
            return;
        }
        
        // The exit from main happened because the we are either doing setjmp/longjmp stuff or we are pausing execution.
        try {
            jai_exports.asyncify_stop_unwind();
        } catch (e) {
            // Asyncify "gurantees" that no memory corruption has happened in the case of a failed operation
            // so we can just reset the jmp_buf and call js_exit which will in turn call an exit handler if you defined one
            new DataView(jai_exports.memory.buffer).setInt32(Number(active_jmp_buf)+JMP_BUF_OFFSET_STATE, JMP_BUF_STATE_INITIALIZED, true);
            jmp_buf_reset(active_jmp_buf);
            active_jmp_buf = 0n;
            
            // :JmpBufVoodoo: we linearly increase the size of the jmp_buf storage because the default page size should be pretty big already
            const old_size = get_jmp_buf_storage_size();
            const new_size = old_size + BigInt(pwa_manifest.default_jmp_buf_storage_size);
            localStorage.setItem(JMP_BUF_SIZE_KEY, new_size.toString());
            
            // We add a breakpoint so that you have a better chance of catching this during development.
            // If you do you should inscrease the jmp_buf_default_storage_size
            debugger;
            
            // We use a 0 exit code with a reload() so that the user rovided wasm_at_exit can act as though no error has occurred and just save data and we reload the page
            // with the bigger buffer to recover from this error. Maybe it would be better to just pass a specific error code so that the user and the default js_exit
            // can handle it more explicitly? Idk man -nzizic, 8 November 2025
            jai_imports.js_exit(0);
            location.reload();
            return;
        }
        
        // wasm_prepare_rewind returns true if active_jmp_buf was unwound with
        // the intention of being rewound immediately (setjmp was called)
        // and returns false if active_jmp_buf was unwound with the intent
        // of being rewound at a later point (wasm_pause was called).
        if (wasm_prepare_for_rewind()) {
            jai_exports.asyncify_start_rewind(active_jmp_buf);
        } else {
            // do NOT rewind and do NOT re-enter __program_main
            return;
        }
    }
};

addEventListener("load", async () => {
    await initialize_wasm_module("main.wasm");
    document.title = pwa_manifest.name;
    entry_point();
});

const create_fullscreen_canvas = (text) => {
    const canvas = document.createElement("canvas");
    const font_name = "Georgia";
    canvas.id = "fullscreen_canvas";
    canvas.style.position = "fixed";
    canvas.style.left = "0";
    canvas.style.top = "0";
    canvas.style.width = "100%";
    canvas.style.height = "100%";
    document.body.appendChild(canvas);

    const draw = () => {
        const ctx = canvas.getContext("2d");
        canvas.width = canvas.clientWidth;
        canvas.height = canvas.clientHeight;
        
        ctx.fillStyle = "dimgray";
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        
        let font_size = 60;
        let line_height = 70;
        ctx.font = `${font_size}px ${font_name}`;
        const lines = text.split("\n");
        let max_width = 0;
        lines.forEach(line => {
            const w = ctx.measureText(line).width;
            if (w > max_width) max_width = w;
        });
        const n = lines.length;
        const required_width = max_width;
        const required_height = n > 0 ? (n - 1) * line_height + font_size : font_size;
        const padding_factor = 0.9;
        const scale_w = (canvas.width * padding_factor) / required_width;
        const scale_h = (canvas.height * padding_factor) / required_height;
        const scale = Math.min(scale_w, scale_h, 1);
        font_size *= scale;
        line_height *= scale;
        ctx.font = `${font_size}px ${font_name}`;
        ctx.fillStyle = "white";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        lines.forEach((line, index) => {
            const y = (canvas.height / 2) + (index - (n - 1) / 2) * line_height;
            ctx.fillText(line, canvas.width / 2, y);
        });
    };

    draw();
    addEventListener("resize", draw);
};

const initialize_wasm_module = async (module_path) => {
    // We use the PWA manifest to store paths to cached assets in addition to metadata about the application
    const response = await fetch(document.querySelector('link[rel="manifest"]').href);
    pwa_manifest   = await response.json();
    
    // If you forget to implement something jai_imports expects, the Proxy below will log a nice error.
    const imports = {
        "env": new Proxy(jai_imports, {
            get(target, prop, receiver) {
                if (target.hasOwnProperty(prop)) return target[prop];
                return () => { throw new Error("Missing function: " + prop); };
            },
        }),
        "memory": new WebAssembly.Memory({"initial": pwa_manifest.initial_pages}),
    };
    
    
    // load the wasm module and extract what we want from it
    const module = await WebAssembly.instantiateStreaming(fetch(module_path), imports);
    jai_exports  = module.instance.exports;
    jai_context  = jai_exports.__jai_runtime_init(0, 0n);
    
    const jmp_buf_storage_size = get_jmp_buf_storage_size();
    const jmp_buf_storage = jai_exports.malloc(jmp_buf_storage_size*2n);
    
    jmp_buf_for_pausing = jai_exports.jmp_buf_for_pausing.value;
    jmp_buf_init(jmp_buf_for_pausing, jmp_buf_storage);
    
    jmp_buf_for_garbage = jai_exports.jmp_buf_for_garbage.value;
    jmp_buf_init(jmp_buf_for_garbage, jmp_buf_storage+jmp_buf_storage_size);
    
    opfs_home_folder               = await opfs_ensure_path_exists(document.location.pathname, true);
    opfs_current_working_directory = opfs_home_folder;
    opfs_copied_files_folder       = await opfs_ensure_path_exists(OPFS_COPIED_FILES_PATH, true);
}

// Contains metadata about the application, search for DEFAULT_MANIFEST_JSON in modules/Web/Progressive_Web_App.jai for more info
let pwa_manifest;

let jai_exports; // contains procedures and globals from the loaded wasm module
let jai_context; // *Runtime_Support.first_thread_context

// Used by the js runtime to pause and resume the
// wasm module when waiting for async APIs
let jmp_buf_for_pausing;

// In order to implement longjmp we have to unwind the current
// stack and then never rewind back to it, so we the runtime
// allocates another jmp_buf in initialize_wasm_module()
// that we reuse every time we want to unwind a stack and
// never return.
let jmp_buf_for_garbage;


// We create a "home folder" for the application so that multiple applications served by the same origin
// do not trample eachothers files. We use document.location.pathname because it mirrors the location
// of the wasm module relative to the server. So if you had a wasm module being served from
// www.mycoolwebsite.com/tools/foozler the home folder would be "/tools/foozler"
let opfs_home_folder;               // set by initialize_wasm_module()
let opfs_current_working_directory; // initially set to opfs_home_folder
let opfs_copied_files_folder;       // for files copied from the system (drag and drop, open file dialog, etc)

// Although we have a notion of a program's home folder, we have a "global" place for
// files generated from the client's *real* file system. This is because we already mark
// filenames that we generate with a timestamp to disambiguate files with the same name.
const OPFS_COPIED_FILES_PATH = "/__jai_runtime_copied_files/";



// There is currently no way to pass a js object into wasm code, so we provide a mechanism for mapping
// an object to a 32 bit integer handle. You can pass any js object to reserve_object_handle to get a handle
// that you can pass to your jai code. You use set_object_from_handle and get_object_from_handle in your js code
// to associate that handle with whatever kind of object you want. Use release_object_handle(id_you_got) to 
// allow that slot to be reused by subsequent reserve_object_handle calls. See the WebGL and File modules
// for more detailed example usage.
// IMPORTANT: Do not use the given handle to index directly into the jai_handle_to_js_object array! The handle
// is the index into the array offset by 1 in order to make 0 an invalid handle. We do this for two reasons:
// 1.) OpenGL uses an id of 0 to indicate no id, 
// 2.) Not allowing a 0 id means that you can pass a handle directly into wasm_resume without issue

const jai_handle_to_js_object = [];
let   jai_handle_free_list    = undefined; // index into jai_handle_to_js_object
const jai_handle_is_invalid   = (handle) => typeof(handle) !== 'number' || !Number.isInteger(handle) || handle <= 0;

const reserve_object_handle = (obj) => {
    let idx = jai_handle_to_js_object.length;
    if (jai_handle_free_list !== undefined) {
        idx = jai_handle_free_list;
        jai_handle_free_list = jai_handle_to_js_object[idx];
    }
    jai_handle_to_js_object[idx] = obj;
    const handle = idx+1;
    return handle;
};

const release_object_handle = (handle) => {
    if (jai_handle_is_invalid(handle)) throw new Error(`Invalid jai handle ${handle}`);
    
    const idx = handle-1;
    jai_handle_to_js_object[idx] = jai_handle_free_list; // either undefined or next free index
    jai_handle_free_list = idx;
    // console.log("release_object_handle", handle);
};

const get_object_from_handle = (handle) => {
    if (handle === 0) return null; // Maybe this is error prone? But it makes webgl stuff easier....
    if (jai_handle_is_invalid(handle)) throw new Error(`Invalid jai handle ${handle}`);
    
    const idx = handle-1;
    const obj = jai_handle_to_js_object[idx];
    // console.log("get_object_from_handle", handle, obj);
    return obj;
};

const set_object_from_handle = (handle, obj) => {
    if (jai_handle_is_invalid(handle)) throw new Error(`Invalid jai handle ${handle}`);
    
    const idx = handle-1;
    jai_handle_to_js_object[idx] = obj;
    // console.log("set_object_from_handle", handle, obj);
};



/*

Exports needed for Runtime_Support.jai and the C code included with the Jai distribution

*/

// TODO: the search for memcmp continues....
jai_imports.memcmp = (a, b, count) => {
    const [na, nb, nc] = [Number(a), Number(b), Number(count)];
    const u8    = new Uint8Array(jai_exports.memory.buffer);
    const buf_a = u8.subarray(na, na + nc);
    const buf_b = u8.subarray(nb, nb + nc);
    for (let i = 0; i < count; i++) {
        const delta = Number(buf_a[i]) - Number(buf_b[i]);
        if (delta !== 0) return delta;
    }
    return 0;
};

jai_imports.js_write_string = (s_count, s_data, to_standard_error) => {
    // since this is only called by write_string_unsynchronized we do not pass is_constant
    const js_string = copy_string_to_js(s_count, s_data, false);
    write_to_console_log(js_string, to_standard_error);
};

jai_imports.js_debug_break = () => { debugger; };

// if your program defines a #program_export wasm_at_exit :: (code: s32) we call that, otherwise we have some default logic that reloads the page when the
// exit code is 0 and indicates an error happened otheriwse.
let program_exited = false;
jai_imports.js_exit = (code) => {
    program_exited = true; // this makes wasm_resume a no-op since we do no want to resume if we want to exit
    if (jai_exports.wasm_at_exit !== undefined) {
        jai_exports.wasm_at_exit(jai_context, code);
        wasm_pause(); // prevent further execution
        return;
    }
    
    if (code === 0) {
        // Because a PWA is a long running interactive application, it isn't expected you will exit unless something
        // bad happens. Reloading the page makes games like Invaders restart when you lose which seems like reasonable
        // enough behaviour for most programs written in this style.    -nzizic, 27 June 2025
        location.reload();
    } else {
        wasm_pause(); // prevent further execution
        // Remove any existing canvases so that the user can see the error code message
        document.querySelectorAll("canvas").forEach(canvas => canvas.remove());
        create_fullscreen_canvas(`Program exited with error code ${code}.\nSee console for details.\n`);
    }
};

// jai_imports.js_alloca = (size) => jai_exports.temporary_alloc(jai_context, size);

// for c code that needs math.h
jai_imports.js_log   = Math.log;
jai_imports.js_exp   = Math.exp;
jai_imports.js_pow   = Math.pow;
jai_imports.js_sin   = Math.sin;
jai_imports.js_cos   = Math.cos;
jai_imports.js_abs   = Math.abs;
jai_imports.js_floor = Math.floor;


// If you have a batch program you need to explicitly yield control back to the browser so that it doesn't lock up.
// Normal programs yield implicitly during procs like js_webgl_swap_buffers. We don't use setTimeout(proc, 0) since that
// gets capped to 5ms if you spam it while this resumes execution as soon as possible. You have to explictly do "js_yield :: () #foreign;"
// in order to get access this procedure. We could put this declaration i Runtime_Support.jai, but I am bit too sheepish to do that atm.
const yield_resume_channel = new MessageChannel();
yield_resume_channel.port1.onmessage = (e) => { wasm_resume(e.data) };
jai_imports.js_yield = () => { if (wasm_pause() === 0) yield_resume_channel.port2.postMessage(1); }


let active_jmp_buf = 0n;

jai_imports.js_setjmp = (jmp_buf) => {
    // This checks wether this is the initial call to setjmp
    // from wasm code (i.e. not js calling wasm_pause).
    if (active_jmp_buf === 0n && jmp_buf !== jmp_buf_for_pausing) {
        // @Leak this allocates memory, but libc setjmp/longjmp does not have an
        // API for deiniting jmp_bufs. In practice it's fine since these only get
        // initialized at startup. You could write some pathological code that uses
        // stack-allocated jmp_bufs inside the body of a loop that would cause a more
        // serious leak, so just don't do that ok!?
        jmp_buf_init(jmp_buf);
    }
    
    const view = new DataView(jai_exports.memory.buffer);
    const buf  = Number(jmp_buf);
    
    if (active_jmp_buf !== 0n && active_jmp_buf !== jmp_buf) throw new Error(`unreachable? ${active_jmp_buf} ${jmp_buf}`);
    
    const state = view.getInt32(buf+JMP_BUF_OFFSET_STATE, true);
    if (state === JMP_BUF_STATE_INITIALIZED) {
        view.setInt32(buf+JMP_BUF_OFFSET_VALUE, 0, true);
        view.setInt32(buf+JMP_BUF_OFFSET_STATE, JMP_BUF_STATE_CAPTURING, true);
        active_jmp_buf = jmp_buf;
        jmp_buf_reset(jmp_buf);
        jai_exports.asyncify_start_unwind(jmp_buf);
        return 0; 
    } else if (state === JMP_BUF_STATE_CAPTURING) {
        if (active_jmp_buf !== jmp_buf) throw new Error(`unreachable? ${active_jmp_buf} ${jmp_buf}`);
        view.setInt32(buf+JMP_BUF_OFFSET_STATE, JMP_BUF_STATE_CAPTURED, true);
        active_jmp_buf = 0n;
        jai_exports.asyncify_stop_rewind();
        return 0;
    } else if (state === JMP_BUF_STATE_RETURNING) {
        view.setInt32(buf+JMP_BUF_OFFSET_STATE, JMP_BUF_STATE_CAPTURED, true);
        active_jmp_buf = 0n;
        jai_exports.asyncify_stop_rewind();
        return view.getInt32(buf+JMP_BUF_OFFSET_VALUE, true);
    } else {
        throw new Error(`unreachable jmp_buf state ${state}`);
    }
};

jai_imports.js_longjmp = (jmp_buf, value) => {
    if (active_jmp_buf !== 0n) throw new Error(`Unreachable? ${active_jmp_buf} ${jmp_buf}`);
    if (jmp_buf === 0n) throw new Error(`Unreachable? ${active_jmp_buf} ${jmp_buf}`);
    if (value === 0) throw new Error("Dude do not pass 0 to longjmp what is wrong with you?");
    
    const view = new DataView(jai_exports.memory.buffer);
    const buf  = Number(jmp_buf);
    
    // It would be really cool if there was a way to just unwind without doing any of the saving.
    // But after staring at https://github.com/WebAssembly/binaryen/blob/main/src/passes/Asyncify.cpp
    // for way too long trying to make asyncify_start_unwind() not save the locals if the provided
    // jmp_buf was null I gave up. So for now our runtime has to allocate another buffer to make
    // this work. If you or a loved one could figure this out, I would be very happy.
    // -nzizic, 1 July 2025
    view.setInt32(buf+JMP_BUF_OFFSET_VALUE, value, true);
    view.setInt32(buf+JMP_BUF_OFFSET_STATE, JMP_BUF_STATE_RETURNING, true);
    active_jmp_buf = jmp_buf;
    jmp_buf_reset(jmp_buf_for_garbage);
    jai_exports.asyncify_start_unwind(jmp_buf_for_garbage);
};

// :JmpBufVoodoo: This might a bad idea for serious projects, but emscripten crashes and tells you to recompile your entire
// application if the buffer is too small which makes this objectively better UX... Actually upon further inspection emscripten does not
// tell you anything; it just runs the "unreachable" instruction inside of the asyncify_* procs without catching the resulting exception.
// Absolutely pathetic. What we do is reload the page and save a value in localStorage that indicates a larger buffer size.
const JMP_BUF_SIZE_KEY = `${document.location.pathname}__JMP_BUF_SIZE__`;
const get_jmp_buf_storage_size = () => {
    const local = localStorage.getItem(JMP_BUF_SIZE_KEY);
    if (local) return BigInt(local); // we return BigInt since we always just do pointer math with these
    return BigInt(pwa_manifest.default_jmp_buf_storage_size);
}

const JMP_BUF_STATE_INITIALIZED = 0;
const JMP_BUF_STATE_CAPTURING   = 1;
const JMP_BUF_STATE_CAPTURED    = 2;
const JMP_BUF_STATE_RETURNING   = 3;
const JMP_BUF_STATE_PAUSING     = 4;

// @Volatile these offset have to match the definitions in *both* libc and JAI_WASM_EXPORTS
const JMP_BUF_OFFSET_CURRENT = 0;
const JMP_BUF_OFFSET_END     = 8;
const JMP_BUF_OFFSET_UNWOUND = 16;
const JMP_BUF_OFFSET_STORAGE = 24;
const JMP_BUF_OFFSET_STATE   = 32;
const JMP_BUF_OFFSET_VALUE   = 36;

const jmp_buf_log_header = (jmp_buf_pointer) => {
    // const jmp_buf = Number(_jmp_buf);
    const view = new DataView(jai_exports.memory.buffer);
    const jmp_buf = Number(jmp_buf_pointer);
    console.log(`jmp_buf: 0x${jmp_buf.toString(16)}
    current: 0x${view.getBigInt64(jmp_buf + JMP_BUF_OFFSET_CURRENT, true).toString(16)}
    end: 0x${view.getBigInt64(jmp_buf + JMP_BUF_OFFSET_END, true).toString(16)}
    unwound: 0x${view.getBigInt64(jmp_buf + JMP_BUF_OFFSET_UNWOUND, true).toString(16)}
    storage: 0x${view.getBigInt64(jmp_buf + JMP_BUF_OFFSET_STORAGE, true).toString(16)}
    state: ${view.getInt32(jmp_buf + JMP_BUF_OFFSET_STATE, true)}
    value: ${view.getInt32(jmp_buf + JMP_BUF_OFFSET_VALUE, true)}
    `);
};

// If you pass storage to this, it must be jai pointer (BigInt) to get_jmp_buf_storage_size() bytes of memory.
const jmp_buf_init = (jmp_buf, storage = undefined) => {
    // The order of the declarations below is important! If you make the view *before* calling malloc
    // that view *might* get invalidated and using it would throw an exception.
    const storage_size = get_jmp_buf_storage_size();
    storage ??= jai_exports.malloc(storage_size); // this is uses context.default_allocator
    
    const view = new DataView(jai_exports.memory.buffer);
    const buf  = Number(jmp_buf);
    view.setBigInt64 (buf+JMP_BUF_OFFSET_CURRENT , storage              , true);
    view.setBigInt64 (buf+JMP_BUF_OFFSET_END     , storage+storage_size , true);
    view.setBigInt64 (buf+JMP_BUF_OFFSET_UNWOUND , 0n                   , true);
    view.setBigInt64 (buf+JMP_BUF_OFFSET_STORAGE , storage              , true);
    view.setInt32    (buf+JMP_BUF_OFFSET_STATE   , 0                    , true);
    view.setInt32    (buf+JMP_BUF_OFFSET_VALUE   , 0                    , true);
};

const jmp_buf_reset = (jmp_buf) => {
    const view    = new DataView(jai_exports.memory.buffer);
    const buf     = Number(jmp_buf);
    const storage = view.getBigInt64(buf+JMP_BUF_OFFSET_STORAGE, true);
    
    view.setBigInt64(buf+JMP_BUF_OFFSET_CURRENT, storage , true);
    view.setBigInt64(buf+JMP_BUF_OFFSET_UNWOUND, 0n      , true);
};

// wasm_prepare_rewind returns true if active_jmp_buf was unwound with
// the intention of being rewound immediately (setjmp was called)
// and returns false if active_jmp_buf was unwound with the intention
// of being rewound at a later point (wasm_pause was called).
const wasm_prepare_for_rewind = () => {
    const view  = new DataView(jai_exports.memory.buffer);
    const buf   = Number(active_jmp_buf);
    const state = view.getInt32(buf + JMP_BUF_OFFSET_STATE, true);
    const value = view.getInt32(buf + JMP_BUF_OFFSET_VALUE, true);
    
    switch (state) {
    case JMP_BUF_STATE_PAUSING: {
        active_jmp_buf = 0n;
        return false;
    }
    case JMP_BUF_STATE_CAPTURING: {
        view.setBigInt64(
            buf + JMP_BUF_OFFSET_UNWOUND,
            view.getBigInt64(buf + JMP_BUF_OFFSET_CURRENT, true),
            true
        );
    } break;
    case JMP_BUF_STATE_CAPTURED:
    case JMP_BUF_STATE_RETURNING: {
        view.setBigInt64(
            buf + JMP_BUF_OFFSET_CURRENT,
            view.getBigInt64(buf + JMP_BUF_OFFSET_UNWOUND, true),
            true
        );
    } break;
    default: {
        jmp_buf_log_header(active_jmp_buf);
        throw Error(`unreachable active_jmp_buf state ${state}`);
    }
    }
    
    return true;
};


const wasm_pause = () => {
    const value = jai_imports.js_setjmp(jmp_buf_for_pausing);
    const view  = new DataView(jai_exports.memory.buffer);
    const buf   = Number(jmp_buf_for_pausing);
    const state = view.getInt32(buf + JMP_BUF_OFFSET_STATE, true);
    
    switch (state) {
    case JMP_BUF_STATE_CAPTURING : view.setInt32(buf + JMP_BUF_OFFSET_STATE, JMP_BUF_STATE_PAUSING,     true); break;
    case JMP_BUF_STATE_CAPTURED  : view.setInt32(buf + JMP_BUF_OFFSET_STATE, JMP_BUF_STATE_INITIALIZED, true); break;
    }
    return value;
};

const wasm_resume = (value) => {
    if (program_exited) return;
    jai_imports.js_longjmp(jmp_buf_for_pausing, value);
    active_jmp_buf = 0n;
    jai_exports.asyncify_start_rewind(jmp_buf_for_pausing);
    entry_point();
};

// We have to do this because you cannot call context.logger (or any wasm procedure)
// While in a suspended state. So use set_resume_error at the moment the error happens
// and log_resume_error when resuming execution, See File.js for examples
let resume_error_message = "";
const set_resume_error = (message) => { resume_error_message = message;      }
const log_resume_error = ()        => { jai_log_error(resume_error_message); }


// We put OPFS procedures here for now instead of a module like File, because the asset stuff we do now happens at startup
// and we do not want every single program importing File. This is subject to change.


const opfs_get_absolute_path = (path) => {
    if (path.startsWith("/"))
        return path;
    else 
        return opfs_current_working_directory.full_path + path;
};


const opfs_absolute_path_to_parent_and_name = async (absolute, create_parents) => {
    const root    = await navigator.storage.getDirectory();
    const folders = [];
    const parts   = absolute.split('/').filter(part => part);
    
    for (let it_index = 0; it_index <= parts.length-2; it_index++) {
        const it = parts[it_index];
        if (it === ".") {
            continue;
        } else if (it === "..") {
            folders.pop();
            continue;
        } else {
            const parent = folders[folders.length-1] ?? root;
            try {
                const next = await parent.getDirectoryHandle(it, { create: create_parents });
                folders.push(next);
            } catch (e) {
                if (e.name !== "NotFoundError") throw e; // uggg
                return {
                    ok: false,
                    parent: undefined,
                    file_name: undefined,
                };
            }
        }
    }

    return {
        ok: true,
        parent: folders.pop() ?? root,
        file_name: parts[parts.length-1],
    }
    
};

// takes a path to a directory and makes sure all of the folders exist to make it a path to a valid folder
const opfs_ensure_path_exists = async (path, is_directory) => {
    const absolute = opfs_get_absolute_path(path);
    const { ok, parent, file_name } = await opfs_absolute_path_to_parent_and_name(absolute, true);
    if (!ok) throw new Error("unreachable");
    
    let handle;
    if (is_directory) {
        handle = await parent.getDirectoryHandle(file_name, { create: true });
    } else {
        handle = await parent.getFileHandle(file_name, { create: true });
    }
    
    handle.full_path = absolute; // we stick in on here because it is usefulP
    
    return handle;
};

const opfs_find_file = async (path, create = false) => {
    try {
        const absolute = opfs_get_absolute_path(path);
        const { ok, parent, file_name } = await opfs_absolute_path_to_parent_and_name(absolute, false);
        if (!ok) return undefined;
        
        const handle = await parent.getFileHandle(file_name, { create: create });
        handle.full_path = absolute; // we stick in on here because it is useful
        
        return handle;
    } catch (e) {
        if (e.name !== "NotFoundError") throw e; // we still want to crash if we get some other error
        return undefined;
    }
};

const opfs_find_directory = async (path, create = false) => {
    try {
        const absolute = opfs_get_absolute_path(path);
        const { ok, parent, file_name } = await opfs_absolute_path_to_parent_and_name(absolute, false);
        if (!ok) return undefined;
        
        const handle = await parent.getDirectoryHandle(file_name, { create: create });
        handle.full_path = absolute; // we stick in on here because it is useful
        
        return handle;
    } catch (e) {
        if (e.name !== "NotFoundError") throw e; // we still want to crash if we get some other error
        return undefined;
    }
};


/*

Helper functions used by the runtime

*/

const find_mangled_jai_procedure = (name) => {
    const re = new RegExp('^'+name+'_[0-9a-z]+$');
    for (let full_name in jai_exports) if (re.test(full_name)) return jai_exports[full_name];
    throw `Could not find ${name} in the wasm module!`;
}
    
// TODO: expose a proper jai_log_* that uses get_caller_location() and jai_exports.jai_log()
const jai_log_error = (message) => {
    const encoder = text_encoder ?? new TextEncoder();
    const source  = encoder.encode(message);
    const count   = BigInt(source.length);
    const data    = jai_exports.temporary_alloc(jai_context, count);
    new Uint8Array(jai_exports.memory.buffer, Number(data), source.length).set(source);
    jai_exports.context_log(jai_context, data, count);
};

const get_caller_location = () => {
    const lines = new Error().stack.split("\n");
    const location     = lines[3].split("at ")[1];
    const start_column = location.lastIndexOf(":");
    const start_line   = location.lastIndexOf(":", start_column-1);
    return {
        file   : location.substring(0, start_line),
        line   : Number(location.substring(start_line+1, start_column)),
        column : Number(location.substring(start_column+1)),
    };
}


// Since passing strings to and from wasm land sucks big time and 
// a lot of time we are just passing constants, we are going to maintain
// a cache of constants that we copy over so that we do not copy every frame
const constant_string_table = new Map();

const text_decoder = new TextDecoder();
const copy_string_to_js = (count, data, is_constant) => {
    if (!is_constant) {
        const u8 = new Uint8Array(jai_exports.memory.buffer)
        const bytes = u8.subarray(Number(data), Number(data) + Number(count));
        const result = text_decoder.decode(bytes);
        // console.log(`normal decode "${result}"`);
        return result;
    }
    
    const key = (count << 64n) | data;
    const str = constant_string_table.get(key);
    if (str !== undefined) {
        // console.log(`cached decdode "${str}"!`);
        return str;
    }
    
    const u8 = new Uint8Array(jai_exports.memory.buffer)
    const bytes = u8.subarray(Number(data), Number(data) + Number(count));
    const result = text_decoder.decode(bytes);
    constant_string_table.set(key, result);
    // console.log(`caching decode "${result}"`);
    return result;
};

const text_encoder = new TextEncoder();
const copy_string_from_js = (jai_string_pointer, js_string) => {
    const source = text_encoder.encode(js_string);
    const count  = BigInt(source.length);
    const data   = jai_exports.context_alloc(jai_context, count); // should we expose this with other allocators or should the user just copy this if they need to?
    
    const view = new DataView(jai_exports.memory.buffer);
    const base = Number(jai_string_pointer);
    view.setBigInt64(base + 0, count, true);
    view.setBigInt64(base + 8, data, true);
    
    const destination = new Uint8Array(jai_exports.memory.buffer, Number(data), Number(count));
    destination.set(source);
}

// console.log and console.error always add newlines so we need to buffer the output from write_string
// to simulate a more basic I/O behavior. We’ll flush it after a certain time so that you still
// see the last line if you forget to terminate it with a newline for some reason.
let console_buffer = "";
let console_buffer_is_standard_error;
let console_timeout;
const FLUSH_CONSOLE_AFTER_MS = 3;
const flush_console_buffer = () => {
    if (!console_buffer) return;

    if (console_buffer_is_standard_error) {
        console.error(console_buffer);
    } else {
        console.log(console_buffer);
    }

    console_buffer = "";
};

const write_to_console_log = (str, to_standard_error) => {
    if (console_buffer && console_buffer_is_standard_error != to_standard_error) {
        flush_console_buffer();
    }

    console_buffer_is_standard_error = to_standard_error;
    const lines = str.split("\n");
    for (let i = 0; i < lines.length - 1; i++) {
        console_buffer += lines[i];
        flush_console_buffer();
    }

    console_buffer += lines[lines.length - 1];

    clearTimeout(console_timeout);
    if (console_buffer) {
        console_timeout = setTimeout(() => { flush_console_buffer(); }, FLUSH_CONSOLE_AFTER_MS);
    }
}    

    
/*
    Code added via collect_js_code() from C:/Users/Noah/source/repos/jai-wasm-toolchain/modules/File/wasm.jai:80,1
*/
    

jai_imports.js_file_open = (name_count, name_data, name_is_constant, for_writing, keep_existing_content, log_errors, out_file, out_success) => {
    switch (wasm_pause()) {
    case 0: (async () => {
        const view = new DataView(jai_exports.memory.buffer);
        const name = copy_string_to_js(name_count, name_data, name_is_constant);
        const create_file = for_writing !== 0 && keep_existing_content === 0;
        
        const file = await opfs_find_file(name, create_file);
        if (file === undefined) {
            set_resume_error(`Could not open file ${name}: File does not exist or is a directory`);
            view.setInt32(Number(out_success), 0, true);
            return -1;
        }
        
        file.seek_position = 0;
        const handle = reserve_object_handle(file);
        view.setInt32(Number(out_file), handle, true);
        view.setInt32(Number(out_success), 1, true);
        return +1;
    })().then(wasm_resume); break;
    case -1: log_resume_error();
    case +1: return;
    }
};

jai_imports.js_file_close = (file_handle_pointer) => {
    const view    = new DataView(jai_exports.memory.buffer);
    const pointer = Number(file_handle_pointer);
    const handle  = view.getInt32(pointer, true);
    release_object_handle(handle);
    view.setInt32(pointer, 0, true);
}

jai_imports.js_file_move = (old_name_count, old_name_data, old_name_is_constant, new_name_count, new_name_data, new_name_is_constant) => {
    switch (wasm_pause()) {
    case 0: (async () => {
        const old_name = copy_string_to_js(old_name_count, old_name_data, old_name_is_constant);
        const new_name = copy_string_to_js(new_name_count, new_name_data, new_name_is_constant);
        const old_fd = await opfs_find_file(old_name);
        if (old_fd === undefined) {
            set_resume_error(`Could not move "${old_name}" to "${new_name}" as "${old_name}" could not be found.`);
            return -1;
        }
        
        const slash_index = new_name.lastIndexOf("/");
        const parent_name = (slash_index === -1) ? "." : new_name.substring(0, slash_index+1);
        const new_parent  = await opfs_find_directory(parent_name);
        if (new_parent === undefined) {
            set_resume_error(`Could not move "${old_name}" to "${new_name}" as "${parent_name}" could not be found.`);
            return -1;
        }
        
        const file_name = (slash_index === -1) ? new_name : new_name.substring(slash_index+1, new_name.length);
        await old_fd.move(new_parent, file_name);
        return +1;
    })().then(wasm_resume); break;
    case +1: return true;
    case -1: {
        log_resume_error();
        return false;
    }
    }
};

jai_imports.js_file_delete = (filename_count, filename_data, filename_is_constant) => {
    switch (wasm_pause()) {
    case 0: (async () => {
        const name = copy_string_to_js(filename_count, filename_data, filename_is_constant);
        const { ok, parent, file_name } = await opfs_absolute_path_to_parent_and_name(opfs_get_absolute_path(name), false);
        if (!ok) {
            set_resume_error(`Could not delete "${name}": File not found.`);
            return -1;    
        }
        await parent.removeEntry(file_name);
        return +1;
    })().then(wasm_resume); break;
    case +1: return true;
    case -1: {
        log_resume_error();
        return false;
    }
    }
};


// You'd think we could just keep a WritableStream per handle we write to since it exposes the seek and write interfaces.
// Think again! These writablestreams only modify files on disk when they are closed making it basically useless womp womp
jai_imports.js_file_write = (file_handle_pointer, data, count) => {
    switch (wasm_pause()) {
    case 0: (async () => {
        try {
            const view   = new DataView(jai_exports.memory.buffer);
            const handle = view.getInt32(Number(file_handle_pointer), true);
            const file   = get_object_from_handle(handle);
            const buffer = new Uint8Array(jai_exports.memory.buffer, Number(data), Number(count));
            
            const writer = await file.createWritable({ keepExistingData: true });
            await writer.seek(file.seek_position);
            await writer.write(buffer);
            await writer.close();
            file.seek_position += buffer.byteLength;
            return +1;
        } catch (e) {
            set_resume_error(`Could not write to ${file.name} (${e.name}) ${e.message}`);
            return -1;
        }
    })().then(wasm_resume); return;
    case +1: return true;
    case -1: {
        log_resume_error();
        return false;
    }
    }
};

jai_imports.js_delete_directory = (path_count, path_data, path_is_constant) => {
    switch (wasm_pause()) {
    case 0: (async () => {
        const path = copy_string_to_js(path_count, path_data, path_is_constant);
        const { ok, parent, file_name } = await opfs_absolute_path_to_parent_and_name(opfs_get_absolute_path(path), false);
        if (!ok) {
            set_resume_error(`Could not delete "${path}": Directory not found or is a file.`);
            return -1;
        }
        try {
            await parent.removeEntry(file_name, { recursive: true });
        } catch (e) {
            if (e.name !== "NotFoundError") { // trying to delete a non-existent directory should not be an error
                set_resume_error(`Could not delete directory ${path}: (${e.name}) ${e.message}`);
                return -1;
            }
        }
        return +1;
    })().then(wasm_resume); break;
    case -1: log_resume_error(); return false;
    case +1: return true;
    }
}

jai_imports.js_os_make_directory_if_it_does_not_exist = (name_count, name_data, name_is_constant) => {
    const value = wasm_pause();
    if (value === 0) (async () => {
        const name  = copy_string_to_js(name_count, name_data, name_is_constant);
        const index = name.lastIndexOf("/");
        const parent = (index === -1)
                ? opfs_current_working_directory // relative to cwd path
                : await opfs_find_directory(name.substring(0, index+1)); // relative to name, which is relative to cwd
        
        if (parent === undefined) {
            set_resume_error(`Could not make directory ${name} because one or more parent directories were missing.`);
            return -1;
        }
        
        await parent.getDirectoryHandle(name, { create: true });
        
        return +1;
    })().then(wasm_resume); else if (value < 0) {
        log_resume_error();
        return false;
    } else {
        return true;
    }
};

jai_imports.js_file_read = (file_handle, data, bytes_to_read, total_read_pointer) => {
    switch (wasm_pause()) {
    case 0: (async () => {
        try {
            const handle  = get_object_from_handle(file_handle);
            const file    = await handle.getFile();
            const to_read = Number(bytes_to_read);
            const buffer  = await new Promise((resolve, reject) => {
                const slice    = file.slice(handle.seek_position, handle.seek_position+to_read+1);
                const reader   = new FileReader();
                reader.onload  = () => { resolve(reader.result); };
                reader.onerror = () => { reject(reader.error);   };
                reader.readAsArrayBuffer(slice);
            });
            handle.seek_position += to_read;
            new Uint8Array(jai_exports.memory.buffer, Number(data), to_read).set(new Uint8Array(buffer));
            new DataView(jai_exports.memory.buffer).setBigInt64(Number(total_read_pointer), bytes_to_read, true);
            return +1;
        } catch (e) {
            new DataView(jai_exports.memory.buffer).setBigInt64(Number(total_read_pointer), 0n, true);
            set_resume_error(`Could not read from ${handle.name} (${e.name}) ${e.message}`);
            return -1;
        } 
    })().then(wasm_resume); break;
    case -1: log_resume_error(); return false;
    case +1: return true;
    }
}

jai_imports.js_file_length = (file_handle, length_pointer) => {
    const value = wasm_pause();
    if (value === 0) (async () => {
        let handle;
        try {
            handle = get_object_from_handle(file_handle);
            const file = await handle.getFile();
            new DataView(jai_exports.memory.buffer).setBigInt64(Number(length_pointer), BigInt(file.size), true);
            wasm_resume(+1);
        } catch (e) {
            if (handle !== undefined) {
                set_resume_error(`Could not get size of ${handle.name}: (${e.name}) ${e.message}`);
            } else {
                set_resume_error(`Could not get size of file handle ${file_handle}: (${e.name}) ${e.message}`);
            }
            wasm_resume(-1);
        }
    })(); else if (value < 0) {
        log_resume_error();
        return false;
    } else {
        return true;
    }
};

jai_imports.js_file_set_position = (file_handle, position) => {
    try {
        const handle = get_object_from_handle(file_handle);
        handle.seek_position = Number(position);
        return true;
    } catch (e) {
        jai_log_error(`Could not write to file with invalid handle ${file_handle}`);
        return false;
    }
};

jai_imports.js_read_entire_file = (file_handle, zero_terminated, out_content, out_success) => {
    const value = wasm_pause();
    switch (value) {
    case 0: (async () => {
        let handle;
        try {
            handle = get_object_from_handle(file_handle);
            const file   = await handle.getFile();
            const buffer = new Uint8Array(await file.arrayBuffer());
            const buffer_handle = reserve_object_handle(buffer);
            return buffer_handle;
        } catch (e){
            const view = new DataView(jai_exports.memory.buffer);
            view.setInt32(Number(out_success), 0, true);
            if (handle !== undefined) {
                set_resume_error(`Could not get size of ${handle.name}: (${e.name}) ${e.message}`);
            } else {
                set_resume_error(`Could not get size of file handle ${handle}: (${e.name}) ${e.message}`);
            }
            return -1;
        }
    })().then(wasm_resume); return;
    case -1: log_resume_error(); return;
    default: {
        const source = get_object_from_handle(value);
        const memory = jai_exports.context_alloc(jai_context, BigInt(source.length + ((zero_terminated !== 0) ? 1 : 0)));
        const array  = new Uint8Array(jai_exports.memory.buffer, Number(memory), source.length)
        array.set(source);
        if (zero_terminated) array[array.byteLength-1] = 0;
        release_object_handle(value);
        
        const view = new DataView(jai_exports.memory.buffer);
        view.setBigInt64(Number(out_content) + 0, BigInt(source.length), true);
        view.setBigInt64(Number(out_content) + 8, memory, true);
        view.setInt32(Number(out_success), 1, true);
        return;
    }
    }
}

jai_imports.js_get_absolute_path = (path_count, path_data, path_is_constant, out_path) => {
    const relative = copy_string_to_js(path_count, path_data, path_is_constant);
    const absolute = opfs_get_absolute_path(relative);
    copy_string_from_js(out_path, absolute);
    return true;
}
    

    
/*
    Code added via collect_js_code() from C:/Users/Noah/source/repos/jai-wasm-toolchain/modules/Window_Creation/wasm.jai:33,1
*/
    
jai_imports.js_create_window = (width, height, name_count, name_data, name_is_constant, window_x, window_y, parent, bg_color_ptr, wanted_msaa) => {
    const name = copy_string_to_js(name_count, name_data, name_is_constant);
    const view = new DataView(jai_exports.memory.buffer);
    
    const offset  = Number(bg_color_ptr);
    const color_r = view.getFloat32(offset + 0, true);
    const color_g = view.getFloat32(offset + 4, true);
    const color_b = view.getFloat32(offset + 8, true);
    
    
    const canvas  = document.createElement("canvas");
    canvas.id     = name;
    canvas.width  = Math.floor(0.5 + Number(width));
    canvas.height = Math.floor(0.5 + Number(height));
    canvas.style.backgroundColor = `rgba(${color_r * 255}, ${color_g * 255}, ${color_b * 255}, 1)`;
    canvas.style.position = "absolute";
    canvas.style.margin   = "0";
    canvas.style.left     = `${(window_x === -1n) ? 0 : window_x}px`;
    canvas.style.top      = `${(window_y === -1n) ? 0 : window_y}px`;
    
    if (parent !== 0) throw new Error("TODO: What does that even mean in this context?");
    
    document.body.appendChild(canvas);
    const window_id = reserve_object_handle(canvas);
    
    // This might be too much voodoo, or maybe just a good idea:
    
    // A lot of the example programs hard code the resolution to be bigger than your typical browser window can display at once.
    // This should be allowed since it is the equivalent of creating a window that is larger than your screen resolution, which is 
    // a valid thing to do in every operating system (why someone would do this is another question entirely...).
    // At the same time, there is a convention in the Window_Creation API that -1 for window position means to place it wherever.
    
    // We will extend that concept to mean that if you do not specify an initial window position, the created canvas will be mapped
    // to the entire browser window and we will forward window resizes to the Input module.
    
    // This is the best compromise I could think of that makes most programs behave how you would expect, with the one caveat
    // that you MUST explicitly position every window if your application has multiple windows.
    
    // An alterantive solution would be to implement a proper window manager in HTML/CSS/JS so that the user can resize the canvas like
    // they can in other OSes, which would be pretty cool thing to try and implement
    
    // The one edge case I can think of here is a situation where you are using Simp but not Input, and in that case you can call
    // Simp.get_render_dimensions explicitly anyway
    
    // -nzizic, 2 May 2025
    
    if (window_x === -1n && window_y === -1n) {
        canvas.style.width  = "100%";
        canvas.style.height = "100%";
        if (fullscreen_canvas_resize_listener !== undefined) {
            const listen = fullscreen_canvas_resize_listener(window_id);
            addEventListener("resize", listen);
            listen();
        } else {
            const scale   = Math.ceil(devicePixelRatio);
            canvas.width  = innerWidth  * scale;
            canvas.height = innerHeight * scale;
            // canvas.style.width  = `${innerWidth}px`;
            // canvas.style.height = `${innerHeight}px`;
        }
    }
    
    return window_id;
};

jai_imports.js_get_mouse_pointer_position = (window_id, right_handed, out_x, out_y) => {
    let pos_x;
    let pos_y;
    if (matchMedia("(pointer: fine)").matches) {
        // This checks if we actually have a mouse plugged in
        pos_x = mouse_position_x;
        pos_y = mouse_position_y;
    } else if (jai_imports.js_device_supports_touch_input()) { // the jai code imports Input so we can use this with no issue
        // if you have no mouse we will treat the primary touch as the pointer if there is one
        if ((primary_touch_x == undefined) || (primary_touch_y == undefined)) {
            // TODO: this isn't really an error, there just isn't a pointer anywhere
            return false;
        }
        pos_x = primary_touch_x;
        pos_y = primary_touch_y;
    } else {
        // jai_log_error("Tried to get_mouse_pointer_position on a device that has no mouse and no touch input. What are you doing?");
        return false;
    }
    
    const canvas = get_object_from_handle(window_id);
    if (canvas === null) {
        jai_log_error("get_mouse_pointer_position got an INVALID_WINDOW.");
        return false;
    }
    if (!(canvas instanceof HTMLCanvasElement)) {
        jai_log_error(`get_mouse_pointer_position got handle ${window_id} which does not map to a canvas element.`);
        return false;
    }
    
    const rect = canvas.getBoundingClientRect();
    
    const scale = Math.ceil(devicePixelRatio);
    const x = BigInt(Math.floor(scale * (0.5 + pos_x - rect.left)));
    const y = (right_handed !== 0)
        ? BigInt(Math.floor(scale * (0.5 + rect.bottom - (innerHeight * (pos_y / innerHeight)))))
        : BigInt(Math.floor(scale * (0.5 + pos_y - rect.top)));
    
    const view  = new DataView(jai_exports.memory.buffer);
    view.setBigInt64(Number(out_x), x, true);
    view.setBigInt64(Number(out_y), y, true);
    
    return true;
};

jai_imports.js_get_window_dimensions = (window, right_handed, x_ptr, y_ptr, width_ptr, height_ptr) => {
    // if (right_handed !== 0) throw "TODO wasm_get_dimensions right_handed";
    const canvas = get_object_from_handle(window);
    if (canvas === null) {
        jai_log_error("get_window_dimensions got an INVALID_WINDOW.");
        return false;
    }
    if (!(canvas instanceof HTMLCanvasElement)) {
        jai_log_error(`get_window_dimensions got handle ${window} which does not map to a canvas element.`);
        return false;
    }
    
    // TODO: css absolute position stuff??
    const view = new DataView(jai_exports.memory.buffer);
    view.setInt32(Number(x_ptr), 0, true);
    view.setInt32(Number(y_ptr), 0, true);
    view.setInt32(Number(width_ptr),  canvas.width, true); // Write width
    view.setInt32(Number(height_ptr), canvas.height, true); // Write height
    return true;
};

// js_toggle_fullscreen :: (window: Window_Type, desire_fullscreen: bool, width: *s32, height: *s32) -> bool #foreign;
jai_imports.js_toggle_fullscreen = (window, desire_fullscreen, out_width, out_height) => {
    const canvas = get_object_from_handle(window);
    if (canvas === null) {
        jai_log_error("toggle_fullscreen got an INVALID_WINDOW.");
        return false;
    }
    if (!(canvas instanceof HTMLCanvasElement)) {
        jai_log_error(`toggle_fullscreen got handle ${window} which does not map to a canvas element.`);
        return false;
    }
    
    switch (wasm_pause()) {
    case 0: (async () => {
        try {
            if (desire_fullscreen) {
                await canvas.requestFullscreen();
            } else {
                await document.exitFullscreen();
            }
            const view = new DataView(jai_exports.memory.buffer);
            view.setInt32(Number(out_width), canvas.width, true);
            view.setInt32(Number(out_height), canvas.height, true);
            wasm_resume(+1);
        } catch (e) {
            set_resume_error(`Could not toggle fullscreen (${e.name}) ${e.message}`);
            wasm_resume(-1);
        }
    })(); return;
    case +1: return true;
    case -1: log_resume_error(); return false;
    }
};
    

    
/*
    Code added via collect_js_code() from C:/Users/Noah/source/repos/jai-wasm-toolchain/modules/Input/wasm.jai:196,1
*/
    
// One important thing to note about working with event listeners with this webassembly stuff:
// DO NOT CALL anything from jai_exports from eventListeners! If an even listener is firing that means
// that the wasm execution is suspended and calling procedures does NOTHING. I'm sure there is a way to
// have a runtime check for this with another proxy object and checking the state of the jmp_buf_for_pausing
// so that a nice error could be thrown, but I really do not want to do that so just be careful ok!
// -nzizic, 2 May 2025

// This is an array of arrays where each element consists of a wasm procedure followed by it's arguments.
// We call the procedures that populate the Input structures during update_window_events
const staged_events = [];

const js_mouse_event_to_jai_keycode = (e) => {
    switch (e.button) {
    case 0: return 168;
    case 1: return 169;
    case 2: return 170;
    default:
        console.warn("Missing mapping for mouse event : ", e);
        return 0;
    }
};

const js_key_event_to_jai_text_input = (e) => (e.key.length === 1) ? e.key.codePointAt(0) : 0;
const js_key_event_to_jai_keycode = (e) => {
    // @Speed: map?
    switch (e.code) {
    case "Backspace": return 8;
    case "Tab":       return 9;
    case "Enter":     return 13;
    case "Escape":    return 27;
    case "Space":     return 32;
    case "Delete":    return 127;

    case "ArrowUp":    return 128;
    case "ArrowDown":  return 129;
    case "ArrowLeft":  return 130;
    case "ArrowRight": return 131;

    case "PageUp":   return 132;
    case "PageDown": return 133;
    case "Home":     return 134;
    case "End":      return 135;
    case "Insert":   return 136;

    case "Pause":      return 137;
    case "ScrollLock": return 138;

    case "AltLeft":     case "AltRight":     return 139;
    case "ControlLeft": case "ControlRight": return 140;
    case "ShiftLeft":   case "ShiftRight":   return 141;
    case "MetaLeft":    case "MetaRight":    return 142;

    case "F1":  return 143;
    case "F2":  return 144;
    case "F3":  return 145;
    case "F4":  return 146;
    case "F5":  return 147;
    case "F6":  return 148;
    case "F7":  return 149;
    case "F8":  return 150;
    case "F9":  return 151;
    case "F10": return 152;
    case "F11": return 153;
    case "F12": return 154;

    default:
        const c = e.key;
        if (c.length === 1) return c.toUpperCase().charCodeAt(0); // A-Z, 0-9, symbols

        console.warn("No mapping for key event: ", e);
        return 0;
    }
};




document.addEventListener('dragover', (event) => {
    if (jai_exports === undefined) return;
    event.preventDefault();
});

document.addEventListener('drop', async (event) => {
    if (jai_exports === undefined) return;
    event.preventDefault();

    const files = event.dataTransfer.files;
    if (files.length > 0) {
        const base    = OPFS_COPIED_FILES_PATH + Date.now().toString() + "_";
        const to_send = [];
        
        for (let index = 0; index < files.length; index++) {
            const it     = files[index];
            const path   = base + it.name;
            const handle = await opfs_ensure_path_exists(path, false);
            const writer = await handle.createWritable();
            await writer.write(it);
            await writer.close();
            to_send.push(path);
        }
        staged_events.push([
            send_dropped_files_to_input_module,
            to_send,
        ]);
    }
});

const send_dropped_files_to_input_module = (jai_context, files) => {
    const current_file = jai_exports.temporary_alloc(jai_context, 16n); // allocating a string makes things a bit nicer here
    for (let it_index = 0; it_index < files.length; it_index++) {
        const it   = files[it_index];
        copy_string_from_js(current_file, it);
        jai_exports.add_dropped_file(jai_context, current_file);
    }
    jai_exports.send_dropped_files(jai_context);
}



// keyboard


document.addEventListener("keydown", (event) => {
    if (jai_exports === undefined) return;
    
    const is_dev_tools_key = 
        event.key === "F12" || 
        (event.ctrlKey && event.shiftKey && event.key === "I") || 
        (event.metaKey && event.altKey && event.key === "I");
    if (!is_dev_tools_key) event.preventDefault();
    
    const key  = js_key_event_to_jai_keycode(event);
    const text = js_key_event_to_jai_text_input(event);
    staged_events.push([
        jai_exports.add_key_event,
        key, text, true,
        event.repeat, event.altKey, event.shiftKey, event.ctrlKey, event.metaKey,
    ]);
});

document.addEventListener("keyup", (event) => {
    if (jai_exports === undefined) return;
    
    const is_dev_tools_key = 
        event.key === "F12" || 
        (event.ctrlKey && event.shiftKey && event.key === "I") || 
        (event.metaKey && event.altKey && event.key === "I");
    if (!is_dev_tools_key) event.preventDefault();
    
    const key  = js_key_event_to_jai_keycode(event);
    const text = js_key_event_to_jai_text_input(event);
    staged_events.push([
        jai_exports.add_key_event,
        key, text, false,
        event.repeat, event.altKey, event.shiftKey, event.ctrlKey, event.metaKey,
    ]);
});



// mouse

let mouse_position_x = 0;
let mouse_position_y = 0;
document.addEventListener("mousemove", (event) => {
    if (jai_exports === undefined) return;
    const scale = Math.ceil(devicePixelRatio);
    mouse_position_x = event.clientX;
    mouse_position_y = event.clientY;
});

document.addEventListener("wheel", (event) => {
    if (jai_exports === undefined) return;
    staged_events.push([
        jai_exports.add_wheel_event,
        -event.deltaY // we negate it to be consistent with other OSes
    ]);
});

document.addEventListener("pointerdown", (event) => {
    if (jai_exports === undefined) return;
    const code = js_mouse_event_to_jai_keycode(event);
    staged_events.push([
        jai_exports.add_key_event,
        code, 0, true,
        event.repeat, event.altKey, event.shiftKey, event.ctrlKey, event.metaKey,
    ]);
});

document.addEventListener("pointerup", (event) => {
    if (jai_exports === undefined) return;
    const code = js_mouse_event_to_jai_keycode(event);
    staged_events.push([
        jai_exports.add_key_event,
        code, 0, false,
        event.repeat, event.altKey, event.shiftKey, event.ctrlKey, event.metaKey,
    ]);
});

// window resize
const fullscreen_canvas_resize_listener = (window_id) => () => {
    const canvas  = get_object_from_handle(window_id);
    const scale   = Math.ceil(devicePixelRatio);
    canvas.width  = innerWidth  * scale;
    canvas.height = innerHeight * scale;
    canvas.style.width  = `${innerWidth}px`;
    canvas.style.height = `${innerHeight}px`;
    // canvas.getContext("2d").setTransform(scale, 0, 0, scale, 0, 0);
    // console.log("pixel ratio is ", scale);
    staged_events.push([
        jai_exports.add_window_resize,
        window_id,
        canvas.width,
        canvas.height,
    ])
};



// touch
const last_touches = [];
jai_imports.js_device_supports_touch_input = () => { return 'ontouchstart' in document.documentElement; };

// Used by Window_Creation.get_mouse_pointer_position when we emulate, I do not like this module crossing stuff, but it looks like that is something specific to the Input module...
let primary_touch_x = undefined;
let primary_touch_y = undefined;

document.addEventListener("touchstart", (event) => {
    if (jai_exports === undefined) return;
    event.preventDefault();
    
    last_touches.length = 0;
    last_touches.push(...event.targetTouches);
    const scale = Math.ceil(devicePixelRatio);
    for (let it_index = 0; it_index < event.targetTouches.length; it_index++) {
        const it = event.targetTouches[it_index];
        
        staged_events.push([
            jai_exports.add_touch,
            it.identifier,
            1,
            it.pageX * scale,
            it.pageY * scale,
        ]);
        
        // get_mouse_pointer_position does dpi scalling so pass the raw values here
        if (it_index === 0) {
            primary_touch_x = it.pageX;
            primary_touch_y = it.pageY;
        }
    }
}, { passive: false });

document.addEventListener("touchmove", (event) => {
    if (jai_exports === undefined) return;
    event.preventDefault();
    
    const scale = Math.ceil(devicePixelRatio);
    for (let it_index = 0; it_index < event.targetTouches.length; it_index++) {
        const it = event.targetTouches[it_index];
        
        staged_events.push([
            jai_exports.add_touch,
            it.identifier,
            0,
            it.pageX * scale,
            it.pageY * scale,
        ]);
        
        // get_mouse_pointer_position does dpi scalling so pass the raw values here
        if (it_index === 0) {
            primary_touch_x = it.pageX;
            primary_touch_y = it.pageY;
        }
    }
}, { passive: false });


const touch_end = (event) => {
    if (jai_exports === undefined) return;
    event.preventDefault();
    
    const scale = Math.ceil(devicePixelRatio);
    const held_touches = new Set(Array.from(event.targetTouches).map(x => x.identifier));
    
    for (let last_touch_index = last_touches.length - 1; last_touch_index >= 0; last_touch_index--) {
        const last_touch = last_touches[last_touch_index];
        if (!held_touches.has(last_touch.identifier)) {
            staged_events.push([
                jai_exports.add_touch,
                last_touch.identifier,
                2,
                last_touch.pageX * scale,
                last_touch.pageY * scale,
            ]);
            last_touches.splice(last_touch_index, 1);
        }
    }
    
    // Reset primary touch coordinates when all touches end
    if (event.targetTouches.length === 0) {
        primary_touch_x = undefined;
        primary_touch_y = undefined;
    }
};

document.addEventListener("touchend", touch_end, { passive: false });
document.addEventListener("touchcancel", touch_end, { passive: false });



// update 
let mouse_position_x_last_frame = 0;
let mouse_position_y_last_frame = 0;
jai_imports.js_update_window_events = () => {
    const mouse_delta_x = mouse_position_x - mouse_position_x_last_frame;
    const mouse_delta_y = mouse_position_y - mouse_position_y_last_frame;
    mouse_position_x_last_frame = mouse_position_x;
    mouse_position_y_last_frame = mouse_position_y;
    jai_exports.set_mouse_delta(mouse_delta_x, mouse_delta_y);
    
    // This is so silly, but the nicest way to factor things given the constraints...
    for (let it_index = 0; it_index < staged_events.length; it_index++) {
        const [proc, ...args] = staged_events[it_index];
        proc(jai_context, ...args);
    }
    staged_events.length = 0;
};
    

    
/*
    Code added via collect_js_code() from C:/Users/Noah/source/repos/jai-wasm-toolchain/modules/Basic/wasm.jai:9,1
*/
    
// We expose microseconds because performance API gives us non-whole milliseconds that are accurate up to 5 microseconds....
jai_imports.js_get_microseconds = () => {
    // We still round despite the comment above, because the number below might still not be whole and trying to BigInt
    // such a number will throw an exception....................
    return BigInt(Math.round(((performance.timeOrigin + performance.now()) * 1000)));
};

jai_imports.js_sleep_milliseconds = (ms) => {
    if (wasm_pause() === 0) setTimeout(() => { wasm_resume(1); }, ms);
};

jai_imports.js_set_working_directory = (path_count, path_data, path_is_constant) => {
    switch (wasm_pause()) {
    case 0: (async () => {
        const path   = copy_string_to_js(path_count, path_data, path_is_constant);
        const handle = await opfs_find_directory(path);
        if (handle === undefined) {
            set_resume_error(`Could not set working directory to "${path}": directory does not exist`);
            return -1;
        }
        opfs_current_working_directory = handle;
        return +1;
    })().then(wasm_resume); return;
    case -1: {
        log_resume_error();
        return false;
    }
    case +1: return true;
    }
};
    

    
/*
    Code added via collect_js_code() from C:/Users/Noah/source/repos/jai-wasm-toolchain/modules/Browser/WebGL.jai:2187,1
*/
    
// Ok so firefox is a piece of shit and takes 40ms to do a simple texture copy. This has been a known issue
// for 10 YEARS. And entire decade! Here look https://bugzilla.mozilla.org/show_bug.cgi?id=1163426 I am not crazy.
// I have tried many different things to work around this, but none of them helped. For now we are just going to alert the
// user about this bug and hope it gets fixed this century. The problem stems from the fact that we want to emulate multiple
// windows using multiple canvases, but WebGL (unlike the GL your OS uses) creates a seperate context for each canvas.
// This means that if you create a shader or a buffer with one context it would not be valid to use with another one. To
// get around this we have a single global GL context and each canvas only has a "2d" context that we blit to when we call
// swap_buffers. That blit happens instantly on most browser (as it should), but takes forever on firefox. The only way to
// fix this performance problem is to remove multiple window emulation, but I refuse to do that! Firefox should do better!
// -nzizic, 31 October 2025

if (navigator.userAgent.includes('Firefox')) alert(
"You are using the Firefox web browser. "+
"Performance is likely to be bad due to a decade old bug in WebGL on that browser. "+
"Switch to a Chrome based one for a much better experience!"
);

let front_canvas = undefined;
const back_canvas = new OffscreenCanvas(0, 0);
const gl = back_canvas.getContext("webgl2", {
    preserveDrawingBuffer: true,
    willReadFrequently: true
});
if (!gl || !gl.getExtension("EXT_texture_filter_anisotropic")) throw new Error("Browser does not support WebGL!");

jai_imports.js_gl_set_render_target = (window_id) => {
    front_canvas = get_object_from_handle(window_id);
    back_canvas.width  = front_canvas.width;
    back_canvas.height = front_canvas.height;
};

const webgl_swap_buffers = (window) => {
    jai_imports.js_gl_set_render_target(window);
    
    // we only use this for blitting, so disable blending options for better performance,
    // this is the part firefox chokes on!
    const ctx = front_canvas.getContext("2d");
    ctx.imageSmoothingEnabled    = false;
    ctx.globalCompositeOperation = "copy";
    ctx.drawImage(back_canvas, 0, 0, front_canvas.width, front_canvas.height);
};

jai_imports.js_webgl_swap_buffers = (window, vsync) => {
    if (wasm_pause() === 0) {
        if (vsync) {
            requestAnimationFrame(() => {
                webgl_swap_buffers(window);
                wasm_resume(1);
            });
        } else {
            webgl_swap_buffers(window);
            // we can't just call wasm_resume here, because the stack doesn't unwind until after js_webgl_swap_buffers returns for
            // the first time. We define a yield_resume_channel in Runtime_Support.js that can be used in situations like this.
            // This schedules the resume operation to happen as soon as possible. If we just called webgl_swap_buffers without
            // any async stuff the browser would hang and we would not be able to render anything.
            yield_resume_channel.port2.postMessage(1)
        }
    }
};

jai_imports.glReadBuffer = (src) => { gl.readBuffer(src); };
jai_imports.glViewport = (x, y, width, height) => { gl.viewport(x, y, width, height); };
jai_imports.glScissor = (x, y, width, height) => { gl.scissor(x, y, width, height); };
jai_imports.glCreateProgram = () => { return reserve_object_handle(gl.createProgram()); };
jai_imports.glCreateShader = (typ) => { return reserve_object_handle(gl.createShader(typ)); };
jai_imports.glAttachShader = (program, shader) => { gl.attachShader(get_object_from_handle(program), get_object_from_handle(shader)); };
jai_imports.glLinkProgram = (program) => { gl.linkProgram(get_object_from_handle(program)); };
jai_imports.glDeleteShader = (shader) => { gl.deleteShader(get_object_from_handle(shader)); };
jai_imports.glBindTexture = (target, texture) => { gl.bindTexture(target, get_object_from_handle(texture)); };
jai_imports.glClearColor = (r, g, b, a) => { gl.clearColor(r, g, b, a); };
jai_imports.glClear = (mask) => { gl.clear(mask); };
jai_imports.glDepthMask = (flag) => { gl.depthMask(flag); };
jai_imports.glEnable = (cap) => { gl.enable(cap); };
jai_imports.glDisable = (cap) => { gl.disable(cap); };
jai_imports.glUseProgram = (program) => { gl.useProgram(get_object_from_handle(program)); };
jai_imports.glUniformBlockBinding = (program, index, binding) => { gl.uniformBlockBinding(get_object_from_handle(program), index, binding); };
jai_imports.glUniform1i = (loc, v) => { gl.uniform1i(get_object_from_handle(loc), v); };
jai_imports.glEnableVertexAttribArray = (index) => { gl.enableVertexAttribArray(index); };
jai_imports.glVertexAttribPointer = (index, size, typ, norm, stride, p) => { gl.vertexAttribPointer(index, size, typ, norm, stride, Number(p)); };
jai_imports.glVertexAttribIPointer = (index, size, typ, stride, offset) => { gl.vertexAttribIPointer(index, size, typ, stride, Number(offset)); };
jai_imports.glDrawArrays = (mode, first, count) => { gl.drawArrays(mode, first, count); };
jai_imports.glDrawElements = (mode, count, typ, offset) => { gl.drawElementsInstanced(mode, count, typ, Number(offset), 1); };
jai_imports.glTexParameteri = (target, pname, param) => { gl.texParameteri(target, pname, param); };
jai_imports.glTexParameterf = (target, pname, param) => { gl.texParameterf(target, pname, param); };
jai_imports.glPixelStorei = (pname, param) => { gl.pixelStorei(pname, param); };
jai_imports.glActiveTexture = (texture) => { gl.activeTexture(texture); };
jai_imports.glBlendFunc = (s,d) => { gl.blendFunc(s, d); };
jai_imports.glFlush = () => { gl.flush(); };
jai_imports.glCompileShader = (shader) => { gl.compileShader(get_object_from_handle(shader)); };
jai_imports.glGetIntegerv   = (pname, data) => { new DataView(jai_exports.memory.buffer).setInt32(Number(data), gl.getParameter(pname), true); };
jai_imports.glGetShaderiv   = (shader, pname, out_param) => { new DataView(jai_exports.memory.buffer).setInt32(Number(out_param), gl.getShaderParameter(get_object_from_handle(shader), pname), true); };
jai_imports.glGetProgramiv  = (shader, pname, out_param) => { new DataView(jai_exports.memory.buffer).setInt32(Number(out_param), gl.getProgramParameter(get_object_from_handle(shader), pname), true); };
jai_imports.glFramebufferTexture2D = (target, attachment, textarget, handle, level) => { gl.framebufferTexture2D(target, attachment, textarget, get_object_from_handle(handle), level); };

jai_imports.glGetAttribLocation = (program, name_count, name_data, name_is_constant) => {
    const prog = get_object_from_handle(program);
    const name = copy_string_to_js(name_count, name_data, name_is_constant);
    const result = gl.getAttribLocation(prog, name);
    return result;
};

// Uniform locations are not handles in normal GL, but an actual index. WebGL is special in that it makes the location a proper object, so we have to do this sillyness
// in order to not leak handles. The worst part is that the vertex attributes above are just indices, meaning the uniforms could be the same if they wanted. Epic fail!
jai_imports.glGetUniformLocation = (program, name_count, name_data, name_is_constant) => {
    const prog = get_object_from_handle(program);
    const name = copy_string_to_js(name_count, name_data, name_is_constant);
    for (let i = 0; i < jai_handle_to_js_object.length; i++) {
        const obj = jai_handle_to_js_object[i];
        if (typeof(obj) === "object" && obj.webgl_uniform_prog === prog && obj.webgl_uniform_name === name) {
            return i+1;
        }
    }
    const loc = gl.getUniformLocation(prog, name);
    loc.webgl_uniform_name = name;
    loc.webgl_uniform_prog = prog;
    return reserve_object_handle(loc);
};

jai_imports.glBindFramebuffer = (target, buffer) => { gl.bindFramebuffer(target, get_object_from_handle(buffer)); };
jai_imports.glBindVertexArray = (array) => { gl.bindVertexArray(get_object_from_handle(array)); };
jai_imports.glBindBuffer = (target, buffer) => { gl.bindBuffer(target, get_object_from_handle(buffer)); };
jai_imports.glBindBufferBase = (target, index, buffer) => { gl.bindBufferBase(target, index, get_object_from_handle(buffer)); };
jai_imports.glBufferData = (target, size, data, usage) => { gl.bufferData(target, (data === 0n) ? Number(size) : new DataView(jai_exports.memory.buffer, Number(data), Number(size)), usage); };
jai_imports.glBufferSubData = (target, offset, size, _data) => { gl.bufferSubData(target, Number(offset), new DataView(jai_exports.memory.buffer, Number(_data), Number(size))); };
jai_imports.glGetBufferSubData = (target, offset, size, data) => {
    const memory = new Uint8Array(jai_exports.memory.buffer, Number(data), Number(size));
    gl.getBufferSubData(target, Number(offset), memory);
};

jai_imports.glGenVertexArrays = (n, arrays) => {
    const view = new DataView(jai_exports.memory.buffer);
    for (let i = 0; i < n; i++) {
        const handle = reserve_object_handle(gl.createVertexArray());
        view.setUint32(Number(arrays) + i * 4, handle, true);
    }
};

jai_imports.glGenFramebuffers = (n, buffers) => {
    const view = new DataView(jai_exports.memory.buffer);
    for (let i = 0; i < n; i++) {
        const handle = reserve_object_handle(gl.createFramebuffer());
        view.setUint32(Number(buffers) + i * 4, handle, true);
    }
};

jai_imports.glGenBuffers = (n, buffers) => {
    const view = new DataView(jai_exports.memory.buffer);
    for (let i = 0; i < n; i++) {
        const handle = reserve_object_handle(gl.createBuffer());
        view.setUint32(Number(buffers) + i * 4, handle, true);
    }
};

jai_imports.glDeleteBuffers = (n, buffers) => {
    const view = new DataView(jai_exports.memory.buffer); // TODO: all of these could just create a Uint32Array instead of doing this....
    for (let i = 0; i < n; i++) {
        const handle = view.getUint32(Number(buffers) + i * 4, true);
        const buffer = get_object_from_handle(handle);
        gl.deleteBuffer(buffer);
        release_object_handle(handle);
    }
};

jai_imports.glGenTextures = (n, buffers) => {
    const view = new DataView(jai_exports.memory.buffer);
    for (let i = 0; i < n; i++) {
        const handle = reserve_object_handle(gl.createTexture());
        view.setUint32(Number(buffers) + i * 4, handle, true);
    }
};

jai_imports.glShaderSource = (_shader, count, strings_data, lengths_data) => {
    const shader = get_object_from_handle(_shader);
    const view = new DataView(jai_exports.memory.buffer);
    
    let source = "";
    for (let i = 0; i < count; i++) {
        const count  = view.getInt32(Number(lengths_data) + i * 4, true);
        const data   = view.getBigInt64(Number(strings_data) + i * 8, true);
        
        // Technically it is very likely that this string is actually constant, but in order to 
        // know that for sure we would have to pass an array of is_constants (which we still could
        // at some point). We do not do this right now because we would only load constant shaders
        // once in a real program. Right?
        source += copy_string_to_js(count, data, false) + "\n";
    }
    gl.shaderSource(shader, source);
};


jai_imports.glGetShaderInfoLog = (_shader, length_ptr, data_ptr) => {
    const shader = get_object_from_handle(_shader);
    const info = gl.getShaderInfoLog(shader);
    throw `TODO: copy string and print \n\n${info}`;
};



jai_imports.glGetUniformBlockIndex = (program, name_count, name_data, name_is_constant) => {
    return gl.getUniformBlockIndex(get_object_from_handle(program), copy_string_to_js(name_count, name_data, name_is_constant));
};

jai_imports.glUniformMatrix4fv = (_location, count, transpose, value_ptr) => {
    if (count !== 1) throw "@Incomplete handle packed array of matrices";
    gl.uniformMatrix4fv(get_object_from_handle(_location), transpose, new Float32Array(jai_exports.memory.buffer, Number(value_ptr), 16));
};

jai_imports.glTexImage2D = (target, level, internal_format, width, height, border, format, typ, pixels) => {
    const components   = gl_get_components_from_format(internal_format);
    const element_size = gl_get_size_from_type(typ);
    const data = new Uint8Array(jai_exports.memory.buffer, Number(pixels), width*height*components*element_size);
    gl.texImage2D(target, level, internal_format, width, height, border, format, typ, data);
};

jai_imports.glReadPixels = (x, y, width, height, format, type, offset) => {
    if (offset !== 0n) throw "@Incomplete we can currently only read from the base of the pixel pack buffer sorry!";
    gl.readPixels(x, y, width, height, format, type, Number(offset));
}

// switch 
// case gl.ALPHA: throw "unhandled type ALPHA"
// case gl.RGB: throw "unhandled type RGB"
// case gl.RGBA: throw "unhandled type RGBA"
// case gl.RED: throw "unhandled type RED"
// case gl.RG: throw "unhandled type RG"
// case gl.RED_INTEGER: throw "unhandled type RED_INTEGER"
// case gl.RG_INTEGER: throw "unhandled type RG_INTEGER"
// case gl.RGB_INTEGER: throw "unhandled type RGB_INTEGER"
// case gl.RGBA_INTEGER: throw "unhandled type RGBA_INTEGER"

const gl_get_components_from_format = (format) => {
    switch (format) {
    case gl.RGB8:  return 3;
    case gl.RGBA8: return 4;
    default: throw `@Incomplete Unsupported texture glformat ${format}`
    }
};

const gl_get_size_from_type = (type) => {
    switch (type) {
    case gl.UNSIGNED_BYTE: return 1;
    default: throw `@Incomplete Unsupported gl element type ${type}`;
    }
};
    

    
/*
    Code added via collect_js_code() from C:/Users/Noah/source/repos/jai-wasm-toolchain/modules/System.jai:558,1
*/
    
jai_imports.js_get_path_of_running_executable = (out_pointer) => {
    // the wasm binary name is hard coded by the toolchain
    // since the "executable name" is set in manifest.json
    const path = document.location.pathname + "main.wasm";
    copy_string_from_js(out_pointer, path);
};

// Poor-man’s replacements for rdtsc.
jai_imports.js_read_cpu_counter = () => { return BigInt(Math.round(performance.now() * 1_000_000)); };
    

    
/*
    Code added via collect_js_code() from C:/Users/Noah/source/repos/jai-wasm-toolchain/modules/Browser/Asset_Download.jai:12,1
*/
    
/*

This is a very simple "asset cache" system that is used by web apps. The reason we need this asset system to begin with is that
our File module is backed by the browser's Origin Private File System (OPFS). This is a virtual filesystem that is tied to the origin
of the website the application is being served from. Since this filesystem exists entirely on the client we need some mechanism
to put files from the server into the OPFS.

The whole point of the Progressive_Web_App metaprogram plugin is to make "simple" programs work on the browser with no modifications
to the original code, so we try to make this "seamless" by default while still allowing the user to override these procedures or use
their own asset system that fetches files on demand for example. This implementation uses localStorage in a pretty stupid way
to store a list of locally stored assets along with the build time of the application.

*/

jai_imports.js_local_assets_are_outdated = () => {
    if (pwa_manifest.assets.length === 0) return false; // if we have no assets do not do anything
    
    switch (wasm_pause()) {
    case  0: pwa_assets_are_outdated().then((x) => wasm_resume(x ? +1 : -1))
    case +1: return true;
    case -1: return false;
    }
};

jai_imports.js_local_assets_download = () => { if (wasm_pause() === 0) pwa_assets_download().then(() => wasm_resume(1)); };

const pwa_assets_key_build_time  = `${document.location.pathname}build_time`;
const pwa_assets_key_asset_count = `${document.location.pathname}asset_count`;

const pwa_assets_are_outdated = async () => {
    const time = localStorage.getItem(pwa_assets_key_build_time);
    if (!time || time !== pwa_manifest.build_time) {
        console.log(`Did not find asset key "${pwa_assets_key_build_time}" with value "${pwa_manifest.build_time}" (it was "${time}"), need to download PWA assets.`);
        return true;
    }
    
    for (let it_index = 0; it_index < pwa_manifest.assets.length; it_index++) {
        const key  = `${document.location.pathname}asset${it_index}`;
        const path = localStorage.getItem(key);
        if (!path) {
            console.log(`Could not find asset key (${key}) in pwa asset cache, need to download PWA assets`);
            return true;
        }
        
        const file = await opfs_find_file(path, false); 
        if (!file) {
            console.log(`could not find asset "${path}" (key ${key}), need to download PWA assets`);
            return true;
        }
    }
    
    return false;
}

const pwa_assets_download = async () => {
    const store = localStorage;
    const assets_to_delete_count = Number(store.getItem(pwa_assets_key_asset_count)); // this will convert null to 0 which is ok here
    
    const keys = Array.from(
        {length: Math.max(assets_to_delete_count, pwa_manifest.assets.length)},
        (_, it_index) => `${document.location.pathname}asset${it_index}`
    );
    
    await Promise.all(Array.from({length: assets_to_delete_count}).map(async (_, it_index) => {
        const key = keys[it_index];
        const old = store.getItem(key);
        store.removeItem(key);
        if (old) {
            const { ok, parent, file_name } = await opfs_absolute_path_to_parent_and_name(opfs_get_absolute_path(old), false);
            if (!ok) return;
            await parent.removeEntry(file_name);
        }
    }));
    
    await Promise.all(pwa_manifest.assets.map(async (it, it_index) => {
        const key    = keys[it_index];
        const path   = document.location.pathname + it;
        const resp   = await fetch(path);
        const buffer = await resp.arrayBuffer();
        const handle = await opfs_ensure_path_exists(path, false);
        const writer = await handle.createWritable();
        await writer.write(buffer);
        await writer.close();
        store.setItem(key, path);
    }));
    
    store.setItem(pwa_assets_key_build_time, pwa_manifest.build_time);
    store.setItem(pwa_assets_key_asset_count, pwa_manifest.assets.length);
}
