# The Good Store: Railway setup

The application consists of a Java server and a MySQL database. The Java server also serves the HTML and CSS pages. Use the root `Dockerfile` as the application's build file.

1. Create a Railway project and add a MySQL service.
2. Add this project as a separate service, using the repository root as its source. Railway needs the root `Dockerfile` and both page folders.
3. In the application service, set the environment variables `MYSQLHOST`, `MYSQLPORT`, `MYSQLDATABASE`, `MYSQLUSER`, and `MYSQLPASSWORD` to references to the matching variables from the MySQL service. Do not put passwords in source files or commit them to Git.
4. Generate a public domain for the application service. Open the application URL; do not open the HTML files directly.
5. Use **Shop owner** and **New shop? Create an account** to create a shop account. Use a unique email and a password of at least ten characters.

The server creates its `gs_` tables at startup. Food photos are stored in MySQL, so they survive application restarts. Booking creation checks the deadline and available stock in a database transaction. Owner data is restricted by the signed-in shop in the Java API.

The customer booking history is tied to the current browser session. It will not follow a customer to another browser or device, and a server restart may end the session. Existing browser-only demo data is not migrated automatically.

For local development, install Java 21 or newer and Maven, create a MySQL database, set the same five environment variables locally, then run `mvn spring-boot:run` from `backend`. Visit `http://localhost:8080/`. Do not commit credentials.

This implementation needs end-to-end testing with a running MySQL database and review before accepting real customer data.
