// Command playground is the CUE evaluator behind site/play/: compiled to
// WebAssembly, it exposes cueEval(source, mode) to the page's JavaScript.
package main

import (
	"syscall/js"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/ast"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/errors"
	"cuelang.org/go/cue/format"
	"cuelang.org/go/encoding/yaml"
)

func eval(src, mode string) (string, error) {
	// Syntax errors surface through Validate too, which, unlike v.Err(),
	// reports every conflict rather than the first one.
	v := cuecontext.New().CompileString(src, cue.Filename("input.cue"))
	if mode == "eval" {
		if err := v.Validate(cue.All()); err != nil {
			return "", err
		}
		// Like `cue eval`: the evaluated value, without the outer braces.
		n := v.Syntax(cue.Final(), cue.Optional(true), cue.Definitions(true))
		if s, ok := n.(*ast.StructLit); ok {
			n = &ast.File{Decls: s.Elts}
		}
		b, err := format.Node(n)
		return string(b), err
	}
	if err := v.Validate(cue.Concrete(true), cue.All()); err != nil {
		return "", err
	}
	b, err := yaml.Encode(v)
	return string(b), err
}

func main() {
	js.Global().Set("cueEval", js.FuncOf(func(_ js.Value, args []js.Value) any {
		out, err := eval(args[0].String(), args[1].String())
		if err != nil {
			return map[string]any{"error": errors.Details(err, nil)}
		}
		return map[string]any{"output": out}
	}))
	select {}
}
