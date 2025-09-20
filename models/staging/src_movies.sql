WITH raw_movies AS (
    SELECT * FROM MOVIELENS.WAR.raw_movies
)
SELECT 
    movieId AS movie_id,
    title,
    genres
FROM raw_movies
