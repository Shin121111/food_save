# Notes for coding agents

The developer is a beginner on Windows. Explain in short, plain steps, and always tell them exactly what to click or run to test your change.

## Project map

- `backend/src/main/java/com/goodstore/StoreController.java`: every `/api/...` endpoint. SQL is written by hand with `JdbcTemplate` (no JPA).
- `backend/src/main/resources/schema.sql`: the only schema. It runs on every start (`spring.sql.init.mode=always`).
- `backend/src/main/resources/application.properties`: database settings, read from `MYSQLHOST`, `MYSQLPORT`, `MYSQLDATABASE`, `MYSQLUSER`, `MYSQLPASSWORD`.
- `user/`: customer pages. `Shop owner log in screen/`: owner pages. Maven copies both into the jar as static files, so the server serves them at `http://localhost:8080/user/...`.
- `start.cmd`, `check.cmd`, `reset-db.cmd`: the developer's tools. The logic is in `scripts/*.ps1`.

## You probably cannot run MySQL here

If your sandbox has no MySQL server or no network, do not stop and say "I can't do database work". Do this:

1. Write the code and the SQL anyway.
2. If Java is available, check that it compiles: `cd backend && ./mvnw -q -DskipTests package` (Windows: `mvnw.cmd`).
3. End your answer with a short **How to test** list for the developer, for example:
   - Stop the store, then double-click `start.cmd`.
   - (Only if `schema.sql` changed) double-click `reset-db.cmd` first.
   - Open http://localhost:8080/ and do X. You should see Y.
   - Double-click `check.cmd`. All checks should pass.
4. When the developer pastes an error, find the first `Caused by:` or `[ERROR]` line and fix that.

## Database rules

- `schema.sql` uses `CREATE TABLE IF NOT EXISTS`. A change to an existing table (new column) does **not** reach a database that already exists. After such a change, tell the developer to run `reset-db.cmd`. For data on Railway, write a separate `ALTER TABLE` and explain it; do not reset production.
- Keep table names with the `gs_` prefix.
- Always use `?` parameters in SQL. Never build SQL with string concatenation from user input.
- Never write passwords into source files. Local and Railway passwords come from environment variables.

## Common errors

| Error text | Cause | Fix |
|---|---|---|
| `Access denied for user 'root'` | wrong `MYSQLPASSWORD` | run `start.cmd` again; it asks again |
| `Communications link failure` | MySQL service not running | start **MySQL84** in Windows Services |
| `Unknown column` / `Table ... doesn't exist` | tables older than `schema.sql` | `reset-db.cmd` |
| `Port 8080 was already in use` | the store is already running | close the other window |
| page shows no food, console shows `fetch` errors | HTML opened as a file | open http://localhost:8080/ |

## Change checklist

- Changed an endpoint? Update the page's `fetch(...)` call, and update `scripts/check.ps1` if the flow it tests changed.
- Keep `scripts/*.ps1` ASCII only. Windows PowerShell 5.1 misreads other characters.
