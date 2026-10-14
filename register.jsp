<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.math.BigDecimal" %>
<%@ page import="java.math.RoundingMode" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Employee Management</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 30px; background-color: #f4f4f9; }
        .msg { padding: 12px; margin-bottom: 20px; border-radius: 4px; font-weight: bold; text-align: center; }
        .success { background-color: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .error { background-color: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
        table { width: 100%; border-collapse: collapse; background: white; margin-top: 15px; }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
        th { background-color: #007bff; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .btn { padding: 6px 12px; text-decoration: none; border-radius: 4px; color: white; font-size: 14px; margin-right: 5px; border: none; cursor: pointer; font-family: inherit; }
        .btn-edit { background-color: #ffc107; color: black; }
        .btn-delete { background-color: #dc3545; }
        .btn-view { background-color: #17a2b8; padding: 10px 15px; font-size: 16px; display: inline-block; margin-bottom: 15px; }
        .btn-home { background-color: #6c757d; padding: 10px 15px; font-size: 16px; display: inline-block; }
        .inline-form { display: inline; margin: 0; }
        .form-container { width: 350px; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        .form-group { margin-bottom: 10px; }
        .form-group label { display: block; font-weight: bold; }
        .form-group input, .form-group select { width: 100%; padding: 8px; box-sizing: border-box; }
    </style>
</head>
<body>

<%!
    // Database connection: configuration comes from environment variables
    // set for the Tomcat process (see /opt/tomcat/bin/setenv.sh).
    // Nothing sensitive is hard-coded in this file.
    private Connection getConnection() throws Exception {
        String url  = System.getenv("DB_URL");
        String user = System.getenv("DB_USER");
        String pass = System.getenv("DB_PASSWORD");

        if (url == null || url.trim().isEmpty()) {
            throw new IllegalStateException("Environment variable DB_URL is not set");
        }
        if (user == null || user.trim().isEmpty()) {
            throw new IllegalStateException("Environment variable DB_USER is not set");
        }
        if (pass == null) {
            throw new IllegalStateException("Environment variable DB_PASSWORD is not set");
        }

        Class.forName("com.mysql.cj.jdbc.Driver");
        return DriverManager.getConnection(url, user, pass);
    }

    // Helper: escape text before writing it into HTML (prevents XSS)
    private static String esc(String s) {
        if (s == null) { return ""; }
        StringBuilder sb = new StringBuilder(s.length() + 16);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '&':  sb.append("&amp;");  break;
                case '<':  sb.append("&lt;");   break;
                case '>':  sb.append("&gt;");   break;
                case '"':  sb.append("&quot;"); break;
                case '\'': sb.append("&#x27;"); break;
                default:   sb.append(c);
            }
        }
        return sb.toString();
    }

    // Helper: trim a request parameter; never returns null
    private static String clean(String s) {
        return (s == null) ? "" : s.trim();
    }

    // Helper: parse a whole number, return null if invalid
    private static Integer parseIntSafe(String s) {
        try {
            return Integer.valueOf(s.trim());
        } catch (Exception e) {
            return null;
        }
    }

    // Helper: parse salary into BigDecimal (0 .. 99999999.99, max 2 decimals), null if invalid
    private static BigDecimal parseSalary(String s) {
        try {
            BigDecimal v = new BigDecimal(s.trim());
            if (v.signum() < 0) { return null; }
            if (v.stripTrailingZeros().scale() > 2) { return null; }
            if (v.compareTo(new BigDecimal("99999999.99")) > 0) { return null; }
            return v.setScale(2, RoundingMode.HALF_UP);
        } catch (Exception e) {
            return null;
        }
    }

    // Server-side validation. Returns an error message or null if OK.
    private static String validateEmployee(String eid, String ename, String esalary,
                                           String egender, String eage, String eaddress) {
        Integer id = parseIntSafe(eid);
        if (id == null || id.intValue() <= 0) {
            return "Employee ID must be a positive whole number.";
        }
        if (ename.isEmpty() || ename.length() > 50) {
            return "Name is required and must be at most 50 characters.";
        }
        if (parseSalary(esalary) == null) {
            return "Salary must be a number from 0 to 99999999.99 with at most 2 decimal places.";
        }
        if (!("M".equals(egender) || "F".equals(egender) || "O".equals(egender))) {
            return "Gender must be M, F or O.";
        }
        Integer age = parseIntSafe(eage);
        if (age == null || age.intValue() < 18 || age.intValue() > 100) {
            return "Age must be a whole number between 18 and 100.";
        }
        if (eaddress.isEmpty() || eaddress.length() > 100) {
            return "Address is required and must be at most 100 characters.";
        }
        return null;
    }
%>

<%
    // Must be called BEFORE the first request.getParameter(...)
    request.setCharacterEncoding("UTF-8");

    String action = clean(request.getParameter("action")).toLowerCase();
    if (action.isEmpty()) {
        action = "view";
    }

    boolean isPost = "POST".equalsIgnoreCase(request.getMethod());

    String message = null;
    boolean isError = false;
    boolean insertSuccess = false;

    // Values used by the edit form
    int editEid = 0;
    String editName = "";
    String editGender = "M";
    String editAddress = "";
    BigDecimal editSalary = BigDecimal.ZERO;
    int editAge = 0;

    // ================= INSERT =================
    if ("insert".equals(action)) {
        if (!isPost) {
            isError = true;
            message = "Invalid request. Please use the registration form.";
        } else {
            String eidS      = clean(request.getParameter("eid"));
            String ename     = clean(request.getParameter("ename"));
            String esalaryS  = clean(request.getParameter("esalary"));
            String egender   = clean(request.getParameter("egender"));
            String eageS     = clean(request.getParameter("eage"));
            String eaddress  = clean(request.getParameter("eaddress"));

            String err = validateEmployee(eidS, ename, esalaryS, egender, eageS, eaddress);
            if (err != null) {
                isError = true;
                message = err;
            } else {
                try (Connection con = getConnection();
                     PreparedStatement ps = con.prepareStatement(
                         "INSERT INTO employee (eid, ename, esalary, egender, eage, eaddress) " +
                         "VALUES (?, ?, ?, ?, ?, ?)")) {

                    ps.setInt(1, Integer.parseInt(eidS));
                    ps.setString(2, ename);
                    ps.setBigDecimal(3, parseSalary(esalaryS));
                    ps.setString(4, egender);
                    ps.setInt(5, Integer.parseInt(eageS));
                    ps.setString(6, eaddress);
                    ps.executeUpdate();

                    message = "The data inserted successfully!";
                    insertSuccess = true;

                } catch (SQLIntegrityConstraintViolationException dup) {
                    isError = true;
                    message = "An employee with this ID already exists.";
                } catch (Exception e) {
                    application.log("INSERT failed", e);
                    isError = true;
                    message = "Could not save the employee. Please try again later.";
                }
            }
        }
    }

    // ================= UPDATE =================
    if ("update".equals(action)) {
        if (!isPost) {
            isError = true;
            message = "Invalid request. Please use the edit form.";
            action = "view";
        } else {
            String eidS      = clean(request.getParameter("eid"));
            String ename     = clean(request.getParameter("ename"));
            String esalaryS  = clean(request.getParameter("esalary"));
            String egender   = clean(request.getParameter("egender"));
            String eageS     = clean(request.getParameter("eage"));
            String eaddress  = clean(request.getParameter("eaddress"));

            String err = validateEmployee(eidS, ename, esalaryS, egender, eageS, eaddress);
            if (err != null) {
                isError = true;
                message = err;
            } else {
                try (Connection con = getConnection();
                     PreparedStatement ps = con.prepareStatement(
                         "UPDATE employee SET ename = ?, esalary = ?, egender = ?, " +
                         "eage = ?, eaddress = ? WHERE eid = ?")) {

                    ps.setString(1, ename);
                    ps.setBigDecimal(2, parseSalary(esalaryS));
                    ps.setString(3, egender);
                    ps.setInt(4, Integer.parseInt(eageS));
                    ps.setString(5, eaddress);
                    ps.setInt(6, Integer.parseInt(eidS));

                    int rows = ps.executeUpdate();
                    if (rows > 0) {
                        message = "Employee record updated successfully!";
                    } else {
                        isError = true;
                        message = "No employee found with that ID.";
                    }
                } catch (Exception e) {
                    application.log("UPDATE failed", e);
                    isError = true;
                    message = "Could not update the employee. Please try again later.";
                }
            }
            action = "view";
        }
    }

    // ================= DELETE (POST only) =================
    if ("delete".equals(action)) {
        if (!isPost) {
            isError = true;
            message = "Invalid request. Delete must be submitted from the Delete button.";
        } else {
            Integer delId = parseIntSafe(clean(request.getParameter("eid")));
            if (delId == null || delId.intValue() <= 0) {
                isError = true;
                message = "Employee ID is invalid.";
            } else {
                try (Connection con = getConnection();
                     PreparedStatement ps = con.prepareStatement(
                         "DELETE FROM employee WHERE eid = ?")) {

                    ps.setInt(1, delId.intValue());
                    int rows = ps.executeUpdate();
                    if (rows > 0) {
                        message = "Employee record deleted successfully!";
                    } else {
                        isError = true;
                        message = "No employee found with that ID.";
                    }
                } catch (Exception e) {
                    application.log("DELETE failed", e);
                    isError = true;
                    message = "Could not delete the employee. Please try again later.";
                }
            }
        }
        action = "view";
    }

    // ================= EDIT (load record for the form) =================
    if ("edit".equals(action)) {
        Integer id = parseIntSafe(clean(request.getParameter("eid")));
        if (id == null || id.intValue() <= 0) {
            isError = true;
            message = "Employee ID is invalid.";
            action = "view";
        } else {
            boolean found = false;
            try (Connection con = getConnection();
                 PreparedStatement ps = con.prepareStatement(
                     "SELECT eid, ename, esalary, egender, eage, eaddress " +
                     "FROM employee WHERE eid = ?")) {

                ps.setInt(1, id.intValue());
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        found       = true;
                        editEid     = rs.getInt("eid");
                        editName    = rs.getString("ename");
                        editSalary  = rs.getBigDecimal("esalary");
                        editGender  = rs.getString("egender");
                        editAge     = rs.getInt("eage");
                        editAddress = rs.getString("eaddress");
                    }
                }
            } catch (Exception e) {
                application.log("EDIT load failed", e);
                isError = true;
                message = "Could not load the employee record. Please try again later.";
                action = "view";
            }

            if (!found && !isError) {
                isError = true;
                message = "Employee not found.";
                action = "view";
            }
        }
    }
%>

<% if (message != null) { %>
    <div class="msg <%= isError ? "error" : "success" %>">
        <%= esc(message) %>
    </div>
<% } %>

<% if (insertSuccess) { %>

    <div style="text-align: center; margin-top: 40px;">
        <a href="register.jsp?action=view" class="btn btn-view">View All Records</a>
        <a href="index.html" class="btn btn-home">Add Another Employee</a>
    </div>

<% } else if ("edit".equals(action)) { %>

    <div class="form-container" style="margin: 0 auto;">
        <h2>Edit Employee</h2>

        <form action="register.jsp" method="POST">
            <input type="hidden" name="action" value="update">

            <div class="form-group">
                <label>EID (Cannot Change):</label>
                <input type="number" name="eid" value="<%= editEid %>" readonly>
            </div>

            <div class="form-group">
                <label>Name:</label>
                <input type="text" name="ename" maxlength="50" value="<%= esc(editName) %>" required>
            </div>

            <div class="form-group">
                <label>Salary:</label>
                <input type="number" name="esalary" step="0.01" min="0" max="99999999.99"
                       value="<%= editSalary.toPlainString() %>" required>
            </div>

            <div class="form-group">
                <label>Gender:</label>
                <select name="egender">
                    <option value="M" <%= "M".equals(editGender) ? "selected" : "" %>>Male</option>
                    <option value="F" <%= "F".equals(editGender) ? "selected" : "" %>>Female</option>
                    <option value="O" <%= "O".equals(editGender) ? "selected" : "" %>>Other</option>
                </select>
            </div>

            <div class="form-group">
                <label>Age:</label>
                <input type="number" name="eage" min="18" max="100" value="<%= editAge %>" required>
            </div>

            <div class="form-group">
                <label>Address:</label>
                <input type="text" name="eaddress" maxlength="100" value="<%= esc(editAddress) %>" required>
            </div>

            <button type="submit" class="btn btn-view" style="width: 100%; margin-top: 10px;">
                Update Record
            </button>
        </form>

        <p style="text-align:center;"><a href="register.jsp?action=view">Cancel</a></p>
    </div>

<% } else { %>

    <h2>Employee Records</h2>

    <a href="index.html" class="btn btn-home" style="margin-bottom: 15px;">
        + Register New Employee
    </a>

    <table>
        <thead>
            <tr>
                <th>EID</th>
                <th>Name</th>
                <th>Salary</th>
                <th>Gender</th>
                <th>Age</th>
                <th>Address</th>
                <th>Actions</th>
            </tr>
        </thead>

        <tbody>
        <%
            try (Connection con = getConnection();
                 Statement st = con.createStatement();
                 ResultSet rs = st.executeQuery(
                     "SELECT eid, ename, esalary, egender, eage, eaddress " +
                     "FROM employee ORDER BY eid")) {

                boolean hasData = false;

                while (rs.next()) {
                    hasData = true;
                    int id = rs.getInt("eid");
        %>
                    <tr>
                        <td><%= id %></td>
                        <td><%= esc(rs.getString("ename")) %></td>
                        <td><%= rs.getBigDecimal("esalary").toPlainString() %></td>
                        <td><%= esc(rs.getString("egender")) %></td>
                        <td><%= rs.getInt("eage") %></td>
                        <td><%= esc(rs.getString("eaddress")) %></td>
                        <td>
                            <a href="register.jsp?action=edit&amp;eid=<%= id %>"
                               class="btn btn-edit">Edit</a>

                            <form class="inline-form" action="register.jsp" method="POST"
                                  onsubmit="return confirm('Are you sure you want to delete this employee?');">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="eid" value="<%= id %>">
                                <button type="submit" class="btn btn-delete">Delete</button>
                            </form>
                        </td>
                    </tr>
        <%
                }
                if (!hasData) {
        %>
                    <tr>
                        <td colspan="7" style="text-align:center;">No records found in database.</td>
                    </tr>
        <%
                }
            } catch (Exception e) {
                application.log("VIEW failed", e);
        %>
                    <tr>
                        <td colspan="7" style="color:red;">
                            Could not load employee records. Please contact the administrator.
                        </td>
                    </tr>
        <%
            }
        %>
        </tbody>
    </table>

<% } %>

</body>
</html>
