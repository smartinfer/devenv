#!/usr/bin/env bash
cluster 70-latex

item name=texlive \
  desc="MacTeX / TeX Live — VERIFY ONLY. This never installs or modifies TeX." \
  check='command -v pdflatex' version='tex --version' method=verify \
  home='' shell='path.zsh:/Library/TeX/texbin' \
  network='' \
  system='/usr/local/texlive:distribution|/Library/TeX:texbin symlinks' \
  apps='/Applications/TeX:GUI apps (MacTeX only)' \
  receipt='pkgutil receipt org.tug.mactex.*' \
  purge='sudo rm -rf /usr/local/texlive /Library/TeX /Applications/TeX' \
  manual='Already installed on this machine. To reinstall: https://tug.org/mactex/' \
  alt='BasicTeX (~100MB) + tlmgr install, if you ever rebuild from scratch' \
  install=install_texlive

install_texlive() {
  export PATH="/Library/TeX/texbin:$PATH"
  if ! have pdflatex && [ ! -d /usr/local/texlive ]; then
    err "No TeX Live found. This item verifies an existing install; it does not install TeX."
    return 1
  fi
  ok "$(tex --version 2>/dev/null | head -1)"
  inf "texbin : $(command -v pdflatex)"
  inf "dist   : $(ls -d /usr/local/texlive/*/ 2>/dev/null | tr '\n' ' ')"
  inf "size   : $(du -sh /usr/local/texlive 2>/dev/null | cut -f1)"
  shellent_add texlive path "/Library/TeX/texbin"
  regen_shell

  say "Paper packages"
  local missing="" p
  for p in latexmk biber natbib biblatex algorithm2e algorithmicx booktabs \
           multirow wrapfig xcolor pgfplots caption subcaption microtype \
           cleveref hyperref mathtools bbm dsfont enumitem xstring environ; do
    kpsewhich "$p.sty" >/dev/null 2>&1 || kpsewhich "$p.cls" >/dev/null 2>&1 || \
      have "$p" || missing="$missing $p"
  done
  if [ -z "$missing" ]; then ok "all paper packages resolve"
  else warn "not found:$missing"; inf "sudo tlmgr install$missing"; fi

  if have biber; then
    inf "biber $(biber --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)"
    dim "biber/biblatex skew only fails at the .bbl step — usually the night"
    dim "before a deadline. If it errors: sudo tlmgr update --all"
  else
    warn "biber missing — natbib papers are fine, biblatex ones will fail"
  fi

  say "Compile smoke test"
  local t; t=$(mktemp -d)
  cat > "$t/t.tex" <<'TEX'
\documentclass{article}
\usepackage{amsmath,amssymb,mathtools,booktabs,microtype,hyperref,cleveref}
\usepackage[ruled,vlined]{algorithm2e}
\usepackage{tikz}\usepackage{pgfplots}\pgfplotsset{compat=1.18}
\begin{document}
\section{Test}\label{sec:t}
\[ \mathcal{F}(\theta)=\mathbb{E}\big[\nabla\log p_\theta(x)\nabla\log p_\theta(x)^\top\big] \]
\begin{algorithm}[H]\KwIn{$B$}\For{$i\gets1$ \KwTo $n$}{allocate\;}\end{algorithm}
\begin{tikzpicture}\begin{axis}\addplot coordinates {(0,0)(1,1)};\end{axis}\end{tikzpicture}
\Cref{sec:t}\end{document}
TEX
  if ( cd "$t" && pdflatex -interaction=nonstopmode -halt-on-error t.tex >build.log 2>&1 ); then
    ok "pdflatex OK — amsmath, mathtools, algorithm2e, tikz, pgfplots, cleveref all resolve together"
  else
    warn "compile FAILED — first error:"
    grep -m1 -A3 '^!' "$t/build.log" 2>/dev/null | sed 's/^/      /'
    rm -rf "$t"; return 1
  fi
  rm -rf "$t"
  return 0
}
