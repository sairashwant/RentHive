create database renthive8;
use renthive8;
CREATE TABLE Owner (
    owner_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL, 
    first_name VARCHAR(100) NOT NULL,  
    last_name VARCHAR(100) NOT NULL,   
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
    property_id INT DEFAULT NULL, 
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (property_id) REFERENCES Property(property_id) ON DELETE SET NULL
);

CREATE TABLE PropertyImage (
    image_id INT AUTO_INCREMENT PRIMARY KEY,
    property_id INT NOT NULL,       
    image_path VARCHAR(255) NOT NULL, 
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
    FOREIGN KEY (property_id) REFERENCES Property(property_id)
);


-- Notifications Table
CREATE TABLE Notifications (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    property_id INT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
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
    DECLARE user_type VARCHAR(10);
    
    SELECT 'owner' INTO user_type
    FROM owner
    WHERE username = p_username AND password = p_password
    LIMIT 1;
    
    IF user_type IS NULL THEN
        SELECT 'tenant' INTO user_type
        FROM tenant
        WHERE username = p_username AND password = p_password
        LIMIT 1;
    END IF;
    
    IF user_type IS NULL THEN
        SET user_type = NULL;
    END IF;

    SELECT user_type;
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
        p.statuss, 
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
        p.owner_id = p_owner_id
    GROUP BY 
        p.property_id,
        p.address,
        p.city,
        p.state,
        p.zip_code,
        p.description,
        p.rent_amount,
        p.statuss, 
        p.created_at
    ORDER BY 
        p.created_at DESC;
END //
DELIMITER ;


-- Procedure to get a specific property by ID for editing
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
        GROUP_CONCAT(DISTINCT pi.image_path) AS property_images
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


DELIMITER //
CREATE PROCEDURE MakePayment (
    IN p_tenant_id INT,
    IN p_agreement_id INT,
    IN p_amount DECIMAL(10, 2),
    IN p_payment_type ENUM('Deposit', 'Rent')
)
BEGIN
    -- Insert payment record
    INSERT INTO Payment (agreement_id, tenant_id, payment_date, amount, payment_type)
    VALUES (p_agreement_id, p_tenant_id, CURRENT_DATE, p_amount, p_payment_type);
    
    -- Return the payment ID
    SELECT LAST_INSERT_ID() AS payment_id;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE ViewOwnerPaymentHistory (
    IN p_owner_id INT
)
BEGIN
    SELECT 
        t.first_name AS tenant_first_name,
        t.last_name AS tenant_last_name,
        p.address AS property_address,
        pay.payment_date,
        pay.amount,
        pay.payment_type
    FROM 
        Payment pay
    JOIN 
        Agreement ag ON ag.agreement_id = pay.agreement_id
    JOIN 
        Property p ON p.property_id = ag.property_id
    JOIN 
        Tenant t ON t.tenant_id = pay.tenant_id
    WHERE 
        p.owner_id = p_owner_id
    ORDER BY 
        pay.payment_date DESC;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE GetAgreementIdByTenantId (
    IN tenant_id INT
)
BEGIN
    -- Get the agreement_id for the provided tenant_id
    SELECT agreement_id
    FROM agreementtenant
    WHERE tenant_id = tenant_id
    LIMIT 1; -- Limit to one result, assuming the tenant has only one active agreement
END //
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE SubmitMaintenanceRequestForm (
    IN in_tenant_id INT,
    IN description TEXT
)
BEGIN
    DECLARE property_ids INT;
    -- Fetch the property_id for the tenant
    SELECT property_id INTO property_ids
    FROM Tenant
    WHERE tenant_id = in_tenant_id
    LIMIT 1;

    IF property_ids IS NULL THEN
        -- If no property found, raise an error
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No property found for the tenant';
    ELSE
        -- Proceed with inserting the maintenance request if property_id is valid
        INSERT INTO MaintenanceRequest (tenant_id, property_id, request_date, status, description)
        VALUES (in_tenant_id, property_ids, CURDATE(), 'Open', description);
    END IF;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE view_maintenance_request_status(
    IN tenant_id INT
)
BEGIN
    SELECT request_id, property_id, status, request_date, description
    FROM MaintenanceRequest
    WHERE tenant_id = tenant_id;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE owner_view_maintenance_requests(
    IN owner_id INT
)
BEGIN
    SELECT mr.request_id, mr.tenant_id, mr.property_id, mr.request_date, mr.status, mr.description
    FROM MaintenanceRequest mr
    JOIN Property p ON mr.property_id = p.property_id
    WHERE p.owner_id = owner_id;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE owner_update_maintenance_status(
    IN owner_id INT,
    IN request_id_input INT,
    IN new_status ENUM('Open', 'In Progress', 'Completed')
)
BEGIN
    -- Check if the owner is authorized to update the maintenance request
    IF EXISTS (SELECT 1 
               FROM MaintenanceRequest mr
               JOIN Property p ON mr.property_id = p.property_id
               WHERE p.owner_id = owner_id AND mr.request_id = request_id) THEN
               
        -- Update the status of the maintenance request
        UPDATE MaintenanceRequest
        SET status = new_status
        WHERE request_id = request_id_input;

    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Owner is not authorized to update this maintenance request';
    END IF;
END $$
DELIMITER ;

SET SQL_SAFE_UPDATES = 0;

DELIMITER //
CREATE PROCEDURE CreateNotification(
    IN p_owner_id INT,
    IN p_property_id INT,
    IN p_message TEXT
)
BEGIN
    -- Verify owner owns the property
    IF EXISTS (SELECT 1 FROM Property WHERE property_id = p_property_id AND owner_id = p_owner_id) THEN
        INSERT INTO Notifications (property_id, message, created_at)
        VALUES (p_property_id, p_message, CURRENT_TIMESTAMP);
        SELECT LAST_INSERT_ID() as notification_id;
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Unauthorized: Property does not belong to this owner';
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE GetOwnerNotifications(IN owner_id INT)
BEGIN
    SELECT 
        p.property_id,
        n.message,
        n.created_at AS sent_at
    FROM Notifications n
    JOIN Property p ON n.property_id = p.property_id
    WHERE p.owner_id = owner_id
    ORDER BY n.created_at DESC;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE GetTenantNotifications(
    IN p_tenant_id INT
)
BEGIN
    SELECT 
        n.notification_id,
        n.message,
        n.created_at AS sent_at,
        p.address as property_address
    FROM Notifications n
    JOIN Property p ON n.property_id = p.property_id
    JOIN Tenant t ON t.property_id = p.property_id
    WHERE t.tenant_id = p_tenant_id
    ORDER BY n.created_at DESC;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE UpdatePropertyDetails (
    IN p_property_id INT,
    IN p_owner_id INT,
    IN p_address VARCHAR(255),
    IN p_city VARCHAR(100),
    IN p_state VARCHAR(100),
    IN p_zip_code VARCHAR(20),
    IN p_description TEXT,
    IN p_rent_amount DECIMAL(10, 2),
    IN p_status VARCHAR(50)
)
BEGIN
    UPDATE Property 
    SET 
        address = p_address, 
        city = p_city, 
        state = p_state, 
        zip_code = p_zip_code, 
        description = p_description, 
        rent_amount = p_rent_amount, 
        statuss = p_status
    WHERE 
        property_id = p_property_id AND owner_id = p_owner_id;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE GetLeaseAgreementDetails(IN agreement_id INT, IN owner_id INT)
BEGIN
    SELECT * FROM lease_agreements WHERE agreement_id = agreement_id AND owner_id = owner_id;
END //
DELIMITER ;



DELIMITER $$
CREATE PROCEDURE GetOwnerLeaseAgreements(IN owner_id INT)
BEGIN
    SELECT 
        a.agreement_id, 
        p.address AS property_name, 
        GROUP_CONCAT(CONCAT(t.first_name, ' ', t.last_name) ORDER BY t.first_name) AS tenant_names,
        a.start_date,
        a.end_date
    FROM Agreement a
    JOIN Property p ON a.property_id = p.property_id
    JOIN AgreementTenant at ON a.agreement_id = at.agreement_id
    JOIN Tenant t ON at.tenant_id = t.tenant_id
    WHERE p.owner_id = owner_id
    GROUP BY a.agreement_id, p.address, a.start_date, a.end_date;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE CreateAgreement(
    IN property_id INT,
    IN tenant_usernames JSON,
    IN pdf_link_path VARCHAR(255),
    IN start_date DATE,
    IN end_date DATE
)
BEGIN
    DECLARE agreement_id INT;
    DECLARE tenant_id INT;
    DECLARE tenant_count INT DEFAULT 0;

    -- Start a transaction
    START TRANSACTION;

    -- Insert into Agreement
    INSERT INTO Agreement (property_id, pdf_link, start_date, end_date)
    VALUES (property_id, pdf_link_path, start_date, end_date);
    SET agreement_id = LAST_INSERT_ID();

    -- Update property status to "Rented"
    UPDATE Property
    SET statuss = 'Rented'
    WHERE property_id = property_id;

    -- Iterate through tenant usernames and link tenants to agreement
    WHILE tenant_count < JSON_LENGTH(tenant_usernames) DO
        SET tenant_id = JSON_UNQUOTE(JSON_EXTRACT(tenant_usernames, CONCAT('$[', tenant_count, ']')));

        -- Link tenant to agreement
        INSERT INTO AgreementTenant (agreement_id, tenant_id)
        VALUES (agreement_id, tenant_id);

        -- Update tenant's property_id
        UPDATE Tenant
        SET property_id = property_id
        WHERE tenant_id = tenant_id;

        SET tenant_count = tenant_count + 1;
    END WHILE;

    -- Commit transaction
    COMMIT;

END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE AddProperty(
    IN owner_id INT,
    IN address VARCHAR(255),
    IN city VARCHAR(100),
    IN state VARCHAR(100),
    IN zip_code VARCHAR(20),
    IN description TEXT,
    IN rent_amount DECIMAL(10, 2),
    IN status VARCHAR(50),
    IN images JSON
)
BEGIN
    DECLARE property_id INT;
    DECLARE image_path VARCHAR(255);
    DECLARE image_count INT DEFAULT 0;

    -- Start a transaction
    START TRANSACTION;

    -- Insert the property into the Property table
    INSERT INTO Property (owner_id, address, city, state, zip_code, description, rent_amount, statuss)
    VALUES (owner_id, address, city, state, zip_code, description, rent_amount, status);
    SET property_id = LAST_INSERT_ID();

    -- Iterate through image paths and insert into PropertyImage
    WHILE image_count < JSON_LENGTH(images) DO
        SET image_path = JSON_UNQUOTE(JSON_EXTRACT(images, CONCAT('$[', image_count, ']')));

        INSERT INTO PropertyImage (property_id, image_path)
        VALUES (property_id, image_path);

        SET image_count = image_count + 1;
    END WHILE;

    -- Commit the transaction
    COMMIT;

END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE GetTenantLeaseAgreements(
    IN tenant_id INT
)
BEGIN
    SELECT a.agreement_id, p.address, a.start_date, a.end_date
    FROM Agreement a
    JOIN Property p ON a.property_id = p.property_id
    JOIN AgreementTenant at ON a.agreement_id = at.agreement_id
    WHERE at.tenant_id = tenant_id;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE GetTenantAgreement(
    IN agreement_id INT,
    IN tenant_id INT
)
BEGIN
    SELECT a.agreement_id, p.address, a.pdf_link, a.start_date, a.end_date
    FROM Agreement a
    JOIN Property p ON a.property_id = p.property_id
    JOIN AgreementTenant at ON a.agreement_id = at.agreement_id
    WHERE a.agreement_id = agreement_id AND at.tenant_id = tenant_id;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE GetAvailablePropertiesofOwner(
    IN owner_id INT
)
BEGIN
    SELECT property_id, CONCAT(address, ', ', city) AS name
    FROM Property
    WHERE owner_id = owner_id AND statuss = 'Available';
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE GetAvailableTenants()
BEGIN
    SELECT tenant_id, CONCAT(first_name, ' ', last_name) AS name
    FROM Tenant
    WHERE property_id IS NULL;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE update_lease_agreement(
    IN agreement_id INT,
    IN start_date DATE,
    IN end_date DATE,
    IN pdf_link VARCHAR(255)
)
BEGIN
    -- Update lease agreement with or without the PDF link
    IF pdf_link IS NOT NULL AND pdf_link != '' THEN
        UPDATE Agreement
        SET start_date = start_date, 
            end_date = end_date,
            pdf_link = pdf_link
        WHERE agreement_id = agreement_id;
    ELSE
        UPDATE Agreement
        SET start_date = start_date, 
            end_date = end_date
        WHERE agreement_id = agreement_id;
    END IF;
END$$
DELIMITER ;

DELIMITER //
CREATE PROCEDURE GetAllAvailablePropertiesHome()
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
        o.email AS owner_email,
        GROUP_CONCAT(pi.image_path) AS property_images
    FROM 
        Property p
    JOIN 
        owner o ON p.owner_id = o.owner_id
    LEFT JOIN 
        PropertyImage pi ON p.property_id = pi.property_id
    WHERE 
        p.statuss = 'Available'
    GROUP BY 
        p.property_id, 
        p.address, 
        p.city, 
        p.state, 
        p.zip_code, 
        p.description, 
        p.rent_amount, 
        p.statuss,
        o.email;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE DeleteProperty(
    IN p_property_id INT, 
    IN p_owner_id INT
)
BEGIN
    DECLARE property_count INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Start transaction
    START TRANSACTION;

    -- Check if the property belongs to the owner
    SELECT COUNT(*) INTO property_count
    FROM Property
    WHERE property_id = p_property_id AND owner_id = p_owner_id;

    -- If property doesn't belong to the owner, raise an error
    IF property_count = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Property not found or you are not authorized to delete it';
    END IF;

    -- Delete associated images first
    DELETE FROM PropertyImage 
    WHERE property_id = p_property_id;

    -- Delete associated agreement tenants
    DELETE FROM AgreementTenant 
    WHERE agreement_id IN (
        SELECT agreement_id 
        FROM Agreement 
        WHERE property_id = p_property_id
    );

    -- Delete associated agreements
    DELETE FROM Agreement 
    WHERE property_id = p_property_id;

    -- Delete associated maintenance requests
    DELETE FROM MaintenanceRequest 
    WHERE property_id = p_property_id;

    -- Update tenants who were associated with this property
    UPDATE Tenant 
    SET property_id = NULL 
    WHERE property_id = p_property_id;

    -- Delete the property
    DELETE FROM Property 
    WHERE property_id = p_property_id AND owner_id = p_owner_id;

    -- Commit the transaction
    COMMIT;
END //
DELIMITER ;
DELIMITER $$
CREATE PROCEDURE DeleteLeaseAgreement(
    IN p_agreement_id INT,
    IN p_user_id INT -- Assuming this is the owner ID for authorization
)
BEGIN
    DECLARE v_tenant_id INT;
    DECLARE v_property_id INT;

    -- Declare handlers for error management
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Get the tenant ID associated with the agreement
    SELECT tenant_id INTO v_tenant_id
    FROM AgreementTenant
    WHERE agreement_id = p_agreement_id
    LIMIT 1;

    IF v_tenant_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lease agreement not found or already deleted';
    END IF;

    -- Delete the lease agreement
    DELETE FROM Agreement
    WHERE agreement_id = p_agreement_id;

    -- Check if the tenant has any remaining lease agreements
    IF (SELECT COUNT(*) FROM AgreementTenant WHERE tenant_id = v_tenant_id) = 0 THEN
        -- If no remaining agreements, set the property_id in the Tenant table to NULL
        UPDATE Tenant
        SET property_id = NULL
        WHERE tenant_id = v_tenant_id;
    END IF;

    COMMIT;

    -- Optionally, return a success message or the deleted agreement ID
    SELECT p_agreement_id AS deleted_agreement_id;
END $$
DELIMITER ;
DELIMITER $$
CREATE PROCEDURE CreateLeaseAgreement(
    IN p_property_id INT,
    IN p_tenant_emails TEXT, -- A comma-separated list of tenant emails
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_pdf_link VARCHAR(255)
)
BEGIN
    DECLARE v_agreement_id INT;
    DECLARE v_owner_id INT;
    DECLARE v_email VARCHAR(100);
    DECLARE v_tenant_id INT;

    -- Declare handlers for error management
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Validate property availability
    SELECT owner_id INTO v_owner_id
    FROM Property
    WHERE property_id = p_property_id AND statuss = 'Available'
    LIMIT 1;

    IF v_owner_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Property is not available for lease';
    END IF;

    -- Insert Agreement
    INSERT INTO Agreement (
        property_id,
        start_date,
        end_date,
        pdf_link
    ) VALUES (
        p_property_id,
        p_start_date,
        p_end_date,
        p_pdf_link
    );

    -- Get the last inserted agreement ID
    SET v_agreement_id = LAST_INSERT_ID();

    -- Split and process tenant emails
    WHILE LOCATE(',', p_tenant_emails) > 0 DO
        SET v_email = TRIM(SUBSTRING_INDEX(p_tenant_emails, ',', 1));
        SET p_tenant_emails = TRIM(SUBSTRING(p_tenant_emails FROM LOCATE(',', p_tenant_emails) + 1));

        -- Validate tenant existence or allow existing tenant for the same property
        SELECT tenant_id INTO v_tenant_id
        FROM Tenant
        WHERE email = v_email AND (property_id IS NULL OR property_id = p_property_id)
        LIMIT 1;

        IF v_tenant_id IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tenant with that email not found or already assigned to a different property';
        END IF;

        -- Link tenant to agreement
        INSERT INTO AgreementTenant (
            agreement_id,
            tenant_id
        ) VALUES (
            v_agreement_id,
            v_tenant_id
        );

        -- Update tenant's property if they are not already linked to it
        IF (SELECT property_id FROM Tenant WHERE tenant_id = v_tenant_id) IS NULL THEN
            UPDATE Tenant
            SET property_id = p_property_id
            WHERE tenant_id = v_tenant_id;
        END IF;
    END WHILE;

    -- Handle the last email (if any)
    IF p_tenant_emails != '' THEN
        SET v_email = TRIM(p_tenant_emails);

        SELECT tenant_id INTO v_tenant_id
        FROM Tenant
        WHERE email = v_email AND (property_id IS NULL OR property_id = p_property_id)
        LIMIT 1;

        IF v_tenant_id IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tenant with that email not found or already assigned to a different property';
        END IF;

        INSERT INTO AgreementTenant (
            agreement_id,
            tenant_id
        ) VALUES (
            v_agreement_id,
            v_tenant_id
        );

        -- Update tenant's property if they are not already linked to it
        IF (SELECT property_id FROM Tenant WHERE tenant_id = v_tenant_id) IS NULL THEN
            UPDATE Tenant
            SET property_id = p_property_id
            WHERE tenant_id = v_tenant_id;
        END IF;
    END IF;

    COMMIT;

    -- Return the created agreement ID
    SELECT v_agreement_id AS agreement_id;
END $$
DELIMITER ;
select * from tenant;

DELIMITER //

CREATE PROCEDURE GetOwnerProperties(IN ownerId INT)
BEGIN
    SELECT property_id, address FROM Property WHERE owner_id = ownerId;
END //

DELIMITER ;
select * from tenant;