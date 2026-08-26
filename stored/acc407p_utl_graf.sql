CREATE OR REPLACE PACKAGE acc407p_utl_graf
IS

-- n1K@N 23.05.2024
-- справочник объектов поиска и анализа
-- v 1.0.5 26.08.2026

-- возвращает наименование группы/категории
FUNCTION get_grp_name(p_id_grp IN NUMBER) RETURN ACC407P_GRP_GRAF.CGRPNAME%TYPE;

-- возвращает наименование типа объекта из справочника типов
FUNCTION get_obj_type_note(pType IN VARCHAR2) RETURN VARCHAR2;

-- анализ переданной строки
PROCEDURE parse_str(pMess OUT VARCHAR2, pType IN VARCHAR2, pGrp IN NUMBER, pStr IN CLOB);

-- разбор помеченных запросов по 407-П (кастомное решение)
PROCEDURE parse_requests(pMess OUT VARCHAR2, pType IN VARCHAR2, pGrp IN NUMBER, pMARKER_ID IN NUMBER);

-- возвращает объект из хранилища в случае вхождения его в заданную строку
FUNCTION check_str(pStr IN VARCHAR2
                   , pType IN VARCHAR2 DEFAULT 'ALL'  -- тип объекта(из ACC407P_TYPES_GRAF)
                   , pGrp IN NUMBER DEFAULT NULL      -- id группы/категории/вида_проверки(из ACC407P_GRP_GRAF)
                   , pMode IN VARCHAR2 DEFAULT 'LIKE' -- режим поиска (MATCH-точное совпадение; LIKE-поиск подстроки)
) RETURN VARCHAR2;

-- удалить все объекты указанного типа
PROCEDURE del_obj_type(pType acc407p_graf.ctype%TYPE);

-- добавить объект в группу
PROCEDURE ins_acc_grp(p_acc_id IN NUMBER, p_grp_id IN NUMBER DEFAULT NULL);

-- удалить объект из группы
PROCEDURE del_acc_grp(p_acc_id IN NUMBER, p_grp_id IN NUMBER DEFAULT NULL);

-- изменить состав групп для объекта
PROCEDURE upd_group_members(p_acc_id IN NUMBER, p_mode IN VARCHAR2, p_grp_id IN NUMBER DEFAULT NULL);

END acc407p_utl_graf;
/
CREATE OR REPLACE PACKAGE BODY acc407p_utl_graf
IS

vIgnoreAccCard VARCHAR2(64) := '`~!@#$%^&*()-_+=[]{}"''<>?/\|'||chr(10);
vIgnoreEmail VARCHAR2(64) := '&?=+#%}{\[]|^<>*$!~`,()';
vRus VARCHAR2(64) := 'АВЕКМНОРСТХ';
vEng VARCHAR2(64) := 'ABEKMHOPCTX';
C_T_EMAIL CONSTANT VARCHAR2(10) := 'EMAIL'; -- стандартный тип для email

-- сохранить новый объект
FUNCTION ins_obj(pObj acc407p_graf.cacc%TYPE, pType acc407p_graf.ctype%TYPE) RETURN NUMBER
IS
  vId NUMBER;
BEGIN
  INSERT INTO acc407p_graf(CACC,CTYPE)
  VALUES(pObj,pType)
  RETURNING IID INTO vId;
  
  RETURN vId;
END;

-- изменить объект
PROCEDURE upd_obj(pObj acc407p_graf.cacc%TYPE, pType acc407p_graf.ctype%TYPE)
IS
BEGIN
  UPDATE acc407p_graf SET 
    CACC = pObj,
    CTYPE = pType
  WHERE CACC = pObj
        AND CTYPE = pType;
END;

-- удалить объект
PROCEDURE del_obj(pObj acc407p_graf.cacc%TYPE, pType acc407p_graf.ctype%TYPE)
IS
BEGIN
  DELETE acc407p_graf
  WHERE CACC = pObj
        AND CTYPE = pType;
END;

FUNCTION get_grp_name(p_id_grp IN NUMBER) RETURN ACC407P_GRP_GRAF.CGRPNAME%TYPE
IS
  vret ACC407P_GRP_GRAF.CGRPNAME%TYPE;
BEGIN
  SELECT CGRPNAME INTO vret 
  FROM ACC407P_GRP_GRAF g
  WHERE g.igrpid = p_id_grp;
  
  RETURN vret;
EXCEPTION WHEN no_data_found THEN
  RETURN '<Noname>';
END;

PROCEDURE del_obj_type(pType acc407p_graf.ctype%TYPE)
IS
BEGIN
  DELETE acc407p_graf
  WHERE CTYPE = pType;
END;

FUNCTION get_obj_type_note(pType IN VARCHAR2) RETURN VARCHAR2
IS
    cNote acc407p_types_graf.CNOTE%TYPE;
    CURSOR cCUR IS
        SELECT CNOTE FROM acc407p_types_graf
            WHERE CTYPE = pType;
BEGIN
    OPEN cCUR;
    FETCH cCUR INTO cNote;
    CLOSE cCUR;
    RETURN NVL(cNote,'Неизвестно');
END get_obj_type_note;


PROCEDURE parse_str(pMess OUT VARCHAR2, pType IN VARCHAR2, pGrp IN NUMBER, pStr IN CLOB)
IS
    cPatt VARCHAR2(254);
    iCntAll NUMBER := 0;
    iCntIns NUMBER := 0;
    iCntDup NUMBER := 0;
    vStr CLOB := pStr; 
    vObj acc407p_graf.cacc%TYPE;
    iObjId NUMBER;
    CURSOR curTypes IS
        SELECT CREGEXP FROM acc407p_types_graf
            WHERE CTYPE = pType;
BEGIN
    IF pStr IS NULL THEN
        pMess := 'Не указана строка для анализа.';
        RETURN;
    ELSIF pType IS NULL THEN
        pMess := 'Не указан тип обрабатываемых данных '||pType;
        RETURN;
    END IF;

    IF pType = C_T_EMAIL THEN
        vStr := REPLACE(TRANSLATE(vStr,vIgnoreEmail,RPAD(' ',LENGTH(vIgnoreEmail))),' ',''); -- убираем символы
    ELSE
        vStr := REPLACE(TRANSLATE(vStr,vIgnoreAccCard,RPAD(' ',LENGTH(vIgnoreAccCard))),' ',''); -- убираем символы
        vStr := TRANSLATE(vStr,vRus,vEng); -- русские буквы заменяем латинскими
    END IF;

    OPEN curTypes;
    FETCH curTypes INTO cPatt;
    CLOSE curTypes;
    IF cPatt IS NULL THEN
        pMess := 'Не указано регулярное выражение для типа данных '||pType; RETURN;
    END IF;
    cPatt := '\W'||cPatt;
    vStr := ' '||vStr; -- добавим пробел вначале, ибо вначале любой строки ожидается пробел(пошло из 407-П)
    dbms_output.put_line('Строка для анализа: '||vStr);
    FOR rOBJ IN (SELECT SUBSTR(regexp_substr(obj, patt, 1, rownum),2) rez_obj
                    FROM (SELECT vStr AS obj
                    , cPatt AS patt FROM dual) dual
                    CONNECT BY level <= regexp_count(obj, patt)
                )
    LOOP
      vObj := rOBJ.rez_obj;
      IF vObj IS NOT NULL THEN
        iCntAll := iCntAll + 1;
        begin
            iObjId := ins_obj(vObj,pType);
            upd_group_members(iObjId,'I',pGrp);
            iCntIns := iCntIns + 1;
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
            iCntDup := iCntDup + 1;
        END;
      END IF;
    END LOOP;

    pMess := 'Обработано всего объектов - '||iCntAll||CHR(10)||
            'Успешно сохранено объектов - '||iCntIns||CHR(10)||
            'Игнорировано дубликатов - '||iCntDup
    ;
EXCEPTION WHEN OTHERS THEN
  pMess := 'Непредвиденная ошибка обработки: '||SQLERRM;
END parse_str;

PROCEDURE parse_requests(pMess OUT VARCHAR2, pType IN VARCHAR2, pGrp IN NUMBER, pMARKER_ID IN NUMBER)
IS
BEGIN
    IF pMARKER_ID IS NULL THEN
        pMess := 'Нет помеченных запросов.';
        RETURN;
    END IF;
    
    FOR rREQ IN (SELECT CCLIENT_OTHER_INFO FROM wash_requests7, mrk_id
                    WHERE IDMARKER = pMARKER_ID
                    AND IDROW = IID
                    AND CCLIENT_OTHER_INFO IS NOT NULL)
    LOOP
        parse_str(pMess, pType, pGrp, rREQ.CCLIENT_OTHER_INFO);
    END LOOP;
END parse_requests;

FUNCTION check_str(pStr IN VARCHAR2
                   , pType IN VARCHAR2 DEFAULT 'ALL'
                   , pGrp IN NUMBER DEFAULT NULL
                   , pMode IN VARCHAR2 DEFAULT 'LIKE'
) RETURN VARCHAR2
IS
BEGIN
    FOR rOBJ IN (SELECT CACC FROM acc407p_graf a
                 LEFT JOIN acc407p_acc_grp_graf g ON a.iid = g.iaccid
                 WHERE CTYPE = DECODE(pType ,'ALL',CTYPE, pType)
                 AND NVL(g.igrpid,'-999') = NVL(pGrp,NVL(g.igrpid,'-999'))
                )
    LOOP
        IF upper(pMode) = 'MATCH' AND UPPER(pStr) = UPPER(rOBJ.CACC)
           OR upper(pMode) = 'LIKE' AND UPPER(pStr) LIKE '%'||UPPER(rOBJ.CACC)||'%'
        THEN
            RETURN rOBJ.CACC;
        END IF;
    END LOOP;
    RETURN NULL;
END check_str;

PROCEDURE ins_acc_grp(p_acc_id IN NUMBER, p_grp_id IN NUMBER DEFAULT NULL) 
IS
BEGIN
  IF p_grp_id IS NOT NULL THEN
    INSERT INTO acc407p_acc_grp_graf(IACCID,IGRPID)
    VALUES(p_acc_id,p_grp_id);
  ELSE
    INSERT INTO acc407p_acc_grp_graf(IACCID,IGRPID)
    SELECT p_acc_id, igrpid FROM acc407p_grp_graf 
     WHERE igrpid NOT IN 
           (SELECT igrpid FROM acc407p_acc_grp_graf
            WHERE IACCID = p_acc_id);
  END IF;
END ins_acc_grp;

PROCEDURE del_acc_grp(p_acc_id IN NUMBER, p_grp_id IN NUMBER DEFAULT NULL) 
IS
BEGIN
  DELETE FROM acc407p_acc_grp_graf
  WHERE IACCID = p_acc_id
    AND IGRPID = nvl(p_grp_id,IGRPID);
END del_acc_grp;

PROCEDURE upd_group_members(p_acc_id IN NUMBER, p_mode IN VARCHAR2, p_grp_id IN NUMBER DEFAULT NULL)
IS
BEGIN
  IF p_mode = 'I' THEN
    ins_acc_grp(p_acc_id,p_grp_id);
  ELSIF p_mode = 'D' THEN
    del_acc_grp(p_acc_id,p_grp_id);
  END IF;
END upd_group_members;

END acc407p_utl_graf;
/
