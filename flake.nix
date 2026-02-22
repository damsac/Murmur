{
  description = "Murmur iOS development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        isDarwin = pkgs.stdenv.isDarwin;

        preCommitHook = pkgs.writeShellScript "pre-commit" ''
          # Validate project.local.yml exists and has required settings
          if git diff --cached --name-only | grep -qE '(project\.yml|project\.local\.yml)'; then
            echo "project.yml changed — validating local config..."
            if [ ! -f project.local.yml ]; then
              echo "ERROR: project.local.yml not found" >&2
              echo "Copy project.local.yml.template to project.local.yml and configure your settings" >&2
              exit 1
            fi
            APP_GROUP=$(grep 'APP_GROUP_IDENTIFIER:' project.local.yml 2>/dev/null | awk '{print $2}')
            if [ -z "$APP_GROUP" ]; then
              echo "ERROR: APP_GROUP_IDENTIFIER not set in project.local.yml" >&2
              exit 1
            fi
            echo "Local config validated."
          fi

          # Lint staged Swift files
          STAGED_SWIFT=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)
          if [ -n "$STAGED_SWIFT" ]; then
            echo "Linting staged Swift files..."
            echo "$STAGED_SWIFT" | xargs ${pkgs.swiftlint}/bin/swiftlint lint --quiet --strict 2>&1
            RESULT=$?
            if [ $RESULT -ne 0 ]; then
              echo "SwiftLint found errors. Fix them or commit with --no-verify to skip." >&2
              exit 1
            fi
          fi
        '';

        postMergeHook = pkgs.writeShellScript "post-merge" ''
          # Regenerate xcodeproj if project.yml or flake changed
          CHANGED=$(git diff-tree -r --name-only --no-commit-id ORIG_HEAD HEAD)

          if echo "$CHANGED" | grep -qE '(project\.yml|project\.local\.yml\.template)'; then
            echo "project.yml changed — regenerating Xcode project..."
            make generate
          fi

          if echo "$CHANGED" | grep -qE '(flake\.nix|flake\.lock)'; then
            echo "Flake inputs changed — run 'direnv reload' or re-enter the shell to update tools."
          fi
        '';

      in
      {
        devShells.default = pkgs.mkShellNoCC {
          name = "murmur-dev";
          packages = pkgs.lib.optionals isDarwin (with pkgs; [
            swiftlint
            xcodegen
            xcbeautify
            gnumake
            nodejs
            gh
          ]);
          shellHook = pkgs.lib.optionalString isDarwin ''
            # Strip Nix SDK variables that conflict with Xcode.
            # Packages propagate Apple SDK setup hooks even with mkShellNoCC;
            # we only need the binaries on PATH, not the C toolchain env.
            unset DEVELOPER_DIR SDKROOT NIX_CFLAGS_COMPILE NIX_LDFLAGS

            # Install git hooks from Nix store
            if [ -d .git ]; then
              mkdir -p .git/hooks
              ln -sf ${preCommitHook} .git/hooks/pre-commit
              ln -sf ${postMergeHook} .git/hooks/post-merge
            fi

            # Warn if Xcode version doesn't match team recommendation
            if command -v xcodebuild &> /dev/null; then
              XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -n1 | awk '{print $2}' | cut -d. -f1)
              if [ -n "$XCODE_VERSION" ]; then
                if [ "$XCODE_VERSION" -lt 26 ]; then
                  echo "⚠️  WARNING: Xcode $XCODE_VERSION detected, but the team recommends Xcode 26.2+"
                  echo "   Some features may not work as expected on older versions"
                fi
              fi
            else
              echo "⚠️  WARNING: xcodebuild not found — Xcode installation not detected"
              echo "   You'll need Xcode installed to build the project"
            fi

            echo "Murmur dev shell — run 'make help' for available targets"
          '';
        };

      });
}
