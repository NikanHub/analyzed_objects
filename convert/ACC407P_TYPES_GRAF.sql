CREATE TABLE acc407p_types_graf
    (ctype                          VARCHAR2(10 BYTE) NOT NULL,
    cnote                          VARCHAR2(100 BYTE),
    cregexp                        VARCHAR2(100 BYTE))
/

ALTER TABLE acc407p_types_graf
ADD CONSTRAINT pk_acc407p_types_graf PRIMARY KEY (ctype)
/

COMMENT ON TABLE acc407p_types_graf IS 'Справочник типов объектов поиска и анализа'
/
COMMENT ON COLUMN acc407p_types_graf.cnote IS 'Наименование'
/
COMMENT ON COLUMN acc407p_types_graf.cregexp IS 'Регулярное выражение'
/
COMMENT ON COLUMN acc407p_types_graf.ctype IS 'Тип'
/
