{ pkgs ? import <nixpkgs> { }, srcs, extraTexPackages ? { } }:
let
  inherit (builtins)
    trace match head tail split filter readFile isList isNull elemAt pathExists;
  inherit (pkgs.lib)
    concatMap concatLists subtractLists splitString genAttrs unique remove
    hasSuffix isDerivation;
  inherit (pkgs.lib.filesystem) listFilesRecursive;
  inherit (pkgs) texlive;
  isTexFile = f:
    let fstr = toString f;
    in hasSuffix ".tex" fstr || hasSuffix ".cls" fstr || hasSuffix ".sty" fstr;
  extractRequirements = f:
    let lines = splitString "\n" (readFile f);
    in concatMap extractRequirements' lines;
  extractRequirements' = line:
    let
      trim = s:
        let trimmed = match "[[:space:]]*([^[:space:]]*)[[:space:]]*" s;
        in if isNull trimmed then
          trace
          "Package '${s}' contains whitespace in the name, please check again."
          null
        else
          elemAt trimmed 0;
      use = match "\\\\(usepackage|RequirePackage).*\\{([^}]+)}.*" line;
      splitted = filter (u: !(isList u)) (split "," (elemAt use 1));
      trimmed = filter (s: !(isNull s)) (map trim splitted);
    in if isNull use then [ ] else trimmed;

  requiredPackages = unique (concatLists (map extractRequirements srcs));

  collectDeps = ps: collectDeps' ps [ ];
  collectDeps' = working: done:
    if working == [ ] then
      done
    else
      let target = head working;
      in if texlive ? ${target} then
        let
          texDirs = filter pathExists (map (o: "${o}/tex") (cleanup
            (filter (p: isDerivation p && p.tlType or "foo" == "run")
              texlive.${target}.pkgs)));
          texFiles = filter isTexFile (concatMap listFilesRecursive texDirs);
          deps = concatMap extractRequirements texFiles;
          done' = done ++ [ target ];
          working' = cleanup (deps ++ tail working);
          cleanup = pkgList: subtractLists done' (unique pkgList);
        in collectDeps' working' done'
      else
        collectDeps' (tail working) done;

  requirements =
    collectDeps (requiredPackages ++ (builtins.attrNames extraTexPackages));

in texlive.combine ((genAttrs requirements (p: texlive.${p})) // {
  inherit (texlive) scheme-small;
})
