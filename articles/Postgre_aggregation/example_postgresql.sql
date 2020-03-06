DROP TABLE IF EXISTS country CASCADE;
DROP TABLE IF EXISTS customer CASCADE;

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





SELECT co.id, co.name,
    (
      SELECT count(*)
      FROM Customer cu
      WHERE cu.countryId = co.id
    ) cust_cnt
FROM Country co
WHERE co.abrv IN ('Cz', 'Sk', 'Pl', 'Hu', 'Hr');

SELECT co.id, co.name, t.cust_cnt
FROM Country co
LEFT JOIN (
   SELECT countryId,
        count(1) cust_cnt
   FROM Customer
   GROUP BY countryId
) t ON co.id = t.countryId
WHERE co.abrv IN ('Cz', 'Sk', 'Pl', 'Hu', 'Hr');


create index ix_customer_countryid
    on customer(countryId);

drop index ix_customer_countryid;




