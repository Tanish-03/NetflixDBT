# NetflixDBT - MovieLens Data Transformation Project

A comprehensive dbt (data build tool) project for transforming and modeling MovieLens dataset into a structured data warehouse. This project implements a modern data engineering pipeline following dimensional modeling principles (Kimball methodology) to create a robust analytics-ready data model.

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Data Sources](#data-sources)
- [Project Structure](#project-structure)
- [Model Documentation](#model-documentation)
  - [Staging Layer](#staging-layer)
  - [Dimension Models](#dimension-models)
  - [Fact Models](#fact-models)
  - [Mart Models](#mart-models)
- [Snapshots](#snapshots)
- [Seeds](#seeds)
- [Configuration](#configuration)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Dependencies](#dependencies)

---

## Project Overview

**Project Name:** `netflix`
**Version:** `1.0.0`
**Profile:** `netflix`

This dbt project transforms raw MovieLens data from the `MOVIELENS.WAR` schema into a well-structured dimensional data model. The project follows a layered architecture approach:

1. **Staging Layer**: Raw data extraction and initial cleaning
2. **Dimension Layer**: Master data entities (movies, users, tags)
3. **Fact Layer**: Transactional and measurement data (ratings, genome scores)
4. **Mart Layer**: Business-ready aggregated and enriched datasets

---

## Architecture

The project follows a **medallion architecture** pattern with clear separation of concerns:

```
Raw Data (MOVIELENS.WAR) 
    ↓
Staging Models (Views)
    ↓
Dimension Models (Tables)
    ↓
Fact Models (Tables)
    ↓
Mart Models (Tables)
```

### Materialization Strategy

- **Staging Models**: Views (default)
- **Dimension Models**: Tables
- **Fact Models**: Tables
- **Mart Models**: Tables (configurable)

---

## Data Sources

All source data is extracted from the `MOVIELENS.WAR` schema in Snowflake:

| Source Table          | Description                               |
| --------------------- | ----------------------------------------- |
| `RAW_MOVIES`        | Movie metadata including title and genres |
| `RAW_RATINGS`       | User ratings for movies with timestamps   |
| `RAW_TAGS`          | User-generated tags for movies            |
| `RAW_GENOME_TAGS`   | Tag definitions from the genome project   |
| `RAW_GENOME_SCORES` | Relevance scores between movies and tags  |
| `RAW_LINKS`         | External ID mappings (IMDB, TMDB)         |

---

## Project Structure

```
NetflixDBT/
├── models/
│   ├── staging/          # Source data extraction and cleaning
│   ├── dim/              # Dimension tables
│   ├── fact/             # Fact tables
│   └── mart/             # Business-ready marts
├── snapshots/            # Slowly changing dimension snapshots
├── seeds/                # Static reference data
├── macros/               # Reusable SQL macros
├── tests/                # Data quality tests
├── analyses/             # Ad-hoc analysis queries
└── dbt_project.yml       # Project configuration
```

---

## Model Documentation

### Staging Layer

The staging layer (`models/staging/`) contains source models that extract and perform initial transformations on raw data. All staging models are materialized as **views** for performance and freshness.

#### `src_movies.sql`

**Purpose**: Extracts and standardizes movie metadata from raw source.

**Transformations**:

- Renames `movieId` → `movie_id`
- Preserves `title` and `genres` fields

**Output Columns**:

- `movie_id` (INTEGER): Unique movie identifier
- `title` (STRING): Movie title
- `genres` (STRING): Pipe-delimited genre list

---

#### `src_ratings.sql`

**Purpose**: Extracts user rating data with timestamp conversion.

**Transformations**:

- Renames `userId` → `user_id`, `movieId` → `movie_id`
- Converts Unix timestamp to `TIMESTAMP_LTZ` format
- Standardizes column naming

**Output Columns**:

- `user_id` (INTEGER): User identifier
- `movie_id` (INTEGER): Movie identifier
- `rating` (DECIMAL): Rating value (typically 0.5-5.0)
- `rating_timestamp` (TIMESTAMP_LTZ): When the rating was submitted

---

#### `src_tags.sql`

**Purpose**: Extracts user-generated movie tags with timestamps.

**Transformations**:

- Renames columns to snake_case
- Converts timestamp to `TIMESTAMP_LTZ`
- Preserves tag text as-is

**Output Columns**:

- `user_id` (INTEGER): User who created the tag
- `movie_id` (INTEGER): Movie being tagged
- `tag` (STRING): Tag text
- `tag_timestamp` (TIMESTAMP_LTZ): When the tag was created

---

#### `src_genome_tags.sql`

**Purpose**: Extracts tag definitions from the MovieLens genome project.

**Transformations**:

- Renames `tagId` → `tag_id`
- Preserves tag text

**Output Columns**:

- `tag_id` (INTEGER): Unique tag identifier
- `tag` (STRING): Tag name/description

---

#### `src_genome_score.sql`

**Purpose**: Extracts relevance scores between movies and genome tags.

**Transformations**:

- Renames `movieId` → `movie_id`, `tagId` → `tag_id`
- Preserves relevance score

**Output Columns**:

- `movie_id` (INTEGER): Movie identifier
- `tag_id` (INTEGER): Tag identifier
- `relevance` (DECIMAL): Relevance score (0-1 scale)

---

#### `src_links.sql`

**Purpose**: Extracts external ID mappings for movies.

**Transformations**:

- Renames columns to snake_case
- Maps to IMDB and TMDB identifiers

**Output Columns**:

- `movie_id` (INTEGER): Internal movie identifier
- `imdb_id` (STRING): IMDB identifier
- `tmdb_id` (STRING): TMDB (The Movie Database) identifier

---

### Dimension Models

Dimension models (`models/dim/`) represent master data entities. All dimension models are materialized as **tables** for query performance.

#### `dim_movies.sql`

**Purpose**: Creates a cleaned and standardized movies dimension table.

**Transformations**:

- Applies `INITCAP()` and `TRIM()` to movie titles for consistency
- Splits pipe-delimited genres into an array (`genre_array`)
- Preserves original genres string

**Output Columns**:

- `movie_id` (INTEGER): Primary key
- `movie_title` (STRING): Cleaned and formatted title
- `genre_array` (ARRAY): Array of individual genres
- `genres` (STRING): Original pipe-delimited genres

**Dependencies**: `src_movies`

---

#### `dim_users.sql`

**Purpose**: Creates a unified user dimension from ratings and tags.

**Transformations**:

- Combines distinct users from both ratings and tags tables
- Uses `UNION` to deduplicate users
- Ensures comprehensive user coverage

**Output Columns**:

- `user_id` (INTEGER): Primary key, unique user identifier

**Dependencies**: `src_ratings`, `src_tags`

---

#### `dim_genome_tags.sql`

**Purpose**: Creates a standardized tags dimension from genome tags.

**Transformations**:

- Applies `INITCAP()` and `TRIM()` for consistent tag formatting
- Standardizes tag naming conventions

**Output Columns**:

- `tag_id` (INTEGER): Primary key
- `tag_name` (STRING): Cleaned and formatted tag name

**Dependencies**: `src_genome_tags`

---

#### `dim_movies_with_tags.sql`

**Purpose**: Creates a denormalized view combining movies with their associated tags and relevance scores.

**Transformations**:

- Joins movies, tags, and genome scores
- Creates a flat structure for easy querying
- Materialized as ephemeral (not persisted)

**Output Columns**:

- `movie_id` (INTEGER): Movie identifier
- `movie_title` (STRING): Movie title
- `genres` (STRING): Movie genres
- `tag_name` (STRING): Associated tag name
- `relevance_score` (DECIMAL): Relevance score for the tag

**Dependencies**: `dim_movies`, `dim_genome_tags`, `fct_genome_scores`

**Note**: This model is configured as `ephemeral` (note: there's a typo in the config as `empheral`), meaning it's not materialized but used as a CTE in downstream models.

---

### Fact Models

Fact models (`models/fact/`) represent transactional and measurement data. All fact models are materialized as **tables**.

#### `fct_ratings.sql`

**Purpose**: Creates the ratings fact table with incremental loading support.

**Transformations**:

- Filters out NULL ratings
- Implements incremental loading strategy
- Only processes new ratings since last run

**Configuration**:

- **Materialization**: Incremental table
- **Incremental Strategy**: Based on `rating_timestamp`
- **Schema Change Policy**: Fail on schema changes

**Output Columns**:

- `user_id` (INTEGER): User who gave the rating
- `movie_id` (INTEGER): Movie being rated
- `rating` (DECIMAL): Rating value
- `rating_timestamp` (TIMESTAMP_LTZ): When rating was submitted

**Incremental Logic**:

```sql
WHERE rating_timestamp > (SELECT MAX(rating_timestamp) FROM {{ this }})
```

**Dependencies**: `src_ratings`

---

#### `fct_genome_scores.sql`

**Purpose**: Creates the genome scores fact table with filtered relevance data.

**Transformations**:

- Filters out zero relevance scores (only keeps meaningful associations)
- Rounds relevance to 4 decimal places for consistency
- Standardizes column naming

**Output Columns**:

- `movie_id` (INTEGER): Movie identifier
- `tag_id` (INTEGER): Tag identifier
- `relevance_score` (DECIMAL): Relevance score (rounded to 4 decimals, > 0)

**Dependencies**: `src_genome_score`

---

### Mart Models

Mart models (`models/mart/`) are business-ready aggregated datasets for end-user consumption.

#### `mart_movie_releases.sql`

**Purpose**: Enriches ratings fact table with movie release date information.

**Transformations**:

- Joins ratings with seed data for release dates
- Adds flag indicating whether release date is available
- Creates a comprehensive view for release date analysis

**Output Columns**:

- All columns from `fct_ratings`:
  - `user_id`
  - `movie_id`
  - `rating`
  - `rating_timestamp`
- `release_info_unavailable` (STRING): 'known' or 'unknown' flag

**Dependencies**: `fct_ratings`, `seed_movie_release_date`

---

## Snapshots

### `snap_tags.sql`

**Purpose**: Implements slowly changing dimension (SCD) Type 2 tracking for user tags.

**Configuration**:

- **Strategy**: Timestamp-based
- **Unique Key**: `['user_id', 'movie_id', 'tag']`
- **Updated At**: `tag_timestamp`
- **Invalidate Hard Deletes**: True

**Behavior**:

- Tracks historical changes to tags
- Creates new snapshot records when tags are updated
- Maintains full history of tag assignments

**Note**: Currently limited to 100 records for testing purposes.

**Dependencies**: `src_tags`

---

## Seeds

### `seed_movie_release_date.csv`

**Purpose**: Static reference data containing movie release dates.

**Schema**:

- `movie_id` (INTEGER): Movie identifier
- `release_date` (DATE): Movie release date

**Usage**: Used to enrich fact tables with release date information in mart models.

**Note**: This is a sample seed file with limited records. In production, this should be populated with complete release date data.

---

## Configuration

### Project Configuration (`dbt_project.yml`)

```yaml
name: 'netflix'
version: '1.0.0'
profile: 'netflix'

# Materialization defaults
models:
  netflix:
    +materialized: view          # Default for all models
    dim:
      +materialized: table        # Override for dimensions
    fact:
      +materialized: table        # Override for facts
```

### Model-Specific Configurations

- **`fct_ratings`**: Incremental materialization with timestamp-based strategy
- **`dim_movies_with_tags`**: Ephemeral materialization (CTE only)
- **`mart_movie_releases`**: Explicit table materialization

---

## Getting Started

### Prerequisites

- dbt Core installed (version 1.0.0 or higher)
- Access to Snowflake data warehouse
- Valid `netflix` profile configured in `~/.dbt/profiles.yml`

### Profile Configuration

Ensure your `profiles.yml` contains:

```yaml
netflix:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <your-account>
      user: <your-user>
      password: <your-password>
      role: <your-role>
      database: <your-database>
      warehouse: <your-warehouse>
      schema: <your-schema>
      threads: 4
```

### Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd NetflixDBT
```

2. Install dbt dependencies (if any):

```bash
dbt deps
```

3. Verify connection:

```bash
dbt debug
```

---

## Usage

### Running Models

**Run all models:**

```bash
dbt run
```

**Run specific model:**

```bash
dbt run --select dim_movies
```

**Run models by layer:**

```bash
dbt run --select staging.*    # Run all staging models
dbt run --select dim.*        # Run all dimension models
dbt run --select fact.*       # Run all fact models
dbt run --select mart.*       # Run all mart models
```

**Run with full refresh (for incremental models):**

```bash
dbt run --select fct_ratings --full-refresh
```

### Testing

**Run all tests:**

```bash
dbt test
```

**Run tests for specific model:**

```bash
dbt test --select dim_movies
```

### Generating Documentation

**Generate and serve documentation:**

```bash
dbt docs generate
dbt docs serve
```

### Loading Seeds

**Load seed data:**

```bash
dbt seed
```

### Creating Snapshots

**Run snapshots:**

```bash
dbt snapshot
```

### Incremental Model Updates

The `fct_ratings` model uses incremental materialization. On subsequent runs, it will:

1. Query existing table for maximum `rating_timestamp`
2. Only process new ratings since last run
3. Append new records to the table

---

## Dependencies

### External Dependencies

- **dbt-core**: Core dbt package
- **dbt-snowflake**: Snowflake adapter for dbt

### Data Dependencies

- Access to `MOVIELENS.WAR` schema in Snowflake
- Required source tables:
  - `RAW_MOVIES`
  - `RAW_RATINGS`
  - `RAW_TAGS`
  - `RAW_GENOME_TAGS`
  - `RAW_GENOME_SCORES`
  - `RAW_LINKS`

---

## Data Model Relationships

```
dim_users ──┐
            ├──> fct_ratings ──> mart_movie_releases
dim_movies ─┘

dim_movies ──┐
             ├──> fct_genome_scores ──┐
dim_genome_tags ──┘                   ├──> dim_movies_with_tags
                                      ┘
```

---

## Best Practices

1. **Incremental Models**: Use incremental materialization for large fact tables (`fct_ratings`)
2. **Data Quality**: Implement tests for primary keys, not null constraints, and referential integrity
3. **Documentation**: Document all models with descriptions and column definitions
4. **Version Control**: All dbt models are version controlled for collaboration
5. **Testing**: Run `dbt test` regularly to ensure data quality

---

## Troubleshooting

### Common Issues

1. **Connection Errors**: Verify `profiles.yml` configuration and network access
2. **Schema Not Found**: Ensure source tables exist in `MOVIELENS.WAR` schema
3. **Incremental Model Issues**: Use `--full-refresh` flag to rebuild from scratch
4. **Snapshot Errors**: Check unique key configuration and timestamp column format

---

## Contributing

When adding new models:

1. Follow the naming convention: `{layer}_{entity}.sql`
2. Add appropriate materialization configs
3. Document transformations and business logic
4. Add data quality tests
5. Update this README with model documentation

---

## License

[Specify your license here]

---

## Contact

[Add contact information or support channels]
