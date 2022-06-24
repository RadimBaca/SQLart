# Intersection with different database designs
Date: 30.5.2022

DBMS: PostgreSql 11.11

Let us imagine that we need to store information about documents where every document contains a set of words and our typical query is to search for documents containing a specific set of words. The idea behind this problem can be identified in different scenarios such as products and their features, or persons and their skills. The topic is not that important, what is significant is that we basically want to perform an intersection of several lists. In this article, we describe and compare several different ways how to handle this problem in PostgreSQL. 

## Relational Approach

We first start with the most straightforward solution storing the data in the relations and creating of an appropriate index. The relational data model can be seen in the following Figure. The data model is a simple M:N relationship between Document and Word.

<img src="img\relational_model.png" alt="Relational data model" width="700"/>

Sample [SQL script](intersect.sql) contains an anonymous procedure that create these tables and generate artificial data. The number of words is fixed to one hundred, whereas the number of documents can be set using the `v_numOfDoc` variable. The initial value of documents is ten thousand. Script randomly assigns words to documents. In the end, we create an index that helps the query processor quickly find the documents according to the list of words. For simplicity, we use just their `id`.

```sql
CREATE INDEX idx_Belongs_idword ON Belongs (id_word);
```

Once the data is ready we may search for documents containing a specified set of words using the following SQL.

```sql
SELECT id_doc
FROM Belongs
WHERE id_word in (10, 20, 30)
GROUP BY id_doc
HAVING count(*) = 3;
```

## ARRAY Approach
The second approach is using the `ARRAY` data type to store the list of words per document. This approach clearly breaks the first normal form and has several other implications, however, it allows us to solve the problem as well. The table will have the following structure.

```sql
CREATE TABLE DocWord
(
    id_doc      int primary key,
    padding 	varchar(10),
    id_words	int array
);
```

Similarly to the relational approach, we need an index to avoid a sequential scan. We will use the `intarray` extension since we are working with a list of integers and we use the `GIN` index. 

```sql
CREATE EXTENSION intarray;
CREATE INDEX idx_DocWord_idb ON DocWord USING gin (id_words gin__int_ops);
```

The `GIN` index creates an inverted list of sorted `id_doc` allowing their fast intersection using a single scan of appropriate word posting lists. We just need to use `<@` operator in order to let the PostgreSQL put the `GIN` index into a query plan.

```sql
SELECT id_doc
FROM DocWord
WHERE '{10, 20, 30}' <@ id_words;
```

## Roaringbitmaps Approach
Since I'm a fan of Daniel Lemire's work I decided to try <a src="https://www.pgxn.org/dist/pg_roaringbitmap/0.5.0/">Roaringbitmaps 0.5.0 extension</a> that is based on his <a src="https://github.com/RoaringBitmap/RoaringBitmap">Roaringbitmaps library</a>. In this case, you need to build and install the extension on your PostgreSQL instance first. Please follow the instruction in the description of the extension. Roaringbitmap is quite simple data structure storing a set in a form of a compressed bit array.

We can prepare data once the extension is installed. In this case, we add a list of documents to each word record. Therefore, the list of documents is stored as a compressed bitmap (Roaringbitmap).

```sql
CREATE EXTENSION roaringbitmap;
CREATE TABLE WordDoc
(
	id_word		int primary key,
    padding		varchar(50),
	id_docs		roaringbitmap
);
```

From a certain perspective, we directly prepare the data as an inverted list, where the posting list is simply Roaringbitmap. The query performs logical AND uses these bit arrays (function `rb_and_agg`), subsequent function `rb_to_array` just transform the bit array into `ARRAY`, and finally query unnest the result from `ARRAY` into a set of rows.

```sql
SELECT unnest(rb_to_array(rb_and_agg(id_docs)))
FROM WordDoc
WHERE WordDoc.id_word in (10, 20, 30);
```


# Comparison of approaches
We have been testing these approaches on a quite old server with Intel Xeon X5670 running the PostgreSQL 11.11. I'm not familiar with the details of Roaringbitmaps implementation, however, SSE2 is available on that processor. The following table shows the different times for a different number of documents per word. The number of words is fixed and it is one hundred. Documents are distributed almost uniformly, therefore, the number of documents per word in the smallest collection is around one hundred. In the case of the largest collection, it is thousands of documents per word. 

<table>  
  <tr>  
    <th>Number of documents</th>  
    <th>Relational [ms]</th>  
    <th>ARRAY [ms]</th>  
    <th>Roaringbitmaps [ms]</th>  
  </tr>  
  <tr>  
    <td>10 000</td>  
    <td>9</td>  
    <td>5</td>  
    <td>4</td>  
  </tr>  
  <tr>  
    <td>100 000</td>  
    <td>34</td>  
    <td>6</td>  
    <td>4</td>  
  </tr>  
  <tr>  
    <td>1 000 000</td>  
    <td>350</td>  
    <td>10</td>  
    <td>5</td>  
  </tr>  
 <caption>Query times</caption>
</table>

<table>  
  <tr>  
    <th>Number of documents</th>  
    <th>Relational [MB]</th>  
    <th>ARRAY [MB]</th>  
    <th>Roaringbitmaps [MB]</th>  
  </tr>  
  <tr>  
    <td>10 000</td>  
    <td>3</td>  
    <td>0.4</td>  
    <td>0.015</td>  
  </tr>  
  <tr>  
    <td>100 000</td>  
    <td>33</td>  
    <td>3</td>  
    <td>0.015</td>  
  </tr>  
  <tr>  
    <td>1 000 000</td>  
    <td>332</td>  
    <td>3</td>  
    <td>0.015</td>  
  </tr>  
 <caption>Index sizes</caption>
</table>

Tables clearly show a dominance of Roaringbitmap approach from the query time and index size perspective. However, these are not the only aspects of data processing. There are certain drawbacks of non-relational approaches that need to be kept in mind if we consider using them:

1. Values in an array are not foreign keys (<a href="https://commitfest.postgresql.org/17/1252/">yet</a>). Therefore, referential integrity inside the database has to be maintained by the application.
2. It can be particularly costly to add new documents into the Roaringbitmap implementation of our database.
3. It may be difficult to express a different type of query using the ARRAY or Roaringbitmap approach.

I have to emphasize the role of the main parameter again: documents per word. As it is obvious from the experiments the selection of a non-relational approach should be driven by an expected number of documents per word. If we expect thousands of documents per word, then it may make sense to use ARRAY or some other inverted list-based approach.

# Conclusion

The main aim of this article is to think about the possibilities of implementing intersection in PostgreSQL. We compare relational approach with two non-relational that are based on a inverted list. We try to cover pros and cons of different approaches that are currently available in PostgreSQL. We focus on a query perspective and show that it make sense to use non-relational approach if the number of documents per word is high (at least in thousands documents per word).
