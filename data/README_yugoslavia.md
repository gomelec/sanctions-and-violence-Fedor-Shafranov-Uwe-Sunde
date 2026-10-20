# GSDB "Yugoslavia" cases: attribution to the successor republics

How the sanctions that GSDB records against "Yugoslavia" are assigned to Slovenia, Croatia,
Bosnia and Herzegovina, North Macedonia and Montenegro in this project. Implemented 20 October 2026.
Adapted from the coding note `gsdb_yugoslavia_attribution_rules.md` (same date); the legal sources
are listed in section 9.

**Files**

| File | Role |
|---|---|
| `data/scripts/cleaning/gsdb_yugoslavia_attribution.csv` | the rules: one row per case × republic (action, years kept, reason, source, status) |
| `data/scripts/cleaning/clean_gsdb.py`, step 4a | applies the rules to the dyadic file |
| `data/clean/gsdb/gsdb_yugoslavia_attribution_log.csv` | every changed sender–target–year row, before and after |
| `data/README.md`, entries S3 / S3b | short summary in the main decision log |

**Status labels:** **[Sourced]** = legal text or database record in section 9; **[GSDB file]** = read from
`GSDB_V4.csv` or `GSDB_V4_dyadic.dta`; **[Not verified]** = no source checked, verify before publication.

---

## 1. Problem

GSDB's case file (`GSDB_V4.csv`) names **"Yugoslavia"** as the sanctioned state of 15 cases, but the
country-pair file (`GSDB_V4_dyadic.dta`) copies each of them to **all six** ex-Yugoslav codes
(SVN, HRV, BIH, MKD, SRB, MNE) [GSDB file]. Without correction Croatia, Bosnia and Macedonia had
`num_sanctioners` ≈ 180 in 1992–96 and 1998–2001, the same as Serbia, including the UN trade embargo
and the Kosovo-era measures that were aimed at Belgrade only.

## 2. Rule

For **Slovenia, Croatia, Bosnia and Herzegovina, North Macedonia**:

1. **Keep** the arms-embargo cases 419, 420, 422, 469, **as arms embargoes only**, until the
   republic-specific end year (section 3).
2. **Drop** all other "Yugoslavia" cases: 421, 470, 619, 620, 621, 636, 637, 638, 660, 676, 732 (section 4).
3. **Keep unchanged** every case that names the republic itself (section 5).
4. **Select by case ID, never by the `arms` flag**: 620 and 637 also have `arms = 1` but are FRY-only.

For **Montenegro from 2006** (its own state in the Gleditsch–Ward system): drop all "Yugoslavia" cases;
Serbia is the continuator (section 6).

**Serbia/Yugoslavia** (GW 345 to 2005, 340 from 2006) is **not changed**.

**How a dyad is changed.** A GSDB row is one sender × target × year and can bundle several cases
(e.g. `case_id = "420,470"`), with the sanction types (`arms`, `trade`, …) as the union over them.
For an affected row the script keeps only the cases allowed by the rules, then rebuilds the types:
kept "Yugoslavia" cases contribute `arms = 1` only; kept own-republic cases contribute their types
from the case file. A row with no case left is removed. Rows are only removed or reduced,
**never added** (see Croatia, section 3.2).

## 3. Arms embargo cases: who was covered and when

### 3.1 UN embargo, case 420 — kept 1991–1996 for all four republics [Sourced]

- Resolution 713 (Sept 1991) applied to all of the territory of former Yugoslavia (SIPRI, Slovenia record).
- Resolution 1021 (22 Nov 1995) ended it in phases; the sanctions committee set 13 March 1996 for most
  provisions (UN SC/6127). Heavy weapons stayed prohibited until arms-control conditions were met
  (UN SC/6193) — date not found [Not verified]. GSDB's end year 1996 is used.

### 3.2 EC/EU embargo, cases 419 (1991–92) and 469 (1992–2006) [Sourced]

| Republic | End year used | GSDB dyadic file had | Source |
|---|---|---|---|
| Slovenia | **1996** (case-by-case licensing; formal lifting Aug 1998 = robustness) | 1996 | CP 96/184/CFSP; Council Decision 1998/398/CFSP |
| North Macedonia | **1996** | 2006 → cut to 1996 | CP 96/184/CFSP |
| Croatia | **2000** | 1999 (no rows in 2000) | CP 2000/722/CFSP |
| Bosnia and Herzegovina | **2006** | 2006 | CP 2006/29/CFSP |
| FRY (Serbia, Montenegro) | not changed | 2006 | sources give Oct 2001 (CP 2001/719/CFSP) — see section 10 |

- The July 1991 embargo covered the whole SFRY; the scope was then narrowed step by step (GRIP, SIPRI).
- **Verified in the dyadic file** (the coding note could not check it): GSDB's per-republic end years for
  case 469 are Slovenia 1996, Croatia 1999, Bosnia 2006, Macedonia 2006 [GSDB file]. Macedonia is
  therefore cut from 2006 to 1996. Croatia 2000 is *not* added because GSDB has no Croatia rows for 2000
  (rows are never created) → Croatia's EU arms embargo is under-recorded by one year.
- Bosnia 1999: the Council only lifted the embargo for small arms for police and for demining equipment;
  otherwise it continued to 2006 (SIPRI).
- The 1998 extension to equipment for internal repression (CP 98/240/CFSP): unclear whether binding for
  Croatia and Bosnia [Not verified]; no effect on the coding.

### 3.3 US embargo, case 422 — kept 1991–1996, arms only [Not verified]

Scope of the US arms embargo not checked; treated like resolution 713. The financial component of 422 is
Serbia and Montenegro only (section 4.2).

## 4. Cases dropped for the four republics

| Case(s) | What | Why dropped | Status |
|---|---|---|---|
| 470 | UN res. 757, comprehensive sanctions 1992–96 | directed at the FRY from May 1992 (UN SC/6127) | [Sourced] |
| 421; financial part of 419, 422 | US/EC financial measures | EO 12808 blocked property of the governments of Serbia, Montenegro and the former SFRY; Treasury rules explicitly allowed debt of banks in Slovenia, Croatia, Bosnia, Macedonia (Bush 1992; Clinton 1993) | [Sourced] for 422; 421 [Not verified] |
| 619, 620, 621, 636, 637, 638 | Kosovo-era measures 1998–2001 | UN res. 1160 arms embargo on FRY territory incl. Kosovo (GRIP); EU fund freeze and flight/visa bans on FRY/Serbian governments (CP 98/326, 1999/318; UN S/1999/490); US freeze on FRY governments (Clinton 1998; CDOC 107-6) | [Sourced]; 637 [Not verified] |
| 660, 676, 732 | targeted measures 2000–16, `objective = democracy` | "Yugoslavia" = Serbia as continuator after 2006 | [Not verified] |

Known omission: the EC trade measures of November 1991 (Reg. 3300/91, then separate arrangements for the
four republics, Reg. 3567/91) are not in GSDB (case 419 has `trade = 0`) and are not added.

## 5. Cases that name a republic — kept as coded [Not verified]

505 (FRY → Bosnia, 1994–95), 515 (Greece → Macedonia, 1994–95), 559, 663 (US, "Balkans", 2001–23),
685 (US, ICC signatories), 710/711 (US → Croatia), 881 (EU → Bosnia, 2011–23), 995, 1033, 1211, 1239,
1240, 1308, 1321–1324, 1339, 1433, 1449, 1528. In the dyadic file the multi-target cases already have one
row per target country, so no splitting is needed.

## 6. Montenegro in the Gleditsch–Ward panel

- **Before 2006** Montenegro is part of Yugoslavia (GW 345): GSDB's MNE and SRB rows are recoded to YUG
  (drop/recode rules in `clean_gsdb.py`), so Montenegro is counted with Serbia, as one state. The partial
  US/EU exemptions for Montenegro in 1998–99 (Clinton 1998; CDOC 107-6; CP 1999/318/CFSP) cannot be
  represented separately and are not applied.
- **From 2006** Montenegro is GW 341: the "Yugoslavia" cases 469, 660, 676, 732 found there are dropped
  (Serbia as continuator) [Not verified].

## 7. What "Yugoslavia" means in this panel

| Period | Panel unit | GSDB "Yugoslavia" cases go to |
|---|---|---|
| to 1991 | Yugoslavia (345); Macedonia (343) from 1991 | Yugoslavia; Macedonia only the arms cases |
| 1992–2005 | Yugoslavia/FRY (345) = Serbia + Montenegro; Slovenia, Croatia, Bosnia, Macedonia separate | 345 all cases; republics arms cases only, until their end year |
| 2006 → | Serbia (340), Montenegro (341), from 2008 Kosovo (347) | Serbia only |

Pre-recognition years: in the GW list Macedonia exists from 1991, Slovenia, Croatia and Bosnia from 1992;
GSDB rows for these three before 1992 are dropped by the pre-independence rule.

## 8. Effect on the data

`num_sanctioners` (received), before → after:

| Year | Slovenia | Croatia | Bosnia | Macedonia | Montenegro |
|---|---|---|---|---|---|
| 1992–96 | 178–183 → same (arms only; trade/financial 178–183 → 0) | same | same (trade 2 in 1994–95 from case 505) | same | (part of 345) |
| 1997 | 0 | 0 | 0 | 15 → 0 | |
| 1998–99 | 0 | 183–187 → 15 | 183–187 → 15 | 183–187 → 0 | |
| 2000–01 | 0 | 0 | 189 → 15–16 | 189 → 0–1 | |
| 2002–06 | | | 17–27 → 16–26 | 17–27 → 1 | 27 → 1 (2006) |
| 2007–16 | | | 29–38 → 1–37 | 2–30 → 1 | 3–30 → 1–2 |

6,645 sender–target–year rows were affected: 2,504 removed, 4,141 kept as arms embargo only. Serbia/Yugoslavia
unchanged. On the sender side, `num_targets_sanctioned` and the `n_*_sent` counts fall for the senders of
these cases (1,104 sender-years). Every change is listed in `gsdb_yugoslavia_attribution_log.csv`.

## 9. Robustness specifications (not yet automated)

1. **Baseline:** this file (sections 2–7).
2. **Territorial maximum:** GSDB as is (all cases copied to all republics) = the data before 20 Oct 2026, kept in `archive/legacy_outputs/`.
3. **Serbia and Montenegro only:** set every row of the rules table to `drop`.
4. **Slovenia end year:** 1996 vs 1998 (edit `keep_to` for case 469 / SVN; rows for 1997–98 do not exist in GSDB, so 1998 cannot add years).
5. **Montenegro:** not separable before 2006 in the GW panel (section 6).

For effectiveness analyses, do not give republics that were not the target of coercion GSDB's `success` codes.

## 10. Open verification list — status: relatively resolved (2026-10-20)

The attribution rules above are the baseline. The remaining points below are **not pursued for now**;
instead the panel contains the controls `ex_yugo` and `ex_yugo_1991_2016` (data/README.md, P7) so that
the ex-Yugoslav state-years of the affected period can be controlled for or excluded in robustness checks.


1. Scope and dates of the US arms embargo (case 422).
2. Primary text of UN resolutions 713, 757 and 1160.
3. Whether the 1998 EU "internal repression" extension bound Croatia and Bosnia.
4. When the heavy-weapons restriction under resolution 1021 ended.
5. Primary sources for cases 421, 637, 660, 676 and 732.
6. FRY end year of the EU arms embargo: GSDB 2006 vs CP 2001/719/CFSP (Oct 2001) — Serbia/Yugoslavia left unchanged for now.
7. Croatia 2000 (EU embargo) missing from GSDB.
8. A citation for the SFRY → FRY → Serbia mapping (section 7).

## 11. Sources

**UN** — Res. 1021 (1995): https://press.un.org/en/1995/19951122.sc6127.html, https://unscr.com/en/resolutions/1021/ ;
SC/6193 (14 Mar 1996): https://press.un.org/en/1996/19960314.sc6193.html ;
S/1999/490: https://digitallibrary.un.org/record/272316/files/S_1999_490-EN.pdf

**EU legal texts** — CP 96/184/CFSP: https://eur-lex.europa.eu/eli/compos/1996/184/oj/eng ;
Reg. 3300/91: https://eu.vlex.com/vid/843835862 ; Reg. 3567/91: https://eur-lex.europa.eu/eli/reg/1991/3567/oj ;
Reg. 548/92: https://eur-lex.europa.eu/eli/reg/1992/548/oj/eng ; Reg. 1433/92: https://ferenda.lagen.nu/celex/31992R1433 ;
Reg. 3953/92: https://eur-lex.europa.eu/eli/reg/1992/3953/oj ; CP 98/326/CFSP: https://boe.es/doue/1998/143/L00001-00002.pdf ;
CP 1999/318/CFSP: https://lexaris.de/book/version/documentflat/head/2123114

**Databases** — SIPRI EU embargo on former SFRY: https://www.sipri.org/databases/embargoes/eu_arms_embargoes/yugoslavia ;
SIPRI Slovenia: https://www.sipri.org/node/1489 ; SIPRI Bosnia: https://www.sipri.org/databases/embargoes/eu_arms_embargoes/bosnia ;
GRIP Bosnia: https://embargo.grip.org/en/bosnia-and-herzegovina/ ; GRIP Croatia: https://embargo.grip.org/en/croatia/ ;
GRIP FRY: https://embargo.grip.org/en/federal-republic-of-yugoslavia/

**US** — Bush, 23 Dec 1992: https://www.govinfo.gov/content/pkg/PPP-1992-book2/html/PPP-1992-book2-doc-pg2209-2.htm ;
Presidency Project: https://www.presidency.ucsb.edu/node/219597 ;
Clinton, 6 Dec 1993: https://clintonwhitehouse6.archives.gov/1993/12/1993-12-06-presidents-letter-on-yugoslavia-economic-sanctions.text.html ;
Clinton, June 1998: https://clintonwhitehouse6.archives.gov/1998/06/1998-06-10-transmittal-to-congress-on-sanctions-in-kosovo.html ;
House Doc. 107-6: https://govinfo.gov/content/pkg/CDOC-107hdoc6/pdf/CDOC-107hdoc6.pdf

**Other** — GATT GD260/27-2: https://gatt-disputes.wto.org/sites/default/files/documents/GD260/27-2.pdf ;
Refworld summary of FRY sanctions (Oct 2000): https://webarchive.archive.unhcr.org/20221022024410if_/https://www.refworld.org/pdfid/3ae6a6ee14.pdf
