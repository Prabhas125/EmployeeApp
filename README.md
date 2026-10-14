# EmployeeApp

Employee Management CRUD (JSP + JDBC + MySQL) deployed on AWS (EC2 + Tomcat + Nginx + RDS).

## Files
- index.html - registration form
- register.jsp - insert / view / edit / update / delete

## Project structure

```text
EmployeeApp/
├── README.md
├── .gitignore
├── index.html
├── register.jsp
└── WEB-INF/
    └── lib/
        └── mysql-connector-j-<version>.jar   (not stored in Git)
```

## Setup note
Download MySQL Connector/J (mysql-connector-j-<version>.jar) and place it in WEB-INF/lib/.
The JAR is not stored in Git.

## Configuration
The database settings are read from environment variables, never from the code:

- DB_URL - for example jdbc:mysql://YOUR_RDS_ENDPOINT:3306/employeedb
- DB_USER
- DB_PASSWORD

Do not commit passwords, keys or endpoints to this repository.


Tech stack: JSP, Tomcat 9, Nginx, MySQL.
