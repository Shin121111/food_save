# The Good Store

Shops post leftover food at a lower price. Customers reserve it and pick it up.

- **Pages** (HTML, CSS, JS): `user/` for customers, `Shop owner log in screen/` for shop owners
- **Server** (Java, Spring Boot): `backend/`
- **Database** (MySQL): the server creates the database and its tables by itself

## Run it on Windows

### One-time setup (about 15 minutes)

1. **Install Java 21.** Open PowerShell and run:
   ```
   winget install EclipseAdoptium.Temurin.21.JDK
   ```
   Then close every terminal window.
2. **Install MySQL.** Download "MySQL Community Server 8.4" (Windows MSI Installer) from
   https://dev.mysql.com/downloads/mysql/ and run it.
   - Config type: **Development Computer**
   - Set a **root password** and write it down. You need it once more.
   - Keep **Start the MySQL Server at System Startup** turned on.

You do not need to install Maven, and you do not need to write any SQL. The project brings its own Maven, and the server creates the `good_store` database and all tables on the first start.

### Every day

| What you want | Do this |
|---|---|
| Start the store | Double-click **`start.cmd`**. The first time, it asks for the MySQL password and saves it in `backend\local.properties` (Git ignores this file). The browser opens at http://localhost:8080/. The store keeps running after the window closes. |
| See your HTML, CSS, JS or Java change | Double-click **`start.cmd`** again. It stops the old server and starts the new code. A browser refresh alone is not enough. |
| Check that everything works | Double-click **`check.cmd`**. Each step shows PASS or FAIL. |
| Stop the store | Double-click **`stop.cmd`**. |
| Fix "Unknown column" or "Table doesn't exist" | Double-click **`reset-db.cmd`**, type YES, then `start.cmd`. This deletes local test data only. |

Always open the store at **http://localhost:8080/**. If you double-click an HTML file, the page cannot reach the server and shows no food.

### Let Codex start the server

Codex can start and test the server itself (see `AGENTS.md`). One time first:

1. Double-click `start.cmd` yourself once, so the MySQL password is saved.
2. In Codex, open this folder and mark the project as **trusted**.
3. When Codex asks to run `server.ps1 start` or `check.ps1` **outside the sandbox**, approve it. Inside the sandbox the server stops when the command ends, and your browser cannot open it.

After that, Codex's server runs at http://localhost:8080/ in any browser, the same as with `start.cmd`.

### When something goes wrong

`start.cmd` checks Java, MySQL and the password before it starts, and it prints how to fix each problem it finds. If you are still stuck:

1. Run `check.cmd`.
2. Copy all the text from both windows, and the end of `backend\logs\server.log`.
3. Paste it to Codex (or your teacher) and say what you clicked.

| Message | Meaning | Fix |
|---|---|---|
| `Java is not installed` | Java is missing, or the window was opened before Java was installed | Install Java (step 1), close all terminals and Codex, try again |
| `Cannot reach MySQL` / `MySQL is installed but not running` | The MySQL service is stopped | Windows key, type **Services**, find **MySQL84**, right-click, **Start** |
| `Wrong MySQL password` | The saved password is wrong | Run `start.cmd` again; it asks again |
| `Another program uses port 8080` | Some other app uses the port | Close it, then try again |
| `Old database tables` | The tables are older than the code | `reset-db.cmd` |

## Run it on Mac

```
brew install maven mysql
brew services start mysql
cd backend
mvn spring-boot:run
```

Brew's MySQL `root` user has no password, so no other setup is needed.

## Deploy

See [RAILWAY-SETUP.md](RAILWAY-SETUP.md).
