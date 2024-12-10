# RentHive

## Project Overview
RentHive is a web application designed to facilitate property rental management, allowing owners to list properties and tenants to find suitable rentals.

## Prerequisites
To build and run the RentHive project, ensure you have the following installed on your computer:

1. **Python 3.7 or higher**
   - **Download**: [Python Download Page](https://www.python.org/downloads/)
   - **Installation Directory**: `C:\Python37` (or your preferred directory)

2. **MySQL Server**
   - **Download**: [MySQL Community Server Download Page](https://dev.mysql.com/downloads/mysql/)
   - **Installation Directory**: `C:\Program Files\MySQL\MySQL Server`

3. **MySQL Workbench**
   - **Download**: [MySQL Workbench Download Page](https://dev.mysql.com/downloads/workbench/)
   - **Installation Directory**: `C:\Program Files\MySQL\MySQL Workbench X.X`

4. **Flask**
   - **Install via pip**: `pip install Flask`

5. **MySQL Connector for Python**
   - **Install via pip**: `pip install mysql-connector-python`

## Setting Up the Project

1. Navigate to the project directory.
2. Install required libraries:
   ```bash
   pip install -r requirements.txt
   ```
3. Set up the MySQL database:
   - Create a new database named `renthive8`.
   - Run the SQL scripts provided in the `sql` directory to set up the tables and stored procedures.

## Running the Application

1. Ensure the MySQL server is running.
2. Update the `app.py` file with your MySQL credentials (root username, password, and database name).
3. Run the application:
   ```bash
   python app.py
   ```
4. Access the application in your web browser at:
   [http://127.0.0.1:5000/](http://127.0.0.1:5000/) (Refer to the terminal for the exact link.)

## Technical Specifications

### Software Used

- **Host Language**: Python
- **Web Framework**: Flask
- **Database**: MySQL
- **Frontend Technologies**: HTML, CSS, JavaScript, Bootstrap
- **Database Management**: MySQL Workbench
- **Version Control**: Git
