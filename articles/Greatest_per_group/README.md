# Greatest per Group - Window Function vs Self-join

DBMS: PostgreSql 9.6.1

Let us have a sample table with customers where each customer belongs to one country (`countryId` attribute). Each customer has one `payment` attribute randomly selected from `(0,10000)` interval. The following command load 1M customers into a PostgreSQL database.

```sql
CREATE TABLE customer AS
SELECT id, 
   'Customer Name ' || id as name, 
   id % 1000 countryId, 
   cast(random() * 10000 as int) payment
FROM generate_series(0, 1000000) id;
```

Now consider a task where we would like to find customers having minimal payment value in their country. To reduce the results, let us do the sum of their IDs. Let us start with a window function solution:

```sql
SELECT sum(id)
FROM (
    SELECT *,
        DENSE_RANK() OVER (PARTITION BY countryId ORDER BY payment) rank
    FROM customer
    WHERE countryId < 500
) ranking
WHERE rank = 1;
```

This SQL syntax leads the PostgreSQL into a query plan where he scans the customer table sequentially filter out the customers having `countryId >= 500 or NULL`, then it performs the sort, window function computation, filtering according to the rank, and finally it sums the customer IDs. This query plan takes almost a second on my PostgreSQL as can be observed from the following query plan.

```
Aggregate  (cost=84317.82..84317.83 rows=1 width=8) (actual time=864.136..864.136 rows=1 loops=1)
  ->  Subquery Scan on ranking  (cost=68062.39..84311.57 rows=2500 width=4) (actual time=557.304..864.097 rows=520 loops=1)
        Filter: (ranking.rank = 1)
        Rows Removed by Filter: 499481
        ->  WindowAgg  (cost=68062.39..78061.89 rows=499975 width=52) (actual time=557.303..844.944 rows=500001 loops=1)
              ->  Sort  (cost=68062.39..69312.32 rows=499975 width=12) (actual time=557.275..570.990 rows=500001 loops=1)
                    Sort Key: customer.countryid, customer.payment
                    Sort Method: quicksort  Memory: 35726kB
                    ->  Seq Scan on customer  (cost=0.00..20736.01 rows=499975 width=12) (actual time=0.026..210.510 rows=500001 loops=1)
                          Filter: (countryid < 500)
                          Rows Removed by Filter: 500000
Planning Time: 1.129 ms
Execution Time: 870.723 ms
```

As we can observe from the EXPLAIN PLAN the major work is attributed to the customer table sort (we are sorting 500k rows), window function computation and subsequent sequential filtering (`rank = 1`). Let us test another SQL variant using a `GROUP BY` clause.

```sql
SELECT sum(c.id)
FROM customer c
JOIN (
    SELECT countryId, MIN(payment) min_payment
    FROM customer
    WHERE countryId < 500
    GROUP BY countryId
) ranking ON c.countryId = ranking.countryId AND
   c.payment = ranking.min_payment;
```

We obtain a fundamentally different query plan using hash aggregate to compute `min(payment)` per `customerId` using a sequential scan. The aggregated result for each table is then joined with the `customer` table using a hash join. This query plan is almost two times faster then the previous solution on my server (500ms vs 870ms).

```
Aggregate  (cost=46757.15..46757.16 rows=1 width=8) (actual time=496.895..496.896 rows=1 loops=1)
  ->  Hash Join  (cost=23270.89..46756.90 rows=100 width=4) (actual time=292.493..496.846 rows=520 loops=1)
        Hash Cond: ((c.countryid = customer.countryid) AND (c.payment = (min(customer.payment))))
        ->  Seq Scan on customer c  (cost=0.00..18236.01 rows=1000001 width=12) (actual time=0.025..80.995 rows=1000001 loops=1)
        ->  Hash  (cost=23255.89..23255.89 rows=1000 width=8) (actual time=292.374..292.374 rows=500 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 28kB
              ->  HashAggregate  (cost=23235.89..23245.89 rows=1000 width=8) (actual time=292.173..292.280 rows=500 loops=1)
                    Group Key: customer.countryid
                    ->  Seq Scan on customer  (cost=0.00..20736.01 rows=499975 width=8) (actual time=0.013..166.279 rows=500001 loops=1)
                          Filter: (countryid < 500)
                          Rows Removed by Filter: 500000
Planning Time: 0.962 ms
Execution Time: 497.054 ms
```

## Adjusting the Filter Condition and Impact of Indexes

The problem of window function query is the sort of the large intermediate result, rank assignment and subsequent filtering. If we change the selectivity of the `WHERE` clause, we might get a slightly different statistics. The following picture shows how the processing time changes with changes in the query selectivity. 


<img src="img/selectivity.png" width="500"/>

The query variant using the hash aggregation and hash join (the GROUP BY variant) is more robust than the window function variant. The difference between these variants can be even more significant if we create appropriate covering index.

```sql
CREATE INDEX ix_customer_countryid ON customer(countryId, payment, id);
```
If we process the above queries having this index, the processing time is 720 ms vs 325 ms. The window function query avoids expensive sort in this case; however, the assignment of ranks and subsequent filtering using a sequential scan is still quite expensive. Therefore, the GROUP BY variant is still significantly faster.

## The Problem Analysis

What is the root cause of this situation which makes window function quite slow fellow? By doing a closer look, we reveal that the major problem here is a fact that we discard most of the previous work when we process the `rank = 1` condition. In other words, we compute the rank for many rows, and we even need to sort the whole set to do that; however, we are interested only in rows having rank equal to 1 which is a tiny part of the input. Using a hash table (the GROUP BY variant) for the same agenda seems to be a better option in many cases.

Can we generalize these observations and find a rule when the query plan produced by window functions syntax is potentially worse than some GROUP BY/subquery syntax? We believe that it is possible. The rule is as follows: **Whenever we have a window function on a potentially large set, and we subsequently perform filtering with high selectivity then it may be better to perform the filtering first and then compute the window function value using a join.**

## Yet Another Example

Let us show another example following the previously stated rule. Let us compute the average payment in the country for several customers. Therefore the window function SQL variant could be as follows:

```sql
SELECT *
FROM (
  SELECT *,
    avg(payment) OVER (PARTITION BY countryId) rank
  FROM customer
) ranking
WHERE id in (1, 10, 100, 1001);
```
Again the PostgreSQL follows the paradigm where it scan, sort, compute win function and then filter. In our server this variant takes 1s. Let us test the second SQL variant using a dependent subquery with aggregation:
```sql
SELECT *, (
  SELECT avg(payment)
  FROM customer c2
  WHERE c1.countryId = c2.countryId
)
FROM customer c1
WHERE id in (1, 10, 100, 1001);
```
Even though the sequential scan for every customer found is inevitable, this variant is still slightly faster than the window function variant. However, it performs unindexed nested-loop join; therefore, the query time grows linearly with the size of the intermediate result (the number of customers found). Therefore, the existence of an index on `customer.countryId` attribute is highly desired to choose the query plan with nested-loop join; especially if there is a risk of bad intermediate result estimation.

# Conclusion

The main aim of this article is to propose quite a simple rule that might be useful when optimizing the queries with window function. The window functions itself always lead to the same type of query plans considering partitioning, sort and window function computation. We believe that it would be good if the query optimizers would also consider other query plans.
