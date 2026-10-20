"""
clean_gdp.py
GDP per capita, PPP (constant 2021 international $), World Bank World Development
Indicators, as processed and published by Our World in Data (OWID).

Input : data/raw/gdp-per-capita-worldbank/gdp-per-capita-worldbank.csv
        (OWID grapher "GDP per capita" = WDI NY.GDP.PCAP.PP.KD, 1990-2025; countries
         plus World Bank / OWID aggregates; metadata and readme files next to it)
Output: data/clean/gdp/wb_gdppc.csv
        one row per country x year: iso3c, entity, year, wb_gdppc

Added 2026-10-20 (data/README.md, P5). Used only for its growth rates, to extend
mrgdppc beyond 2019. Kept: rows with an ISO3 code, plus Kosovo (OWID_KOS -> XKX).
Dropped: World Bank regions (WB_*), income groups, EU27, World (OWID_*).

Source: Eurostat, OECD, IMF, and World Bank (2026) – with minor processing by Our World in Data.
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "data" / "raw" / "gdp-per-capita-worldbank" / "gdp-per-capita-worldbank.csv"
OUT = ROOT / "data" / "clean" / "gdp"
OUT.mkdir(parents=True, exist_ok=True)

d = pd.read_csv(RAW)
d = d.rename(columns={"Entity": "entity", "Code": "iso3c", "Year": "year", "GDP per capita": "wb_gdppc"})
d["iso3c"] = d["iso3c"].replace({"OWID_KOS": "XKX"})          # Kosovo
is_country = d["iso3c"].fillna("").str.fullmatch(r"[A-Z]{3}")
print("dropped aggregates:", sorted(d.loc[~is_country, "entity"].unique()))
gdp = d.loc[is_country & d["wb_gdppc"].notna(), ["iso3c", "entity", "year", "wb_gdppc"]].copy()
assert not gdp.duplicated(["iso3c", "year"]).any()

gdp.to_csv(OUT / "wb_gdppc.csv", index=False)
print("Wrote", OUT / "wb_gdppc.csv", gdp.shape, "| countries:", gdp["iso3c"].nunique(),
      "| years:", gdp["year"].min(), "-", gdp["year"].max())
