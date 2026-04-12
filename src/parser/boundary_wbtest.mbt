///|
test "parser can reach lexer and objects boundary probes" {
  inspect(@objects.boundary_probe(), content="objects")
  inspect(@lexer.boundary_probe(), content="objects")
}
