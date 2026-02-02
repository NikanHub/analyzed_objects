SET DEFINE OFF
SPOOL runme.log

SELECT USER || '@' || GLOBAL_NAME || ' ' || TO_CHAR (SYSDATE, 'DD.MM.YYYY HH24:MI:SS') "Script processed on"
       FROM GLOBAL_NAME
/

PROMPT s_acc407p_graf.sql
@@s_acc407p_graf.sql
SHOW ERRORS

PROMPT acc407p_utl_graf.sql
@@acc407p_utl_graf.sql
SHOW ERRORS

PROMPT v_acc407p_graf.sql
@@v_acc407p_graf.sql
SHOW ERRORS

SPOOL OFF
