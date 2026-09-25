deck := "decks/2026-09-28-lirmm-seminar.typ"

build file=deck:
    typst compile --root . {{file}} {{file_stem(file)}}.pdf

watch file=deck:
    typst watch --root . {{file}} {{file_stem(file)}}.pdf

build-all:
    mkdir -p site/decks
    for f in decks/*.typ; do \
        typst compile --root . "$f" "site/decks/$(basename "${f%.typ}").pdf"; \
    done
