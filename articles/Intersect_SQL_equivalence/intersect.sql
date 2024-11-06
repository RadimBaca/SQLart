
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
        v_idword integer;
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
            id_doc int references Doc,
            id_word int references Word,
            primary key (id_doc, id_word)
        );

        -- We have many documents ...
        INSERT
        INTO Doc
        SELECT id,
               RPAD('Value ' || id || ' ', 10, '*') as padding
        FROM generate_series(0, v_numOfDoc) id;

        -- ... with just few words
        INSERT
        INTO Word
        SELECT id,
               RPAD('Value ' || id || ' ', 50, '*') as padding
        FROM generate_series(0, 99) id;

        -- We randomly insert several words to every document
        FOR v_iddoc in 0 .. v_numOfDoc
            LOOP
                v_idword := random() * 10;
                WHILE v_idword < 100
                    LOOP
                        INSERT INTO Belongs VALUES (v_iddoc, v_idword);
                        v_idword := v_idword + (random() * v_idword) + 1;
                    END LOOP;
            END LOOP;

        CREATE INDEX idx_Belongs_idword ON Belongs (id_word);
    END
$$;

-----------------
-- Version No.2 - ARRAY + GIN
DROP TABLE IF EXISTS DocWord;
CREATE TABLE DocWord
(
    id_doc      int primary key,
    padding varchar(10),
    id_words     int array
);

-- We copy data from the relational design
INSERT INTO DocWord
SELECT id_doc, padding, array_agg(id_word) id_words
FROM Belongs
         JOIN Doc ON Belongs.id_doc = Doc.id
GROUP BY id_doc, padding;

CREATE EXTENSION intarray;
CREATE INDEX idx_DocWord_idb ON DocWord USING gin (id_words gin__int_ops);

-----------------
-- Version No.3 - Roaringbitmap
CREATE EXTENSION roaringbitmap;
DROP TABLE IF EXISTS WordDoc;
CREATE TABLE WordDoc
(
    id_word     int primary key,
    padding varchar(50),
    id_docs     roaringbitmap
);

-- We copy data from the relational design
INSERT INTO WordDoc
SELECT id_word, padding, rb_build(array_agg(id_doc)) id_docs
FROM Belongs
         JOIN Word ON Belongs.id_word = Word.id
GROUP BY id_word, padding;


---- Queries

-- We search for documents containing words 10, 20, 30
-- Versio No.1 - Binding table
SELECT id_doc
FROM Belongs
WHERE id_word in (10, 20, 30)
GROUP BY id_doc
HAVING count(*) = 3;

-- Version No.2 - Array + GIN
SELECT id_doc
FROM DocWord
WHERE '{10, 20, 30}' <@ id_words;

-- Version No.3 - Roaringbitmaps
SELECT unnest(rb_to_array(rb_and_agg(id_docs)))
FROM WordDoc
WHERE WordDoc.id_word in (10, 20, 30);


----- velikost tabulek
SELECT pg_indexes_size('Belongs');
SELECT pg_indexes_size('DocWord');
SELECT pg_indexes_size('WordDoc');