CREATE OR REPLACE FORCE VIEW v_acc407p_graf (
   iid,
   cacc,
   ctype,
   ctype_note,
   ddate )
AS
SELECT "IID","CACC","CTYPE",acc407p_utl_graf.get_obj_type_note(CTYPE) CTYPE_NOTE,"DDATE" FROM acc407p_graf
/
COMMENT ON TABLE v_acc407p_graf IS 'Представление для справочника объектов'
/
