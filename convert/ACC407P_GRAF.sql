CREATE TABLE acc407p_graf
    (iid                            NUMBER ,
    cacc                           VARCHAR2(100 BYTE),
    ctype                          VARCHAR2(10 BYTE),
    ddate                          DATE DEFAULT trunc(Sysdate

))
/


ALTER TABLE acc407p_graf
ADD CONSTRAINT uk_acc407p_graf UNIQUE (cacc, ctype)
/

ALTER TABLE acc407p_graf
ADD CONSTRAINT pk_acc407p_graf PRIMARY KEY (iid)
/

CREATE OR REPLACE TRIGGER tbu_acc407p_graf
 BEFORE
  UPDATE
 ON acc407p_graf
REFERENCING NEW AS NEW OLD AS OLD
 FOR EACH ROW
BEGIN
    :NEW.DDATE := SYSDATE;
END;
/

CREATE OR REPLACE TRIGGER tbi_acc407p_graf
 BEFORE
  INSERT
 ON acc407p_graf
REFERENCING NEW AS NEW OLD AS OLD
 FOR EACH ROW
WHEN (new.iid is null)
BEGIN
    SELECT s_acc407p_graf.NEXTVAL INTO :NEW.IID FROM dual ;
END;
/

COMMENT ON TABLE acc407p_graf IS 'Справочник объектов поиска и анализа'
/
COMMENT ON COLUMN acc407p_graf.cacc IS 'Счет/карта/строка'
/
COMMENT ON COLUMN acc407p_graf.ctype IS 'Тип(ACC,CARD,...)'
/
COMMENT ON COLUMN acc407p_graf.ddate IS 'Дата добавления'
/
COMMENT ON COLUMN acc407p_graf.iid IS 'ID'
/
ALTER TABLE acc407p_graf
ADD CONSTRAINT fk_acc407p_ctype_graf FOREIGN KEY (ctype)
REFERENCES acc407p_types_graf (ctype)
/
