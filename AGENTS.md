# Notes for coding agents

The developer is a beginner on Windows. Explain in short, plain steps.

## Project map

- `backend/src/main/java/com/goodstore/StoreController.java`: every `/api/...` endpoint. SQL is written by hand with `JdbcTemplate` (no JPA).
- `backend/src/main/resources/schema.sql`: the only schema. It runs on every start (`spring.sql.init.mode=always`).
- `backend/src/main/resources/application.properties`: database settings from `MYSQLHOST`, `MYSQLPORT`, `MYSQLDATABASE`, `MYSQLUSER`, `MYSQLPASSWORD`. On this computer the password comes from `backend/local.properties` (Git ignores it; `start.cmd` writes it). Never print or commit that file.
- `user/`: customer pages. `Shop owner log in screen/`: owner pages. Maven copies both into the jar, so after a page change you must restart the server.
- `scripts/server.ps1`: start, stop, status and logs for the local server. `scripts/check.ps1`: end-to-end self-test. `scripts/reset-db.ps1`: rebuild local tables. The `.cmd` files in the root only call these.

## Run the server and test your change

Always use these commands. They end by themselves and print a clear result.

```
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\server.ps1 start -NoBrowser
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\check.ps1
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\server.ps1 logs
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\server.ps1 stop
```

- **Run `server.ps1 start` and `check.ps1` outside the sandbox** (ask for approval / escalated permissions). Inside the Windows sandbox, background processes stop when the command ends, and the developer's browser cannot reach the server. Outside the sandbox, the server keeps running at http://localhost:8080/ and the developer can open it in any browser.
- `server.ps1 start` stops the old server, builds (compile errors show in its output), starts the new jar in the background, and waits until `/api/health` answers. Exit code 0 means the server runs.
- Do **not** run `mvnw spring-boot:run` or `java -jar` yourself. They never end, and the server dies with your command.
- If `start` says the MySQL password is not saved yet, ask the developer to double-click `start.cmd` once. Do not ask for the password in chat.
- After the change, tell the developer what to open at http://localhost:8080/ and what they should see.

If you cannot run commands outside the sandbox at all, write the code, compile it (`cd backend; .\mvnw.cmd -q -DskipTests package`), and give the developer a short **How to test** list: double-click `start.cmd`, then open the page and do X, then double-click `check.cmd`.

## Database rules

- `schema.sql` uses `CREATE TABLE IF NOT EXISTS`. A change to an existing table (new column) does **not** reach a database that already exists. Locally: tell the developer to double-click `reset-db.cmd` (it asks for YES; never run it without the developer). For Railway data, write a separate `ALTER TABLE` and explain it; never reset production.
- Keep the `gs_` table prefix.
- Always use `?` parameters in SQL. Never build SQL from user input with string concatenation.
- Never write passwords into tracked files.

## Common errors

`server.ps1 start` detects these in `backend/logs/server.log` and prints the fix.

| Error text | Cause | Fix |
|---|---|---|
| `Access denied for user 'root'` | wrong saved password | developer double-clicks `start.cmd` (it asks again) |
| `Communications link failure` | MySQL service stopped, or the sandbox blocks it | start **MySQL84** in Windows Services; run outside the sandbox |
| `Could not transfer artifact` / `Unknown host` | no network for Maven | run outside the sandbox, or check the internet |
| `Unknown column` / `Table ... doesn't exist` | tables older than `schema.sql` | developer runs `reset-db.cmd` |
| page shows no food, console shows `fetch` errors | HTML opened as a file | open http://localhost:8080/ |

## Change checklist

- Changed an endpoint? Update the page's `fetch(...)` call, and update `scripts/check.ps1` if the flow it tests changed.
- Keep `scripts/*.ps1` ASCII only. Windows PowerShell 5.1 misreads other characters.
