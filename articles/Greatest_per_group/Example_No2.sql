
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
       SELECT *
       FROM (
         SELECT *,
           avg(payment) OVER (PARTITION BY countryId) rank
         FROM customer
       ) ranking
       WHERE id in (1, 10, 100, 1001);

 EXPLAIN ANALYSE
       SELECT *, (
         SELECT avg(payment)
         FROM customer c2
         WHERE c1.countryId = c2.countryId
       )
       FROM customer c1
       WHERE id in (1, 10, 100, 1001);

CREATE INDEX ix_customer_countryid ON customer(countryId, payment);



