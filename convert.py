# convert.py — запустіть один раз перед завантаженням
import csv
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
IMPORT_DIR = BASE_DIR / "import"

IMPORT_DIR.mkdir(exist_ok=True)


def convert_file(source_name, destination_name, headers):
    source_path = IMPORT_DIR / source_name
    destination_path = IMPORT_DIR / destination_name

    if not source_path.exists():
        raise FileNotFoundError(
            f"Не знайдено файл: {source_path}"
        )

    with open(source_path, encoding="latin-1") as f_in, \
         open(destination_path, "w", newline="", encoding="utf-8") as f_out:

        writer = csv.writer(f_out)
        writer.writerow(headers)

        for line in f_in:
            parts = line.rstrip("\r\n").split("::")
            writer.writerow(parts)

    print(f"Converted: {source_name} -> {destination_name}")


# movies.dat
convert_file(
    "movies.dat",
    "movies.csv",
    ["movieId", "title", "genres"]
)


# users.dat
convert_file(
    "users.dat",
    "users.csv",
    ["userId", "gender", "age", "occupation", "zip"]
)

# Remove ZIP column because it is not used in our graph schema.
users_csv = IMPORT_DIR / "users.csv"
temp_csv = IMPORT_DIR / "users.tmp.csv"

with open(users_csv, encoding="utf-8", newline="") as f_in, \
     open(temp_csv, "w", encoding="utf-8", newline="") as f_out:

    reader = csv.reader(f_in)
    writer = csv.writer(f_out)

    header = next(reader)
    writer.writerow(["userId", "gender", "age", "occupation"])

    for row in reader:
        writer.writerow(row[:4])

temp_csv.replace(users_csv)


# ratings.dat
convert_file(
    "ratings.dat",
    "ratings.csv",
    ["userId", "movieId", "rating", "timestamp"]
)


print()
print("Conversion completed successfully.")
print(f"CSV files are located in: {IMPORT_DIR}")