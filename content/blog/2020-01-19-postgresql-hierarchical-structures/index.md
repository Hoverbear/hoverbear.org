+++
title = "Hierarchical Structures in PostgreSQL"
description = "Modelling hierarchical/team/categorical/tag data with arbitrary depths."
template = "blog/single.html"
[taxonomies]
tags = [
    "Tutorials",
    "PostgreSQL",
]
[extra]
[extra.image]
path =  "cover.jpg"
photographer = "Javier Allegue Barros; @soymeraki on Unsplash"
+++

It's a common pattern: a database developer at a startup is probably on the Product subteam of the Engineering team at their company. In a department store, shoes are a subcategory of clothing, while your favorite thermos is probably in the travel department.

In any Github organization, there are teams within teams within teams. In any large department store there are categories deeply nested. In any recipe book, there are many ways to classify food.

So how can we model them?

<!-- more -->

Jake (my boyfriend) and I have been exploring relational database concepts out of interest and pure geekery. This was a fun problem that I gave him and we got to work it out together. It was so fun we wanted to share! We won't beat the bush around with PostgreSQL installation, security, setup, blah blah at this time, let's just have some pure database fun for a few minutes!

## Core Problem

Handle a high amount of reads and a small amount of writes over a small to medium amount of keys (in this case, a text field), each of which *possibly* has a reference to a parent key.

In this concrete example, we will replicate team structures. Start with the teams existing inside some small organization, each with a `name` and possibly a `parent`:

| name | parent |
| :--- | :--- |
| Engineering | NULL |
| Geschäftstätigkeit | Engineering |
| Product | Engineering |
| Interns | Product |
| Administration | NULL |
| Human Resources | Administration |
| Finance | Administration |
| Marketing | NULL |
| Logistics | NULL |
| 国际化 | NULL |

Then somehow mixin the `path` which shows the datum's place in the hierarchy.

| name | parent | path |
| :--- | :--- | :--- |
| Administration | NULL | {Administration} |
| Finance | Administration | {Administration,Finance} |
| Human Resources | Administration | {Administration,Human Resources} |
| Engineering | NULL | {Engineering} |
| Geschäftstätigkeit | Engineering | {Engineering,Geschäftstätigkeit} |
| Product | Engineering | {Engineering,Product} |
| Interns | Product | {Engineering,Product,Interns} |
| Logistics | NULL | {Logistics} |
| Marketing | NULL | {Marketing} |
| 国际化 | NULL | {国际化} |

For this exercise, the exact format of the `path` is not important. An HTML string, a comma separated list, or any ordered collection is acceptable.

## Concepts

We'll actually cover two solutions, both of which demonstrate a few core concepts! 

For the first solution, ensure you're familiar with the ideas of [**`NULL`**](https://www.postgresql.org/docs/current/functions-comparison.html), [**Primary Keys**](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-PRIMARY-KEYS), and [**Foreign Keys**](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK). We'll need these for building safe, efficient linking between teams and their parents.

We'll then use a [**Materialized View**](https://www.postgresql.org/docs/12/sql-creatematerializedview.html) to create a sort of *cache* of the point-in-time team structure. We'll refresh this using a [**Function**](https://www.postgresql.org/docs/12/plpgsql-trigger.html) that is [**Triggered**](https://www.postgresql.org/docs/12/trigger-definition.html) whenever the original table is written to.

For the next solution, we'll explore the tailor-made [**`ltree`**](https://www.postgresql.org/docs/12/ltree.html) type that can solve our needs without the complex mechanics of the first solution. Further, this solution offers some useful functionality like `subpath`s.

## Before we start

Please make sure your database is in UTF-8! We're going to be exploring international text today. If you're not sure, let's create a new empty database, and go ahead and connect to it.

```sql
CREATE DATABASE organization WITH ENCODING 'UTF8' TEMPLATE=template0
```

## Solution 1: Materialized Views and Recursive CTEs

```sql
CREATE TABLE teams (
    name   TEXT
           UNIQUE NOT NULL
           PRIMARY KEY,
    parent TEXT
           REFERENCES teams (name)
);

CREATE MATERIALIZED VIEW team_structure AS
    WITH RECURSIVE teams_cte(name, parent, path) AS (
        SELECT teams.name, teams.parent, ARRAY [teams.name]
            FROM teams
            WHERE teams.parent IS NULL
        UNION ALL
        SELECT teams.name, teams.parent, array_append(teams_cte.path, teams.name)
            FROM teams_cte,
                 teams
            WHERE teams.parent = teams_cte.name
    )
    SELECT *
        FROM teams_cte;

CREATE FUNCTION refresh_team_structure() RETURNS TRIGGER
    LANGUAGE plpgsql AS
$$
BEGIN
    REFRESH MATERIALIZED VIEW team_structure;
    RETURN new;
END;
$$;

CREATE TRIGGER trigger_update_team_structure
    AFTER UPDATE OR INSERT OR DELETE OR TRUNCATE
    ON teams
EXECUTE PROCEDURE refresh_team_structure();
```

### Testing

Loading the example data, including a few complex cases, like spaces, umlauts, and Chinese script:

```sql
INSERT INTO teams (name, parent)
    VALUES ('Engineering', NULL),
           ('Geschäftstätigkeit', 'Engineering'),
           ('Product', 'Engineering'),
           ('Interns', 'Product'),
           ('Administration', NULL),
           ('Human Resources', 'Administration'),
           ('Finance', 'Administration'),
           ('Marketing', NULL),
           ('Logistics', NULL),
           ('国际化', NULL);
```

Listing all of them:

```sql
SELECT * FROM team_structure ORDER BY path;
```

| name | parent | path |
| :--- | :--- | :--- |
| Administration | NULL | {Administration} |
| Finance | Administration | {Administration,Finance} |
| Human Resources | Administration | {Administration,Human Resources} |
| Engineering | NULL | {Engineering} |
| Geschäftstätigkeit | Engineering | {Engineering,Geschäftstätigkeit} |
| Product | Engineering | {Engineering,Product} |
| Interns | Product | {Engineering,Product,Interns} |
| Logistics | NULL | {Logistics} |
| Marketing | NULL | {Marketing} |
| 国际化 | NULL | {国际化} |

A specific one:

```sql
SELECT * FROM team_structure WHERE name = 'Finance';
```

| name | parent | path |
| :--- | :--- | :--- |
| Finance | Administration | {Administration,Finance} |


Finding all subteams (deep) of a team:

```sql
SELECT * FROM team_structure WHERE 'Product' = ANY(path);
```

| name | parent | path |
| :--- | :--- | :--- |
| Product | Engineering | {Engineering,Product} |
| Interns | Product | {Engineering,Product,Interns} |

Let's look at the analysis:

```sql
> EXPLAIN ANALYZE SELECT * FROM team_structure WHERE 'Product' = ANY(path);
Seq Scan on team_structure  (cost=0.00..24.63 rows=3 width=96) (actual time=0.015..0.016 rows=2 loops=1)
  Filter: ('Product'::text = ANY (path))
  Rows Removed by Filter: 8
Planning Time: 0.047 ms
Execution Time: 0.026 ms
```

## Solution 2: `ltree` columns

> Thanks to [@focusaurus](https://twitter.com/focusaurus) for giving me the idea to add this section after publication!

`ltree` is an extension that you should *probably* already have if your PostgreSQL is an officially distributed package. The [PostgreSQL docs](https://www.postgresql.org/docs/12/ltree.html) on the `ltree` type summarize it quite well, so let's not just repeat them and let's solve our problem!

First, let's note some limitations:

> A label is a sequence of alphanumeric characters and underscores **(for example, in C locale the characters A-Za-z0-9_ are allowed)**. Labels must be **less than 256 bytes long**.

While the length limit is not terrible, the lack of support for the full UTF-8 spectrum, such as spaces or even words like 工程 or Geschäftstätigkeit is really limiting!

So, when we create our table, let's give it a `name` column where we can store any e̘̫̩̼͝x̢o̵̞͙̰͕t͈̼̺͍̥ͅi̻͉̺͚͕c̶̥̘͖̪̤̜ text we want. We'll also need a `slug` column containing the expected fragment in the `path`.

```sql
CREATE EXTENSION IF NOT EXISTS ltree;
CREATE TABLE teams (
    name text
        NOT NULL,
    slug text
        NOT NULL
        CHECK (slug ~* '^[A-Za-z0-9_]{1,255}$'),
    path ltree
        UNIQUE NOT NULL
        PRIMARY KEY
);
```

### Testing

Loading the data is a bit different, you'll notice we just insert paths. 

```sql
INSERT INTO teams (name, slug, path)
    VALUES ('Engineering', 'Engineering', 'Engineering'),
           ('Geschäftstätigkeit', 'Operations', 'Engineering.Operations'),
           ('Product', 'Product', 'Engineering.Product'),
           ('Interns', 'Interns', 'Engineering.Product.Interns'),
           ('Administration', 'Administration', 'Administration'),
           ('Human Resources', 'Human_Resources', 'Administration.Human_Resources'),
           ('Finance', 'Finance', 'Administration.Finance'),
           ('Marketing', 'Marketing', 'Marketing'),
           ('Logistics', 'Logistics', 'Logistics'),
           ('国际化', 'Internationalization','Internationalization');
```

Listing all of them:

```sql
SELECT * FROM teams ORDER BY path;
```

| name | slug | path |
| :--- | :--- | :--- |
| Administration | Administration | Administration |
| Finance | Finance | Administration.Finance |
| Human Resources | Human\_Resources | Administration.Human\_Resources |
| Engineering | Engineering | Engineering |
| Geschäftstätigkeit | Operations | Engineering.Operations |
| Product | Product | Engineering.Product |
| Interns | Interns | Engineering.Product.Interns |
| 国际化 | Internationalization | Internationalization |
| Logistics | Logistics | Logistics |
| Marketing | Marketing | Marketing |

```sql
SELECT * FROM teams WHERE slug = 'Finance';
```

| name | slug | path |
| :--- | :--- | :--- |
| Finance | Finance | Administration.Finance |

Finding all subteams (deep) of a team:

```sql
SELECT * FROM teams WHERE path @ 'Product';
```

| name | slug | path |
| :--- | :--- | :--- |
| Product | Product | Engineering.Product |
| Interns | Interns | Engineering.Product.Interns |

The query plan:

```sql
> EXPLAIN ANALYZE SELECT * FROM teams WHERE path @ 'Product';
Seq Scan on teams  (cost=0.00..18.13 rows=1 width=96) (actual time=0.013..0.014 rows=2 loops=1)
  Filter: (path @ 'Product'::ltxtquery)
  Rows Removed by Filter: 8
Planning Time: 0.055 ms
Execution Time: 0.029 ms
```

## Conclusion

As you can see, this problem can be tackled in a couple different ways, with some basic SQL concepts used together, or with already existing types! Don't let limitations turn you away, you can overcome them!

I hope this have given you some ideas about new things you can do with your database!
