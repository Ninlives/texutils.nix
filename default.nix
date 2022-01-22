{ pkgs ? import <nixpkgs> { }, srcs, extraTexPackages ? { } }:
let
  inherit (builtins)
    trace match head tail split filter readFile isList isNull elemAt pathExists;
  inherit (pkgs.lib)
    concatMap concatLists subtractLists splitString genAttrs unique remove;
  inherit (pkgs.lib.filesystem) listFilesRecursive;
  inherit (pkgs) texlive;
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
          texDirs =
            filter pathExists (map (o: "${o}/tex") texlive.${target}.pkgs);
          texFiles = concatMap listFilesRecursive texDirs;
          deps = concatMap extractRequirements texFiles;
          done' = done ++ [ target ];
          working' = subtractLists done' (deps ++ tail working);
        in collectDeps' working' done'
      else
        collectDeps' (tail working) done;

  requirements = collectDeps requiredPackages;

in texlive.combine ((genAttrs requirements (p: texlive.${p})) // {
  inherit (texlive) scheme-small;
} // extraTexPackages)
