{
  description = "Hoverbear.org";

  inputs = {
    nixpkgs.url = "nixpkgs";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
    in
    {
      overlay = final: prev: {
        image-optimize = final.writeShellApplication {
          name = "image-optimize";
          runtimeInputs = with final; [
            bash
            fd
            jpegoptim
            optipng
          ];
          text = ''
            fd \
              --exclude static/processed_images \
              --extension jpg \
              --extension jpeg \
              --threads "$(nproc)" \
              --exec jpegoptim
            fd \
              --exclude static/processed_images \
              --extension png \
              --threads "$(nproc)" \
              --exec optipng
          '';
        };
      };

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              self.overlay
            ];
          };
        in
        {
          inherit (pkgs) image-optimize;
        });

      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              self.overlay
            ];
          };
        in
        {
          format = pkgs.runCommand "check-format"
            { } ''
            ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
            touch $out # it worked!
          '';
        });

      devShell = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              self.overlay
            ];
          };
        in
        pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            zola
            image-optimize
          ];
        });
    };
}
