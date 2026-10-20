-- FGX Debug Inspector Plugin for MAME
-- Dumps CPU registers, memory regions, and SHR screen analysis to JSON
--
-- Enable:  -plugin fgxdebug
-- Config:  reads /tmp/fgx_debug_config.json (optional)
-- Output:  writes /tmp/fgx_debug_output.json

local exports = {
    name = "fgxdebug",
    version = "0.2.0",
    description = "FGX Apple IIgs debug inspector",
    license = "BSD-3-Clause",
    author = { name = "FGX" }
}

local fgxdebug = exports

function fgxdebug.startplugin()
    -- MAME 0.254+ notifier subscriptions are RAII objects: if the return
    -- value of emu.add_machine_*_notifier is discarded, the Lua GC collects
    -- it and SILENTLY UNSUBSCRIBES the callback.  fgxdebug allocates enough
    -- during startplugin that a GC cycle runs before the initial machine
    -- reset, so a discarded reset subscription never fires (cpu/mem stay
    -- nil, no config load, no dumps, no auto-exit — and every harness test
    -- "passes" vacuously on exit-by-timeout).  Anchor them on the exports
    -- table (retained by MAME's plugin registry) — a bare local dies with
    -- startplugin's scope, which is the same bug one level up.
    exports._subscriptions = {}
    local subscriptions = exports._subscriptions
    local cpu = nil
    local mem = nil
    local frame_count = 0
    -- The autoboot paste's frame, echoed from the config.  EVERY frame this
    -- plugin reports -- capture_log, watch_log, sampled_at_frame, and the
    -- "frame" in the dump header -- is ABSOLUTE, counted from reset; a
    -- manifest's memory_region "frame" is relative to the paste.  Without this
    -- number in the dump the two read as one axis, which on a fresh boot is an
    -- error of 1500 frames (apple/fgx#183).  -1 = the config did not say.
    local paste_frame = -1
    -- fbench cycle markers (optional; capture emu.time() at two memory writes).
    local cyc_start_addr = nil
    local cyc_done_addr  = nil
    local cyc_out_path   = nil
    local cyc_start_t    = nil
    local cyc_done_t     = nil
    local cyc_armed      = false   -- only record writes AFTER the bench command is sent
    local cyc_written    = false
    local cyc_taps       = {}      -- keep tap objects alive
    local dump_frame = 600        -- dump after this many frames (~10s at 60fps)
    local dump_done = false
    local output_path = "/tmp/fgx_debug_output.json"
    -- Parallel harness runs: each run.py invocation points its MAME at a
    -- private config via FGX_DEBUG_CONFIG (per-test scratch dir); the /tmp
    -- path remains the fallback for external/manual invocations.
    local config_path = (os.getenv and os.getenv("FGX_DEBUG_CONFIG"))
                        or "/tmp/fgx_debug_config.json"

    -- PC-sampler (Phase-0 real-tool profiler).  Opt-in via the config key
    -- "pc_sample": {"out": "<path>"}.  When the key is absent everything below
    -- is inert (zero effect on golden/oracle/cycle_markers runs).  When set, the
    -- program counter is histogrammed once per frame while ARMED -- arming
    -- happens after all scripted input has fired, so boot/idle frames do not
    -- dilute the tool's profile.  CURPC/PC are the full 24-bit program address
    -- in this g65816 build (bank in the high byte), so no separate PB read is
    -- needed.  Output JSON matches tools/profile/profile_report.py's reader:
    --   {"samples": {"BB:OOOO": count, ...}, "total": N, "wall_s": <emu.time delta>}
    local pc_sample_out = nil
    local pc_hist = {}
    local pc_total = 0
    local pc_t0 = nil
    local pc_armed = false

    -- Memory regions to dump: {name, address, length}.
    --
    -- kbank = true marks a region that lives in the kernel code+data bank.
    -- That bank is $02 on the legacy build but a dynamic NewHandle bank
    -- (e.g. $20) under FGX_RELOC.  At dump time the bank byte of these
    -- regions is replaced with the live kernel bank read from the loader
    -- anchor ($00:032C, magic $00:032D = $4B) — so the same region resolves
    -- correctly under both builds.  Regions WITHOUT kbank are in fixed banks
    -- that do NOT relocate: bank 0 (DP/stacks/staging), bank 1 (SHR),
    -- bank 3 (console char/attr buffers), bank 4 (fonts).  Heap-resident
    -- structures use pointer-indirect (ptr) regions instead.
    local memory_regions = {
        { name = "direct_page",    addr = 0x000000, len = 256 },
        { name = "kernel_dp",      addr = 0x00BF00, len = 256 },
        { name = "stack_native",   addr = 0x000100, len = 256 },
        { name = "fs_filestate",   addr = 0x02D4EF, len = 64,  kbank = true },
        { name = "fs_curowner",    addr = 0x02D742, len = 3,   kbank = true },
        { name = "sys_dispatch",   addr = 0x025C0D, len = 128, kbank = true },  -- _Sys_SavedSig..CallerBank cluster
        { name = "user_stack",     addr = 0x003300, len = 256 },  -- bank-0 around cp's S=$33xx
        { name = "fcb_table",      addr = 0x02081D, len = 64,  kbank = true },   -- src/dst FCBs in the kernel bank
        { name = "kernel_entry",   addr = 0x022000, len = 64,  kbank = true },
        { name = "kernel_vars",    addr = 0x0222C5, len = 20,  kbank = true },
        { name = "shr_scb",       addr = 0x019D00, len = 200 },
        { name = "shr_palette",   addr = 0x019E00, len = 512 },
        { name = "stack_area",     addr = 0x00FF00, len = 256 },
        { name = "charbuf",        addr = 0x030000, len = 8000, conbank = true },
        { name = "attrbuf",        addr = 0x032000, len = 8000, conbank = true },
        { name = "preexp_var0",    addr = 0x040000, len = 32 },  -- space glyph, 8 scanlines
        { name = "preexp_var3",    addr = 0x0417A0, len = 32 },
        { name = "preexp_var4",    addr = 0x041F80, len = 32 },
        { name = "preexp_var12",   addr = 0x045E80, len = 32 },
        { name = "fs_dirbuf",      addr = 0x02B000, len = 512, kbank = true },
        { name = "fs_pathscratch", addr = 0x02B6E0, len = 64,  kbank = true },
        { name = "fs_statbuf",     addr = 0x02B680, len = 16,  kbank = true },
        { name = "blk_stage",      addr = 0x002000, len = 512 },  -- bank 0 staging
        -- The KERNEL-IMAGE SLOT stacks, FGX_STK_KTASKS: FGX_KSLOT_COUNT of
        -- FGX_KSLOT_STK bytes (6 x 1,216).  Dumped whole so the depth can be
        -- measured: main.s paints every slot with STK_PAINT ($A5A5) and seeds
        -- a $C5C5 canary at each bottom word before boot borrows the top one,
        -- so the lowest painted word is the high-water mark itself rather
        -- than a floor on it.  The fill used to be ZERO, which measured
        -- nothing: a legitimately pushed zero is indistinguishable from
        -- untouched fill.  kstkhwm_check.py reads the slot size from the
        -- config, so this length must cover the whole block.
        { name = "kern_stacks",    addr = 0x00E000, len = 7296 },
        -- The scheduler's own stack, FGX_STK_SWITCH: the top 512 bytes of the
        -- mapped $D000 bank, painted and canaried at boot like a slice.
        { name = "switch_stack",   addr = 0x00DE00, len = 512 },
        -- The region the stacks VACATED, to prove they really left.
        { name = "old_kstk",       addr = 0x000C00, len = 3072 },
        -- Shadow register $C035 (read/write, not a toggle softswitch, so
        -- reading it is side-effect free).  Bit 0 = 1 inhibits TEXT page
        -- shadowing, bit 1 = hi-res page 1, bit 2 = hi-res page 2.  A shadowed
        -- bank-0 write is mirrored to $E0 at 1 MHz, so this decides whether
        -- $0400-$0BFF is usable RAM and whether the part of the user-stack
        -- arena covering $2000-$5FFF is running slow.
        { name = "shadow_reg",     addr = 0x00C035, len = 1 },
        { name = "shell_line",     addr = 0x028400, len = 256, kbank = true },
        { name = "sh_builtin_tbl", addr = 0x02316C, len = 96,  kbank = true },
        { name = "vt_state",       addr = 0x028200, len = 64,  kbank = true },
        { name = "shr_full",       addr = 0x012000, len = 32000 },
        { name = "gfx_paltab",     addr = 0x01A000, len = 8192 },  -- 256 per-line palettes x 32 B (3200)
        { name = "gfx_scancount",  addr = 0x02F759, len = 4, kbank = true },  -- DIAG scanline-IRQ entries
    }

    -- Checkpoints: memory addresses where we expect specific values.
    -- kbank = true: bank byte replaced with the live kernel bank (see above).
    local checkpoints = {
        { name = "kernel_signature", addr = 0x022000, expect = 0xE2, desc = "SEP #$20 at entry", kbank = true },
    }

    -- SHR screen analysis config
    -- 640x200 mode: 160 bytes/line, text grid is 106x25 (6x8 chars)
    local SHR_BASE = 0x012000
    local BYTES_PER_LINE = 160
    local TEXT_ROWS = 25
    local FONT_HEIGHT = 8
    local TEXT_COLS = 106
    local FONT_WIDTH = 6

    -- Kernel data addresses (must match main.s ORG $028000 layout)
    local CURSOR_X_ADDR = 0x028000 + 14   -- After 7 DS 2 vars
    local CURSOR_Y_ADDR = 0x028000 + 16

    -- Try to load config from file
    -- WARM RESET (apple/fgx#120).  Every test in this suite has always cold
    -- booted, so "boots from power-on" and "boots" were the same claim -- and
    -- they are not: a warm boot re-enters the kernel with bank 0, the language
    -- card, the ramdisk banks and every card's registers still holding the last
    -- run's values.  With "warm_reset_frame": N the plugin soft-resets the
    -- machine once at frame N, which leaves RAM alone exactly as the reset line
    -- does on the real machine, and the run's dump then describes the SECOND
    -- boot.  Latched, and deliberately NOT cleared by the reset notifier below:
    -- clearing it there would reset forever.
    -- POISON (apple/fgx#120).  Fill a bank-0 region with a byte at a chosen
    -- frame.  A warm boot differs from a cold one in exactly one way that FGX
    -- can see -- RAM holds the last run's values instead of power-on values --
    -- so any cell the kernel READS BEFORE IT WRITES behaves differently.  This
    -- reproduces that condition without needing a working warm reset, which
    -- MAME's reset line does not give us.  Config: "poison": [{addr, len,
    -- byte, frame}, ...].
    local poison = {}
    -- RAM_POISON (apple/fgx: hardware-only boot failures).  MAME zero-fills RAM
    -- at power-on; a real IIgs does not.  Every cell the kernel READS BEFORE IT
    -- WRITES therefore reads 0 here and garbage there, which is why apple/fgx#225
    -- (_fcc_stkfloor) and _KZeroRegion's dead-bank MVN both booted green in the
    -- harness and died on real hardware.  "ram_poison_seed": N fills physical
    -- DRAM with a deterministic PRNG before the first instruction, so the harness
    -- models a COLD boot instead of a zeroed one.  Seeded, so a failure repeats
    -- and can be bisected; a single-byte fill would not model a stale value that
    -- still looks VALID, which is the other half of this class.
    local ram_poison_seed = nil
    local ram_poison_top_bank = 0x7F      -- 8M = banks $00..$7F
    -- Window WITHIN the top bank; default covers it all, so an unset window
    -- behaves exactly as before.
    local ram_poison_win_lo  = 0x0000
    local ram_poison_win_hi  = 0xFFFF
    local warm_reset_frame = nil
    local warm_reset_done  = false
    local warm_settle_frames = 600
    local script_offset = 0

    local function load_config()
        local f = io.open(config_path, "r")
        if not f then return end
        local content = f:read("*a")
        f:close()

        local df = content:match('"dump_frame"%s*:%s*(%d+)')
        if df then dump_frame = tonumber(df) end

        local op = content:match('"output_path"%s*:%s*"([^"]+)"')
        if op then output_path = op end

        local rps = content:match('"ram_poison_seed"%s*:%s*(%d+)')
        if rps then ram_poison_seed = tonumber(rps) end

        local rpt = content:match('"ram_poison_top_bank"%s*:%s*(%d+)')
        if rpt then ram_poison_top_bank = tonumber(rpt) end

        local rwl = content:match('"ram_poison_win_lo"%s*:%s*(%d+)')
        if rwl then ram_poison_win_lo = tonumber(rwl) end
        local rwh = content:match('"ram_poison_win_hi"%s*:%s*(%d+)')
        if rwh then ram_poison_win_hi = tonumber(rwh) end

        local wr = content:match('"warm_reset_frame"%s*:%s*(%d+)')
        if wr then warm_reset_frame = tonumber(wr) end

        local ws = content:match('"warm_settle_frames"%s*:%s*(%d+)')
        if ws then warm_settle_frames = tonumber(ws) end

        -- BLOB form: {"addr":N, "hex":"....", "frame":N}.  Replays a previous
        -- run's memory into a fresh machine, which is what a warm boot IS --
        -- Measured on hardware: the failure survives a power
        -- cut shorter than ~10s and dies with a longer one, i.e. it tracks DRAM
        -- decay and nothing else.  A single-byte fill tests whether the kernel
        -- tolerates GARBAGE; only the real bytes test whether it is fooled by a
        -- stale value that still looks VALID, which is the actual failure mode.
        for addr, hex, fr in content:gmatch(
                '"addr"%s*:%s*(%d+)%s*,%s*"hex"%s*:%s*"(%x*)"%s*,%s*"frame"%s*:%s*(%d+)') do
            table.insert(poison, {addr = tonumber(addr), hex = hex,
                                  frame = tonumber(fr), done = false})
        end

        for addr, len, byte, fr in content:gmatch(
                '"addr"%s*:%s*(%d+)%s*,%s*"len"%s*:%s*(%d+)%s*,%s*"byte"%s*:%s*(%d+)%s*,%s*"frame"%s*:%s*(%d+)') do
            table.insert(poison, {addr = tonumber(addr), len = tonumber(len),
                                  byte = tonumber(byte), frame = tonumber(fr),
                                  done = false})
        end

        -- PC-sampler opt-in (gated solely by key presence; not test_mode).
        local ps = content:match('"pc_sample"%s*:%s*%b{}')
        if ps then
            local pso = ps:match('"out"%s*:%s*"([^"]+)"')
            if pso then
                pc_sample_out = pso
                emu.print_info("fgxdebug: pc-sampler enabled -> " .. pc_sample_out)
            end
        end

        for name, addr, len in content:gmatch('"name"%s*:%s*"([^"]+)"%s*,%s*"addr"%s*:%s*(%d+)%s*,%s*"len"%s*:%s*(%d+)') do
            table.insert(memory_regions, {
                name = name,
                addr = tonumber(addr),
                len = tonumber(len)
            })
        end

        -- Pointer-indirect regions: {name, ptr, len}.  At dump time, read a
        -- 3-byte little-endian 24-bit pointer at `ptr` (bank 0), then dump
        -- `len` bytes from that address.  Used for heap-resident structures
        -- whose static address moved (e.g. the kernel-log ring after it was
        -- migrated to the heap — deref _kLogBufPtr @ $00BFB0).
        for name, ptr, len in content:gmatch('"name"%s*:%s*"([^"]+)"%s*,%s*"ptr"%s*:%s*(%d+)%s*,%s*"len"%s*:%s*(%d+)') do
            table.insert(memory_regions, {
                name = name,
                ptr = tonumber(ptr),
                len = tonumber(len)
            })
        end

        -- Optional per-region SAMPLE FRAME: {"name":..., "frame":N}.  Without
        -- one a region is read when the dump is written, i.e. at the very end
        -- of the run -- useless for anything transient (a signal-request cell
        -- that is posted and then drained reads 0 either way, so "never set"
        -- and "set and consumed" are indistinguishable).  With one, the region
        -- is captured the first frame at or after N and that snapshot is what
        -- the dump reports.
        local frame_by_name = {}
        for nm, fr in content:gmatch('"name"%s*:%s*"([^"]+)"[^}]-"frame"%s*:%s*(%d+)') do
            frame_by_name[nm] = tonumber(fr)
        end

        -- Kernel-bank-relative regions: {name, kbank_off, len}.  kbank_off is
        -- the 16-bit offset within the kernel code+data bank; at dump time it
        -- is combined with the live kernel bank from the anchor, so the region
        -- resolves correctly under both the relocating ($20) and legacy ($02)
        -- builds.  run.py emits these for test regions tagged "kbank": true.
        for name, off, len in content:gmatch('"name"%s*:%s*"([^"]+)"%s*,%s*"kbank_off"%s*:%s*(%d+)%s*,%s*"len"%s*:%s*(%d+)') do
            table.insert(memory_regions, {
                name = name,
                addr = tonumber(off),
                len = tonumber(len),
                kbank = true
            })
        end

        -- Far-bank-relative regions: {name, farbank_off, len}.  Same shape as
        -- kbank_off above, resolved against the live kernel bank + 1.
        for name, off, len in content:gmatch('"name"%s*:%s*"([^"]+)"%s*,%s*"farbank_off"%s*:%s*(%d+)%s*,%s*"len"%s*:%s*(%d+)') do
            table.insert(memory_regions, {
                name = name,
                addr = tonumber(off),
                len = tonumber(len),
                farbank = true
            })
        end

        -- Tty-bank-relative regions: {name, ttybank_off, len}.  Same shape as
        -- farbank_off above, resolved against the live kernel bank + 2.  A
        -- check that wants ttys[].t_pgrp needs this: the field moved out of the
        -- core kernel at apple/fgx#108 T3 stage 1c.
        for name, off, len in content:gmatch('"name"%s*:%s*"([^"]+)"%s*,%s*"ttybank_off"%s*:%s*(%d+)%s*,%s*"len"%s*:%s*(%d+)') do
            table.insert(memory_regions, {
                name = name,
                addr = tonumber(off),
                len = tonumber(len),
                ttybank = true
            })
        end

        -- Console-bank-relative regions: {name, addr, len, conbank:true}.  The
        -- plain-addr parser above already inserted them; all that is left is to
        -- set the flag read_region_for() checks, so the bank byte is swapped for
        -- the live console bank (CON_CHARBUF and friends move off $03 under
        -- relocation).  run.py emits these for regions tagged "conbank": true.
        local conbank_by_name = {}
        for nm in content:gmatch('"name"%s*:%s*"([^"]+)"[^}]-"conbank"%s*:%s*true') do
            conbank_by_name[nm] = true
        end
        local vcbank_by_name = {}
        for nm, n in content:gmatch('"name"%s*:%s*"([^"]+)"[^}]-"vcbank"%s*:%s*(%d+)') do
            vcbank_by_name[nm] = tonumber(n)
        end

        -- modbank = N: the module ORDINAL, indexing _modBankTab.
        local modbank_by_name = {}
        for nm, n in content:gmatch('"name"%s*:%s*"([^"]+)"[^}]-"modbank"%s*:%s*(%d+)') do
            modbank_by_name[nm] = tonumber(n)
        end

        -- Attach sample frames now that every region parser has run.
        for _, r in ipairs(memory_regions) do
            if frame_by_name[r.name] then r.sample_frame = frame_by_name[r.name] end
            if conbank_by_name[r.name] then r.conbank = true end
            if vcbank_by_name[r.name] then r.vcbank = vcbank_by_name[r.name] end
            if modbank_by_name[r.name] then r.modbank = modbank_by_name[r.name] end
        end

        emu.print_info("fgxdebug: loaded config, dump at frame " .. dump_frame)
    end

    -- Convert bytes to hex string
    local function bytes_to_hex(bytes)
        local hex = {}
        for i = 1, #bytes do
            hex[i] = string.format("%02x", bytes[i])
        end
        return table.concat(hex)
    end

    -- Read a memory region and return as table of byte values
    local function read_bytes(addr, len)
        if not mem then return {} end
        local bytes = {}
        for i = 0, len - 1 do
            local ok, val = pcall(function() return mem:read_u8(addr + i) end)
            bytes[#bytes + 1] = ok and val or 0
        end
        return bytes
    end

    -- Read a memory region and return as hex string
    local function read_region(addr, len)
        return bytes_to_hex(read_bytes(addr, len))
    end

    -- Console framebuffer base.  CharBuf/AttrBuf relocate off fixed bank $03 into
    -- the MM-assigned rest-of-OS console bank under reloc (REST_CONSOLE_BANK_OFF==0,
    -- so console bank == rest base).  Resolve it from the rest anchor ($00:03CC,
    -- magic $00:03CD == $4B); default $030000 (static build / before the loader
    -- has written the anchor).  Used for the charbuf/attrbuf dumps (conbank=true)
    -- and the prompt-exit charbuf poll.
    -- DECLARED HERE, ABOVE THEIR FIRST USE, AND THAT MATTERS.  Lua closures
    -- capture upvalues by lexical position: a `local` written further down the
    -- file is a DIFFERENT variable from the global name the functions above it
    -- resolve.  Both of these were first declared next to the keyboard-cell
    -- constants ~450 lines below con_base(), so con_base() read a nil global
    -- and silently fell back to the boot anchor -- which returns the same bank
    -- until something switches, so it looked like it worked.
    local KCONSOLE_BANK    = nil           -- _kConsoleBank; nil = fall back to
                                           --   the boot rest anchor
    local MOD_BANK_TAB     = nil           -- _modBankTab[]; ordinal -> real bank
    local KVC_BANK         = nil           -- _kVcBank[]; per-VC framebuffer
                                           --   registry, 2 bytes per VC

    -- Live kernel bank, from the relocation anchor at $00:032C (magic $032D).
    -- Factored out of the raw-inject drainer, which computed it inline.
    local function kern_base()
        local kb = 0x02
        if mem then
            local okm, magic = pcall(function() return mem:read_u8(0x00032D) end)
            if okm and magic == 0x4B then
                local okb, b = pcall(function() return mem:read_u8(0x00032C) end)
                if okb and type(b) == "number" and b > 0 then kb = b end
            end
        end
        return kb * 65536
    end

    -- Did the anchor answer, or is kern_base() returning its fallback?  Same
    -- read, reported rather than folded into an address (see kernel_bank_anchor
    -- in the dump).
    local function anchor_ok()
        if not mem then return false end
        local okm, magic = pcall(function() return mem:read_u8(0x00032D) end)
        if not (okm and magic == 0x4B) then return false end
        local okb, b = pcall(function() return mem:read_u8(0x00032C) end)
        return okb and type(b) == "number" and b > 0
    end

    -- Prefer _kConsoleBank, the LIVE framebuffer bank, over the rest anchor.
    --
    -- The anchor is the rest-of-OS base, which equals the console bank AT BOOT
    -- and never moves again.  A virtual console gets its own runtime-allocated
    -- bank and Con_SwitchVC repoints _kConsoleBank at it, so reading the anchor
    -- meant every dump showed the BOOT console no matter which one was on
    -- screen -- screen_contains could not observe a VC switch at all, and a
    -- test written that way failed for reasons unrelated to the code
    -- (apple/fgx#40).  Falls back to the anchor, then to $030000, so a kernel
    -- without the symbol (or a fresh clone with no listing) behaves as before.
    local function con_base()
        if not mem then return 0x030000 end
        if KCONSOLE_BANK then
            local ok_c, b = pcall(function()
                return mem:read_u8(kern_base() + KCONSOLE_BANK) end)
            if ok_c and type(b) == "number" and b > 0 then return b * 65536 end
        end
        local ok_m, magic = pcall(function() return mem:read_u8(0x0003CD) end)
        if ok_m and magic == 0x4B then
            local ok_b, b = pcall(function() return mem:read_u8(0x0003CC) end)
            if ok_b and type(b) == "number" and b > 0 then return b * 65536 end
        end
        return 0x030000
    end

    -- ONE RESOLVER FOR A REGION'S BANK, AND BOTH READERS USE IT (apple/fgx#236).
    --
    -- A region names its bank with a FLAG, and the bank is only knowable at
    -- runtime: the kernel bank comes off the $00:032C anchor, the far bank is
    -- that plus one, the tty bank plus two, the console bank moves with a VC
    -- switch, and vcbank/modbank are table lookups.  There are two places that
    -- have to do this -- the dump at the end of a run, and the frame-scheduled
    -- sampler -- and until #236 they were two copies, of which the sampler's
    -- handled `ptr' and `kbank' and NOTHING ELSE.  A ttybank region with a
    -- "frame" therefore resolved to a bare 16-bit offset, which is bank 0, and
    -- reported a plausible body from the user-stack arena with no hint that it
    -- had done so.  That is apple/fgx#74's failure on the frame axis, and it is
    -- the same wrong-bank read #234 spent a session chasing.
    --
    -- Returns the absolute address, or 0 for a vcbank/modbank ordinal that has
    -- no bank yet -- the callers turn that into an EMPTY body rather than a
    -- dump of bank 0, so "not allocated" stays distinguishable from "empty".
    local function region_addr(r)
        local raddr = r.addr
        if r.ptr then
            local p = read_bytes(r.ptr, 3)
            return p[1] + p[2] * 256 + p[3] * 65536
        end
        if r.kbank   then raddr = kern_base() + (raddr % 65536) end
        if r.farbank then raddr = kern_base() + 0x010000 + (raddr % 65536) end
        if r.ttybank then raddr = kern_base() + 0x020000 + (raddr % 65536) end
        if r.conbank then raddr = con_base() + (raddr % 65536) end
        if r.vcbank and KVC_BANK and mem then
            local vb = 0
            local okv, v = pcall(function()
                return mem:read_u8(kern_base() + KVC_BANK + r.vcbank * 2) end)
            if okv and type(v) == "number" then vb = v end
            raddr = (vb > 0) and (vb * 65536 + (raddr % 65536)) or 0
        end
        if r.modbank and MOD_BANK_TAB and mem then
            local mb = 0
            local okm, m = pcall(function()
                return mem:read_u8(kern_base() + MOD_BANK_TAB + r.modbank) end)
            if okm and type(m) == "number" then mb = m end
            raddr = (mb > 0) and (mb * 65536 + (raddr % 65536)) or 0
        end
        return raddr
    end

    -- Escape a string for JSON
    local function json_str(s)
        return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
    end

    -- Analyze one text row of the SHR screen
    -- Returns: whether any non-background pixels exist, and the hex of the row's scanlines
    local function analyze_text_row(row)
        local start_line = row * FONT_HEIGHT
        local has_content = false
        local scanlines = {}

        for line = 0, FONT_HEIGHT - 1 do
            local addr = SHR_BASE + (start_line + line) * BYTES_PER_LINE
            local bytes = read_bytes(addr, BYTES_PER_LINE)
            local line_hex = bytes_to_hex(bytes)
            scanlines[#scanlines + 1] = line_hex

            -- Check if any byte differs from $55 (background)
            if not has_content then
                for _, b in ipairs(bytes) do
                    if b ~= 0x55 then
                        has_content = true
                        break
                    end
                end
            end
        end

        return has_content, scanlines
    end

    -- Count non-background bytes in a screen region
    local function count_active_pixels(start_row, end_row)
        local count = 0
        for line = start_row * FONT_HEIGHT, (end_row + 1) * FONT_HEIGHT - 1 do
            if line >= 200 then break end
            local addr = SHR_BASE + line * BYTES_PER_LINE
            for i = 0, BYTES_PER_LINE - 1 do
                local ok, val = pcall(function() return mem:read_u8(addr + i) end)
                if ok and val ~= 0x55 then
                    count = count + 1
                end
            end
        end
        return count
    end

    -- Watch-addrs state (declared BEFORE do_dump so do_dump can close
    -- over them as upvalues — Lua resolves upvalues at function-def time).
    local watch_addrs = {}   -- list of { addr=..., name=..., last=... }
    local watch_log   = {}   -- list of change records, capped at watch_log_max
    local watch_log_max = 256

    -- capture_writes: instruction-precise write-taps.  On each write into a
    -- target range, snapshot the writer's PB:PC + registers + HW-stack return
    -- chain + a direct-page window.  For finding WHO writes a given address
    -- (e.g. the elvis kbuf code-as-data garbage).  Gated on a config key ->
    -- inert (no taps) for golden/oracle/cycle_markers runs.
    local capture_writes = {}   -- list of { name, addr, len, max_hits, hits }
    local watch_min      = {}   -- list of { name, addr, min, max, hits, hits8 }
                                -- 16-bit write-value aggregator (P3-1 _fcc_ssp
                                -- high-water): no per-hit log, just min/max.
    local stack_exc      = nil  -- P3-3 #42 pad calibration: per-instant HW-stack
                                -- excursion aggregator e = _fcc_fb-1-S over the
                                -- user-stack arena, keyed per task DP page.
                                -- { lo, hi, tasks = {[dp] = {max_e, min_s, ..}} }
    local capture_log    = {}   -- captured snapshots
    -- Monotonic across ALL capture taps.  keep="last" gives each tap its own
    -- ring, drained tap-by-tap, so cross-tap ORDER is otherwise lost -- and the
    -- whole point of two taps is often to correlate them ("which fd produced
    -- which descriptor?").  frame alone is too coarse: a select scan touches
    -- every fd within one frame.
    local capture_seq    = 0
    local capture_taps   = {}   -- keep tap objects alive
    -- Kernel-context register snapshot (2026-07-17).  The raw CPU registers
    -- at dump time are a race: the dump fires off the sentinel/frame logic
    -- and can catch the CPU mid-firmware (PB=0, DB=0 — boot-duration
    -- sensitive: fresh-BRAM or bigger kernels boot slower and flipped the
    -- "reg DB = KERNEL" checks red while the OS was perfectly healthy).
    -- Instead, snapshot the registers each frame the CPU is executing IN
    -- THE KERNEL BANK; do_dump reports the latest such snapshot, i.e. the
    -- assertion's real invariant: "when in kernel code, DB == kernel bank".
    local kregs, kregs_frame = nil, nil

    -- Current program address for PC-sampling, as (bank, offset).  CURPC
    -- (GENPCBASE) is the start of the executing instruction; PC is the fallback.
    -- Both are full 24-bit ("%06X") in this g65816 core, so the bank is the high
    -- byte.  Uses arithmetic (not bitwise) for Lua-version portability.
    local function pc_sample_addr()
        local function rd(k)
            local e = cpu.state[k]
            if not e then return nil end
            local ok, v = pcall(function() return e.value end)
            if ok and type(v) == "number" then return v end
            return nil
        end
        local cur = rd("CURPC") or rd("PC")
        if cur and cur >= 0x10000 then
            return math.floor(cur / 65536) % 256, cur % 65536
        end
        -- 16-bit PC fallback: take the bank from PB.
        local bank = rd("PB") or 0
        return bank % 256, (cur or 0) % 65536
    end

    -- SAMPLING IS DECOUPLED FROM THE FRAME ON PURPOSE.  register_frame_done
    -- fires once per frame at vblank begin, a FIXED phase ~1.4 ms after the
    -- 60 Hz heartbeat IRQ (raised at scanline 208; vblank begins at 231).
    -- Anything the tick drives -- the ISR body, the post-WAI idle path, a
    -- VBL-synced repaint -- is then either always or never executing at the
    -- sample point, so it reads 0% or 100% and never its true share.  A
    -- coroutine waiting a PRIME microsecond period is incommensurate with the
    -- frame, so the sample point walks through it and tick-synchronous code is
    -- sampled fairly.  It also samples ~16x more often, which is what makes an
    -- A/B on anything but the top symbol statistically possible.
    local PC_SAMPLE_US   = 1009     -- prime
    local pc_task        = nil
    local pc_per_frame   = false    -- fallback when emu.wait is unavailable

    local function pc_take_sample()
        if not cpu then return end
        local b, off = pc_sample_addr()
        local key = string.format("%02X:%04X", b, off)
        pc_hist[key] = (pc_hist[key] or 0) + 1
        pc_total = pc_total + 1
    end

    local function pc_start_sampler()
        if pc_task or pc_per_frame then return end
        if not (emu.wait and coroutine and coroutine.create) then
            pc_per_frame = true
            emu.print_info("fgxdebug: pc-sampler FALLING BACK to per-frame "
                           .. "(emu.wait unavailable) -- tick-synchronous code "
                           .. "will read 0% or 100%")
            return
        end
        pc_task = coroutine.create(function()
            while true do
                emu.wait(PC_SAMPLE_US / 1000000.0)
                if pc_armed then pc_take_sample() end
            end
        end)
        local ok, err = coroutine.resume(pc_task)
        if not ok then
            pc_task = nil
            pc_per_frame = true
            emu.print_error("fgxdebug: pc-sampler coroutine failed ("
                            .. tostring(err) .. ") -- per-frame fallback")
        else
            emu.print_info(string.format(
                "fgxdebug: pc-sampler decoupled from the frame, %d us period",
                PC_SAMPLE_US))
        end
    end

    -- Dump everything to JSON
    local png_snapshot = nil   -- optional: write a PNG of the screen at dump
    local function do_dump()
        if not cpu then
            emu.print_error("fgxdebug: no CPU available")
            return
        end

        -- Optional PNG screenshot of the emulated screen (proof-grade
        -- evidence for interactive/visual behavior; 2026-07-27).
        if png_snapshot then
            for _, scr in pairs(manager.machine.screens) do
                local ok, err = pcall(function() scr:snapshot(png_snapshot) end)
                emu.print_info("fgxdebug: png snapshot -> " .. png_snapshot
                               .. (ok and "" or (" FAILED: " .. tostring(err))))
                break
            end
        end

        -- Live kernel bank from the loader-written anchor ($00:032C, with
        -- magic $00:032D = $4B).  Under FGX_RELOC the kernel code+data bank
        -- is a dynamic NewHandle bank (e.g. $20); the legacy build keeps $02.
        -- Used to relocate kbank regions/checkpoints and reported so the test
        -- runner can match `"DB_hex": "KERNEL"` against the running build.
        local kbank = 0x02
        do
            local ok_m, magic = pcall(function() return mem:read_u8(0x00032D) end)
            if ok_m and magic == 0x4B then
                local ok_b, b = pcall(function() return mem:read_u8(0x00032C) end)
                if ok_b and type(b) == "number" and b > 0 then kbank = b end
            end
        end
        local function kbank_resolve(a)
            return kbank * 65536 + (a % 65536)
        end

        -- THE FAR AND TTY RESOLVERS STOOD HERE and are `region_addr''s now
        -- (apple/fgx#236).  The far kernel bank is ALWAYS the live kernel bank
        -- + 1 and the tty bank + 2 -- stated in include/kernel.s:185 and
        -- docs/history/plans/tty-kernel-bank.md section 2, not inferred.  FGX_KFAR_BANK ($08)
        -- and FGX_KTTY_BANK ($09) are assembly-time ORG conventions only; every
        -- far entry does PHK, so the assembled bank never appears at runtime
        -- and must never resolve a dump address.

        local lines = {}
        lines[#lines + 1] = "{"

        -- Metadata
        lines[#lines + 1] = '  "plugin": "fgxdebug",'
        lines[#lines + 1] = '  "version": "0.2.0",'
        -- "frame" and "paste_frame" are the SAME axis: absolute, from reset.
        -- A manifest region frame is paste-relative, so paste_frame is what
        -- converts between them.
        lines[#lines + 1] = string.format('  "frame": %d,', frame_count)
        lines[#lines + 1] = string.format('  "paste_frame": %d,', paste_frame)
        lines[#lines + 1] = string.format('  "kernel_bank": %d,', kbank)
        -- WHETHER kernel_bank IS A READING OR A GUESS.
        --
        -- kern_base() falls back to $02 when the magic at $00:032D is not $4B,
        -- and that fallback is SILENT: every kbank/conbank region then resolves
        -- into bank $02, reads whatever is there, and the dump looks like a
        -- machine whose screen is blank and whose kernel has been zeroed.  A
        -- `screen_lacks' assertion cannot fail against bytes read from the
        -- wrong bank, so a crash arrives as a vacuous PASS on every lacks-check
        -- plus one misleading "screen missing <needle>".
        --
        -- The anchor lives in bank 0, so a wild jump that lands there takes it
        -- out: the COP/BRK loop that follows wraps the 16-bit stack through the
        -- whole bank and overwrites it with its own frames.  That is exactly
        -- when the dump matters most, and exactly when it was least readable.
        lines[#lines + 1] = string.format('  "kernel_bank_anchor": %s,',
                                         anchor_ok() and "true" or "false")


        -- CPU registers: prefer the latest IN-KERNEL snapshot (see kregs
        -- above); fall back to the live registers only if the CPU was never
        -- observed in the kernel (a genuine boot failure — and the
        -- registers_in_kernel flag tells the harness which case it is).
        lines[#lines + 1] = '  "registers": {'
        local reg_lines = {}
        if kregs then
            for name, val in pairs(kregs) do
                reg_lines[#reg_lines + 1] = string.format('    %s: %d', json_str(name), val)
            end
        else
            for name, entry in pairs(cpu.state) do
                local ok, val = pcall(function() return entry.value end)
                if ok and type(val) == "number" then
                    reg_lines[#reg_lines + 1] = string.format('    %s: %d', json_str(name), val)
                end
            end
        end
        lines[#lines + 1] = table.concat(reg_lines, ",\n")
        lines[#lines + 1] = '  },'
        lines[#lines + 1] = string.format('  "registers_in_kernel": %s,',
                                          kregs and "true" or "false")
        lines[#lines + 1] = string.format('  "registers_frame": %d,',
                                          kregs_frame or -1)
        -- THE LIVE REGISTERS TOO, whatever bank the CPU is in.  `registers'
        -- above is the last IN-KERNEL sample, which is the right default
        -- (apple/fgx#222) and is USELESS for a wedge outside the kernel bank --
        -- it reports, with no hint that it is doing so, where the core last was
        -- rather than where the machine is.  apple/fgx#225 hid behind that for
        -- a whole session: the stale sample said the core bank, the live one
        -- said $7D:1090, and $7D:1090 is `_fcc_stkoflow's spin.  One line of
        -- JSON turned an unattributable hang into a named routine.
        lines[#lines + 1] = '  "registers_live": {'
        local live_lines = {}
        for name, entry in pairs(cpu.state) do
            local ok, val = pcall(function() return entry.value end)
            if ok and type(val) == "number" then
                live_lines[#live_lines + 1] = string.format('    %s: %d', json_str(name), val)
            end
        end
        lines[#lines + 1] = table.concat(live_lines, ",\n")
        lines[#lines + 1] = '  },'
        -- Memory regions
        lines[#lines + 1] = '  "memory": {'
        local mem_lines = {}
        for _, region in ipairs(memory_regions) do
            -- ONE RESOLVER, SHARED WITH THE FRAME SAMPLER (apple/fgx#236).
            -- The chain that used to stand here was one of two copies, and the
            -- other one handled two flags of seven.
            local raddr = region_addr(region)
            local hex
            if region.ptr then
                -- A null result (heap buffer not yet allocated) dumps empty;
                -- only ptr regions get this guard -- a static region at addr 0
                -- (e.g. the direct page) is a valid dump target.
                hex = (raddr ~= 0) and read_region(raddr, region.len) or ""
            else
                -- The bank is resolved by region_addr above.  vcbank = N
                -- reads _kVcBank[N] so a test can read a console that is NOT on
                -- screen: con_base() only ever follows the ACTIVE one, which is
                -- useless for the assertion that matters most here -- "VC1
                -- received this while VC0 did not".  0 in the registry means the
                -- VC has no bank yet (lazy first-write allocation); the region
                -- is then emitted with addr 0 and an empty body rather than
                -- dumping bank 0, so "not allocated" stays distinguishable from
                -- "empty".
                -- modbank = N reads _modBankTab[N], whose entries are ONE
                -- byte each (DS MOD_BANK_MAX) unlike _kVcBank's words; both are
                -- region_addr's business now.
                if raddr == 0 and (region.vcbank or region.modbank) then
                    hex = ""                -- empty body, NOT a dump of bank 0
                else
                    hex = read_region(raddr, region.len)
                end
            end
            -- A frame-scheduled sample wins over the live read: the point of
            -- asking for frame N is that the value at dump time is not the
            -- value you wanted.
            local sampled_at = -1
            if region.sampled_hex then
                hex, raddr, sampled_at = region.sampled_hex, region.sampled_addr,
                                         region.sampled_at
            end
            mem_lines[#mem_lines + 1] = string.format(
                '    %s: {"addr": %d, "len": %d, "sampled_at_frame": %d, "hex": %s}',
                json_str(region.name), raddr, region.len, sampled_at, json_str(hex))
        end
        lines[#lines + 1] = table.concat(mem_lines, ",\n")
        lines[#lines + 1] = '  },'

        -- Cursor position (from kernel data)
        local cursor_x = 0
        local cursor_y = 0
        local ok_cx, cx = pcall(function() return mem:read_u16(CURSOR_X_ADDR) end)
        local ok_cy, cy = pcall(function() return mem:read_u16(CURSOR_Y_ADDR) end)
        if ok_cx then cursor_x = cx end
        if ok_cy then cursor_y = cy end
        lines[#lines + 1] = string.format('  "cursor": {"x": %d, "y": %d},', cursor_x, cursor_y)

        -- SHR screen analysis: which text rows have content?
        lines[#lines + 1] = '  "screen_analysis": {'
        local sa_lines = {}

        -- Summary: scan all 25 text rows, report which have non-background content
        local active_rows = {}
        for row = 0, TEXT_ROWS - 1 do
            local has_content, _ = analyze_text_row(row)
            if has_content then
                active_rows[#active_rows + 1] = row
            end
        end
        sa_lines[#sa_lines + 1] = string.format('    "active_text_rows": [%s]', table.concat(active_rows, ", "))
        sa_lines[#sa_lines + 1] = string.format('    "total_active_rows": %d', #active_rows)

        -- Dump the actual scanline data for active rows (first 8 rows max to keep output manageable)
        local dump_rows = {}
        local dump_count = 0
        for _, row in ipairs(active_rows) do
            if dump_count >= 8 then break end
            local _, scanlines = analyze_text_row(row)
            local sl_strs = {}
            for _, sl in ipairs(scanlines) do
                sl_strs[#sl_strs + 1] = json_str(sl)
            end
            dump_rows[#dump_rows + 1] = string.format(
                '    "text_row_%d": {"row": %d, "scanlines": [%s]}',
                row, row, table.concat(sl_strs, ", "))
            dump_count = dump_count + 1
        end

        for _, dr in ipairs(dump_rows) do
            sa_lines[#sa_lines + 1] = dr
        end

        lines[#lines + 1] = table.concat(sa_lines, ",\n")
        lines[#lines + 1] = '  },'

        -- THE CARD'S OWN SCREEN.  A Second Sight card (-slN secondsight)
        -- draws its cell buffer into a screen of its own, so a pixel sample
        -- there is the only evidence that the console reached the card: the
        -- charbuf capture is the console's ring and reads the same either
        -- way.  Every 8th pixel of a 720x400 raster, counted against the
        -- most common value, because the console's background is a colour
        -- and not black.  A snapshot goes beside the dump, for eyes.
        local card = '{"present": false}'
        local seen = {}
        for tag, scr in pairs(manager.machine.screens) do
            seen[#seen + 1] = json_str(tostring(tag))
            if tostring(tag):match(":sl%d:") then
                local hist, samples = {}, 0
                for y = 0, 399, 8 do
                    for x = 0, 719, 8 do
                        local ok, v = pcall(function() return scr:pixel(x, y) end)
                        if ok and v ~= nil then
                            hist[v] = (hist[v] or 0) + 1
                            samples = samples + 1
                        end
                    end
                end
                local best, bestn = 0, 0
                for v, n in pairs(hist) do
                    if n > bestn then best, bestn = v, n end
                end
                local png = output_path:gsub("dump%.json$", "card.png")
                pcall(function() scr:snapshot(png) end)
                card = string.format(
                    '{"present": true, "tag": %s, "samples": %d, "majority": %d, "nonmajority": %d}',
                    json_str(tostring(tag)), samples, best, samples - bestn)
                break
            end
        end
        if card == '{"present": false}' then
            card = '{"present": false, "screens": [' .. table.concat(seen, ", ") .. ']}'
        end
        lines[#lines + 1] = '  "card_screen": ' .. card .. ','

        -- Checkpoints
        lines[#lines + 1] = '  "checkpoints": {'
        local cp_lines = {}
        for _, cp in ipairs(checkpoints) do
            local cpaddr = cp.kbank and kbank_resolve(cp.addr) or cp.addr
            local ok, val = pcall(function() return mem:read_u8(cpaddr) end)
            local actual = ok and val or -1
            local passed = (cp.expect == nil) or (actual == cp.expect)
            cp_lines[#cp_lines + 1] = string.format(
                '    %s: {"addr": %d, "actual": %d, "expected": %s, "pass": %s, "desc": %s}',
                json_str(cp.name), cpaddr, actual,
                cp.expect and tostring(cp.expect) or "null",
                passed and "true" or "false",
                json_str(cp.desc or ""))
        end
        lines[#lines + 1] = table.concat(cp_lines, ",\n")

        -- Optional trailing arrays (watch_log, capture_log).
        local trailing = {}
        if #watch_addrs > 0 then
            local wl_lines = {}
            for _, w in ipairs(watch_log) do
                wl_lines[#wl_lines + 1] = string.format(
                    '    {"frame": %d, "name": "%s", "addr": %d, "old": %d, "new": %d, "pc": %d}',
                    w.frame, w.name, w.addr, w.old, w.new, w.pc or -1)
            end
            trailing[#trailing + 1] = '  "watch_log": [\n'
                .. table.concat(wl_lines, ",\n") .. '\n  ]'
        end
        if #watch_min > 0 then
            local wm_lines = {}
            for _, wm in ipairs(watch_min) do
                wm_lines[#wm_lines + 1] = string.format(
                    '    {"name": "%s", "addr": %d, "min": %s, "max": %s, '
                    .. '"first": %s, "hits": %d, "hits8": %d}',
                    wm.name, wm.addr,
                    wm.min and tostring(wm.min) or "null",
                    wm.max and tostring(wm.max) or "null",
                    wm.first and tostring(wm.first) or "null",
                    wm.hits, wm.hits8)
            end
            trailing[#trailing + 1] = '  "watch_min": [\n'
                .. table.concat(wm_lines, ",\n") .. '\n  ]'
        end
        if stack_exc then
            local se_lines = {}
            for dp, t in pairs(stack_exc.tasks) do
                se_lines[#se_lines + 1] = string.format(
                    '    {"dp": %d, "max_e": %d, "e_pb": %s, "e_pc": %s, '
                    .. '"e_s": %s, "e_fb": %s, "e_db": %s, "min_s": %d, '
                    .. '"max_s": %d, "floor": %d, "ms_pb": %s, "ms_pc": %s, '
                    .. '"ms_fb": %s, "hits": %d}',
                    dp, t.max_e,
                    tostring(t.e_pb or -1), tostring(t.e_pc or -1),
                    tostring(t.e_s or -1), tostring(t.e_fb or -1),
                    tostring(t.e_db or -1), t.min_s,
                    t.max_s or -1, t.floor or 0,
                    tostring(t.ms_pb or -1), tostring(t.ms_pc or -1),
                    tostring(t.ms_fb or -1), t.hits)
            end
            trailing[#trailing + 1] = '  "stack_excursion": [\n'
                .. table.concat(se_lines, ",\n") .. '\n  ]'
        end
        -- Build the emitted list as a COPY: capture_log (keep="first" taps)
        -- plus a chronological drain of each keep="last" ring.  It must not
        -- mutate capture_log -- do_dump can run more than once per session, and
        -- appending there duplicated every ring entry on each call.
        -- ECHO THE WATCH LIST, always -- including taps that recorded
        -- nothing, which is the case that matters.  A checker that recomputes
        -- a tap's address independently can disagree with the address the
        -- plugin actually watched, and the disagreement is invisible until the
        -- two expressions stop coinciding: apple/fgx#104, where a base-anchored
        -- manifest and a top-anchored checker agreed at one NPROC and differed
        -- by a page at the next.  capture_log alone cannot close that, because
        -- a silent tap contributes no entry and so carries no address -- and a
        -- silent tap is exactly what a control arm reports on.
        local cc_lines = {}
        for _, cw in ipairs(capture_writes) do
            cc_lines[#cc_lines + 1] = string.format(
                '    {"name": "%s", "addr": %d, "len": %d, "hits": %d}',
                cw.name, cw.addr, cw.len, cw.hits)
        end
        if #cc_lines > 0 then
            trailing[#trailing + 1] = '  "capture_config": [\n'
                            .. table.concat(cc_lines, ",\n") .. "\n  ]"
        end

        local emit_log = {}
        for _, c in ipairs(capture_log) do emit_log[#emit_log + 1] = c end
        for _, cw in ipairs(capture_writes) do
            if cw.keep == "last" then
                if cw.wrapped then
                    for i = cw.ringpos, cw.max_hits do
                        emit_log[#emit_log + 1] = cw.ring[i]
                    end
                end
                for i = 1, cw.ringpos - 1 do
                    emit_log[#emit_log + 1] = cw.ring[i]
                end
                emu.print_info(string.format(
                    "fgxdebug: capture '%s' keep=last, %d total hits, kept %d",
                    cw.name, cw.hits,
                    cw.wrapped and cw.max_hits or (cw.ringpos - 1)))
            end
        end
        if #emit_log > 0 then
            local function hexbytes(t)
                local h = {}
                for i = 1, #t do h[i] = string.format("%02x", t[i]) end
                return table.concat(h)
            end
            local cl_lines = {}
            for _, c in ipairs(emit_log) do
                cl_lines[#cl_lines + 1] = string.format(
                    '    {"name": "%s", "off": %d, "data": %d, "frame": %d, '
                    .. '"seq": %d, "PB": %d, "PC": %d, '
                    .. '"S": %d, "D": %d, "DB": %d, "A": %d, "X": %d, "Y": %d, '
                    .. '"stk": "%s", "dp": "%s"}',
                    c.name, c.off, c.data, c.frame or -1, c.seq or -1,
                    c.PB, c.PC, c.S, c.D, c.DB,
                    c.A, c.X, c.Y, hexbytes(c.stk), hexbytes(c.dp))
            end
            trailing[#trailing + 1] = '  "capture_log": [\n'
                .. table.concat(cl_lines, ",\n") .. '\n  ]'
        end
        if #trailing == 0 then
            lines[#lines + 1] = '  }'
        else
            lines[#lines + 1] = '  },'
            lines[#lines + 1] = table.concat(trailing, ",\n")
        end

        lines[#lines + 1] = "}"

        local json = table.concat(lines, "\n")

        -- Write to file
        local f = io.open(output_path, "w")
        if f then
            f:write(json)
            f:write("\n")
            f:close()
            emu.print_info("fgxdebug: wrote " .. output_path)
        else
            emu.print_error("fgxdebug: failed to write " .. output_path)
        end

        -- PC-sampler output (Phase-0 profiler), gated on the config key.
        if pc_sample_out then
            local pf = io.open(pc_sample_out, "w")
            if pf then
                local parts = {}
                for k, v in pairs(pc_hist) do
                    parts[#parts + 1] = string.format('"%s":%d', k, v)
                end
                local wall = (pc_t0 and emu.time) and (emu.time() - pc_t0) or 0
                -- kbank (the live kernel code+data bank) lets the post-processor
                -- exclude kernel samples whose in-bank offsets would otherwise
                -- collide with the tool's seg0 offsets.
                pf:write(string.format(
                    '{"samples":{%s},"total":%d,"wall_s":%.3f,"kernel_bank":%d}\n',
                    table.concat(parts, ","), pc_total, wall, kbank))
                pf:close()
                emu.print_info(string.format(
                    "fgxdebug: wrote %d pc samples -> %s", pc_total, pc_sample_out))
            end
        end
    end

    -- Inspect available device methods (run once at start)
    local device_inspected = false

    -- Write watchpoints, opt-in via $FGX_WATCH: a comma-separated list of
    -- ADDR[:LEN] tokens.  ADDR is either an absolute 24-bit CPU address
    -- ("0x00C000") or "k:OFFSET" -- a HEX offset within the live kernel bank,
    -- which is what a kernel symbol from the build listing actually is:
    --
    --   FGX_WATCH=k:2EC5 \
    --   FGX_MAME_EXTRA_ARGS='-debug -debugger none -oslog' \
    --   python3 tools/mame_test/run.py NAME --fresh
    --
    -- ...then grep the run's mame_stderr.log for "FGXWP @addr val= pc=".
    --
    -- USE k: FOR KERNEL SYMBOLS.  The kernel assembles at ORG $02xxxx but the
    -- relocating loader runs it somewhere else entirely (measured: bank $7D).
    -- A watchpoint on the assembly address watches a bank the kernel never
    -- executes in and faithfully reports ZERO hits, which reads exactly like
    -- "nothing writes this cell" -- a false negative that costs a whole
    -- theory.  k: tokens wait for the relocation anchor at $00:032C and are
    -- installed on the first frame it is valid.
    --
    -- Two MAME facts this depends on, both found the hard way:
    --   * -debugscript does NOT run under `-debugger none`.  A sourced script
    --     is only processed when the debugger next STOPS, and the none-
    --     debugger never stops, so the script silently never executes.
    --     Setting the watchpoint from Lua sidesteps that: a watchpoint hit is
    --     itself a stop, so its ACTION does run.
    --   * `printf` from that action goes to the debugger console, which
    --     `-debugger none` discards.  `logerror` + `-oslog` reaches stderr.
    --
    -- Env, not a manifest key or a config field, deliberately: a committed
    -- test must never depend on the debugger being available.
    local wp_pending = nil          -- tokens not yet installed
    local function install_watchpoints()
        if wp_pending == nil then
            local spec = os.getenv("FGX_WATCH")
            if not spec or spec == "" then wp_pending = {} return end
            wp_pending = {}
            for tok in spec:gmatch("[^,%s]+") do
                wp_pending[#wp_pending + 1] = tok
            end
        end
        if #wp_pending == 0 then return end
        if not (cpu and mem) then return end
        if not cpu.debug then
            emu.print_error("fgxdebug: FGX_WATCH needs MAME's debugger -- "
                            .. "add -debug to FGX_MAME_EXTRA_ARGS")
            wp_pending = {}
            return
        end
        local still = {}
        for _, tok in ipairs(wp_pending) do
            -- "r!" prefix = READ watchpoint (an opcode fetch is a read, so this
            -- answers "was this routine ever ENTERED", which a write watchpoint
            -- cannot).  Default stays write.
            local wtype = "w"
            local rtok = tok:match("^r!(.+)$")
            if rtok then wtype, tok = "r", rtok end
            local kern = tok:match("^[kK]:(.+)$")
            local body = kern or tok
            local a, l = body:match("^([^:]+):(.+)$")
            local off  = tonumber(a or body, kern and 16 or nil)
            local wlen = tonumber(l or "1") or 1
            local addr = off
            local defer = false
            if kern then
                -- Kernel-bank-relative: WAIT for the relocation anchor.  The
                -- kernel is not in bank $02 at runtime (measured $7D), and a
                -- watchpoint installed at reset against the assembly ORG
                -- watches a bank the kernel never executes in -- it reports
                -- ZERO writes and reads as "nothing writes this cell".
                local base = kern_base()
                if base == 0x020000 then
                    still[#still + 1] = tok           -- anchor not up yet
                    defer = true
                else
                    addr = base + off
                end
            end
            if defer then
                -- nothing to do this pass
            elseif addr == nil then
                emu.print_error("fgxdebug: FGX_WATCH: bad address " .. tok)
            else
                -- REGISTERS COME AFTER pc, NOT INSTEAD OF IT.  A wrong register
                -- name makes the whole logerror fail, and a watchpoint that
                -- logs NOTHING reads exactly like a cell nobody writes -- the
                -- false negative this block's own header warns about.  Keeping
                -- @addr/val/pc first means a broken tail is visible as a
                -- SHORTENED line rather than as silence.  s answers "where was
                -- the stack", which is what a runaway push needs and what the
                -- address alone cannot say.
                local ok, err = pcall(function()
                    cpu.debug:wpset(mem, wtype, addr, wlen, "1",
                        'logerror "FGXWP @%06X val=%02X pc=%06X s=%04X a=%04X '
                        .. 'x=%04X y=%04X db=%02X\\n",wpaddr,'
                        .. 'wpdata,pc,s,a,x,y,db; g')
                end)
                if ok then
                    emu.print_info(string.format(
                        "fgxdebug: %s watchpoint at %06X len=%d",
                        wtype, addr, wlen))
                else
                    emu.print_error("fgxdebug: wpset failed: " .. tostring(err))
                end
            end
        end
        wp_pending = still
    end

    -- Machine reset: grab CPU and memory references
    subscriptions[#subscriptions + 1] = emu.add_machine_reset_notifier(function()
        cpu = manager.machine.devices[":maincpu"]
        if cpu then
            mem = cpu.spaces["program"]
            emu.print_info("fgxdebug: attached to " .. (cpu.shortname or "maincpu"))
        else
            emu.print_error("fgxdebug: maincpu not found")
        end
        frame_count = 0
        dump_done = false
        -- Reset PC-sampler state; load_config() re-detects the opt-in key.
        pc_sample_out = nil
        pc_hist = {}
        pc_total = 0
        pc_t0 = nil
        pc_armed = false
        load_config()
        -- RAM garbage first, targeted poison second: a fixture that pins one
        -- cell must win over the fill, not race it.
        if ram_poison_seed and mem then
            -- LCG (Numerical Recipes): reproducible across Lua builds, which
            -- math.random is NOT -- and a seed that does not repeat cannot be
            -- bisected.
            local st = ram_poison_seed % 0x100000000
            local function nextbyte()
                st = (st * 1664525 + 1013904223) % 0x100000000
                -- bits 16..23: the low bits of an LCG are notoriously
                -- non-random, and a fill whose low bit alternates is a pattern
                -- the kernel could accidentally survive.
                return math.floor(st / 65536) % 256
            end
            -- SKIP THE I/O WINDOW, NOT THE LANGUAGE CARD.  $00C000..$00CFFF
            -- and $01C000..$01CFFF are soft switches -- writing them is not
            -- "memory held garbage", it is pulling levers no power-on does.
            --
            -- $00D000..$00FFFF IS COVERED, and covering it is the point: it is
            -- read-mapped to ROM at reset, so a naive fill lands nowhere, and
            -- FGX_DP_KERNELC_IRQ ($00FA00) and FGX_STK_KIRQ ($00FB00..$00FCFF)
            -- BOTH LIVE THERE -- the newest boot-path state in the kernel and
            -- the least covered.  So the card is banked in first, exactly as
            -- KTTY_KC_ENTER_IRQ does it: "Perform two reads to $C083; then ...
            -- language card write enabled" -- IIgs Firmware Reference, App. E,
            -- STATEREG.  $D000..$DFFF is banked TWICE ($C08B bank 1, $C083
            -- bank 2) because the two are different DRAM and a power-on leaves
            -- garbage in both.  ROM is put back afterwards, which is the state
            -- reset leaves and therefore the state the ROM's own startup
            -- expects to find.
            local filled = 0
            local consumed = 0
            local ok = pcall(function()
                for bank = 0, ram_poison_top_bank do
                    local lo, hi = 0x0000, 0xFFFF
                    if bank <= 1 then hi = 0xBFFF end
                    local base = bank * 0x10000
                    -- TOP-BANK WINDOW: poison only [win_lo, win_hi] of the
                    -- HIGHEST bank, leaving the rest of it zero.  The stream is
                    -- still consumed for every skipped byte, so each byte keeps
                    -- the value it would have had -- that is what lets a window
                    -- be compared against the full fill.  Bisecting WITHIN a
                    -- bank is how a trigger gets from "bank $40" down to a
                    -- structure; without it, apple/fgx#360 stops at the bank.
                    local wlo, whi = 0x0000, 0xFFFF
                    if bank == ram_poison_top_bank then
                        wlo, whi = ram_poison_win_lo, ram_poison_win_hi
                    end
                    for off = lo, hi do
                        local b = nextbyte()
                        if off >= wlo and off <= whi then
                            mem:write_u8(base + off, b)
                            filled = filled + 1
                        end
                    end
                    -- CONSUMED, not written: the stream advances over skipped
                    -- bytes too, and it is the consumed count the language-card
                    -- catch-up below must reason about.  Conflating the two
                    -- would make a windowed run silently re-roll the card.
                    consumed = consumed + (hi - lo + 1)
                end
                -- ADVANCE THE STREAM TO ITS FULL-FILL POSITION FIRST, so the
                -- language card holds the same bytes whatever ram_poison_top_bank
                -- was.  The fill is positional -- bank 0 upward -- so lowering
                -- the top bank leaves every bank BELOW it byte-identical, which
                -- is what makes a bank-restricted run comparable to a full one.
                -- The card was the one leak in that property: it is filled AFTER
                -- the loop from the same stream, so a shorter loop used to hand
                -- it different bytes and quietly changed a second variable.
                -- At the default top bank this loop runs zero times, so the
                -- committed fixtures' bytes do not move.
                local FULL_FILL = 2 * 0xC000 + 126 * 0x10000   -- banks $00..$7F
                for _ = consumed + 1, FULL_FILL do nextbyte() end
                -- The bank-0 language card, both $D000 banks.
                for _, sw in ipairs({ 0xE0C08B, 0xE0C083 }) do
                    mem:read_u8(sw) ; mem:read_u8(sw)   -- read RAM, write-enable
                    local hi = (sw == 0xE0C08B) and 0xFFFF or 0xDFFF
                    for off = 0xD000, hi do
                        mem:write_u8(off, nextbyte())
                    end
                    filled = filled + (hi - 0xD000 + 1)
                end
                mem:read_u8(0xE0C08A) ; mem:read_u8(0xE0C08A)  -- ROM back
            end)
            emu.print_info(string.format(
                "fgxdebug: ram_poison seed=%d banks $00..$%02X win $%04X-$%04X, "
                .. "%d B at RESET (%s)",
                ram_poison_seed, ram_poison_top_bank,
                ram_poison_win_lo, ram_poison_win_hi, filled,
                ok and "ok" or "FAILED"))
        end
        -- "frame": 0 means BEFORE THE FIRST INSTRUCTION.  Poisoning a few frames
        -- in is 30-odd ms into the ROM's own startup, so a region the ROM is
        -- actively using gets clobbered mid-flight and any machine would die --
        -- an artifact, not a warm boot.  At reset the memory simply already
        -- holds those bytes, which is exactly what a warm boot is.
        for _, p in ipairs(poison) do
            if not p.done and p.frame == 0 then
                p.done = true
                local n, ok
                if p.hex then
                    n = #p.hex / 2
                    ok = pcall(function()
                        for i = 0, n - 1 do
                            mem:write_u8(p.addr + i,
                                tonumber(p.hex:sub(i * 2 + 1, i * 2 + 2), 16))
                        end
                    end)
                else
                    n = p.len
                    ok = pcall(function()
                        for i = 0, n - 1 do mem:write_u8(p.addr + i, p.byte) end
                    end)
                end
                emu.print_info(string.format(
                    "fgxdebug: poisoned $%06X..$%06X (%d B) at RESET (%s)",
                    p.addr, p.addr + n - 1, n, ok and "ok" or "FAILED"))
            end
        end
        wp_pending = nil
        install_watchpoints()
    end)

    -- Machine stop: final dump + cleanup
    subscriptions[#subscriptions + 1] = emu.add_machine_stop_notifier(function()
        do_dump()
        cpu = nil
        mem = nil
    end)

    -- Optional: script of {frame, "text"} entries to paste at given frames.
    -- Configurable via JSON field "input_script": [[frame, "text"], ...]
    local input_script = {}
    local input_script_idx = 1
    local nk = nil
    -- How to deliver input_script text: "post", "paste", or "both" (legacy
    -- default; see the A/B note at the send site).
    local paste_mode = "both"
    -- Kernel-ring keystroke injection (the natural_keyboard Lua property is
    -- nil in MAME 0.288, so scripted input is written straight into the
    -- kernel's heartbeat-fed keyboard ring).  Addresses are kernel-bank
    -- offsets from include/memmap.s — keep in sync (same convention as the
    -- hardcoded memory_regions above).
    -- These defaults are a LAST RESORT: run.py normally derives the live
    -- offsets from the kernel listing and passes them in the config's
    -- "kbd_ring" field (see load_input_script).  Hardcoding them here rotted
    -- silently once — kernel data grew, the cells moved $540, and every
    -- scripted keystroke went into dead memory with nothing reporting it.
    local KBD_RING_BASE  = 0xE732          -- _kKbdRing (16 slots)
    local KBD_RING_HEAD  = 0xE742          -- _kKbdRingHead (2 B)
    local KBD_RING_COUNT = 0xE746          -- _kKbdRingCount (2 B)
    local KBD_RING_SZ    = 16
    -- Raw-key inject (vt100 keyboard net).  The heartbeat consumes a
    -- PRE-translation ADB byte here and runs it through the SAME vt100
    -- translation as a real strobe, so the ADB->vt100 path (arrows ->
    -- ESC-seq, Ctrl+letter -> bare) is headless-testable even though the
    -- $E0C000 latch is not pokeable in MAME.  Encoding: lo = 7-bit key,
    -- bit 8 = Ctrl-held.  Self-clearing: heartbeat STZs it after consuming,
    -- so the drainer writes the next only when it reads back 0.
    local raw_inject_queue = {}            -- pending {key, ctrl} entries
    local raw_script       = {}            -- frame-tagged {frame,key,ctrl}
    local raw_script_idx   = 1
    local KBD_INJECT_RAW   = 0xE748        -- _kKbdInjectRaw (2 B)

    -- Exit-marker polling: when memory at addr matches expected byte,
    -- request a clean MAME exit (and optionally trigger a save state
    -- first).  Lets a test runner cut MAME off the instant the test
    -- program finishes rather than burning the full timeout.
    local exit_marker = nil       -- { addr = ..., byte_eq = ..., done = false }
    local exit_after_frame = nil  -- hard frame cap (defense in depth)
    local save_state_name = nil   -- save state name to write at exit
    local exit_pending = false
    local exit_at_frame = nil

    -- Prompt-counting exit.  Polls the kernel charbuf at $030000
    -- (low byte = 7-bit ASCII char per cell, 8000 cells) for the
    -- shell-prompt sentinel (e.g. "fgx:" or "/root/").  Snapshots
    -- the count just before the first paste; subsequent frames
    -- exit when count exceeds snapshot + N.
    local prompt_sentinel = nil     -- bytes of the pattern
    local prompt_snapshot = nil     -- count at first-paste time
    local prompt_snapshot_frame = nil  -- frame to take the baseline (the
                                       -- autoboot paste moment; config-fed)
    local prompt_target_delta = 1   -- exit when count - snapshot >= this
    local CHARBUF_ADDR = 0x030000
    local CHARBUF_LEN  = 8000

    -- (watch_addrs / watch_log / watch_log_max declared earlier so do_dump
    -- can close over them.)

    local function load_extra_config()
        local f = io.open(config_path, "r")
        if not f then return end
        local content = f:read("*a")
        f:close()
        -- Auto-exit / input-script logic only fires when the config
        -- explicitly says `"test_mode": true`.  Otherwise the plugin
        -- still loads (memory dumps, screen analysis) but won't
        -- hijack an interactive session.
        if not content:match('"test_mode"%s*:%s*true') then
            emu.print_info("fgxdebug: config present but test_mode "
                           .. "not set — passive mode (dumps only)")
            return
        end
        local ea = content:match('"exit_marker"%s*:%s*%b{}')
        if ea then
            local addr = ea:match('"addr"%s*:%s*(%d+)')
            local bv   = ea:match('"byte_eq"%s*:%s*(%d+)')
            if addr and bv then
                exit_marker = { addr = tonumber(addr), byte_eq = tonumber(bv),
                                done = false }
                emu.print_info(string.format(
                    "fgxdebug: exit-marker addr=%d byte_eq=%d",
                    exit_marker.addr, exit_marker.byte_eq))
            end
        end
        local frame_cap = content:match('"exit_after_frame"%s*:%s*(%d+)')
        if frame_cap then exit_after_frame = tonumber(frame_cap) end
        local snap = content:match('"png_snapshot"%s*:%s*"([^"]+)"')
        if snap then png_snapshot = snap end
        local pm = content:match('"paste_mode"%s*:%s*"([^"]+)"')
        if pm then paste_mode = pm end
        local psf = content:match('"prompt_snapshot_frame"%s*:%s*(%d+)')
        if psf then prompt_snapshot_frame = tonumber(psf) end
        local ssn = content:match('"save_state"%s*:%s*"([^"]+)"')
        if ssn then
            save_state_name = ssn
            emu.print_info("fgxdebug: will save state '" .. ssn .. "' at exit")
        end
        -- exit_on_prompt: { sentinel: "fgx:", count_delta: 1 }
        local eop = content:match('"exit_on_prompt"%s*:%s*%b{}')
        if eop then
            local sent = eop:match('"sentinel"%s*:%s*"([^"]+)"')
            if sent then
                prompt_sentinel = sent
                local cd = eop:match('"count_delta"%s*:%s*(%d+)')
                if cd then prompt_target_delta = tonumber(cd) end
                emu.print_info(string.format(
                    "fgxdebug: exit_on_prompt sentinel=%q count_delta=%d",
                    prompt_sentinel, prompt_target_delta))
            end
        end
        -- paste_frame: the autoboot paste's absolute frame, so the dump can
        -- say which origin a manifest's region frames were resolved against.
        local pf = content:match('"paste_frame"%s*:%s*(%d+)')
        if pf then paste_frame = tonumber(pf) end
        -- watch_addrs: [{name, addr}, ...]  Per-frame poll; log every
        -- value change to watch_log (included in dump output).
        local wa_block = content:match('"watch_addrs"%s*:%s*(%b[])')
        if wa_block then
            for name, addr in wa_block:gmatch('"name"%s*:%s*"([^"]+)"%s*,%s*"addr"%s*:%s*(%d+)') do
                table.insert(watch_addrs, {
                    name = name, addr = tonumber(addr), last = nil
                })
            end
            emu.print_info(string.format(
                "fgxdebug: watching %d address(es)", #watch_addrs))
        end
        -- capture_writes: [{name, addr, len, max_hits}]  Instruction-precise
        -- write-tap snapshots (writer PC + registers + return chain + DP window).
        local cw_block = content:match('"capture_writes"%s*:%s*(%b[])')
        if cw_block then
            for item in cw_block:gmatch('%b{}') do
                local addr = item:match('"addr"%s*:%s*(%d+)')
                if addr then
                    table.insert(capture_writes, {
                        name = item:match('"name"%s*:%s*"([^"]+)"') or "cap",
                        addr = tonumber(addr),
                        len  = tonumber(item:match('"len"%s*:%s*(%d+)') or "1"),
                        max_hits = tonumber(item:match('"max_hits"%s*:%s*(%d+)') or "32"),
                        -- "first" (default) preserves the behaviour every
                        -- existing fixture relies on; "last" opts into the ring.
                        keep = item:match('"keep"%s*:%s*"([^"]+)"') or "first",
                        ring = {}, ringpos = 1, wrapped = false,
                        hits = 0 })
                end
            end
            emu.print_info(string.format(
                "fgxdebug: capture_writes on %d region(s)", #capture_writes))
        end
        -- watch_min: [{name, addr|addr_hex}]  Aggregate 16-bit write values
        -- into {min,max,hits} per cell — for high-water measurements where a
        -- per-hit capture log would be huge (e.g. _fcc_ssp on every prologue).
        local wm_block = content:match('"watch_min"%s*:%s*(%b[])')
        if wm_block then
            for item in wm_block:gmatch('%b{}') do
                local a = item:match('"addr"%s*:%s*(%d+)')
                local ah = item:match('"addr_hex"%s*:%s*"([0-9A-Fa-f]+)"')
                local addr = a and tonumber(a) or (ah and tonumber(ah, 16))
                if addr then
                    table.insert(watch_min, {
                        name = item:match('"name"%s*:%s*"([^"]+)"') or "wm",
                        addr = addr, min = nil, max = nil, hits = 0, hits8 = 0 })
                end
            end
            emu.print_info(string.format(
                "fgxdebug: watch_min on %d cell(s)", #watch_min))
        end
        -- stack_excursion: { lo, hi }  (defaults to the user-stack arena
        -- $3000..$B000).  Installs one write-tap over that range; on each write
        -- with D in the per-task DP band ($B0xx) it aggregates the per-instant
        -- excursion e = _fcc_fb-1-S — how far the current push descends below
        -- the live C frame base.  The MAX of e (with a PB:PC snapshot) is the
        -- quantity DEFAULT_PAD must cover (hand-asm libc / IRQ frame / signal
        -- trampoline pushes the static call graph cannot see); absolute min_S
        -- is kept as a cross-check.  P3-3 pad-calibration (task #42).
        local se_block = content:match('"stack_excursion"%s*:%s*(%b{})')
        if se_block then
            local function se_num(key)
                local a = se_block:match('"'..key..'"%s*:%s*(%d+)')
                local ah = se_block:match('"'..key..'_hex"%s*:%s*"([0-9A-Fa-f]+)"')
                return a and tonumber(a) or (ah and tonumber(ah, 16)) or nil
            end
            -- DP window for write attribution, from the harness rather than
            -- baked here.  The harness sends none today: a task's direct
            -- page is the first page of its own stack reservation, not a
            -- pid-indexed band, so the tap does not attribute hits.
            local dp_base = se_num("dp_base")
            local nproc   = se_num("nproc")
            stack_exc = { lo = se_num("lo") or 0x3000,
                          hi = se_num("hi") or 0xB000, tasks = {},
                          dp_lo = dp_base and (dp_base + 0x100) or nil,
                          dp_hi = (dp_base and nproc)
                                  and (dp_base + nproc * 0x100) or nil }
            -- A dp_base, when one is given, names the kernel DP region.
            if dp_base then
                for _, r in ipairs(memory_regions) do
                    if r.name == "kernel_dp" then r.addr = dp_base end
                end
            end
            emu.print_info(string.format(
                "fgxdebug: stack_excursion over $%04X..$%04X",
                stack_exc.lo, stack_exc.hi))
        end
        -- cycle_markers: { start_addr: N, done_addr: M, out_path: "..." }
        -- fbench cycle timing: capture emu.time() at the START/DONE marker writes.
        local cm = content:match('"cycle_markers"%s*:%s*%b{}')
        if cm then
            local sa = cm:match('"start_addr"%s*:%s*(%d+)')
            local da = cm:match('"done_addr"%s*:%s*(%d+)')
            local op = cm:match('"out_path"%s*:%s*"([^"]+)"')
            if sa and da then
                cyc_start_addr = tonumber(sa)
                cyc_done_addr  = tonumber(da)
                cyc_out_path   = op or "/tmp/fbench_cyc.json"
                emu.print_info(string.format(
                    "fgxdebug: cycle markers start=%d done=%d -> %s",
                    cyc_start_addr, cyc_done_addr, cyc_out_path))
            end
        end
    end

    -- Count occurrences of `prompt_sentinel` in charbuf (low 7 bits
    -- of each cell).  Returns nil if memory access fails.
    local function count_prompts()
        if not prompt_sentinel or not mem then return nil end
        local base = con_base()             -- charbuf moved off fixed $03 under reloc
        local buf = {}
        for i = 0, CHARBUF_LEN - 1 do
            local ok, v = pcall(function() return mem:read_u8(base + i) end)
            if not ok then return nil end
            buf[i + 1] = string.char(v % 128)
        end
        local s = table.concat(buf)
        local count = 0
        local from = 1
        while true do
            local hit = s:find(prompt_sentinel, from, true)
            if not hit then break end
            count = count + 1
            from = hit + 1
        end
        return count
    end

    local function load_input_script()
        local f = io.open(config_path, "r")
        if not f then return end
        local content = f:read("*a")
        f:close()
        -- Only fire scripted input in test mode.
        if not content:match('"test_mode"%s*:%s*true') then return end
        -- Live keyboard-ring offsets from run.py (kernel listing), overriding
        -- the built-in constants so a kernel data move can't silently kill
        -- scripted input.
        local kblock = content:match('"kbd_ring"%s*:%s*(%b{})')
        if kblock then
            local function cell(name)
                return tonumber(kblock:match('"' .. name .. '"%s*:%s*(%d+)'))
            end
            local base, head = cell("_kKbdRing"), cell("_kKbdRingHead")
            local count, raw = cell("_kKbdRingCount"), cell("_kKbdInjectRaw")
            if base and head and count and raw then
                KBD_RING_BASE, KBD_RING_HEAD = base, head
                KBD_RING_COUNT, KBD_INJECT_RAW = count, raw
                emu.print_info(string.format(
                    "fgxdebug: kbd ring from listing: base=%04X head=%04X "
                    .. "count=%04X raw=%04X", base, head, count, raw))
            end
            -- _kConsoleBank: the LIVE framebuffer bank.  With it, charbuf dumps
            -- follow a virtual-console switch instead of forever showing the
            -- boot console (apple/fgx#40).
            local vb = cell("_kVcBank")
            if vb then KVC_BANK = vb end
            -- _modBankTab: the ordinal -> real-bank map Mod_Load fills.  Lets a
            -- test dump a LOADED MODULE'S IMAGE without baking the bank the
            -- allocator happened to choose (apple/fgx#110).
            local mbt = cell("_modBankTab")
            if mbt then MOD_BANK_TAB = mbt end
            local cb = cell("_kConsoleBank")
            if cb then
                KCONSOLE_BANK = cb
                emu.print_info(string.format(
                    "fgxdebug: _kConsoleBank at %04X -- charbuf follows the "
                    .. "active console", cb))
            end
        end
        local block = content:match('"input_script"%s*:%s*(%b[])')
        if block then
            for frame, text in block:gmatch('%[%s*(%d+)%s*,%s*"([^"]*)"%s*%]') do
                local f_num = tonumber(frame)
                -- Un-escape common JSON escapes so we can inject newlines etc.
                -- ONE pass, so `\\' is a backslash rather than the first half
                -- of the escape after it: run.py json.dumps each command, and
                -- a command containing `\377' arrived as `\\377'.  An escape
                -- not in the table is left as written.
                text = text:gsub('\\(.)', { n = '\n', r = '\r', t = '\t',
                                            e = '\27', ['\\'] = '\\' })
                table.insert(input_script, { frame = f_num, text = text })
                emu.print_info(string.format("fgxdebug: queued paste at frame %d: %q", f_num, text))
            end
        end
        -- raw_inject: [[frame, key, ctrl], ...]  Feeds _kKbdInjectRaw so the
        -- heartbeat's vt100 translation runs (unlike input_script, which pokes
        -- the ring post-translation).  key 0-127, ctrl 0/1.
        local rblock = content:match('"raw_inject"%s*:%s*(%b[])')
        if rblock then
            for frame, key, ctrl in rblock:gmatch('%[%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%]') do
                table.insert(raw_script, { frame = tonumber(frame),
                                           key = tonumber(key),
                                           ctrl = tonumber(ctrl) })
                emu.print_info(string.format(
                    "fgxdebug: queued raw-inject frame %d key=%d ctrl=%d",
                    tonumber(frame), tonumber(key), tonumber(ctrl)))
            end
        end
    end

    local function request_exit()
        if exit_pending then return end
        exit_pending = true
        -- One last dump so the runner sees the final state.
        do_dump()
        -- Save state if requested.  MAME 0.230+ uses
        -- machine:schedule_save(name) which queues the save for the
        -- next frame.  Older versions had machine:save() as direct.
        -- Try several names; ignore failures.
        if save_state_name then
            local methods_tried = {}
            local function try(name, fn)
                local ok, err = pcall(fn)
                table.insert(methods_tried, name .. (ok and "=ok" or "=fail"))
                return ok
            end
            -- machine:save(name) is the working call on MAME 0.287
            -- (verified empirically).  Try that first; fall back to
            -- the other API names for older/newer builds.
            local saved = false
            saved = try("save", function()
                manager.machine:save(save_state_name)
            end) or saved
            if not saved then
                saved = try("schedule_save", function()
                    manager.machine:schedule_save(save_state_name)
                end) or saved
            end
            if not saved then
                saved = try("emu.start_state_save", function()
                    emu.start_state_save(save_state_name)
                end) or saved
            end
            emu.print_info("fgxdebug: save_state '" .. save_state_name ..
                           "' tried [" .. table.concat(methods_tried, ", ") .. "]")
            -- Give MAME several frames to finish the save before exit.
            exit_at_frame = frame_count + 30
        else
            exit_at_frame = frame_count + 1
        end
    end

    -- Per-frame watch-addr poll.  Logs value-change events to watch_log.
    local function poll_watch_addrs()
        if #watch_addrs == 0 or not mem then return end
        -- Snapshot CPU state ONCE per frame (post-execution).  Not the
        -- instruction-precise PC at the write site, but enough to narrow
        -- the responsible subsystem.
        local pc = -1
        if cpu and cpu.state then
            local ok_pc, v_pc = pcall(function() return cpu.state["PC"].value end)
            if ok_pc and type(v_pc) == "number" then pc = v_pc end
        end
        for _, w in ipairs(watch_addrs) do
            local ok, v = pcall(function() return mem:read_u8(w.addr) end)
            if ok and type(v) == "number" then
                if w.last ~= nil and w.last ~= v then
                    -- RING (2026-07-17): keep the LAST watch_log_max changes,
                    -- not the first — a boot-heavy watch drowned the cap in
                    -- early-boot noise and truncated the window under
                    -- investigation (the train-2 M-1 stall hunt).
                    if true then
                        if #watch_log >= watch_log_max then
                            table.remove(watch_log, 1)
                        end
                        table.insert(watch_log, {
                            frame = frame_count, name = w.name,
                            addr = w.addr, old = w.last, new = v, pc = pc
                        })
                    end
                end
                w.last = v
            end
        end
    end

    -- Frame callback: count frames, dump every dump_frame frames (overwrites file)
    emu.register_frame_done(function()
        if not cpu then return end
        frame_count = frame_count + 1
        for _, p in ipairs(poison) do
            if not p.done and p.frame > 0 and frame_count >= p.frame then
                p.done = true
                local n, ok
                if p.hex then
                    n = #p.hex / 2
                    ok = pcall(function()
                        for i = 0, n - 1 do
                            mem:write_u8(p.addr + i,
                                tonumber(p.hex:sub(i * 2 + 1, i * 2 + 2), 16))
                        end
                    end)
                else
                    n = p.len
                    ok = pcall(function()
                        for i = 0, n - 1 do mem:write_u8(p.addr + i, p.byte) end
                    end)
                end
                emu.print_info(string.format(
                    "fgxdebug: poisoned $%06X..$%06X (%d B, %s) at frame %d (%s)",
                    p.addr, p.addr + n - 1, n, p.hex and "blob" or "fill",
                    frame_count, ok and "ok" or "FAILED"))
            end
        end
        if warm_reset_frame and not warm_reset_done
           and frame_count >= warm_reset_frame then
            warm_reset_done = true
            emu.print_info(string.format(
                "fgxdebug: warm reset at frame %d (RAM retained)", frame_count))
            -- Replay the whole input script against the SECOND boot: the
            -- frame numbers it is scheduled on are relative to a boot, and
            -- the reset notifier restarts frame_count.  Without this the
            -- script is consumed by boot 1 and boot 2 is asserted on with
            -- nothing typed into it -- which reads as "the warm boot never
            -- reached a shell" whether or not it did.
            input_script_idx = 1
            -- ...and give the second boot room.  The script's frames are
            -- tuned to a cold boot; a warm one re-enters through the ROM's
            -- reset path and need not take the same time, and a `sh` typed
            -- one frame early is a command that never ran -- indistinguishable
            -- from a boot that never reached a shell.  This margin is the
            -- difference between measuring the warm boot and measuring the
            -- typing.
            script_offset = warm_settle_frames
            for _, e in ipairs(input_script) do e.done = false end
            manager.machine:soft_reset()
            return
        end
        if wp_pending and #wp_pending > 0 then install_watchpoints() end
        -- Kernel-context register snapshot (see kregs decl): when this
        -- frame ended with the CPU executing in the live kernel bank,
        -- capture the registers.  do_dump reports the latest snapshot.
        pcall(function()
            local okm, magic = pcall(function() return mem:read_u8(0x00032D) end)
            if okm and magic == 0x4B then
                local okb, kb = pcall(function() return mem:read_u8(0x00032C) end)
                if okb then
                    local pb = pc_sample_addr()
                    if pb == kb then
                        local snap = {}
                        for name, entry in pairs(cpu.state) do
                            local ok, val = pcall(function() return entry.value end)
                            if ok and type(val) == "number" then snap[name] = val end
                        end
                        kregs, kregs_frame = snap, frame_count
                    end
                end
            end
        end)
        local ok_poll, err_poll = pcall(poll_watch_addrs)
        if not ok_poll and frame_count <= 3 then
            emu.print_error("fgxdebug: poll_watch_addrs error: " .. tostring(err_poll))
        end

        -- Lazy init of natural_keyboard + script + extras
        if frame_count == 1 then
            local ok, kb = pcall(function() return manager.machine.natural_keyboard end)
            if ok then nk = kb end
            if nk then
                local okiu, iu = pcall(function() return nk.in_use end)
                emu.print_info(string.format(
                    "fgxdebug: natural_keyboard acquired (in_use=%s empty=%s full=%s)",
                    okiu and tostring(iu) or "?",
                    tostring(pcall(function() return nk.empty end)),
                    tostring(pcall(function() return nk.full end))))
                -- Newer MAME ignores posted text unless the natural keyboard
                -- is switched on; harmless no-op on builds where it isn't a
                -- writable property.
                pcall(function() nk.in_use = true end)
            else
                emu.print_info("fgxdebug: natural_keyboard NOT available: "
                               .. tostring(kb))
                -- Older/newer API shapes.
                for _, probe in ipairs({
                    function() return manager:machine():natural_keyboard() end,
                    function() return manager:machine().natural_keyboard end,
                    function() return machine.natural_keyboard end,
                }) do
                    local ok2, kb2 = pcall(probe)
                    if ok2 and kb2 then
                        nk = kb2
                        emu.print_info("fgxdebug: natural_keyboard via fallback")
                        break
                    end
                end
            end
            load_input_script()
            load_extra_config()
            -- Install fbench cycle-marker write-taps (instruction-precise:
            -- emu.time() captured at the marker write, not the frame boundary).
            if cyc_start_addr and cyc_done_addr and mem and mem.install_write_tap then
                cyc_taps[#cyc_taps + 1] = mem:install_write_tap(
                    cyc_start_addr, cyc_start_addr + 1, "fbstart",
                    function()
                        if cyc_armed and not cyc_start_t then
                            cyc_start_t = emu.time()
                        end
                    end)
                cyc_taps[#cyc_taps + 1] = mem:install_write_tap(
                    cyc_done_addr, cyc_done_addr + 1, "fbdone",
                    function()
                        if cyc_armed and cyc_start_t and not cyc_done_t then
                            cyc_done_t = emu.time()
                        end
                    end)
                emu.print_info("fgxdebug: cycle taps installed")
            end
            -- Install capture-write taps: instruction-precise state snapshots.
            if #capture_writes > 0 and mem and mem.install_write_tap then
                for _, cw in ipairs(capture_writes) do
                    capture_taps[#capture_taps + 1] = mem:install_write_tap(
                        cw.addr, cw.addr + cw.len - 1, cw.name,
                        function(offset, data, mask)
                            -- keep="first" (default): stop once max_hits are in
                            -- hand -- right for "what touched this FIRST".
                            -- keep="last": never stop; retain the most recent
                            -- max_hits in a per-tap ring -- the only way to see
                            -- a stall at the END of a run, where a first-N tap
                            -- fills with boot noise and reports nothing.
                            if cw.keep ~= "last" and cw.hits >= cw.max_hits then
                                return
                            end
                            cw.hits = cw.hits + 1
                            local function rs(k)
                                local ok, e = pcall(function() return cpu.state[k].value end)
                                return (ok and type(e) == "number") and e or -1
                            end
                            local S = rs("S"); local D = rs("D")
                            -- HW-stack return chain (bank 0): 128 bytes above S
                            -- (deep enough to reach a callee's caller's params).
                            local stk = {}
                            for i = 1, 128 do
                                local ok, v = pcall(function() return mem:read_u8((S + i) % 0x10000) end)
                                stk[i] = (ok and v) or 0
                            end
                            -- Full direct page (bank 0): D+0x00 .. D+0xFF, 256 B
                            -- (covers _fcc_ptr, LIBC_DP_LP0, _fcc_ssp, all ptr slots).
                            local dp = {}
                            for i = 0, 255 do
                                local ok, v = pcall(function() return mem:read_u8((D + i) % 0x10000) end)
                                dp[i + 1] = (ok and v) or 0
                            end
                            -- frame is stamped on EVERY entry, both modes: a
                            -- capture with no time axis cannot distinguish
                            -- "stopped happening" from "never captured".
                            capture_seq = capture_seq + 1
                            local ent = {
                                name = cw.name, off = offset or -1, data = data or -1,
                                frame = frame_count, seq = capture_seq,
                                PB = rs("PB"), PC = rs("PC"), S = S, D = D, DB = rs("DB"),
                                A = rs("A"), X = rs("X"), Y = rs("Y"), stk = stk, dp = dp }
                            if cw.keep == "last" then
                                -- Ring: overwrite in place, O(1) per hit.  Drained
                                -- in chronological order at dump time.
                                cw.ring[cw.ringpos] = ent
                                cw.ringpos = cw.ringpos + 1
                                if cw.ringpos > cw.max_hits then
                                    cw.ringpos = 1
                                    cw.wrapped = true
                                end
                            else
                                capture_log[#capture_log + 1] = ent
                            end
                        end)
                end
                emu.print_info(string.format(
                    "fgxdebug: capture taps installed on %d region(s)", #capture_writes))
            end
            -- watch_min taps: aggregate 16-bit write values, no logging.
            if #watch_min > 0 and mem and mem.install_write_tap then
                -- Kernel bank from the $00:032C anchor (magic $4B at $032D):
                -- used to IGNORE kernel writers (TCB DP-page zeroing, scratch)
                -- so only user-code writes (fcc prologue ssp updates) count.
                local wm_kbank = 0x02
                do
                    local ok, m = pcall(function() return mem:read_u8(0x32D) end)
                    if ok and m == 0x4B then
                        local ok2, b = pcall(function() return mem:read_u8(0x32C) end)
                        if ok2 then wm_kbank = b end
                    end
                end
                for _, wm in ipairs(watch_min) do
                    capture_taps[#capture_taps + 1] = mem:install_write_tap(
                        wm.addr, wm.addr + 1, wm.name,
                        function(offset, data, mask)
                            -- The 65816 bus issues 16-bit stores as TWO 8-bit
                            -- writes, low byte first.  Aggregate on the HIGH
                            -- byte: the low byte has already landed, so
                            -- cell = (hi<<8) | read(lo).
                            local pb_ok, pb = pcall(function()
                                return cpu.state["PB"].value end)
                            if pb_ok and (pb == wm_kbank or pb == 0) then
                                return          -- kernel/bank-0 writer: not ssp
                            end
                            if offset == wm.addr + 1 then
                                local lo_ok, lo = pcall(function()
                                    return mem:read_u8(wm.addr) end)
                                local v = ((data % 0x100) * 0x100)
                                          + ((lo_ok and lo) or 0)
                                if v == 0 then return end  -- crt0 pre-seed zero
                                if not wm.first then wm.first = v end
                                if not wm.min or v < wm.min then wm.min = v end
                                if not wm.max or v > wm.max then wm.max = v end
                                wm.hits = wm.hits + 1
                            else
                                wm.hits8 = wm.hits8 + 1
                            end
                        end)
                end
                emu.print_info(string.format(
                    "fgxdebug: watch_min taps on %d cell(s)", #watch_min))
            end
            -- stack_excursion tap: ONE write-tap over the user-stack arena.
            -- A write into [lo,hi) happens only in USER context (kernel stacks
            -- are $0100 + $1000-$1FFF, below $3000), so D = the running task's
            -- DP (the first page of its reservation) and fb = mem16[D+$BC].  e = fb-1-S is the depth
            -- of the current push below the live C frame base — invisible to
            -- stack_measure when it happens inside hand-asm libc, the IRQ hw
            -- frame, or the signal trampoline.  Key by D (per task); keep max_e
            -- with a PB:PC snapshot and the absolute min_S with its own context.
            if stack_exc and mem and mem.install_write_tap then
                capture_taps[#capture_taps + 1] = mem:install_write_tap(
                    stack_exc.lo, stack_exc.hi - 1, "stack_exc",
                    function(offset, data, mask)
                        local function rs(k)
                            local ok, e = pcall(function() return cpu.state[k].value end)
                            return (ok and type(e) == "number") and e or -1
                        end
                        local D = rs("D")
                        -- Attribution needs a DP band from the harness, and
                        -- there is none any more: a task's direct page is the
                        -- first page of its own stack reservation.  Missing
                        -- bounds SKIP the hit: attributing a write to the
                        -- wrong task is worse than not attributing it.
                        if not stack_exc.dp_lo or not stack_exc.dp_hi then
                            return
                        end
                        if D < stack_exc.dp_lo or D > stack_exc.dp_hi
                           or (D % 0x100) ~= 0 then
                            return
                        end
                        local S = rs("S")
                        -- Require S itself in the arena: a write with a task-band
                        -- D but S on the kernel stack ($1xxx) is the kernel
                        -- staging a child — a stale fb there would poison e
                        -- (fb-1-S passes the <=0x4000 gate).  The harmful
                        -- descents we size the pad for all run on the task's own
                        -- in-arena stack.  (Inert for this run — every recorded
                        -- extremum already had in-arena S.)
                        if S < stack_exc.lo or S >= stack_exc.hi then return end
                        local function fbread()
                            local ok, v = pcall(function()
                                return mem:read_u8((D + 0xBC) % 0x10000)
                                     + mem:read_u8((D + 0xBD) % 0x10000) * 0x100 end)
                            return ok and v or nil
                        end
                        local t = stack_exc.tasks[D]
                        if not t then
                            -- Seed the guard floor (kernel-written _fcc_stkfloor
                            -- at DP $B9 = StackBase + FCC_STK_FLOOR_MARGIN) so
                            -- headroom can be derived offline.
                            local fok, fl = pcall(function()
                                return mem:read_u8((D + 0xB9) % 0x10000)
                                     + mem:read_u8((D + 0xBA) % 0x10000) * 0x100 end)
                            t = { max_e = -1, min_s = 0x10000, max_s = -1,
                                  hits = 0, floor = (fok and fl) or 0 }
                            stack_exc.tasks[D] = t
                        end
                        t.hits = t.hits + 1
                        -- min_S / max_S are fb-INDEPENDENT (also valid for hand-
                        -- asm tasks + the raw IRQ/signal frame): absolute depth.
                        if S < t.min_s then
                            t.min_s = S
                            t.ms_pc = rs("PC"); t.ms_pb = rs("PB")
                            t.ms_fb = fbread() or 0
                        end
                        if S > t.max_s then t.max_s = S end
                        -- e = _fcc_fb-1-S: how far this push descends below the
                        -- live C frame base.  Only when a C frame base is set.
                        local fb = fbread()
                        if fb and fb ~= 0 then
                            local e = fb - 1 - S
                            if e >= 0 and e <= 0x4000 and e > t.max_e then
                                t.max_e = e
                                t.e_pc = rs("PC"); t.e_pb = rs("PB")
                                t.e_s = S; t.e_fb = fb; t.e_db = rs("DB")
                            end
                        end
                    end)
                emu.print_info("fgxdebug: stack_excursion tap installed")
            end
        end

        -- Fire scripted paste events. One char every N frames; use
        -- natural_keyboard:paste for each char since post_char didn't
        -- fire on IIgs. Paste() queues chars in MAME's own buffer which
        -- then drive the emulated keyboard at natural timing.
        if input_script_idx <= #input_script then
            local entry = input_script[input_script_idx]
            if frame_count >= entry.frame + script_offset and not entry.done then
                -- Snapshot prompt count once, on the FIRST paste.
                if prompt_sentinel and not prompt_snapshot then
                    prompt_snapshot = count_prompts()
                    emu.print_info(string.format(
                        "fgxdebug: prompt snapshot=%s before first paste",
                        tostring(prompt_snapshot)))
                end
                -- Try both `:post` and `:paste`.  On state-restored
                -- IIgs sessions, `:paste` sometimes gets eaten while
                -- `:post` still delivers characters.  Send both.
                -- (paste_mode config narrows this to one mechanism —
                -- the double-send is suspected of wedging the natural-
                -- keyboard buffer after the first delivery.)
                if nk then
                    -- Legacy natural-keyboard delivery (nk is nil on MAME
                    -- 0.288 -- the Lua property is gone; see the raw queue).
                    local ok_p1, ok_p2 = "skip", "skip"
                    if paste_mode == "both" or paste_mode == "post" then
                        ok_p1 = tostring(pcall(function()
                            if nk.post then nk:post(entry.text) end
                        end))
                    end
                    if paste_mode == "both" or paste_mode == "paste" then
                        ok_p2 = tostring(pcall(function()
                            if nk.paste then nk:paste(entry.text) end
                        end))
                    end
                    emu.print_info(string.format(
                        "fgxdebug: input @ frame %d: %q  (post=%s paste=%s)",
                        frame_count, entry.text, ok_p1, ok_p2))
                else
                    -- KEY-LATCH INJECTION: queue the bytes for the raw-inject
                    -- drainer, which writes `_kKbdInjectRaw' and lets the
                    -- heartbeat's own translation run.  LF -> CR (the shell and
                    -- the tools read CR).
                    --
                    -- IT USED TO WRITE `_kKbdRing' DIRECTLY, one byte per frame
                    -- while the ring read empty, and BOTH halves of that stop
                    -- working at apple/fgx#108 T6 increment 4b.  The line
                    -- discipline moves to ARRIVAL time there: the heartbeat
                    -- hands each key to `ttyinput' and a `read(2)' takes it
                    -- from the line's own `t_rawq'.  Nothing dequeues
                    -- `_kKbdRing' on such a session any more -- only the
                    -- SYS_GETKEY primitive does (apple/fgx#151) -- so a byte
                    -- written straight into the ring would never reach the
                    -- shell, AND the drainer's `count == 0' gate would never
                    -- reopen: one character delivered, then a stall, across the
                    -- 91 of 203 manifests that use `post_commands'.  It would
                    -- have presented as a mass kernel hang.
                    --
                    -- THE RAW DOOR REACHES BOTH QUEUES, because the heartbeat
                    -- feeds the discipline and the ring ("feed both").  It is also the more honest injection: the byte
                    -- arrives PRE-TRANSLATION through `@hb_kbdXlate', which is
                    -- where a real strobe arrives.
                    --
                    -- CTRL IS 0 HERE.  A `post_commands' string is ordinary
                    -- text; a test that needs a control key uses `raw_inject',
                    -- which carries the flag.  The only bytes that would differ
                    -- are $08/$0B/$15, which `@hb_kbdXlate' expands as vt100
                    -- arrows, and $0A -- and $0A cannot occur, being mapped to
                    -- $0D one line down.
                    for i = 1, #entry.text do
                        local c = entry.text:byte(i)
                        if c == 0x0A then c = 0x0D end
                        table.insert(raw_inject_queue, { key = c, ctrl = 0 })
                    end
                    emu.print_info(string.format(
                        "fgxdebug: input @ frame %d: %q  (key-latch inject, %d queued)",
                        frame_count, entry.text, #raw_inject_queue))
                end
                entry.done = true
                input_script_idx = input_script_idx + 1
            end
        end

        -- Prompt-count baseline at the autoboot paste moment (the primary
        -- command no longer flows through input_script, so the old
        -- first-paste snapshot hook doesn't fire for it).
        if prompt_sentinel and not prompt_snapshot
                and prompt_snapshot_frame
                and frame_count >= prompt_snapshot_frame then
            prompt_snapshot = count_prompts()
            emu.print_info(string.format(
                "fgxdebug: prompt snapshot=%s at autoboot frame",
                tostring(prompt_snapshot)))
        end

        -- THE KBD-RING DRAINER STOOD HERE and goes with T6 increment 4b, for
        -- the reasons the injection site above spells out.  `post_commands'
        -- uses the RAW door now, which is the same door a real key comes
        -- through.

        -- Frame-scheduled region sampling: capture any region carrying a
        -- sample_frame the first frame at or after it, and remember the bytes.
        -- Regions without sample_frame are untouched and still read at dump
        -- time.  Resolving the kernel bank here (rather than reusing do_dump's
        -- local helper) keeps the capture self-contained.
        for _, r in ipairs(memory_regions) do
            if r.sample_frame and not r.sampled_hex
               and frame_count >= r.sample_frame and mem then
                -- THE SAME RESOLVER THE DUMP USES (apple/fgx#236).  This
                -- loop used to carry its own copy, and that copy knew about
                -- `ptr' and `kbank' only -- so a ttybank, farbank, conbank,
                -- vcbank or modbank region that also named a frame was sampled
                -- from a bare 16-bit offset, which is BANK 0, and reported a
                -- plausible body with no hint it had done so.
                local raddr = region_addr(r)
                if not ((r.ptr or r.vcbank or r.modbank) and raddr == 0) then
                    r.sampled_hex = read_region(raddr, r.len)
                    r.sampled_addr = raddr
                    r.sampled_at = frame_count
                    emu.print_info(string.format(
                        "fgxdebug: sampled region %s @ frame %d addr %06X = %s",
                        r.name, frame_count, raddr, r.sampled_hex))
                end
            end
        end

        -- Promote frame-due raw_script entries into the raw queue.
        while raw_script_idx <= #raw_script
              and frame_count >= raw_script[raw_script_idx].frame do
            local e = raw_script[raw_script_idx]
            table.insert(raw_inject_queue, { key = e.key, ctrl = e.ctrl })
            raw_script_idx = raw_script_idx + 1
        end
        -- Raw-inject drainer: write one pre-translation byte to _kKbdInjectRaw
        -- only when the cell reads back 0 (heartbeat has consumed the prior
        -- one).  16-bit LE: lo = key, hi = ctrl flag (bit 8 of the word).
        if #raw_inject_queue > 0 and mem then
            local okm, magic = pcall(function() return mem:read_u8(0x00032D) end)
            local kb = 0x02
            if okm and magic == 0x4B then
                local okb, b = pcall(function() return mem:read_u8(0x00032C) end)
                if okb and type(b) == "number" and b > 0 then kb = b end
            end
            local base = kb * 65536
            local ok_r, cur = pcall(function()
                return mem:read_u8(base + KBD_INJECT_RAW) end)
            local ok_h, hi = pcall(function()
                return mem:read_u8(base + KBD_INJECT_RAW + 1) end)
            if ok_r and ok_h and cur == 0 and hi == 0 then
                local e = table.remove(raw_inject_queue, 1)
                pcall(function()
                    -- MODIFIER BYTE FIRST, KEY BYTE SECOND.  The kernel polls
                    -- the 16-bit word and acts the moment it is non-zero, and
                    -- the LOW byte is what makes it non-zero.  Writing the key
                    -- first leaves a window in which the heartbeat samples a
                    -- key with no modifier -- which is exactly how slice D's
                    -- alt-N arrived as a bare '2' and never switched.
                    mem:write_u8(base + KBD_INJECT_RAW + 1, e.ctrl % 256)
                    mem:write_u8(base + KBD_INJECT_RAW, e.key)
                end)
                emu.print_info(string.format(
                    "fgxdebug: raw-inject key=%d ctrl=%d @ frame %d (%d left)",
                    e.key, e.ctrl, frame_count, #raw_inject_queue))
            end
        end

        -- PC-sampler: arm once the command has been DELIVERED, then histogram
        -- the program counter per frame.  Delivery means BOTH that every
        -- scripted input has fired AND that the autoboot paste frame has
        -- passed: the autoboot path sends the primary command through MAME's
        -- -autoboot_command and leaves input_script empty, so the script test
        -- alone is satisfied on frame 1 and the entire boot lands in the
        -- histogram and in wall_s.
        if pc_sample_out then
            if not pc_armed and input_script_idx > #input_script
               and frame_count >= paste_frame then
                pc_armed = true
                pc_t0 = emu.time and emu.time() or nil
                emu.print_info("fgxdebug: pc-sampler armed @ frame " .. frame_count)
                pc_start_sampler()
            end
            -- The coroutine takes the samples; this arm runs only when it
            -- could not start.
            if pc_armed and pc_per_frame then pc_take_sample() end
        end

        -- fbench: arm the cycle taps once the bench command has been sent (so
        -- boot-time writes to the marker addrs aren't mistaken for START), then
        -- write the timing result and exit when the DONE marker fires.
        if cyc_start_addr then
            if not cyc_armed and input_script_idx > #input_script
               and frame_count >= paste_frame then
                cyc_armed = true
            end
            if cyc_done_t and not cyc_written then
                cyc_written = true
                local f = io.open(cyc_out_path, "w")
                if f then
                    f:write(string.format(
                        '{"start_t": %.9f, "done_t": %.9f, "delta_s": %.9f}\n',
                        cyc_start_t, cyc_done_t, cyc_done_t - cyc_start_t))
                    f:close()
                end
                emu.print_info(string.format(
                    "fgxdebug: FBENCH-CYC delta_s=%.9f -> %s",
                    cyc_done_t - cyc_start_t, tostring(cyc_out_path)))
                if not exit_pending then request_exit() end
            end
        end

        -- Prompt-count exit: poll charbuf every 12 frames (~5 Hz)
        -- after all pastes have fired.  Cheap enough not to bother
        -- with deeper instrumentation.
        if prompt_sentinel and prompt_snapshot
                and input_script_idx > #input_script
                and frame_count % 12 == 0
                and not exit_pending then
            local cur = count_prompts()
            -- A snapshot of 0 means the shell's FIRST prompt hadn't been
            -- printed yet at the paste frame (slow boot).  That first prompt
            -- is the command's OWN prompt, not its completion — treat it as
            -- the baseline, never the exit trigger.
            if cur and cur >= math.max(prompt_snapshot, 1) + prompt_target_delta then
                emu.print_info(string.format(
                    "fgxdebug: prompt-exit @ frame %d (count %d -> %d, delta %d)",
                    frame_count, prompt_snapshot, cur,
                    cur - prompt_snapshot))
                request_exit()
            end
        end

        -- Poll exit-marker.  Only check after all scripted inputs have
        -- fired so we don't exit during the boot wait.
        if exit_marker and not exit_marker.done and
           input_script_idx > #input_script then
            local ok, v = pcall(function() return mem:read_u8(exit_marker.addr) end)
            if ok and v == exit_marker.byte_eq then
                exit_marker.done = true
                emu.print_info(string.format(
                    "fgxdebug: exit-marker hit @ frame %d (mem[%d]=%d)",
                    frame_count, exit_marker.addr, v))
                request_exit()
            end
        end

        -- Hard frame cap.
        if exit_after_frame and frame_count >= exit_after_frame and
           not exit_pending then
            emu.print_info("fgxdebug: exit_after_frame reached @ " .. frame_count)
            request_exit()
        end

        if frame_count % dump_frame == 0 then
            do_dump()
        end

        -- Honour pending exit a few frames after the save kicked off.
        if exit_pending and exit_at_frame and frame_count >= exit_at_frame then
            do_dump()
            pcall(function() manager.machine:exit() end)
        end
    end)
end

return exports
