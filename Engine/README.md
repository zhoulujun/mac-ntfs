# Engine

`ntfs-3g` sources are fetched by `Scripts/fetch-ntfs3g.sh` (pinned to the same
revision used by xntfs) and are **not** committed to git.

```bash
./Scripts/fetch-ntfs3g.sh
./Scripts/build-libntfs.sh
```

Output: `build/libntfs-universal/libntfs-3g.a` + `config.h`.
