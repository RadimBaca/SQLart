# Intersection with different database designs

DBMS: PostgreSql 11.11

Let us imagine that we need to store information about documents where every document contains a set of words and we our typical query is search for documents containing specific set of words. This problem can be found in different scenarios such as products and their features, or persons and their skills. The topic is not that important, what is significant is that we basically want to perform an intersection of several lists. In this article we describe and compare several different ways how to handle this problem in PostgreSQL. 

We first start with the most straightforward solution storing the data in the relations and creation of appropriate index. The relational data model can be seen in the following Figure. The data model is simple M:N relationship between Document and Word.

<img src="img\relational_model.png" alt="Relational data model" width="500"/>

Sample SQL script contains an anonymous procedure that create these tables and generate artificial data. The number of words is fixed to one hundred, whereas the number of documents can be set using the `v_numOfDoc` variable. The initial value od documents is ten thousands. Script randomly assigns words into documents. At the end we create an index that help the query processor quickly find the documents according to the list of words. For simplicity we use just their `id`.

```sql
CREATE INDEX idx_Belongs_idb ON Belongs (idb);
```

Once the data is ready we may search for documents containing specified set of words using the following SQL.

```sql
SELECT ida
FROM Belongs
WHERE idb in (10, 20, 30, 40, 50)
GROUP BY ida
HAVING count(*) = 5;
```


# Conclusion

The main aim of this article is to think about the possibilities of implementing intersection in PostgreSQL. We try to cover pros and cons of different approaches that are currently available in PostgreSQL. 