DROP TABLE IF EXISTS country CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS branch CASCADE;

CREATE TABLE country
(
   id int primary key,
   name varchar(50),
   abrv char(2) null
);

CREATE TABLE customer
(
   id int primary key,
   name varchar(50),
   male int,
   countryId int references country
);


CREATE TABLE branch
(
   id int primary key,
   countryId int references country,
   name varchar(50)
);

INSERT
INTO    country
SELECT
   id,
   'Country ' || id as name,
   'Ab'
FROM generate_series(0, 95) id
UNION
SELECT 96, 'Czech republic', 'Cz'
UNION
SELECT 97, 'Slovakia', 'Sk'
UNION
SELECT 98, 'Poland', 'Pl'
UNION
SELECT 99, 'Hungary', 'Hu'
UNION
SELECT 100, 'Croatia', 'Hr';

INSERT
INTO    customer
SELECT id, 'Customer ' || id as name, id % 2 male, id % 101 countryId
FROM generate_series(0, 1000000) id;

INSERT
INTO    branch
SELECT id, id % 101 countryId,  'Branch ' || id as name
FROM generate_series(0, 1000) id;

EXPLAIN ANALYZE SELECT co.id, co.name,
    (
      SELECT count(*)
      FROM Customer cu
      WHERE cu.countryId = co.id
    ) cust_cnt,
    (
      SELECT count(*)
      FROM Branch br
      WHERE br.countryId = co.id
    ) branch_cnt
FROM Country co
WHERE co.abrv IN ('Cz', 'Sk', 'Pl', 'Hu', 'Hr');


EXPLAIN ANALYZE SELECT co.id, co.name, t1.cust_cnt, t2.branch_cnt
FROM Country co
LEFT JOIN (
   SELECT countryId,
        count(1) cust_cnt
   FROM Customer
   GROUP BY countryId
) t1 ON co.id = t1.countryId
LEFT JOIN (
   SELECT countryId,
        count(1) branch_cnt
   FROM Branch
   GROUP BY countryId
) t2 ON co.id = t2.countryId
WHERE co.abrv IN ('Cz', 'Sk', 'Pl', 'Hu', 'Hr');

CREATE INDEX ix_customer_countryid
    on customer(countryId);

CREATE INDEX ix_branch_countryid
    on branch(countryId);

DROP INDEX ix_customer_countryid;
DROP INDEX ix_branch_countryid;



EXPLAIN ANALYZE SELECT co.id, co.name,
    (
      SELECT count(*)
      FROM Customer cu
      WHERE cu.countryId = co.id
    ) cust_cnt,
    (
      SELECT count(*)
      FROM Branch br
      WHERE br.countryId = co.id
    ) branch_cnt
FROM Country co
WHERE co.id < 25;
