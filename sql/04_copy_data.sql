-- 04_copy_data.sql
-- Purpose: Load CSV data from Object Storage into staging tables.
-- Run order: 4
-- Dependencies: sql/02_staging_ddl.sql, uploaded objects in bucket

BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'OBJ_STORE_CRED',
    username => '<oci_user_or_tenancy_ocid>',
    password => '<auth_token>'
  );
END;
/

BEGIN
  DBMS_CLOUD.COPY_DATA(
    table_name      => 'STG_PAYSIM',
    credential_name => 'OBJ_STORE_CRED',
    file_uri_list   => 'https://objectstorage.<region>.oraclecloud.com/n/<namespace>/b/<bucket>/o/raw/paysim/PS_20174392719_1491204439457_log.csv',
    format          => JSON('{"type":"csv","skipheaders":1}')
  );

  DBMS_CLOUD.COPY_DATA(
    table_name      => 'STG_LENDING',
    credential_name => 'OBJ_STORE_CRED',
    file_uri_list   => 'https://objectstorage.<region>.oraclecloud.com/n/<namespace>/b/<bucket>/o/lendingclub_5k.csv',
    format          => JSON('{"type":"csv","skipheaders":1}')
  );

  DBMS_CLOUD.COPY_DATA(
    table_name      => 'STG_BANKING77',
    credential_name => 'OBJ_STORE_CRED',
    file_uri_list   => 'https://objectstorage.<region>.oraclecloud.com/n/<namespace>/b/<bucket>/o/raw/banking77/banking77.csv',
    format          => JSON('{"type":"csv","skipheaders":1}')
  );

  DBMS_CLOUD.COPY_DATA(
    table_name      => 'STG_MARKETING',
    credential_name => 'OBJ_STORE_CRED',
    file_uri_list   => 'https://objectstorage.<region>.oraclecloud.com/n/<namespace>/b/<bucket>/o/raw/uci_marketing/bank-additional-full.csv',
    format          => JSON('{"type":"csv","delimiter":";","skipheaders":1}')
  );
END;
/
