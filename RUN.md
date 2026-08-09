# RUN — Final submission

## Local Docker

```bash
docker compose up -d
python convert.py
```

Open:

```text
http://localhost:7474
```

Then execute, in order:

1. `queries/part2_load.cypher`
2. `queries/part3.cypher`
3. `queries/part4_supernodes.cypher`
4. `queries/part5_gds.cypher`

## Expected Part 2 validation

```text
Users = 6040
Movies = 3883
Genres = 18
Ratings = 1000209
HAS_GENRE = 6408
Nodes = 9941
Base relationships = 1006617
```

## GDS

Run Part 5 section-by-section. The practical evidence in `evidence/` was captured from the successful local Neo4j Browser run with GDS 2026.06.0.

## Submission

The main explanatory document is `README.md`. It contains:
- answers to the original questions;
- practical results;
- algorithm interpretations;
- Graph vs SQL comparison;
- final conclusions.

The PDF/DOCX report in `docs/` is a formatted version of the same final analysis.