-- 08_select_ai_profile.sql
-- Purpose: Configure Select AI profile for agentic nudge generation.
-- Run order: 8
-- Dependencies: OCI Generative AI credential and object grants

BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'NUDGE_BOT',
    attributes   => JSON_OBJECT(
      'provider' VALUE 'oci',
      'credential_name' VALUE 'OCI_GENAI_CRED',
      'model' VALUE 'cohere.command-r-plus',
      'object_list' VALUE JSON_ARRAY(
        JSON_OBJECT('owner' VALUE USER, 'name' VALUE 'CUSTOMER'),
        JSON_OBJECT('owner' VALUE USER, 'name' VALUE 'ACCOUNT'),
        JSON_OBJECT('owner' VALUE USER, 'name' VALUE 'TXN'),
        JSON_OBJECT('owner' VALUE USER, 'name' VALUE 'APPLICATION'),
        JSON_OBJECT('owner' VALUE USER, 'name' VALUE 'CONVERSATION_CHUNK')
      )
    )
  );
END;
/

BEGIN
  DBMS_CLOUD_AI.SET_PROFILE('NUDGE_BOT');
END;
/
