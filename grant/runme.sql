SET DEFINE OFF
SPOOL runme.log

SELECT USER || '@' || GLOBAL_NAME || ' ' || TO_CHAR (SYSDATE, 'DD.MM.YYYY HH24:MI:SS') "Script processed on"
       FROM GLOBAL_NAME
/

PROMPT grants.sql
@@grants.sql
SHOW ERRORS

SPOOL OFF
