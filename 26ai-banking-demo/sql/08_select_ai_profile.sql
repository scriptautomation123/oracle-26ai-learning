-- 08_select_ai_profile.sql
-- Purpose: Create and activate Select AI profile used for nudge generation.
-- Prerequisite: Run after 01_schema.sql and create OCI credential OCI_GENAI_CRED.

BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'NUDGE_BOT',
    attributes   => '{
      "provider":"oci",
      "credential_name":"OCI_GENAI_CRED",
      "model":"cohere.command-r-plus",
      "object_list":[
        {"owner":"ADMIN","name":"CUSTOMER"},
        {"owner":"ADMIN","name":"TXN"},
        {"owner":"ADMIN","name":"APPLICATION"},
        {"owner":"ADMIN","name":"CONVERSATION_CHUNK"}
      ]
    }'
  );
END;
/

EXEC DBMS_CLOUD_AI.SET_PROFILE('NUDGE_BOT');
