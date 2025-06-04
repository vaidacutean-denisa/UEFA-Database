--1. Să se afișeze jucătorii care au marcat goluri din faze fixe (Penalty, Lovitură liberă sau Corner) în meciuri desfășurate pe stadioane cu capacitate mai mică
--decât media capacităților stadioanelor pe care echipa lor a jucat în deplasare în competițiile europene de club.
--Pentru fiecare jucător se va afișa numele complet, vârsta în ani și echipa pentru care joacă.
--Precizări: O echipă care joacă în deplasare are rolul de oaspete; vârsta JUCATORilor va fi raportată la sfârșitul sezonului 2015-2016 (01-07-2016)

SELECT DISTINCT
    J.PRENUME || ' ' || J.NUME AS NUME_JUCATOR,                       
    E.NUME AS NUME_ECHIPA,
    TRUNC(MONTHS_BETWEEN (TO_DATE('01-07-2016', 'DD-MM-YYYY'), J.DATA_NASTERII) / 12) AS VARSTA         --- funcții pe date calendaristice
FROM JUCATOR J
JOIN ECHIPA E ON J.ID_ECHIPA = E.ID_ECHIPA
JOIN GOL G ON J.ID_JUCATOR = G.ID_JUCATOR
JOIN MECI M ON G.ID_MECI = M.ID_MECI
JOIN STADION S ON M.ID_STADION = S.ID_STADION
WHERE UPPER(G.TIP_GOL) IN ('PENALTY', 'LOVITURĂ LIBERĂ', 'CORNER')    --- funcție pe șiruri de caractere: UPPER
      AND S.CAPACITATE < (                                            --- subcerere sincronizată
          SELECT AVG(S2.CAPACITATE)                                   --- funcția agregată AVG
          FROM MECI M2
          JOIN STADION S2 ON M2.ID_STADION = S2.ID_STADION
          JOIN MECI_EURO ME2 ON M2.ID_MECI = ME2.ID_MECI  
          WHERE M2.ID_ECHIPA_OASPETE = E.ID_ECHIPA
      )
      AND E.ID_COMPETITIE IS NOT NULL
      AND UPPER(G.VALIDAT) = 'DA'                                     --- funcție pe șiruri de caractere: UPPER
ORDER BY VARSTA;                                                      --- ordonare

--- Sunt respectate următoarele cerințe:
--- utilizarea funcțiilor pe date calendaristice: TRUNC, MONTHS_BETWEEN
--- utilizarea funcțiilor pe șiruri de caractere: UPPER
--- utilizarea funcției agregate AVG
--- subcerere sincronizată în care intervin cel puțin trei tabele
--- ordonare


-- 2. Să se afișeze echipele care au marcat cele mai multe goluri în cadrul campionatului intern din care fac parte și care au în lot
-- cel puțin doi jucători convocați la echipele naționale. 
-- Precizări: se vor afișa numele echipei, numărul de goluri marcate și campionatul intern de care aparțin

WITH GOLURI_ECHIPA AS (                      --- utilizarea blocurilor de cerere (clauza WITH)
    SELECT 
        E.ID_ECHIPA, E.ID_CAMPIONAT, E.NUME AS NUME_ECHIPA,
        COUNT(*) AS NUMAR_GOLURI                      --- funcția agregată COUNT
    FROM ECHIPA E
    JOIN JUCATOR J ON E.ID_ECHIPA = J.ID_ECHIPA
    JOIN GOL G ON J.ID_JUCATOR = G.ID_JUCATOR
    JOIN MECI M ON G.ID_MECI = M.ID_MECI
    JOIN MECI_INTERN MI ON M.ID_MECI = MI.ID_MECI
    WHERE UPPER(G.VALIDAT) = 'DA'                           --- funcția pe șiruri: UPPER
    GROUP BY E.ID_ECHIPA, E.ID_CAMPIONAT, E.NUME            --- grupări de date
),

MAX_GOLURI_CAMPIONAT AS (
    SELECT 
        ID_CAMPIONAT,
        MAX(NUMAR_GOLURI) AS MAX_GOLURI     -- funcția agregată: MAX
    FROM GOLURI_ECHIPA
    GROUP BY ID_CAMPIONAT    -- grupări de date
),

JUCATORI_CONVOCATI AS (
    SELECT 
        ID_ECHIPA,
        COUNT(DISTINCT ID_JUCATOR) AS NUMAR_CONVOCATI       -- funcția agregată COUNT
    FROM JUCATOR
    WHERE ID_NATIONALA IS NOT NULL
    GROUP BY ID_ECHIPA      -- grupări de date
)

SELECT 
    MAX_EC.ID_ECHIPA, MAX_EC.NUMAR_GOLURI,
    JC.NUMAR_CONVOCATI,
    CI.NUME AS NUME_CAMPIONAT
FROM (                                          --- subcerere nesincronizată (clauza FROM)
    SELECT 
        GE.ID_ECHIPA, GE.NUME_ECHIPA, 
        GE.ID_CAMPIONAT, GE.NUMAR_GOLURI
    FROM GOLURI_ECHIPA GE
    JOIN MAX_GOLURI_CAMPIONAT MG ON GE.ID_CAMPIONAT = MG.ID_CAMPIONAT
         AND GE.NUMAR_GOLURI = MG.MAX_GOLURI
  ) MAX_EC

JOIN CAMPIONAT_INTERN CI ON MAX_EC.ID_CAMPIONAT = CI.ID_CAMPIONAT
JOIN JUCATORI_CONVOCATI JC ON MAX_EC.ID_ECHIPA = JC.ID_ECHIPA
WHERE JC.NUMAR_CONVOCATI >= 2
ORDER BY MAX_EC.NUME_ECHIPA;    -- ordonare

-- Sunt respectate următoarele cerințe:
-- utilizarea blocurilor de cerere (clauza WITH)
-- utilizarea funcțiilor agregate și grupări: COUNT, MAX
-- grupări de date
-- subcerere nesincronizată în clauza FROM
-- ordonare


-- 3. Să se afișeze pentru fiecare sponsor un mesaj, astfel:
-- Dacă sponsorul a oferit contracte de sponsorizare unor echipe care au participat în competiții europene se afișează: "Sponsor activ în competiții europene"
-- Dacă sponsorul a oferit contracte de sponsorizare altor echipe, se afișează: "Sponsor fără participare europeană"
-- Dacă sponsorul nu a oferit niciun contract de sponsorizare, se afișează: "Nu a sponsorizat"
-- Precizări: sponsorii vor fi afișați în ordine descrescătoare după valoarea totală a contractelor oferite.

WITH SPONSORIZARI_EURO AS (   -- utilizarea blocurilor de cerere (clauza WITH)
    SELECT DISTINCT
        SZ.ID_SPONSOR
    FROM SPONSORIZARE SZ
    JOIN ECHIPA E ON SZ.ID_ECHIPA = E.ID_ECHIPA
    JOIN COMPETITIE_EURO_CLUB CEC ON E.ID_COMPETITIE = CEC.ID_COMPETITIE
),

SPONSORIZARI_TOTAL AS (
    SELECT 
        SZ.ID_SPONSOR,
        SUM(NVL(SZ.VALOARE_CONTRACT, 0)) AS VALOARE_TOTALA      -- funcția de grup: SUM
    FROM SPONSORIZARE SZ
    GROUP BY SZ.ID_SPONSOR      -- grupare de date
)

SELECT
    S.NUME AS NUME_SPONSOR,
    CASE                            -- utilizarea unei expresii CASE
        WHEN NVL(ST.VALOARE_TOTALA, 0) = 0 THEN 'Nu a sponsorizat'
        WHEN SE.ID_SPONSOR IS NOT NULL THEN 'Sponsor activ în competiții europene'
        ELSE 'Sponsor fără participare europeană'
    END AS MESAJ_SPONSORIZARE,
    NVL(ST.VALOARE_TOTALA, 0) AS VALOARE_TOTALA_CONTRACTE       -- utilizarea funcției NVL
FROM SPONSOR S
LEFT JOIN SPONSORIZARI_TOTAL ST ON S.ID_SPONSOR = ST.ID_SPONSOR
LEFT JOIN SPONSORIZARI_EURO SE ON S.ID_SPONSOR = SE.ID_SPONSOR
ORDER BY VALOARE_TOTALA_CONTRACTE DESC, S.NUME;     -- ordonare

--- Sunt respectate următoarele cerințe:
--- utilizarea blocurilor de cerere (clauza WITH)
--- utilizarea funcției de grup SUM
--- grupări de date
--- utilizarea unei expresii CASE
--- utilizarea funcției NVL
--- ordonări



-- 4. Să se afișeze antrenorii care antrenează echipe cu mai multe goluri marcate decât media golurilor înscrise de echipele din același campionat,
-- dar care joacă pe stadioane cu capacitate mai mare decât media capacităților stadioanelor unde se desfășoară meciuri în competițiile europene de club.
-- Precizări: pentru fiecare antrenor se va afișa numele complet, având doar numele scris cu majuscule (Prenume NUME), capacitatea stadionului echipei,
-- numărul total de goluri ale echipei și statusul acesteia (Europeană - dacă echipa participă în competițiile europene de club și Națională în caz contrar).

WITH GOLURI_PE_ECHIPA AS (  -- bloc de cerere (clauza WITH)
    SELECT 
        E.ID_ECHIPA,
        E.ID_CAMPIONAT,
        COUNT(G.ID_MECI) AS TOTAL_GOLURI        -- funcție de grup
    FROM ECHIPA E
    JOIN JUCATOR J ON E.ID_ECHIPA = J.ID_ECHIPA
    LEFT JOIN GOL G ON J.ID_JUCATOR = G.ID_JUCATOR 
                    AND UPPER(G.VALIDAT) = 'DA'      -- funcția NVL
    GROUP BY E.ID_ECHIPA, E.ID_CAMPIONAT             -- grupare de date
),

MEDIA_GOLURI_CAMPIONAT AS (
    SELECT 
        ID_CAMPIONAT,
        AVG(TOTAL_GOLURI) AS MEDIA_GOLURI       -- funcție agregată: AVG
    FROM GOLURI_PE_ECHIPA                   
    GROUP BY ID_CAMPIONAT                       -- grupare de date
)

SELECT 
    CONCAT(A.PRENUME, CONCAT(' ', UPPER(A.NUME))) AS ANTRENOR_COMPLET,      -- funcții pe șiruri: CONCAT, UPPER    
    S.CAPACITATE AS CAPACITATE_STADION,
    NVL(GPE.TOTAL_GOLURI, 0) AS GOLURI_ECHIPA,                                      -- funcția NVL
    DECODE(E.ID_COMPETITIE, NULL, 'Națională', 'Europeană') AS STATUS_ECHIPA,       -- funcția DECODE
    CI.NUME AS CAMPIONAT
FROM ANTRENOR A

JOIN ECHIPA E ON A.ID_ECHIPA = E.ID_ECHIPA
JOIN STADION S ON E.ID_STADION = S.ID_STADION
JOIN CAMPIONAT_INTERN CI ON E.ID_CAMPIONAT = CI.ID_CAMPIONAT
JOIN GOLURI_PE_ECHIPA GPE ON E.ID_ECHIPA = GPE.ID_ECHIPA
JOIN MEDIA_GOLURI_CAMPIONAT MGC ON GPE.ID_CAMPIONAT = MGC.ID_CAMPIONAT

WHERE GPE.TOTAL_GOLURI > MGC.MEDIA_GOLURI                             
GROUP BY A.PRENUME, A.NUME, S.CAPACITATE, 
         GPE.TOTAL_GOLURI, E.ID_COMPETITIE, CI.NUME     -- grupare de date
HAVING S.CAPACITATE >
(                                     -- subcerere nesincronizată în HAVING în care intervin cel puțin trei tabele
    SELECT AVG(S2.CAPACITATE)           
    FROM STADION S2
    JOIN MECI M2 ON S2.ID_STADION = M2.ID_STADION
    JOIN MECI_EURO ME ON M2.ID_MECI = ME.ID_MECI
    JOIN COMPETITIE_EURO_CLUB CEC ON ME.ID_COMPETITIE = CEC.ID_COMPETITIE
)
ORDER BY NVL(GPE.TOTAL_GOLURI, 0) DESC,                       -- ordonare cu NVL
         DECODE(E.ID_COMPETITIE, NULL, 2, 1),                 -- ordonare cu DECODE
         LENGTH(A.NUME);                                      -- ordonare după lungimea numelui (funcție pe șiruri: LENGTH)
        
--- Sunt respectate următoarele cerințe:
--- utilizarea blocurilor de cerere (clauza WITH)
--- utilizarea funcțiilor de grupare și agregare: AVG, COUNT
--- grupări de date
--- subcerere nesincronizată în clauza HAVING în care intervin cel puțin trei tabele
--- utilizarea funcțiilor pe șiruri de caractere: CONCAT, UPPER, LENGTH
--- utilizarea funcțiilor DECODE, NVL
--- ordonarea datelor



-- 5. Să se afișeze jucătorii care au marcat goluri în ultimele 10 minute ale meciului sau în prelungiri.
-- Precizări: pentru fiecare jucător se va afișa numele complet, echipa pentru care joacă, minutul și tipul golului marcat, vârsta la data meciului.

WITH GOLURI_DECISIVE AS (                                              -- bloc de cerere: clauza WITH
    SELECT 
        J.ID_JUCATOR, J.PRENUME || ' ' || J.NUME AS NUME_COMPLET,
        J.DATA_NASTERII,
        G.TIP_GOL, G.MINUT_GOL,
        M.DATA_MECI,
        E.NUME AS NUME_ECHIPA,
        COUNT(*) OVER (PARTITION BY J.ID_JUCATOR)       -- funcția de grup: COUNT
    FROM GOL G
    JOIN JUCATOR J ON G.ID_JUCATOR = J.ID_JUCATOR
    JOIN MECI M ON G.ID_MECI = M.ID_MECI
    JOIN ECHIPA E ON J.ID_ECHIPA = E.ID_ECHIPA
    WHERE G.MINUT_GOL >= 80 AND UPPER(G.VALIDAT) = 'DA'                 -- funcție pe șiruri: UPPER
)

SELECT 
    NUME_COMPLET, NUME_ECHIPA,
    INITCAP(LOWER(TIP_GOL)) AS TIPUL_GOLULUI,                           -- funcții pe șiruri: INITCAP, LOWER
    TRUNC(MONTHS_BETWEEN(DATA_MECI, DATA_NASTERII)/12) AS VÂRSTĂ,       -- funcții pe date: MONTHS_BETWEEN, TRUNC
    MINUT_GOL
FROM GOLURI_DECISIVE
ORDER BY VÂRSTĂ, NUME_COMPLET;                                          -- ordonare

-- Sunt respectate următoarele cerințe:
-- utilizarea a cel puțin două funcții pe șiruri de caractere: UPPER, LOWER, INITCAP
-- utilizarea a două funcții pe date calendaristice: TRUNC, MONTHS_BETWEEN
-- ordonări
-- utilizarea unui bloc de cerere (clauza WITH)
--



-- 1. UPDATE: Actualizează capacitatea stadioanelor care au găzduit meciuri cu mai mult de 2 goluri

UPDATE STADION 
SET CAPACITATE = CAPACITATE * 1.1 
WHERE ID_STADION IN (
    SELECT M.ID_STADION
    FROM MECI M
    WHERE (
        SELECT COUNT(G.NUMAR_GOL)
        FROM GOL G
        WHERE G.ID_MECI = M.ID_MECI
              AND UPPER(G.VALIDAT) = 'DA'
    ) > 2
);


--- 2. STERGERE: Șterge jucătorii care nu au marcat niciun gol valid.

DELETE FROM JUCATOR
WHERE ID_JUCATOR NOT IN (
    SELECT DISTINCT ID_JUCATOR
    FROM GOL
    WHERE UPPER(VALIDAT) = 'DA'
);


--- 3. ȘTERGERE: Șterge sponsorii care au oferit contracte cu valoare mai mică de 30000000.

DELETE FROM SPONSOR
WHERE ID_SPONSOR IN (
    SELECT ID_SPONSOR
    FROM SPONSORIZARE
    GROUP BY ID_SPONSOR
    HAVING SUM(NVL(VALOARE_CONTRACT, 0)) < 30000000
);



--- vizualizari (ex. 14)

CREATE OR REPLACE VIEW V_ECHIPE_STADIOANE AS
SELECT 
    E.ID_ECHIPA, E.NUME AS NUME_ECHIPA,
    S.NUME AS NUME_STADION, S.ORAS AS ORAS_STADION, S.CAPACITATE,
    CASE 
        WHEN S.CAPACITATE > 50000 THEN 'Mare'
        WHEN S.CAPACITATE > 20000 THEN 'Mediu'
        ELSE 'Mic'
    END AS CATEGORIA_STADION
FROM ECHIPA E
LEFT JOIN STADION S ON E.ID_STADION = S.ID_STADION;


-- Exemplu de operație LMD permisă pe vizualizare: afișează echipele care au stadioane cu capacitatea mai mare de 30000 de locuri.

SELECT NUME_ECHIPA, NUME_STADION, CAPACITATE
FROM V_ECHIPE_STADIOANE
WHERE CAPACITATE > 30000
ORDER BY CAPACITATE DESC;

-- Exemplu de operație nepermisă: actualizarea datelor pe coloane ale căror valori rezultă prin calcul

UPDATE V_ECHIPE_STADIOANE 
SET CATEGORIA_STADION = 'Foarte Mare'
WHERE NUME_ECHIPA = 'Real Madrid';

-- Exemplu de operație nepermisă: update pe tabele multiple simultan

UPDATE V_ECHIPE_STADIOANE 
SET NUME_ECHIPA = 'FC Nou',
    NUME_STADION = 'Arena Nouă'
WHERE ID_ECHIPA = 5;
