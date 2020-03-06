
/*
Basic parameters of the test:
GRP_C - Number of groups
SEL - Selectivity of the input data

The main principle of the test if to adjust the SEL and GRP_C and measure the difference in the greatest per group SQL variants.
In other words, we have two SQL queries that perform the same operation, and we observe which one is more efficient depending on the parameters.
*/

SET max_parallel_workers_per_gather = 0;

DO $$
DECLARE
  C INTEGER := 1000000;
  GRP_C INTEGER := 1000;
  SEL INTEGER;
  RESULT_WF TEXT;
  RESULT_GROUPBY TEXT;
BEGIN
  raise notice 'GROUP COUNT;SELECTIVITY[Percent];WinFun time[s];Groupby time[s]';
  FOR counter IN 1 .. 1 LOOP
    DROP TABLE IF EXISTS  customer;
    CREATE TABLE customer AS
    SELECT id, 'Customer Name ' || id as name, id % GRP_C countryId, cast(random() * 10000 as int) payment
    FROM generate_series(0, C) id;

    SEL := 10;
    FOR in_selectivity IN 1 .. 5 LOOP

      EXPLAIN ANALYSE
        SELECT sum(id) INTO RESULT_WF
        FROM (
          SELECT *,
            DENSE_RANK() OVER (PARTITION BY countryId ORDER BY payment) rank
          FROM customer
          WHERE countryId < SEL
        ) ranking
        WHERE rank = 1;

      EXPLAIN ANALYSE
        SELECT sum(c.id) INTO RESULT_GROUPBY
        FROM customer c
        JOIN (
          SELECT countryId, MIN(payment) min_payment
          FROM customer
          WHERE countryId < SEL
          GROUP BY countryId
        ) ranking ON c.countryId = ranking.countryId AND
            c.payment = ranking.min_payment;

      raise notice '%;%;%;%', GRP_C, SEL * 100 / GRP_C, substring(RESULT_WF from position('actual time' in RESULT_WF) + 12 for 7), substring(RESULT_GROUPBY from position('actual time' in RESULT_GROUPBY) + 12 for 7);

      --This is an output for a simple SQL import of results
      --raise notice 'SELECT % grp, % sel, % winf,  % grpby', GRP_C, SEL * 100 / GRP_C, substring(RESULT_WF from position('actual time' in RESULT_WF) + 12 for 7), substring(RESULT_GROUPBY from position('actual time' in RESULT_GROUPBY) + 12 for 7);
      --raise notice 'UNION ALL';

      SEL := SEL + GRP_C / 4;

    END LOOP;

    GRP_C := GRP_C * 2;
  END LOOP;
END $$