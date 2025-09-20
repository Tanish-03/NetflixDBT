{ % snapshot snap_tags %}

{{
    config(
        target_schema = 'snapshots',
        unique_key=['user_id','movie_id','tag'],
        strategy='timestamp',
        updated_at='tag_timestamp',
        invalidate_hard_deletes=True
    )
}}
SELECT  user_id,
movie_id,
tag,
CAST(tag_timestamp AS TIMESTAMP_NTZ) AS tag_timestamp
FROM {{red('src_tags')}}
LIMIT 100
(%endpoint%)