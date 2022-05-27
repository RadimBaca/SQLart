
/*
Basic parameter of the test:
v_numOfDoc - Number of documents

The main idea of the test is to compare intersection performed by a classical relational design with designs 
based on arrays. 
*/

SET max_parallel_workers_per_gather = 0;

-----------------
-- Version No.1 - Binding table (classical relational M:N design)
DO
$$
    DECLARE
        v_idb integer;
        v_numOfDoc integer := 10000;
    BEGIN
        DROP TABLE IF EXISTS Belongs;
        DROP TABLE IF EXISTS Doc;
        DROP TABLE IF EXISTS Word;

        -- Documents
        CREATE TABLE Doc
        (
            id      int primary key,
            padding varchar(10)
        );

        -- Words
        CREATE TABLE Word
        (
            id      int primary key,
            padding varchar(50)
        );

        -- Binding table
        CREATE TABLE Belongs
        (
            ida int references Doc,
            idb int references Word,
            primary key (ida, idb)
        );

        -- We have many documents ...
        INSERT
        INTO Doc
        WITH t1 AS
                 (
                     SELECT id
                     FROM generate_series(0, v_numOfDoc) id
                 )
        SELECT id,
               RPAD('Value ' || id || ' ', 10, '*') as padding
        FROM t1;

        -- ... with just few words
        INSERT
        INTO Word
        WITH t1 AS
                 (
                     SELECT id
                     FROM generate_series(0, 99) id
                 )
        SELECT id,
               RPAD('Value ' || id || ' ', 50, '*') as padding
        FROM t1;

        -- We randomly insert several words to every document
        FOR v_ida in 0 .. v_numOfDoc
            LOOP
                v_idb := random() * 10;
                WHILE v_idb < 100
                    LOOP
                        INSERT INTO Belongs VALUES (v_ida, v_idb);
                        v_idb := v_idb + (random() * v_idb) + 1;
                    END LOOP;
            END LOOP;

        CREATE INDEX idx_Belongs_idb ON Belongs (idb);
    END
$$;

-----------------
-- Version No.2 - ARRAY + GIN
DROP TABLE IF EXISTS DocWord;
CREATE TABLE DocWord
(
    id      int primary key,
    padding varchar(10),
    idb     int array
);

-- We copy data from the relational design
INSERT INTO DocWord
SELECT ida, padding, array_agg(idb)
FROM Belongs
         JOIN Doc ON Belongs.ida = Doc.id
GROUP BY ida, padding;

CREATE EXTENSION intarray;
CREATE INDEX idx_DocWord_idb ON DocWord USING gin (idb gin__int_ops);

-----------------
-- Version No.3 - Roaringbitmap
CREATE EXTENSION roaringbitmap;
DROP TABLE IF EXISTS WordDoc;
CREATE TABLE WordDoc
(
    idb     int primary key,
    padding varchar(50),
    ida     roaringbitmap
);

-- We copy data from the relational design
INSERT INTO WordDoc
SELECT idb, padding, rb_build(array_agg(ida))
FROM Belongs
         JOIN Word ON Belongs.idb = Word.id
GROUP BY idb, padding;


---- Queries

-- We search for documents containing words 2, 14, 30, 50, 80
-- Versio No.1 - Binding table
SELECT ida
FROM Belongs
WHERE idb in (2, 14, 30, 50, 80)
GROUP BY ida
HAVING count(*) = 5;

-- Version No.2 - Array + GIN
SELECT id
FROM DocWord
WHERE '{2, 14, 30, 50, 80}' <@ idb;

-- Version No.3 - Roaringbitmaps
SELECT unnest(rb_to_array(rb_and_agg(ida)))
FROM WordDoc
WHERE WordDoc.idb in (2, 14, 30, 50, 80);


----- velikost tabulek
SELECT pg_indexes_size('Belongs');
SELECT pg_indexes_size('DocWord');
SELECT pg_indexes_size('WordDoc');