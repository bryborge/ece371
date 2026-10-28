# ECE 371 in VSCode/VSCodium instead of Code Composer Studio

This guide sets up VSCodium (or VS Code) on Linux to do everything the
course's *CCS 20 BeagleBone Black Tutorial* does: build bare-metal ARM
assembly for the BeagleBone Black (AM3359, Cortex-A8), load it into DDR
through a Blackhawk/TI **XDS100v2** JTAG probe, and inspect registers, CPSR,
disassembly and memory.

The CCS pieces map onto open tools like this:

| CCS 20                                   | Here                                                    |
| ---------------------------------------- | ------------------------------------------------------- |
| BeagleBone Toolbox project wizard        | A lab folder with `main.S`, `AM335x.lds`, `Makefile`    |
| GNU v15.3.1 toolchain, Build (Ctrl+B)    | `arm-none-eabi-gcc` via `make`, the **build** task      |
| `-Wa,-adhlns=...` listing                | Same flag in the Makefile, so `build/<lab>.lst`         |
| XDS100v2 driver + `.ccxml`               | OpenOCD + `common/bbb-xds100v2.cfg`                      |
| `beagleboneblack.gel` (clocks, DDR3)     | `bbb_init` in `common/bbb-xds100v2.cfg`, ported from it  |
| Debug Project (F5)                       | Cortex-Debug launch config, F5                          |
| Registers / Disassembly / Memory views   | Cortex-Debug + VS Code's built-in views                 |

## 1. Install the tools

Debian/Ubuntu package names; versions tested are in parentheses.

```sh
sudo apt install gcc-arm-none-eabi binutils-arm-none-eabi \
                 gdb-multiarch openocd make
```

- `arm-none-eabi-gcc` (14.2.1). The course uses 15.3.1; nothing in the labs
  so far depends on the difference.
- `gdb-multiarch` (Debian no longer ships `arm-none-eabi-gdb`).
- `openocd` (0.12.0). Its package installs `/lib/udev/rules.d/60-openocd.rules`,
  which already lets your logged-in user open the XDS100v2 (USB ID
  `0403:a6d0`). If OpenOCD later says it cannot open the device, check that
  rule exists, then replug the probe.

## 2. Install the extensions

Both are on Open VSX, so VSCodium installs them directly. Use the profile you
work in (`codium --list-extensions --profile "<name>"` shows what it has):

```sh
codium --profile "<profile name>" --install-extension marus25.cortex-debug
codium --profile "<profile name>" --install-extension dan-c-underwood.arm
```

- **Cortex-Debug** (`marus25.cortex-debug`) drives OpenOCD and GDB. It
  installs four companions (`mcu-debug.memory-view`, `peripheral-viewer`,
  `rtos-views`, `debug-tracker-vscode`). Only the memory view matters here,
  but the others are hard dependencies, so leave them.
- **ARM** (`dan-c-underwood.arm`) gives syntax highlighting for `.s`/`.S`.

`.vscode/extensions.json` lists both, so opening the folder prompts for them.

Cortex-Debug is written for Cortex-M, but it only needs an OpenOCD GDB
server, so it works for the A8 once its default launch sequence is
overridden (see §4).

## 3. The repository layout

```
ece371/                      open this folder in VSCodium
├── .vscode/
│   ├── tasks.json           build / clean the focused lab
│   ├── launch.json          debug the focused lab on the board
│   └── extensions.json
├── common/
│   ├── bbb-xds100v2.cfg     OpenOCD: probe, AM335x, GEL port
│   └── xds100v2-clear-power-loss.cfg   run before it (§4)
├── docs/
└── Lab0_ArrayMultiply/
    ├── main.S
    ├── AM335x.lds           the course template's, unmodified
    └── Makefile             produces build/Lab0_ArrayMultiply.{elf,lst,map}
```

**One rule ties it together:** the tasks and the launch config act on the
lab whose file is focused in the editor (CCS's "active project"), and the
debugger expects `build/<lab folder name>.elf`. So each lab's Makefile must
set `PROJ` to the folder's name.

To start a new lab, copy `Lab0_ArrayMultiply/`, rename the folder, set
`PROJ` in its Makefile to the new name, and replace `main.S`.

The Makefile covers what the tutorial sets in CCS's Project Properties:

- `-nostdlib` covers the tutorial's `-nostartfiles` and also drops
  libc/libgcc, which pure assembly never calls.
- `-Wa,-adhlns=build/$(PROJ).lst` writes the listing file (tutorial §5,
  Step 13).
- `--defsym=STACKSIZE=0x1C000 --defsym=HEAPSIZE=0x400` size the stack and
  heap, which the linker script leaves to the build. The values come from
  the wizard's project settings.

`AM335x.lds` is copied unchanged from the professor's BeagleBone Toolbox
(`ccs20extensions/ccs20-bbb-wizard/template/AM335x.lds`, TI's sample
script). Using the course's copy means every address matches the tutorial,
SP included. It also has the `.bss`, heap and init-array sections that the
later C labs need.

## 4. How debugging works, and why

### The GEL script, ported

CCS doesn't load straight into DDR. On connect, its target configuration
runs TI's `beagleboneblack.gel` v1.5, which:

1. resets and halts the core, and disables the watchdog,
2. relocks all five DPLLs for OPP100 (MPU 600 MHz, DDR 400 MHz),
3. enables the EMIF and calibrates VTP, then programs the DDR PHY and the
   DDR3 timings,
4. puts the core in ARM state, Supervisor mode, MMU off.

DDR at `0x80000000` doesn't exist until step 3 has run, so OpenOCD has to do
the same work. `common/bbb-xds100v2.cfg` defines `bbb_init`, a line-for-line
port of those GEL functions, which the launch runs with `monitor bbb_init`.
The GEL file comes with any CCS install, at
`ccs/ccs_base/emulation/boards/beaglebone/gel/beagleboneblack.gel`. The
course's `.ccxml` (in the professor's toolbox) points the Cortex-A8 at
exactly this file.

The port deliberately differs from the GEL in three places:

- **No reset.** The GEL resets the chip before halting it. Through the
  XDS100v2, OpenOCD's stock BeagleBone Black reset (TRST + SRST) takes the
  A8's debug logic down along with the core. OpenOCD then can't halt the
  core in time, the halt times out, and the init never runs. So `bbb_init`
  just halts. On a board fresh from an S2 boot, that halts the boot ROM's
  idle loop. Over a previous session's program, it halts that program. Both
  cases were tested: re-running the init while DDR is live works.

- The GEL busy-waits forever on PLL-lock, VTP and EMIF status bits. Here
  each wait times out with an error that names the register.
- The GEL prints a warning and carries on if the board's input clock isn't
  24 MHz, and it only reports whether the DDR PHY came up. Here both are
  errors, because nothing after them can work.

**How the port was verified.** The relevant GEL functions were compiled as C,
with their register reads and writes redirected to a simulated register file
(registers seeded with junk values, PLL status bits that follow the
CLKMODE writes). The same simulation was run on the Tcl procs inside
OpenOCD's own Tcl interpreter. Both produce the same 62 register writes,
with the same values in the same order. A deliberately wrong PHY ratio
shows up as a diff, so the test can fail.

### The XDS100v2 quirk

The probe's CPLD sets a "power-loss" flag whenever the board loses power.
While the flag is set, it holds every JTAG pin high-Z, and only a rising
edge on its `PWR_RST` line clears it. OpenOCD's
`interface/ftdi/xds100v2.cfg` suggests ending your config with
`init; ftdi set_signal PWR_RST 1; jtag arp_init`. On the AM335x, that
crashes OpenOCD the first time after every power-up:

1. The first scan (during `init`) reads all ones, so OpenOCD skips the
   ICEPick setup that enables the A8's TAP. It also skips initializing that
   TAP's debug port (DAP), because the TAP is disabled.
2. `jtag arp_init` then enables the TAP, and OpenOCD immediately examines
   the A8 through the DAP it never initialized:
   `Assertion 'ap->dap->ops' failed`.

The flag is a latch, so the fix is to clear it in a separate, earlier run.
`common/xds100v2-clear-power-loss.cfg` opens the probe, pulses `PWR_RST`,
and exits. The **prepare debug** task runs it after **build** and before
every launch, so OpenOCD's first scan always succeeds. Running it when the
flag is already clear does nothing.

### The launch sequence

By default, Cortex-Debug runs `reset halt`, `load`, `reset halt`. That's
right for a Cortex-M running from flash, but resetting this board loses the
debugger (see above). So `launch.json` overrides it with:

```
monitor bbb_init                    # halt + the GEL's work
maintenance flush register-cache    # GDB's cached registers predate bbb_init
monitor arm semihosting enable      # service svc 0x123456 (see below)
load                                # write the ELF into DDR; GDB sets PC = _start
```

The session then stops at `_start` (line 39), as CCS does. The debug
toolbar's **Restart** re-runs the init and the load (everything except the
semihosting line), so it starts from a freshly loaded state. CCS's Restart
only moves the PC.

GDB caches register values. Anything that changes the target behind GDB's
back, such as a `monitor` command, leaves stale values in that cache. Before
the flush was added, GDB showed the boot ROM's Thumb-state CPSR after
`bbb_init` had already switched the core to ARM state. If you ever run
`monitor` commands by hand, follow them with
`maintenance flush register-cache` (`flushregs` for short).

### Semihosting

The course's starter Assembly template prints with `svc 0x123456`, and
its C templates link `rdimon.specs`. Both rely on ARM semihosting: the
debugger catches the SVC, does the I/O on the host, and resumes the
program. CCS enables this with a setting in its launch config; here it's
`monitor arm semihosting enable`.

In OpenOCD 0.12, that command sets the SVC bit in the Cortex-A8's vector
catch register. When the core halts, OpenOCD treats it as a semihosting
call only if the core is in SVC mode, the PC is at `VBAR + 0x08`, and the
instruction at `lr - 4` is `svc 0x123456`. Because the check reads VBAR, it
still works when `main.S` moves the vector table to `0x80000000`. The
output goes to OpenOCD's console, which Cortex-Debug shows in its
gdb-server terminal tab.

Lab 0 never calls `svc`, so for Lab 0 this changes nothing.

## 5. Daily workflow

1. **Boot the board in bare-metal mode** (tutorial §2): hold **S2**, apply
   power, keep holding about 3 s. Only the PWR LED should be lit. If the USR
   LEDs blink, Linux booted: shut it down with S3, then retry.
2. Plug the XDS100v2 into the PC. `lsusb` should show `0403:a6d0`.
3. Open `ece371/` in VSCodium and focus the lab's `main.S`.
4. **Ctrl+Shift+B** builds. Assembler errors show up in Problems and are
   underlined in the editor.
5. **F5** builds, clears the probe's power-loss flag, starts OpenOCD, runs
   `bbb_init`, loads, and stops at `_start`. The **Debug Console** shows the `bbb_init:` progress lines,
   which play the role of the GEL Output tab.
6. Set breakpoints in the gutter, then use **Continue (F5)** and **Step
   Over (F10)**.
7. When you're done, shut down in the order below.

### Shutting down

This follows tutorial §6, Step 22, in the same order.

1. **Stop the debug session**: **Shift+F5**, or the Stop button on the debug
   toolbar. This also shuts down the OpenOCD that Cortex-Debug started. If
   you ran OpenOCD and GDB by hand, `quit` GDB (answer `y`) and press
   **Ctrl+C** in the OpenOCD terminal.
2. **Check that nothing still holds the probe**:

   ```sh
   pgrep -a openocd || echo "no openocd running"
   ```

   If an `openocd` process is listed, the session didn't shut down cleanly.
   End it with `pkill openocd`.
3. **Remove the board's power** (its USB cable or 5 V supply). In
   bare-metal mode this is safe at any time, because only the boot ROM and
   your program are running and neither writes to the eMMC. If the USR LEDs
   are blinking, Linux is running instead: press **S3** once and wait for
   all the LEDs to go out before pulling power (tutorial §2), or you risk
   corrupting the eMMC.
4. **Unplug the XDS100v2's USB cable**, and the JTAG ribbon if you're
   packing up.

Pulling the probe in the middle of a session doesn't damage anything, but
the session dies with JTAG errors and may need the probe replugged. That's
why step 1 comes first. Powering the board off sets the probe's power-loss
flag, which the next F5 clears automatically (§4).

### Where the CCS views are

| Tutorial step                | Here                                                                 |
| ---------------------------- | -------------------------------------------------------------------- |
| Registers (Step 19)          | Run and Debug sidebar, **Variables > Registers**                      |
| CPSR flags (Step 19)         | Add Watch expressions, listed below                                   |
| Disassembly (Step 20)        | Right-click in the editor while halted: **Open Disassembly View**     |
| Memory (Step 21)             | Command Palette, "memory view"; or Debug Console: `x/4xw &PRODUCTS`  |
| Listing file (Step 13)       | `LabN/build/<lab>.lst`                                                |

GDB shows CPSR as a single word, without CCS's per-flag breakdown. These
Watch expressions give you the flags:

| Watch expression     | Field                   | Expected at the Lab 0 NOP |
| -------------------- | ----------------------- | ------------------------- |
| `($cpsr >> 31) & 1`  | N                       | 0                         |
| `($cpsr >> 30) & 1`  | Z                       | 1                         |
| `($cpsr >> 29) & 1`  | C                       | 1                         |
| `($cpsr >> 28) & 1`  | V                       | 0                         |
| `$cpsr & 0x1f`       | Mode (19 = 0x13 = SVC)  | 19                        |

The Debug Console passes what you type straight to GDB, so any GDB command
works there. For example, `x/8xh &MULTIPLICANDS` shows the input arrays in
array order, which is CCS's 16-bit memory format.

### Lab 0 expected values

Everything in the tutorial's tables (§4 and §6) applies unchanged:
`_start` at `0x80000040`, the NOP on line 61 at `0x80000080`, SP =
`0x8001C4D4`, R1–R8, and `PRODUCTS` = `01234321 048D0C84 0A3D5C29
12343210`.

## 6. Troubleshooting

| Symptom                                                       | Likely cause and fix                                                                                         |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `unable to open ftdi device with vid 0403, pid a6d0`          | Probe unplugged, or no udev permission. Check `lsusb`, the udev rule (§1), then replug.                       |
| `JTAG scan chain interrogation failed: all ones`              | From the clear-flag run: expected. From `bbb-xds100v2.cfg`: the flag wasn't cleared first, or the board is off. |
| OpenOCD aborts: `Assertion 'ap->dap->ops' failed`             | OpenOCD started without clearing the power-loss flag (§4). Run `xds100v2-clear-power-loss.cfg` first.         |
| `timed out while waiting for target halted` after a reset     | Don't use `monitor reset` or `reset init`; resetting loses the debugger (§4). Use `monitor bbb_init`.           |
| Registers in GDB don't match OpenOCD's halt message           | GDB's register cache is stale after a `monitor` command. Run `flushregs`.                                       |
| `bbb_init: timed out waiting for ...`                         | That PLL or PHY never reported ready. Power-cycle in bare-metal mode and retry; if it persists, note which.  |
| `bbb_init: SYSBOOT[15:14] = ..., expected 1`                  | The board doesn't report a 24 MHz crystal. Not a BeagleBone Black, or JTAG reads are failing.                 |
| F5 says the `.elf` doesn't exist                              | The focused file isn't in a lab folder, or `PROJ` in the Makefile doesn't match the folder name.             |
| Loads, but behaves strangely                                  | Linux booted (USR LEDs blinking). Boot with S2 held (§5, step 1).                                            |
| Probe errors after unplugging during a session                | Stop the session, replug the probe, start again.                                                             |

To debug OpenOCD by hand, without the editor:

```sh
openocd -f common/xds100v2-clear-power-loss.cfg     # terminal 1, exits
openocd -f common/bbb-xds100v2.cfg                  # terminal 1, stays up
gdb-multiarch Lab0_ArrayMultiply/build/Lab0_ArrayMultiply.elf \
  -ex 'target extended-remote :3333' \
  -ex 'monitor bbb_init' -ex flushregs -ex load     # terminal 2
```

## 7. Verification status

Verified on a BeagleBone Black and a TI XDS100v2 (Oct 2026, OpenOCD 0.12.0,
GDB 16.3, VSCodium 1.140):

- From a cold power-up in bare-metal mode, the clear-flag run followed by
  `bbb-xds100v2.cfg` gives one clean JTAG scan, with no sticky errors.
- `bbb_init` locks the PLLs and brings up DDR3, both from a fresh S2 boot
  and over a previous session's running program.
- Lab 0 loads, stops at `_start`, and hits the line 61 breakpoint. Every
  register, CPSR (`0x60000193`) and `PRODUCTS` match tutorial §6, both from
  the GDB command line and through F5 in VSCodium.

Verified without hardware:

- `bbb_init`'s register writes match the GEL's exactly (§4).
- The `as` error matcher catches assembler errors.
- OpenOCD 0.12's semihosting support for Cortex-A, by reading its source
  (`armv7a_setup_semihosting`, `arm_semihosting`).

**Not yet verified:**

- **Semihosting output.** It depends on two inferences: that the A8's
  vector catch fires at the relocated VBAR, and that Cortex-Debug shows the
  output in its gdb-server terminal. The starter Assembly template's print
  loop is the test.
- **A working reset.** For now there's no way to reset the board from the
  debugger. Power-cycle it with S2 held instead.
