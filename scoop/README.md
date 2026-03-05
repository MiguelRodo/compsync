# Scoop Installation (Windows)

Install `compsync` via [Scoop](https://scoop.sh):

```powershell
scoop bucket add compsync https://github.com/MiguelRodo/compsync
scoop install compsync
```

Or install directly from the manifest:

```powershell
scoop install scoop/compsync.json
```

## Requirements

- [Scoop](https://scoop.sh)
- [Git for Windows](https://git-scm.com/download/win) (provides `bash.exe`)
- [Python 3](https://www.python.org/downloads/)

## Usage

```powershell
compsync update
compsync --help
```
