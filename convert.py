# convert.py — запустіть один раз перед завантаженням
import csv
from pathlib import Path

DATA_DIR = Path(".")
IMPORT_DIR = Path("import")
IMPORT_DIR.mkdir(exist_ok=True)

def convert_file(src, dst, headers, encoding="latin-1"):
    with open(src, encoding=encoding) as f_in, open(
        IMPORT_DIR / dst, "w", newline="", encoding="utf-8"
    ) as f_out:
        writer = csv.writer(f_out)
        writer.writerow(headers)
        for line in f_in:
            parts = line.rstrip("\n\r").split("::")
            writer.writerow(parts)

# MovieID::Title::Genres
convert_file("movies.dat", "movies.csv", ["movieId", "title", "genres"])

# UserID::Gender::Age::Occupation::Zip-code
# Zip-code is deliberately omitted from the graph.
with open("users.dat", encoding="latin-1") as f_in, open(
    IMPORT_DIR / "users.csv", "w", newline="", encoding="utf-8"
) as f_out:
    writer = csv.writer(f_out)
    writer.writerow(["userId", "gender", "age", "occupation"])
    for line in f_in:
        parts = line.rstrip("\n\r").split("::")
        writer.writerow(parts[:4])

# UserID::MovieID::Rating::Timestamp
convert_file(
    "ratings.dat",
    "ratings.csv",
    ["userId", "movieId", "rating", "timestamp"],
)

print("Done: import/movies.csv, import/users.csv, import/ratings.csv")