let
  cacu = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/ggOo83D7D2Imd7bv8hErkMqZhkeRZbRS0Obqb7KlO cacu@mininas";
in
{
  "github-token.age".publicKeys = [ cacu ];
}
