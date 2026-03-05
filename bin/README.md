# bin/

Contains platform-specific executable wrappers for `compsync`.

| File | Platform | Description |
|------|----------|-------------|
| `compsync.ps1` | Windows | PowerShell wrapper — locates Git Bash and delegates to `scripts/compsync.sh` |

## Usage

After running `install.ps1` (which adds this directory to your `PATH`), you can call:

```powershell
compsync update
compsync --help
```

The script requires **Git for Windows** (which provides `bash.exe`) and **Python 3** to be installed.
