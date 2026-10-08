# quick_blue_windows

The Windows WinRT implementation of the `quick_blue` federated Flutter plugin.

Follow the main package's
[Git installation instructions](https://github.com/prefanatic/quick_blue/blob/master/quick_blue/README.md#install)
to use this implementation from the fork.

See the [QuickBlue repository](https://github.com/prefanatic/quick_blue) for
usage, platform setup, and development documentation.

## Platform behaviour

| Capability | Windows behaviour |
| --- | --- |
| Scanning | Supported, including service-data and manufacturer-data scan filters plus `WindowsSignalStrengthFilter` tuning through `WindowsScanOptions`. |
| Connect / disconnect | Supported, with one GATT session shared across Flutter engines. |
| Discovery, read, write, notifications | Supported. |
| MTU | Reported as `readNegotiated`: `requestMtu` returns the negotiated session value rather than requesting a specific MTU. |
| Bonding | Unsupported (`capabilities().supportsPairing` is false). |
| L2CAP sockets | Unsupported. |
| Companion association | Unsupported. |

## Requirements

- Windows 10 1809 or later with a working BLE adapter.
- Visual Studio with the C++ desktop workload, plus C++/WinRT. The CMake build
  resolves the WinRT package through `nuget.exe`, which must be on `PATH`.

## Smoke test

Hardware-backed BLE verification runs inside a Dockur Windows VM:

```sh
QUICK_BLUE_WINDOWS_USB_VENDOR_ID=0x0bda \
QUICK_BLUE_WINDOWS_USB_PRODUCT_ID=0x8771 \
  scripts/windows-integration-test.sh
```

The VM state persists under `.dart_tool/dockur_windows/`; see the repository
`AGENTS.md` for the guest worktree refresh and VM reset options.
