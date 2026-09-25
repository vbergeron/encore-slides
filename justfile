build file="example.typ":
    typst compile {{file}} {{file_stem(file)}}.pdf

watch file="example.typ":
    typst watch {{file}} {{file_stem(file)}}.pdf
