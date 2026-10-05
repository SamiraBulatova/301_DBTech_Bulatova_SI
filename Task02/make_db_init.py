import csv
import os

TABLES = {
    'movies':  (['id', 'title', 'year', 'genres'],
                ['INTEGER PRIMARY KEY', 'TEXT', 'INTEGER', 'TEXT']),
    'ratings': (['id', 'user_id', 'movie_id', 'rating', 'timestamp'],
                ['INTEGER PRIMARY KEY', 'INTEGER', 'INTEGER', 'REAL', 'INTEGER']),
    'tags':    (['id', 'user_id', 'movie_id', 'tag', 'timestamp'],
                ['INTEGER PRIMARY KEY', 'INTEGER', 'INTEGER', 'TEXT', 'INTEGER']),
    'users':   (['id', 'name', 'email', 'gender', 'register_date', 'occupation'],
                ['INTEGER PRIMARY KEY', 'TEXT', 'TEXT', 'TEXT', 'TEXT', 'TEXT']),
}

FILES = {
    'movies':  'movies.csv',
    'ratings': 'ratings.csv',
    'tags':    'tags.csv',
    'users':   'users.txt',
}

def sql_str(value):
    return "'" + str(value).replace("'", "''") + "'"

def sql_num(value, is_int=False):
    v = str(value).strip()
    if v == '':
        return 'NULL'
    if is_int:
        return str(int(float(v)))  # 4.0 -> 4
    return str(v)

with open('db_init.sql', 'w', encoding='utf-8') as out:
    out.write("PRAGMA foreign_keys=OFF;\n")
    out.write("BEGIN TRANSACTION;\n")

    for table, (columns, types) in TABLES.items():
        out.write(f"DROP TABLE IF EXISTS {table};\n")
        cols_sql = ', '.join([f"{c} {t}" for c, t in zip(columns, types)])
        out.write(f"CREATE TABLE {table} ({cols_sql});\n")

        csv_file = FILES[table]
        if not os.path.exists(csv_file):
            print(f"Файл {csv_file} не найден, пропускаю таблицу {table}")
            continue

        with open(csv_file, 'r', encoding='utf-8') as f:
            delimiter = '|' if table == 'users' else ','
            reader = csv.reader(f, delimiter=delimiter)
            header = next(reader)

            if table == 'movies':
                for row in reader:
                    movie_id = row[0]
                    title = row[1]
                    genres = row[2]
                    year = ''
                    if '(' in title and ')' in title:
                        year_part = title[title.rfind('(')+1:title.rfind(')')]
                        if year_part.isdigit():
                            year = year_part
                            title = title[:title.rfind('(')].strip()
                    vals = f"{sql_num(movie_id, is_int=True)}, {sql_str(title)}, {sql_num(year, is_int=True)}, {sql_str(genres)}"
                    out.write(f"INSERT INTO movies VALUES ({vals});\n")

            elif table == 'users':
                for row in reader:
                    vals = ", ".join([
                        sql_num(row[0], is_int=True),
                        sql_str(row[1]),
                        sql_str(row[2]),
                        sql_str(row[3]),
                        sql_str(row[4]),
                        sql_str(row[5]),
                    ])
                    out.write(f"INSERT INTO users VALUES ({vals});\n")

            elif table == 'ratings':
                for idx, row in enumerate(reader, start=1):
                    vals = ", ".join([
                        str(idx),
                        sql_num(row[0], is_int=True),
                        sql_num(row[1], is_int=True),
                        sql_num(row[2]),  # rating — REAL
                        sql_num(row[3], is_int=True),
                    ])
                    out.write(f"INSERT INTO ratings VALUES ({vals});\n")

            elif table == 'tags':
                for idx, row in enumerate(reader, start=1):
                    vals = ", ".join([
                        str(idx),
                        sql_num(row[0], is_int=True),
                        sql_num(row[1], is_int=True),
                        sql_str(row[2]),
                        sql_num(row[3], is_int=True),
                    ])
                    out.write(f"INSERT INTO tags VALUES ({vals});\n")

    out.write("COMMIT;\n")

print("db_init.sql создан успешно.")