-- 04_copy_data.sql
-- Purpose: Define object storage credential and load raw CSV files into staging tables.
-- Prerequisite: Run after 02_staging_ddl.sql. Requires uploaded files in OCI Object Storage.

BEGIN
  -- Replace with OCI user/tenancy details and an Auth Token from OCI Console:
  -- Identity & Security -> Users -> <user> -> Auth tokens.
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'OBJ_STORE_CRED',
    username        => '<OCI_USER_OR_TENANCY>',
    password        => '<OCI_AUTH_TOKEN>'
  );
END;
/

BEGIN
  DBMS_CLOUD.COPY_DATA(
    table_name      => 'STG_PAYSIM',
    credential_name => 'OBJ_STORE_CRED',
    file_uri_list   => 'https://objectstorage.<region>.oraclecloud.com/n/<namespace>/b/<bucket>/o/PS_20174392719_1491204439457_log.csv',
    format          => JSON_OBJECT('type' VALUE 'csv', 'skipheaders' VALUE 1)
  );

  DBMS_CLOUD.COPY_DATA(
    table_name      => 'STG_LENDING',
    credential_name => 'OBJ_STORE_CRED',
    file_uri_list   => 'https://objectstorage.<region>.oraclecloud.com/n/<namespace>/b/<bucket>/o/lendingclub_5k.csv',
    format          => JSON_OBJECT('type' VALUE 'csv', 'skipheaders' VALUE 1)
  );

  DBMS_CLOUD.COPY_DATA(
    table_name      => 'STG_BANKING77',
    credential_name => 'OBJ_STORE_CRED',
    file_uri_list   => 'https://objectstorage.<region>.oraclecloud.com/n/<namespace>/b/<bucket>/o/banking77_conversations.csv',
    format          => JSON_OBJECT('type' VALUE 'csv', 'skipheaders' VALUE 1)
  );

  DBMS_CLOUD.COPY_DATA(
    table_name      => 'STG_MARKETING',
    credential_name => 'OBJ_STORE_CRED',
    file_uri_list   => 'https://objectstorage.<region>.oraclecloud.com/n/<namespace>/b/<bucket>/o/bank-additional-full.csv',
    format          => JSON_OBJECT('type' VALUE 'csv', 'skipheaders' VALUE 1, 'delimiter' VALUE ';')
  );
END;
/
