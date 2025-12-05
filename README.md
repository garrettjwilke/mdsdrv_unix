# mdsdrv_unix

Build MDSDRV sound driver natively for UNIX (macOS or Linux) **without Wine**.

This project compiles the MDSDRV driver using native UNIX tools. The driver is built from source using native assemblers and compilers - no Wine or Windows emulation is required.

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
