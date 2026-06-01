# 02 — VPS Safe-Zone Directory Structure

> WHO-217 · 建立 `/opt/edgar` 安全區，讓遠端編輯器可安全操作 repos，同時保護 runtime 狀態不被意外修改。

---

## 目錄總覽

| Path | Purpose | Owner | Mode |
|---|---|---|---|
| `/opt/edgar/repos` | Git repos — 主要編輯區 | `edgar` | `0755 + setgid` |
| `/opt/edgar/runtime` | Docker volumes / databases / state | `edgar` | `0750` |
| `/opt/edgar/backups` | 手動 / 排程備份 | `edgar` | `0750` |
| `/opt/edgar/logs` | 應用程式 & 服務 logs | `edgar` | `0755` |

---

## 權限策略

### repos (`0755`, setgid)

- **完整讀寫** — 這是唯一設計給 WinSCP、VSCode Remote、Codex Remote 直接操作的路徑。
- `setgid` 確保新建檔案繼承群組，多個 remote session 不會產生權限衝突。
- 所有 git clone / pull / push 操作都在這裡進行。

### runtime (`0750`)

- **不作為 Windows 掛載主目標。**
- 存放 Docker compose state、volume mounts、SQLite / PostgreSQL data 等。
- 只允許 `edgar` 使用者與同群組成員存取；其他使用者無法讀取。
- 目錄內有 `.no-visual-edit` marker 檔案，供 mount script 或編輯器外掛判斷「此路徑不應被設為主要編輯目標」。

### backups (`0750`)

- 存放 cron job 或手動觸發的備份檔（tar、database dump 等）。
- 可透過 WinSCP 下載，但不建議直接在此目錄編輯。

### logs (`0755`)

- 存放應用程式 log、service output、部署紀錄。
- 可透過 WinSCP / VSCode Remote **唯讀瀏覽**，方便 debug。

---

## 視覺化操作對照表

| Tool | repos | runtime | backups | logs |
|---|---|---|---|---|
| **WinSCP** | read/write | view only | download only | read only |
| **VSCode Remote** | read/write | view only | download only | read only |
| **Codex Remote** | read/write | view only | — | read only |
| **SSH terminal** | full | full | full | full |

> **原則：** 只有 `repos` 是設計給視覺化編輯器「直接修改檔案」的安全區。
> 其他路徑可以瀏覽、下載，但不應作為主要掛載 / 編輯目標。

---

## 安全規則

1. **不掃 secrets** — 此目錄結構本身不包含 secret 管理機制。Secret 由 Doppler / Vault / `.env` 等外部工具管理，不在此範圍內。
2. **不清理整台 VPS** — `init-vps-dirs.sh` 只建立 `/opt/edgar` 底下的目錄，不會移動、刪除或影響系統其他位置的檔案。
3. **冪等設計** — script 可重複執行，不會覆蓋已存在的檔案內容。

---

## 初始化

```bash
sudo ./scripts/init-vps-dirs.sh
```

如果 VPS 上的使用者名稱不是 `edgar`，可用環境變數覆寫：

```bash
sudo VPS_USER=myuser ./scripts/init-vps-dirs.sh
```

---

## 相關文件

- [01 — Connection Config](./01-connection-config.md) (WHO-216)
