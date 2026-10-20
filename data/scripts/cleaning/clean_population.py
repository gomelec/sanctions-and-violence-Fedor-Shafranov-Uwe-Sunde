"""
clean_population.py
Population totals from UN World Population Prospects 2024, as processed and published
by Our World in Data (OWID).

Input : data/raw/population/population_owid_WPP2024_processed.csv
        (OWID "Population – UN WPP": total population on 1 July, persons, 1950-2023;
         countries plus OWID/UN aggregates; metadata and readme files next to it)
Output: data/clean/population/wpp_population.csv
        one row per country x year: iso3c, entity, year, wpp_pop (millions, 1 July)

Changed 2026-10-20 (data/README.md, P4): source switched from the UN single-age file
(1 January) to the OWID-processed series (1 July = same timing as pwtpop).
Kept: rows with an ISO3 code, plus Kosovo (OWID code OWID_KOS -> XKX).
Dropped: continents, UN regions, income groups, "World" (codes OWID_*, UN_* or empty).

Source: UN, World Population Prospects (2024) – processed by Our World in Data.
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "data" / "raw" / "population" / "population_owid_WPP2024_processed.csv"
OUT = ROOT / "data" / "clean" / "population"
OUT.mkdir(parents=True, exist_ok=True)

d = pd.read_csv(RAW)
d = d.rename(columns={"Entity": "entity", "Code": "iso3c", "Year": "year", "all years": "wpp_pop"})

d["iso3c"] = d["iso3c"].replace({"OWID_KOS": "XKX"})          # Kosovo
is_country = d["iso3c"].fillna("").str.fullmatch(r"[A-Z]{3}")
print("dropped aggregates:", sorted(d.loc[~is_country, "entity"].unique()))
pop = d.loc[is_country, ["iso3c", "entity", "year", "wpp_pop"]].copy()
pop["wpp_pop"] = pop["wpp_pop"] / 1e6                          # persons -> millions (as pwtpop)
assert not pop.duplicated(["iso3c", "year"]).any()

pop.to_csv(OUT / "wpp_population.csv", index=False)
print("Wrote", OUT / "wpp_population.csv", pop.shape, "| countries:", pop["iso3c"].nunique(),
      "| years:", pop["year"].min(), "-", pop["year"].max())
