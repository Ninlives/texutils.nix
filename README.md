# texutils.nix

Some utilities that can be used by nix projects which manage tex files.

# Usage

## callTex2Nix

Inspired by [tex2nix](https://github.com/Mic92/tex2nix), re-implemented in pure nix.

Example:
```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.texutils.url = "github:Ninlives/texutils.nix";

  outputs = { self, nixpkgs, texutils }:
    let
      inherit (nixpkgs.lib) hasSuffix;
      inherit (nixpkgs.lib.filesystem) listFilesRecursive;
      inherit (nixpkgs.legacyPackages.x86_64-linux) texlive runCommandLocal;
      tex = texutils.lib.callTex2Nix {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        srcs = builtins.filter (p: hasSuffix ".tex" p || hasSuffix ".cls" p || hasSuffix ".sty" p) (listFilesRecursive ./.);
        # In case some dependencies fails to be detected
        extraTexPackages = { inherit (texlive) ctex; };
      };
      input = ./.;
    in {
      defaultPackage.x86_64-linux = runCommandLocal "resume" {} ''
        cd ${input}
        ${tex}/bin/xelatex -output-directory=$TMPDIR resume.tex
        mkdir -p $out
        cd $TMPDIR
        mv *.pdf $out
      '';
    };
}
```
