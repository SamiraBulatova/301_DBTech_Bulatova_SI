#!/bin/bash
chcp 65001

# 1. Создание базы данных
sqlite3 movies_rating.db < Task05/db_init.sql

echo "1. Для каждого фильма выведите его название, год выпуска и средний рейтинг. Дополнительно добавьте столбец rank_by_avg_rating (ранг по убыванию среднего рейтинга). Оставить 10 фильмов с наибольшим рангом."
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "
SELECT title, year, avg_rating, 
       RANK() OVER (ORDER BY avg_rating DESC) AS rank_by_avg_rating
FROM (
    SELECT m.id, m.title, m.year, AVG(r.rating) AS avg_rating
    FROM movies m
    JOIN ratings r ON m.id = r.movie_id
    GROUP BY m.id
) 
ORDER BY rank_by_avg_rating
LIMIT 10;
"
echo " "

echo "2. С помощью рекурсивного CTE выделить все жанры фильмов. Для каждого жанра рассчитать средний рейтинг. Выведите genre, avg_rating и ранг жанра по убыванию среднего рейтинга."
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "
WITH RECURSIVE split_genres(id, genre, rest) AS (
    SELECT id, '', genres || '|' FROM movies
    UNION ALL
    SELECT id, 
           substr(rest, 1, instr(rest, '|') - 1),
           substr(rest, instr(rest, '|') + 1)
    FROM split_genres
    WHERE rest <> ''
),
all_genres AS (
    SELECT DISTINCT genre FROM split_genres WHERE genre <> ''
),
genre_ratings AS (
    SELECT sg.genre, AVG(r.rating) AS avg_rating
    FROM split_genres sg
    JOIN ratings r ON sg.id = r.movie_id
    WHERE sg.genre <> ''
    GROUP BY sg.genre
)
SELECT genre, avg_rating,
       RANK() OVER (ORDER BY avg_rating DESC) AS rank
FROM genre_ratings
ORDER BY rank;
"
echo " "

echo "3. Посчитайте количество фильмов в каждом жанре. Выведите два столбца: genre и movie_count, отсортировав результат по убыванию количества фильмов."
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "
WITH RECURSIVE split_genres(id, genre, rest) AS (
    SELECT id, '', genres || '|' FROM movies
    UNION ALL
    SELECT id, 
           substr(rest, 1, instr(rest, '|') - 1),
           substr(rest, instr(rest, '|') + 1)
    FROM split_genres
    WHERE rest <> ''
)
SELECT genre, COUNT(DISTINCT id) AS movie_count
FROM split_genres
WHERE genre <> ''
GROUP BY genre
ORDER BY movie_count DESC;
"
echo " "

echo "4. Найдите жанры, в которых чаще всего оставляют теги. Выведите genre, tag_count и долю этого жанра в общем числе тегов (tag_share) в процентах."
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "
WITH RECURSIVE split_genres(id, genre, rest) AS (
    SELECT id, '', genres || '|' FROM movies
    UNION ALL
    SELECT id, 
           substr(rest, 1, instr(rest, '|') - 1),
           substr(rest, instr(rest, '|') + 1)
    FROM split_genres
    WHERE rest <> ''
),
genre_tags AS (
    SELECT sg.genre, COUNT(t.id) AS tag_count
    FROM split_genres sg
    JOIN tags t ON sg.id = t.movie_id
    WHERE sg.genre <> ''
    GROUP BY sg.genre
),
total_tags AS (
    SELECT COUNT(*) AS total FROM tags
)
SELECT gt.genre, gt.tag_count,
       ROUND((gt.tag_count * 100.0) / (SELECT total FROM total_tags), 2) AS tag_share
FROM genre_tags gt
ORDER BY gt.tag_count DESC;
"
echo " "

echo "5. Для каждого пользователя рассчитайте: общее количество оценок, средний выставленный рейтинг, дату первой и последней оценки. Выведите 10 первых строк по убыванию количества оценок."
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "
SELECT user_id, 
       COUNT(rating) AS rating_count, 
       AVG(rating) AS avg_rating, 
       datetime(MIN(timestamp), 'unixepoch') AS first_rating_date, 
       datetime(MAX(timestamp), 'unixepoch') AS last_rating_date
FROM ratings
GROUP BY user_id
ORDER BY rating_count DESC
LIMIT 10;
"
echo " "

echo "6. Сегментируйте пользователей по типу поведения (Комментаторы, Оценщики, Активные, Пассивные). Выведите user_id, число оценок, число тегов и категорию."
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "
WITH user_stats AS (
    SELECT u.id AS user_id,
           (SELECT COUNT(*) FROM ratings r WHERE r.user_id = u.id) AS rating_count,
           (SELECT COUNT(*) FROM tags t WHERE t.user_id = u.id) AS tag_count
    FROM users u
)
SELECT user_id, rating_count, tag_count,
       CASE 
           WHEN rating_count >= 10 AND tag_count >= 10 THEN 'Активные'
           WHEN rating_count > tag_count THEN 'Оценщики'
           WHEN tag_count > rating_count THEN 'Комментаторы'
           WHEN rating_count < 5 AND tag_count < 5 THEN 'Пассивные'
           ELSE 'Другое'
       END AS category
FROM user_stats;
"
echo " "

echo "7. Для каждого пользователя выведите его имя и последний фильм, который он оценил. Если не оценивал, то NULL в полях фильма."
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "
WITH last_ratings AS (
    SELECT user_id, movie_id, timestamp,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY timestamp DESC) as rn
    FROM ratings
)
SELECT u.id AS user_id, u.name AS name, 
       m.title AS last_rated_movie_title, 
       datetime(lr.timestamp, 'unixepoch') AS last_rating_timestamp
FROM users u
LEFT JOIN last_ratings lr ON u.id = lr.user_id AND lr.rn = 1
LEFT JOIN movies m ON lr.movie_id = m.id
ORDER BY u.id;
"
echo " "