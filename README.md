# tcrun

`tcrun` provides a means to locate or invoke Swift development tools from the command-line on Windows, without requiring users to modify `Path` or take otherwise inconvenient measures to support multiple Swift toolchains.

## Description

`tcrun` automatically discovers Swift toolchain installations through the Windows registry and provides a unified interface for tool execution across different toolchain versions. It simplifies Swift development on Windows by handling toolchain and SDK management transparently.

The SDK defaults to the boot system OS SDK (`Windows.sdk`), and can be specified by the `SDKROOT` environment variable or the `-sdk` option (which takes precedence over `SDKROOT`).

## Synopsis

```bash
tcrun [-sdk SDK] -f <tool_name>
tcrun [-sdk SDK] <tool_name> [tool_arguments]
tcrun [-toolchain ID] <tool_name> [tool_arguments]
```

## Usage Patterns

**Find tool location**: The first usage returns the full path to the specified `tool_name`.

**Execute tool**: The second usage executes `tool_name` with the provided `tool_arguments`.

**Toolchain-specific execution**: The third usage executes the tool using a specific toolchain identifier.

## Options

| Option | Description |
|--------|-------------|
| `-f`, `-find` | Print the full path to the tool |
| `-r`, `-run` | Find the tool in the toolchain and execute it (default) |
| `-sdk SDK` | Specifies which SDK to use (overrides `SDKROOT` environment variable) |
| `-toolchain ID` | Use the specified toolchain identifier |
| `-toolchains` | List all available toolchains |
| `-show-sdk-path` | Print the path to the SDK |
| `-show-sdk-platform-path` | Print the path to the SDK platform |
| `-version` | Print the version of tcrun |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `SDKROOT` | Specifies the SDK to use; overridden by the `-sdk` option |
| `TOOLCHAINS` | Specifies the default toolchain to use; overridden by the `-toolchain` option |

## Examples

### Basic Usage

Find the Swift compiler:
```bash
tcrun -f swift
```

Execute the Swift compiler:
```bash
tcrun swift --version
```

Build with a specific SDK:
```bash
tcrun -sdk Windows.sdk swift build
```

### Toolchain Management

List available toolchains:
```bash
tcrun -toolchains
```

Use a specific toolchain:
```bash
tcrun -toolchain org.compnerd.dt.toolchain.20250623.0-asserts swift build
```

### SDK Information

Show SDK path:
```bash
tcrun -show-sdk-path
```

Show SDK platform path:
```bash
tcrun -show-sdk-platform-path
```
