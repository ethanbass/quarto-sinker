# sinker

A Quarto filter that moves figures and tables to the end of the document, or
under a heading such as "Supporting Information", and keeps their
cross-references working. It does what the LaTeX `endfloat` package does, but
works for Word, PDF, HTML and Typst. It is not a port of `endfloat` and doesn't
add "[Figure 1 about here]" markers.

Journals often ask for figures and tables at the end of a manuscript, or for
supplementary figures in a separate section. With sinker you can keep each
figure next to the code and text that produce it and still meet those rules.

## Installation

Open a terminal in the folder that holds your document and run:

```bash
quarto add ethanbass/quarto-sinker
```

This copies the extension into an `_extensions/` folder next to your document.
Quarto has no global install: each project gets its own copy, so you need to
run `quarto add` once in every project that uses sinker. Quarto finds the
extension only in two places:

- the folder that contains the document, or
- the root of a Quarto project (the folder with `_quarto.yml`), for documents
  anywhere inside that project.

An `_extensions/` folder anywhere else, such as a parent folder of a project,
is ignored, and the render fails with an error naming `sinker`.

Keep `_extensions/` with your document and check it into version control. The
document then renders on any machine, including your collaborators', without a
separate install. To update a project to a newer sinker, run `quarto add` in it
again.

### Using one copy for all your documents

If you only render on your own computer, you can skip the per-project install
and point `filters:` at the Lua file instead:

```yaml
filters:
  - /path/to/quarto-sinker/_extensions/sinker/sinker.lua
```

This is convenient for one-off documents, but the document will only render on
a machine with sinker at that path. Every document also picks up whatever
version is there, so updating sinker can change how an older document renders.
For anything you share or need to reproduce, install the extension in the
project.

## Usage

Add the filter, then tell it which floats to move and where:

```yaml
filters:
  - sinker
sinker:
  kinds: [fig, tbl]
```

This moves every figure and table to the end of the document. To move them
under a heading instead, give the heading's ID:

```yaml
sinker:
  kinds: [fig, tbl]
  to: figures-and-tables
```

`## Figures and Tables` gets the ID `figures-and-tables` automatically. You can
also set one yourself with `## Figures and Tables {#floats}` and write
`to: floats`.

### Options

- `kinds`: label prefixes to move. A float moves if its label starts with one of
  them, so `fig` matches `@fig-growth` and `tbl` matches `@tbl-anova`. Custom
  float kinds work too.
- `to`: ID of the heading to move them under. If you leave it out, or the
  heading doesn't exist, the floats go to the end of the document.
- `pagebreak`: set to `true` to put each moved float on its own page. sinker
  adds a page break after each one; in HTML the break only applies when
  printing. In PDF it uses `\clearpage`, which also stops LaTeX from moving
  floats past the break. Defaults to `false`.

### Several destinations

Give a list of groups to send different kinds to different sections:

```yaml
sinker:
  - kinds: [suppfig]
    to: supporting-information
  - kinds: [tbl]
    to: appendix-tables
```

Groups that share a heading go under it in the order you list them. If two
groups list the same kind, the first one wins.

## Main-text and supplementary figures

To keep some figures in the main text and move the rest, define a custom float
kind for the supplementary ones. Each kind then gets its own numbering and its
own caption prefix:

```yaml
filters:
  - sinker
sinker:
  kinds: [suppfig]
  to: supporting-information
crossref:
  custom:
    - kind: float
      key: suppfig
      reference-prefix: Supplementary Figure
      latex-env: suppfig
```

Main-text figures keep the `fig-` prefix and stay where they are. Write
supplementary figures as divs:

````markdown
:::{#suppfig-residuals}

```{r}
plot(fit, which = 1)
```

Residuals against fitted values.

:::
````

The same pattern works for tables. `example.qmd` shows a complete document.

## How floats are placed

- A float moves only if it comes before its destination heading. Floats already
  below the heading stay where they are.
- Moved floats keep their original order and go directly under the heading,
  ahead of any text in that section.
- Quarto numbers floats in their final order, so the numbers match what a reader
  sees.
- Subfigures move with their parent figure.
- Floats need a label. An unlabelled figure has no prefix and never moves.
- sinker moves floats that sit at the top level of the document, in code-cell
  output or inside a `::: landscape` block. A float nested in anything else,
  such as a callout or a column layout, stays in place, and sinker prints a
  warning naming it.

## PDF output

- A custom float kind needs a `latex-env` entry, as in the example above, or the
  LaTeX render fails.
- LaTeX may still push a float onto a later page, past the next heading. To keep
  floats inside their section, load `placeins` and put `\FloatBarrier` before
  the next heading.

## Compatibility

Tested with Quarto 1.7.31 for `docx`, `pdf`, `html` and `typst` output. sinker
finds floats through an internal Quarto attribute (`__quarto_custom_id`), so a
future Quarto release could break it. Please open an issue if it does.

The filter was written with Claude (Anthropic) and tested on the example
document and a journal manuscript.
