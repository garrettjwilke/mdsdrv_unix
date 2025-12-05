# mdsdrv_unix

Build MDSDRV sound driver natively for UNIX (macOS or Linux) **without Wine**.

This project compiles the MDSDRV driver using native UNIX tools. The driver is built from source using native assemblers and compilers - no Wine or Windows emulation is required.

## Version Information

- **MDSDRV Version:** `MDSDRV0.6 230612`
- **MDSDRV Commit:** `fefc7178579c59505f860e292e76af4a1857c6eb`
- **mdsdrv.bin SHA256:** `34682d2b994409c3a3f0508bcf97c521c9b9873a6779e1f80b90755a16b1a617`

## Building

### Prerequisites

- `git` - for cloning repositories
- `make` - for building dependencies
- `cmake` - for building clownassembler

### Build Instructions

1. Run the build script:

```bash
./build.sh
```

This will:
- Clone or update the MDSDRV repository in the current directory
- Build all required dependencies (sjasmplus, salvador, clownassembler)
- Compile the MDSDRV driver natively
- Copy the final `mdsdrv.bin` file next to the build script

### Output Location

The resulting `mdsdrv.bin` file will be located in the project root directory (next to `build.sh`):

```
./mdsdrv.bin
```
