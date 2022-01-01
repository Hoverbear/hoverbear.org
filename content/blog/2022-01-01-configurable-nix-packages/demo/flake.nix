{
  description = "An example of a configurable Nix package.";

  inputs = {
    nixpkgs.url = "nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    naersk.url = "github:nix-community/naersk";
    naersk.inputs.nixpkgs.follows = "nixpkgs";
    gitignore.url = "github:hercules-ci/gitignore.nix";
    gitignore.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay, naersk, gitignore }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      pkgsForSystem = system: (import nixpkgs {
        inherit system;
        overlays = [
          self.overlay
          rust-overlay.overlay
          (self: super: { inherit (self.rust-bin.stable.latest) rustc cargo rustdoc; })
        ];
      });
    in
    {
      overlay = final: prev: {
        demo-unwrapped = naersk.lib."${final.hostPlatform.system}".buildPackage rec {
          pname = "demo";
          version = "0.0.1";
          src = gitignore.lib.gitignoreSource ./.;
        };
        wrapDemo = demo-unwrapped: final.lib.makeOverridable ({ configuration ? null }:
          if configuration == null then
            demo-unwrapped
          else
            let
              configurationFile = final.writeTextFile {
                name = "demo-config";
                text = configuration;
              }; in
            final.symlinkJoin {
              name = "demo-${final.lib.getVersion final.demo-unwrapped}";
              paths = [ ];
              nativeBuildInputs = with final; [ makeWrapper ];
              postBuild = ''
                makeWrapper ${demo-unwrapped}/bin/demo \
                  ${placeholder "out"}/bin/demo \
                  --set-default DEMO_CONFIG ${configurationFile}
              '';
            });
        demo = final.wrapDemo final.demo-unwrapped { };
      };

      defaultPackage = forAllSystems (system:
        (pkgsForSystem system).demo
      );

      packages = forAllSystems (system:
        let
          pkgs = pkgsForSystem system;
        in
        {
          inherit (pkgs) demo demo-unwrapped;
          demoConfigured = pkgs.demo.override {
            configuration = ''
              switch = true
            '';
          };
        });

      devShell = forAllSystems (system:
        let
          pkgs = pkgsForSystem system;
        in
        pkgs.mkShell {
          inputsFrom = [ pkgs.demo ];
          buildInputs = with pkgs; [ nixpkgs-fmt cargo rust-bin.stable.latest.default ];
        });

      checks = forAllSystems (system:
        let
          pkgs = pkgsForSystem system;
        in
        {
          format = pkgs.runCommand "check-format"
            { } ''
            ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
            touch $out # it worked!`
          '';
          inherit (pkgs) demo;
          demoConfigured = self.packages."${system}".demoConfigured;
        });
    };
}
