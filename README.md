# RED

This repo contains the Julia code for the revision of the paper "Computer adption and the changing labor market" for the journal _Review of Economic Dynamics_ (RED, hence the repo name), which issued a "reject and resubmit", with the original paper [here](https://www.columbia.edu/~mm3509/research.html).

In this repo:
- The file `RED.org` is a [literate analysis](https://www.turing.ac.uk/events/masterclass-literate-programming-data-science/) document with discussion, code, and results all in one place. This document revises the data in the original paper with the suggestions from the referees. This project focusses on reproducible research by default.
- The file `RED.pdf` is the PDF output from the Org-mode export of `RED.org`.
- The directory `src` contains the Julia source code called by `RED.org` and doc-tests for that code.
- The directory `data` contains small data files for convenience and reproducibility.
- The directory `docs` contains the setup for doc-testing the code (because `Documenter.jl` requires building the documentation for doc-testing).

To run the code in `RED.org`, you need:
- [Emacs](https://www.gnu.org/software/emacs/), e.g. for MacOS you can run `brew install emacs --with-cocoa`
- [Org-mode](https://orgmode.org/), which now ships by default with Emacs
- [Julia](https://julialang.org/)
- [`ob-julia-doc`](https://github.com/gjkerns/ob-julia/blob/master/ob-julia-doc.org), a [contributed language to Org babel](https://orgmode.org/worg/org-contrib/babel/languages.html) to run Julia source code blocks in Org mode.

To compile the PDF, you need a LaTeX distribution. Then run `C-c C-e lp` to compile the PDF from the Org document.

If you are concerned about security, you may prefer to first tangle the code with Org-babel and run it in a Julia REPL, instead of running all the code in Org mode.
