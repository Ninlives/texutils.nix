{
  outputs = { self }: {
    lib.callTex2Nix = import ./default.nix;
  };
}
