import mysql.connector
from mysql.connector import Error

def connect_to_db():
    """Connect to the MySQL database."""
    try:
        connection = mysql.connector.connect(
            host="localhost",  # Replace with your DB host
            user="root",  # Replace with your DB username
            password="1234",  # Replace with your DB password
            database="renthive2"
        )
        if connection.is_connected():
            print("Connected to the database")
            return connection
    except Error as e:
        print(f"Error: {e}")
        return None

def register_user(username, password, first_name, last_name, email, phone, user_type):
    """Register a new user."""
    try:
        connection = connect_to_db()
        if connection is None:
            return
        
        cursor = connection.cursor()
        cursor.callproc('RegisterUser', (username, password, first_name, last_name, email, phone, user_type))
        connection.commit()
        print(f"User '{username}' registered successfully as {user_type}.")
    except Error as e:
        print(f"Error during registration: {e}")
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

def login_user(username, password):
    """Log in a user and determine user type."""
    try:
        connection = connect_to_db()
        if connection is None:
            return
        
        cursor = connection.cursor()
        cursor.callproc('LoginUser', (username, password))
        
        for result in cursor.stored_results():
            user_type = result.fetchone()
            if user_type and user_type[0]:
                print(f"Login successful! User type: {user_type[0]}")
            else:
                print("Invalid username or password.")
    except Error as e:
        print(f"Error during login: {e}")
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

# Example usage
if __name__ == "__main__":
    # Register a user
    register_user(
        username="johndoe",
        password="securepassword",
        first_name="John",
        last_name="Doe",
        email="johndoe@example.com",
        phone="1234567890",
        user_type="tenant"  # or "owner"
    )

    # Log in a user
    login_user(
        username="johndoe",
        password="securepassword"
    )
