# Equivalence of Conjunctive and Intersect SQL queries
Date: 6.11.2024

## INTERSECT Construct

We have a simple SQL table.

```sql
CREATE TABLE person (
  name VARCHAR(40),
  year INT,
  place VARCHAR(20),
  number INT
);
```

Let us have an SQL command with `AND` operator (conjunctive SQL query). 

```sql
SELECT * FROM person 
WHERE place IN ('London', 'Neverland') and year >= 1900;
```

We ask a simple question. Is it equivalent to the following query?

```sql
SELECT * FROM person 
WHERE place in ('London', 'Neverland')
  INTERSECT
SELECT * FROM person 
WHERE year >= 1900;
```

If they are not equivalent, we should simply find a counterexample. It should not be difficult because the `INTERSECT` removes duplicates; therefore, if we insert two same rows, the SQL queries return different results. Here is an example of data.

```sql
INSERT INTO person VALUES('James Bond', 1953, 'London',  7);
INSERT INTO person VALUES('James Bond', 1953, 'London',  7);
```


## INTERSECT ALL Construct

Now let's improve the query using `INTERSECT ALL`:

```sql
SELECT * FROM person 
WHERE place in ('London', 'Neverland')
  INTERSECT ALL
SELECT * FROM person 
WHERE year >= 1900;
```

Now it is not possible to find any counterexample. Fine. Lets ask another question. If we have a query 

```sql
SELECT name FROM person 
WHERE place IN ('London', 'Neverland') and year >= 1900;
```

Is it equivalent to the following SQL query?

```sql
SELECT name FROM person 
WHERE place in ('London', 'Neverland')
  INTERSECT ALL
SELECT name FROM person 
WHERE year >= 1900;
```

If we think about the queries more thoroughly, we can realize that a `name` could be duplicated by the `INTERSECT ALL` version of the query. Can you pick data where these two queries return different results? It is not straightforward. I even asked chatGPT out of curiosity. He correctly recognized that the SQL queries were probably not equivalent. However, he was unable to provide a counterexample. Therefore, after several prompts, I convinced him these SQL queries are equivalent. Here is the ending of our conversation. :) 

<img src="chat.png" alt="Are SQL commands equivalent"/>


# Final Note

Deciding a SQL query equivalenece is a hard problem. Proving that two SQL commands are equivalent is still an open question for many queries. Here is a list of several articles that deal with SQL formalization and SQL query equivalence.

1. Benzaken, Véronique, and Evelyne Contejean. "A Coq mechanised formal semantics for realistic SQL queries: formally reconciling SQL and bag relational algebra." In Proceedings of the 8th ACM SIGPLAN International Conference on Certified Programs and Proofs, pp. 249-261. 2019.
2. Zhou, Qi, Joy Arulraj, Shamkant Navathe, William Harris, and Dong Xu. "Automated verification of query equivalence using satisfiability modulo theories." Proceedings of the VLDB Endowment 12, no. 11 (2019): 1276-1288.
3. Chu, Shumo, Konstantin Weitz, Alvin Cheung, and Dan Suciu. "HoTTSQL: Proving query rewrites with univalent SQL semantics." ACM SIGPLAN Notices 52, no. 6 (2017): 510-524.
4. Wang, Shuxian, Sicheng Pan, and Alvin Cheung. "QED: A Powerful Query Equivalence Decider for SQL." Proceedings of the VLDB Endowment 17, no. 11 (2024): 3602-3614.