
SET max_parallel_workers_per_gather = 0;
SET work_mem TO '512 MB';

DO $$
DECLARE
  C INTEGER := 1000000;
  N INTEGER := 1000;
  countryId_selectivity INTEGER;
  RESULT_WF TEXT;
  RESULT_GROUPBY TEXT;
BEGIN

    DROP TABLE IF EXISTS  customer;
    CREATE TABLE customer AS
    SELECT id, 'Customer Name ' || id as name, id % N countryId, cast(random() * 10000 as int) payment
    FROM generate_series(0, C) id;
END $$;


 EXPLAIN ANALYSE
       SELECT sum(id)
       FROM (
         SELECT *,
           DENSE_RANK() OVER (PARTITION BY countryId ORDER BY payment) rank
         FROM customer
         WHERE countryId < 500
       ) ranking
       WHERE rank = 1;

 EXPLAIN ANALYSE
       SELECT sum(c.id)
       FROM customer c
       JOIN (
         SELECT countryId, MIN(payment) min_payment
         FROM customer
         WHERE countryId < 500
         GROUP BY countryId
       ) ranking ON c.countryId = ranking.countryId AND
           c.payment = ranking.min_payment;


CREATE INDEX ix_customer_countryid ON customer(countryId, payment, id);

