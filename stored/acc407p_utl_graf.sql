CREATE OR REPLACE PACKAGE acc407p_utl_graf
IS

-- n1K@N 23.05.2024
-- справочник объектов хранения и анализа
-- v 1.0.2 02.02.2026

-- возвращает наименование типа объекта из справочника типов
FUNCTION get_obj_type_note(pType IN VARCHAR2) RETURN VARCHAR2;

-- анализ переданной строки
PROCEDURE parce_str(pMess OUT VARCHAR2, pType IN VARCHAR2, pStr IN CLOB);

-- разбор помеченных запросов по 407-П (кастомное решение)
PROCEDURE parce_requests(pMess OUT VARCHAR2, pType IN VARCHAR2, pMARKER_ID IN NUMBER);

-- возвращает объект из хранилища в случае вхождения его в заданную строку
FUNCTION check_str(pStr IN VARCHAR2, pType IN VARCHAR2 DEFAULT 'ALL') RETURN VARCHAR2;

END acc407p_utl_graf;
/
CREATE OR REPLACE PACKAGE BODY acc407p_utl_graf
IS

vIgnoreAccCard VARCHAR2(64) := '`~!@#$%^&*()-_+=[]{}"''<>?/\|'||chr(10);
vIgnoreEmail VARCHAR2(64) := '&?=+#%}{\[]|^<>*$!~`,()';
vRus VARCHAR2(64) := 'АВЕКМНОРСТХ';
vEng VARCHAR2(64) := 'ABEKMHOPCTX';
C_T_EMAIL CONSTANT VARCHAR2(10) := 'EMAIL'; -- стандартный тип для email

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


PROCEDURE parce_str(pMess OUT VARCHAR2, pType IN VARCHAR2, pStr IN CLOB)
IS
    cPatt VARCHAR2(254);
    iCntAll NUMBER := 0;
    iCntIns NUMBER := 0;
    iCntDup NUMBER := 0;
    vStr CLOB := pStr;
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
    dbms_output.put_line('Строка для анализа: '||vStr);
    FOR rOBJ IN (SELECT SUBSTR(regexp_substr(obj, patt, 1, rownum),2) rez_obj
                    FROM (SELECT vStr AS obj
                    , cPatt AS patt FROM dual) dual
                    CONNECT BY level <= regexp_count(obj, patt)
                )
    LOOP
        IF rOBJ.rez_obj IS NOT NULL THEN
            iCntAll := iCntAll + 1;
            begin
                INSERT INTO acc407p_graf(CACC,CTYPE)
                VALUES(rOBJ.rez_obj,pType);
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
END parce_str;

PROCEDURE parce_requests(pMess OUT VARCHAR2, pType IN VARCHAR2, pMARKER_ID IN NUMBER)
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
        parce_str(pMess, pType, rREQ.CCLIENT_OTHER_INFO);
    END LOOP;
END parce_requests;

FUNCTION check_str(pStr IN VARCHAR2, pType IN VARCHAR2 DEFAULT 'ALL') RETURN VARCHAR2
IS
BEGIN
    FOR rOBJ IN (SELECT CACC FROM acc407p_graf WHERE CTYPE = DECODE(pType ,'ALL',CTYPE, pType))
    LOOP
        IF UPPER(pStr) LIKE '%'||UPPER(rOBJ.CACC)||'%' THEN
            RETURN rOBJ.CACC;
        END IF;
    END LOOP;
    RETURN NULL;
END check_str;

END acc407p_utl_graf;
/
