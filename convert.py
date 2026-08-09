# convert.py — запустіть один раз перед завантаженням
import csv
from pathlib import Path

IMPORT_DIR = Path("import")
IMPORT_DIR.mkdir(exist_ok=True)


def convert_file(source, target, headers, limit_columns=None):
    with open(source, encoding="latin-1") as f_in, \
         open(IMPORT_DIR / target, "w", newline="", encoding="utf-8") as f_out:
        writer = csv.writer(f_out)
        writer.writerow(headers)
        for line in f_in:
            parts = line.rstrip("\r\n").split("::")
            if limit_columns is not None:
                parts = parts[:limit_columns]
            writer.writerow(parts)


# MovieID::Title::Genres
convert_file(
    "movies.dat", "movies.csv",
    ["movieId", "title", "genres"]
)

# UserID::Gender::Age::Occupation::Zip-code
convert_file(
    "users.dat", "users.csv",
    ["userId", "gender", "age", "occupation"],
    limit_columns=4
)

# UserID::MovieID::Rating::Timestamp
convert_file(
    "ratings.dat", "ratings.csv",
    ["userId", "movieId", "rating", "timestamp"]
)

print("Conversion complete: import/movies.csv, import/users.csv, import/ratings.csv")