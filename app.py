from flask import Flask, render_template, request, redirect, url_for, flash, session
import mysql.connector
from mysql.connector import Error
import os
from werkzeug.utils import secure_filename
import json
app = Flask(__name__)
app.secret_key = 'your_secret_key'  
db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': '1234',
    'database': 'renthive8'
}


UPLOAD_FOLDER = 'static/uploads'
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Utility function to connect to the database
def get_db_connection():
    try:
        connection = mysql.connector.connect(**db_config)
        if connection.is_connected():
            return connection
    except Error as e:
        print(f"Database connection error: {e}")
        return None

@app.route('/')
def home():
    connection = get_db_connection()
    properties = []
    owner_email = None

    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Call the stored procedure
            cursor.callproc('GetAllAvailablePropertiesHome')

            # Fetch results from the procedure
            for result in cursor.stored_results():
                properties = result.fetchall()

            # Debug print
            print("Properties Retrieved:", properties)

        except Error as e:
            print(f"Error retrieving properties: {e}")
            flash(f'Error retrieving properties: {e}', 'danger')
        finally:
            connection.close()

    return render_template('home.html', properties=properties)



@app.route('/create_user', methods=['GET', 'POST'])
def create_user():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        first_name = request.form['first_name']
        last_name = request.form['last_name']
        email = request.form['email']
        phone = request.form['phone']
        user_type = request.form['user_type']

        connection = get_db_connection()
        if connection:
            try:
                cursor = connection.cursor()
                cursor.callproc('RegisterUser', (username, password, first_name, last_name, email, phone, user_type))
                connection.commit()
                flash('User created successfully!', 'success')
                return redirect(url_for('home'))
            except Error as e:
                flash(f'Error creating user: {e}', 'danger')
            finally:
                connection.close()
    return render_template('create_user.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')

        connection = get_db_connection()
        if connection:
            try:
                cursor = connection.cursor(dictionary=True)

                # Call the stored procedure
                cursor.callproc('LoginUser', (username, password))
                
                # Fetch results from the procedure
                fetched_result = None
                for result in cursor.stored_results():
                    fetched_result = result.fetchall()
                
                print(f"Fetched Result: {fetched_result}")  # Debugging
                
                if fetched_result and fetched_result[0]['user_type']:
                    user_type = fetched_result[0]['user_type']
                    
                    if user_type == 'owner':
                        cursor.execute("SELECT owner_id, username FROM owner WHERE username = %s", (username,))
                        owner = cursor.fetchone()
                        session['user_type'] = 'owner'
                        session['user_id'] = owner['owner_id']
                        session['username'] = owner['username']
                        flash('Login successful as Owner!', 'success')
                        return redirect(url_for('owner_dashboard'))
                    
                    elif user_type == 'tenant':
                        cursor.execute("SELECT tenant_id, username FROM tenant WHERE username = %s", (username,))
                        tenant = cursor.fetchone()
                        session['user_type'] = 'tenant'
                        session['user_id'] = tenant['tenant_id']
                        session['username'] = tenant['username']
                        flash('Login successful as Tenant!', 'success')
                        return redirect(url_for('tenant_dashboard'))
                else:
                    flash('Invalid username or password!', 'error')
            except Exception as e:
                flash(f'Database error during login: {e}', 'danger')
            finally:
                cursor.close()
                connection.close()
        else:
            flash('Unable to connect to the database.', 'danger')

    return render_template('login.html')

@app.route('/owner_dashboard')
def owner_dashboard():
    if 'user_type' not in session or session['user_type'] != 'owner':
        flash('You need to log in as an owner to access this page.', 'error')
        return redirect(url_for('login'))

    connection = get_db_connection()
    properties = []
    lease_agreements = []

    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Existing property fetch
            cursor.callproc('OwnerDashboard', (session['user_id'],))
            for result in cursor.stored_results():
                properties = result.fetchall()

            # Fetch lease agreements
            cursor.callproc('GetOwnerLeaseAgreements', (session['user_id'],))
            for result in cursor.stored_results():
                lease_agreements = result.fetchall()

            for prop in properties:
                if prop['property_images']:
                    prop['property_images'] = [
                        f"/{img.replace(os.path.sep, '/')}" for img in prop['property_images'].split(',')
                    ]
                else:
                    prop['property_images'] = []

        except Error as e:
            flash(f'Error retrieving properties or lease agreements: {e}', 'danger')
        finally:
            cursor.close()
            connection.close()

    return render_template('owner_home.html', 
                           username=session['username'], 
                           properties=properties, 
                           lease_agreements=lease_agreements)


@app.route('/tenant_dashboard')
def tenant_dashboard():
    if 'user_type' not in session or session['user_type'] != 'tenant':
        flash('You need to log in as a tenant to access this page.', 'error')
        return redirect(url_for('login'))

    connection = get_db_connection()
    lease_agreements = []
    requests = []


    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Call the stored procedure
            cursor.callproc('GetTenantLeaseAgreements', (session['user_id'],))
            
            # Fetch results from the procedure
            for result in cursor.stored_results():
                lease_agreements = result.fetchall()

            cursor.callproc('view_maintenance_request_status', (session['user_id'],))
            for result in cursor.stored_results():
                requests = result.fetchall()

        except Error as e:
            flash(f'Error retrieving lease agreements: {e}', 'danger')
        finally:
            cursor.close()
            connection.close()

    return render_template('tenant_home.html', username=session.get('username', 'Guest'), lease_agreements=lease_agreements, requests=requests)

@app.route('/add_property', methods=['GET', 'POST'])
def add_property():
    if 'user_type' not in session or session['user_type'] != 'owner':
        flash('You need to log in as an owner to access this page.', 'error')
        return redirect(url_for('login'))

    if request.method == 'POST':
        address = request.form['address']
        city = request.form['city']
        state = request.form['state']
        zip_code = request.form['zip_code']
        description = request.form['description']
        rent_amount = request.form['rent_amount']
        status = request.form['status']
        owner_id = session['user_id']

        image_paths = []

        # Save the images and collect paths
        if 'images' in request.files:
            images = request.files.getlist('images')
            for image in images:
                if image.filename != '':
                    image_filename = secure_filename(image.filename)
                    image_path = os.path.join(app.config['UPLOAD_FOLDER'], image_filename)
                    image.save(image_path)

                    normalized_path = f"/{image_path.replace(os.path.sep, '/')}"
                    image_paths.append(normalized_path)

        connection = get_db_connection()
        if connection:
            try:
                cursor = connection.cursor()

                # Convert image_paths to JSON format
                image_paths_json = json.dumps(image_paths)

                # Call the stored procedure
                cursor.callproc('AddProperty', (owner_id, address, city, state, zip_code, description, rent_amount, status, image_paths_json))

                # Commit the transaction
                connection.commit()

                flash('Property added successfully!', 'success')
                return redirect(url_for('owner_dashboard'))
            except Error as e:
                flash(f'Error adding property: {e}', 'danger')
            finally:
                connection.close()

    return render_template('addproperty.html')


@app.route('/edit_property/<int:property_id>', methods=['GET', 'POST'])
def edit_property(property_id):
    if 'user_type' not in session or session['user_type'] != 'owner':
        flash('You need to log in as an owner to access this page.', 'error')
        return redirect(url_for('login'))

    connection = get_db_connection()
    property_data = None
    property_images = []

    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Call the procedure to fetch property details
            cursor.callproc('GetPropertyById', (property_id, session['user_id']))
            for result in cursor.stored_results():
                property_data = result.fetchone()

            if property_data:
                # Process property images
                if property_data['property_images']:
                    property_images = [
                        f"/{img.replace(os.path.sep, '/')}" for img in property_data['property_images'].split(',')
                    ]

                if request.method == 'POST':
                    # Gather form data
                    address = request.form['address']
                    city = request.form['city']
                    state = request.form['state']
                    zip_code = request.form['zip_code']
                    description = request.form['description']
                    rent_amount = request.form['rent_amount']
                    status = request.form['status']

                    # Call the procedure to update property details
                    cursor.callproc('UpdatePropertyDetails', (
                        property_id, session['user_id'], address, city, state,
                        zip_code, description, rent_amount, status
                    ))
                    connection.commit()

                    # Handle image uploads
                    if 'images' in request.files:
                        images = request.files.getlist('images')
                        for image in images:
                            if image.filename != '':
                                image_path = os.path.join(app.config['UPLOAD_FOLDER'], image.filename)
                                image.save(image_path)
                                
                                normalized_path = f"/{image_path.replace(os.path.sep, '/')}"

                                # Call the procedure to insert property images
                                cursor.callproc('InsertPropertyImage', (property_id, normalized_path))
                                connection.commit()

                    flash('Property updated successfully!', 'success')
                    return redirect(url_for('owner_dashboard'))
            else:
                flash('Property not found or you are not authorized to edit it.', 'danger')
                return redirect(url_for('owner_dashboard'))

        except Error as e:
            flash(f'Error editing property: {e}', 'danger')
        finally:
            connection.close()

    return render_template('edit_property.html', property=property_data, images=property_images)

@app.route('/delete_property/<int:property_id>', methods=['GET'])
def delete_property(property_id):
    if 'user_type' not in session or session['user_type'] != 'owner':
        flash('You need to log in as an owner to access this page.', 'error')
        return redirect(url_for('login'))

    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor()
            
            # Call the stored procedure to delete the property
            cursor.callproc('DeleteProperty', (property_id, session['user_id']))
            connection.commit()
            
            if cursor.rowcount > 0:
                flash('Property deleted successfully!', 'success')
            else:
                flash('Property not found or you are not authorized to delete it.', 'danger')
        
        except Error as e:
            flash(f'Error deleting property: {e}', 'danger')
        finally:
            connection.close()

    return redirect(url_for('owner_dashboard'))


@app.route('/create_agreement', methods=['GET', 'POST'])
def create_agreement():
    if request.method == 'POST':
        property_id = request.form['property_id']
        tenant_usernames = request.form.getlist('tenant_usernames')
        pdf_link = request.files['pdf_link']
        start_date = request.form['start_date']
        end_date = request.form['end_date']

        # Save the PDF file
        if pdf_link:
            pdf_filename = secure_filename(pdf_link.filename)
            pdf_link.save(os.path.join(app.config['UPLOAD_FOLDER'], pdf_filename))
            pdf_link_path = f"/{os.path.join(app.config['UPLOAD_FOLDER'], pdf_filename).replace(os.path.sep, '/')}"
        else:
            pdf_link_path = None

        connection = get_db_connection()
        cursor = connection.cursor()

        try:
            # Convert tenant_usernames to JSON format
            tenant_usernames_json = json.dumps(tenant_usernames)

            # Call the stored procedure
            cursor.callproc('CreateAgreement', (property_id, tenant_usernames_json, pdf_link_path, start_date, end_date))

            # Commit the transaction
            connection.commit()
            flash('Lease agreement created successfully!', 'success')
            return redirect(url_for('owner_dashboard'))

        except Error as e:
            # If any error occurs, rollback the transaction
            connection.rollback()
            flash(f'Error creating agreement: {e}', 'danger')
        finally:
            cursor.close()
            connection.close()

    # GET request handling (render the form)
    # Fetch properties and tenants to display in the form
    connection = get_db_connection()
    properties = []
    tenants = []

    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            # Fetch properties
            cursor.execute("SELECT property_id, address FROM Property WHERE statuss = 'Available'")
            properties = cursor.fetchall()

            # Fetch tenants with first and last names
            cursor.execute("SELECT tenant_id, username, first_name, last_name FROM Tenant")
            tenants = cursor.fetchall()

        except Error as e:
            flash(f'Error retrieving properties or tenants: {e}', 'danger')
        finally:
            cursor.close()
            connection.close()

    return render_template('create_agreement.html', properties=properties, tenants=tenants)

@app.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out.', 'success')
    return redirect(url_for('home'))

@app.route('/tenant_lease_agreements')
def tenant_lease_agreements():
    if 'user_type' not in session or session['user_type'] != 'tenant':
        flash('You need to log in as a tenant to access this page.', 'error')
        return redirect(url_for('login'))

    connection = get_db_connection()
    lease_agreements = []

    if connection:
        try:
            cursor = connection.cursor(dictionary=True)

            # Call the stored procedure
            cursor.callproc('GetTenantLeaseAgreements', (session['user_id'],))

            # Fetch the results from the stored procedure
            for result in cursor.stored_results():
                lease_agreements = result.fetchall()
                
        except Error as e:
            flash(f'Error retrieving lease agreements: {e}', 'danger')
        finally:
            cursor.close()
            connection.close()

    return render_template('tenant_lease_agreements.html', username=session.get('username', 'Guest'), lease_agreements=lease_agreements)

@app.route('/view_agreement/<int:agreement_id>', methods=['GET'])
def view_agreement(agreement_id):
    if 'user_type' not in session or session['user_type'] != 'tenant':
        flash('You need to log in as a tenant to access this page.', 'error')
        return redirect(url_for('login'))

    connection = get_db_connection()
    agreement_data = None

    if connection:
        try:
            cursor = connection.cursor(dictionary=True)

            # Call the stored procedure
            cursor.callproc('GetTenantAgreement', (agreement_id, session['user_id']))

            # Fetch the result from the stored procedure
            for result in cursor.stored_results():
                agreement_data = result.fetchone()

            if not agreement_data:
                flash('Agreement not found or you are not authorized to view it.', 'danger')
                return redirect(url_for('tenant_lease_agreements'))

        except Error as e:
            flash(f'Error retrieving agreement: {e}', 'danger')
        finally:
            cursor.close()
            connection.close()

    # Ensure the PDF link is correctly formatted
    if agreement_data and agreement_data['pdf_link']:
        agreement_data['pdf_link'] = url_for('static', filename='uploads/' + agreement_data['pdf_link'].split('/')[-1])

    return render_template('view_agreement.html', agreement=agreement_data)



@app.route('/payment_history', methods=['GET'])
def payment_history():
    if 'user_type' not in session or session['user_type'] != 'owner':
        flash('You need to log in as an owner to access this page.', 'error')
        return redirect(url_for('login'))

    # Get the owner ID from the session
    owner_id = session.get('user_id')

    # Get the database connection
    connection = get_db_connection()
    payments = []

    if connection:
        try:
            cursor = connection.cursor(dictionary=True)

            # Call the stored procedure
            cursor.callproc('ViewOwnerPaymentHistory', [owner_id])

            # Fetch all results from the stored procedure
            for result in cursor.stored_results():
                payments = result.fetchall()

        except Error as e:
            flash(f"Error fetching payment history: {e}", 'danger')
        finally:
            connection.close()

    # Render the payment history template
    if payments:
        return render_template('owner_payment_history.html', payments=payments)
    else:
        flash("No payment history available.", 'warning')
        return render_template('owner_payment_history.html', payments=[])
    
    
@app.route('/make_payment', methods=['GET', 'POST'])
def make_payment():
    if 'user_type' not in session or session['user_type'] != 'tenant':
        flash('You need to log in as a tenant to access this page.', 'error')
        return redirect(url_for('login'))

    if request.method == 'POST':
        tenant_id = session.get('user_id')

        # Get form data
        amount = request.form.get('amount')
        payment_type = request.form.get('payment_type')

        # Validate inputs
        if not amount or not payment_type:
            flash('All fields are required.', 'error')
            return redirect(url_for('make_payment'))

        # Connect to the database
        connection = get_db_connection()

        if connection:
            try:
                cursor = connection.cursor(dictionary=True)
                
                # Call the stored procedure to get agreement_id
                cursor.callproc('GetAgreementIdByTenantId', [tenant_id])
                
                # Fetch the agreement_id
                agreement_id_result = cursor.stored_results()
                agreement_id = None
                for result in agreement_id_result:
                    row = result.fetchone()
                    if row:
                        agreement_id = row.get('agreement_id')

                # Check if an agreement_id was found
                if not agreement_id:
                    flash('No agreement found for the tenant.', 'error')
                    return redirect(url_for('make_payment'))

                # Call the MakePayment stored procedure
                cursor.callproc('MakePayment', [tenant_id, agreement_id, amount, payment_type])
                
                # Fetch the result to get the payment ID
                payment_id = None
                for result in cursor.stored_results():
                    payment_id = result.fetchone().get('payment_id')

                connection.commit()
                flash(f'Payment successful! Payment ID: {payment_id}', 'success')

            except Error as e:
                flash(f"Error processing payment: {e}", 'danger')
            finally:
                connection.close()

        return redirect(url_for('tenant_dashboard'))

    # If it's a GET request, render the payment form
    return render_template('payment_form.html')  

@app.route('/submit_maintenance_request', methods=['GET', 'POST'])
def submit_maintenance_request():
    if 'user_type' not in session or session['user_type'] != 'tenant':
        flash('You need to log in as a tenant to access this page.', 'error')
        return redirect(url_for('login'))

    if request.method == 'POST':
        description = request.form['description']
        tenant_id = session['user_id']

        connection = get_db_connection()
        if connection:
            try:
                cursor = connection.cursor()
                cursor.callproc('SubmitMaintenanceRequestForm', (tenant_id, description))
                connection.commit()
                flash('Maintenance request submitted successfully!', 'success')
                return redirect(url_for('tenant_dashboard'))
            except Error as e:
                flash(f'Error submitting maintenance request: {e}', 'danger')
            finally:
                cursor.close()
                connection.close()

    return render_template('submit_maintenance_request.html')

@app.route('/view_maintenance_requests')
def view_maintenance_requests():
    if 'user_type' not in session or session['user_type'] != 'tenant':
        flash('You need to log in as a tenant to access this page.', 'error')
        return redirect(url_for('login'))

    tenant_id = session['user_id']
    requests = []

    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.callproc('view_maintenance_request_status', (tenant_id,))
            for result in cursor.stored_results():
                requests = result.fetchall()
        except Error as e:
            flash(f'Error retrieving maintenance requests: {e}', 'danger')
        finally:
            cursor.close()
            connection.close()

    return render_template('view_maintenance_requests.html', requests=requests)


@app.route('/owner/maintenance_requests')
def owner_view_maintenance_requests():
    """Route to display all maintenance requests for an owner."""
    if 'user_type' not in session or session['user_type'] != 'owner':
        flash('You need to log in as an owner to access this page.', 'error')
        return redirect(url_for('login'))

    owner_id = session['user_id']
    connection = get_db_connection()
    requests = []

    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            # Call the stored procedure to get maintenance requests
            cursor.callproc('owner_view_maintenance_requests', (owner_id,))

            # Fetch the results from the procedure
            for result in cursor.stored_results():
                requests = result.fetchall()

        except Error as e:
            flash(f'Error retrieving maintenance requests: {e}', 'danger')
        finally:
            cursor.close()
            connection.close()

    return render_template('maintenance_requests.html', requests=requests)


@app.route('/owner/update_request_status', methods=['GET', 'POST'])
def update_maintenance_status():
    """Route to view maintenance requests and update their status."""
    if 'user_type' not in session or session['user_type'] != 'owner':
        flash('You need to log in as an owner to access this page.', 'error')
        return redirect(url_for('login'))

    owner_id = session['user_id']
    connection = get_db_connection()
    requests = []

    if request.method == 'POST':
        request_id = request.form.get('request_id')
        new_status = request.form.get('new_status')

        if connection:
            try:
                cursor = connection.cursor()
                # Call the stored procedure to update the status
                cursor.callproc('owner_update_maintenance_status', (owner_id, request_id, new_status))
                connection.commit()
                flash('Maintenance request status updated successfully.', 'success')
            except Error as e:
                flash(f'Error updating maintenance request status: {e}', 'danger')
            finally:
                cursor.close()
                connection.close()

        return redirect(url_for('update_maintenance_status'))

    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            # Call the stored procedure to get maintenance requests
            cursor.callproc('owner_view_maintenance_requests', (owner_id,))

            # Fetch the results from the procedure
            for result in cursor.stored_results():
                requests = result.fetchall()

        except Error as e:
            flash(f'Error retrieving maintenance requests: {e}', 'danger')
        finally:
            cursor.close()
            connection.close()

    return render_template('update_requests.html', requests=requests)

@app.route('/send_notification', methods=['POST'])
def send_notification():
    if 'user_type' not in session or session['user_type'] != 'owner':
        return jsonify({'error': 'Unauthorized'}), 403
    
    property_id = request.form.get('property_id')
    message = request.form.get('message')
    owner_id = session['user_id']
    
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.callproc('CreateNotification', [owner_id, property_id, message])
            
            for result in cursor.stored_results():
                notification = result.fetchone()
            
            connection.commit()
            flash('Notification sent successfully!', 'success')
            return redirect(url_for('owner_dashboard'))
            
        except Error as e:
            flash(f'Error sending notification: {e}', 'danger')
        finally:
            connection.close()
            
    return redirect(url_for('owner_dashboard'))

@app.route('/view_notifications')
def view_notifications():
    if 'user_type' not in session:
        return redirect(url_for('login'))
        
    connection = get_db_connection()
    notifications = []
    
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            
            if session['user_type'] == 'owner':
                cursor.callproc('GetOwnerNotifications', [session['user_id']])
            else:
                cursor.callproc('GetTenantNotifications', [session['user_id']])
                
            for result in cursor.stored_results():
                notifications = result.fetchall()
                
        except Error as e:
            flash(f'Error retrieving notifications: {e}', 'danger')
        finally:
            connection.close()
            
    return render_template(
        'notifications.html',
        notifications=notifications,
        user_type=session['user_type']
    )

from flask import Flask, request, session, flash, redirect, url_for, render_template

@app.route('/owner/lease-agreements', methods=['GET', 'POST'])
def owner_lease_agreements():
    if 'user_type' not in session or session['user_type'] != 'owner':
        flash('You need to log in as an owner to access this page.', 'error')
        return redirect(url_for('login'))

    connection = get_db_connection()
    agreements = []
    properties = []
    tenants = []

    if connection:
        try:
            cursor = connection.cursor(dictionary=True)

            # Call the stored procedure to fetch owner's lease agreements
            cursor.callproc('GetOwnerLeaseAgreements', (session['user_id'],))

            # Fetch results from the procedure
            for result in cursor.stored_results():
                agreements = result.fetchall()

            # Call the stored procedure to fetch available properties for the owner
            cursor.callproc('GetAvailablePropertiesofOwner', (session['user_id'],))

            # Fetch results from the procedure
            for result in cursor.stored_results():
                properties = result.fetchall()

            # Call the stored procedure to fetch available tenants
            cursor.callproc('GetAvailableTenants')

            # Fetch results from the procedure
            for result in cursor.stored_results():
                tenants = result.fetchall()

        except Error as e:
            flash(f'Error retrieving data: {e}', 'danger')
        finally:
            cursor.close()
            connection.close()

    return render_template('owner_lease_agreements.html', 
                           agreements=agreements, 
                           properties=properties, 
                           tenants=tenants)


@app.route('/edit_lease_agreement/<int:agreement_id>', methods=['GET', 'POST'])
def edit_lease_agreement(agreement_id):
    if 'user_type' not in session or session['user_type'] != 'owner':
        flash('You need to log in as an owner to access this page.', 'error')
        return redirect(url_for('login'))

    connection = get_db_connection()
    agreement = None

    if connection:
        try:
            cursor = connection.cursor(dictionary=True)

            # Fetch agreement details with more robust error handling
            cursor.execute("""
                SELECT 
                    a.agreement_id, 
                    a.start_date, 
                    a.end_date, 
                    p.address,
                    a.pdf_link
                FROM Agreement a
                JOIN Property p ON a.property_id = p.property_id
                WHERE a.agreement_id = %s
            """, (agreement_id,))
            agreement = cursor.fetchone()

            if not agreement:
                flash('Agreement not found.', 'danger')
                return redirect(url_for('owner_lease_agreements'))

            if request.method == 'POST':
                # Extensive logging for debugging
                print("Form Data Received:")
                for key, value in request.form.items():
                    print(f"{key}: {value}")
                
                start_date = request.form.get('start_date')
                end_date = request.form.get('end_date')

                # Validate dates
                if not start_date or not end_date:
                    flash('Start and end dates are required.', 'danger')
                    return render_template('edit_lease_agreement.html', agreement=agreement)

                # Optional PDF upload
                pdf_link = agreement.get('pdf_link')  # Keep existing PDF if no new upload
                if 'pdf_link' in request.files:
                    pdf_file = request.files['pdf_link']
                    if pdf_file and pdf_file.filename != '':
                        # Secure the filename
                        filename = secure_filename(pdf_file.filename)
                        
                        # Create uploads directory if it doesn't exist
                        upload_folder = os.path.join(app.config['UPLOAD_FOLDER'], 'agreements')
                        os.makedirs(upload_folder, exist_ok=True)
                        
                        # Save the file
                        file_path = os.path.join(upload_folder, filename)
                        pdf_file.save(file_path)
                        
                        # Create a relative path for database storage
                        pdf_link = f"/uploads/agreements/{filename}"

                # Call the stored procedure to update the agreement
                try:
                    cursor.callproc('update_lease_agreement', (agreement_id, start_date, end_date, pdf_link))
                    connection.commit()
                    flash('Lease agreement updated successfully!', 'success')
                    return redirect(url_for('owner_lease_agreements'))

                except Error as update_error:
                    connection.rollback()
                    flash(f'Database update error: {update_error}', 'danger')
                    print(f"Update Error: {update_error}")

        except Error as e:
            flash(f'Error retrieving lease agreement: {e}', 'danger')
            print(f"Retrieval Error: {e}")
        finally:
            if connection:
                connection.close()

    return render_template('edit_lease_agreement.html', agreement=agreement)

@app.route('/delete_lease_agreement/<int:agreement_id>', methods=['POST'])
def delete_lease_agreement(agreement_id):
    if 'user_type' not in session or session['user_type'] != 'owner':
        flash('You need to log in as an owner to access this page. ', 'error')
        return redirect(url_for('login'))

    connection = get_db_connection()

    if connection:
        try:
            cursor = connection.cursor(dictionary=True)

            # Call the stored procedure 
            cursor.callproc('DeleteLeaseAgreement', (agreement_id, session['user_id']))

            # Commit the transaction
            connection.commit()
            flash('Lease agreement deleted successfully! ', 'success')

        except Error as e:
            flash(f'Error deleting lease agreement: {e}', 'danger')
        finally:
            connection.close()

    return redirect(url_for('owner_lease_agreements'))

@app.route('/create_lease_agreement', methods=['GET', 'POST'])
def create_lease_agreement():
    if 'user_type' not in session or session['user_type'] != 'owner':
        flash('You need to log in as an owner to access this page.', 'error')
        return redirect(url_for('login'))

    connection = get_db_connection()
    properties = []

    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.callproc('GetAvailablePropertiesofOwner', (session['user_id'],))

            for result in cursor.stored_results():
                properties = result.fetchall()
        except Error as e:
            flash(f'Error retrieving properties: {e}', 'danger')
        finally:
            cursor.close()
            connection.close()

    if request.method == 'POST':
        property_id = request.form.get('property_id')
        tenant_emails = request.form.getlist('tenant_emails[]')
        start_date = request.form.get('start_date')
        end_date = request.form.get('end_date')

        pdf_link = None
        if 'pdf_link' in request.files:
            pdf_file = request.files['pdf_link']
            if pdf_file and pdf_file.filename != '':
                filename = secure_filename(pdf_file.filename)
                upload_folder = os.path.join(app.config['UPLOAD_FOLDER'], 'agreements')
                os.makedirs(upload_folder, exist_ok=True)
                file_path = os.path.join(upload_folder, filename)
                pdf_file.save(file_path)
                pdf_link = f"/uploads/agreements/{filename}"

        if not all([property_id, tenant_emails, start_date, end_date]):
            flash('All fields are required.', 'danger')
            return redirect(url_for('create_lease_agreement'))

        tenant_emails_string = ','.join(tenant_emails)

        connection = get_db_connection()
        if connection:
            try:
                cursor = connection.cursor()

                cursor.callproc('CreateLeaseAgreement', [
                    property_id,
                    tenant_emails_string,
                    start_date,
                    end_date,
                    pdf_link
                ])

                connection.commit()
                flash('Lease agreement created successfully!', 'success')
            except Error as e:
                connection.rollback()
                flash(f'Error creating lease agreement: {e}', 'danger')
            finally:
                connection.close()

        return redirect(url_for('owner_lease_agreements'))

    return render_template('create_lease_agreement.html', properties=properties)

if __name__ == '__main__':
    app.run(debug=True)
    