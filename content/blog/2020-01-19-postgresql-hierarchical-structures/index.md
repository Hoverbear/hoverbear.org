+++
title = "Hierarchical Structures in PostgreSQL"
description = "Modelling hierarchical/team/categorical/tag data with arbitrary depths."
layout = "blog/single.html"
[taxonomies]
tags = [
    "Tutorials",
    "PostgreSQL",
]
[extra]
image = "cover.jpg"
image_credit = "Javier Allegue Barros; @soymeraki on Unsplash"
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
| Operations | Engineering |
| Product | Engineering |
| Interns | Product |
| Administration | NULL |
| Human Resources | Administration |
| Finance | Administration |
| Marketing | NULL |
| Logistics | NULL |

Then somehow mixin the `path` which shows the datum's place in the hierarchy.

| name | parent | path |
| :--- | :--- | :--- |
| Administration | NULL | {Administration} |
| Finance | Administration | {Administration,Finance} |
| Human Resources | Administration | {Administration,Human Resources} |
| Engineering | NULL | {Engineering} |
| Operations | Engineering | {Engineering,Operations} |
| Product | Engineering | {Engineering,Product} |
| Interns | Product | {Engineering,Product,Interns} |
| Logistics | NULL | {Logistics} |
| Marketing | NULL | {Marketing} |

For this exercise, the exact format of the `path` is not important. An HTML string, a comma separated list, or any ordered collection is acceptable.

## Concepts

Solving this problem involves a few core concepts!

Ensure you're familiar with the ideas of [**`NULL`**](https://www.postgresql.org/docs/current/functions-comparison.html), [**Primary Keys**](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-PRIMARY-KEYS), and [**Foreign Keys**](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK). We'll need these for building safe, efficient linking between teams and their parents.

We'll then use a [**Materialized View**](https://www.postgresql.org/docs/12/sql-creatematerializedview.html) to create a sort of *cache* of the point-in-time team structure. We'll refresh this using a [**Function**](https://www.postgresql.org/docs/12/plpgsql-trigger.html) that is [**Triggered**](https://www.postgresql.org/docs/12/trigger-definition.html) whenever the original table is written to.

## Implementation

```sql
BEGIN;
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
COMMIT;
```

## Testing

Loading the example data:

```sql
INSERT INTO teams (name, parent)
    VALUES ('Engineering', NULL),
           ('Operations', 'Engineering'),
           ('Product', 'Engineering'),
           ('Interns', 'Product'),
           ('Administration', NULL),
           ('Human Resources', 'Administration'),
           ('Finance', 'Administration'),
           ('Marketing', NULL),
           ('Logistics', NULL);
```

Listing all of them:

```sql
> SELECT * FROM team_structure ORDER BY path;
      name       |     parent     |                path
-----------------+----------------+------------------------------------
 Administration  |                | {Administration}
 Finance         | Administration | {Administration,Finance}
 Human Resources | Administration | {Administration,"Human Resources"}
 Engineering     |                | {Engineering}
 Operations      | Engineering    | {Engineering,Operations}
 Product         | Engineering    | {Engineering,Product}
 Interns         | Product        | {Engineering,Product,Interns}
 Logistics       |                | {Logistics}
 Marketing       |                | {Marketing}
(9 rows)
```

A specific one:

```sql
> SELECT * FROM team_structure WHERE name = 'Finance';
  name   |     parent     |           path
---------+----------------+--------------------------
 Finance | Administration | {Administration,Finance}
(1 row)

```

Finding all subteams (deep) of a team:

```sql
>  SELECT * FROM team_structure WHERE 'Product' = ANY(path);
  name   |   parent    |             path
---------+-------------+-------------------------------
 Product | Engineering | {Engineering,Product}
 Interns | Product     | {Engineering,Product,Interns}
(2 rows)
```

As you can see, this problem can be tackled deftly with some basic SQL concepts used together! I hope this have given you some ideas about new things you can do with your database!