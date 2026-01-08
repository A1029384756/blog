{
	description = "my blog";
	inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
	inputs.flake-utils.url = "github:numtide/flake-utils";

	outputs = { self, nixpkgs, flake-utils }:
		flake-utils.lib.eachDefaultSystem (system:
			let pkgs = nixpkgs.legacyPackages.${system};
			in {
				packages.blog = pkgs.stdenv.mkDerivation {
					name = "blog";
					src = self;
					buildPhase = "${pkgs.lib.getExe pkgs.hugo}";
					installPhase = "cp -r public $out";
				};

				defaultPackage = self.packages.${system}.blog;
				devShells.default = pkgs.mkShell { packages = [ pkgs.hugo ]; };
		});
}
