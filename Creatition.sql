create database renthive2;
-- drop database renthive2;
use renthive2;
CREATE TABLE Owner (
    owner_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,  -- Added username for login
    first_name VARCHAR(100) NOT NULL,  -- Added first name
    last_name VARCHAR(100) NOT NULL,   -- Added last name
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(100) NOT NULL,
    phone VARCHAR(15),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Property Table
CREATE TABLE Property (
    property_id INT AUTO_INCREMENT PRIMARY KEY,
    owner_id INT NOT NULL,
    address VARCHAR(255) NOT NULL,
    city VARCHAR(50),
    state VARCHAR(50),
    zip_code VARCHAR(10),
    description TEXT,
	statuss enum("Available", "Rented") NOT NULL,
    rent_amount DECIMAL(10, 2) NOT NULL,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner_id) REFERENCES Owner(owner_id) ON DELETE CASCADE
);

-- Tenant Table
CREATE TABLE Tenant (
    tenant_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(100) NOT NULL,
    phone VARCHAR(15),
    property_id INT DEFAULT NULL, -- Foreign key referencing the Property table
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (property_id) REFERENCES Property(property_id) ON DELETE SET NULL
);



CREATE TABLE PropertyImage (
    image_id INT AUTO_INCREMENT PRIMARY KEY,
    property_id INT NOT NULL,       -- Foreign key referencing the Property table
    image_path VARCHAR(255) NOT NULL, -- Path or URL to the image
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (property_id) REFERENCES Property(property_id) ON DELETE CASCADE
);

-- Agreement Table
CREATE TABLE Agreement (
    agreement_id INT AUTO_INCREMENT PRIMARY KEY,
    property_id INT NOT NULL,
    pdf_link VARCHAR(255) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    FOREIGN KEY (property_id) REFERENCES Property(property_id) ON DELETE CASCADE
);

-- Agreement-Tenant Relationship Table
CREATE TABLE AgreementTenant (
    agreement_id INT NOT NULL,
    tenant_id INT NOT NULL,
    PRIMARY KEY (agreement_id, tenant_id),
    FOREIGN KEY (agreement_id) REFERENCES Agreement(agreement_id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id) REFERENCES Tenant(tenant_id) ON DELETE CASCADE
);

-- Payment Table
CREATE TABLE Payment (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    agreement_id INT NOT NULL,
    tenant_id INT NOT NULL,
    payment_date DATE NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_type ENUM('Deposit', 'Rent') NOT NULL,
    FOREIGN KEY (agreement_id) REFERENCES Agreement(agreement_id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id) REFERENCES Tenant(tenant_id) ON DELETE CASCADE
);

-- Maintenance Request Table
CREATE TABLE MaintenanceRequest (
    request_id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id INT NOT NULL,
    property_id INT NOT NULL,
    request_date DATE NOT NULL,
    status ENUM('Open', 'In Progress', 'Completed') NOT NULL,
    description TEXT NOT NULL,
    FOREIGN KEY (tenant_id) REFERENCES Tenant(tenant_id) ON DELETE CASCADE,
    FOREIGN KEY (property_id) REFERENCES Property(property_id) ON DELETE CASCADE
);

-- Messages Table
CREATE TABLE Messages (
    message_id INT AUTO_INCREMENT PRIMARY KEY,
    sender_id INT NOT NULL,
    receiver_id INT NOT NULL,
    property_id INT NOT NULL,
    message_text TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sender_id) REFERENCES Tenant(tenant_id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES Owner(owner_id) ON DELETE CASCADE,
    FOREIGN KEY (property_id) REFERENCES Property(property_id) ON DELETE CASCADE
);

DELIMITER //

CREATE PROCEDURE RegisterUser (
    IN p_username VARCHAR(255),
    IN p_password VARCHAR(255),
    IN p_first_name VARCHAR(255),
    IN p_last_name VARCHAR(255),
    IN p_email_id VARCHAR(255),
    IN p_phone_no VARCHAR(20),
    IN p_user_type VARCHAR(50)
)
BEGIN
    IF p_user_type = 'owner' THEN
        INSERT INTO owner (username, password, first_name, last_name, email, phone)
        VALUES (p_username, p_password, p_first_name, p_last_name, p_email_id, p_phone_no);
    ELSEIF p_user_type = 'tenant' THEN
        INSERT INTO tenant (username, password, first_name, last_name, email, phone)
        VALUES (p_username, p_password, p_first_name, p_last_name, p_email_id, p_phone_no);
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid user type. Must be either owner or tenant.';
    END IF;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE LoginUser (
    IN p_username VARCHAR(100),
    IN p_password VARCHAR(100)
)
BEGIN
    -- Check if the user is an owner
    IF EXISTS (SELECT * FROM owner WHERE username = p_username AND password = p_password) THEN
        SELECT 'owner' AS user_type;
    -- Check if the user is a tenant
    ELSEIF EXISTS (SELECT * FROM tenant WHERE username = p_username AND password = p_password) THEN
        SELECT 'tenant' AS user_type;
    ELSE
        SELECT NULL AS user_type; -- Invalid login
    END IF;
END //

DELIMITER ;
DELIMITER //

CREATE PROCEDURE AddProperty (
    IN p_owner_id INT,
    IN p_address VARCHAR(255),
    IN p_city VARCHAR(50),
    IN p_state VARCHAR(50),
    IN p_zip_code VARCHAR(10),
    IN p_description TEXT,
    IN p_rent_amount DECIMAL(10, 2),
    IN p_image_paths TEXT, -- JSON or comma-separated paths for property images
    IN p_amenities TEXT, -- Comma-separated list of amenity names, each with optional descriptions
    IN p_status ENUM('Available', 'Rented') -- New field for property status
)
BEGIN
    -- Declare variables at the top
    DECLARE new_property_id INT;
    DECLARE image_path VARCHAR(255);
    DECLARE amenity_name VARCHAR(100);
    DECLARE amenity_description TEXT;
    DECLARE done INT DEFAULT 0;

    -- Cursor declaration for images
    DECLARE image_cursor CURSOR FOR 
        SELECT TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(p_image_paths, ',', numbers.n), ',', -1)) AS image_path
        FROM (SELECT 1 n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5) numbers
        WHERE LENGTH(p_image_paths) - LENGTH(REPLACE(p_image_paths, ',', '')) + 1 >= numbers.n;

    -- Cursor declaration for amenities
    DECLARE amenity_cursor CURSOR FOR 
        SELECT TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(p_amenities, ',', numbers.n), ',', -1)) AS amenity_name
        FROM (SELECT 1 n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5) numbers
        WHERE LENGTH(p_amenities) - LENGTH(REPLACE(p_amenities, ',', '')) + 1 >= numbers.n;

    -- Declare handler for when cursor reaches the end
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- Insert the property into the Property table, including the status field
    INSERT INTO Property (
        owner_id, address, city, state, zip_code, description, rent_amount, statuss
    ) VALUES (
        p_owner_id, p_address, p_city, p_state, p_zip_code, p_description, p_rent_amount, p_status
    );

    -- Get the ID of the newly inserted property
    SET new_property_id = LAST_INSERT_ID();

    -- Insert the associated images into the PropertyImage table if any
    IF p_image_paths IS NOT NULL AND p_image_paths != '' THEN
        OPEN image_cursor;
        read_loop: LOOP
            FETCH image_cursor INTO image_path;
            IF done THEN
                LEAVE read_loop;
            END IF;

            INSERT INTO PropertyImage (property_id, image_path)
            VALUES (new_property_id, image_path);
        END LOOP;
        CLOSE image_cursor;
    END IF;

    -- Insert the associated amenities into the Amenity table if any
    IF p_amenities IS NOT NULL AND p_amenities != '' THEN
        OPEN amenity_cursor;
        read_amenity_loop: LOOP
            FETCH amenity_cursor INTO amenity_name;
            IF done THEN
                LEAVE read_amenity_loop;
            END IF;

            -- Insert amenity into the Amenity table
            INSERT INTO Amenity (property_id, name, description)
            VALUES (new_property_id, amenity_name, NULL); -- Assuming no description for amenities by default

        END LOOP;
        CLOSE amenity_cursor;
    END IF;

    -- Return the new property ID
    SELECT new_property_id AS property_id;
END //

DELIMITER ;
DELIMITER //

CREATE PROCEDURE OwnerDashboard(
    IN p_owner_id INT
)
BEGIN
    SELECT 
        p.property_id,
        p.address,
        p.city,
        p.state,
        p.zip_code,
        p.description,
        p.rent_amount,
        p.statuss,  -- Added status to the procedure
        GROUP_CONCAT(DISTINCT pi.image_path) AS property_images,
        p.created_at AS property_created_at,
        (
            SELECT COUNT(a.agreement_id) 
            FROM Agreement a 
            WHERE a.property_id = p.property_id
        ) AS active_agreements,
        (
            SELECT GROUP_CONCAT(CONCAT(t.first_name, ' ', t.last_name) SEPARATOR ', ')
            FROM Tenant t 
            WHERE t.property_id = p.property_id
        ) AS tenants -- Added tenants associated with the property
    FROM 
        Property p
    LEFT JOIN 
        PropertyImage pi ON p.property_id = pi.property_id
    WHERE 
        p.owner_id = p_owner_id
    GROUP BY 
        p.property_id,
        p.address,
        p.city,
        p.state,
        p.zip_code,
        p.description,
        p.rent_amount,
        p.statuss,  -- Added status to grouping
        p.created_at
    ORDER BY 
        p.created_at DESC;
END //

DELIMITER //

CREATE PROCEDURE GetPropertyById(
    IN p_property_id INT,
    IN p_owner_id INT
)
BEGIN
    SELECT 
        p.property_id,
        p.address,
        p.city,
        p.state,
        p.zip_code,
        p.description,
        p.rent_amount,
        p.statuss,
        GROUP_CONCAT(DISTINCT pi.image_path) AS property_images,
        (
            SELECT GROUP_CONCAT(CONCAT(t.first_name, ' ', t.last_name)) 
            FROM Tenant t
            WHERE t.property_id = p.property_id
        ) AS tenants
    FROM 
        Property p
    LEFT JOIN 
        PropertyImage pi ON p.property_id = pi.property_id
    WHERE 
        p.property_id = p_property_id AND p.owner_id = p_owner_id
    GROUP BY 
        p.property_id,
        p.address,
        p.city,
        p.state,
        p.zip_code,
        p.description,
        p.rent_amount,
        p.statuss;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE GetAllAvailableProperties()
BEGIN
    SELECT 
        p.property_id,
        p.address,
        p.city,
        p.state,
        p.zip_code,
        p.description,
        p.rent_amount,
        GROUP_CONCAT(DISTINCT pi.image_path) AS property_images,
        p.created_at AS property_created_at,
        (
            SELECT COUNT(a.agreement_id) 
            FROM Agreement a 
            WHERE a.property_id = p.property_id
        ) AS active_agreements
    FROM 
        Property p
    LEFT JOIN 
        PropertyImage pi ON p.property_id = pi.property_id
    WHERE 
        p.statuss = "Available"
    GROUP BY 
        p.property_id,
        p.address,
        p.city,
        p.state,
        p.zip_code,
        p.description,
        p.rent_amount,
        p.created_at,
        p.statuss
    ORDER BY 
        p.created_at DESC;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE AssignPropertyToTenant (
    IN p_tenant_id INT,
    IN p_property_id INT
)
BEGIN
    UPDATE Tenant
    SET property_id = p_property_id
    WHERE tenant_id = p_tenant_id;
END //

DELIMITER ;
