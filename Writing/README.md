# Writing

Preliminary advisor brief, set up as the skeleton of the paper.

| File | Content |
|---|---|
| `main.tex` | The brief: summary box, introduction, literature, data, strategy, results, diagnostics, robustness, LP-DiD extension, next steps, appendix |
| `references.bib` | Bibliography (BibTeX, `plainnat`). Field `comment` marks the source of each entry: `[folder]` = PDF in `papers/`, `[web]` = checked online, `[check]` = verify before submission |
| `scripts/make_tables.py` | Writes `tables/*.tex` from the CSV results in `empirics/results/tables/` |
| `tables/` | Generated LaTeX tables — do not edit by hand |

Figures are not copied: `main.tex` reads them from `../empirics/results/figures/`.

## Build

From the project folder:

```
uv run python master.py --only writing_tables   # or: python3 Writing/scripts/make_tables.py
cd Writing && latexmk -pdf main.tex
```

After a new empirics run, the tables update automatically; numbers quoted in the **text** of `main.tex`
(marked with `% NUMBERS` comments) must be checked by hand. Red `[To do: ...]` and grey `[Paper: ...]` notes
can be hidden by setting `\showtodosfalse` in the preamble.
