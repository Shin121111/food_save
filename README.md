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
| Start the store | Double-click **`start.cmd`**. The first time, it asks for the MySQL password. The browser opens at http://localhost:8080/. |
| Check that everything works | While the store runs, double-click **`check.cmd`**. Each step shows PASS or FAIL. |
| Stop the store | Press `Ctrl+C` in the `start.cmd` window, or close it. |
| See your HTML, CSS, JS or Java change | Stop the store, then start it again. A browser refresh alone is not enough. |
| Fix "Unknown column" or "Table doesn't exist" | Stop the store, double-click **`reset-db.cmd`**, then start again. This deletes local test data only. |

Always open the store at **http://localhost:8080/**. If you double-click an HTML file, the page cannot reach the server and shows no food.

### When something goes wrong

`start.cmd` checks Java, MySQL and the password before it starts, and it prints how to fix each problem it finds. If you are still stuck:

1. Run `check.cmd` (if the store started).
2. Copy all the text from both windows.
3. Paste it to Codex (or your teacher) and say what you clicked.

| Message | Meaning | Fix |
|---|---|---|
| `Java is not installed` | Java is missing, or the window was opened before Java was installed | Install Java (step 1), close all terminals, try again |
| `MySQL is not running` | The MySQL service is stopped | Windows key, type **Services**, find **MySQL84**, right-click, **Start** |
| `Wrong MySQL password` | The saved password is wrong | Run `start.cmd` again; it asks again |
| `Port 8080 is busy` | The store is already open in another window | Close the other window |
| `Unknown column` | The tables are older than the code | `reset-db.cmd` |

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
